import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_client.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:path_provider/path_provider.dart';

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

  Future<void> init(int apiId, String apiHash) async {
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
    
    send(const td.SetLogVerbosityLevel(newVerbosityLevel: 1));
    _startEventLoop();

    final appDocDir = await getApplicationDocumentsDirectory();
    final params = td.SetTdlibParameters(
      useTestDc: false,
      databaseDirectory: appDocDir.path,
      filesDirectory: appDocDir.path,
      useFileDatabase: true,
      useChatInfoDatabase: true,
      useMessageDatabase: true,
      useSecretChats: false,
      apiId: apiId,
      apiHash: apiHash,
      systemLanguageCode: 'en',
      deviceModel: 'Android',
      systemVersion: '10',
      applicationVersion: '1.0',
      enableStorageOptimizer: true,
      ignoreFileNames: false,
      databaseEncryptionKey: '', 
    );
    send(params);

    // Give TDLib a moment to initialize its DB, then clear large cached video files
    Future.delayed(const Duration(seconds: 5), () {
      clearVideoCache();
    });
  }

  Future<void> clearVideoCache() async {
    try {
      await sendAsync(td.OptimizeStorage(
        size: 0,
        ttl: 0,
        count: 0,
        immunityDelay: 0,
        fileTypes: [
          const td.FileTypeVideo(),
          const td.FileTypeDocument(),
          const td.FileTypeAnimation(),
          const td.FileTypePhoto(),
          const td.FileTypeThumbnail(),
          const td.FileTypeAudio(),
          const td.FileTypeVoiceNote(),
        ],
        chatIds: [],
        excludeChatIds: [],
        returnDeletedFileStatistics: false,
        chatLimit: 0,
      ));
    } catch (_) {}

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetDirs = [
        'photos',
        'videos',
        'documents',
        'temp',
        'voice',
        'music',
        'video_notes',
        'stickers',
        'animations',
      ];
      
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
                  final size = await entity.length();
                  await entity.delete();
                  print('CACHE DELETED: $path ($size bytes)');
                } catch (e) {
                  print('CACHE DELETE FAILED: $path - Error: $e');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('CACHE SCAN ERROR: $e');
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
        ));
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
