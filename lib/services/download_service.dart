import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'tdlib_service.dart';
import 'storage_service.dart';
import '../core/logger.dart';
import '../features/settings/settings_provider.dart';
import '../core/utils/path_helper.dart';

class DownloadTask {
  final int fileId;
  final int? messageId;
  final String title;
  final double progress;
  final String? localPath;
  final bool isCompleted;
  final double speedBytesPerSecond;
  final int etaSeconds;
  final bool isScheduled;
  final bool isPaused;
  final bool isQueued;

  DownloadTask({
    required this.fileId,
    this.messageId,
    required this.title,
    this.progress = 0.0,
    this.localPath,
    this.isCompleted = false,
    this.speedBytesPerSecond = 0.0,
    this.etaSeconds = 0,
    this.isScheduled = false,
    this.isPaused = false,
    this.isQueued = false,
  });

  DownloadTask copyWith({
    double? progress,
    String? localPath,
    bool? isCompleted,
    double? speedBytesPerSecond,
    int? etaSeconds,
    bool? isScheduled,
    bool? isPaused,
    bool? isQueued,
  }) {
    return DownloadTask(
      fileId: fileId,
      messageId: messageId,
      title: title,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      isCompleted: isCompleted ?? this.isCompleted,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      isScheduled: isScheduled ?? this.isScheduled,
      isPaused: isPaused ?? this.isPaused,
      isQueued: isQueued ?? this.isQueued,
    );
  }

  String get speedString {
    if (speedBytesPerSecond <= 0) return '0.0 KB/s';
    final kb = speedBytesPerSecond / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB/s';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB/s';
  }

  String get etaString {
    if (etaSeconds <= 0 || progress >= 1.0) return 'Calculating...';
    if (etaSeconds < 60) {
      return '${etaSeconds}s left';
    }
    final minutes = etaSeconds ~/ 60;
    final seconds = etaSeconds % 60;
    return '${minutes}m ${seconds}s left';
  }
}

class DownloadController extends Notifier<Map<int, DownloadTask>> {
  StreamSubscription? _subscription;
  StreamSubscription? _dirWatcherSubscription;
  StreamSubscription? _connectivitySubscription;
  static const _channel = MethodChannel('com.darkmatter.telstream/downloads');
  final Map<int, int> _lastNotificationTimes = {};
  final List<int> _pausedForStreamingFileIds = [];
  final Map<int, int> _lastDownloadedSizes = {};
  final Map<int, int> _lastUpdateTimes = {};
  Timer? _schedulerTimer;
  final Set<int> _pausedBySchedulerFileIds = {};

  Timer? _pwmTimer;
  int _pwmCycleElapsedMs = 0;
  final Map<int, int> _startDownloadedSize = {};
  final Map<int, bool> _isPwmPaused = {};
  final Map<int, int> _lastPwmUpdateSizes = {};

  @override
  Map<int, DownloadTask> build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _dirWatcherSubscription?.cancel();
      _schedulerTimer?.cancel();
      _connectivitySubscription?.cancel();
      _pwmTimer?.cancel();
    });
    _init();
    _setupConnectivityListener();
    
    if (Platform.isAndroid) {
      try {
        _channel.invokeMethod('updateDownloadNotification', {
          'fileId': -1,
          'title': 'Service running',
          'progress': 0.0,
          'isCompleted': false,
          'isCancelled': false,
          'isPaused': false,
        });
      } catch (_) {}
    }

    ref.listen<VideoSettings>(videoSettingsProvider, (previous, next) {
      if (previous?.downloadSpeedLimit != next.downloadSpeedLimit) {
        _updatePwmState();
      }
    });

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationAction') {
        final args = call.arguments as Map;
        final action = args['action'] as String;
        final fileId = args['fileId'] as int;
        if (action == 'pause') {
          await pauseDownload(fileId);
        } else if (action == 'resume') {
          await resumeDownload(fileId);
        } else if (action == 'cancel') {
          await cancelDownload(fileId);
        }
      }
    });

    return {};
  }

  Future<void> _updateNativeNotification(int fileId, String title, double progress, {bool isCompleted = false, bool isCancelled = false, bool isPaused = false}) async {
    if (!Platform.isAndroid) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastNotificationTimes[fileId] ?? 0;
    
    if (isCompleted || isCancelled || isPaused || progress == 0.0 || (now - lastTime) >= 800) {
      _lastNotificationTimes[fileId] = now;
      try {
        await _channel.invokeMethod('updateDownloadNotification', {
          'fileId': fileId,
          'title': title,
          'progress': progress,
          'isCompleted': isCompleted,
          'isCancelled': isCancelled,
          'isPaused': isPaused,
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
    final appDocDir = await getAppDirectory();
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

      // Load active (incomplete) downloads from storage
      final activeDownloads = storage.getActiveDownloads();
      final tdlibService = ref.read(tdlibServiceProvider);
      for (final entry in activeDownloads.entries) {
        final fileId = entry.key;
        final title = entry.value;
        
        loadedTasks[fileId] = DownloadTask(
          fileId: fileId,
          title: title,
          progress: 0.0,
          isCompleted: false,
        );

        // Resume download via TDLib
        tdlibService.send(td.DownloadFile(
          fileId: fileId,
          priority: 1,
          offset: 0,
          limit: 0,
          synchronous: false,
        ));
        Log.i('Resumed active queue download task: $title (ID: $fileId)');
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
    await _subscription?.cancel();
    final Set<int> _savingFileIds = {};
    _subscription = tdlibService.updates.listen((event) {
      if (event is td.UpdateFile) {
        final fileId = event.file.id;
        if (state.containsKey(fileId)) {
          final task = state[fileId]!;
          if (task.isCompleted) return; // Already finished and saved
          if (_savingFileIds.contains(fileId)) return;

          final expectedSize = event.file.expectedSize;
          final downloadedSize = event.file.local.downloadedSize;
          _lastPwmUpdateSizes[fileId] = downloadedSize;
          
          double progress = 0.0;
          if (expectedSize > 0) {
            progress = downloadedSize / expectedSize;
          }

          final isCompleted = event.file.local.isDownloadingCompleted;
          String? tempPath = event.file.local.path;

          if (isCompleted && tempPath.isNotEmpty) {
            _savingFileIds.add(fileId);
            _saveFilePermanently(fileId, tempPath, task.title).whenComplete(() {
              _savingFileIds.remove(fileId);
            });
            _lastDownloadedSizes.remove(fileId);
            _lastUpdateTimes.remove(fileId);
          } else {
            // Speed and ETA calculation
            final now = DateTime.now().millisecondsSinceEpoch;
            final lastSize = _lastDownloadedSizes[fileId];
            final lastTime = _lastUpdateTimes[fileId];
            
            double speed = 0.0;
            int eta = 0;
            
            if (lastSize != null && lastTime != null && now > lastTime) {
              final sizeDelta = downloadedSize - lastSize;
              final timeDeltaMs = now - lastTime;
              if (timeDeltaMs > 0 && sizeDelta >= 0) {
                speed = sizeDelta / (timeDeltaMs / 1000.0); // bytes/sec
                final remainingBytes = expectedSize - downloadedSize;
                eta = speed > 0 ? (remainingBytes / speed).round() : 0;
              }
            }
            
            // Only update speed tracking every 500ms to avoid noisy fluctuations
            if (lastTime == null || (now - lastTime) >= 500) {
              _lastDownloadedSizes[fileId] = downloadedSize;
              _lastUpdateTimes[fileId] = now;
            }

            state = {
              ...state,
              fileId: task.copyWith(
                progress: progress,
                isCompleted: false,
                speedBytesPerSecond: speed > 0 ? speed : task.speedBytesPerSecond,
                etaSeconds: eta > 0 ? eta : task.etaSeconds,
                isPaused: false,
              ),
            };
            _updateNativeNotification(fileId, task.title, progress, isPaused: false);
          }
        }
      }
    });
    _startSchedulerTimer();
    checkScheduler();
    _updatePwmState();
  }

  void _startSchedulerTimer() {
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkScheduler();
    });
  }

  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      if (hasConnection) {
        Log.i('Network connectivity restored: Auto-resuming active download queue.');
        resumeActiveQueueDownloads();
      }
    });
  }

  void resumeActiveQueueDownloads() {
    final tdlibService = ref.read(tdlibServiceProvider);
    final settings = ref.read(videoSettingsProvider);
    
    // Check scheduler window if scheduler is enabled
    bool schedulerAllows = true;
    if (settings.downloadSchedulerEnabled) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final start = settings.downloadStartHour;
      final end = settings.downloadEndHour;
      if (start < end) {
        schedulerAllows = currentHour >= start && currentHour < end;
      } else if (start > end) {
        schedulerAllows = currentHour >= start || currentHour < end;
      } else {
        schedulerAllows = true;
      }
    }
    
    if (!schedulerAllows) {
      Log.i('Connectivity auto-resume: skipped because scheduler window is inactive');
      return;
    }

    state.forEach((fileId, task) {
      if (!task.isCompleted && !task.isScheduled && !_pausedForStreamingFileIds.contains(fileId)) {
        tdlibService.send(td.DownloadFile(
          fileId: fileId,
          priority: 1,
          offset: 0,
          limit: 0,
          synchronous: false,
        ));
        Log.i('Connectivity auto-resume: re-triggered download for ${task.title} (ID: $fileId)');
      }
    });
    _updatePwmState();
  }

  void checkScheduler() {
    final settings = ref.read(videoSettingsProvider);
    if (!settings.downloadSchedulerEnabled) {
      if (_pausedBySchedulerFileIds.isNotEmpty) {
        final toResume = List<int>.from(_pausedBySchedulerFileIds);
        _pausedBySchedulerFileIds.clear();
        final Map<int, DownloadTask> updated = {...state};
        for (final fileId in toResume) {
          final task = state[fileId];
          if (task != null && !task.isCompleted) {
            updated[fileId] = task.copyWith(isScheduled: false);
            ref.read(tdlibServiceProvider).send(td.DownloadFile(
              fileId: fileId,
              priority: 1,
              offset: 0,
              limit: 0,
              synchronous: false,
            ));
            Log.i('Scheduler disabled: Resumed download: ${task.title}');
          }
        }
        state = updated;
      }
      _updatePwmState();
      return;
    }

    final now = DateTime.now();
    final currentHour = now.hour;
    final start = settings.downloadStartHour;
    final end = settings.downloadEndHour;

    bool isWithinWindow = false;
    if (start < end) {
      isWithinWindow = currentHour >= start && currentHour < end;
    } else if (start > end) {
      isWithinWindow = currentHour >= start || currentHour < end;
    } else {
      isWithinWindow = true;
    }

    if (isWithinWindow) {
      if (_pausedBySchedulerFileIds.isNotEmpty) {
        final toResume = List<int>.from(_pausedBySchedulerFileIds);
        _pausedBySchedulerFileIds.clear();
        final Map<int, DownloadTask> updated = {...state};
        for (final fileId in toResume) {
          final task = state[fileId];
          if (task != null && !task.isCompleted) {
            updated[fileId] = task.copyWith(isScheduled: false);
            ref.read(tdlibServiceProvider).send(td.DownloadFile(
              fileId: fileId,
              priority: 1,
              offset: 0,
              limit: 0,
              synchronous: false,
            ));
            Log.i('Inside scheduled window ($start:00 - $end:00): Resumed download: ${task.title}');
          }
        }
        state = updated;
      }
    } else {
      final Map<int, DownloadTask> updated = {...state};
      bool changed = false;
      state.forEach((fileId, task) {
        if (!task.isCompleted && !_pausedBySchedulerFileIds.contains(fileId)) {
          _pausedBySchedulerFileIds.add(fileId);
          updated[fileId] = task.copyWith(isScheduled: true);
          changed = true;
          ref.read(tdlibServiceProvider).send(td.CancelDownloadFile(
            fileId: fileId,
            onlyIfPending: false,
          ));
          Log.i('Outside scheduled window ($start:00 - $end:00): Paused download: ${task.title}');
        }
      });
      if (changed) {
        state = updated;
      }
    }
    _updatePwmState();
  }

  void _watchDirectory(Directory downloadsDir) {
    _dirWatcherSubscription?.cancel();
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    try {
      Timer? debounceTimer;
      _dirWatcherSubscription = downloadsDir.watch().listen((event) {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 500), () {
          _syncDownloadsWithDisk();
        });
      });
    } catch (e) {
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
      _updatePwmState();
    }
  }

  static const int _maxConcurrentDownloads = 3;

  int get _activeDownloadCount {
    return state.values.where((t) => !t.isCompleted && !t.isPaused && !t.isScheduled && !t.isQueued && !_pausedForStreamingFileIds.contains(t.fileId)).length;
  }

  void _processQueue() {
    int activeCount = _activeDownloadCount;
    if (activeCount < _maxConcurrentDownloads) {
      final queuedTasks = state.values.where((t) => t.isQueued && !t.isPaused && !t.isScheduled && !_pausedForStreamingFileIds.contains(t.fileId)).toList();
      if (queuedTasks.isNotEmpty) {
        final tasksToStart = queuedTasks.take(_maxConcurrentDownloads - activeCount).toList();
        final Map<int, DownloadTask> updated = {...state};
        
        for (final task in tasksToStart) {
          updated[task.fileId] = task.copyWith(isQueued: false);
          ref.read(tdlibServiceProvider).send(td.DownloadFile(
            fileId: task.fileId,
            priority: 1,
            offset: 0,
            limit: 0,
            synchronous: false,
          ));
          Log.i('Queue Manager: Started download for ${task.title}');
        }
        state = updated;
      }
    }
  }

  Future<void> startDownload(int fileId, String title, {int? messageId, int? chatId}) async {
    int finalFileId = fileId;

    if (messageId != null && chatId != null) {
      try {
        final tdlibService = ref.read(tdlibServiceProvider);
        final res = await tdlibService.sendAsync(td.GetMessage(
          chatId: chatId,
          messageId: messageId,
        )).timeout(const Duration(seconds: 4));
        
        if (res is td.Message) {
          int? freshFileId;
          if (res.content is td.MessageVideo) {
            freshFileId = (res.content as td.MessageVideo).video.video.id;
          } else if (res.content is td.MessageDocument) {
            freshFileId = (res.content as td.MessageDocument).document.document.id;
          }
          if (freshFileId != null && freshFileId != 0) {
            if (freshFileId != fileId) {
              Log.i('Resolved fresh file ID $freshFileId (was stale $fileId) for message $messageId');
              finalFileId = freshFileId;
            }
          }
        }
      } catch (e) {
        Log.w('Failed to resolve fresh file ID for download: $e');
      }
    }

    if (state.containsKey(finalFileId) && state[finalFileId]!.isCompleted) {
      return; // Already downloaded
    }

    final settings = ref.read(videoSettingsProvider);
    bool isScheduledNow = false;

    if (settings.downloadSchedulerEnabled) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final start = settings.downloadStartHour;
      final end = settings.downloadEndHour;

      bool isWithinWindow = false;
      if (start < end) {
        isWithinWindow = currentHour >= start && currentHour < end;
      } else if (start > end) {
        isWithinWindow = currentHour >= start || currentHour < end;
      } else {
        isWithinWindow = true;
      }

      if (!isWithinWindow) {
        isScheduledNow = true;
        _pausedBySchedulerFileIds.add(finalFileId);
        Log.i('Download scheduled for off-peak hours ($start:00 - $end:00): $title');
      }
    }

    // Register the task in memory
    bool willBeQueued = !isScheduledNow && _activeDownloadCount >= _maxConcurrentDownloads;

    state = {
      ...state,
      finalFileId: DownloadTask(
        fileId: finalFileId,
        messageId: messageId,
        title: title,
        isScheduled: isScheduledNow,
        isQueued: willBeQueued,
      ),
    };

    // Persist active download in queue database
    await ref.read(storageServiceProvider).addActiveDownload(finalFileId, title);

    // Notify native background download service to start
    _updateNativeNotification(finalFileId, title, 0.0);

    if (!isScheduledNow && !willBeQueued) {
      // Send TDLib DownloadFile command
      ref.read(tdlibServiceProvider).send(td.DownloadFile(
        fileId: finalFileId,
        priority: 1,
        offset: 0,
        limit: 0,
        synchronous: false,
      ));
    } else if (willBeQueued) {
      Log.i('Download queued (max concurrent reached): $title');
    }
    _updatePwmState();
  }

  Future<void> pauseDownload(int fileId) async {
    final task = state[fileId];
    if (task == null || task.isPaused) return;

    ref.read(tdlibServiceProvider).send(td.CancelDownloadFile(
      fileId: fileId,
      onlyIfPending: false,
    ));

    state = {
      ...state,
      fileId: task.copyWith(
        isPaused: true,
        speedBytesPerSecond: 0.0,
      ),
    };

    _updateNativeNotification(fileId, task.title, task.progress, isPaused: true);
    _updatePwmState();
    _processQueue();
  }

  Future<void> resumeDownload(int fileId) async {
    final task = state[fileId];
    if (task == null || !task.isPaused) return;

    bool willBeQueued = _activeDownloadCount >= _maxConcurrentDownloads;

    state = {
      ...state,
      fileId: task.copyWith(
        isPaused: false,
        isQueued: willBeQueued,
      ),
    };

    if (!willBeQueued) {
      ref.read(tdlibServiceProvider).send(td.DownloadFile(
        fileId: fileId,
        priority: 1,
        offset: 0,
        limit: 0,
        synchronous: false,
      ));
    } else {
      Log.i('Resumed download queued (max concurrent reached): ${task.title}');
    }

    _updateNativeNotification(fileId, task.title, task.progress, isPaused: false);
    _updatePwmState();
    _processQueue();
  }

  Future<void> cancelDownload(int fileId) async {
    final task = state[fileId];
    final title = task?.title ?? 'Download';
    
    _pausedBySchedulerFileIds.remove(fileId);
    _isPwmPaused.remove(fileId);
    _startDownloadedSize.remove(fileId);
    _lastPwmUpdateSizes.remove(fileId);
    
    // Remove active download from persistent queue database
    await ref.read(storageServiceProvider).removeActiveDownload(fileId);
    
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
    _updatePwmState();
    _processQueue();
  }

  Future<void> _saveFilePermanently(int fileId, String tempPath, String title) async {
    try {
      _pausedBySchedulerFileIds.remove(fileId);
      _isPwmPaused.remove(fileId);
      _startDownloadedSize.remove(fileId);
      _lastPwmUpdateSizes.remove(fileId);
      
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
      final partPath = '$permanentPath.part';

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        final tempSize = await tempFile.length();
        if (tempSize <= 0) {
          throw Exception("Temp file size is 0 bytes");
        }
        
        // Use Dart Streams for chunked copy to avoid blocking the main isolate
        // and allow the OS to optimize the file IO.
        final sink = File(partPath).openWrite();
        int totalRead = 0;
        try {
          await for (final chunk in tempFile.openRead()) {
            sink.add(chunk);
            totalRead += chunk.length;
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        
        if (totalRead != tempSize) {
          throw Exception("Copied file size ($totalRead bytes) does not match original size ($tempSize bytes)");
        }
        
        final permFile = await File(partPath).rename(permanentPath);
        
        try {
          await tempFile.delete();
          Log.i('Cleaned up TDLib temp download cache file: $tempPath');
        } catch (e) {
          Log.w('Failed to delete temp cache file: $tempPath. Error: $e');
        }
        
        Log.i('FILE SAVED PERMANENTLY: $permanentPath');
        
        // Remove from active queue database and save persistent mapping in JSON storage
        await ref.read(storageServiceProvider).removeActiveDownload(fileId);
        await ref.read(storageServiceProvider).addDownloadedFile(fileId, permanentPath);
      } else {
        throw Exception("Temp file does not exist at $tempPath");
      }

      if (state.containsKey(fileId)) {
        state = {
          ...state,
          fileId: state[fileId]!.copyWith(
            progress: 1.0,
            isCompleted: true,
            localPath: permanentPath,
            isScheduled: false,
          ),
        };
      }

      // Notify native background download service of success
      _updateNativeNotification(fileId, title, 1.0, isCompleted: true);
      _updatePwmState();
      _processQueue();

    } catch (e, stackTrace) {
      Log.e('FAILED TO SAVE FILE PERMANENTLY', e, stackTrace);
      _updateNativeNotification(fileId, title, 0.0, isCancelled: true);
      _updatePwmState();
    }
  }

  void pauseDownloadsForStreaming() {
    _pausedForStreamingFileIds.clear();
    final Map<int, DownloadTask> updated = {...state};
    state.forEach((fileId, task) {
      if (!task.isCompleted) {
        _pausedForStreamingFileIds.add(fileId);
        updated[fileId] = task.copyWith(isPaused: true, speedBytesPerSecond: 0.0);
        ref.read(tdlibServiceProvider).send(td.CancelDownloadFile(
          fileId: fileId,
          onlyIfPending: false,
        ));
        Log.i('Paused background download for active streaming: ${task.title}');
      }
    });
    state = updated;
    _updatePwmState();
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
    _updatePwmState();
  }

  Future<void> deleteDownloadedFile(int fileId) async {
    final storage = ref.read(storageServiceProvider);
    final downloadedFiles = storage.getDownloadedFiles();
    final path = downloadedFiles[fileId];
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          Log.i('Deleted downloaded file: $path');
        }
      } catch (e, stack) {
        Log.e('Error deleting downloaded file: $path', e, stack);
      }
      
      _isPwmPaused.remove(fileId);
      _startDownloadedSize.remove(fileId);
      _lastPwmUpdateSizes.remove(fileId);
      _pausedBySchedulerFileIds.remove(fileId);

      await storage.removeDownloadedFile(fileId);
      state = {...state}..remove(fileId);
      _updatePwmState();
    }
  }

  int? parseSpeedLimitForTesting(String limit) => _parseSpeedLimit(limit);

  int? _parseSpeedLimit(String limit) {
    if (limit == 'Unlimited') return null;
    final match = RegExp(r'^(\d+)\s*(KB|MB)/s$').firstMatch(limit);
    if (match != null) {
      final value = int.parse(match.group(1)!);
      final unit = match.group(2)!;
      if (unit == 'KB') {
        return value * 1024;
      } else if (unit == 'MB') {
        return value * 1024 * 1024;
      }
    }
    return null;
  }

  bool _pwmTickInProgress = false;

  void _onPwmTick() {
    if (_pwmTickInProgress) return;
    _pwmTickInProgress = true;
    try {
      final settings = ref.read(videoSettingsProvider);
      final limitBytesPerSec = _parseSpeedLimit(settings.downloadSpeedLimit);
      if (limitBytesPerSec == null) {
        _stopPwm();
        return;
      }

      _pwmCycleElapsedMs += 500;
      final isNewCycle = _pwmCycleElapsedMs >= 1000;
      if (isNewCycle) {
        _pwmCycleElapsedMs = 0;
      }

    final tdlib = ref.read(tdlibServiceProvider);

    final activeRunningTasks = state.entries.where((entry) {
      final task = entry.value;
      return !task.isCompleted &&
             !task.isScheduled &&
             !_pausedForStreamingFileIds.contains(entry.key);
    }).toList();

    if (activeRunningTasks.isEmpty) {
      return;
    }

    final limitPerFile = limitBytesPerSec ~/ activeRunningTasks.length;

    for (final entry in activeRunningTasks) {
      final fileId = entry.key;
      final task = entry.value;

      final currentSize = _lastPwmUpdateSizes[fileId] ?? 0;

      if (isNewCycle) {
        _startDownloadedSize[fileId] = currentSize;
        if (_isPwmPaused[fileId] == true) {
          _isPwmPaused[fileId] = false;
          tdlib.send(td.DownloadFile(
            fileId: fileId,
            priority: 1,
            offset: 0,
            limit: 0,
            synchronous: false,
          ));
          Log.d('PWM Cycle Start: Resumed download for ${task.title}');
        }
      } else {
        final startSize = _startDownloadedSize[fileId] ?? currentSize;
        final downloadedInCycle = currentSize - startSize;

        if (downloadedInCycle >= limitPerFile && _isPwmPaused[fileId] != true) {
          _isPwmPaused[fileId] = true;
          tdlib.send(td.CancelDownloadFile(
            fileId: fileId,
            onlyIfPending: false,
          ));
          Log.d('PWM Cycle Limit Reached ($downloadedInCycle >= $limitPerFile bytes): Paused download for ${task.title}');
        }
      }
    }
    } finally {
      _pwmTickInProgress = false;
    }
  }

  void _stopPwm() {
    _pwmTimer?.cancel();
    _pwmTimer = null;
    _pwmCycleElapsedMs = 0;

    final tdlib = ref.read(tdlibServiceProvider);
    _isPwmPaused.forEach((fileId, isPaused) {
      if (isPaused) {
        final task = state[fileId];
        if (task != null && !task.isCompleted && !task.isScheduled && !_pausedForStreamingFileIds.contains(fileId)) {
          tdlib.send(td.DownloadFile(
            fileId: fileId,
            priority: 1,
            offset: 0,
            limit: 0,
            synchronous: false,
          ));
          Log.i('PWM Disabled: Resumed download for ${task.title}');
        }
      }
    });
    _isPwmPaused.clear();
    _startDownloadedSize.clear();
  }

  void _updatePwmState() {
    final settings = ref.read(videoSettingsProvider);
    final limit = _parseSpeedLimit(settings.downloadSpeedLimit);

    if (limit == null) {
      _stopPwm();
      return;
    }

    final hasActiveIncomplete = state.entries.any((entry) {
      final task = entry.value;
      return !task.isCompleted &&
             !task.isScheduled &&
             !_pausedForStreamingFileIds.contains(entry.key);
    });

    if (hasActiveIncomplete) {
      if (_pwmTimer == null) {
        _pwmTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
          _onPwmTick();
        });
        Log.i('PWM Speed Limiter started with limit: ${settings.downloadSpeedLimit}');
      }
    } else {
      if (_pwmTimer != null) {
        _stopPwm();
      }
    }
  }

  Future<void> reorderActiveDownloads(int oldIndex, int newIndex) async {
    final storage = ref.read(storageServiceProvider);
    final activeDownloads = state.entries.where((entry) => !entry.value.isCompleted).toList();
    final activeDownloadsOrder = storage.getActiveDownloadsOrder();

    final List<int> currentOrder = [];
    for (final fid in activeDownloadsOrder) {
      if (state.containsKey(fid) && !state[fid]!.isCompleted) {
        currentOrder.add(fid);
      }
    }
    for (final entry in activeDownloads) {
      if (!currentOrder.contains(entry.key)) {
        currentOrder.add(entry.key);
      }
    }

    if (oldIndex < currentOrder.length && newIndex < currentOrder.length) {
      final item = currentOrder.removeAt(oldIndex);
      currentOrder.insert(newIndex, item);
      await storage.setActiveDownloadsOrder(currentOrder);
      
      final tdlib = ref.read(tdlibServiceProvider);
      for (int i = 0; i < currentOrder.length; i++) {
        final fileId = currentOrder[i];
        final priority = (32 - i).clamp(1, 32);
        tdlib.send(td.DownloadFile(
          fileId: fileId,
          priority: priority,
          offset: 0,
          limit: 0,
          synchronous: false,
        ));
        Log.i('Adjusted TDLib download priority for fileId $fileId to $priority');
      }
      
      state = {...state};
    }
  }
}

final downloadControllerProvider = NotifierProvider<DownloadController, Map<int, DownloadTask>>(DownloadController.new);

