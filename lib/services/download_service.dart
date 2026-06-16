import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:path_provider/path_provider.dart';
import 'tdlib_service.dart';
import 'storage_service.dart';
import '../core/logger.dart';

class DownloadTask {
  final int fileId;
  final String title;
  final double progress;
  final String? localPath;
  final bool isCompleted;

  DownloadTask({
    required this.fileId,
    required this.title,
    this.progress = 0.0,
    this.localPath,
    this.isCompleted = false,
  });

  DownloadTask copyWith({
    double? progress,
    String? localPath,
    bool? isCompleted,
  }) {
    return DownloadTask(
      fileId: fileId,
      title: title,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class DownloadController extends Notifier<Map<int, DownloadTask>> {
  StreamSubscription? _subscription;
  StreamSubscription? _dirWatcherSubscription;
  static const _channel = MethodChannel('com.darkmatter.telstream/downloads');
  final Map<int, int> _lastNotificationTimes = {};
  final List<int> _pausedForStreamingFileIds = [];

  @override
  Map<int, DownloadTask> build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _dirWatcherSubscription?.cancel();
    });
    _init();
    return {};
  }

  Future<void> _updateNativeNotification(int fileId, String title, double progress, {bool isCompleted = false, bool isCancelled = false}) async {
    if (!Platform.isAndroid) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastNotificationTimes[fileId] ?? 0;
    
    if (isCompleted || isCancelled || progress == 0.0 || (now - lastTime) >= 800) {
      _lastNotificationTimes[fileId] = now;
      try {
        await _channel.invokeMethod('updateDownloadNotification', {
          'fileId': fileId,
          'title': title,
          'progress': progress,
          'isCompleted': isCompleted,
          'isCancelled': isCancelled,
        });
      } catch (e, stackTrace) {
        Log.e('Failed to update native notification', e, stackTrace);
      }
    }
  }

  Future<Directory> _getEffectiveDownloadsDirectory() async {
    final storage = ref.read(storageServiceProvider);
    final customPath = storage.getCustomDownloadDirectory();
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) {
        return dir;
      }
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final defaultDir = Directory('${appDocDir.path}/downloads');
    if (!await defaultDir.exists()) {
      await defaultDir.create(recursive: true);
    }
    return defaultDir;
  }

  Future<void> reloadDownloads() async {
    await _init();
  }

  Future<void> _init() async {
    try {
      final storage = ref.read(storageServiceProvider);
      final cachedFiles = storage.getDownloadedFiles();
      final Map<int, DownloadTask> loadedTasks = {};
      
      for (final entry in cachedFiles.entries) {
        final fileId = entry.key;
        final path = entry.value;
        final file = File(path);
        if (await file.exists()) {
          final filename = path.split(Platform.pathSeparator).last;
          loadedTasks[fileId] = DownloadTask(
            fileId: fileId,
            title: filename,
            progress: 1.0,
            isCompleted: true,
            localPath: path,
          );
        } else {
          // File was deleted / moved since last run
          await storage.removeDownloadedFile(fileId);
        }
      }
      state = loadedTasks;

      // Start watching the downloads directory for real-time updates
      final downloadsDir = await _getEffectiveDownloadsDirectory();
      _watchDirectory(downloadsDir);

    } catch (e, stackTrace) {
      Log.e('Error initializing downloads directory scan', e, stackTrace);
    }

    // Listen to tdlib updates for file download progress
    final tdlibService = ref.read(tdlibServiceProvider);
    _subscription?.cancel();
    _subscription = tdlibService.updates.listen((event) {
      if (event is td.UpdateFile) {
        final fileId = event.file.id;
        if (state.containsKey(fileId)) {
          final task = state[fileId]!;
          if (task.isCompleted) return; // Already finished and saved

          final expectedSize = event.file.expectedSize;
          final downloadedSize = event.file.local.downloadedPrefixSize;
          
          double progress = 0.0;
          if (expectedSize > 0) {
            progress = downloadedSize / expectedSize;
          }

          final isCompleted = event.file.local.isDownloadingCompleted;
          String? tempPath = event.file.local.path;

          if (isCompleted && tempPath.isNotEmpty) {
            _saveFilePermanently(fileId, tempPath, task.title);
          } else {
            state = {
              ...state,
              fileId: task.copyWith(
                progress: progress,
                isCompleted: false,
              ),
            };
            _updateNativeNotification(fileId, task.title, progress);
          }
        }
      }
    });
  }

  void _watchDirectory(Directory downloadsDir) {
    _dirWatcherSubscription?.cancel();
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    try {
      _dirWatcherSubscription = downloadsDir.watch().listen((event) {
        _syncDownloadsWithDisk();
      });
    } catch (e, stackTrace) {
      Log.w('Directory watcher failed to start: $e');
    }
  }

  Future<void> _syncDownloadsWithDisk() async {
    final storage = ref.read(storageServiceProvider);
    final cachedFiles = storage.getDownloadedFiles();
    final Map<int, DownloadTask> updatedState = {...state};
    bool changed = false;

    for (final entry in cachedFiles.entries) {
      final fileId = entry.key;
      final path = entry.value;
      if (!await File(path).exists()) {
        await storage.removeDownloadedFile(fileId);
        updatedState.remove(fileId);
        changed = true;
      }
    }

    if (changed) {
      state = updatedState;
    }
  }

  Future<void> startDownload(int fileId, String title) async {
    if (state.containsKey(fileId) && state[fileId]!.isCompleted) {
      return; // Already downloaded
    }

    // Register the task in memory
    state = {
      ...state,
      fileId: DownloadTask(fileId: fileId, title: title),
    };

    // Notify native background download service to start
    _updateNativeNotification(fileId, title, 0.0);

    // Send TDLib DownloadFile command
    ref.read(tdlibServiceProvider).send(td.DownloadFile(
      fileId: fileId,
      priority: 32,
      offset: 0,
      limit: 0,
      synchronous: false,
    ));
  }

  Future<void> cancelDownload(int fileId) async {
    final task = state[fileId];
    final title = task?.title ?? 'Download';
    
    ref.read(tdlibServiceProvider).send(td.CancelDownloadFile(
      fileId: fileId,
      onlyIfPending: false,
    ));
    ref.read(tdlibServiceProvider).send(td.DeleteFile(
      fileId: fileId,
    ));
    
    // Notify native background download service of cancellation
    _updateNativeNotification(fileId, title, 0.0, isCancelled: true);

    state = {...state}..remove(fileId);
  }

  Future<void> _saveFilePermanently(int fileId, String tempPath, String title) async {
    try {
      final downloadsDir = await _getEffectiveDownloadsDirectory();
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // 1. Keep original extension from temp path
      final ext = tempPath.contains('.') ? tempPath.split('.').last : 'mp4';

      // 2. Clean forbidden chars but preserve spaces and hyphens
      var cleanTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      
      // 3. Strip duplicate extension if cleanTitle already ends with it
      if (cleanTitle.toLowerCase().endsWith('.${ext.toLowerCase()}')) {
        cleanTitle = cleanTitle.substring(0, cleanTitle.length - (ext.length + 1));
      }

      // 4. Construct path (clean, no fileId prefixes)
      final permanentPath = '${downloadsDir.path}/$cleanTitle.$ext';

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        final tempSize = await tempFile.length();
        if (tempSize <= 0) {
          throw Exception("Temp file size is 0 bytes");
        }
        
        final permFile = await tempFile.copy(permanentPath);
        final permSize = await permFile.length();
        
        if (permSize != tempSize) {
          throw Exception("Copied file size ($permSize bytes) does not match original size ($tempSize bytes)");
        }
        
        Log.i('FILE SAVED PERMANENTLY: $permanentPath');
        
        // 5. Save persistent mapping in JSON storage
        await ref.read(storageServiceProvider).addDownloadedFile(fileId, permanentPath);
      } else {
        throw Exception("Temp file does not exist at $tempPath");
      }

      state = {
        ...state,
        fileId: state[fileId]!.copyWith(
          progress: 1.0,
          isCompleted: true,
          localPath: permanentPath,
        ),
      };

      // Notify native background download service of success
      _updateNativeNotification(fileId, title, 1.0, isCompleted: true);

    } catch (e, stackTrace) {
      Log.e('FAILED TO SAVE FILE PERMANENTLY', e, stackTrace);
      _updateNativeNotification(fileId, title, 0.0, isCancelled: true);
    }
  }

  void pauseDownloadsForStreaming() {
    _pausedForStreamingFileIds.clear();
    state.forEach((fileId, task) {
      if (!task.isCompleted) {
        _pausedForStreamingFileIds.add(fileId);
        ref.read(tdlibServiceProvider).send(td.CancelDownloadFile(
          fileId: fileId,
          onlyIfPending: false,
        ));
        Log.i('Paused background download for active streaming: ${task.title}');
      }
    });
  }

  void resumeDownloadsAfterStreaming() {
    for (final fileId in _pausedForStreamingFileIds) {
      final task = state[fileId];
      if (task != null && !task.isCompleted) {
        ref.read(tdlibServiceProvider).send(td.DownloadFile(
          fileId: fileId,
          priority: 10, // Resume at lower priority to avoid throttling active playback
          offset: 0,
          limit: 0,
          synchronous: false,
        ));
        Log.i('Resumed background download after streaming: ${task.title}');
      }
    }
    _pausedForStreamingFileIds.clear();
  }
}

final downloadControllerProvider = NotifierProvider<DownloadController, Map<int, DownloadTask>>(DownloadController.new);
