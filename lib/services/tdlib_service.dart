import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:ffi';
import 'dart:convert';
import 'dart:math';
import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synchronized/synchronized.dart';
import 'package:flutter/widgets.dart';
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
  Timer? _onlineHeartbeat;
  bool _isForeground = true;
  final _pendingLock = Lock();
  final _initLock = Lock();
  
  late final DynamicLibrary _lib;
  late final Pointer<Utf8> Function(double timeout) _nativeReceive;
  void Function(Pointer<Void>)? _nativeFree;
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
          } catch (e, st) { Log.e('Ignored error in tdlib_service', e, st); }
          // Give the previous client a short moment to close databases and release locks
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    } catch (e, st) { Log.e('Ignored error in tdlib_service', e, st); }
  }

  Future<void> _saveCurrentClient(int id) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/last_client_id.txt');
      await file.writeAsString(id.toString());
    } catch (e, st) { Log.e('Ignored error in tdlib_service', e, st); }
  }

  Future<String> _loadOrCreateDbEncryptionKey() async {
    const storage = FlutterSecureStorage();
    String? key = await storage.read(key: 'tdlib_db_key');

    if (key != null && key.isNotEmpty) {
      if (key.contains('-') || key.contains('_')) {
        key = key.replaceAll('-', '+').replaceAll('_', '/');
        await storage.write(key: 'tdlib_db_key', value: key);
      }
      return key;
    }

    // Generate new key
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    key = base64Encode(values);
    await storage.write(key: 'tdlib_db_key', value: key);
    return key;
  }

  void onAppStateChanged(AppLifecycleState state) {
    _isForeground = (state == AppLifecycleState.resumed);
    if (_clientId != null) {
      send(td.SetOption(
        name: 'online',
        value: td.OptionValueBoolean(value: _isForeground),
      ));
    }
  }

  void _startOnlineHeartbeat() {
    _onlineHeartbeat?.cancel();
    _onlineHeartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isDestroyed || _clientId == null) return;
      if (_isForeground) {
        send(const td.SetOption(
          name: 'online',
          value: td.OptionValueBoolean(value: true),
        ));
      }
    });
  }

  Future<void>? _initFuture;

  Future<void> forceReset() async {
    Log.w('TDLib forceReset called. Clearing in-flight init.');
    await _initLock.synchronized(() async {
      _initFuture = null;
      if (_clientId != null) {
        try {
          tdSend(_clientId!, const td.Close());
        } catch (e, st) {
          Log.e('Failed to close TDLib on forceReset', e, st);
        }
        _clientId = null;
      }
    });
  }

  Future<void> init(
    int apiId,
    String apiHash, {
    List<String>? excludedPaths,
    double? limitMb,
    int? ttlDays,
  }) {
    if (_initFuture != null) return _initFuture!;
    return _initFuture = _initLock.synchronized(() async {
      await _doInit(apiId, apiHash, excludedPaths: excludedPaths, limitMb: limitMb, ttlDays: ttlDays);
    }).whenComplete(() {
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
      } catch (e, st) { Log.e('Ignored error in tdlib_service', e, st); }
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

    final dbPath = '$safePath/database';
    
    // In TDLib 1.8.65, setTdlibParameters is inlined and doesn't use the 'parameters' object.
    // We send it manually via raw JSON to bypass tdlib 1.6.0's SetTdlibParameters schema.
    final rawParams = {
      "@type": "setTdlibParameters",
      "use_test_dc": false,
      "database_directory": dbPath,
      "files_directory": safePath,
      "use_file_database": true,
      "use_chat_info_database": true,
      "use_message_database": true,
      "use_secret_chats": false,
      "api_id": apiId,
      "api_hash": apiHash,
      "system_language_code": "en",
      "device_model": deviceModel,
      "system_version": Platform.operatingSystemVersion.replaceAll(RegExp(r'[^\x20-\x7E]'), ''),
      "application_version": "1.0",
      "enable_storage_optimizer": true,
      "ignore_file_names": false,
      "database_encryption_key": dbKey,
    };
    
    Future<void> handleInitError(td.TdError res) async {
      Log.e('TDLib Init Error: ${res.message} (Code: ${res.code})');
      if (res.code == 401 && res.message.contains('encryption key')) {
        Log.w('Database encryption key mismatch. TDLib format likely changed. Clearing old database...');
        try {
          if (_clientId != null) {
            tdSend(_clientId!, const td.Close());
            await Future.delayed(const Duration(milliseconds: 500));
          }
          final dir = Directory(dbPath);
          if (await dir.exists()) {
            dir.deleteSync(recursive: true);
          }
          Log.i('Old database cleared. Please retry initialization.');
        } catch (e) {
          Log.e('Failed to clear old database', e);
        }
      }
      throw Exception('TDLib Init Error: ${res.message}');
    }

    if (_nativeSend != null && _clientId != null) {
      final res = await _sendRawAsync(rawParams);
      if (res is td.TdError) {
        await handleInitError(res);
      }
    } else {
      final params = td.SetTdlibParameters(
        useTestDc: false,
        databaseDirectory: dbPath,
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
      final res = await sendAsync(params);
      if (res is td.TdError) {
        await handleInitError(res);
      }
    }

    // Force TDLib online mode so it doesn't throttle background downloads
    send(const td.SetOption(name: 'online', value: td.OptionValueBoolean(value: true)));
    _startOnlineHeartbeat();

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
          } catch (e, st) { Log.e('Ignored error in tdlib_service', e, st); }
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
        } catch (e, st) { Log.e('Ignored error in tdlib_service', e, st); }
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
          } catch (e, st) { Log.e('Ignored error in tdlib_service', e, st); }
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
    } catch (e, st) { Log.e('Ignored error in tdlib_service', e, st); }

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

  void Function(int, Pointer<Utf8>)? _nativeSend;

  void _initNativeLibrary() {
      if (_libInitialized) return;
      try {
        String libName;
        if (Platform.isWindows) {
          libName = 'tdjson.dll';
        } else if (Platform.isMacOS) {
          libName = 'libtdjson.dylib';
        } else {
          libName = 'libtdjson.so';
        }
        _lib = DynamicLibrary.open(libName);
        final receivePtr = _lib.lookup<NativeFunction<Pointer<Utf8> Function(Double)>>('td_receive');
        _nativeReceive = receivePtr.asFunction<Pointer<Utf8> Function(double)>();
        try {
          final sendPtr = _lib.lookup<NativeFunction<Void Function(Int32, Pointer<Utf8>)>>('td_send');
          _nativeSend = sendPtr.asFunction<void Function(int, Pointer<Utf8>)>();
        } catch(e) {
          Log.w('td_send not found in native library');
        }
        try {
          final freePtr = _lib.lookup<NativeFunction<Void Function(Pointer<Void>)>>('td_free_string');
          _nativeFree = freePtr.asFunction<void Function(Pointer<Void>)>();
        } catch (e) {
          Log.w('td_free_string not found in native library');
        }
        _libInitialized = true;
        Log.i('TDLib direct FFI receive library loaded successfully.');
      } catch (e, stack) {
        Log.e('Failed to load TDLib native library. App will not be able to fetch from Telegram.', e, stack);
        rethrow;
      }
    }

  static Map<String, dynamic> sanitizeJson(Map<String, dynamic> json) {
    return TdJsonUtil.sanitize(json);
  }

  bool _eventLoopRunning = false;
  ReceivePort? _isolateReceivePort;
  Isolate? _eventIsolate;

  void _startEventLoop() async {
      if (_eventLoopRunning) return;
      _eventLoopRunning = true;
      
      if (!_libInitialized) {
        // Fallback for non-FFI init
        int eventsProcessed = 0;
        while (!_isDestroyed) {
          try {
            td.TdObject? event = tdReceive(0.0);
            if (event == null) {
              await Future.delayed(const Duration(milliseconds: 10));
              continue;
            }
            eventsProcessed++;
            if (eventsProcessed > 50) {
              eventsProcessed = 0;
              await Future.delayed(Duration.zero);
            }
            _processEvent(event);
          } catch (e, stack) {
            Log.e("Exception inside TDLib event loop fallback", e, stack);
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
        return;
      }

      _isolateReceivePort = ReceivePort();
      final receivePtr = _lib.lookup<NativeFunction<Pointer<Utf8> Function(Double)>>('td_receive');
      Pointer<NativeFunction<Void Function(Pointer<Void>)>>? freePtrRes;
      try {
        freePtrRes = _lib.lookup<NativeFunction<Void Function(Pointer<Void>)>>('td_free_string');
      } catch (e) {
        // Ignore if not found
      }
      
      _eventIsolate = await Isolate.spawn(_backgroundEventLoop, _EventLoopArgs(
        _isolateReceivePort!.sendPort,
        receivePtr.address,
        freePtrRes?.address,
      ));

      _isolateReceivePort!.listen((message) async {
        if (_isDestroyed) return;
        if (message is String) {
          try {
            final jsonMap = jsonDecode(message);
            final sanitized = sanitizeJson(jsonMap);
            final event = td.convertToObject(jsonEncode(sanitized));
            if (event != null) {
              _processEvent(event);
            }
          } catch (e, stack) {
            Log.e("Exception parsing event from isolate", e, stack);
          }
        }
      });
  }

  void _processEvent(td.TdObject event) async {
    if (event is td.TdError && (event.message == "Invalid TDLib instance specified" || event.message.contains("Invalid TDLib instance"))) {
      return;
    }
    if (event.extra is int) {
      final id = event.extra as int;
      final completer = await _pendingLock.synchronized(() => _pendingRequests.remove(id));
      if (completer != null && !completer.isCompleted) {
        completer.complete(event);
        return;
      }
    }
    _updatesController.add(event);
  }

  static void _backgroundEventLoop(_EventLoopArgs args) {
    final receivePtr = Pointer<NativeFunction<Pointer<Utf8> Function(Double)>>.fromAddress(args.receiveAddress);
    final nativeReceive = receivePtr.asFunction<Pointer<Utf8> Function(double)>();
    void Function(Pointer<Void>)? nativeFree;
    if (args.freeAddress != null) {
      final freePtr = Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(args.freeAddress!);
      nativeFree = freePtr.asFunction<void Function(Pointer<Void>)>();
    }

    while (true) {
      final rawPtr = nativeReceive(1.0); // Blocking receive, yields native thread
      if (rawPtr != nullptr) {
        final str = rawPtr.toDartString();
        if (nativeFree != null) nativeFree(rawPtr.cast());
        try {
          args.sendPort.send(str);
        } catch (e) {
          break;
        }
      }
    }
  }

  void send(td.TdFunction request, {dynamic extra}) {
    if (_clientId != null) {
      tdSend(_clientId!, request, extra);
    }
  }

  Future<td.TdObject> _sendRawAsync(Map<String, dynamic> request) async {
    final id = ++_requestId;
    final completer = Completer<td.TdObject>();
    await _pendingLock.synchronized(() => _pendingRequests[id] = completer);
    
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 30), () async {
      final pending = await _pendingLock.synchronized(() => _pendingRequests.remove(id));
      if (pending != null && !pending.isCompleted) {
        pending.complete(td.TdError(code: 408, message: 'TDLib response timeout (30s limit)'));
      }
    });

    completer.future.whenComplete(() => timeoutTimer?.cancel());

    request['@extra'] = id;
    
    if (_nativeSend != null && _clientId != null) {
      final jsonStr = jsonEncode(request);
      final ptr = jsonStr.toNativeUtf8();
      _nativeSend!(_clientId!, ptr);
      malloc.free(ptr);
    } else {
      timeoutTimer.cancel();
      completer.completeError(Exception("Native td_send not available, cannot send raw json"));
    }
    
    return completer.future;
  }

  Future<td.TdObject> sendAsync(td.TdFunction request) async {
    final id = ++_requestId;
    final completer = Completer<td.TdObject>();
    await _pendingLock.synchronized(() => _pendingRequests[id] = completer);
    
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 30), () async {
      final pending = await _pendingLock.synchronized(() => _pendingRequests.remove(id));
      if (pending != null && !pending.isCompleted) {
        pending.complete(td.TdError(code: 408, message: 'TDLib response timeout (30s limit)'));
      }
    });

    completer.future.whenComplete(() => timeoutTimer?.cancel());

    send(request, extra: id);
    return completer.future;
  }

  void loadChatsInBackground() {
    Future(() async {
      int chatsLoaded = 0;
      while (chatsLoaded < 500) {
        if (_isDestroyed || _clientId == null) break;
        final res = await sendAsync(const td.LoadChats(
          chatList: td.ChatListMain(),
          limit: 50,
        )).timeout(
          const Duration(seconds: 10),
          onTimeout: () => const td.TdError(code: 408, message: "Request Timeout"),
        );
        
        if (_isDestroyed || _clientId == null) break;
        
        if (res is td.TdError) {
          if (res.code == 404) break; // End of list
          // FLOOD_WAIT or transient error
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        
        chatsLoaded += 50;
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    });
  }

  void destroy() {
      _isDestroyed = true;
      _onlineHeartbeat?.cancel();
      _initPruneTimer?.cancel();
      _updatesController.close();
      if (_clientId != null) {
        try {
          tdSend(_clientId!, const td.Close());
        } catch (e, st) { Log.e('Ignored error in tdlib_service', e, st); }
        _clientId = null;
      }
      _pendingLock.synchronized(() {
        for (final c in _pendingRequests.values) {
          if (!c.isCompleted) {
            c.completeError(StateError('TdlibService destroyed'));
          }
        }
        _pendingRequests.clear();
      });
    }
}





class _EventLoopArgs {
  final SendPort sendPort;
  final int receiveAddress;
  final int? freeAddress;
  _EventLoopArgs(this.sendPort, this.receiveAddress, this.freeAddress);
}
