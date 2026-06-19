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
  StreamSubscription? _bufferingSubscription;
  Timer? _saveTimer;
  bool _nextEpisodePreloaded = false;
  Timer? _preloadCooldownTimer;
  bool _hasUpdatedTracker = false;

  late final StorageService _storageService;
  late final TdlibService _tdlibService;
  late final PipController _pipController;
  late final VideoSettings _settings;
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
    


    player = Player(
      configuration: PlayerConfiguration(
        pitch: _settings.pitchCorrection,
        libass: true, // Always enable libass to allow subtitle parsing for both native and flutter modes
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
        nativePlayer.setProperty('cache-pause-initial', 'no'); // Start playing immediately without artificial startup delay
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

        // Apply adaptive streaming profile
        _applyStreamingProfile();
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

    // Auto-apply saved preferred tracks with smart sub/dub tracking
    _tracksSubscription = player.stream.tracks.listen((tracks) {
      if (tracks.audio.isEmpty) return;

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
            // English audio (Dub) -> Default to no subtitles
            if (player.state.track.subtitle != SubtitleTrack.no()) {
              player.setSubtitleTrack(SubtitleTrack.no());
              Log.i('Smart Sub/Dub default: English audio -> Subtitles disabled');
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

  void _startPlayback(String localPath) {
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
            _proxyService.setDownloadOffset(_resolvedVideoFileId!, 0, event.file.local.downloadedSize);
            final proxyUrl = _proxyService.getProxyUrl(_resolvedVideoFileId!);
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

    // Check if the file is already cached locally (fully or partially)
    if (_resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      try {
        final res = await _tdlibService.sendAsync(td.GetFile(fileId: _resolvedVideoFileId!))
            .timeout(const Duration(milliseconds: 300));
        if (res is td.File && res.local.path.isNotEmpty) {
          final localPath = res.local.path;
          if (mounted) {
            setState(() {
              _downloadedPrefixSize = res.local.downloadedPrefixSize;
              _expectedSize = res.expectedSize;
            });
          }
          if (res.local.isDownloadingCompleted) {
            Log.i('Instant playback: playing cached completed file path: $localPath');
            _startPlayback(localPath);
          } else {
            Log.i('Instant playback: streaming active download via proxy: $localPath');
            _proxyService.setDownloadOffset(_resolvedVideoFileId!, 0, res.local.downloadedSize);
            final proxyUrl = _proxyService.getProxyUrl(_resolvedVideoFileId!);
            _startPlayback(proxyUrl);
          }
        }
      } catch (e) {
        Log.w('Failed fast local GetFile check: $e');
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
    }

    // Trigger download with highest priority sequentially. If already completed, this will be a no-op in TDLib.
    if (_resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      _tdlibService.send(td.DownloadFile(
        fileId: _resolvedVideoFileId!,
        priority: 32,
        offset: 0,
        limit: 0,
        synchronous: false,
      ));
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
      final isWithinDownloadedRange = byteOffset < _downloadedPrefixSize;

      if (isCompleted || isWithinDownloadedRange) {
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

      // Cancel previous TDLib download tasks to clear the old offset queue before requesting a new offset
      _tdlibService.send(td.CancelDownloadFile(
        fileId: _resolvedVideoFileId ?? widget.videoFileId,
        onlyIfPending: false,
      ));

      // Update download offset in TDLib and Proxy
      final fileId = _resolvedVideoFileId ?? widget.videoFileId;
      _tdlibService.sendAsync(td.GetFile(fileId: fileId)).then((res) {
        if (res is td.File) {
          _proxyService.setDownloadOffset(fileId, byteOffset, res.local.downloadedSize);
        }
      });

      _tdlibService.send(td.DownloadFile(
        fileId: fileId,
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
        if (!isDownloadingPermanently) {
          _tdlibService.send(td.CancelDownloadFile(fileId: fileId, onlyIfPending: false));
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
        limit: 15728640, // 15 MB limit (15 * 1024 * 1024)
        synchronous: false,
      ));
    }
  }

  void _cancelPreloadOfNextEpisode() {
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
                seriesName: widget.seriesName,
                currentEpisodeIndex: widget.currentEpisodeIndex ?? 0,
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
          nativePlayer.setProperty('demuxer-max-bytes', '524288000'); // 500 MB
          nativePlayer.setProperty('demuxer-max-back-bytes', '157286400'); // 150 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '180');
          nativePlayer.setProperty('cache-pause-wait', '2');
          Log.i('Applied Aggressive Buffer Profile: 500MB buffer, 150MB back buffer, 180s prefetch');
        } else if (profile == 'Mobile Saver') {
          nativePlayer.setProperty('demuxer-max-bytes', '41943040'); // 40 MB
          nativePlayer.setProperty('demuxer-max-back-bytes', '10485760'); // 10 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '45');
          nativePlayer.setProperty('cache-pause-wait', '4');
          Log.i('Applied Mobile Saver Profile: 40MB buffer, 10MB back buffer, 45s prefetch');
        } else {
          // Balanced profile
          nativePlayer.setProperty('demuxer-max-bytes', '157286400'); // 150 MB
          nativePlayer.setProperty('demuxer-max-back-bytes', '52428800'); // 50 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '90');
          nativePlayer.setProperty('cache-pause-wait', '3');
          Log.i('Applied Balanced Profile: 150MB buffer, 50MB back buffer, 90s prefetch');
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
          await trackerService.updateAnilistProgress(
            mediaId,
            episodeNumber,
            status: isCompleted ? 'COMPLETED' : 'CURRENT',
          );
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
          await trackerService.updateMalProgress(
            animeId,
            episodeNumber,
            status: isCompleted ? 'completed' : 'watching',
          );
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
          await trackerService.updateTraktProgress(
            showSlug,
            seasonNum,
            episodeNumber,
            80.0,
          );
        }
      } catch (e) {
        Log.w('Trakt background scrobble failed: $e');
      }
    }
  }
}
