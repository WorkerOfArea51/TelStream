import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tdlib/td_api.dart' as td;
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
  bool _currentLibass = false;
  String? _openedMediaPath;
  bool _isRecreatingPlayer = false;
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

  StreamSubscription? _tracksSubscription;
  StreamSubscription? _bufferingSubscription;
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
    


    final initialLibass = _settings.subtitleRendererMode == 'native'; // For 'auto', start with false (overlay)
    _currentLibass = initialLibass;
    _initPlayerInstance(libass: initialLibass);
    _setupPlayerListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pipController.isTransitioning = false;
    });
    
    _initDownload();
    
    if (!widget.isPip) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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

    _saveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_settings.savePositionOnQuit && player.state.position.inSeconds > 0) {
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

      // Check and trigger next episode preloading if progress >= 25% (Adaptive Preload Pipeline)
      if (!_nextEpisodePreloaded && player.state.duration.inSeconds > 0) {
        final position = player.state.position.inSeconds;
        final duration = player.state.duration.inSeconds;
        final progress = position / duration;
        if (progress >= 0.25) {
          _nextEpisodePreloaded = true;
          _preloadNextEpisode();
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

  @override
  void didUpdateWidget(VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPip && !oldWidget.isPip) {
      _resetOrientationAndUI();
    }
  }

  void _resetOrientationAndUI() {
    try {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
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

  void _startPlayback(String localPath) {
    _openedMediaPath = localPath;
    if (_isPlaying) return;
    _isPlaying = true;
    player.open(Media(localPath), play: true).then((_) {
      if (!mounted) return;
      final savedPos = _storageService.getWatchPosition(widget.messageId);
      if (savedPos > 0) {
        if (player.state.duration.inSeconds > 0) {
          _handleCustomSeek(Duration(seconds: savedPos));
        } else {
          late final StreamSubscription<Duration> durSub;
          durSub = player.stream.duration.listen((dur) {
            if (dur.inSeconds > 0) {
              durSub.cancel();
              if (mounted) {
                _handleCustomSeek(Duration(seconds: savedPos));
              }
            }
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
      player.open(Media(widget.networkUrl!));
      player.setVolume(100.0);
      return;
    }

    _resolvedVideoFileId = widget.videoFileId;
    if (widget.seriesName.isNotEmpty && _resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      _storageService.associateFileWithSeries(widget.seriesName, _resolvedVideoFileId!);
    }

    if (mounted) {
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
        priority: 32,
        offset: initialOffset,
        limit: 0,
        synchronous: false,
      ));
    }

    // Play now if path is already resolved by TDLib
    if (initialFileState != null && initialFileState.local.path.isNotEmpty) {
      final localPath = initialFileState.local.path;
      if (initialFileState.local.isDownloadingCompleted) {
        Log.i('Instant playback: playing cached completed file path: $localPath');
        _startPlayback(localPath);
      } else {
        Log.i('Instant playback: streaming active download via proxy: $localPath');
        _proxyService.setDownloadOffset(_resolvedVideoFileId!, _initialOffset, initialFileState.local.downloadedSize);
        final proxyUrl = _proxyService.getProxyUrl(_resolvedVideoFileId!, fileName: widget.videoTitle);
        _startPlayback(proxyUrl);
      }
    }

    if (_resolvedVideoFileId == 0) {
      Log.i('videoFileId is 0, resolving fresh file ID via categories search...');
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
            if (freshFileId != null) {
              Log.i('Resolved fresh file ID $freshFileId for message ${widget.messageId} in category ${category.title}');
              break;
            }
          }
        } catch (e) {
          Log.w('Failed to check category ${category.title} for message ${widget.messageId}: $e');
        }
      }
      _resolvedVideoFileId = freshFileId ?? 0;
      if (widget.seriesName.isNotEmpty && _resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
        _storageService.associateFileWithSeries(widget.seriesName, _resolvedVideoFileId!);
      }
      _listenToUpdates();

      // Trigger download for newly resolved file ID
      if (_resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
        int initialOffset = 0;
        final savedPos = _storageService.getWatchPosition(widget.messageId);
        if (savedPos > 0) {
          final totalDuration = _storageService.getVideoDuration(widget.messageId);
          final cachedFile = _proxyService.getCachedFile(_resolvedVideoFileId!);
          final expectedSize = cachedFile?.expectedSize ?? 0;
          if (totalDuration > 0 && expectedSize > 0) {
            final fraction = savedPos / totalDuration;
            initialOffset = (fraction * expectedSize).round();
            const graceBuffer = 1 * 1024 * 1024;
            initialOffset = (initialOffset - graceBuffer).clamp(0, expectedSize);
          }
        }
        _initialOffset = initialOffset;

        if (initialOffset > 0) {
          final cachedFile = _proxyService.getCachedFile(_resolvedVideoFileId!);
          _proxyService.setDownloadOffset(_resolvedVideoFileId!, initialOffset, cachedFile?.local.downloadedSize ?? 0);
        }

        _tdlibService.send(td.DownloadFile(
          fileId: _resolvedVideoFileId!,
          priority: 32,
          offset: initialOffset,
          limit: 0,
          synchronous: false,
        ));
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
        priority: 32,
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
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Redundant pause/stop removed to prevent race conditions during player disposal

    _updatesSubscription?.cancel();
    _tracksSubscription?.cancel();
    _bufferingSubscription?.cancel();
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
    } catch (_) {}

    // Resume any downloads that were paused for streaming
    try {
      ref.read(downloadControllerProvider.notifier).resumeDownloadsAfterStreaming();
    } catch (_) {}

    try {
      player.dispose();
    } catch (_) {}

    if (_pipController.activePlayer == player) {
      _pipController.clearActivePlayer(player);
    }
    
    try {
      if (_pipController.activePlayer == null) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {}

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
    } catch (_) {}
    
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
      Log.i('Preloading next episode (ID: $nextFileId) - downloading first 15MB');
      _tdlibService.send(td.DownloadFile(
        fileId: nextFileId,
        priority: 1, // Low priority for background preloading
        offset: 0,
        limit: 15728640, // 15 MB limit (15 * 1024 * 1024)
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
      if (previous?.subtitleRendererMode != next.subtitleRendererMode) {
        _settings = next;
        _updateBlendSubtitlesForTrack(player, player.state.track.subtitle);
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _isPlaying 
             ? CustomVideoControls(
                 player: player,
                 controller: controller,
                 videoTitle: pipState?.queue[pipState.currentIndex].videoTitle ?? widget.videoTitle,
                 isPip: false,
                 downloadedPrefixSize: _downloadedPrefixSize,
                 expectedSize: _expectedSize,
                 activeDownloadOffset: _activeDownloadOffset,
                 activeDownloadedSize: _activeDownloadedSize,
                 onBack: () => Navigator.of(context).pop(),
                 hasPrevEpisode: pipState != null && pipState.currentIndex > 0,
                 hasNextEpisode: pipState != null && pipState.currentIndex + 1 < pipState.queue.length,
                 onPrevEpisode: _playPreviousEpisode,
                 onNextEpisode: _playNextEpisode,
                 onSeek: _handleCustomSeek,
                 customBuffering: _isBuffering,
                 seriesName: pipState?.queue[pipState.currentIndex].seriesName ?? widget.seriesName,
                 currentEpisodeIndex: pipState?.currentIndex ?? widget.currentEpisodeIndex ?? 0,
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
        
        final hwdec = _storageService.getHardwareDecoderMode();
        final isDirectHw = Platform.isAndroid && hwdec == 'mediacodec';
        
        final settings = ref.read(videoSettingsProvider);
        
        final targetLibass = settings.subtitleRendererMode == 'native';
                             
        if (targetLibass != _currentLibass) {
          Log.i('Subtitles Mode: Switching libass from $_currentLibass to $targetLibass. Recreating player.');
          await _recreatePlayer(targetLibass, track);
          return;
        }
        
        final useNativeBlending = !isDirectHw && targetLibass;
        
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

  void _initPlayerInstance({required bool libass}) {
    player = Player(
      configuration: PlayerConfiguration(
        pitch: _settings.pitchCorrection,
        libass: libass,
        libassAndroidFont: 'assets/fonts/Roboto-Regular.ttf',
        libassAndroidFontName: 'Roboto',
      ),
    );

    // Optimize streaming cache/buffering parameters for low-bandwidth connections and reduce glitching
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        
        // Enable fast rendering/scaling profile to save GPU/CPU thermals and prevent lag
        nativePlayer.setProperty('profile', 'fast');

        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('demuxer-max-back-bytes', '16777216'); // 16 MB back buffer (instant backward seek)
        nativePlayer.setProperty('cache-pause', 'yes'); // Stalls playback if buffer runs out to prevent decoding corrupted frames
        nativePlayer.setProperty('cache-pause-initial', 'yes'); // Wait for initial buffer to prevent stutters
        nativePlayer.setProperty('hr-seek', 'no'); // Disable high-precision seeking on slow networks to seek instantly to keyframes
        
        // Set synchronization clocks and framedrop to maintain perfect audio/video/subtitle sync at high speed
        nativePlayer.setProperty('video-sync', 'audio');
        nativePlayer.setProperty('audio-pitch-correction', 'yes');
        nativePlayer.setProperty('audio-buffer', '0.2'); // Increased to 0.2s to prevent audio underflow stutters
        nativePlayer.setProperty('framedrop', 'vo'); // Drop late frames in VO to avoid lag at 2x speed without decoder slideshow freezes
        nativePlayer.setProperty('sub-fix-timing', 'yes');
        nativePlayer.setProperty('stream-buffer-size', '8388608'); // 8 MB stream buffer for high-throughput network reading
        nativePlayer.setProperty('vd-lavc-fast', 'yes'); // Enable fast decoding optimizations
        nativePlayer.setProperty('vd-lavc-skiploopfilter', 'all'); // Skip all loop filtering to keep up with 2x playback speed
        nativePlayer.setProperty('vd-lavc-threads', '0'); // Enable multi-threaded video decoding to prevent lag at 2x speed

        final hwDecMode = _storageService.getHardwareDecoderMode();
        if (hwDecMode != 'no') {
          if (Platform.isAndroid) {
            nativePlayer.setProperty('hwdec', hwDecMode);
          } else {
            nativePlayer.setProperty('hwdec', 'auto');
          }
        } else {
          nativePlayer.setProperty('hwdec', 'no');
        }
        // Always configure native subtitle rendering (libass)
        nativePlayer.setProperty('sub-visibility', 'yes');
        nativePlayer.setProperty('sub-auto', 'all');
        nativePlayer.setProperty('embeddedfonts', 'yes'); // Enable embedded fonts inside media containers (MKV, etc.)
        nativePlayer.setProperty('blend-subtitles', 'no'); // Set to 'no' so subtitles render independently and sync perfectly with the master audio clock
        nativePlayer.setProperty('demuxer-mkv-subtitle-preroll', 'yes');
        nativePlayer.setProperty('sub-ass-override', 'scale');

        // Load subtitle customizations
        final subSize = _storageService.getSubtitleFontSize();
        final subColor = _storageService.getSubtitleColor();
        final subDelay = _storageService.getSubtitleDelay();
        final subFont = _storageService.getSubtitleFont();

        nativePlayer.setProperty('sub-font-size', subSize.round().toString());
        nativePlayer.setProperty('sub-color', subColor);
        nativePlayer.setProperty('sub-delay', subDelay.toString());

        // Set sub-font to the font family name.
        String resolvedFontFamily = 'Roboto'; // Default to Roboto
        if (subFont.toLowerCase().contains('arial')) {
          resolvedFontFamily = 'Arial';
        } else if (subFont.toLowerCase().contains('dejavu')) {
          resolvedFontFamily = 'DejaVuSans';
        } else if (subFont.toLowerCase().contains('sans-serif')) {
          resolvedFontFamily = 'sans-serif';
        } else if (subFont.toLowerCase().contains('roboto')) {
          resolvedFontFamily = 'Roboto';
        }
        
        nativePlayer.setProperty('sub-font', resolvedFontFamily);

        final volBoost = _storageService.getVolumeBoostEnabled();
        if (volBoost) {
          nativePlayer.setProperty('volume-max', '200');
        }

        // Apply audio filters (DRC & Equalizer)
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
          Log.i('Applied audio filters on init: ${filters.join(',')}');
        } else {
          nativePlayer.setProperty('af', '');
        }

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
    _tracksSubscription?.cancel();
    _bufferingSubscription?.cancel();

    _tracksSubscription = player.stream.tracks.listen((tracks) {
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
      if (targetAudioTrack != null) {
        if (player.state.track.audio != targetAudioTrack) {
          player.setAudioTrack(targetAudioTrack);
          Log.i('Automatically applied preferred audio track: ${targetAudioTrack.language ?? targetAudioTrack.title ?? targetAudioTrack.id}');
        }
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

      if (prefSub != null) {
        if (prefSub == 'no') {
          if (player.state.track.subtitle != SubtitleTrack.no()) {
            player.setSubtitleTrack(SubtitleTrack.no());
          }
          matchedSub = true;
        } else {
          for (final track in tracks.subtitle) {
            final identifier = (track.language ?? track.title ?? track.id).toLowerCase();
            if (identifier == prefSub.toLowerCase() ||
                (track.title != null && track.title!.toLowerCase().contains(prefSub.toLowerCase())) ||
                (track.language != null && track.language!.toLowerCase().contains(prefSub.toLowerCase()))) {
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
              
              if (player.state.track.subtitle != targetSubTrack) {
                player.setSubtitleTrack(targetSubTrack);
                Log.i('Smart Sub/Dub default: $audioLangCategory audio -> English/fallback subtitle: ${targetSubTrack.language ?? targetSubTrack.title ?? targetSubTrack.id}');
              }
            }
          }
        }
      }

      // Update blend-subtitles based on selected track codec
      _updateBlendSubtitlesForTrack(player, player.state.track.subtitle);
    });

    _bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isBuffering = buffering;
        });
      }
      
      // Pause preload dynamically if buffering starts
      if (buffering && _nextEpisodePreloaded) {
        _cancelPreloadOfNextEpisode();
      }
    });
  }

  Future<void> _recreatePlayer(bool newLibass, SubtitleTrack targetTrack) async {
    if (_isRecreatingPlayer || !mounted) return;
    _isRecreatingPlayer = true;
    
    // Save current playback state
    final savedPosition = player.state.position;
    final wasPlaying = player.state.playing;
    final volume = player.state.volume;
    final rate = player.state.rate;
    final currentAudioTrack = player.state.track.audio;
    
    Log.i('Recreating player dynamically: position=$savedPosition, playing=$wasPlaying, volume=$volume, rate=$rate, libass=$newLibass');
    
    setState(() {
      _isPlaying = false;
      _isBuffering = true;
    });
    
    // Give the framework a short delay to completely unmount the old Video widget
    // before we dispose the player, avoiding any "use of disposed player" crash.
    await Future.delayed(const Duration(milliseconds: 100));
    
    _tracksSubscription?.cancel();
    _bufferingSubscription?.cancel();
    
    try {
      await player.dispose();
    } catch (e) {
      Log.e('Error disposing old player during recreation', e);
    }
    
    _currentLibass = newLibass;
    _initialTrackSelectionDone = false; // Allow track listener to run again
    
    _initPlayerInstance(libass: newLibass);
    
    // Set up new listeners for the new player instance
    _setupPlayerListeners();
    
    // Set track selection listener to restore selected tracks on-the-fly
    _tracksSubscription = player.stream.tracks.listen((tracks) {
      if (tracks.audio.isEmpty && tracks.subtitle.isEmpty) return;
      if (_initialTrackSelectionDone) return;
      _initialTrackSelectionDone = true;
      
      // Restore audio track
      if (currentAudioTrack.id != 'no' && currentAudioTrack.id != 'auto') {
        final matchedAudio = tracks.audio.firstWhere(
          (t) => t.id == currentAudioTrack.id,
          orElse: () => tracks.audio.first,
        );
        player.setAudioTrack(matchedAudio);
      }
      
      // Restore selected subtitle track
      if (targetTrack.id != 'no' && targetTrack.id != 'auto') {
        final matchedSub = tracks.subtitle.firstWhere(
          (t) => t.id == targetTrack.id,
          orElse: () => SubtitleTrack.no(),
        );
        player.setSubtitleTrack(matchedSub);
      } else {
        player.setSubtitleTrack(SubtitleTrack.no());
      }
      
      _updateBlendSubtitlesForTrack(player, player.state.track.subtitle);
    });
    
    // Start media playback at the saved position
    if (_openedMediaPath != null) {
      await player.open(Media(_openedMediaPath!), play: wasPlaying);
      if (mounted) {
        await player.seek(savedPosition);
        await player.setVolume(volume);
        await player.setRate(rate);
      }
    }
    
    _isRecreatingPlayer = false;
    if (mounted) {
      setState(() {
        _isPlaying = true;
      });
    }
  }
}
