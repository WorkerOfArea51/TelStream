import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_client.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:path_provider/path_provider.dart';
import '../core/logger.dart';
import '../core/utils/path_helper.dart';

final tdlibServiceProvider = Provider<TdlibService>((ref) {
  final service = TdlibService();
  ref.onDispose(() => service.destroy());
  return service;
});

class TdlibService {
  int? _clientId;
  bool _isDestroyed = false;
  
  final _updatesController = StreamController<td.TdObject>.broadcast();
  Stream<td.TdObject> get updates => _updatesController.stream;

  Future<void> _closePreviousClient() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/last_client_id.txt');
      if (await file.exists()) {
        final content = await file.readAsString();
        final lastId = int.tryParse(content.trim());
        if (lastId != null && lastId > 0) {
          try {
            tdSend(lastId, const td.Close());
          } catch (_) {}
          // Give the previous client a short moment to close databases and release locks
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCurrentClient(int id) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/last_client_id.txt');
      await file.writeAsString(id.toString());
    } catch (_) {}
  }

  Future<void> init(
    int apiId,
    String apiHash, {
    List<String>? excludedPaths,
    double? limitMb,
    int? ttlDays,
  }) async {
    if (_clientId != null) {
      try {
        tdSend(_clientId!, const td.Close());
      } catch (_) {}
      _clientId = null;
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      // Close previous client ID from last session/hot restart to release database lock
      await _closePreviousClient();
    }

    _clientId = tdCreate();
    if (_clientId != null && _clientId! > 0) {
      await _saveCurrentClient(_clientId!);
    }
    
    final appDocDir = await getAppDirectory();
    final safePath = appDocDir.path.replaceAll('\\', '/');
    final logPath = '$safePath/tdlib.log';

    send(td.SetLogStream(
      logStream: td.LogStreamFile(
        path: logPath,
        maxFileSize: 10 * 1024 * 1024,
        redirectStderr: true,
      ),
    ));
    send(const td.SetLogVerbosityLevel(newVerbosityLevel: 2));
    _startEventLoop();

    final params = td.SetTdlibParameters(
      useTestDc: false,
      databaseDirectory: safePath,
      filesDirectory: safePath,
      useFileDatabase: true,
      useChatInfoDatabase: true,
      useMessageDatabase: true,
      useSecretChats: false,
      apiId: apiId,
      apiHash: apiHash,
      systemLanguageCode: 'en',
      deviceModel: 'Windows',
      systemVersion: '10',
      applicationVersion: '1.0',
      enableStorageOptimizer: true,
      ignoreFileNames: false,
      databaseEncryptionKey: '', 
    );
    send(params);

    // Give TDLib a moment to initialize its DB, then prune cached video files
    Future.delayed(const Duration(seconds: 5), () {
      pruneCache(
        excludedPaths: excludedPaths ?? [],
        limitMb: limitMb,
        ttlDays: ttlDays,
      );
    });
  }

  Future<void> pruneCache({
    required List<String> excludedPaths,
    double? limitMb,
    int? ttlDays,
  }) async {
    try {
      final appDocDir = await getAppDirectory();
      final targetDirs = [
        'videos',
        'documents',
        'temp',
        'voice',
        'music',
        'video_notes',
        'stickers',
        'animations',
        'photos'
      ];
      
      final List<File> cacheFiles = [];
      final List<td.FileType> optimizeTypes = [
        const td.FileTypeVideo(),
        const td.FileTypeDocument(),
        const td.FileTypeAnimation(),
        const td.FileTypeAudio(),
        const td.FileTypeVoiceNote(),
      ];

      // 1. Run TDLib's OptimizeStorage first
      try {
        await sendAsync(td.OptimizeStorage(
          size: limitMb != null ? (limitMb * 1024 * 1024).round() : 0,
          ttl: ttlDays != null ? ttlDays * 24 * 3600 : 0,
          count: 0,
          immunityDelay: 0,
          fileTypes: optimizeTypes,
          chatIds: [],
          excludeChatIds: [],
          returnDeletedFileStatistics: false,
          chatLimit: 0,
        ));
      } catch (e, stackTrace) {
        Log.e('TDLib OptimizeStorage failed', e, stackTrace);
      }

      // 2. Scan and prune local files manually based on TTL and Size Limit
      final now = DateTime.now();
      final double limitBytes = (limitMb ?? 2048.0) * 1024 * 1024;
      
      for (final dirName in targetDirs) {
        final dir = Directory('${appDocDir.path}/$dirName');
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              final path = entity.path.toLowerCase();
              final isDatabase = path.endsWith('.db') || 
                                 path.endsWith('.db-journal') || 
                                 path.endsWith('.db-wal') || 
                                 path.endsWith('.db-shm') || 
                                 path.endsWith('.bin') ||
                                 path.endsWith('.binlog') ||
                                 path.endsWith('.key');
                                 
              if (!isDatabase) {
                final bool isExcluded = excludedPaths.any((ex) => ex.toLowerCase() == path);
                if (!isExcluded) {
                  cacheFiles.add(entity);
                }
              }
            }
          }
        }
      }

      // TTL Check: Delete files older than ttlDays
      if (ttlDays != null && ttlDays > 0) {
        final threshold = now.subtract(Duration(days: ttlDays));
        final List<File> toRemove = [];
        for (final file in cacheFiles) {
          try {
            final lastModified = await file.lastModified();
            if (lastModified.isBefore(threshold)) {
              final size = await file.length();
              await file.delete();
              Log.i('TTL CACHE PRUNED: ${file.path} ($size bytes, age: ${now.difference(lastModified).inDays} days)');
              toRemove.add(file);
            }
          } catch (_) {}
        }
        cacheFiles.removeWhere((f) => toRemove.contains(f));
      }

      // Limit Check: Sort remaining files by lastModified ascending and prune oldest if size exceeds limit
      double totalSize = 0;
      final List<MapEntry<File, DateTime>> fileStats = [];
      for (final file in cacheFiles) {
        try {
          final size = await file.length();
          final mTime = await file.lastModified();
          totalSize += size;
          fileStats.add(MapEntry(file, mTime));
        } catch (_) {}
      }

      if (limitMb != null && limitMb > 0 && totalSize > limitBytes) {
        fileStats.sort((a, b) => a.value.compareTo(b.value));
        
        double currentSize = totalSize;
        for (final entry in fileStats) {
          if (currentSize <= limitBytes) break;
          try {
            final size = await entry.key.length();
            await entry.key.delete();
            currentSize -= size;
            Log.i('SIZE LIMIT CACHE PRUNED: ${entry.key.path} ($size bytes)');
          } catch (_) {}
        }
      }

    } catch (e, stackTrace) {
      Log.e('CACHE PRUNE ERROR', e, stackTrace);
    }
  }

  Future<void> clearVideoCache({bool includePhotos = false, List<String>? excludedPaths}) async {
    try {
      final List<td.FileType> fileTypes = [
        const td.FileTypeVideo(),
        const td.FileTypeDocument(),
        const td.FileTypeAnimation(),
        const td.FileTypeAudio(),
        const td.FileTypeVoiceNote(),
      ];
      if (includePhotos) {
        fileTypes.add(const td.FileTypePhoto());
        fileTypes.add(const td.FileTypeThumbnail());
      }

      await sendAsync(td.OptimizeStorage(
        size: 0,
        ttl: 0,
        count: 0,
        immunityDelay: 0,
        fileTypes: fileTypes,
        chatIds: [],
        excludeChatIds: [],
        returnDeletedFileStatistics: false,
        chatLimit: 0,
      ));
    } catch (_) {}

    try {
      final appDocDir = await getAppDirectory();
      final targetDirs = [
        'videos',
        'documents',
        'temp',
        'voice',
        'music',
        'video_notes',
        'stickers',
        'animations',
      ];
      if (includePhotos) {
        targetDirs.add('photos');
      }
      
      for (final dirName in targetDirs) {
        final dir = Directory('${appDocDir.path}/$dirName');
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              final path = entity.path.toLowerCase();
              final isDatabase = path.endsWith('.db') || 
                                 path.endsWith('.db-journal') || 
                                 path.endsWith('.db-wal') || 
                                 path.endsWith('.db-shm') || 
                                 path.endsWith('.bin') ||
                                 path.endsWith('.binlog') ||
                                 path.endsWith('.key');
                                 
              if (!isDatabase) {
                try {
                  final bool isExcluded = excludedPaths?.any((ex) => ex.toLowerCase() == path) ?? false;
                  if (!isExcluded) {
                    final size = await entity.length();
                    await entity.delete();
                    Log.i('CACHE DELETED: $path ($size bytes)');
                  }
                } catch (e, stackTrace) {
                  Log.e('CACHE DELETE FAILED: $path', e, stackTrace);
                }
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      Log.e('CACHE SCAN ERROR', e, stackTrace);
    }
  }

  Future<void> compactDatabase() async {
    try {
      Log.i('TDLib compactDatabase initiated.');
      // Optimize storage to trigger general database defragmentation and vacuum SQLite pages
      await sendAsync(const td.OptimizeStorage(
        size: 0,
        ttl: 0,
        count: 0,
        immunityDelay: 0,
        fileTypes: [],
        chatIds: [],
        excludeChatIds: [],
        returnDeletedFileStatistics: false,
        chatLimit: 0,
      ));
      Log.i('TDLib compactDatabase completed successfully.');
    } catch (e, stack) {
      Log.e('TDLib Database compaction failed', e, stack);
    }
  }

  final Map<int, Completer<td.TdObject>> _pendingRequests = {};
  int _requestId = 0;

  void _startEventLoop() async {
    while (!_isDestroyed) {
      try {
        final event = tdReceive(0.0);
        if (event != null) {
          // Filter out false-positive TdError events caused by closing inactive client IDs on startup
          if (event is td.TdError && (event.message == "Invalid TDLib instance specified" || event.message.contains("Invalid TDLib instance"))) {
            continue;
          }
          if (event.extra is int) {
            final id = event.extra as int;
            if (_pendingRequests.containsKey(id)) {
              _pendingRequests[id]!.complete(event);
              _pendingRequests.remove(id);
              continue;
            }
          }
          _updatesController.add(event);
          continue;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 5));
    }
  }

  void send(td.TdFunction request, {dynamic extra}) {
    if (_clientId != null) {
      tdSend(_clientId!, request, extra);
    }
  }

  Future<td.TdObject> sendAsync(td.TdFunction request) {
    final id = ++_requestId;
    final completer = Completer<td.TdObject>();
    _pendingRequests[id] = completer;
    
    // Automatically clean up after 30 seconds to prevent memory leaks if TDLib never responds
    Future.delayed(const Duration(seconds: 30), () {
      if (_pendingRequests.containsKey(id)) {
        _pendingRequests.remove(id);
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('TDLib response timeout', const Duration(seconds: 30)));
        }
      }
    });

    send(request, extra: id);
    return completer.future;
  }

  void loadChatsInBackground() {
    Future(() async {
      int chatsLoaded = 0;
      while (chatsLoaded < 500) {
        if (_isDestroyed || _clientId == null) break;
        final res = await sendAsync(td.LoadChats(
          chatList: const td.ChatListMain(),
          limit: 100,
        )).timeout(
          const Duration(seconds: 10),
          onTimeout: () => td.TdError(code: 408, message: "Request Timeout"),
        );
        if (res is td.TdError) {
          break; // End of list or error
        }
        chatsLoaded += 100;
        await Future.delayed(const Duration(milliseconds: 200));
      }
    });
  }

  void destroy() {
    _isDestroyed = true;
    _updatesController.close();
    if (_clientId != null) {
      try {
        tdSend(_clientId!, const td.Close());
      } catch (_) {}
      _clientId = null;
    }
  }
}
