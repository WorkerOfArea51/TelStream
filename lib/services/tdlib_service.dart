import 'dart:async';
import 'dart:io';
import 'dart:ffi';
import 'dart:convert';
import 'dart:math';
import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synchronized/synchronized.dart';
import 'package:tdlib/td_client.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:path_provider/path_provider.dart';
import '../core/logger.dart';
import '../core/utils/path_helper.dart';
import '../core/utils/td_json_util.dart';

final tdlibServiceProvider = Provider<TdlibService>((ref) {
  final service = TdlibService();
  ref.onDispose(() => service.destroy());
  return service;
});

class TdlibService {
  int? _clientId;
  bool _isDestroyed = false;
  Timer? _initPruneTimer;
  final _pendingLock = Lock();
  
  late final DynamicLibrary _lib;
  late final Pointer<Utf8> Function(double timeout) _nativeReceive;
  bool _libInitialized = false;
  
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

  Future<String> _loadOrCreateDbEncryptionKey() async {
    const storage = FlutterSecureStorage();
    String? key = await storage.read(key: 'tdlib_db_key');
    if (key == null || key.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64Encode(values);
      await storage.write(key: 'tdlib_db_key', value: key);
    } else if (key.contains('-') || key.contains('_')) {
      key = key.replaceAll('-', '+').replaceAll('_', '/');
      await storage.write(key: 'tdlib_db_key', value: key);
    }
    return key;
  }

  Future<void>? _initFuture;

  void forceReset() {
    Log.w('TDLib forceReset called. Clearing in-flight init.');
    _initFuture = null;
    if (_clientId != null) {
      try {
        tdSend(_clientId!, const td.Close());
      } catch (_) {}
      _clientId = null;
    }
  }

  Future<void> init(
    int apiId,
    String apiHash, {
    List<String>? excludedPaths,
    double? limitMb,
    int? ttlDays,
  }) {
    if (_initFuture != null) return _initFuture!;
    return _initFuture = _doInit(apiId, apiHash, excludedPaths: excludedPaths, limitMb: limitMb, ttlDays: ttlDays).whenComplete(() {
      _initFuture = null;
    });
  }

  Future<void> _doInit(
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
    _initNativeLibrary();
    _startEventLoop();

    final dbKey = await _loadOrCreateDbEncryptionKey();
    
    const storage = FlutterSecureStorage();
    final isMigrated = await storage.read(key: 'tdlib_db_migrated');
    bool needsMigration = isMigrated != 'true';
    
    String deviceModel = 'Unknown';
    if (Platform.isAndroid) deviceModel = 'Android';
    else if (Platform.isIOS) deviceModel = 'iOS';
    else if (Platform.isMacOS) deviceModel = 'macOS';
    else if (Platform.isWindows) deviceModel = 'Windows';
    else if (Platform.isLinux) deviceModel = 'Linux';

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
      deviceModel: deviceModel,
      systemVersion: Platform.operatingSystemVersion.replaceAll(RegExp(r'[^\x20-\x7E]'), ''),
      applicationVersion: '1.0',
      enableStorageOptimizer: true,
      ignoreFileNames: false,
      databaseEncryptionKey: dbKey, 
    );
    await sendAsync(params);

    // Force TDLib online mode so it doesn't throttle background downloads
    send(const td.SetOption(name: 'online', value: td.OptionValueBoolean(value: true)));

    if (needsMigration) {
      await storage.write(key: 'tdlib_db_migrated', value: 'true');
    }

    // Give TDLib a moment to initialize its DB, then prune cached video files
    _initPruneTimer?.cancel();
    _initPruneTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDestroyed) {
        pruneCache(
          excludedPaths: excludedPaths ?? [],
          limitMb: limitMb,
          ttlDays: ttlDays,
        );
      }
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

  void _initNativeLibrary() {
    if (_libInitialized) return;
    try {
      final libName = Platform.isWindows ? 'tdjson.dll' : (Platform.isAndroid ? 'libtdjson.so' : 'libtdjson.so');
      _lib = DynamicLibrary.open(libName);
      final receivePtr = _lib.lookup<NativeFunction<Pointer<Utf8> Function(Double)>>('td_receive');
      _nativeReceive = receivePtr.asFunction<Pointer<Utf8> Function(double)>();
      _libInitialized = true;
      Log.i('TDLib direct FFI receive library loaded successfully.');
    } catch (e, stack) {
      Log.e('Failed to load native library for custom FFI receive', e, stack);
    }
  }

  static Map<String, dynamic> sanitizeJson(Map<String, dynamic> json) {
    return TdJsonUtil.sanitize(json);
  }

  void _startEventLoop() async {
    int idleCount = 0;
    int eventsProcessed = 0;
    while (!_isDestroyed) {
      try {
        td.TdObject? event;
        if (_libInitialized) {
          final rawPtr = _nativeReceive(0.0);
          if (rawPtr != nullptr) {
            final jsonStr = rawPtr.toDartString();
            final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
            final sanitized = sanitizeJson(jsonMap);
            event = td.convertToObject(jsonEncode(sanitized));
          }
        } else {
          event = tdReceive(0.0);
        }

        if (event == null) {
          idleCount++;
          // Yield to event loop, back off to 20ms when idle to reduce CPU usage without freezing UI
          await Future.delayed(Duration(milliseconds: idleCount > 10 ? 20 : 5));
          continue;
        }
        
        idleCount = 0; // reset on event
        eventsProcessed++;
        if (eventsProcessed > 50) {
          eventsProcessed = 0;
          await Future.delayed(Duration.zero); // force yield to Dart event loop
        }

        // Filter out false-positive TdError events caused by closing inactive client IDs on startup
        if (event is td.TdError && (event.message == "Invalid TDLib instance specified" || event.message.contains("Invalid TDLib instance"))) {
          continue;
        }
        if (event.extra is int) {
          final id = event.extra as int;
          final completer = await _pendingLock.synchronized(() => _pendingRequests.remove(id));
          if (completer != null && !completer.isCompleted) {
            completer.complete(event);
            continue;
          }
        }
        _updatesController.add(event);
        
      } catch (e, stack) {
        try {
          final appDir = await getAppDirectory();
          File('${appDir.path}/tdlib_crash.txt').writeAsStringSync('CRASH: ${e.runtimeType} | $e\n$stack\n', mode: FileMode.append);
        } catch (_) {}
        Log.e("Exception inside TDLib event loop", e, stack);
        // Only delay if it's NOT a parsing error to prevent infinite spin on critical FFI failure
        if (e is! TypeError && e is! FormatException && e is! NoSuchMethodError) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  }

  void send(td.TdFunction request, {dynamic extra}) {
    if (_clientId != null) {
      tdSend(_clientId!, request, extra);
    }
  }

  Future<td.TdObject> sendAsync(td.TdFunction request) async {
    final id = ++_requestId;
    final completer = Completer<td.TdObject>();
    await _pendingLock.synchronized(() => _pendingRequests[id] = completer);
    
    // Automatically clean up after 30 seconds to prevent memory leaks if TDLib never responds
    Timer(const Duration(seconds: 30), () async {
      final pending = await _pendingLock.synchronized(() => _pendingRequests.remove(id));
      if (pending != null && !pending.isCompleted) {
        pending.completeError(TimeoutException('TDLib response timeout', const Duration(seconds: 30)));
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
          limit: 50,
        )).timeout(
          const Duration(seconds: 10),
          onTimeout: () => td.TdError(code: 408, message: "Request Timeout"),
        );
        if (_isDestroyed || _clientId == null) break;
        if (res is td.TdError) {
          break; // End of list or error
        }
        chatsLoaded += 50;
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    });
  }

  void destroy() {
    _isDestroyed = true;
    _initPruneTimer?.cancel();
    _updatesController.close();
    if (_clientId != null) {
      try {
        tdSend(_clientId!, const td.Close());
      } catch (_) {}
      _clientId = null;
    }
  }
}




