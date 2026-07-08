import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../settings/settings_provider.dart';
import 'pip_manager.dart';
import 'custom_video_controls.dart';
import '../../core/logger.dart';
import '../../core/constants.dart';
import '../../services/streaming_proxy_service.dart';
import '../../services/tracker_service.dart';
import 'package:window_manager/window_manager.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final int messageId;
  final int videoFileId;
  final String videoTitle;
  final List<td.Message>? episodeList;
  final int? currentEpisodeIndex;
  final String seriesName;
  final bool isPip;
  final String? networkUrl;
  
  const VideoPlayerScreen({
    super.key, 
    required this.messageId, 
    required this.videoFileId, 
    this.videoTitle = '',
    this.episodeList,
    this.currentEpisodeIndex,
    this.seriesName = '',
    this.isPip = false,
    this.networkUrl,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> with WidgetsBindingObserver {
  late Player player;
  late VideoController controller;
  StreamSubscription? _updatesSubscription;
  bool _isPlaying = false;
  int _downloadedPrefixSize = 0;
  int _expectedSize = 0;
  int _activeDownloadOffset = 0;
  int _activeDownloadedSize = 0;
  int _initialOffset = 0;
  int? _initialDownloadedSize;
  Duration? _pendingSeekTarget;
  bool _isBuffering = false;
  int? _resolvedVideoFileId;
  bool _isInitializing = true;
  bool _initialTrackSelectionDone = false;

  final List<StreamSubscription> _subscriptions = [];
  Timer? _saveTimer;
  bool _nextEpisodePreloaded = false;
  Timer? _preloadCooldownTimer;
  bool _hasUpdatedTracker = false;

  late final StorageService _storageService;
  late final TdlibService _tdlibService;
  late final PipController _pipController;
  late VideoSettings _settings;
  late final StreamingProxyService _proxyService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _storageService = ref.read(storageServiceProvider);
    _tdlibService = ref.read(tdlibServiceProvider);
    _pipController = ref.read(pipControllerProvider.notifier);
    _settings = ref.read(videoSettingsProvider);
    _proxyService = ref.read(streamingProxyServiceProvider);
    


    _initPlayerInstance();
    _setupPlayerListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pipController.isTransitioning = false;
    });
    
    _initDownload();
    
    if (!widget.isPip) {
      _setLandscapeOrientationAndUI();
    } else {
      _resetOrientationAndUI();
    }

    // Pause other downloads while streaming to maximize bandwidth
    Future.microtask(() {
      if (mounted) {
        ref.read(downloadControllerProvider.notifier).pauseDownloadsForStreaming();
      }
    });

    // Periodic Save for Continue Watching
    if (widget.seriesName.isNotEmpty && widget.currentEpisodeIndex != null) {
      Future.microtask(() {
        if (mounted) {
          ref.read(lastWatchedProvider.notifier).updateLastWatched(
            widget.seriesName,
            widget.messageId,
            widget.currentEpisodeIndex!,
          );
        }
      });
    }

    _saveTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_settings.savePositionOnQuit && player.state.position.inSeconds > 0 && player.state.playing) {
        _storageService.saveWatchPosition(widget.messageId, player.state.position.inSeconds);
        if (player.state.duration.inSeconds > 0) {
          _storageService.saveVideoDuration(widget.messageId, player.state.duration.inSeconds);
        }
        if (!_storageService.isIncognitoMode() && widget.seriesName.isNotEmpty && widget.currentEpisodeIndex != null) {
          ref.read(historyLogProvider.notifier).addToHistory(
            seriesName: widget.seriesName,
            messageId: widget.messageId,
            episodeIndex: widget.currentEpisodeIndex!,
            episodeTitle: widget.videoTitle.replaceFirst('${widget.seriesName} - ', ''),
            positionInSeconds: player.state.position.inSeconds,
            videoFileId: _resolvedVideoFileId ?? widget.videoFileId,
          );
        }
      }

      // Check and trigger tracker watch progress syncing if progress >= 80%
      if (!_hasUpdatedTracker && player.state.duration.inSeconds > 0) {
        final position = player.state.position.inSeconds;
        final duration = player.state.duration.inSeconds;
        final progress = position / duration;
        if (progress >= 0.8) {
          _hasUpdatedTracker = true;
          _syncProgressToTrackers();
        }
      }
    });
  }

  void _setLandscapeOrientationAndUI() {
    try {
      try {
        WakelockPlus.enable();
      } catch (_) {}
      if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void didUpdateWidget(VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPip && !oldWidget.isPip) {
      _resetOrientationAndUI();
    }
    if (widget.messageId != oldWidget.messageId) {
      // Episode changed on Desktop (reusing player)
      player.stop().then((_) {
        if (mounted) {
          setState(() {
            _isInitializing = true;
            _isPlaying = false;
            _downloadedPrefixSize = 0;
            _expectedSize = 0;
          });
          _initDownload();
        }
      });
    }
  }

  void _resetOrientationAndUI() {
    try {
      if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (e) {
      // ignore
    }
  }

  void _playNextEpisode() {
    final pipState = ref.read(pipControllerProvider);
    if (pipState != null && pipState.currentIndex + 1 < pipState.queue.length) {
      ref.read(pipControllerProvider.notifier).playQueueIndex(context, pipState.currentIndex + 1);
    }
  }

  void _playPreviousEpisode() {
    final pipState = ref.read(pipControllerProvider);
    if (pipState != null && pipState.currentIndex > 0) {
      ref.read(pipControllerProvider.notifier).playQueueIndex(context, pipState.currentIndex - 1);
    }
  }

  DateTime? _lastUpdateTime;

  Future<void> _startPlayback(String localPath) async {
    if (_isPlaying) return;
    _isPlaying = true;

    String finalPath = localPath;
    if (localPath.startsWith('http://127.0.0.1')) {
      try {
        await _proxyService.onReady.timeout(const Duration(seconds: 3));
      } catch (e) {
        Log.w('Proxy service ready await timed out or failed: $e');
      }
      finalPath = _proxyService.getProxyUrl(
        _resolvedVideoFileId ?? widget.videoFileId,
        fileName: widget.videoTitle,
      );
    }

    final savedPos = _storageService.getWatchPosition(widget.messageId);
    final shouldPlayImmediately = savedPos <= 0;

    final proxyHeaders = finalPath.startsWith('http://127.0.0.1') ? _proxyService.getAuthHeaders() : null;
    player.open(Media(finalPath, httpHeaders: proxyHeaders), play: shouldPlayImmediately).then((_) {
      if (!mounted) return;
      if (savedPos > 0) {
        Future<void> performRobustStartupSeek() async {
          for (int i = 0; i < 5; i++) {
            if (!mounted) return;
            await player.seek(Duration(seconds: savedPos));
            await Future.delayed(Duration(milliseconds: 300 + (i * 200)));
            if (!mounted) return;
            final currentPos = player.state.position.inSeconds;
            if (currentPos > 0 && (currentPos - savedPos).abs() <= 5) {
              Log.i('Robust startup seek successful at attempt ${i + 1}');
              break;
            }
            Log.w('Playback startup seek failed. Retrying seek to $savedPos (Attempt ${i + 1})');
          }
          if (mounted) {
            player.play();
            setState(() {
              _isInitializing = false;
            });
          }
        }

        if (player.state.duration.inSeconds > 0) {
          performRobustStartupSeek();
        } else {
          late final StreamSubscription<Duration> durSub;
          durSub = player.stream.duration.listen((dur) {
            if (dur.inSeconds > 0) {
              durSub.cancel();
              _subscriptions.remove(durSub);
              if (mounted) {
                performRobustStartupSeek();
              }
            }
          });
          _subscriptions.add(durSub);
        }
      } else {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    });
    player.setVolume(100.0);
  }

  void _listenToUpdates() {
    _updatesSubscription?.cancel();
    _updatesSubscription = _tdlibService.updates.listen((event) {
      if (event is td.UpdateFile && event.file.id == _resolvedVideoFileId) {
        final localPath = event.file.local.path;
        
        final now = DateTime.now();
        if (_lastUpdateTime == null || now.difference(_lastUpdateTime!).inMilliseconds > 500 || event.file.local.isDownloadingCompleted) {
          _lastUpdateTime = now;
          if (mounted) {
            setState(() {
              _downloadedPrefixSize = event.file.local.downloadedPrefixSize;
              _expectedSize = event.file.expectedSize;
              _activeDownloadOffset = _proxyService.getActiveDownloadOffset(_resolvedVideoFileId!);
              final baseDownloaded = _proxyService.getDownloadedSizeAtOffset(_resolvedVideoFileId!);
              _activeDownloadedSize = (event.file.local.downloadedSize - baseDownloaded).clamp(0, event.file.expectedSize);
            });
          }
        }

        if (event.file.local.isDownloadingCompleted) {
          // Boost buffer sizes since the file is completely downloaded
          try {
            if (player.platform is NativePlayer) {
              final nativePlayer = player.platform as NativePlayer;
              nativePlayer.setProperty('demuxer-max-bytes', '524288000'); // 500 MB buffer
              nativePlayer.setProperty('demuxer-max-back-bytes', '157286400'); // 150 MB back buffer
              nativePlayer.setProperty('demuxer-readahead-secs', '180');
            }
          } catch (_) {}

          if (!_nextEpisodePreloaded) {
            _nextEpisodePreloaded = true;
            _preloadNextEpisode();
          }
        }

        // If we are actively seeking, capture the start downloaded size
        if (_isPlaying && _pendingSeekTarget != null) {
          _initialDownloadedSize ??= event.file.local.downloadedSize;
        }

        if (localPath.isNotEmpty && !_isPlaying) {
          if (event.file.local.isDownloadingCompleted) {
            Log.i('Proxy playback fallback: playing cached completed file path: $localPath');
            _startPlayback(localPath);
          } else {
            Log.i('Proxy playback active: routing streaming through loopback server');
            _proxyService.setDownloadOffset(_resolvedVideoFileId!, _initialOffset, event.file.local.downloadedSize);
            final proxyUrl = _proxyService.getProxyUrl(_resolvedVideoFileId!, fileName: widget.videoTitle);
            _startPlayback(proxyUrl);
          }
        }

        // Handle mid-play seek buffering updates
        if (_isPlaying && _pendingSeekTarget != null && _initialDownloadedSize != null) {
          final totalSize = event.file.expectedSize;
          final targetBuffer = (totalSize * 0.01).clamp(524288, 2097152); // Optimized: 512KB to 2MB buffer
          final downloadedDelta = event.file.local.downloadedSize - _initialDownloadedSize!;
          
          if (event.file.local.isDownloadingCompleted || downloadedDelta >= targetBuffer) {
            final seekTarget = _pendingSeekTarget!;
            _pendingSeekTarget = null;
            if (mounted) {
              setState(() {
                _isBuffering = false;
              });
            }
            player.seek(seekTarget).then((_) {
              player.play();
            });
          }
        }
      }
    });
  }

  Future<void> _initDownload() async {
    if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _resolvedVideoFileId = widget.videoFileId;
          _isPlaying = true;
          _isInitializing = false;
        });
      }
      player.open(Media(widget.networkUrl!), play: true);
      player.setVolume(100.0);
      return;
    }

    _resolvedVideoFileId = widget.videoFileId;

    // Pre-emptively resolve the fresh file ID from TDLib to prevent stale file ID errors
    Log.i('Resolving fresh file ID for message ${widget.messageId}...');
    int? freshFileId;
    for (final category in Constants.categories) {
      try {
        final res = await _tdlibService.sendAsync(td.GetMessage(
          chatId: category.channelId,
          messageId: widget.messageId,
        )).timeout(const Duration(seconds: 3));
        
        if (res is td.Message) {
          if (res.content is td.MessageVideo) {
            freshFileId = (res.content as td.MessageVideo).video.video.id;
          } else if (res.content is td.MessageDocument) {
            freshFileId = (res.content as td.MessageDocument).document.document.id;
          }
          if (freshFileId != null && freshFileId != 0) {
            Log.i('Successfully resolved fresh file ID $freshFileId (previous was $_resolvedVideoFileId) for message ${widget.messageId} in category ${category.title}');
            break;
          }
        }
      } catch (e) {
        Log.w('Failed to check category ${category.title} for message ${widget.messageId}: $e');
      }
    }

    if (freshFileId != null && freshFileId != 0) {
      _resolvedVideoFileId = freshFileId;
    }

    if (widget.seriesName.isNotEmpty && _resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      _storageService.associateFileWithSeries(widget.seriesName, _resolvedVideoFileId!);
    }

    final savedPos = _storageService.getWatchPosition(widget.messageId);
    if (mounted && savedPos <= 0) {
      setState(() {
        _isInitializing = false;
      });
    }

    // Start listening to updates immediately to catch progress and local path updates
    _listenToUpdates();

    td.File? initialFileState;
    // Check if the file is already cached locally (fully or partially)
    if (_resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      try {
        final res = await _tdlibService.sendAsync(td.GetFile(fileId: _resolvedVideoFileId!))
            .timeout(const Duration(seconds: 3));
        if (res is td.File) {
          initialFileState = res;
          if (mounted) {
            setState(() {
              _downloadedPrefixSize = res.local.downloadedPrefixSize;
              _expectedSize = res.expectedSize;
            });
          }

          // If the file is completed but path is empty, trigger a quick DownloadFile to force TDLib to resolve the path
          if (res.local.isDownloadingCompleted && res.local.path.isEmpty) {
            _tdlibService.send(td.DownloadFile(
              fileId: _resolvedVideoFileId!,
              priority: 1,
              offset: 0,
              limit: 0,
              synchronous: false,
            ));
            
            // Wait up to 1.5 seconds for the path to resolve
            for (int i = 0; i < 15; i++) {
              await Future.delayed(const Duration(milliseconds: 100));
              final fresh = await _tdlibService.sendAsync(td.GetFile(fileId: _resolvedVideoFileId!));
              if (fresh is td.File && fresh.local.path.isNotEmpty) {
                initialFileState = fresh;
                break;
              }
            }
          }
        }
      } catch (e) {
        Log.w('Failed fast local GetFile check: $e');
      }
    }

    // Trigger download with highest priority immediately. This ensures TDLib pre-allocates
    // the local file path so that subsequent GetFile queries retrieve it instantly.
    if (_resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      int initialOffset = 0;
      final savedPos = _storageService.getWatchPosition(widget.messageId);
      if (savedPos > 0) {
        final totalDuration = _storageService.getVideoDuration(widget.messageId);
        final expectedSize = initialFileState?.expectedSize ?? 0;
        if (totalDuration > 0 && expectedSize > 0) {
          final fraction = savedPos / totalDuration;
          initialOffset = (fraction * expectedSize).round();
          // Apply a 1MB lookbehind grace buffer for the initial seek offset
          const graceBuffer = 1 * 1024 * 1024;
          initialOffset = (initialOffset - graceBuffer).clamp(0, expectedSize);
        }
      }
      _initialOffset = initialOffset;

      if (initialOffset > 0) {
        _proxyService.setDownloadOffset(_resolvedVideoFileId!, initialOffset, initialFileState?.local.downloadedSize ?? 0);
      }

      _tdlibService.send(td.DownloadFile(
        fileId: _resolvedVideoFileId!,
        priority: 1,
        offset: initialOffset,
        limit: 0,
        synchronous: false,
      ));
    }

    // Play now using the resolved file state (completed file, active download via proxy, or pre-emptively via proxy)
    if (_resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      final cachedFile = _proxyService.getCachedFile(_resolvedVideoFileId!) ?? initialFileState;
      if (cachedFile != null && cachedFile.local.path.isNotEmpty) {
        final localPath = cachedFile.local.path;
        if (cachedFile.local.isDownloadingCompleted) {
          Log.i('Instant playback: playing cached completed file path: $localPath');
          _startPlayback(localPath);
          if (!_nextEpisodePreloaded) {
            _nextEpisodePreloaded = true;
            _preloadNextEpisode();
          }
        } else {
          Log.i('Instant playback: streaming active download via proxy: $localPath');
          _proxyService.setDownloadOffset(_resolvedVideoFileId!, _initialOffset, cachedFile.local.downloadedSize);
          final proxyUrl = _proxyService.getProxyUrl(_resolvedVideoFileId!, fileName: widget.videoTitle);
          _startPlayback(proxyUrl);
        }
      } else {
        // Fallback: start playback via proxy immediately even if path isn't allocated on disk yet
        Log.i('Pre-emptive playback fallback: starting proxy streaming immediately for fileId: $_resolvedVideoFileId');
        _proxyService.setDownloadOffset(_resolvedVideoFileId!, _initialOffset, cachedFile?.local.downloadedSize ?? 0);
        final proxyUrl = _proxyService.getProxyUrl(_resolvedVideoFileId!, fileName: widget.videoTitle);
        _startPlayback(proxyUrl);
      }
    }
  }

  void _handleCustomSeek(Duration position) {
    if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
      player.seek(position);
      return;
    }

    int totalDuration = player.state.duration.inSeconds;
    if (totalDuration <= 0) {
      totalDuration = _storageService.getVideoDuration(widget.messageId);
    }
    final expectedSize = _expectedSize;

    if (totalDuration > 0 && expectedSize > 0) {
      // Calculate corresponding byte offset
      final fraction = position.inSeconds / totalDuration;
      int byteOffset = (fraction * expectedSize).round();

      // Check if file is fully downloaded or if target offset is within already-downloaded prefix
      final isCompleted = _downloadedPrefixSize >= expectedSize;
      final fileId = _resolvedVideoFileId ?? widget.videoFileId;
      final isWithinDownloadedRange = _proxyService.isRangeDownloaded(fileId, byteOffset, byteOffset + 2 * 1024 * 1024);

      // If the target byteOffset is already close to the active download pointer (e.g. within 8MB),
      // we don't need to restart the download or shift offsets.
      final activeOffset = _proxyService.getActiveDownloadOffset(fileId);
      final isNearActiveOffset = byteOffset >= activeOffset && byteOffset <= activeOffset + 8 * 1024 * 1024;

      if (isCompleted || isWithinDownloadedRange || isNearActiveOffset) {
        player.seek(position);
        return;
      }

      if (byteOffset >= expectedSize - 2097152) {
        byteOffset = (expectedSize - 2097152).clamp(0, expectedSize);
      }

      // Initiate pause-buffer-play seek cycle
      player.pause();
      if (mounted) {
        setState(() {
          _isBuffering = true;
          _initialDownloadedSize = null; // Will trigger re-init in updates listener
          _pendingSeekTarget = position;
        });
      }

      const graceBuffer = 1 * 1024 * 1024; // 1 MB lookbehind buffer to align with proxy and keyframe seek queries
      final shiftOffset = (byteOffset - graceBuffer).clamp(0, expectedSize);

      // Update download offset in TDLib and Proxy synchronously to avoid race conditions
      final cachedFile = _proxyService.getCachedFile(fileId);
      _proxyService.setDownloadOffset(fileId, shiftOffset, cachedFile?.local.downloadedSize ?? 0);

      _tdlibService.send(td.DownloadFile(
        fileId: fileId,
        priority: 1,
        offset: shiftOffset,
        limit: 0,
        synchronous: false,
      ));
      Log.i('Seeking TDLib download to offset: $shiftOffset bytes (original target: $byteOffset bytes, position: $position)');
    } else {
      player.seek(position);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      try {
        player.pause();
      } catch (e, st) {
        Log.e('player.pause() in lifecycle pause failed', e, st);
      }
    }
  }

  @override
  void dispose() {
    if (!widget.isPip) {
      WakelockPlus.disable();
    }
    _cancelPreloadOfNextEpisode();
    WidgetsBinding.instance.removeObserver(this);
    // Redundant pause/stop removed to prevent race conditions during player disposal

    _updatesSubscription?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _saveTimer?.cancel();
    _preloadCooldownTimer?.cancel();
    
    try {
      final position = player.state.position.inSeconds;
      if (position > 0 && _settings.savePositionOnQuit) {
        _storageService.saveWatchPosition(widget.messageId, position);
        if (player.state.duration.inSeconds > 0) {
          _storageService.saveVideoDuration(widget.messageId, player.state.duration.inSeconds);
        }
        if (!_storageService.isIncognitoMode() && widget.seriesName.isNotEmpty && widget.currentEpisodeIndex != null) {
          ref.read(historyLogProvider.notifier).addToHistory(
            seriesName: widget.seriesName,
            messageId: widget.messageId,
            episodeIndex: widget.currentEpisodeIndex!,
            episodeTitle: widget.videoTitle.replaceFirst('${widget.seriesName} - ', ''),
            positionInSeconds: position,
            videoFileId: _resolvedVideoFileId ?? widget.videoFileId,
          );
        }
      }
    } catch (e, st) {
      Log.e('Failed to save watch position on dispose', e, st);
    }

    // Resume any downloads that were paused for streaming
    try {
      ref.read(downloadControllerProvider.notifier).resumeDownloadsAfterStreaming();
    } catch (e, st) {
      Log.e('Failed to resume downloads after streaming', e, st);
    }

    // Silence, pause, and stop the player immediately to halt all decoding and audio output
    try {
      player.setVolume(0.0);
    } catch (e) {}
    try {
      player.pause();
    } catch (e) {}
    try {
      player.stop();
    } catch (e) {}

    // Reset PipController active state first. If this player is the active player,
    // we call close() to clean up the state and set activePlayer to null.
    final isActive = _pipController.activePlayer == player;
    if (isActive) {
      _pipController.close();
    }

    try {
      if (_pipController.activePlayer == null) {
        _resetOrientationAndUI();
      }
    } catch (_) {}

    final playerToDispose = player;
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        playerToDispose.dispose();
      } catch (e, st) {
        Log.e('Failed to dispose Player', e, st);
      }
    });

    try {
      final fileId = _resolvedVideoFileId ?? widget.videoFileId;
      if (widget.networkUrl == null && fileId != 0) {
        final activeDownloads = ref.read(downloadControllerProvider);
        final isDownloadingPermanently = activeDownloads.containsKey(fileId);
        final pipState = ref.read(pipControllerProvider);
        final isCurrentlyPlaying = pipState != null && pipState.videoFileId == fileId;
        
        if (!isDownloadingPermanently && !isCurrentlyPlaying) {
          _tdlibService.send(td.CancelDownloadFile(fileId: fileId, onlyIfPending: false));
          Log.i('Cancelled background download for inactive file $fileId on dispose');
        } else {
          Log.i('Skipped CancelDownloadFile on dispose: file $fileId is still active (downloading permanently: $isDownloadingPermanently, playing: $isCurrentlyPlaying)');
        }
      }
    } catch (e, st) {
      Log.e('Failed to cancel active downloads on dispose', e, st);
    }
    
    super.dispose();
  }

  void _preloadNextEpisode() {
    final pipState = ref.read(pipControllerProvider);
    if (pipState == null) return;
    final nextIndex = pipState.currentIndex + 1;
    if (nextIndex >= pipState.queue.length) return;

    final nextItem = pipState.queue[nextIndex];
    final nextFileId = nextItem.videoFileId;

    if (nextFileId != 0) {
      Log.i('Preloading next episode (ID: $nextFileId) - downloading entire file');
      _tdlibService.send(td.DownloadFile(
        fileId: nextFileId,
        priority: 1, // Low priority for background preloading
        offset: 0,
        limit: 0, // 0 means unlimited / entire file
        synchronous: false,
      ));
    }
  }

  void _cancelPreloadOfNextEpisode() {
    final pipState = ref.read(pipControllerProvider);
    if (pipState == null) return;
    final nextIndex = pipState.currentIndex + 1;
    if (nextIndex >= pipState.queue.length) return;

    final nextItem = pipState.queue[nextIndex];
    final nextFileId = nextItem.videoFileId;

    if (nextFileId != 0) {
      Log.i('Playback buffered: Cancelling next episode background preload (ID: $nextFileId)');
      _tdlibService.send(td.CancelDownloadFile(
        fileId: nextFileId,
        onlyIfPending: false,
      ));
      
      // Start a 2-minute cooldown before resetting preloading status to protect against infinite buffering-preloading loops
      _preloadCooldownTimer?.cancel();
      _preloadCooldownTimer = Timer(const Duration(minutes: 2), () {
        if (mounted) {
          Log.i('Preloading cooldown complete. Resetting _nextEpisodePreloaded flag.');
          _nextEpisodePreloaded = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipState = ref.watch(pipControllerProvider);

    ref.listen<VideoSettings>(videoSettingsProvider, (previous, next) {
      bool needAudioFilterUpdate = false;
      bool needSubUpdate = false;
      if (previous?.subtitleRendererMode != next.subtitleRendererMode) {
        _settings = next;
        _recreatePlayer();
      }
      if (previous?.dynamicRangeCompression != next.dynamicRangeCompression ||
          previous?.equalizerEnabled != next.equalizerEnabled ||
          previous?.equalizerBands != next.equalizerBands) {
        _settings = next;
        needAudioFilterUpdate = true;
      }
      if (previous?.subtitleFontSize != next.subtitleFontSize ||
          previous?.subtitleColor != next.subtitleColor ||
          previous?.subtitleDelay != next.subtitleDelay ||
          previous?.subtitleFont != next.subtitleFont) {
        _settings = next;
        needSubUpdate = true;
      }
      if (needAudioFilterUpdate) {
        _updateAudioFilters();
      }
      if (needSubUpdate) {
        _updateSubtitleProperties();
      }
    });

    final isDesktop = Platform.isWindows;

    Widget scaffold = Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
                if (player.state.playing) {
                  player.pause();
                } else {
                  player.play();
                }
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
                final seekTarget = player.state.position + Duration(seconds: _settings.doubleTapSeekDuration);
                _handleCustomSeek(seekTarget);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
                final seekTarget = player.state.position - Duration(seconds: _settings.doubleTapSeekDuration);
                _handleCustomSeek(seekTarget);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowUp) {
                final newVol = (player.state.volume + 5.0).clamp(0.0, 100.0);
                player.setVolume(newVol);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowDown) {
                final newVol = (player.state.volume - 5.0).clamp(0.0, 100.0);
                player.setVolume(newVol);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.keyM) {
                if (player.state.volume > 0.0) {
                  player.setVolume(0.0);
                } else {
                  player.setVolume(100.0);
                }
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.escape) {
                try {
                  player.setVolume(0.0);
                  player.pause();
                  player.stop();
                } catch (_) {}
                _resetOrientationAndUI();
                Navigator.of(context, rootNavigator: true).pop();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final dy = pointerSignal.scrollDelta.dy;
                if (dy < 0) {
                  // Scrolled up
                  final newVol = (player.state.volume + 5.0).clamp(0.0, 100.0);
                  player.setVolume(newVol);
                } else if (dy > 0) {
                  // Scrolled down
                  final newVol = (player.state.volume - 5.0).clamp(0.0, 100.0);
                  player.setVolume(newVol);
                }
              }
            },
            child: Center(
              child: _isPlaying 
                 ? (isDesktop 
                     ? Video(controller: controller, controls: NoVideoControls)
                     : CustomVideoControls(
                         player: player,
                         controller: controller,
                         videoTitle: pipState?.queue[pipState.currentIndex].videoTitle ?? widget.videoTitle,
                     isPip: false,
                     downloadedPrefixSize: _downloadedPrefixSize,
                     expectedSize: _expectedSize,
                     activeDownloadOffset: _activeDownloadOffset,
                     activeDownloadedSize: _activeDownloadedSize,
                     onBack: () {
                       try {
                         player.setVolume(0.0);
                         player.pause();
                         player.stop();
                       } catch (_) {}
                       _resetOrientationAndUI();
                       Navigator.of(context, rootNavigator: true).pop();
                     },
                     hasPrevEpisode: pipState != null && pipState.currentIndex > 0,
                     hasNextEpisode: pipState != null && pipState.currentIndex + 1 < pipState.queue.length,
                     onPrevEpisode: _playPreviousEpisode,
                     onNextEpisode: _playNextEpisode,
                     onSeek: _handleCustomSeek,
                     customBuffering: _isBuffering,
                     seriesName: pipState?.queue[pipState.currentIndex].seriesName ?? widget.seriesName,
                     currentEpisodeIndex: pipState?.currentIndex ?? widget.currentEpisodeIndex ?? 0,
                   )
                 )
                : _isInitializing
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(color: Colors.blueAccent),
                          SizedBox(height: 16),
                          Text('Resolving video stream from Telegram...', style: TextStyle(color: Colors.white70)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.blueAccent),
                          const SizedBox(height: 16),
                          const Text('Buffering stream from Telegram...', style: TextStyle(color: Colors.white70)),
                          if (_expectedSize > 0)
                            Text('${(_downloadedPrefixSize / 1024 / 1024).toStringAsFixed(1)} MB / ${(_expectedSize / 1024 / 1024).toStringAsFixed(1)} MB', style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
            ),
          ),
        ),
      );

    if (isDesktop) return scaffold;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          try {
            player.setVolume(0.0);
            player.pause();
            player.stop();
          } catch (e) {}
          _resetOrientationAndUI();
        }
      },
      child: scaffold,
    );
  }

  void _applyStreamingProfile() {
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        final profile = _settings.streamingProfile;
        
        if (profile == 'Aggressive Buffer') {
          nativePlayer.setProperty('demuxer-max-bytes', '629145600'); // 600 MB
          nativePlayer.setProperty('demuxer-max-back-bytes', '209715200'); // 200 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '240');
          nativePlayer.setProperty('cache-pause-wait', '2');
          Log.i('Applied Aggressive Buffer Profile: 600MB buffer, 200MB back buffer, 240s prefetch');
        } else if (profile == 'Mobile Saver') {
          nativePlayer.setProperty('demuxer-max-bytes', '104857600'); // 100 MB
          nativePlayer.setProperty('demuxer-max-back-bytes', '31457280'); // 30 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '75');
          nativePlayer.setProperty('cache-pause-wait', '6');
          Log.i('Applied Mobile Saver Profile: 100MB buffer, 30MB back buffer, 75s prefetch');
        } else {
          // Balanced profile
          nativePlayer.setProperty('demuxer-max-bytes', '314572800'); // 300 MB
          nativePlayer.setProperty('demuxer-max-back-bytes', '104857600'); // 100 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '150');
          nativePlayer.setProperty('cache-pause-wait', '4');
          Log.i('Applied Balanced Profile: 300MB buffer, 100MB back buffer, 150s prefetch');
        }
      }
    } catch (e) {
      Log.w('Failed to apply streaming profile: $e');
    }
  }

  Future<void> _syncProgressToTrackers() async {
    if (widget.seriesName.isEmpty || widget.currentEpisodeIndex == null) return;
    final episodeNumber = widget.currentEpisodeIndex! + 1;
    final trackerService = ref.read(trackerServiceProvider);

    Log.i('80% watched milestone reached. Syncing watch progress to enabled trackers for "${widget.seriesName}" Ep $episodeNumber');

    // 1. AniList
    if (_storageService.getAnilistToken()?.isNotEmpty == true) {
      try {
        final mediaId = await trackerService.searchAnilistId(widget.seriesName);
        if (mediaId != null) {
          final isCompleted = widget.episodeList != null && episodeNumber == widget.episodeList!.length;
          final success = await trackerService.updateAnilistProgress(
            mediaId,
            episodeNumber,
            status: isCompleted ? 'COMPLETED' : 'CURRENT',
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('[AniList] Progress synced successfully (Ep $episodeNumber)'),
                backgroundColor: Colors.blueAccent,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        Log.w('AniList background progress sync failed: $e');
      }
    }

    // 2. MyAnimeList
    if (_storageService.getMalToken()?.isNotEmpty == true) {
      try {
        final animeId = await trackerService.searchMalId(widget.seriesName);
        if (animeId != null) {
          final isCompleted = widget.episodeList != null && episodeNumber == widget.episodeList!.length;
          final success = await trackerService.updateMalProgress(
            animeId,
            episodeNumber,
            status: isCompleted ? 'completed' : 'watching',
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('[MAL] Progress synced successfully (Ep $episodeNumber)'),
                backgroundColor: Colors.teal,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        Log.w('MAL background progress sync failed: $e');
      }
    }

    // 3. Trakt.tv
    if (_storageService.getTraktToken()?.isNotEmpty == true) {
      try {
        final showSlug = await trackerService.searchTraktId(widget.seriesName);
        if (showSlug != null) {
          int seasonNum = 1;
          final match = RegExp(r'season\s*(\d+)', caseSensitive: false).firstMatch(widget.videoTitle);
          if (match != null) {
            seasonNum = int.tryParse(match.group(1)!) ?? 1;
          }
          final success = await trackerService.updateTraktProgress(
            showSlug,
            seasonNum,
            episodeNumber,
            80.0,
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('[Trakt] Scrobble stop synced successfully (S${seasonNum}E$episodeNumber)'),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        Log.w('Trakt background scrobble failed: $e');
      }
    }
  }

  Future<void> _updateBlendSubtitlesForTrack(Player player, SubtitleTrack track) async {
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        String targetId = track.id;
        if (targetId == 'auto') {
          final sid = await nativePlayer.getProperty('sid');
          if (sid == 'no' || sid == 'auto') {
            nativePlayer.setProperty('blend-subtitles', 'no');
            return;
          }
          targetId = sid;
        } else if (targetId == 'no') {
          nativePlayer.setProperty('blend-subtitles', 'no');
          return;
        }

        final settings = ref.read(videoSettingsProvider);
        final targetLibass = settings.subtitleRendererMode == 'native';
        final useNativeBlending = targetLibass;
        
        if (useNativeBlending) {
          nativePlayer.setProperty('blend-subtitles', 'yes');
          Log.i('Native blending subtitle enabled. Set blend-subtitles to yes.');
        } else {
          nativePlayer.setProperty('blend-subtitles', 'no');
          Log.i('Native blending subtitle disabled. Set blend-subtitles to no.');
        }
      }
    } catch (e) {
      Log.e('Failed to check and update blend-subtitles for track', e);
    }
  }

  Future<void> _recreatePlayer() async {
    try {
      final currentPos = player.state.position;
      final isPlayingState = player.state.playing;
      
      if (_isInitializing) return;
      
      setState(() {
        _isInitializing = true;
        _isPlaying = false;
        _updatesSubscription?.cancel();
        for (final sub in _subscriptions) {
          sub.cancel();
        }
        _subscriptions.clear();
      });
      
      _pipController.clearActivePlayer(player);
      
      try {
        await player.setVolume(0.0);
      } catch (e) {}
      try {
        await player.pause();
      } catch (e) {}
      try {
        await player.stop();
      } catch (e) {}
      await player.dispose();

      _initialTrackSelectionDone = false;
      _initPlayerInstance();
      _setupPlayerListeners();

      final fileId = _resolvedVideoFileId ?? widget.videoFileId;
      if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
        player.open(Media(widget.networkUrl!), play: isPlayingState).then((_) {
          if (!mounted) return;
          setState(() {
            _isPlaying = true;
            _isInitializing = false;
          });
          if (currentPos.inSeconds > 0) {
            if (player.state.duration.inSeconds > 0) {
              _handleCustomSeek(currentPos);
            } else {
              late final StreamSubscription<Duration> durSub;
              durSub = player.stream.duration.listen((dur) {
                if (dur.inSeconds > 0) {
                  durSub.cancel();
                  _subscriptions.remove(durSub);
                  if (mounted) {
                    _handleCustomSeek(currentPos);
                  }
                }
              });
              _subscriptions.add(durSub);
            }
          }
        });
      } else {
        final cachedFile = _proxyService.getCachedFile(fileId);
        final localPath = cachedFile?.local.path ?? '';
        String mediaUrl = (localPath.isNotEmpty && cachedFile?.local.isDownloadingCompleted == true)
            ? localPath
            : _proxyService.getProxyUrl(fileId, fileName: widget.videoTitle);
            
        if (mediaUrl.startsWith('http://127.0.0.1')) {
          try {
            await _proxyService.onReady.timeout(const Duration(seconds: 3));
          } catch (e) {}
          mediaUrl = _proxyService.getProxyUrl(fileId, fileName: widget.videoTitle);
        }

        final proxyHeaders = mediaUrl.startsWith('http://127.0.0.1') ? _proxyService.getAuthHeaders() : null;
        player.open(Media(mediaUrl, httpHeaders: proxyHeaders), play: isPlayingState).then((_) {
          if (!mounted) return;
          setState(() {
            _isPlaying = true;
            _isInitializing = false;
          });
          if (currentPos.inSeconds > 0) {
            if (player.state.duration.inSeconds > 0) {
              _handleCustomSeek(currentPos);
            } else {
              late final StreamSubscription<Duration> durSub;
              durSub = player.stream.duration.listen((dur) {
                if (dur.inSeconds > 0) {
                  durSub.cancel();
                  if (mounted) {
                    _handleCustomSeek(currentPos);
                  }
                }
              });
            }
          }
        });
      }
      player.setVolume(100.0);
    } catch (e, stack) {
      Log.e('Failed to recreate player on subtitle mode switch', e, stack);
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _initPlayerInstance() {
    final localFont = ref.read(storageServiceProvider).localFontPath;
    player = Player(
      configuration: PlayerConfiguration(
        pitch: _settings.pitchCorrection,
        libass: _settings.subtitleRendererMode == 'native',
        libassAndroidFont: localFont ?? 'assets/fonts/Roboto-Regular.ttf',
        libassAndroidFontName: 'Roboto',
      ),
    );

    // Optimize streaming cache/buffering parameters for low-bandwidth connections and reduce glitching
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        
        // Enable cache and buffers aggressively
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('demuxer-max-bytes', '209715200'); // 200 MB cache (prevents connection stalls)
        nativePlayer.setProperty('demuxer-max-back-bytes', '52428800'); // 50 MB back buffer (fast seeking)
        nativePlayer.setProperty('demuxer-readahead-secs', '180'); // Cache up to 180 seconds ahead
        
        // Prevent artificial freeze/stall on first load by disabling hard pause-initial locks
        nativePlayer.setProperty('cache-pause', 'yes'); 
        nativePlayer.setProperty('cache-pause-initial', 'yes'); 
        nativePlayer.setProperty('cache-pause-wait', '5'); // Buffer 5 seconds before resuming play
        nativePlayer.setProperty('cache-secs', '180'); // Max caching seconds
        nativePlayer.setProperty('hr-seek', 'no'); // Disable high-precision seeking to avoid frame decoding stalls
        
        nativePlayer.setProperty('audio-pitch-correction', 'yes');
        nativePlayer.setProperty('audio-buffer', '0.2'); // 0.2s audio buffer
        nativePlayer.setProperty('framedrop', 'no'); // Disable framedrop to prevent skips and micro-stuttering
        nativePlayer.setProperty('sub-fix-timing', 'yes');
        nativePlayer.setProperty('stream-buffer-size', '16777216'); // 16 MB stream buffer (faster download pipeline)
        
        // Fix glitching on all decoders by optimizing decoder loops
        nativePlayer.setProperty('vd-lavc-fast', 'no'); // Disable fast decoding hacks to prevent pixelation/glitching
        nativePlayer.setProperty('vd-lavc-skiploopfilter', 'none'); // Do not skip loop filter to keep lines sharp and clean in anime
        nativePlayer.setProperty('vd-lavc-check-hw-profile', 'no'); // Skip HW profile validation to prevent decoder load failures
        nativePlayer.setProperty('vd-lavc-threads', '0'); // Auto threads for multi-threaded decoding
        nativePlayer.setProperty('vd-lavc-show-all', 'no'); // Discard corrupted/smeared frames instead of displaying them
        nativePlayer.setProperty('vd-lavc-er', 'careful'); // Enable high error resilience to conceal stream packet drops
        if (!Platform.isAndroid && !Platform.isIOS) {
          nativePlayer.setProperty('hwdec-extra-frames', '64'); // Allocate larger buffer pool on PC GPUs to prevent frame drops
        }
        
        final hwDecMode = _storageService.getHardwareDecoderMode();
        if (Platform.isAndroid) {
          String safeMode = hwDecMode;
          // mediacodec-copy causes severe macroblocking on Android HEVC streams due to CPU RAM bottlenecks
          if (safeMode == 'mediacodec-copy') {
            safeMode = 'auto';
          }
          if (safeMode != 'no') {
            nativePlayer.setProperty('hwdec', safeMode);
            Log.i('Set hardware decoder mode to $safeMode on player init (Android sanitized)');
          } else {
            nativePlayer.setProperty('hwdec', 'no');
            Log.i('Hardware decoder mode is disabled (no) on player init');
          }
        } else {
          String safeMode = hwDecMode;
          // media_kit's default auto (d3d11va) and auto-copy can cause severe macroblocking/smearing on TDLib streams
          if (safeMode == 'auto' || safeMode == 'auto-copy') {
            safeMode = 'no'; // Default to software decoding on PC for flawless playback
          }
          nativePlayer.setProperty('hwdec', safeMode);
          Log.i('Set hardware decoder mode to $safeMode on player init (PC)');
        }
        // Always configure native subtitle rendering (libass)
        if (localFont != null) {
          try {
            final fontDir = File(localFont).parent.path;
            nativePlayer.setProperty('sub-fonts-dir', fontDir);
            Log.i('Native fonts directory set to: $fontDir');
          } catch (e) {
            Log.e('Failed to parse font parent directory', e);
          }
        }
        nativePlayer.setProperty('sub-font', 'Roboto');
        nativePlayer.setProperty('sub-visibility', _settings.subtitleRendererMode == 'native' ? 'yes' : 'no');
        nativePlayer.setProperty('sub-auto', 'all');
        nativePlayer.setProperty('embeddedfonts', 'yes'); // Enable embedded fonts inside media containers (MKV, etc.)
        nativePlayer.setProperty('blend-subtitles', 'no'); // Set to 'no' so subtitles render independently and sync perfectly with the master audio clock
        nativePlayer.setProperty('demuxer-mkv-subtitle-preroll', 'yes');
        nativePlayer.setProperty('demuxer-mkv-subtitle-preroll-secs', '10'); // Pre-roll/cache subtitles 10 seconds ahead
        nativePlayer.setProperty('sub-ass-override', 'force');
        nativePlayer.setProperty('sub-codepage', 'utf-8'); // Ensure non-Unicode text subtitles fall back to UTF-8
        nativePlayer.setProperty('sub-scale-with-window', 'yes'); // Keep subtitles proportional to resizing
        nativePlayer.setProperty('sub-ass-force-margins', 'yes'); // Ensure margins are utilized for ASS subtitles

        // Load subtitle customizations dynamically
        _updateSubtitleProperties();

        final volBoost = _storageService.getVolumeBoostEnabled();
        if (volBoost) {
          nativePlayer.setProperty('volume-max', '200');
        }

        // Apply audio filters (DRC & Equalizer)
        _updateAudioFilters();

        // Apply adaptive streaming profile
        _applyStreamingProfile();

        // Apply custom MPV options
        final customOpts = _settings.customMpvOptions;
        if (customOpts.isNotEmpty) {
          final pairs = customOpts.split(',');
          for (final pair in pairs) {
            final idx = pair.indexOf('=');
            if (idx != -1) {
              final key = pair.substring(0, idx).trim();
              final value = pair.substring(idx + 1).trim();
              if (key.isNotEmpty) {
                try {
                  nativePlayer.setProperty(key, value);
                  Log.i('Applied custom MPV option: $key = $value');
                } catch (e) {
                  Log.w('Failed to set custom MPV option $key: $e');
                }
              }
            } else {
              final key = pair.trim();
              if (key.isNotEmpty) {
                try {
                  nativePlayer.setProperty(key, 'yes');
                  Log.i('Applied custom MPV option: $key = yes');
                } catch (e) {
                  Log.w('Failed to set custom MPV option $key: $e');
                }
              }
            }
          }
        }
      }
    } catch (e, stack) {
      Log.e('Failed to configure native player features', e, stack);
    }

    final hwDecMode = _storageService.getHardwareDecoderMode();
    final enableHw = hwDecMode != 'no';
    _pipController.setActivePlayer(player);
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: enableHw,
      ),
    );
  }

  void _setupPlayerListeners() {

    _subscriptions.add(player.stream.playing.listen((playing) {
      if (playing) {
        if (!widget.isPip) WakelockPlus.enable();
      } else {
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted && !player.state.playing && !widget.isPip) {
            WakelockPlus.disable();
          }
        });
      }
    }));

    _subscriptions.add(player.stream.tracks.listen((tracks) {
      if (tracks.audio.isEmpty && tracks.subtitle.isEmpty) return;
      if (_initialTrackSelectionDone) return;
      _initialTrackSelectionDone = true;

      // 1. Select the audio track based on global preference
      final prefAudio = _storageService.getPreferredAudioTrack();
      AudioTrack? targetAudioTrack;
      if (prefAudio != null && prefAudio != 'auto') {
        for (final track in tracks.audio) {
          final identifier = (track.language ?? track.title ?? track.id).toLowerCase();
          if (identifier == prefAudio.toLowerCase() ||
              (track.title != null && track.title!.toLowerCase().contains(prefAudio.toLowerCase())) ||
              (track.language != null && track.language!.toLowerCase().contains(prefAudio.toLowerCase()))) {
            targetAudioTrack = track;
            break;
          }
        }
      }

      // Apply audio track if resolved and not already set
      if (targetAudioTrack != null && player.state.track.audio != targetAudioTrack) {
        player.setAudioTrack(targetAudioTrack);
        Log.i('Auto-selected preferred audio track: ${targetAudioTrack.title ?? targetAudioTrack.language ?? targetAudioTrack.id}');
      } else {
        targetAudioTrack = player.state.track.audio;
      }

      // 2. Classify audio language category for sub/dub logic
      String audioLangCategory = 'other';
      final lower = (targetAudioTrack.language ?? targetAudioTrack.title ?? '').toLowerCase();
      if (lower.contains('jpn') || lower.contains('ja') || lower.contains('japanese')) {
        audioLangCategory = 'jpn';
      } else if (lower.contains('eng') || lower.contains('en') || lower.contains('english')) {
        audioLangCategory = 'eng';
      }

      // 3. Select subtitle track based on the audio language preference
      final prefSub = _storageService.getPreferredSubtitleTrackForAudioLanguage(audioLangCategory);
      bool matchedSub = false;
      SubtitleTrack? selectedTrack;

      if (prefSub != null) {
        if (prefSub == 'no') {
          selectedTrack = SubtitleTrack.no();
          if (player.state.track.subtitle != selectedTrack) {
            player.setSubtitleTrack(selectedTrack);
          }
          matchedSub = true;
        } else {
          for (final track in tracks.subtitle) {
            final identifier = (track.language ?? track.title ?? track.id).toLowerCase();
            if (identifier == prefSub.toLowerCase() ||
                (track.title != null && track.title!.toLowerCase().contains(prefSub.toLowerCase())) ||
                (track.language != null && track.language!.toLowerCase().contains(prefSub.toLowerCase()))) {
              selectedTrack = track;
              if (player.state.track.subtitle != track) {
                player.setSubtitleTrack(track);
                Log.i('Automatically applied preferred subtitle track ($prefSub) for audio language category ($audioLangCategory)');
              }
              matchedSub = true;
              break;
            }
          }
        }
      }

      // 4. Default smart fallbacks if no user preference is saved
      if (!matchedSub) {
        final currentSub = player.state.track.subtitle;
        if (currentSub.id == 'no' || currentSub.id == 'auto') {
          if (audioLangCategory == 'eng') {
            // English audio (Dub) -> Default to forced/signs/songs subtitles if available, otherwise disabled
            SubtitleTrack? forcedTrack;
            for (final track in tracks.subtitle) {
              final titleLower = (track.title ?? '').toLowerCase();
              if (titleLower.contains('forced') || 
                  titleLower.contains('sign') || 
                  titleLower.contains('song') || 
                  titleLower.contains('translation')) {
                forcedTrack = track;
                break;
              }
            }
            final targetTrack = forcedTrack ?? SubtitleTrack.no();
            selectedTrack = targetTrack;
            if (player.state.track.subtitle != targetTrack) {
              player.setSubtitleTrack(targetTrack);
              Log.i('Smart Sub/Dub default: English audio -> Target subtitle track: ${targetTrack.title ?? targetTrack.id}');
            }
          } else {
            // Japanese / other audio (Sub) -> Default to English subtitle if available
            if (tracks.subtitle.isNotEmpty) {
              SubtitleTrack? targetSubTrack;
              for (final track in tracks.subtitle) {
                final lower = (track.language ?? track.title ?? '').toLowerCase();
                if (lower.contains('eng') || lower.contains('en') || lower.contains('english')) {
                  targetSubTrack = track;
                  break;
                }
              }
              targetSubTrack ??= tracks.subtitle.firstWhere(
                (t) => t.id != 'no' && t.id != 'auto',
                orElse: () => tracks.subtitle.first,
              );
              selectedTrack = targetSubTrack;
              if (player.state.track.subtitle != targetSubTrack) {
                player.setSubtitleTrack(targetSubTrack);
                Log.i('Smart Sub/Dub default: $audioLangCategory audio -> English/fallback subtitle: ${targetSubTrack.language ?? targetSubTrack.title ?? targetSubTrack.id}');
              }
            }
          }
        }
      }

      // Update blend-subtitles based on selected track codec
      _updateBlendSubtitlesForTrack(player, selectedTrack ?? player.state.track.subtitle);
    }));

    _subscriptions.add(player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isBuffering = buffering;
        });
      }
      
      // Pause preload dynamically if buffering starts
      if (buffering && _nextEpisodePreloaded) {
        _cancelPreloadOfNextEpisode();
      }
    }));
  }

  void _updateAudioFilters() {
    if (player.platform is NativePlayer) {
      final nativePlayer = player.platform as NativePlayer;
      final filters = <String>[];
      if (_settings.dynamicRangeCompression) {
        filters.add('lavfi=[dynaudnorm]');
      }
      if (_settings.equalizerEnabled) {
        final bands = _settings.equalizerBands;
        filters.add('equalizer=f=100:width_type=o:w=2.0:g=${bands[0]}');
        filters.add('equalizer=f=300:width_type=o:w=2.0:g=${bands[1]}');
        filters.add('equalizer=f=1000:width_type=o:w=2.0:g=${bands[2]}');
        filters.add('equalizer=f=3000:width_type=o:w=2.0:g=${bands[3]}');
        filters.add('equalizer=f=10000:width_type=o:w=2.0:g=${bands[4]}');
      }
      if (filters.isNotEmpty) {
        nativePlayer.setProperty('af', filters.join(','));
        Log.i('Applied audio filters dynamically: ${filters.join(',')}');
      } else {
        nativePlayer.setProperty('af', '');
        Log.i('Cleared audio filters dynamically');
      }
    }
  }

  void _updateSubtitleProperties() {
    if (player.platform is NativePlayer) {
      final nativePlayer = player.platform as NativePlayer;
      nativePlayer.setProperty('sub-font-size', _settings.subtitleFontSize.round().toString());
      nativePlayer.setProperty('sub-color', _settings.subtitleColor);
      nativePlayer.setProperty('sub-delay', _settings.subtitleDelay.toString());
      
      String resolvedFontFamily = 'Roboto';
      final fontName = _settings.subtitleFont.toLowerCase();
      if (fontName.contains('arial')) {
        resolvedFontFamily = 'Arial';
      } else if (fontName.contains('dejavu')) {
        resolvedFontFamily = 'DejaVuSans';
      } else if (fontName.contains('sans-serif')) {
        resolvedFontFamily = 'sans-serif';
      } else if (fontName.contains('roboto')) {
        resolvedFontFamily = 'Roboto';
      }
      nativePlayer.setProperty('sub-font', resolvedFontFamily);
      Log.i('Updated subtitle settings dynamically: size=${_settings.subtitleFontSize}, color=${_settings.subtitleColor}, delay=${_settings.subtitleDelay}, font=$resolvedFontFamily');
    }
  }

}

