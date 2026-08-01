import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
    
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (!isConnected && _wasNetworkConnected) {
        Log.w('Network disconnected — pausing playback');
        _userPaused = !player.state.playing;
        try { player.pause(); } catch (_) {}
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
          try { player.play(); } catch (_) {}
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
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        if (_settings.savePositionOnQuit && player.state.position.inSeconds > 0 && player.state.playing) {
          _storageService.saveWatchPosition(widget.messageId, player.state.position.inSeconds);
          if (player.state.duration.inSeconds > 0) {
            _storageService.saveVideoDuration(widget.messageId, player.state.duration.inSeconds);
          }
          if (!_storageService.isIncognitoMode() && widget.seriesName.isNotEmpty && widget.currentEpisodeIndex != null) {
            _historyLog.addToHistory(
              seriesName: widget.seriesName,
              messageId: widget.messageId,
              episodeIndex: widget.currentEpisodeIndex!,
              episodeTitle: widget.videoTitle.replaceFirst('${widget.seriesName} - ', ''),
              positionInSeconds: player.state.position.inSeconds,
              videoFileId: _resolvedVideoFileId ?? widget.videoFileId,
            );
          }
        }
      } catch (e, st) {
        Log.e('Failed to save watch position in periodic timer', e, st);
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
      }();
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
      
      // Call Wakelock after SystemChrome, as SystemChrome can clear window flags on Android
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (mounted) {
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
      // Episode changed on Desktop (reusing player)
      // Defer to after the widget tree finishes building — Riverpod forbids
      // modifying providers during didUpdateWidget.
      Future.microtask(() {
        if (mounted) {
          _pipController.setActivePlayer(player);
        }
      });
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
      }).catchError((Object e, StackTrace st) {
        Log.e('player.stop() failed during episode change', e, st);
        if (mounted) {
          _recreatePlayer(); // Force-recreate the player if stop failed.
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

    // Reset HDR fallback flag for the new playback session. The watchdog
    // will re-detect HDR content and apply the fallback if needed.
    _hdrFallbackApplied = false;

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
    // after the player reports the duration.
    final shouldPlayImmediately = savedPos <= 0;

    final proxyHeaders = StreamingProxyService.isProxyUrl(finalPath) ? _proxyService.getAuthHeaders() : null;
    player.open(Media(finalPath, httpHeaders: proxyHeaders), play: shouldPlayImmediately)
        .timeout(const Duration(seconds: 30))
        .then((_) {
      if (!mounted) return;
      if (savedPos > 0) {
        Future<void> performRobustStartupSeek(Duration knownDuration) async {
          // If savedPos is >= 95% of duration, restart from beginning
          // (video was already watched to the end)
          if (knownDuration.inSeconds > 0 &&
              savedPos >= (knownDuration.inSeconds * 0.95).toInt()) {
            Log.i('savedPos ($savedPos) is near end of video (duration ${knownDuration.inSeconds}s), restarting from beginning');
            if (mounted) {
              player.play();
              setState(() {
                _isInitializing = false;
              });
            }
            return;
          }
          // Reduced from 5 to 2 retries — each retry calls abortActiveRequests
          // which can cause HttpException flood if set too high.
          for (int i = 0; i < 2; i++) {
            if (!mounted) return;
            
            // Abort any active proxy reads to free the mpv thread so player.seek won't deadlock
            final fileId = _resolvedVideoFileId ?? widget.videoFileId;
            if (fileId != 0) {
              _proxyService.abortActiveRequests(fileId);
            }
            
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
          performRobustStartupSeek(player.state.duration);
        } else {
          late final StreamSubscription<Duration> durSub;
          durSub = player.stream.duration.listen((dur) {
            if (dur.inSeconds > 0) {
              durSub.cancel();
              _subscriptions.remove(durSub);
              if (mounted) {
                performRobustStartupSeek(dur);
              }
            }
          });
          _subscriptions.add(durSub);
        }
      } else {
        if (mounted) {
          // Explicit play() needed on PC (software decoding) — 
          // play: true in player.open() doesn't always auto-start on PC
          try {
            player.play();
          } catch (e) {
            Log.w('player.play() after open failed: $e');
          }
          setState(() {
            _isInitializing = false;
          });
        }
      }
    }).catchError((Object e, StackTrace st) {
      Log.e('player.open() failed for $finalPath', e, st);
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.unableToOpenVideo(e.toString())),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });
    player.setVolume(100.0);
  }

  void _listenToUpdates() {
    _updatesSubscription?.cancel();
    _updatesSubscription = _tdlibService.updates.listen((event) {
      try {
        if (event is td.UpdateFile) {
          final fileId = _resolvedVideoFileId;
          if (fileId == null || event.file.id != fileId) return;
          final localPath = event.file.local.path;
          
          final now = DateTime.now();
          if (_lastUpdateTime == null || now.difference(_lastUpdateTime!).inMilliseconds > 500 || event.file.local.isDownloadingCompleted) {
            _lastUpdateTime = now;
            if (mounted) {
              setState(() {
                _downloadedPrefixSize = event.file.local.downloadedPrefixSize;
                _expectedSize = event.file.expectedSize;
                _activeDownloadOffset = _proxyService.getActiveDownloadOffset(fileId);
                final baseDownloaded = _proxyService.getDownloadedSizeAtOffset(fileId);
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
            _initialDownloadedSize = null;
            if (mounted) {
              setState(() {
                _isBuffering = false;
              });
            }
            player.seek(seekTarget).then((_) {
              if (mounted) {
                try { player.play(); } catch (e, st) { Log.e('player.play() after seek failed', e, st); }
              }
            }).catchError((Object e, StackTrace st) {
              Log.e('player.seek() to $seekTarget failed', e, st);
              if (mounted) {
                try { player.play(); } catch (_) {}
              }
            });
          }
        }
      } // Close if (event is td.UpdateFile)
    } catch (e, st) {
      Log.e('Error processing TDLib update in player', e, st);
    }
  });
}

  Future<void> _initDownload() async {
    if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
      // Reset HDR fallback flag for the new playback session.
      _hdrFallbackApplied = false;
      if (mounted) {
        setState(() {
          _resolvedVideoFileId = widget.videoFileId;
          _isPlaying = true;
          _isInitializing = false;
        });
      }
      player.open(Media(widget.networkUrl!), play: true)
          .timeout(const Duration(seconds: 30))
          .catchError((Object e, StackTrace st) {
        Log.e('player.open() failed for network URL ${widget.networkUrl}', e, st);
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _isInitializing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToLoadNetworkStream(e.toString())),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      });
      player.setVolume(100.0);
      return;
    }

    _resolvedVideoFileId = widget.videoFileId;

    // Check if the original file ID already has a completed download.
    // If yes, skip fresh file ID resolution and use the original.
    final originalFile = _proxyService.getCachedFile(widget.videoFileId);
    if (originalFile != null &&
        originalFile.local.path.isNotEmpty &&
        originalFile.local.isDownloadingCompleted) {
      Log.i('Original file ID ${widget.videoFileId} already fully downloaded, skipping fresh file ID resolution');
      _resolvedVideoFileId = widget.videoFileId;
      _startPlayback(originalFile.local.path);
      if (!_nextEpisodePreloaded) {
        _nextEpisodePreloaded = true;
        _preloadNextEpisode();
      }
      return;
    }

    // Pre-emptively resolve the fresh file ID from TDLib to prevent stale file ID errors
    Log.i('Resolving fresh file ID for message ${widget.messageId}...');
    int? freshFileId;

    // PREFERRED PATH: use widget.chatId directly (works for user-added channels too).
    if (widget.chatId != null && widget.chatId! != 0) {
      try {
        final res = await _tdlibService.sendAsync(td.GetMessage(
          chatId: widget.chatId!,
          messageId: widget.messageId,
        )).timeout(const Duration(seconds: 3));
        if (res is td.Message) {
          if (res.content is td.MessageVideo) {
            freshFileId = (res.content as td.MessageVideo).video.video.id;
          } else if (res.content is td.MessageDocument) {
            freshFileId = (res.content as td.MessageDocument).document.document.id;
          }
          if (freshFileId != null && freshFileId != 0) {
            Log.i('Resolved fresh file ID $freshFileId via chatId=${widget.chatId} for message ${widget.messageId}');
          }
        }
      } catch (e) {
        Log.w('Failed to resolve file ID via chatId=${widget.chatId}: $e');
      }
    }

    // FALLBACK PATH: iterate Constants.categories + user-added channels.
    // This preserves backwards compatibility for callers that don't pass chatId.
    if (freshFileId == null || freshFileId == 0) {
      // 1. Try the 3 hardcoded categories.
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
              Log.i('Resolved fresh file ID $freshFileId via Constants.categories[${category.title}] for message ${widget.messageId}');
              break;
            }
          }
        } catch (e) {
          Log.w('Failed to check category ${category.title} for message ${widget.messageId}: $e');
        }
      }
    }

    if (freshFileId == null || freshFileId == 0) {
      // 2. Try user-added channels.
      try {
        final userChannels = ref.read(userChannelsProvider);
        for (final uc in userChannels) {
          try {
            final res = await _tdlibService.sendAsync(td.GetMessage(
              chatId: uc.channelId,
              messageId: widget.messageId,
            )).timeout(const Duration(seconds: 3));
            if (res is td.Message) {
              if (res.content is td.MessageVideo) {
                freshFileId = (res.content as td.MessageVideo).video.video.id;
              } else if (res.content is td.MessageDocument) {
                freshFileId = (res.content as td.MessageDocument).document.document.id;
              }
              if (freshFileId != null && freshFileId != 0) {
                Log.i('Resolved fresh file ID $freshFileId via user channel ${uc.title} for message ${widget.messageId}');
                break;
              }
            }
          } catch (e) {
            Log.w('Failed to check user channel ${uc.title} for message ${widget.messageId}: $e');
          }
        }
      } catch (e) {
        Log.w('Failed to read userChannelsProvider during file ID resolution: $e');
      }
    }

    if (freshFileId != null && freshFileId != 0) {
      _resolvedVideoFileId = freshFileId;
    } else {
      // Last resort: keep widget.videoFileId. Log loudly so the user can report.
      Log.e('Could not resolve fresh file ID for message ${widget.messageId} (chatId=${widget.chatId}). Falling back to widget.videoFileId=${widget.videoFileId}. Playback will likely fail.');
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
      _schedulePostSeekRecovery();
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
        _proxyService.abortActiveRequests(fileId);
        player.seek(position);
        _schedulePostSeekRecovery();
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

      // Forcefully abort any active streaming proxy requests for this file to free up the mpv thread.
      // If mpv is blocked waiting for an HTTP read from the proxy, player.seek() will block the Dart main isolate!
      _proxyService.abortActiveRequests(fileId);

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
  /// recreate the player (which creates a fresh MediaCodec instance).
  ///
  /// The watchdog's Mode B detection also catches this case, but only
  /// after 3 seconds of consecutive zero-render. This method gives a
  /// faster recovery (3s vs 6s) by acting immediately on the seek
  /// callsite.
  void _schedulePostSeekRecovery() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted || !player.state.playing) return;
      final np = player.platform;
      if (np is! NativePlayer) return;
      final decodedAfter = int.tryParse(
              await np.getProperty('video-dec-params/decoded-frames')
                  .catchError((_) => '0')) ??
          0;
      final renderedAfter = int.tryParse(
              await np.getProperty('vo-passes').catchError((_) => '0')) ??
          0;
      // If decoder produced frames but VO rendered 0 → MediaTek codec2
      // post-seek breakage. Recreate the player.
      if (decodedAfter >= 5 && renderedAfter == 0) {
        Log.w('Post-seek decoder stall detected '
            '(decoded=$decodedAfter, rendered=$renderedAfter). '
            'Recreating player to reset MediaCodec state.');
        await _recreatePlayer();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      try {
        player.pause();
      } catch (e, st) {
        Log.e('player.pause() in lifecycle pause failed', e, st);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Refresh player state when returning to the app
      try {
        if (player.state.playing) {
          player.play();
        }
      } catch (e) {
        Log.w('Failed to refresh player on resume: $e');
      }
    }
  }

  @override
  void dispose() {
    _renderWatchdog?.cancel();
    _renderWatchdog = null;
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
          _historyLog.addToHistory(
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
      _downloadController.resumeDownloadsAfterStreaming();
    } catch (e, st) {
      Log.e('Failed to resume downloads after streaming', e, st);
    }

    // Silence, pause, and stop the player immediately to halt all decoding and audio output
    try {
      player.setVolume(0.0);
    } catch (e) { /* ignore */ }
    try {
      player.pause();
    } catch (e) { /* ignore */ }
    try {
      player.stop();
    } catch (e) { /* ignore */ }

    // Reset PipController active state first. If this player is the active player,
    // we call close() to clean up the state and set activePlayer to null.
    final isActive = _pipController.activePlayer == player;
    if (isActive) {
      _pipController.clearActivePlayer(player);
    }

    // Wait a brief moment to see if another player took over (e.g. Next Episode).
    // If not, we are truly exiting the player and should reset UI and Wakelock.
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      try {
        if (_pipController.activePlayer == null) {
          _resetOrientationAndUI();
          if (!widget.isPip) {
            try { WakelockPlus.disable(); } catch (_) {}
          }
        }
      } catch (_) {}
    });

    final p = player;
    Future.microtask(() async {
      try {
        await p.stop();
        await p.dispose();
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
      Log.i('Preloading next episode (ID: $nextFileId) - low priority background download');
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

      if (previous?.streamingProfile != next.streamingProfile) {
        _settings = next;
        _applyStreamingProfile();
      }

      if (previous?.hardwareDecoderMode != next.hardwareDecoderMode) {
        _settings = next;
        _recreatePlayer();
      }
      if (previous?.subtitles.subtitleRendererMode != next.subtitles.subtitleRendererMode) {
        _settings = next;
        _recreatePlayer();
      }
      if (previous?.audio.dynamicRangeCompression != next.audio.dynamicRangeCompression ||
          previous?.audio.equalizerEnabled != next.audio.equalizerEnabled ||
          previous?.audio.equalizerBands != next.audio.equalizerBands) {
        _settings = next;
        needAudioFilterUpdate = true;
      }
      if (previous?.subtitles.subtitleFontSize != next.subtitles.subtitleFontSize ||
          previous?.subtitles.subtitleColor != next.subtitles.subtitleColor ||
          previous?.subtitles.subtitleDelay != next.subtitles.subtitleDelay ||
          previous?.subtitles.subtitleFont != next.subtitles.subtitleFont) {
        _settings = next;
        needSubUpdate = true;
      }
      if (needAudioFilterUpdate) {
        PlayerFilterService.updateAudioFilters(player, _settings);
      }
      if (needSubUpdate) {
        _updateSubtitleProperties();
      }
    });

    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
                final seekTarget = player.state.position + Duration(seconds: _settings.gestures.doubleTapSeekDuration);
                _handleCustomSeek(seekTarget);
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
                final seekTarget = player.state.position - Duration(seconds: _settings.gestures.doubleTapSeekDuration);
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
                 ? (widget.isPip 
                     ? Video(controller: controller, controls: NoVideoControls, wakelock: false)
                     : CustomVideoControls(
                         player: player,
                         controller: controller,
                         isDesktop: widget.isDesktopMode,
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
                          Text(AppLocalizations.of(context)!.bufferingStream, style: const TextStyle(color: Colors.white70)),
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
          } catch (e) { /* ignore */ }
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
                content: Text(AppLocalizations.of(context)!.anilistProgressSynced(episodeNumber.toString())),
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
                content: Text(AppLocalizations.of(context)!.malProgressSynced(episodeNumber.toString())),
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
                content: Text(AppLocalizations.of(context)!.traktProgressSynced(seasonNum.toString(), episodeNumber.toString())),
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
    try {
      final currentPos = player.state.position;
      final isPlayingState = player.state.playing;
      
      if (_isInitializing) return;
      
      setState(() {
        _isInitializing = true;
        _isPlaying = false;
        _updatesSubscription?.cancel();
        _saveTimer?.cancel();
        for (final sub in _subscriptions) {
          sub.cancel();
        }
        _subscriptions.clear();
      });
      
      _pipController.clearActivePlayer(player);
      
      try {
        await player.setVolume(0.0);
      } catch (e) { /* ignore */ }
      try {
        await player.pause();
      } catch (e) { /* ignore */ }
      try {
        await player.stop();
      } catch (e) { /* ignore */ }
      await player.dispose();

      _initialTrackSelectionDone = false;
      // Reset HDR fallback flag for the recreated player.
      _hdrFallbackApplied = false;
      _initPlayerInstance();
      _setupPlayerListeners();

      final fileId = _resolvedVideoFileId ?? widget.videoFileId;
      if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
        player.open(Media(widget.networkUrl!), play: isPlayingState)
            .timeout(const Duration(seconds: 30))
            .then((_) {
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
            
        if (StreamingProxyService.isProxyUrl(mediaUrl)) {
          // Proxy is started at app launch — no wait needed (see _initDownload).
          mediaUrl = _proxyService.getProxyUrl(fileId, fileName: widget.videoTitle);
        }

        final proxyHeaders = StreamingProxyService.isProxyUrl(mediaUrl) ? _proxyService.getAuthHeaders() : null;
        player.open(Media(mediaUrl, httpHeaders: proxyHeaders), play: isPlayingState)
            .timeout(const Duration(seconds: 30))
            .then((_) {
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

  // ─────────────────────────────────────────────────────────────────────────
  // Frame-drop watchdog — auto-recovers from black-screen regressions.
  //
  // Polls MPV every 1s for the first 8 seconds of playback. If we observe
  // "rendered frames == 0 AND dropped frames > 0" for 3 consecutive polls
  // while the player reports it is playing, we recreate the player with a
  // fallback decoder chain: mediacodec → mediacodec-copy → software (no).
  //
  // This is the safety net that prevents future regressions from ever
  // shipping a permanent black-screen bug to MediaTek users again.
  // ─────────────────────────────────────────────────────────────────────────
  // ───────────────────────────────────────────────────────────────────────
  // Render Watchdog (v3) — detects TWO distinct black-screen failure modes.
  // ───────────────────────────────────────────────────────────────────────
  //
  // Mode A: HDR content + Flutter Impeller on Mali-G57 (the actual user bug)
  //   - MediaCodec decodes correctly and renders frames to SurfaceTexture
  //     (Render: 109 in 5s — confirmed by logcat)
  //   - But Flutter Impeller (Vulkan) on Mali-G57 MC2 CANNOT tone-map
  //     HDR External OES textures to SDR → black pixels
  //   - Detection: poll `video-params/gamma` for HDR transfers (one-shot
  //     check at the 2-second mark, after the demuxer populates it)
  //   - Fix: switch from `mediacodec` (zero-copy) to `hwdec=no` (software)
  //     so that mpv's `gpu` VO can apply the tone-mapping properties
  //     (target-prim, target-trc, tone-mapping, etc.) set in
  //     _initPlayerInstance.
  //
  // Mode B: Post-seek MediaCodec breakage on MediaTek (secondary bug)
  //   - After a flush+restart (seek), MediaCodec drops ALL frames
  //     (Render: 0, Drop: 121 in 5s — confirmed by logcat)
  //   - Detection: poll `video-dec-params/decoded-frames` vs `vo-passes`
  //   - Fix: escalate through mediacodec-copy → software
  //
  // The watchdog runs for 30 seconds after playback starts. If neither
  // mode is detected, it auto-stops.
  Timer? _renderWatchdog;
  int _watchdogZeroRenderStreak = 0;
  int _watchdogFallbackStage = 0; // 0 = primary, 1 = mediacodec-copy, 2 = software
  bool _watchdogHdrChecked = false;
  static const int _watchdogMaxZeroRenderStreak = 3;
  static const Duration _watchdogDuration = Duration(seconds: 30);

  /// Tracks whether we have already applied the HDR fallback for the
  /// current playback session. Reset to `false` whenever a new media
  /// URL is loaded (in _startPlayback and player.open callsites).
  bool _hdrFallbackApplied = false;

  void _startRenderWatchdog() {
    _renderWatchdog?.cancel();
    _watchdogZeroRenderStreak = 0;
    _watchdogHdrChecked = false;
    _renderWatchdog = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted || !player.state.playing) return;
      try {
        final nativePlayer = player.platform;
        if (nativePlayer is! NativePlayer) return;

        // ── Mode A: HDR detection (one-shot, after 2 seconds) ──────────
        // We wait 2 seconds for the demuxer to populate `video-params/*`.
        // Once detected, if hwdec is currently `mediacodec` (zero-copy),
        // we MUST switch to `hwdec=no` because the tone-mapping properties
        // are no-ops under zero-copy decoding (mpv's gpu VO is bypassed).
        if (!_watchdogHdrChecked &&
            _watchdogZeroRenderStreak == 0 &&
            t.tick >= 2) {
          _watchdogHdrChecked = true;
          final isHdr = await _isCurrentVideoHdr();
          if (isHdr && _watchdogFallbackStage == 0) {
            final currentHwdec = await nativePlayer
                .getProperty('hwdec')
                .catchError((_) => '');
            if (currentHwdec != 'no' &&
                currentHwdec != 'mediacodec-copy' &&
                currentHwdec != 'auto-copy' &&
                currentHwdec != 'd3d11va-copy' &&
                currentHwdec != 'vaapi-copy') {
              Log.e('Render watchdog MODE A TRIGGERED — HDR content '
                  'detected with hwdec=$currentHwdec. Switching to '
                  'software decoding + tone-mapping (this is the actual '
                  'fix for the user\'s MediaTek black-screen bug).');
              t.cancel();
              _watchdogOverrideHwdec = 'no';
              _hdrFallbackApplied = true;
              _watchdogFallbackStage = 2; // skip mediacodec-copy stage
              _recreatePlayer();
              return;
            }
          }
        }

        // ── Mode B: zero-render detection (continuous) ─────────────────
        // Triggered when the decoder produces 10+ frames but mpv's VO
        // renders 0. This catches the post-seek "all frames dropped"
        // bug (MediaTek codec2 quirk after a flush).
        final decodedStr = await nativePlayer
            .getProperty('video-dec-params/decoded-frames')
            .catchError((_) => '0');
        final renderedStr = await nativePlayer
            .getProperty('vo-passes')
            .catchError((_) => '0');

        final decoded = int.tryParse(decodedStr) ?? 0;
        final rendered = int.tryParse(renderedStr) ?? 0;

        final blackScreenDetected = decoded >= 10 && rendered == 0;

        if (blackScreenDetected) {
          _watchdogZeroRenderStreak++;
          Log.w('Render watchdog MODE B: zero-render streak='
              '$_watchdogZeroRenderStreak (decoded=$decoded, '
              'rendered=$rendered)');
        } else {
          _watchdogZeroRenderStreak = 0;
        }

        if (_watchdogZeroRenderStreak >= _watchdogMaxZeroRenderStreak) {
          Log.e('Render watchdog MODE B TRIGGERED — all frames dropped. '
              'decoded=$decoded, rendered=$rendered. '
              'Fallback stage=$_watchdogFallbackStage');
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

    if (_watchdogFallbackStage > 2) {
      Log.e('Render watchdog: exhausted all fallback stages. Giving up. '
          'Black screen will persist until the user manually changes the '
          'decoder setting or restarts the app.');
      _watchdogFallbackStage = 0;
      return;
    }
    final stageName = _watchdogFallbackStage == 1
        ? 'mediacodec-copy'
        : 'no (software)';
    Log.w('Render watchdog: recreating player with hwdec=$stageName');

    // Temporarily override the stored setting for this player instance only.
    // We do NOT persist this — the user's setting stays as-is for next launch,
    // but this playback session uses the fallback.
    _watchdogOverrideHwdec = stageName == 'no (software)' ? 'no' : stageName;
    _recreatePlayer();
  }

  // ───────────────────────────────────────────────────────────────────────
  // HDR Detection (v3 fix for the actual black-screen root cause)
  // ───────────────────────────────────────────────────────────────────────
  //
  // The user's test video is HDR10 (BT.2020 + SMPTE ST 2084 PQ). The
  // hardware decoder produces valid HDR frames at the correct frame rate,
  // but Flutter Impeller (Vulkan) on Mali-G57 MC2 cannot tone-map HDR
  // External OES textures to SDR → the user sees black.
  //
  // mpv exposes the video's colorspace via `video-params/*` properties:
  //   - `video-params/gamma` (transfer function):
  //       "bt709"        → SDR
  //       "gamma22"      → SDR
  //       "bt1886"       → SDR
  //       "smpte2084"    → HDR10 (PQ)
  //       "arib-std-b67" → HLG
  //       "srgb"         → SDR
  //   - `video-params/primaries` (color primaries):
  //       "bt709"     → SDR
  //       "bt2020"    → HDR
  //       "bt2020-cie" → HDR
  //
  // We check both: an HDR transfer function OR BT.2020 primaries.
  Future<bool> _isCurrentVideoHdr() async {
    try {
      final nativePlayer = player.platform;
      if (nativePlayer is! NativePlayer) return false;

      final gamma = await nativePlayer
          .getProperty('video-params/gamma')
          .catchError((_) => '');
      final primaries = await nativePlayer
          .getProperty('video-params/primaries')
          .catchError((_) => '');

      final gammaLower = gamma.toLowerCase();
      final primariesLower = primaries.toLowerCase();

      final isHdr = gammaLower == 'smpte2084' ||
          gammaLower == 'arib-std-b67' ||
          primariesLower == 'bt2020' ||
          primariesLower == 'bt2020-cie';

      if (isHdr) {
        Log.w('HDR video detected: gamma=$gamma, primaries=$primaries. '
            'Will use software decoding + tone-mapping to avoid the '
            'Flutter Impeller HDR rendering bug on Mali-G57.');
      } else {
        Log.i('Video is SDR: gamma=$gamma, primaries=$primaries. '
            'No tone-mapping fallback needed.');
      }
      return isHdr;
    } catch (e) {
      Log.w('HDR detection failed: $e');
      return false;
    }
  }

  /// When non-null, [_initPlayerInstance] uses this value instead of the
  /// stored setting. Cleared on every successful playback start.
  String? _watchdogOverrideHwdec;

  Future<void> _initPlayerInstance() async {
    final localFont = ref.read(storageServiceProvider).localFontPath;
    player = Player(
      configuration: PlayerConfiguration(
        pitch: _settings.audio.pitchCorrection,
        libass: _settings.subtitles.subtitleRendererMode == 'native',
        libassAndroidFont: localFont ?? 'assets/fonts/Roboto-Regular.ttf',
        libassAndroidFontName: 'Roboto',
      ),
    );

    // Optimize streaming cache/buffering parameters for low-bandwidth
    // connections and reduce glitching.
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;

        // ── Cache / buffering ──────────────────────────────────────────────
        // These values were validated by Hotfixes 4, 5, and 7. Do NOT change
        // them without re-testing on MediaTek Dimensity 6080.
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('demuxer-max-bytes', '209715200'); // 200 MB
        nativePlayer.setProperty('demuxer-max-back-bytes', '52428800'); // 50 MB
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
        nativePlayer.setProperty('stream-buffer-size', '16777216'); // 16 MB

        // ── Software decoder fallback tuning ───────────────────────────────
        // These only run if HW decoding fails and MPV falls back to lavc.
        nativePlayer.setProperty('vd-lavc-fast', 'yes');
        nativePlayer.setProperty('vd-lavc-skiploopfilter', 'default');
        nativePlayer.setProperty('vd-lavc-check-hw-profile', 'no');
        nativePlayer.setProperty('vd-lavc-threads', '0');
        nativePlayer.setProperty('vd-lavc-show-all', 'no');
        nativePlayer.setProperty('vd-lavc-er', 'careful');
        if (!Platform.isAndroid && !Platform.isIOS) {
          nativePlayer.setProperty('hwdec-extra-frames', '64');
        }

        // ── Hardware decoder selection ─────────────────────────────────────
        // This is the CRITICAL FIX for the MediaTek black-screen bug.
        //
        // Background:
        //   - MediaCodec has two modes:
        //     * `mediacodec`      — zero-copy. Decodes directly into a
        //                           SurfaceTexture. media_kit renders it via
        //                           the SurfaceProducer API, no GL upload.
        //     * `mediacodec-copy` — decode-to-RAM. Each frame is a ByteBuffer
        //                           that media_kit must upload to a GL texture.
        //   - On MediaTek Dimensity 6080 with Flutter Impeller (Vulkan),
        //     the GL→Vulkan texture interop silently produces black pixels.
        //     So `mediacodec-copy` works on Adreno (Snapdragon) but NOT on
        //     Mali-G57 (MediaTek).
        //   - `hwdec=auto` lets MPV pick. On MediaTek it almost always picks
        //     `mediacodec-copy`, which is exactly the broken path.
        //
        // The previous code (v2.13.7+69) *claimed* to map `mediacodec-copy`
        // → `mediacodec`, but actually mapped it → `auto`. That regression
        // is the root cause of the user's bug.
        //
        // Fix: always normalize every "hwdec-on" mode to `mediacodec`
        // (zero-copy) on Android. Only `no` (software) survives as-is.
        final storedHwdec =
            _watchdogOverrideHwdec ?? _storageService.getHardwareDecoderMode();
        _watchdogOverrideHwdec = null; // consume the override

        if (Platform.isAndroid) {
          // ── MediaTek SoC detection ───────────────────────────────────────
          // CRITICAL v2 FIX: MediaTek's c2.mtk.*.decoder has two known bugs
          // that make hardware decoding unusable on Dimensity 6080 (and
          // likely all MediaTek SoCs with Mali-G57 and earlier GPUs):
          //
          //   Bug 1 (mediacodec zero-copy): MediaCodec drops every decoded
          //   frame because mpv's audio clock drifts ahead of the video
          //   clock during the first-frame warmup. MediaTek's decoder has
          //   ZERO tolerance for late render timestamps (unlike Qualcomm's
          //   ~100ms tolerance). Logcat shows: `Render: 0, Drop: 120`.
          //
          //   Bug 2 (mediacodec-copy + Impeller): The GL→Vulkan texture
          //   interop is broken on Mali-G57 MC2 drivers, so frames decoded
          //   to RAM and uploaded to GL textures render black under
          //   Flutter's Impeller (Vulkan) backend.
          //
          // The ONLY reliable decoder path on these devices is SOFTWARE
          // decoding (hwdec=no), which uses libavcodec and avoids both
          // MediaCodec and the GL→Vulkan interop. Software HEVC decode of
          // 1080p24 content uses ~25-35% on one Cortex-A78 core, which is
          // acceptable for a streaming app.
          //
          // We detect MediaTek SoCs at runtime via DeviceDetector and force
          // hwdec=no. The user can still override this by explicitly
          // selecting a hardware decoder in Settings, but the default is
          // software for reliability.
          // ── Hardware decoder selection (Android, v3) ─────────────────────
          //
          // v3 FIX (the actual root cause fix):
          //
          // We no longer force `hwdec=no` on MediaTek. Instead, we use
          // `mediacodec` (zero-copy) by default on ALL Android devices
          // because:
          //   1. For SDR content, `mediacodec` is faster and uses less
          //      battery than software decoding.
          //   2. The black-screen bug is NOT a decoder bug — it's an
          //      HDR tone-mapping bug. Forcing `hwdec=no` does not fix
          //      it because software decoding produces the SAME HDR
          //      frames (the colorspace metadata is preserved).
          //   3. The real fix is in the HDR tone-mapping properties set
          //      below (target-prim, target-trc, tone-mapping, etc.),
          //      AND in the watchdog's Mode A detection which dynamically
          //      switches to `hwdec=no` when HDR content is detected
          //      (so that mpv's gpu VO can apply the tone-mapping).
          //
          // Software decoding is still used when:
          //   - The user explicitly sets hwdec=no in Settings.
          //   - The watchdog detects HDR content and forces the fallback.
          //   - The watchdog detects zero-render (Mode B) after a seek.
          final isMediaTek = await DeviceDetector.isMediaTekSoC;
          final socDesc = await DeviceDetector.socDescription;
          Log.i('SoC: $socDesc (isMediaTek=$isMediaTek)');

          String safeMode;
          if (_watchdogFallbackStage > 0) {
            // Watchdog is in fallback mode — respect its override.
            safeMode = storedHwdec;
          } else if (storedHwdec == 'no') {
            // User explicitly chose software decoding.
            safeMode = 'no';
          } else {
            // Default: zero-copy hardware decode. Works for SDR content.
            // HDR content is handled by the watchdog's Mode A detection,
            // which dynamically switches to `hwdec=no` + tone-mapping.
            safeMode = 'mediacodec';
          }

          nativePlayer.setProperty('hwdec', safeMode);
          Log.i('Set hardware decoder mode to $safeMode on player init '
              '(Android, SoC=$socDesc, source=$storedHwdec'
              '${_watchdogFallbackStage > 0 ? ', fallback stage=$_watchdogFallbackStage' : ''})');

          // ── Explicit codec allowlist ─────────────────────────────────────
          // Only applied when hardware decoding is active (not for sw).
          // Tells MediaCodec exactly which codecs it is allowed to claim.
          // Without this, MediaCodec will opportunistically grab codecs it
          // can't actually zero-copy (e.g., AV1 on Dimensity 6080 which
          // lacks AV1 HW decode), then silently fall back to software
          // INSIDE the mediacodec backend — which is even worse than
          // picking lavc directly, because the software frames go through
          // the broken GL→Vulkan interop path.
          //
          // Dimensity 6080 MediaCodec supports zero-copy for:
          //   H.264, HEVC (H.265), VP9, MPEG-4, MPEG-2.
          // AV1 is NOT supported in HW on this SoC — exclude it so MPV
          // routes AV1 streams to software decoding explicitly.
          if (safeMode != 'no') {
            nativePlayer.setProperty(
              'hwdec-codecs',
              'h264,hevc,vp9,mpeg4,mpegvideo',
            );
          }

          // ── HDR → SDR tone-mapping (THE ACTUAL FIX) ────────────────────
          // This is the v3 fix for the user's black-screen bug.
          //
          // Background:
          //   - The user's test video is HDR10 (BT.2020 + SMPTE ST 2084 PQ).
          //   - MediaCodec decodes it correctly and produces valid HDR YUV.
          //   - But Flutter Impeller (Vulkan) on Mali-G57 MC2 CANNOT
          //     tone-map HDR External OES textures to SDR. The PQ-encoded
          //     values (which represent brightness up to 10,000 nits) are
          //     sampled as if they were sRGB SDR values, producing
          //     near-black pixels.
          //   - On Adreno (Snapdragon 7s Gen 3), the driver handles this
          //     correctly → that's why the user's friend's phone works.
          //
          // Why hwdec=no alone doesn't fix it:
          //   - Software decoding produces the SAME HDR YUV frames as
          //     hardware decoding. The colorspace metadata is preserved.
          //   - mpv's `gpu` VO needs EXPLICIT tone-mapping properties to
          //     convert HDR → SDR before the SurfaceTexture receives frames.
          //   - Without these properties, mpv passes HDR through unchanged.
          //
          // The fix:
          //   - `target-prim=bt709`     → force BT.709 (sRGB) primaries
          //   - `target-trc=bt1886`     → force BT.1886 (sRGB) transfer
          //   - `tone-mapping=mobius`   → Mobius algorithm (preserves
          //                              shadow detail, smooth highlight
          //                              roll-off)
          //   - `tone-mapping-param=0.85` → Mobius knee point (default 0.3
          //                              is too aggressive; 0.85 preserves
          //                              more mid-tone detail)
          //   - `hdr-compute-peak=yes`  → dynamically compute the HDR peak
          //                              luminance per scene (better than
          //                              relying on static metadata, which
          //                              is often missing or wrong)
          //   - `target-colorspace-hint=no` → do NOT pass HDR metadata to
          //                              the display (we want SDR output)
          //   - `gamma-auto=no`          → do not auto-adjust gamma
          //
          // IMPORTANT: These properties only take effect with `hwdec=no`.
          // With `hwdec=mediacodec` (zero-copy), the raw HDR YUV frames
          // bypass mpv's tone-mapping pipeline and go directly to the
          // SurfaceTexture. That's why the watchdog's Mode A detection
          // dynamically switches to `hwdec=no` when HDR is detected.
          //
          // We set these properties UNCONDITIONALLY on Android — even for
          // SDR content — because:
          //   1. They are no-ops for SDR content (no tone-mapping needed).
          //   2. Setting them lazily after HDR detection introduces a
          //      1-2 second window where HDR frames reach the
          //      SurfaceTexture unconverted (still black).
          //   3. mpv's `gpu` VO handles the "SDR input + SDR target" case
          //      with zero overhead (it skips the tone-mapping shader).
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
          // settings ensure libavcodec uses all available cores
          // efficiently. The Dimensity 6080 has 2x A78 + 6x A55 = 8
          // threads available.
          if (safeMode == 'no') {
            nativePlayer.setProperty('vd-lavc-threads', '8');
            // Allow fast decoding mode (skips some error checks) to reduce
            // CPU usage. Safe for streaming content (which is typically
            // well-formed).
            nativePlayer.setProperty('vd-lavc-fast', 'yes');
            // Skip the deblocking loop filter for additional speed.
            // Slight quality reduction (blocky edges in high-motion
            // scenes) but ~20-30% faster decode.
            nativePlayer.setProperty('vd-lavc-skiploopfilter', 'nonref');
          }
        } else {
          // Desktop path — unchanged from original logic.
          String safeMode = storedHwdec;
          if (Platform.isWindows) {
            if (safeMode == 'auto' ||
                safeMode == 'auto-copy' ||
                safeMode == 'd3d11va') {
              safeMode = 'd3d11va-copy';
            } else if (safeMode == 'mediacodec-copy' ||
                safeMode == 'mediacodec') {
              safeMode = 'd3d11va-copy';
            }
          } else if (Platform.isLinux || Platform.isMacOS) {
            if (safeMode == 'auto' || safeMode == 'auto-copy') {
              safeMode = 'vaapi-copy';
            } else if (safeMode == 'mediacodec-copy' ||
                safeMode == 'mediacodec') {
              safeMode = 'vaapi-copy';
            } else if (safeMode == 'd3d11va' || safeMode == 'd3d11va-copy') {
              safeMode = 'vaapi-copy';
            }
          }
          nativePlayer.setProperty('hwdec', safeMode);
          Log.i('Set hardware decoder mode to $safeMode on player init (PC)');
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
        nativePlayer.setProperty('sub-visibility',
            _settings.subtitles.subtitleRendererMode == 'native' ? 'yes' : 'no');
        nativePlayer.setProperty('sub-auto', 'all');
        nativePlayer.setProperty('embeddedfonts', 'yes');
        nativePlayer.setProperty('blend-subtitles', 'no');
        nativePlayer.setProperty('demuxer-mkv-subtitle-preroll', 'yes');
        nativePlayer.setProperty('demuxer-mkv-subtitle-preroll-secs', '10');
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
        PlayerFilterService.updateAudioFilters(player, _settings);

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
      Log.e('Failed to configure native player features', e, stack);
    }

    // ── VideoController creation ───────────────────────────────────────────
    // enableHardwareAcceleration controls whether media_kit creates an EGL
    // surface for the Video widget. On Android, this MUST be true whenever
    // hwdec != 'no', because mediacodec zero-copy requires a SurfaceTexture
    // backed by an EGLSurface. Setting it to false would break the
    // SurfaceTexture path and re-introduce the black screen.
    //
    // On desktop, this is always true — the comment from the original code
    // still applies: setting it to false causes the black screen bug
    // because mpv's decoded frames never reach the Flutter Video widget.
    final hwDecMode = _storageService.getHardwareDecoderMode();
    final enableHw = Platform.isAndroid ? (hwDecMode != 'no') : true;

    // Defer to after the widget tree finishes building — Riverpod forbids
    // modifying providers during initState/build.
    Future.microtask(() {
      if (mounted) {
        _pipController.setActivePlayer(player);
      }
    });

    try {
      controller = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          enableHardwareAcceleration: enableHw,
        ),
      );
    } catch (e, st) {
      Log.e('Failed to create VideoController. Disposing player.', e, st);
      try {
        player.dispose();
      } catch (_) {}
      rethrow;
    }

    // Start the render watchdog once the controller is wired up. It will
    // auto-cancel after 8 seconds if rendering is healthy.
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
      if (c == ']' || c == ')') bracketDepth = (bracketDepth > 0) ? bracketDepth - 1 : 0;
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

    _subscriptions.add(player.stream.playing.listen((playing) async {
      if (playing) {
        if (!widget.isPip) {
          try {
            // Force reset WakelockPlus internal boolean cache by disabling first
            await WakelockPlus.disable();
            await WakelockPlus.enable();
          } catch (_) {}
        }
      } else {
        // When paused, wait 60 seconds before disabling Wakelock
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted && !player.state.playing && !widget.isPip) {
            try { WakelockPlus.disable(); } catch (_) {}
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
      PlayerFilterService.updateBlendSubtitlesForTrack(player, selectedTrack ?? player.state.track.subtitle);
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



  void _updateSubtitleProperties() {
    if (player.platform is NativePlayer) {
      final nativePlayer = player.platform as NativePlayer;
      nativePlayer.setProperty('sub-font-size', _settings.subtitles.subtitleFontSize.round().toString());
      nativePlayer.setProperty('sub-color', _settings.subtitles.subtitleColor);
      nativePlayer.setProperty('sub-delay', _settings.subtitles.subtitleDelay.toString());
      
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
      Log.i('Updated subtitle settings dynamically: size=${_settings.subtitles.subtitleFontSize}, color=${_settings.subtitles.subtitleColor}, delay=${_settings.subtitles.subtitleDelay}, font=$resolvedFontFamily');
    }
  }

}

