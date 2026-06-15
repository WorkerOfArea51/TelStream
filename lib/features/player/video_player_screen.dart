import 'dart:async';
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
    Key? key, 
    required this.messageId, 
    required this.videoFileId, 
    this.videoTitle = '',
    this.episodeList,
    this.currentEpisodeIndex,
    this.seriesName = '',
    this.isPip = false,
    this.networkUrl,
  }) : super(key: key);

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> with WidgetsBindingObserver {
  late final Player player;
  late final VideoController controller;
  StreamSubscription? _updatesSubscription;
  bool _isPlaying = false;
  int _downloadedPrefixSize = 0;
  int _expectedSize = 0;
  bool _autoNextCancelled = false;
  int? _initialDownloadedSize;
  Duration? _pendingSeekTarget;
  bool _isBuffering = false;

  StreamSubscription? _completedSubscription;
  Timer? _saveTimer;

  late final StorageService _storageService;
  late final TdlibService _tdlibService;
  late final PipController _pipController;
  late final VideoSettings _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _storageService = ref.read(storageServiceProvider);
    _tdlibService = ref.read(tdlibServiceProvider);
    _pipController = ref.read(pipControllerProvider.notifier);
    _settings = ref.read(videoSettingsProvider);
    
    player = Player(
      configuration: PlayerConfiguration(
        pitch: _settings.pitchCorrection,
      ),
    );

    // Optimize streaming cache/buffering parameters for low-bandwidth connections and reduce glitching
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('demuxer-max-bytes', '8388608'); // 8 MB buffer
        nativePlayer.setProperty('demuxer-max-back-bytes', '2097152'); // 2 MB back buffer
        nativePlayer.setProperty('demuxer-readahead-secs', '5'); // Buffer up to 5 seconds ahead
        nativePlayer.setProperty('cache-pause', 'yes'); // Stalls playback if buffer runs out to prevent decoding corrupted frames
        nativePlayer.setProperty('cache-pause-initial', 'yes');
        nativePlayer.setProperty('cache-pause-wait', '5'); // Wait for 5 seconds of buffered data before resuming
        nativePlayer.setProperty('hr-seek', 'no'); // Disable high-precision seeking on slow networks to seek instantly to keyframes
      }
    } catch (_) {}

    _pipController.setActivePlayer(player);
    controller = VideoController(player);
    
    _startDownload();
    
    if (!widget.isPip) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _resetOrientationAndUI();
    }
    
    // Auto-Play Next Episode Logic
    _completedSubscription = player.stream.completed.listen((completed) {
      if (completed && _settings.autoplayNextVideo && !_autoNextCancelled && widget.episodeList != null && widget.currentEpisodeIndex != null) {
        if (widget.currentEpisodeIndex! + 1 < widget.episodeList!.length) {
          _playNextEpisode();
        }
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
            videoFileId: widget.videoFileId,
          );
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
    final nextIndex = widget.currentEpisodeIndex! + 1;
    final nextMsg = widget.episodeList![nextIndex];
    int? nextFileId;
    String nextTitle = 'Episode ${nextIndex + 1}';
    
    if (nextMsg.content is td.MessageVideo) {
      final v = nextMsg.content as td.MessageVideo;
      nextFileId = v.video.video.id;
      nextTitle = v.video.fileName;
    } else if (nextMsg.content is td.MessageDocument) {
      final d = nextMsg.content as td.MessageDocument;
      nextFileId = d.document.document.id;
      nextTitle = d.document.fileName;
    }

    if (nextFileId != null) {
      ref.read(pipControllerProvider.notifier).playVideo(
        context,
        messageId: nextMsg.id,
        videoFileId: nextFileId,
        videoTitle: '${widget.seriesName} - $nextTitle',
        episodeList: widget.episodeList,
        currentEpisodeIndex: nextIndex,
        seriesName: widget.seriesName,
      );
    }
  }

  void _playPreviousEpisode() {
    if (widget.currentEpisodeIndex == null || widget.currentEpisodeIndex! <= 0 || widget.episodeList == null) return;
    final prevIndex = widget.currentEpisodeIndex! - 1;
    final prevMsg = widget.episodeList![prevIndex];
    int? prevFileId;
    String prevTitle = 'Episode ${prevIndex + 1}';
    
    if (prevMsg.content is td.MessageVideo) {
      final v = prevMsg.content as td.MessageVideo;
      prevFileId = v.video.video.id;
      prevTitle = v.video.fileName;
    } else if (prevMsg.content is td.MessageDocument) {
      final d = prevMsg.content as td.MessageDocument;
      prevFileId = d.document.document.id;
      prevTitle = d.document.fileName;
    }

    if (prevFileId != null) {
      ref.read(pipControllerProvider.notifier).playVideo(
        context,
        messageId: prevMsg.id,
        videoFileId: prevFileId,
        videoTitle: '${widget.seriesName} - $prevTitle',
        episodeList: widget.episodeList,
        currentEpisodeIndex: prevIndex,
        seriesName: widget.seriesName,
      );
    }
  }

  DateTime? _lastUpdateTime;

  void _startDownload() {
    if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
      _isPlaying = true;
      player.open(Media(widget.networkUrl!));
      player.setVolume(100.0);
      return;
    }

    _updatesSubscription = _tdlibService.updates.listen((event) {
      if (event is td.UpdateFile && event.file.id == widget.videoFileId) {
        final localPath = event.file.local.path;
        
        final now = DateTime.now();
        if (_lastUpdateTime == null || now.difference(_lastUpdateTime!).inMilliseconds > 500 || event.file.local.isDownloadingCompleted) {
          _lastUpdateTime = now;
          if (mounted) {
            setState(() {
              _downloadedPrefixSize = event.file.local.downloadedPrefixSize;
              _expectedSize = event.file.expectedSize;
            });
          }
        }

        if (event.file.local.isDownloadingCompleted) {
          // Boost buffer sizes since the file is completely downloaded
          try {
            if (player.platform is NativePlayer) {
              final nativePlayer = player.platform as NativePlayer;
              nativePlayer.setProperty('demuxer-max-bytes', '104857600'); // 100 MB buffer
              nativePlayer.setProperty('demuxer-max-back-bytes', '52428800'); // 50 MB back buffer
              nativePlayer.setProperty('demuxer-readahead-secs', '120');
            }
          } catch (_) {}
        }

        if (localPath.isNotEmpty && !_isPlaying) {
          final totalSize = event.file.expectedSize;
          // Wait for 3% of the file, or at least 2.5MB, but at most 8MB before starting to play
          final targetBuffer = (totalSize * 0.03).clamp(2621440, 8388608);

          _initialDownloadedSize ??= event.file.local.downloadedSize;

          final downloadedDelta = event.file.local.downloadedSize - (_initialDownloadedSize ?? 0);
          final isReady = event.file.local.isDownloadingCompleted || downloadedDelta >= targetBuffer;

          if (isReady) {
            _isPlaying = true;
            player.open(Media(localPath), play: true).then((_) {
              if (!mounted) return;
              final savedPos = _storageService.getWatchPosition(widget.messageId);
              if (savedPos > 0) {
                // Seek to target position immediately
                player.seek(Duration(seconds: savedPos));
              }
            });
            player.setVolume(100.0);
          }
        }

        // Handle mid-play seek buffering updates
        if (_isPlaying && _pendingSeekTarget != null && _initialDownloadedSize != null) {
          final totalSize = event.file.expectedSize;
          final targetBuffer = (totalSize * 0.03).clamp(2621440, 8388608);
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

    // Determine initial offset based on saved watch position
    _tdlibService.sendAsync(td.GetFile(fileId: widget.videoFileId)).then((res) {
      if (!mounted) return;
      if (res is td.File) {
        final expectedSize = res.expectedSize;
        final isCompleted = res.local.isDownloadingCompleted;
        int initialOffset = 0;

        if (!isCompleted) {
          final savedPos = _storageService.getWatchPosition(widget.messageId);
          final duration = _storageService.getVideoDuration(widget.messageId);
          if (savedPos > 0 && duration > 0 && expectedSize > 0) {
            final fraction = savedPos / duration;
            initialOffset = (fraction * expectedSize).round();
            // Bound initialOffset to ensure we don't start at the very EOF
            if (initialOffset >= expectedSize - 2097152) {
              initialOffset = (expectedSize - 2097152).clamp(0, expectedSize);
            }
            Log.i('Cold-starting TDLib download from offset: $initialOffset bytes (resuming at $savedPos/$duration s)');
          }
        }

        _tdlibService.send(td.DownloadFile(
          fileId: widget.videoFileId,
          priority: 32,
          offset: initialOffset,
          limit: 0,
          synchronous: false,
        ));
      }
    }).catchError((_) {
      // Fallback if GetFile fails
      _tdlibService.send(td.DownloadFile(
        fileId: widget.videoFileId,
        priority: 32,
        offset: 0,
        limit: 0,
        synchronous: false,
      ));
    });
  }

  void _handleCustomSeek(Duration position) {
    if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
      player.seek(position);
      return;
    }

    final totalDuration = player.state.duration.inSeconds;
    final expectedSize = _expectedSize;

    if (totalDuration > 0 && expectedSize > 0 && _isPlaying) {
      // Check if file is fully downloaded
      final isCompleted = _downloadedPrefixSize >= expectedSize;
      if (isCompleted) {
        player.seek(position);
        return;
      }

      // Calculate corresponding byte offset
      final fraction = position.inSeconds / totalDuration;
      int byteOffset = (fraction * expectedSize).round();
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

      // Update download offset in TDLib
      _tdlibService.send(td.DownloadFile(
        fileId: widget.videoFileId,
        priority: 32,
        offset: byteOffset,
        limit: 0,
        synchronous: false,
      ));
      Log.i('Seeking TDLib download to offset: $byteOffset bytes (targeting $position)');
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
    try {
      player.pause();
      player.stop();
    } catch (_) {}

    _updatesSubscription?.cancel();
    _completedSubscription?.cancel();
    _saveTimer?.cancel();
    
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
            videoFileId: widget.videoFileId,
          );
        }
      }
    } catch (_) {}

    try {
      player.dispose();
    } catch (_) {}

    if (_pipController.activePlayer == player) {
      _pipController.clearActivePlayer(player);
    }
    
    try {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}

    try {
      if (widget.networkUrl == null && widget.videoFileId != 0) {
        final activeDownloads = ref.read(downloadControllerProvider);
        final isDownloadingPermanently = activeDownloads.containsKey(widget.videoFileId);
        if (!isDownloadingPermanently) {
          final fileId = widget.videoFileId;
          _tdlibService.send(td.CancelDownloadFile(fileId: fileId, onlyIfPending: false));
          Future.delayed(const Duration(milliseconds: 500), () {
            _tdlibService.send(td.DeleteFile(fileId: fileId));
          });
        }
      }
    } catch (_) {}
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                videoTitle: widget.videoTitle,
                isPip: false,
                downloadedPrefixSize: _downloadedPrefixSize,
                expectedSize: _expectedSize,
                onBack: () => Navigator.of(context).pop(),
                hasPrevEpisode: widget.episodeList != null && widget.currentEpisodeIndex != null && widget.currentEpisodeIndex! > 0,
                hasNextEpisode: widget.episodeList != null && widget.currentEpisodeIndex != null && widget.currentEpisodeIndex! + 1 < widget.episodeList!.length,
                onPrevEpisode: _playPreviousEpisode,
                onNextEpisode: _playNextEpisode,
                onAutoNextCancelled: () {
                  setState(() {
                    _autoNextCancelled = true;
                  });
                },
                onSeek: _handleCustomSeek,
                customBuffering: _isBuffering,
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
}
