import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../settings/settings_provider.dart';
import 'pip_manager.dart';
import 'custom_video_controls.dart';
import '../../core/logger.dart';
import '../../core/constants.dart';

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
  int? _resolvedVideoFileId;
  bool _isInitializing = true;

  StreamSubscription? _completedSubscription;
  StreamSubscription? _tracksSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _saveTimer;
  bool _nextEpisodePreloaded = false;

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
    
    final localFontPath = _storageService.localFontPath;
    player = Player(
      configuration: PlayerConfiguration(
        pitch: _settings.pitchCorrection,
        libass: true,
        libassAndroidFont: 'assets/fonts/Roboto-Regular.ttf',
        libassAndroidFontName: 'Roboto',
      ),
    );

    // Optimize streaming cache/buffering parameters for low-bandwidth connections and reduce glitching
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('demuxer-max-back-bytes', '16777216'); // 16 MB back buffer (instant backward seek)
        nativePlayer.setProperty('cache-pause', 'yes'); // Stalls playback if buffer runs out to prevent decoding corrupted frames
        nativePlayer.setProperty('cache-pause-initial', 'yes'); // Ensure initial buffer is populated to prevent decoder underflow/freeze
        nativePlayer.setProperty('hr-seek', 'no'); // Disable high-precision seeking on slow networks to seek instantly to keyframes
        nativePlayer.setProperty('sub-visibility', 'yes');
        nativePlayer.setProperty('sub-auto', 'all');
        nativePlayer.setProperty('embeddedfonts', 'yes'); // Enable embedded fonts inside media containers (MKV, etc.)

        if (Platform.isAndroid) {
          nativePlayer.setProperty('hwdec', 'mediacodec-copy');
        }
        
        // Load subtitle customizations
        final subSize = _storageService.getSubtitleFontSize();
        final subColor = _storageService.getSubtitleColor();
        final subDelay = _storageService.getSubtitleDelay();
        final subFont = _storageService.getSubtitleFont();
        final volBoost = _storageService.getVolumeBoostEnabled();

        nativePlayer.setProperty('sub-size', subSize.round().toString());
        nativePlayer.setProperty('sub-color', subColor);
        nativePlayer.setProperty('sub-delay', subDelay.toString());
        
        if (volBoost) {
          nativePlayer.setProperty('volume-max', '200');
        }

        if (localFontPath != null) {
          final fontFile = File(localFontPath);
          nativePlayer.setProperty('sub-fonts-dir', fontFile.parent.path);
          nativePlayer.setProperty('sub-font', subFont);
          if (Platform.isAndroid) {
            final useSysFonts = _storageService.getSubtitleSystemFonts();
            nativePlayer.setProperty('sub-font-provider', useSysFonts ? 'auto' : 'none');
          }
          Log.i('Native MPV configured with sub-fonts-dir: ${fontFile.parent.path}');
        }

        // Setup connectivity subscription for network caching profiles
        _initNetworkProfiling();
        _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
          _applyNetworkCacheProfile(results);
        });
      }
    } catch (e, stack) {
      Log.e('Failed to configure native player features', e, stack);
    }

    _pipController.setActivePlayer(player);
    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    
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
    
    // Auto-Play Next Episode Logic
    _completedSubscription = player.stream.completed.listen((completed) {
      if (completed && _settings.autoplayNextVideo && !_autoNextCancelled && widget.episodeList != null && widget.currentEpisodeIndex != null) {
        if (widget.currentEpisodeIndex! + 1 < widget.episodeList!.length) {
          _playNextEpisode();
        }
      }
    });

    // Auto-apply saved preferred tracks
    _tracksSubscription = player.stream.tracks.listen((tracks) {
      final prefSub = _storageService.getPreferredSubtitleTrack();
      final prefAudio = _storageService.getPreferredAudioTrack();

      bool matched = false;
      if (prefSub != null) {
        if (prefSub == 'no') {
          if (player.state.track.subtitle != SubtitleTrack.no()) {
            player.setSubtitleTrack(SubtitleTrack.no());
          }
          matched = true;
        } else {
          for (final track in tracks.subtitle) {
            final identifier = (track.language ?? track.title ?? track.id).toLowerCase();
            if (identifier == prefSub.toLowerCase() ||
                (track.title != null && track.title!.toLowerCase().contains(prefSub.toLowerCase())) ||
                (track.language != null && track.language!.toLowerCase().contains(prefSub.toLowerCase()))) {
              if (player.state.track.subtitle != track) {
                player.setSubtitleTrack(track);
                Log.i('Automatically applied preferred subtitle track: ${track.language ?? track.title ?? track.id}');
              }
              matched = true;
              break;
            }
          }
        }
      }

      if (!matched) {
        // No preference saved yet or matching preference not found.
        // Let's auto-select English or the first subtitle track if available.
        if (tracks.subtitle.isNotEmpty) {
          SubtitleTrack? targetTrack;
          // Look for english track
          for (final track in tracks.subtitle) {
            final lower = (track.language ?? track.title ?? '').toLowerCase();
            if (lower.contains('eng') || lower.contains('en')) {
              targetTrack = track;
              break;
            }
          }
          // Fallback to first non-disabled track
          targetTrack ??= tracks.subtitle.firstWhere((t) => t.id != 'no' && t.id != 'auto', orElse: () => tracks.subtitle.first);
          if (player.state.track.subtitle != targetTrack) {
            player.setSubtitleTrack(targetTrack);
            Log.i('Auto-selected default subtitle track: ${targetTrack.language ?? targetTrack.title ?? targetTrack.id}');
          }
        }
      }

      if (prefAudio != null) {
        if (prefAudio == 'auto') {
          if (player.state.track.audio != AudioTrack.auto()) {
            player.setAudioTrack(AudioTrack.auto());
          }
        } else {
          for (final track in tracks.audio) {
            final identifier = (track.language ?? track.title ?? track.id).toLowerCase();
            if (identifier == prefAudio.toLowerCase() ||
                (track.title != null && track.title!.toLowerCase().contains(prefAudio.toLowerCase())) ||
                (track.language != null && track.language!.toLowerCase().contains(prefAudio.toLowerCase()))) {
              if (player.state.track.audio != track) {
                player.setAudioTrack(track);
                Log.i('Automatically applied preferred audio track: ${track.language ?? track.title ?? track.id}');
                break;
              }
            }
          }
        }
      }
    });

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

      // Check and trigger next episode preloading if progress >= 80%
      if (!_nextEpisodePreloaded && player.state.duration.inSeconds > 0) {
        final progress = player.state.position.inSeconds / player.state.duration.inSeconds;
        if (progress >= 0.8) {
          _nextEpisodePreloaded = true;
          _preloadNextEpisode();
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

    _resolvedVideoFileId = freshFileId ?? widget.videoFileId;

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }

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

        // If we are actively seeking, capture the start downloaded size
        if (_isPlaying && _pendingSeekTarget != null) {
          _initialDownloadedSize ??= event.file.local.downloadedSize;
        }

        if (localPath.isNotEmpty && !_isPlaying) {
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

    // Reverted startup offset to 0 so the file header is downloaded sequentially
    _tdlibService.send(td.DownloadFile(
      fileId: _resolvedVideoFileId!,
      priority: 32,
      offset: 0,
      limit: 0,
      synchronous: false,
    ));
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

      // Cancel previous TDLib download tasks to clear the old offset queue before requesting a new offset
      _tdlibService.send(td.CancelDownloadFile(
        fileId: _resolvedVideoFileId ?? widget.videoFileId,
        onlyIfPending: false,
      ));

      // Update download offset in TDLib
      _tdlibService.send(td.DownloadFile(
        fileId: _resolvedVideoFileId ?? widget.videoFileId,
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
    // Redundant pause/stop removed to prevent race conditions during player disposal

    _updatesSubscription?.cancel();
    _completedSubscription?.cancel();
    _tracksSubscription?.cancel();
    _connectivitySubscription?.cancel();
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
      if (!_pipController.isTransitioning) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {}

    try {
      final fileId = _resolvedVideoFileId ?? widget.videoFileId;
      if (widget.networkUrl == null && fileId != 0) {
        final activeDownloads = ref.read(downloadControllerProvider);
        final isDownloadingPermanently = activeDownloads.containsKey(fileId);
        if (!isDownloadingPermanently) {
          _tdlibService.send(td.CancelDownloadFile(fileId: fileId, onlyIfPending: false));
          Future.delayed(const Duration(milliseconds: 500), () {
            _tdlibService.send(td.DeleteFile(fileId: fileId));
          });
        }
      }
    } catch (_) {}
    
    super.dispose();
  }

  void _preloadNextEpisode() {
    if (widget.episodeList == null || widget.currentEpisodeIndex == null) return;
    final nextIndex = widget.currentEpisodeIndex! + 1;
    if (nextIndex >= widget.episodeList!.length) return;

    final nextMsg = widget.episodeList![nextIndex];
    int? nextFileId;
    
    if (nextMsg.content is td.MessageVideo) {
      nextFileId = (nextMsg.content as td.MessageVideo).video.video.id;
    } else if (nextMsg.content is td.MessageDocument) {
      nextFileId = (nextMsg.content as td.MessageDocument).document.document.id;
    }

    if (nextFileId != null) {
      Log.i('Preloading next episode (ID: $nextFileId) - downloading first 15MB');
      _tdlibService.send(td.DownloadFile(
        fileId: nextFileId,
        priority: 1, // Low priority for background preloading
        offset: 0,
        limit: 15728640, // 15 MB limit
        synchronous: false,
      ));
    }
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

  Future<void> _initNetworkProfiling() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      _applyNetworkCacheProfile(connectivityResults);
    } catch (e) {
      Log.w('Failed to check initial connectivity: $e');
    }
  }

  void _applyNetworkCacheProfile(List<ConnectivityResult> results) {
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        final profileMode = _storageService.getNetworkProfileMode();
        
        bool isWifi = false;
        if (profileMode == 'wifi') {
          isWifi = true;
        } else if (profileMode == 'mobile') {
          isWifi = false;
        } else {
          // auto mode
          isWifi = results.contains(ConnectivityResult.wifi) ||
              results.contains(ConnectivityResult.ethernet) ||
              results.contains(ConnectivityResult.vpn);
        }
        
        if (isWifi) {
          nativePlayer.setProperty('demuxer-max-bytes', '134217728'); // 128 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '120'); // 120s
          nativePlayer.setProperty('cache-pause-wait', '2');
          Log.i('Applied Wi-Fi Profile: Caching boundary set to 128MB');
        } else {
          nativePlayer.setProperty('demuxer-max-bytes', '16777216'); // 16 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '20'); // 20s
          nativePlayer.setProperty('cache-pause-wait', '4');
          Log.i('Applied Mobile Data Profile: Caching boundary set to 16MB');
        }
      }
    } catch (e) {
      Log.w('Failed to apply network cache profile: $e');
    }
  }
}
