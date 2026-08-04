import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:telstream/features/player/widgets/cached_video_widget.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:telstream/features/player/media_kit_unified_controller.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../../services/device_detector.dart';
import '../../services/download_service.dart';
import '../settings/settings_provider.dart';
import '../home/user_channels_provider.dart';
import 'pip_manager.dart';
import 'custom_video_controls.dart';
import '../../core/logger.dart';
import '../../core/constants.dart';
import '../../services/streaming_proxy_service.dart';
import '../../services/tracker_service.dart';
import 'utils/player_filter_service.dart';
import 'unified_player_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'exo_player_unified_controller.dart';
import 'vlc_unified_controller.dart';


import '../../models/episode.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final int messageId;
  final int videoFileId;
  final String videoTitle;
  final List<Episode>? episodeList;
  final int? currentEpisodeIndex;
  final String seriesName;
  final bool isPip;
  final String? networkUrl;
  final bool isDesktopMode;
  final int? chatId;

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
    this.isDesktopMode = false,
    this.chatId,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
    late Player _mediaKitPlayer;
  late VideoController _mediaKitController;
  VideoPlayerController? _exoPlayerController;
  VlcPlayerController? _vlcPlayerController;
  late UnifiedPlayerController activePlayer;

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
  Map<String, String>? _currentHttpHeaders;

  // ── Disposal guard ──────────────────────────────────────────────────────
  // Prevents any post-disposal interaction with the Player or VideoController.
  // Without this, async callbacks (connectivity, watchdog, seek) can call
  // activePlayer.pause()/play()/seek() on a disposed Player, causing native crashes.
  bool _disposed = false;

  // ── Recreate-activePlayer guard ───────────────────────────────────────────────
  // Prevents _startPlayback from opening new media while _recreatePlayer is
  // still disposing the old Player. The old Player's stop/dispose is async,
  // and if _startPlayback runs concurrently it opens Media on a Player that
  // is about to be replaced.
  bool _isRecreating = false;

  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasNetworkConnected = true;
  Timer? _saveTimer;
  bool _nextEpisodePreloaded = false;
  Timer? _preloadCooldownTimer;
  bool _hasUpdatedTracker = false;
  bool _userPaused = false;
  late final StorageService _storageService;
  late final TdlibService _tdlibService;
  late final PipController _pipController;
  late VideoSettings _settings;
  late final StreamingProxyService _proxyService;
  late final HistoryLogNotifier _historyLog;
  late final DownloadController _downloadController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (_disposed) return; // Guard: don't touch activePlayer after dispose
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (!isConnected && _wasNetworkConnected) {
        Log.w('Network disconnected — pausing playback');
        _userPaused = !activePlayer.state.playing;
        try {
          activePlayer.pause();
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Network disconnected. Playback paused.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (isConnected && !_wasNetworkConnected) {
        Log.i('Network reconnected — resuming playback');
        if (!_userPaused) {
          try {
            activePlayer.play();
          } catch (_) {}
        }
      }
      _wasNetworkConnected = isConnected;
    });

    _storageService = ref.read(storageServiceProvider);
    _tdlibService = ref.read(tdlibServiceProvider);
    _pipController = ref.read(pipControllerProvider.notifier);
    _settings = ref.read(videoSettingsProvider);
    _proxyService = ref.read(streamingProxyServiceProvider).requireValue;
    _historyLog = ref.read(historyLogProvider.notifier);
    _downloadController = ref.read(downloadControllerProvider.notifier);

    () async {
      await _initPlayerInstance();
      if (!mounted) return;

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
          ref
              .read(downloadControllerProvider.notifier)
              .pauseDownloadsForStreaming();
        }
      });

      // Periodic Save for Continue Watching
      if (widget.seriesName.isNotEmpty &&
          widget.currentEpisodeIndex != null) {
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

      _startPeriodicSaveTimer();
    }();
  }

  // ── Extracted periodic save timer startup ───────────────────────────────
  // Previously this was inline in initState(). Now it's a named method so
  // _recreatePlayer() can restart it after cancelling it.
  void _startPeriodicSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!mounted || _disposed) {
        timer.cancel();
        return;
      }
      try {
        if (_settings.savePositionOnQuit &&
            activePlayer.state.position.inSeconds > 0 &&
            activePlayer.state.playing) {
          _storageService.saveWatchPosition(
              widget.messageId, activePlayer.state.position.inSeconds);
          if (activePlayer.state.duration.inSeconds > 0) {
            _storageService.saveVideoDuration(
                widget.messageId, activePlayer.state.duration.inSeconds);
          }
          if (!_storageService.isIncognitoMode() &&
              widget.seriesName.isNotEmpty &&
              widget.currentEpisodeIndex != null) {
            _historyLog.addToHistory(
              seriesName: widget.seriesName,
              messageId: widget.messageId,
              episodeIndex: widget.currentEpisodeIndex!,
              episodeTitle:
                  widget.videoTitle.replaceFirst('${widget.seriesName} - ', ''),
              positionInSeconds: activePlayer.state.position.inSeconds,
              videoFileId: _resolvedVideoFileId ?? widget.videoFileId,
            );
          }
        }
      } catch (e, st) {
        Log.e('Failed to save watch position in periodic timer', e, st);
      }

      // Check and trigger tracker watch progress syncing if progress >= 80%
      if (!_hasUpdatedTracker && activePlayer.state.duration.inSeconds > 0) {
        final position = activePlayer.state.position.inSeconds;
        final duration = activePlayer.state.duration.inSeconds;
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
      if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }

      // Call Wakelock after SystemChrome, as SystemChrome can clear window
      // flags on Android
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (mounted && !_disposed) {
          try {
            await WakelockPlus.disable(); // Force clear internal state
            await WakelockPlus.enable();
          } catch (_) {}
        }
      });
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
      // Episode changed on Desktop (reusing activePlayer)
      // Defer to after the widget tree finishes building — Riverpod forbids
      // modifying providers during didUpdateWidget.
      Future.microtask(() {
        if (mounted && !_disposed) {
          _pipController.setActivePlayer(_mediaKitPlayer);
        }
      });
      activePlayer.stop().then((_) {
        if (mounted && !_disposed) {
          setState(() {
            _isInitializing = true;
            _isPlaying = false;
            _downloadedPrefixSize = 0;
            _expectedSize = 0;
          });
          _initDownload();
        }
      }).catchError((Object e, StackTrace st) {
        Log.e('activePlayer.stop() failed during episode change', e, st);
        if (mounted && !_disposed) {
          _recreatePlayer(); // Force-recreate the activePlayer if stop failed.
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
    if (pipState != null &&
        pipState.currentIndex + 1 < pipState.queue.length) {
      ref
          .read(pipControllerProvider.notifier)
          .playQueueIndex(context, pipState.currentIndex + 1);
    }
  }

  void _playPreviousEpisode() {
    final pipState = ref.read(pipControllerProvider);
    if (pipState != null && pipState.currentIndex > 0) {
      ref
          .read(pipControllerProvider.notifier)
          .playQueueIndex(context, pipState.currentIndex - 1);
    }
  }

  DateTime? _lastUpdateTime;

  Future<void> _startPlayback(String localPath) async {
    // Guard: don't open media while activePlayer is being recreated or disposed
    if (_isPlaying || _isRecreating || _disposed) return;
    _isPlaying = true;

    String finalPath = localPath;
    if (StreamingProxyService.isProxyUrl(localPath)) {
      // Proxy is started at app launch (main.dart line 107 via
      // container.read(streamingProxyServiceProvider.future)), so it's
      // always ready by the time the user plays a video. No wait needed.
      finalPath = _proxyService.getProxyUrl(
        _resolvedVideoFileId ?? widget.videoFileId,
        fileName: widget.videoTitle,
      );
    }

    final savedPos = _storageService.getWatchPosition(widget.messageId);
    // We don't know the duration yet, so we can't check if savedPos is
    // near the end here. We'll check inside performRobustStartupSeek
    // after the activePlayer reports the duration.
    final shouldPlayImmediately = savedPos <= 0;

    final proxyHeaders =
        StreamingProxyService.isProxyUrl(finalPath)
            ? _proxyService.getAuthHeaders()
            : null;
            
    if (mounted) {
      setState(() {
        _currentHttpHeaders = proxyHeaders;
      });
    }

        
    // Always call open() on the active engine
    activePlayer.open(finalPath, httpHeaders: proxyHeaders, play: shouldPlayImmediately)
        .timeout(const Duration(seconds: 30))
        .then((_) {
      if (!mounted || _disposed) return;
      if (savedPos > 0) {
        Future<void> performRobustStartupSeek(Duration knownDuration) async {
          // If savedPos is >= 95% of duration, restart from beginning
          // (video was already watched to the end)
          if (knownDuration.inSeconds > 0 &&
              savedPos >= (knownDuration.inSeconds * 0.95).toInt()) {
            Log.i(
                'savedPos ($savedPos) is near end of video (duration ${knownDuration.inSeconds}s), restarting from beginning');
            if (mounted && !_disposed) {
              activePlayer.play();
              setState(() {
                _isInitializing = false;
              });
            }
            return;
          }
          // Reduced from 5 to 2 retries — each retry calls abortActiveRequests
          // which can cause HttpException flood if set too high.
          for (int i = 0; i < 2; i++) {
            if (!mounted || _disposed) return;

            // Abort any active proxy reads to free the mpv thread so
            // activePlayer.seek won't deadlock
            final fileId = _resolvedVideoFileId ?? widget.videoFileId;
            if (fileId != 0) {
              _proxyService.abortActiveRequests(fileId);
            }

            await activePlayer.seek(Duration(seconds: savedPos));
            await Future.delayed(Duration(milliseconds: 300 + (i * 200)));
            if (!mounted || _disposed) return;
            final currentPos = activePlayer.state.position.inSeconds;
            if (currentPos > 0 && (currentPos - savedPos).abs() <= 5) {
              Log.i('Robust startup seek successful at attempt ${i + 1}');
              break;
            }
            Log.w(
                'Playback startup seek failed. Retrying seek to $savedPos (Attempt ${i + 1})');
          }
          if (mounted && !_disposed) {
            activePlayer.play();
            setState(() {
              _isInitializing = false;
            });
          }
        }

        if (activePlayer.state.duration.inSeconds > 0) {
          performRobustStartupSeek(activePlayer.state.duration);
        } else {
          late final StreamSubscription<Duration> durSub;
          durSub = activePlayer.stream.duration.listen((dur) {
            if (dur.inSeconds > 0) {
              durSub.cancel();
              _subscriptions.remove(durSub);
              if (mounted && !_disposed) {
                performRobustStartupSeek(dur);
              }
            }
          });
          _subscriptions.add(durSub);
        }
      } else {
        if (mounted && !_disposed) {
          // Explicit play() needed on PC (software decoding) —
          // play: true in activePlayer.open() doesn't always auto-start on PC
          try {
            activePlayer.play();
          } catch (e) {
            Log.w('activePlayer.play() after open failed: $e');
          }
          setState(() {
            _isInitializing = false;
          });
        }
      }
    }).catchError((Object e, StackTrace st) {
      Log.e('activePlayer.open() failed for $finalPath', e, st);
      if (mounted && !_disposed) {
        setState(() {
          _isInitializing = false;
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.unableToOpenVideo(e.toString())),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });

    if (!_disposed) {
      activePlayer.setVolume(100.0);
    }
  }

  void _listenToUpdates() {
    _updatesSubscription?.cancel();
    _updatesSubscription = _tdlibService.updates.listen((event) {
      if (_disposed) return; // Guard: don't process updates after dispose
      try {
        if (event is td.UpdateFile) {
          final fileId = _resolvedVideoFileId;
          if (fileId == null || event.file.id != fileId) return;
          final localPath = event.file.local.path;

          final now = DateTime.now();
          if (_lastUpdateTime == null ||
              now.difference(_lastUpdateTime!).inMilliseconds > 500 ||
              event.file.local.isDownloadingCompleted) {
            _lastUpdateTime = now;
            if (mounted) {
              setState(() {
                _downloadedPrefixSize =
                    event.file.local.downloadedPrefixSize;
                _expectedSize = event.file.expectedSize;
                _activeDownloadOffset =
                    _proxyService.getActiveDownloadOffset(fileId);
                final baseDownloaded =
                    _proxyService.getDownloadedSizeAtOffset(fileId);
                _activeDownloadedSize =
                    (event.file.local.downloadedSize - baseDownloaded)
                        .clamp(0, event.file.expectedSize);
              });
            }
          }

          if (event.file.local.isDownloadingCompleted) {
            // Boost buffer sizes since the file is completely downloaded
            try {
              if ((activePlayer is MediaKitUnifiedController && _mediaKitPlayer.platform is NativePlayer)) {
                final nativePlayer = _mediaKitPlayer.platform as NativePlayer;
                nativePlayer.setProperty(
                    'demuxer-max-bytes', '524288000'); // 500 MB buffer
                nativePlayer.setProperty(
                    'demuxer-max-back-bytes', '157286400'); // 150 MB back
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
              Log.i(
                  'Proxy playback fallback: playing cached completed file path: $localPath');
              _startPlayback(localPath);
            } else {
              Log.i(
                  'Proxy playback active: routing streaming through loopback server');
              _proxyService.setDownloadOffset(_resolvedVideoFileId!,
                  _initialOffset, event.file.local.downloadedSize);
              final proxyUrl = _proxyService.getProxyUrl(
                  _resolvedVideoFileId!,
                  fileName: widget.videoTitle);
              _startPlayback(proxyUrl);
            }
          }

          // Handle mid-play seek buffering updates
          if (_isPlaying &&
              _pendingSeekTarget != null &&
              _initialDownloadedSize != null) {
            final totalSize = event.file.expectedSize;
            final targetBuffer =
                (totalSize * 0.01).clamp(524288, 2097152); // 512KB-2MB
            final downloadedDelta =
                event.file.local.downloadedSize - _initialDownloadedSize!;

            if (event.file.local.isDownloadingCompleted ||
                downloadedDelta >= targetBuffer) {
              final seekTarget = _pendingSeekTarget!;
              _pendingSeekTarget = null;
              _initialDownloadedSize = null;
              if (mounted && !_disposed) {
                setState(() {
                  _isBuffering = false;
                });
              }
              activePlayer.seek(seekTarget).then((_) {
                if (mounted && !_disposed) {
                  try {
                    activePlayer.play();
                  } catch (e, st) {
                    Log.e('activePlayer.play() after seek failed', e, st);
                  }
                }
              }).catchError((Object e, StackTrace st) {
                Log.e('activePlayer.seek() to $seekTarget failed', e, st);
                if (mounted && !_disposed) {
                  try {
                    activePlayer.play();
                  } catch (_) {}
                }
              });
            }
          }
        } // Close if (event is td.UpdateFile)
      } catch (e, st) {
        Log.e('Error processing TDLib update in activePlayer', e, st);
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
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || ref.read(videoSettingsProvider).videoEngine == 'MediaKit') {
        activePlayer.open(widget.networkUrl!, play: true)
            .timeout(const Duration(seconds: 30))
            .catchError((Object e, StackTrace st) {
          Log.e(
              'activePlayer.open() failed for network URL ${widget.networkUrl}', e, st);
          if (mounted && !_disposed) {
            setState(() {
              _isPlaying = false;
              _isInitializing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!
                    .unableToOpenVideo(e.toString())),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 4),
              ),
            );
            Navigator.of(context, rootNavigator: true).maybePop();
          }
        });
      }
      
      if (!_disposed) {
        activePlayer.setVolume(100.0);
      }
      return;
    }

    _resolvedVideoFileId = widget.videoFileId;

    // Check if the original file ID already has a completed download.
    // If yes, skip fresh file ID resolution and use the original.
    final originalFile = _proxyService.getCachedFile(widget.videoFileId);
    if (originalFile != null &&
        originalFile.local.path.isNotEmpty &&
        originalFile.local.isDownloadingCompleted) {
      Log.i(
          'Original file ID ${widget.videoFileId} already fully downloaded, skipping fresh file ID resolution');
      _resolvedVideoFileId = widget.videoFileId;
      _startPlayback(originalFile.local.path);
      if (!_nextEpisodePreloaded) {
        _nextEpisodePreloaded = true;
        _preloadNextEpisode();
      }
      return;
    }

    // Pre-emptively resolve the fresh file ID from TDLib to prevent stale
    // file ID errors
    Log.i(
        'Resolving fresh file ID for message ${widget.messageId}...');
    int? freshFileId;

    // PREFERRED PATH: use widget.chatId directly (works for user-added
    // channels too).
    if (widget.chatId != null && widget.chatId! != 0) {
      try {
        final res = await _tdlibService
            .sendAsync(td.GetMessage(
              chatId: widget.chatId!,
              messageId: widget.messageId,
            ))
            .timeout(const Duration(seconds: 3));
        if (res is td.Message) {
          if (res.content is td.MessageVideo) {
            freshFileId =
                (res.content as td.MessageVideo).video.video.id;
          } else if (res.content is td.MessageDocument) {
            freshFileId =
                (res.content as td.MessageDocument).document.document.id;
          }
          if (freshFileId != null && freshFileId != 0) {
            Log.i(
                'Resolved fresh file ID $freshFileId via chatId=${widget.chatId} for message ${widget.messageId}');
          }
        }
      } catch (e) {
        Log.w(
            'Failed to resolve file ID via chatId=${widget.chatId}: $e');
      }
    }

    // FALLBACK PATH: iterate Constants.categories + user-added channels.
    // This preserves backwards compatibility for callers that don't pass
    // chatId.
    if (freshFileId == null || freshFileId == 0) {
      // 1. Try the 3 hardcoded categories.
      for (final category in Constants.categories) {
        try {
          final res = await _tdlibService
              .sendAsync(td.GetMessage(
                chatId: category.channelId,
                messageId: widget.messageId,
              ))
              .timeout(const Duration(seconds: 3));
          if (res is td.Message) {
            if (res.content is td.MessageVideo) {
              freshFileId =
                  (res.content as td.MessageVideo).video.video.id;
            } else if (res.content is td.MessageDocument) {
              freshFileId =
                  (res.content as td.MessageDocument).document.document.id;
            }
            if (freshFileId != null && freshFileId != 0) {
              Log.i(
                  'Resolved fresh file ID $freshFileId via Constants.categories[${category.title}] for message ${widget.messageId}');
              break;
            }
          }
        } catch (e) {
          Log.w(
              'Failed to check category ${category.title} for message ${widget.messageId}: $e');
        }
      }
    }

    if (freshFileId == null || freshFileId == 0) {
      // 2. Try user-added channels.
      try {
        final userChannels = ref.read(userChannelsProvider);
        for (final uc in userChannels) {
          try {
            final res = await _tdlibService
                .sendAsync(td.GetMessage(
                  chatId: uc.channelId,
                  messageId: widget.messageId,
                ))
                .timeout(const Duration(seconds: 3));
            if (res is td.Message) {
              if (res.content is td.MessageVideo) {
                freshFileId =
                    (res.content as td.MessageVideo).video.video.id;
              } else if (res.content is td.MessageDocument) {
                freshFileId =
                    (res.content as td.MessageDocument).document.document.id;
              }
              if (freshFileId != null && freshFileId != 0) {
                Log.i(
                    'Resolved fresh file ID $freshFileId via user channel ${uc.title} for message ${widget.messageId}');
                break;
              }
            }
          } catch (e) {
            Log.w(
                'Failed to check user channel ${uc.title} for message ${widget.messageId}: $e');
          }
        }
      } catch (e) {
        Log.w(
            'Failed to read userChannelsProvider during file ID resolution: $e');
      }
    }

    if (freshFileId != null && freshFileId != 0) {
      _resolvedVideoFileId = freshFileId;
    } else {
      // Last resort: keep widget.videoFileId. Log loudly so the user can
      // report.
      Log.e(
          'Could not resolve fresh file ID for message ${widget.messageId} (chatId=${widget.chatId}). Falling back to widget.videoFileId=${widget.videoFileId}. Playback will likely fail.');
    }

    if (widget.seriesName.isNotEmpty &&
        _resolvedVideoFileId != null &&
        _resolvedVideoFileId != 0) {
      _storageService.associateFileWithSeries(
          widget.seriesName, _resolvedVideoFileId!);
    }

    final savedPos = _storageService.getWatchPosition(widget.messageId);
    if (mounted && savedPos <= 0) {
      setState(() {
        _isInitializing = false;
      });
    }

    // Start listening to updates immediately to catch progress and local
    // path updates
    _listenToUpdates();

    td.File? initialFileState;
    // Check if the file is already cached locally (fully or partially)
    if (_resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      try {
        final res = await _tdlibService
            .sendAsync(td.GetFile(fileId: _resolvedVideoFileId!))
            .timeout(const Duration(seconds: 3));
        if (res is td.File) {
          initialFileState = res;
          if (mounted) {
            setState(() {
              _downloadedPrefixSize = res.local.downloadedPrefixSize;
              _expectedSize = res.expectedSize;
            });
          }

          // If the file is completed but path is empty, trigger a quick
          // DownloadFile to force TDLib to resolve the path
          if (res.local.isDownloadingCompleted &&
              res.local.path.isEmpty) {
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
              final fresh = await _tdlibService
                  .sendAsync(td.GetFile(fileId: _resolvedVideoFileId!));
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

    // Trigger download with highest priority immediately. This ensures
    // TDLib pre-allocates the local file path so that subsequent GetFile
    // queries retrieve it instantly.
    if (_resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      int initialOffset = 0;
      final savedPos = _storageService.getWatchPosition(widget.messageId);
      if (savedPos > 0) {
        final totalDuration =
            _storageService.getVideoDuration(widget.messageId);
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
        _proxyService.setDownloadOffset(_resolvedVideoFileId!,
            initialOffset, initialFileState?.local.downloadedSize ?? 0);
      }

      _tdlibService.send(td.DownloadFile(
        fileId: _resolvedVideoFileId!,
        priority: 1,
        offset: initialOffset,
        limit: 0,
        synchronous: false,
      ));
    }

    // Play now using the resolved file state (completed file, active
    // download via proxy, or pre-emptively via proxy)
    if (_resolvedVideoFileId != null && _resolvedVideoFileId != 0) {
      final cachedFile =
          _proxyService.getCachedFile(_resolvedVideoFileId!) ??
              initialFileState;
      if (cachedFile != null && cachedFile.local.path.isNotEmpty) {
        final localPath = cachedFile.local.path;
        if (cachedFile.local.isDownloadingCompleted) {
          Log.i(
              'Instant playback: playing cached completed file path: $localPath');
          _startPlayback(localPath);
          if (!_nextEpisodePreloaded) {
            _nextEpisodePreloaded = true;
            _preloadNextEpisode();
          }
        } else {
          Log.i(
              'Instant playback: streaming active download via proxy: $localPath');
          _proxyService.setDownloadOffset(_resolvedVideoFileId!,
              _initialOffset, cachedFile.local.downloadedSize);
          final proxyUrl = _proxyService.getProxyUrl(
              _resolvedVideoFileId!,
              fileName: widget.videoTitle);
          _startPlayback(proxyUrl);
        }
      } else {
        // Fallback: start playback via proxy immediately even if path isn't
        // allocated on disk yet
        Log.i(
            'Pre-emptive playback fallback: starting proxy streaming immediately for fileId: $_resolvedVideoFileId');
        _proxyService.setDownloadOffset(_resolvedVideoFileId!,
            _initialOffset, cachedFile?.local.downloadedSize ?? 0);
        final proxyUrl = _proxyService.getProxyUrl(
            _resolvedVideoFileId!,
            fileName: widget.videoTitle);
        _startPlayback(proxyUrl);
      }
    }
  }

  void _handleCustomSeek(Duration position) {
    if (_disposed) return; // Guard: don't seek after dispose
    if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
      activePlayer.seek(position);
      _schedulePostSeekRecovery();
      return;
    }

    int totalDuration = activePlayer.state.duration.inSeconds;
    if (totalDuration <= 0) {
      totalDuration = _storageService.getVideoDuration(widget.messageId);
    }
    final expectedSize = _expectedSize;

    if (totalDuration > 0 && expectedSize > 0) {
      // Calculate corresponding byte offset
      final fraction = position.inSeconds / totalDuration;
      int byteOffset = (fraction * expectedSize).round();

      // Check if file is fully downloaded or if target offset is within
      // already-downloaded prefix
      final isCompleted = _downloadedPrefixSize >= expectedSize;
      final fileId = _resolvedVideoFileId ?? widget.videoFileId;
      final isWithinDownloadedRange = _proxyService.isRangeDownloaded(
          fileId, byteOffset, byteOffset + 2 * 1024 * 1024);

      // If the target byteOffset is already close to the active download
      // pointer (e.g. within 8MB), we don't need to restart the download
      // or shift offsets.
      final activeOffset = _proxyService.getActiveDownloadOffset(fileId);
      final isNearActiveOffset =
          byteOffset >= activeOffset && byteOffset <= activeOffset + 8 * 1024 * 1024;

      if (isCompleted || isWithinDownloadedRange || isNearActiveOffset) {
        _proxyService.abortActiveRequests(fileId);
        activePlayer.seek(position);
        _schedulePostSeekRecovery();
        return;
      }

      if (byteOffset >= expectedSize - 2097152) {
        byteOffset = (expectedSize - 2097152).clamp(0, expectedSize);
      }

      // Initiate pause-buffer-play seek cycle
      activePlayer.pause();
      if (mounted) {
        setState(() {
          _isBuffering = true;
          _initialDownloadedSize = null; // Will trigger re-init in updates
          _pendingSeekTarget = position;
        });
      }

      const graceBuffer =
          1 * 1024 * 1024; // 1 MB lookbehind buffer to align with proxy
      final shiftOffset = (byteOffset - graceBuffer).clamp(0, expectedSize);

      // Forcefully abort any active streaming proxy requests for this file
      // to free up the mpv thread.
      _proxyService.abortActiveRequests(fileId);

      // Update download offset in TDLib and Proxy synchronously to avoid
      // race conditions
      final cachedFile = _proxyService.getCachedFile(fileId);
      _proxyService.setDownloadOffset(
          fileId, shiftOffset, cachedFile?.local.downloadedSize ?? 0);

      _tdlibService.send(td.DownloadFile(
        fileId: fileId,
        priority: 1,
        offset: shiftOffset,
        limit: 0,
        synchronous: false,
      ));
      Log.i(
          'Seeking TDLib download to offset: $shiftOffset bytes (original target: $byteOffset bytes, position: $position)');
    } else {
      activePlayer.seek(position);
      _schedulePostSeekRecovery();
    }
  }

  /// Post-seek recovery check (v3 fix for the second MediaTek bug).
  ///
  /// The logcat showed that after a seek, the new MediaCodec instance
  /// dropped ALL frames (Render: 0, Drop: 121 in 5s). This is a
  /// MediaTek codec2 quirk where flushing the decoder does not fully
  /// reset its internal state.
  ///
  /// This method schedules a check 3 seconds after the seek. If the
  /// decoder hasn't produced any new frames in that window, we fully
  /// recreate the activePlayer (which creates a fresh MediaCodec instance).
  ///
  /// The watchdog's Mode B detection also catches this case, but only
  /// after 3 seconds of consecutive zero-render. This method gives a
  /// faster recovery (3s vs 6s) by acting immediately on the seek
  /// callsite.
  void _schedulePostSeekRecovery() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted || !activePlayer.state.playing || _disposed) return;
      final np = activePlayer.mediaKitPlayer?.platform;
      if (np is! NativePlayer) return;
      final decodedAfter = int.tryParse(
              await np
                  .getProperty('video-dec-params/decoded-frames')
                  .catchError((_) => '0')) ??
          0;
      // If decoder stalled
      if (decodedAfter == 0) {
        Log.w('Post-seek decoder stall detected '
            '(decoded=$decodedAfter, rendered=N/AAfter). '
            'Recreating activePlayer to reset MediaCodec state.');
        await _recreatePlayer();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return; // Guard: don't touch activePlayer after dispose
    if (state == AppLifecycleState.paused) {
      try {
        activePlayer.pause();
      } catch (e, st) {
        Log.e('activePlayer.pause() in lifecycle pause failed', e, st);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Refresh activePlayer state when returning to the app
      try {
        if (activePlayer.state.playing) {
          activePlayer.play();
        }
      } catch (e) {
        Log.w('Failed to refresh activePlayer on resume: $e');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true; // Set the disposal guard FIRST

    _renderWatchdog?.cancel();
    _renderWatchdog = null;
    _cancelPreloadOfNextEpisode();
    WidgetsBinding.instance.removeObserver(this);

    _updatesSubscription?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _saveTimer?.cancel();
    _preloadCooldownTimer?.cancel();

    try {
      final position = activePlayer.state.position.inSeconds;
      if (position > 0 && _settings.savePositionOnQuit) {
        _storageService.saveWatchPosition(widget.messageId, position);
        if (activePlayer.state.duration.inSeconds > 0) {
          _storageService.saveVideoDuration(
              widget.messageId, activePlayer.state.duration.inSeconds);
        }
        if (!_storageService.isIncognitoMode() &&
            widget.seriesName.isNotEmpty &&
            widget.currentEpisodeIndex != null) {
          _historyLog.addToHistory(
            seriesName: widget.seriesName,
            messageId: widget.messageId,
            episodeIndex: widget.currentEpisodeIndex!,
            episodeTitle:
                widget.videoTitle.replaceFirst('${widget.seriesName} - ', ''),
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
      _downloadController.resumeDownloadsAfterStreaming();
    } catch (e, st) {
      Log.e('Failed to resume downloads after streaming', e, st);
    }

    // Silence, pause, and stop the activePlayer immediately to halt all decoding
    // and audio output. Only call stop ONCE — the async microtask below
    // handles dispose.
    try {
      activePlayer.setVolume(0.0);
    } catch (e) { /* ignore */ }
    try {
      activePlayer.pause();
    } catch (e) { /* ignore */ }
    try {
      activePlayer.stop();
    } catch (e) { /* ignore */ }

    // Reset PipController active state first. If this activePlayer is the active
    // activePlayer, we call close() to clean up the state and set activePlayer
    // to null.
    final isActive = _pipController.activePlayer == _mediaKitPlayer;
    if (isActive) {
      _pipController.clearActivePlayer(_mediaKitPlayer);
    }

    // Wait a brief moment to see if another activePlayer took over (e.g. Next
    // Episode). If not, we are truly exiting the activePlayer and should reset
    // UI and Wakelock.
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      try {
        if (_pipController.activePlayer == null) {
          _resetOrientationAndUI();
          if (!widget.isPip) {
            try {
              WakelockPlus.disable();
            } catch (_) {}
          }
        }
      } catch (_) {}
    });

    // Dispose the activePlayer asynchronously — no need to call stop() again
    // since we already called it synchronously above.
    final p = activePlayer;
    Future.microtask(() async {
      try {
        p.dispose();
      } catch (e, st) {
        Log.e('Failed to dispose Player async', e, st);
      }
    });

    try {
      final fileId = _resolvedVideoFileId ?? widget.videoFileId;
      if (widget.networkUrl == null && fileId != 0) {
        final activeDownloads = ref.read(downloadControllerProvider);
        final isDownloadingPermanently = activeDownloads.containsKey(fileId);
        final pipState = ref.read(pipControllerProvider);
        final isCurrentlyPlaying =
            pipState != null && pipState.videoFileId == fileId;

        if (!isDownloadingPermanently && !isCurrentlyPlaying) {
          _tdlibService.send(
              td.CancelDownloadFile(fileId: fileId, onlyIfPending: false));
          Log.i(
              'Cancelled background download for inactive file $fileId on dispose');
        } else {
          Log.i(
              'Skipped CancelDownloadFile on dispose: file $fileId is still active (downloading permanently: $isDownloadingPermanently, playing: $isCurrentlyPlaying)');
        }
      }
    } catch (e, st) {
      Log.e('Failed to cancel active downloads on dispose', e, st);
    }

    _connectivitySubscription?.cancel();
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
      Log.i(
          'Preloading next episode (ID: $nextFileId) - low priority background download');
      _tdlibService.send(td.DownloadFile(
        fileId: nextFileId,
        priority: 32, // LOWEST priority — don't compete with active playback
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
      Log.i(
          'Playback buffered: Cancelling next episode background preload (ID: $nextFileId)');
      _tdlibService.send(td.CancelDownloadFile(
        fileId: nextFileId,
        onlyIfPending: false,
      ));

      // Start a 2-minute cooldown before resetting preloading status to
      // protect against infinite buffering-preloading loops
      _preloadCooldownTimer?.cancel();
      _preloadCooldownTimer = Timer(const Duration(minutes: 2), () {
        if (mounted && !_disposed) {
          Log.i(
              'Preloading cooldown complete. Resetting _nextEpisodePreloaded flag.');
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

      if (previous?.streamingProfile != next.streamingProfile) {
        _settings = next;
        _applyStreamingProfile();
      }

      if (previous?.hardwareDecoderMode != next.hardwareDecoderMode) {
        _settings = next;
        _recreatePlayer();
      }
      if (previous?.subtitles.subtitleRendererMode !=
          next.subtitles.subtitleRendererMode) {
        _settings = next;
        _recreatePlayer();
      }
      if (previous?.audio.dynamicRangeCompression !=
              next.audio.dynamicRangeCompression ||
          previous?.audio.equalizerEnabled !=
              next.audio.equalizerEnabled ||
          previous?.audio.equalizerBands != next.audio.equalizerBands) {
        _settings = next;
        needAudioFilterUpdate = true;
      }
      if (previous?.subtitles.subtitleFontSize !=
              next.subtitles.subtitleFontSize ||
          previous?.subtitles.subtitleColor !=
              next.subtitles.subtitleColor ||
          previous?.subtitles.subtitleDelay !=
              next.subtitles.subtitleDelay ||
          previous?.subtitles.subtitleFont != next.subtitles.subtitleFont) {
        _settings = next;
        needSubUpdate = true;
      }
      if (needAudioFilterUpdate) {
        PlayerFilterService.updateAudioFilters(_mediaKitPlayer, _settings);
      }
      if (needSubUpdate) {
        _updateSubtitleProperties();
      }
    });

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    

    Widget scaffold = Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              if (_disposed) return KeyEventResult.ignored;
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.space ||
                  key == LogicalKeyboardKey.keyK) {
                if (activePlayer.state.playing) {
                  activePlayer.pause();
                } else {
                  activePlayer.play();
                }
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowRight ||
                  key == LogicalKeyboardKey.keyL) {
                final seekTarget = activePlayer.state.position +
                    Duration(
                        seconds:
                            _settings.gestures.doubleTapSeekDuration);
                _handleCustomSeek(seekTarget);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowLeft ||
                  key == LogicalKeyboardKey.keyJ) {
                final seekTarget = activePlayer.state.position -
                    Duration(
                        seconds:
                            _settings.gestures.doubleTapSeekDuration);
                _handleCustomSeek(seekTarget);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowUp) {
                final newVol =
                    (activePlayer.state.volume + 5.0).clamp(0.0, 100.0);
                activePlayer.setVolume(newVol);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowDown) {
                final newVol =
                    (activePlayer.state.volume - 5.0).clamp(0.0, 100.0);
                activePlayer.setVolume(newVol);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.keyM) {
                if (activePlayer.state.volume > 0.0) {
                  activePlayer.setVolume(0.0);
                } else {
                  activePlayer.setVolume(100.0);
                }
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.escape) {
                try {
                  activePlayer.setVolume(0.0);
                  activePlayer.pause();
                  activePlayer.stop();
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
                if (_disposed) return;
                final dy = pointerSignal.scrollDelta.dy;
                if (dy < 0) {
                  // Scrolled up
                  final newVol =
                      (activePlayer.state.volume + 5.0).clamp(0.0, 100.0);
                  activePlayer.setVolume(newVol);
                } else if (dy > 0) {
                  // Scrolled down
                  final newVol =
                      (activePlayer.state.volume - 5.0).clamp(0.0, 100.0);
                  activePlayer.setVolume(newVol);
                }
              }
            },
            child: Center(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // BUG FOUND (Aug 3): ALWAYS mount the Video widget immediately.
                  // If we wait for activePlayer.open() to finish, the activePlayer starts decoding
                  // frames before the SurfaceTexture is bound, resulting in a black screen.
                  (widget.isPip
                      ? Video(
                          controller: _mediaKitController,
                          controls: NoVideoControls,
                          wakelock: false)
                                            : CustomVideoControls(
                          player: activePlayer,
                          videoSurfaceBuilder: (context, fit, customAspectRatio) {
                            // ── Engine-specific video surface (FIX 2025-08-04) ──────────
                            // Previously this builder checked exoPlayerController
                            // and vlcPlayer getters, but those returned null
                            // (base-class defaults) because the engine controllers
                            // didn't override them. The fallback to
                            // CachedVideoWidget(controller: _mediaKitController)
                            // crashed with LateInitializationError on ExoPlayer/VLC
                            // engines because _mediaKitController is only created
                            // for the media_kit engine path.
                            //
                            // Now we dispatch on engineName to pick the right
                            // widget, and return a black placeholder if the
                            // engine's controller isn't ready yet (before open()
                            // completes).
                            final engine = activePlayer.engineName;

                            if (engine == 'ExoPlayer') {
                              final exoCtl = activePlayer.exoPlayerController
                                  as VideoPlayerController?;
                              if (exoCtl != null && exoCtl.value.isInitialized) {
                                final size = exoCtl.value.size;
                                final fallback = (size.width > 0 && size.height > 0)
                                    ? size.width / size.height
                                    : 16.0 / 9.0;
                                return RepaintBoundary(
                                  child: AspectRatio(
                                    aspectRatio: customAspectRatio ?? fallback,
                                    child: VideoPlayer(exoCtl),
                                  ),
                                );
                              }
                              // ExoPlayer controller not ready yet — show black
                              // while initialize() runs. Do NOT fall through to
                              // media_kit (would crash: _mediaKitController is
                              // never created for the ExoPlayer engine).
                              return const ColoredBox(color: Colors.black);
                            }

                            if (engine == 'LibVLC') {
                              final vlcCtl =
                                  activePlayer.vlcPlayer as VlcPlayerController?;
                              if (vlcCtl != null) {
                                return RepaintBoundary(
                                  child: VlcPlayer(
                                    controller: vlcCtl,
                                    aspectRatio: customAspectRatio ?? 16 / 9,
                                    placeholder: const ColoredBox(color: Colors.black),
                                  ),
                                );
                              }
                              // VLC controller not ready yet — show black.
                              return const ColoredBox(color: Colors.black);
                            }

                            // media_kit (default engine).
                            return CachedVideoWidget(
                              controller: _mediaKitController,
                              fit: fit,
                              customAspectRatio: customAspectRatio,
                              subtitleConfig: const SubtitleViewConfiguration(visible: false),
                            );
                          },
                          isDesktop: widget.isDesktopMode,
                          videoTitle: pipState
                                  ?.queue[pipState.currentIndex]
                                  .videoTitle ??
                              widget.videoTitle,
                          isPip: false,
                          downloadedPrefixSize: _downloadedPrefixSize,
                          expectedSize: _expectedSize,
                          activeDownloadOffset: _activeDownloadOffset,
                          activeDownloadedSize: _activeDownloadedSize,
                          onBack: () {
                            try {
                              activePlayer.setVolume(0.0);
                              activePlayer.pause();
                              activePlayer.stop();
                            } catch (_) {}
                            _resetOrientationAndUI();
                            Navigator.of(context, rootNavigator: true).pop();
                          },
                          hasPrevEpisode: pipState != null &&
                              pipState.currentIndex > 0,
                          hasNextEpisode: pipState != null &&
                              pipState.currentIndex + 1 <
                                  pipState.queue.length,
                          onPrevEpisode: _playPreviousEpisode,
                          onNextEpisode: _playNextEpisode,
                          onSeek: _handleCustomSeek,
                          customBuffering: _isBuffering,
                          seriesName: pipState
                                  ?.queue[pipState.currentIndex]
                                  .seriesName ??
                              widget.seriesName,
                          currentEpisodeIndex:
                              pipState?.currentIndex ??
                                  widget.currentEpisodeIndex ??
                                  0,
                        )),
                  if (!_isPlaying)
                    Container(
                      color: Colors.black,
                      child: _isInitializing
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                CircularProgressIndicator(
                                    color: Colors.blueAccent),
                                SizedBox(height: 16),
                                Text(
                                    'Resolving video stream from Telegram...',
                                    style: TextStyle(color: Colors.white70)),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                    color: Colors.blueAccent),
                                const SizedBox(height: 16),
                                Text(
                                    AppLocalizations.of(context)!.bufferingStream,
                                    style: const TextStyle(color: Colors.white70)),
                                if (_expectedSize > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(
                                      '${(_activeDownloadedSize / 1024 / 1024).toStringAsFixed(1)} MB / ${(_expectedSize / 1024 / 1024).toStringAsFixed(1)} MB',
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  // ── Engine badge (FIX 2025-08-04) ────────────────────────
                  // Small overlay in the top-right corner showing the active
                  // engine name. This helps users visually distinguish which
                  // engine is running (previously all engines showed identical
                  // UI because they all fell through to media_kit's widget).
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          activePlayer.engineName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
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
            activePlayer.setVolume(0.0);
            activePlayer.pause();
            activePlayer.stop();
          } catch (e) { /* ignore */ }
          _resetOrientationAndUI();
        }
      },
      child: scaffold,
    );
  }

  void _applyStreamingProfile() {
    try {
      if ((activePlayer is MediaKitUnifiedController && _mediaKitPlayer.platform is NativePlayer)) {
        final nativePlayer = _mediaKitPlayer.platform as NativePlayer;
        final profile = _settings.streamingProfile;

        if (profile == 'Aggressive Buffer') {
          nativePlayer.setProperty(
              'demuxer-max-bytes', '629145600'); // 600 MB
          nativePlayer.setProperty(
              'demuxer-max-back-bytes', '209715200'); // 200 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '240');
          nativePlayer.setProperty('cache-pause-wait', '2');
          Log.i(
              'Applied Aggressive Buffer Profile: 600MB buffer, 200MB back buffer, 240s prefetch');
        } else if (profile == 'Mobile Saver') {
          nativePlayer.setProperty(
              'demuxer-max-bytes', '104857600'); // 100 MB
          nativePlayer.setProperty(
              'demuxer-max-back-bytes', '31457280'); // 30 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '75');
          nativePlayer.setProperty('cache-pause-wait', '6');
          Log.i(
              'Applied Mobile Saver Profile: 100MB buffer, 30MB back buffer, 75s prefetch');
        } else {
          // Balanced profile
          nativePlayer.setProperty(
              'demuxer-max-bytes', '314572800'); // 300 MB
          nativePlayer.setProperty(
              'demuxer-max-back-bytes', '104857600'); // 100 MB
          nativePlayer.setProperty('demuxer-readahead-secs', '150');
          nativePlayer.setProperty('cache-pause-wait', '4');
          Log.i(
              'Applied Balanced Profile: 300MB buffer, 100MB back buffer, 150s prefetch');
        }
      }
    } catch (e) {
      Log.w('Failed to apply streaming profile: $e');
    }
  }

  Future<void> _syncProgressToTrackers() async {
    if (widget.seriesName.isEmpty || widget.currentEpisodeIndex == null) {
      return;
    }
    final episodeNumber = widget.currentEpisodeIndex! + 1;
    final trackerService = ref.read(trackerServiceProvider);

    Log.i(
        '80% watched milestone reached. Syncing watch progress to enabled trackers for "${widget.seriesName}" Ep $episodeNumber');

    // 1. AniList
    if (_storageService.getAnilistToken()?.isNotEmpty == true) {
      try {
        final mediaId =
            await trackerService.searchAnilistId(widget.seriesName);
        if (mediaId != null) {
          final isCompleted = widget.episodeList != null &&
              episodeNumber == widget.episodeList!.length;
          final success = await trackerService.updateAnilistProgress(
            mediaId,
            episodeNumber,
            status: isCompleted ? 'COMPLETED' : 'CURRENT',
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!
                    .anilistProgressSynced(episodeNumber.toString())),
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
        final animeId =
            await trackerService.searchMalId(widget.seriesName);
        if (animeId != null) {
          final isCompleted = widget.episodeList != null &&
              episodeNumber == widget.episodeList!.length;
          final success = await trackerService.updateMalProgress(
            animeId,
            episodeNumber,
            status: isCompleted ? 'completed' : 'watching',
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!
                    .malProgressSynced(episodeNumber.toString())),
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
        final showSlug =
            await trackerService.searchTraktId(widget.seriesName);
        if (showSlug != null) {
          int seasonNum = 1;
          final match = RegExp(r'season\s*(\d+)', caseSensitive: false)
              .firstMatch(widget.videoTitle);
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
                content: Text(AppLocalizations.of(context)!
                    .traktProgressSynced(seasonNum.toString(),
                        episodeNumber.toString())),
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

  Future<void> _recreatePlayer() async {
    if (_disposed || _isRecreating) return; // Guard: no re-entrant recreates
    _isRecreating = true;

    try {
      final currentPos = activePlayer.state.position;
      final isPlayingState = activePlayer.state.playing;

      if (_isInitializing) {
        _isRecreating = false;
        return;
      }

      // Cancel all subscriptions and timers
      _updatesSubscription?.cancel();
      _saveTimer?.cancel();
      for (final sub in _subscriptions) {
        sub.cancel();
      }
      _subscriptions.clear();

      setState(() {
        _isInitializing = true;
        _isPlaying = false;
      });

      _pipController.clearActivePlayer(_mediaKitPlayer);

      try {
        await activePlayer.setVolume(0.0);
      } catch (e) { /* ignore */ }
      try {
        activePlayer.pause();
      } catch (e) { /* ignore */ }
      try {
        activePlayer.stop();
      } catch (e) { /* ignore */ }
      activePlayer.dispose();

      _initialTrackSelectionDone = false;
      // BUG FOUND (Aug 3): this was previously un-awaited, unlike the
      // initial call at line ~149. _initPlayerInstance() assigns `activePlayer`
      // synchronously up front, but assigns `controller` much later (after
      // several internal awaits for DeviceDetector/settings checks). Not
      // awaiting here meant _setupPlayerListeners()/activePlayer.open() below —
      // and the setState() after open() completes — could run before
      // `controller` was reassigned, leaving the widget tree bound to the
      // disposed old controller while the new decoder rendered into a
      // texture nobody was displaying. This is a real race: whichever
      // finishes first wins, which matches the intermittent (not 100%,
      // not 0%) black screen observed across today's logs.
      await _initPlayerInstance();
      _setupPlayerListeners();
      _startPeriodicSaveTimer(); // Restart the periodic save timer

      final fileId = _resolvedVideoFileId ?? widget.videoFileId;
      if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
        activePlayer.open(widget.networkUrl!, play: isPlayingState)
            .timeout(const Duration(seconds: 30))
            .then((_) {
          if (!mounted || _disposed) return;
          setState(() {
            _isPlaying = true;
            _isInitializing = false;
          });
          if (currentPos.inSeconds > 0) {
            if (activePlayer.state.duration.inSeconds > 0) {
              _handleCustomSeek(currentPos);
            } else {
              late final StreamSubscription<Duration> durSub;
              durSub = activePlayer.stream.duration.listen((dur) {
                if (dur.inSeconds > 0) {
                  durSub.cancel();
                  _subscriptions.remove(durSub);
                  if (mounted && !_disposed) {
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
        String mediaUrl =
            (localPath.isNotEmpty &&
                    cachedFile?.local.isDownloadingCompleted == true)
                ? localPath
                : _proxyService.getProxyUrl(fileId,
                    fileName: widget.videoTitle);

        if (StreamingProxyService.isProxyUrl(mediaUrl)) {
          // Proxy is started at app launch — no wait needed
          mediaUrl = _proxyService.getProxyUrl(fileId,
              fileName: widget.videoTitle);
        }

        final proxyHeaders =
            StreamingProxyService.isProxyUrl(mediaUrl)
                ? _proxyService.getAuthHeaders()
                : null;
        activePlayer.open(mediaUrl, httpHeaders: proxyHeaders, play: isPlayingState)
            .timeout(const Duration(seconds: 30))
            .then((_) {
          if (!mounted || _disposed) return;
          setState(() {
            _isPlaying = true;
            _isInitializing = false;
          });
          if (currentPos.inSeconds > 0) {
            if (activePlayer.state.duration.inSeconds > 0) {
              _handleCustomSeek(currentPos);
            } else {
              late final StreamSubscription<Duration> durSub;
              durSub = activePlayer.stream.duration.listen((dur) {
                if (dur.inSeconds > 0) {
                  durSub.cancel();
                  _subscriptions.remove(durSub);
                  if (mounted && !_disposed) {
                    _handleCustomSeek(currentPos);
                  }
                }
              });
              _subscriptions.add(durSub);
            }
          }
        });
      }
      if (!_disposed) {
        activePlayer.setVolume(100.0);
      }
    } catch (e, stack) {
      Log.e('Failed to recreate activePlayer', e, stack);
      if (mounted && !_disposed) {
        setState(() {
          _isInitializing = false;
          _isPlaying = false; // Fix: ensure _isPlaying is reset on error
        });
      }
    } finally {
      _isRecreating = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Render Watchdog — detects black-screen from decoder failures.
  //
  // Polls MPV every 1s for the first 30 seconds of playback. If we observe
  // "rendered frames == 0 AND decoded frames > 0" for 3 consecutive polls
  // while the activePlayer reports it is playing, we recreate the activePlayer with a
  // fallback decoder chain:
  //   Stage 0 (default): mediacodec-copy
  //   Stage 1: software (hwdec=no)
  //   Stage 2: exhausted — give up
  //
  // NOTE: The primary black-screen fix is the Impeller disable in
  // AndroidManifest.xml. This watchdog is a safety net for post-seek
  // MediaTek codec2 quirks and other edge cases.
  // ─────────────────────────────────────────────────────────────────────────
  Timer? _renderWatchdog;
  int _watchdogZeroRenderStreak = 0;
  int _watchdogFallbackStage = 0; // 0 = primary, 1 = software
  int _watchdogLastDecoded = 0;
  int _watchdogLastDropped = 0;
  static const int _watchdogMaxZeroRenderStreak = 3;
  static const Duration _watchdogDuration = Duration(seconds: 30);

  void _startRenderWatchdog() {
    _renderWatchdog?.cancel();
    _watchdogZeroRenderStreak = 0;
    _watchdogLastDecoded = 0;
    _watchdogLastDropped = 0;
    _renderWatchdog = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted || !activePlayer.state.playing || _disposed) return;
      try {
        final nativePlayer = activePlayer.mediaKitPlayer?.platform;
        if (nativePlayer is! NativePlayer) return;

        // ── Mode B: zero-render detection (continuous) ─────────────────
        // decoded-frames is cumulative, so track the delta since the last
        // poll to know whether the decoder is actively producing frames.
        final decodedStr = await nativePlayer
            .getProperty('video-dec-params/decoded-frames')
            .catchError((_) => '0');
        final decoded = int.tryParse(decodedStr) ?? 0;
        final decodedDelta = decoded - _watchdogLastDecoded;
        _watchdogLastDecoded = decoded;

        // frame-drop-count is mpv's own cumulative VO-level drop counter.
        // This is the Dart-visible equivalent of the "Drop:" figure MediaCodec
        // prints to logcat — when nearly every newly-decoded frame is also a
        // newly-dropped frame, that's the black-screen signature (decode
        // succeeds, nothing ever reaches the screen).
        final droppedStr = await nativePlayer
            .getProperty('frame-drop-count')
            .catchError((_) => '0');
        final dropped = int.tryParse(droppedStr) ?? 0;
        final droppedDelta = dropped - _watchdogLastDropped;
        _watchdogLastDropped = dropped;

        final blackScreenDetected =
            decodedDelta >= 10 && droppedDelta >= (decodedDelta - 2);

        if (blackScreenDetected) {
          _watchdogZeroRenderStreak++;
          Log.w('Render watchdog: zero-render streak='
              '$_watchdogZeroRenderStreak (decoded=+$decodedDelta, '
              'dropped=+$droppedDelta)');
        } else {
          _watchdogZeroRenderStreak = 0;
        }

        if (_watchdogZeroRenderStreak >= _watchdogMaxZeroRenderStreak) {
          Log.e('Render watchdog TRIGGERED — zero renders for '
              '$_watchdogMaxZeroRenderStreak seconds. '
              'decoded=+$decodedDelta, dropped=+$droppedDelta. '
              'Escalating decoder fallback (stage=$_watchdogFallbackStage).');
          t.cancel();
          _escalateDecoderFallback();
        }
      } catch (e) {
        Log.w('Render watchdog poll failed: $e');
      }
    });

    // Auto-stop after 30 seconds — if we got past the first 30 seconds of
    // playback without a black-screen event, the decoder is healthy.
    Future.delayed(_watchdogDuration, () {
      _renderWatchdog?.cancel();
      _renderWatchdog = null;
    });
  }

  void _escalateDecoderFallback() {
    _watchdogFallbackStage++;

    // Fix: Stage 0 = mediacodec-copy (default), Stage 1 = software.
    // Previous code had 3 stages (0, 1, 2) where stage 1 was also
    // mediacodec-copy — a no-op since that's already the default.
    if (_watchdogFallbackStage > 1) {
      Log.e('Render watchdog: exhausted all fallback stages. Giving up. '
          'Black screen will persist until the user manually changes the '
          'decoder setting or restarts the app.');
      _watchdogFallbackStage = 0;
      return;
    }
    // Stage 1: software decoding (hwdec=no)
    const stageName = 'no (software)';
    Log.w('Render watchdog: recreating activePlayer with hwdec=$stageName');

    // Temporarily override the stored setting for this activePlayer instance only.
    // We do NOT persist this — the user's setting stays as-is for next
    // launch, but this playback session uses the fallback.
    _watchdogOverrideHwdec = 'no';
    _recreatePlayer();
  }

  /// When non-null, [_initPlayerInstance] uses this value instead of the
  /// stored setting. Cleared on every successful playback start.
  String? _watchdogOverrideHwdec;

  Future<void> _initPlayerInstance() async {
    final localFont = ref.read(storageServiceProvider).localFontPath;

    // ── FIX (2025-08-04): Read videoEngine FRESH from the provider ──────
    // Previously this used `_settings.videoEngine`, but `_settings` was
    // captured once in initState() (line 156: `_settings = ref.read(...)`)
    // and never refreshed. If the user changed the engine in Settings →
    // closed and reopened the player, the stale cached value was used
    // instead of the newly-saved value. Reading fresh here ensures we
    // always honor the user's current engine choice.
    final currentEngine = ref.read(videoSettingsProvider).videoEngine;

    if (currentEngine == 'ExoPlayer') {
      final exo = ExoPlayerUnifiedController(
        httpHeaders: _currentHttpHeaders ?? {},
      );
      activePlayer = exo;
      // Note: _exoPlayerController is created lazily inside open(),
      // so the video view builder reads from activePlayer.exoPlayerController
      // at build time instead of this field. We keep the field for the
      // existing _settings.videoEngine == 'ExoPlayer' checks elsewhere.
      _exoPlayerController = null;
    } else if (currentEngine == 'LibVLC') {
      final vlc = VlcUnifiedController(
        httpHeaders: _currentHttpHeaders ?? {},
      );
      activePlayer = vlc;
      _vlcPlayerController = vlc.vlcController;
    } else {
      _mediaKitPlayer = Player(
        configuration: PlayerConfiguration(
          pitch: _settings.audio.pitchCorrection,
          libass: _settings.subtitles.subtitleRendererMode == 'native',
          libassAndroidFont:
              localFont ?? 'assets/fonts/Roboto-Regular.ttf',
          libassAndroidFontName: 'Roboto',
        ),
      );
      activePlayer = MediaKitUnifiedController(_mediaKitPlayer);
    }

    // media_kit-only configuration 
    if (activePlayer is! MediaKitUnifiedController) {
      return;
    }

    String actualHwdec = 'auto';
    try {
      if ((activePlayer is MediaKitUnifiedController && _mediaKitPlayer.platform is NativePlayer)) {
        final nativePlayer = _mediaKitPlayer.platform as NativePlayer;

        // ── Cache / buffering ──────────────────────────────────────────────
        // These values were validated by Hotfixes 4, 5, and 7. Do NOT change
        // them without re-testing on MediaTek Dimensity 6080.
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty(
            'demuxer-max-bytes', '209715200'); // 200 MB
        nativePlayer.setProperty(
            'demuxer-max-back-bytes', '52428800'); // 50 MB
        nativePlayer.setProperty('demuxer-readahead-secs', '180');

        // cache-pause-initial MUST stay 'no' on Android. If set to 'yes',
        // MPV pauses on first frame waiting for buffer fill, which prevents
        // the first frame from reaching the SurfaceTexture → black screen
        // on MediaTek (see Hotfix 4 / v2.13.7+63).
        nativePlayer.setProperty('cache-pause', 'yes');
        nativePlayer.setProperty('cache-pause-initial', 'no');
        nativePlayer.setProperty('cache-pause-wait', '2');
        nativePlayer.setProperty('cache-secs', '180');
        nativePlayer.setProperty('hr-seek', 'no');

        // ── Audio ──────────────────────────────────────────────────────────
        // audio-buffer MUST stay 0.2 on mobile. Hotfix 5 (v2.13.7+64) proved
        // that 1.0 causes MediaCodec to drop 100% of video frames because
        // the audio clock falsely reports the video as permanently lagging.
        nativePlayer.setProperty('audio-pitch-correction', 'yes');
        nativePlayer.setProperty('audio-buffer', '0.2');

        // ── Video sync / interpolation ─────────────────────────────────────
        // CRITICAL FIX: motion interpolation + display-resample is a desktop
        // feature. On mobile, it requires a stable display-refresh signal
        // which MediaTek Dimensity 6080 does NOT reliably provide (especially
        // under battery-saver or 60↔90 Hz dynamic switching). When the vsync
        // source is unstable, MPV silently disables the VO → black screen.
        //
        // Mobile uses MPV's default 'audio' sync, which is rock-solid and
        // has zero dependency on the display subsystem.
        if (!Platform.isAndroid && !Platform.isIOS) {
          nativePlayer.setProperty('video-sync', 'display-resample');
          nativePlayer.setProperty('interpolation', 'yes');
          nativePlayer.setProperty('tscale', 'oversample');
        }
        // Mobile: explicitly set 'audio' sync so any inherited mpv.conf
        // default doesn't sneak in a broken display-* mode.
        if (Platform.isAndroid || Platform.isIOS) {
          nativePlayer.setProperty('video-sync', 'audio');
          nativePlayer.setProperty('interpolation', 'no');
        }

        // framedrop=vo is REQUIRED on Android (Hotfix 7 / v2.13.7+66).
        // 'decoder' tells MediaCodec to drop 100% of frames; 'vo' lets the
        // VO decide, which is what we want.
        nativePlayer.setProperty('framedrop', 'vo');
        nativePlayer.setProperty('sub-fix-timing', 'yes');
        nativePlayer.setProperty(
            'stream-buffer-size', '16777216'); // 16 MB

        // ── Software decoder fallback tuning ───────────────────────────────
        // These only run if HW decoding fails and MPV falls back to lavc.
        nativePlayer.setProperty('vd-lavc-fast', 'yes');
        nativePlayer.setProperty(
            'vd-lavc-skiploopfilter', 'default');
        nativePlayer.setProperty('vd-lavc-check-hw-profile', 'no');
        nativePlayer.setProperty('vd-lavc-threads', '0');
        nativePlayer.setProperty('vd-lavc-show-all', 'no');
        nativePlayer.setProperty('vd-lavc-er', 'careful');
        if (!Platform.isAndroid && !Platform.isIOS) {
          nativePlayer.setProperty('hwdec-extra-frames', '64');
        }

        // ── Hardware decoder selection ─────────────────────────────────────
        // v4 uses `hwdec=mediacodec-copy` by default on Android, which
        // routes frames through mpv's gpu VO for tone-mapping (HDR→SDR).
        //
        // With Impeller disabled (AndroidManifest.xml), the Skia renderer
        // correctly composites textures from media_kit. With
        // enableHardwareAcceleration=false in VideoControllerConfiguration
        // (set below), the Video widget uses the CPU pixel buffer path,
        // which correctly receives frames from mpv's GPU VO output.
        //
        // We keep `mediacodec-copy` as the default because it enables
        // tone-mapping.
        final storedHwdec = _watchdogOverrideHwdec ??
            _storageService.getHardwareDecoderMode();
        _watchdogOverrideHwdec = null; // consume the override

        if (Platform.isAndroid) {
          final isMediaTek = await DeviceDetector.isMediaTekSoC;
          final socDesc = await DeviceDetector.socDescription;
          Log.i('SoC: $socDesc (isMediaTek=$isMediaTek)');

          String safeMode;
          if (_watchdogFallbackStage > 0) {
            // Watchdog is in fallback mode — respect its override.
            safeMode = storedHwdec;
          } else if (storedHwdec == 'no') {
            safeMode = 'no';
          } else {
            safeMode = 'mediacodec-copy';
          }

          if (safeMode != 'no') {
            nativePlayer.setProperty('hwdec', safeMode);
            // CRITICAL FIX: explicitly force vo=gpu to fix black screen.
            // This was removed on July 30 and caused 3 days of black screens
            // because it allowed mpv to choose the wrong video output.
            // nativePlayer.setProperty('vo', 'gpu'); // V4 FIX: explicit vo=gpu requires Impeller to be ENABLED so it doesn't crash Skia! // REMOVED to prevent initialization crash
            actualHwdec = safeMode;
            Log.i('Set hardware decoder mode to $safeMode + vo=gpu on activePlayer init (Android)');
          } else {
            nativePlayer.setProperty('hwdec', 'no');
            actualHwdec = 'no';
            Log.i('Hardware decoder mode is disabled (no) on activePlayer init');
          }

          // ── Explicit codec allowlist ─────────────────────────────────────
          // Only applied when hardware decoding is active (not for sw).
          // Tells MediaCodec exactly which codecs it is allowed to claim.
          if (safeMode != 'no') {
            nativePlayer.setProperty(
              'hwdec-codecs',
              'h264,hevc,vp9,mpeg4,mpegvideo',
            );
          }

          // ── HDR → SDR tone-mapping ──────────────────────────────────────
          // With `mediacodec-copy`, frames go through mpv's gpu VO which
          // applies these tone-mapping properties. For SDR content they are
          // no-ops (same primaries/transfer). For HDR content they convert
          // PQ → BT.1886 SDR so Skia can display the frames via the CPU
          // pixel buffer path.
          if (_storageService.getHdrToneMappingEnabled()) {
            nativePlayer.setProperty('target-prim', 'bt709');
            nativePlayer.setProperty('target-trc', 'bt1886');
            nativePlayer.setProperty('tone-mapping', 'mobius');
            nativePlayer.setProperty('tone-mapping-param', '0.85');
            nativePlayer.setProperty('hdr-compute-peak', 'yes');
            nativePlayer.setProperty('target-colorspace-hint', 'no');
            nativePlayer.setProperty('gamma-auto', 'no');
            Log.i('HDR tone-mapping properties applied: target=BT.709/'
                'BT.1886, algorithm=mobius (knee=0.85), '
                'hdr-compute-peak=yes');
          } else {
            Log.i('HDR tone-mapping disabled by user setting.');
          }

          // ── Software decoder tuning ────────────────────────────────────
          // When hwdec=no (user choice or watchdog fallback), these
          // settings ensure libavcodec uses all available cores.
          if (safeMode == 'no') {
            nativePlayer.setProperty('vd-lavc-threads', '8');
            nativePlayer.setProperty('vd-lavc-fast', 'yes');
            nativePlayer.setProperty(
                'vd-lavc-skiploopfilter', 'nonref');
          }
        } else {
          // Desktop path — unchanged from original logic.
          String safeMode = storedHwdec;
          if (Platform.isWindows) {
            // Windows green-glitch fix: d3d11va-copy produces YUV RGB mismatches
            safeMode = 'no';
          } else if (Platform.isLinux || Platform.isMacOS) {
            if (safeMode == 'auto' || safeMode == 'auto-copy') {
              safeMode = 'vaapi-copy';
            } else if (safeMode == 'mediacodec-copy' ||
                safeMode == 'mediacodec') {
              safeMode = 'vaapi-copy';
            } else if (safeMode == 'd3d11va' ||
                safeMode == 'd3d11va-copy') {
              safeMode = 'vaapi-copy';
            }
          }
          nativePlayer.setProperty('hwdec', safeMode);
          actualHwdec = safeMode; // Save for VideoController creation below
          Log.i('Set hardware decoder mode to $safeMode on activePlayer init (PC)');
        }

        // ── Subtitles (libass) ─────────────────────────────────────────────
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
        nativePlayer.setProperty(
            'sub-visibility',
            _settings.subtitles.subtitleRendererMode == 'native'
                ? 'yes'
                : 'no');
        nativePlayer.setProperty('sub-auto', 'all');
        nativePlayer.setProperty('embeddedfonts', 'yes');
        nativePlayer.setProperty('blend-subtitles', 'no');
        nativePlayer.setProperty(
            'demuxer-mkv-subtitle-preroll', 'yes');
        nativePlayer.setProperty(
            'demuxer-mkv-subtitle-preroll-secs', '10');
        nativePlayer.setProperty('sub-ass-override', 'force');
        nativePlayer.setProperty('sub-codepage', 'utf-8');
        nativePlayer.setProperty('sub-scale-with-window', 'yes');
        nativePlayer.setProperty('sub-ass-force-margins', 'yes');

        // Load subtitle customizations dynamically.
        _updateSubtitleProperties();

        final volBoost = _storageService.getVolumeBoostEnabled();
        if (volBoost) {
          nativePlayer.setProperty('volume-max', '200');
        }

        // Apply audio filters (DRC & Equalizer).
        PlayerFilterService.updateAudioFilters(_mediaKitPlayer, _settings);

        // Apply adaptive streaming profile.
        _applyStreamingProfile();

        // Apply custom MPV options (user-supplied via Settings → Advanced).
        final customOpts = _settings.customMpvOptions;
        if (customOpts.isNotEmpty) {
          final pairs = _parseMpvOptions(customOpts);
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
      Log.e('Failed to configure native activePlayer features', e, stack);
    }

    // ── VideoController creation ───────────────────────────────────────────
    // enableHardwareAcceleration controls whether media_kit creates an EGL
    // SurfaceTexture for the Video widget.
    //
    // The correct value depends on the hwdec mode that was actually set above:
    //
    //   hwdec=mediacodec (zero-copy):
    //     MediaCodec decodes directly INTO the Video widget's SurfaceTexture.
    //     enableHardwareAcceleration MUST be true — the SurfaceTexture IS the
    //     output surface. Setting it to false would break the zero-copy path.
    //
    //   hwdec=mediacodec-copy (copy-back):
    //     MediaCodec decodes to its own SurfaceTexture, then mpv copies the
    //     frames through its GPU VO for tone-mapping. The output goes to mpv's
    //     internal GL framebuffer, NOT to the Video widget's EGL SurfaceTexture.
    //     enableHardwareAcceleration MUST be false — the Video widget must use
    //     the CPU pixel buffer path, which correctly receives frames from mpv's
    //     GPU VO output. Setting it to true creates an EGL SurfaceTexture that
    //     never receives frames → black screen on Mali-G57 MC2 and similar GPUs.
    //
    //   hwdec=no (software):
    //     Frames are decoded by libavcodec and go through mpv's GPU VO → CPU
    //     buffer. Same as mediacodec-copy: enableHardwareAcceleration MUST be
    //     false.
    //
    // On desktop, this is always true — setting it to false causes the black
    //     screen bug because mpv's decoded frames never reach the Flutter Video
    //     widget.
    //
    // NOTE: We use actualHwdec (the mode that was actually set on the native
    // activePlayer) rather than the stored setting, because the code above may
    // override the stored setting (e.g., forcing mediacodec-copy on Android).


    // Defer to after the widget tree finishes building — Riverpod forbids
    // modifying providers during initState/build.
    // Desktop platforms and normal Android devices use hardware acceleration natively.
    // On Windows, software decode (hwdec=no) must use the CPU pixel buffer
    final enableHw = !Platform.isWindows;

    // Defer to after the widget tree finishes building - Riverpod forbids
    // modifying providers during initState/build.
    Future.microtask(() {
      if (mounted && !_disposed) {
        _pipController.setActivePlayer(_mediaKitPlayer);
      }
    });

    try {
      _mediaKitController = VideoController(
      _mediaKitPlayer,
        configuration: VideoControllerConfiguration(
          // IMPORTANT: media_kit_video's own docs (VideoControllerConfiguration
          // in platform_video_controller.dart) state the default for `hwdec`
          // on Android is `auto-safe`, NOT whatever was set via
          // nativePlayer.setProperty('hwdec', ...) above. Leaving this out
          // silently lets VideoController creation reset the decoder mode
          // away from the mediacodec-copy we deliberately chose.
          // hwdec: actualHwdec, // REMOVED: causes media_kit to crash on init! Let it use auto-safe, we re-apply via safety net below.
          enableHardwareAcceleration: enableHw,
        ),
      );

      // Safety net: re-apply hwdec after VideoController creation, in case
      // creating the controller reset it back to VideoControllerConfiguration's
      // own default (auto-safe on Android).
      if ((activePlayer is MediaKitUnifiedController && _mediaKitPlayer.platform is NativePlayer)) {
        (activePlayer.mediaKitPlayer?.platform as NativePlayer).setProperty('hwdec', actualHwdec);
      }
    } catch (e, st) {
      Log.e('Failed to create VideoController. Disposing activePlayer.', e, st);
      // Use the fresh engine value, not the stale _settings cache.
      if (currentEngine == 'ExoPlayer') {
        _exoPlayerController?.dispose();
      } else if (currentEngine == 'LibVLC') {
        _vlcPlayerController?.dispose();
      } else {
        activePlayer.mediaKitPlayer?.dispose();
      }
      activePlayer.dispose();
      rethrow;
    }

    // Start the render watchdog once the controller is wired up. It will
    // auto-cancel after 30 seconds if rendering is healthy.
    _startRenderWatchdog();
  }

  List<String> _parseMpvOptions(String raw) {
    if (raw.trim().isEmpty) return const [];
    final result = <String>[];
    final buf = StringBuffer();
    int bracketDepth = 0;
    for (int i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == '[' || c == '(') bracketDepth++;
      if (c == ']' || c == ')') {
        bracketDepth = (bracketDepth > 0) ? bracketDepth - 1 : 0;
      }
      if (c == ',' && bracketDepth == 0) {
        final opt = buf.toString().trim();
        if (opt.isNotEmpty) result.add(opt);
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    final last = buf.toString().trim();
    if (last.isNotEmpty) result.add(last);
    return result;
  }

  void _setupPlayerListeners() {
    _subscriptions.add(activePlayer.stream.playing.listen((playing) async {
      if (_disposed) return;
      if (playing) {
        if (!widget.isPip) {
          try {
            // Force reset WakelockPlus internal boolean cache by disabling
            // first
            await WakelockPlus.disable();
            await WakelockPlus.enable();
          } catch (_) {}
        }
      } else {
        // When paused, wait 60 seconds before disabling Wakelock
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted && !_disposed && !activePlayer.state.playing && !widget.isPip) {
            try {
              WakelockPlus.disable();
            } catch (_) {}
          }
        });
      }
    }));

    final mpv = activePlayer.mediaKitPlayer;
    if (mpv != null) {
      _subscriptions.add(mpv.stream.tracks.listen((tracks) {
        if (_disposed) return;
        if (tracks.audio.isEmpty && tracks.subtitle.isEmpty) return;
        if (_initialTrackSelectionDone) return;
        _initialTrackSelectionDone = true;

      // 1. Select the audio track based on global preference
      final prefAudio = _storageService.getPreferredAudioTrack();
      AudioTrack? targetAudioTrack;
      if (prefAudio != null && prefAudio != 'auto') {
        for (final track in tracks.audio) {
          final identifier =
              (track.language ?? track.title ?? track.id)
                  .toLowerCase();
          if (identifier == prefAudio.toLowerCase() ||
              (track.title != null &&
                  track.title!.toLowerCase().contains(prefAudio.toLowerCase())) ||
              (track.language != null &&
                  track.language!.toLowerCase().contains(prefAudio.toLowerCase()))) {
            targetAudioTrack = track;
            break;
          }
        }
      }

      // Apply audio track if resolved and not already set
      if (targetAudioTrack != null &&
          activePlayer.mediaKitPlayer?.state.track.audio != targetAudioTrack) {
        activePlayer.mediaKitPlayer?.setAudioTrack(targetAudioTrack);
        Log.i(
            'Auto-selected preferred audio track: ${targetAudioTrack.title ?? targetAudioTrack.language ?? targetAudioTrack.id}');
      } else {
        targetAudioTrack = activePlayer.mediaKitPlayer?.state.track.audio;
      }

      // 2. Classify audio language category for sub/dub logic
      String audioLangCategory = 'other';
      final track = targetAudioTrack;
      if (track == null) return;
      final lower = (track.language ?? track.title ?? '').toLowerCase();
      if (lower.contains('jpn') ||
          lower.contains('ja') ||
          lower.contains('japanese')) {
        audioLangCategory = 'jpn';
      } else if (lower.contains('eng') ||
          lower.contains('en') ||
          lower.contains('english')) {
        audioLangCategory = 'eng';
      }

      // 3. Select subtitle track based on the audio language preference
      final prefSub = _storageService
          .getPreferredSubtitleTrackForAudioLanguage(audioLangCategory);
      bool matchedSub = false;
      SubtitleTrack? selectedTrack;

      if (prefSub != null) {
        if (prefSub == 'no') {
          selectedTrack = SubtitleTrack.no();
          if (activePlayer.mediaKitPlayer?.state.track.subtitle != selectedTrack) {
            activePlayer.mediaKitPlayer?.setSubtitleTrack(selectedTrack);
          }
          matchedSub = true;
        } else {
          for (final track in tracks.subtitle) {
            final identifier =
                (track.language ?? track.title ?? track.id)
                    .toLowerCase();
            if (identifier == prefSub.toLowerCase() ||
                (track.title != null &&
                    track.title!.toLowerCase().contains(prefSub.toLowerCase())) ||
                (track.language != null &&
                    track.language!.toLowerCase().contains(prefSub.toLowerCase()))) {
              selectedTrack = track;
              if (activePlayer.mediaKitPlayer?.state.track.subtitle != track) {
                activePlayer.mediaKitPlayer?.setSubtitleTrack(track);
                Log.i(
                    'Automatically applied preferred subtitle track ($prefSub) for audio language category ($audioLangCategory)');
              }
              matchedSub = true;
              break;
            }
          }
        }
      }

      // 4. Default smart fallbacks if no user preference is saved
      if (!matchedSub) {
        final currentSub = activePlayer.mediaKitPlayer?.state.track.subtitle;
        final subId = currentSub?.id;
        if (subId == 'no' || subId == 'auto') {
          if (audioLangCategory == 'eng') {
            // English audio (Dub) -> Default to forced/signs/songs subtitles
            // if available, otherwise disabled
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
            if (activePlayer.mediaKitPlayer?.state.track.subtitle != targetTrack) {
              activePlayer.mediaKitPlayer?.setSubtitleTrack(targetTrack);
              Log.i(
                  'Smart Sub/Dub default: English audio -> Target subtitle track: ${targetTrack.title ?? targetTrack.id}');
            }
          } else {
            // Japanese / other audio (Sub) -> Default to English subtitle
            // if available
            if (tracks.subtitle.isNotEmpty) {
              SubtitleTrack? targetSubTrack;
              for (final track in tracks.subtitle) {
                final lower = (track.language ?? track.title ?? '')
                    .toLowerCase();
                if (lower.contains('eng') ||
                    lower.contains('en') ||
                    lower.contains('english')) {
                  targetSubTrack = track;
                  break;
                }
              }
              targetSubTrack ??= tracks.subtitle.firstWhere(
                (t) => t.id != 'no' && t.id != 'auto',
                orElse: () => tracks.subtitle.first,
              );
              selectedTrack = targetSubTrack;
              if (activePlayer.mediaKitPlayer?.state.track.subtitle != targetSubTrack) {
                activePlayer.mediaKitPlayer?.setSubtitleTrack(targetSubTrack);
                Log.i(
                    'Smart Sub/Dub default: $audioLangCategory audio -> English/fallback subtitle: ${targetSubTrack.language ?? targetSubTrack.title ?? targetSubTrack.id}');
              }
            }
          }
        }
      }

      // Update blend-subtitles based on selected track codec
      final mpv2 = activePlayer.mediaKitPlayer;
      if (mpv2 != null) {
        final sub = selectedTrack ?? mpv2.state.track.subtitle;
        PlayerFilterService.updateBlendSubtitlesForTrack(mpv2, sub);
      }
    }));
    }

    _subscriptions.add(activePlayer.stream.buffering.listen((buffering) {
      if (_disposed) return;
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

  void _updateSubtitleProperties() {
    if (_disposed) return;
    if ((activePlayer is MediaKitUnifiedController && _mediaKitPlayer.platform is NativePlayer)) {
      final nativePlayer = _mediaKitPlayer.platform as NativePlayer;
      nativePlayer.setProperty('sub-font-size',
          _settings.subtitles.subtitleFontSize.round().toString());
      nativePlayer.setProperty(
          'sub-color', _settings.subtitles.subtitleColor);
      nativePlayer.setProperty('sub-delay',
          _settings.subtitles.subtitleDelay.toString());

      String resolvedFontFamily = 'Roboto';
      final fontName = _settings.subtitles.subtitleFont.toLowerCase();
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
      Log.i(
          'Updated subtitle settings dynamically: size=${_settings.subtitles.subtitleFontSize}, color=${_settings.subtitles.subtitleColor}, delay=${_settings.subtitles.subtitleDelay}, font=$resolvedFontFamily');
    }
  }
}
