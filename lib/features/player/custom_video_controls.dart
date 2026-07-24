import 'widgets/squiggly_play_button.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:telstream/features/player/widgets/subtitle_overlay.dart';
import 'package:telstream/features/player/widgets/video_layer.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'widgets/gesture_overlay_indicators.dart';
import 'widgets/sleep_timer_panel.dart';
import 'widgets/video_gesture_handler.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:file_picker/file_picker.dart';
import '../settings/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../core/widgets/expressive_container.dart';
import '../../core/logger.dart';
import '../../services/streaming_proxy_service.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/permission_service.dart';


import 'widgets/equalizer_dialog.dart';
import 'widgets/speed_selector_panel.dart';
import 'widgets/track_selector_panel.dart';
import 'widgets/chapters_panel.dart';
import 'widgets/aspect_ratio_panel.dart';
import 'widgets/more_options_panel.dart';
import 'widgets/subtitle_downloader_dialog.dart';
import 'widgets/audio_sync_dialog.dart';
import 'widgets/player_playback_bar.dart';

import 'widgets/queue_dialog.dart';
import 'widgets/nerd_stats_overlay.dart';
import 'widgets/auto_next_overlay.dart';


import 'widgets/flashing_chevrons.dart';
import 'widgets/player_header_bar.dart';

class _PlayPauseIntent extends Intent { const _PlayPauseIntent(); }
class _SeekBackwardIntent extends Intent { const _SeekBackwardIntent(); }
class _SeekForwardIntent extends Intent { const _SeekForwardIntent(); }
class _FullscreenIntent extends Intent { const _FullscreenIntent(); }
class _MuteIntent extends Intent { const _MuteIntent(); }

class CustomVideoControls extends ConsumerStatefulWidget {
  final Player player;
  final VideoController controller;
  final String videoTitle;
  final bool isPip;
  final int downloadedPrefixSize;
  final int expectedSize;
  final int activeDownloadOffset;
  final int activeDownloadedSize;
  final VoidCallback onBack;
  final bool hasPrevEpisode;
  final bool hasNextEpisode;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final ValueChanged<Duration>? onSeek;
  final bool customBuffering;
  final String seriesName;
  final int currentEpisodeIndex;
  final bool isDesktop;

  const CustomVideoControls({
    super.key,
    required this.player,
    required this.controller,
    required this.videoTitle,
    required this.isPip,
    required this.downloadedPrefixSize,
    required this.expectedSize,
    required this.activeDownloadOffset,
    required this.activeDownloadedSize,
    required this.onBack,
    this.hasPrevEpisode = false,
    this.hasNextEpisode = false,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.onSeek,
    this.customBuffering = false,
    this.seriesName = '',
    this.currentEpisodeIndex = 0,
    this.isDesktop = false,
  });

  @override
  ConsumerState<CustomVideoControls> createState() =>
      _CustomVideoControlsState();
}

class _CustomVideoControlsState extends ConsumerState<CustomVideoControls> {
  final GlobalKey<SpeedSelectorPanelState> _speedPanelKey = GlobalKey();
  final GlobalKey<TrackSelectorPanelState> _trackPanelKey = GlobalKey();
  final GlobalKey<ChaptersPanelState> _chaptersPanelKey = GlobalKey();
  late final VideoGestureHandler _gestureHandler;

  bool _showControls = true;
  Timer? _hideTimer;

  bool _isLocked = false;
  bool _isFullscreen = true;
  final _fitNotifier = ValueNotifier<BoxFit>(BoxFit.contain);
  String _currentAspectRatioString = 'fit';
  final _customAspectRatioNotifier = ValueNotifier<double?>(null);
  bool _rememberRatio = false;
  bool _tapToSwitchRatio = false;
  bool _showRatioPanel = false;
  bool _showMoreOptionsPanel = false;
  double _preLongPressSpeed = 1.0;

  StreamSubscription<bool>? _bufferingSubscription;
  bool _isBuffering = false;
  bool _isBlendingSubtitles = false;
  StreamSubscription<Track>? _trackSubscription;
  StreamSubscription? _tracksListSubscription;
  Map<String, String> _trackCodecs = {};

  // Gestures
  double _currentVolume = 100.0;
  double _currentBrightness = 1.0;
  bool _isPhysicalBrightnessSupported = false;
  Timer? _brightnessSaveTimer;
  final bool _audioBoostActive = false;
  bool _nightModeActive = false;
  double _audioDelay = 0.0;
  Timer? _statsTimer;
  Map<String, String> _nerdStats = {};
  final Map<int, int> _lastDownloadedBytes = {};

  // Double tap seek variables
  bool _showLeftSeekOverlay = false;
  bool _showRightSeekOverlay = false;
  double _doubleTapSeekOpacity = 0.0;
  int _doubleTapSeekAccumulated = 0;
  Timer? _doubleTapOverlayTimer;
  Timer? _doubleTapSeekTimer;

  int _autoNextSecondsRemaining = 15;
  Timer? _autoNextTimer;
  bool _autoNextCancelled = false;
  bool _autoNextTriggered = false;
  bool _autoNextSlideIn = false;
  bool _showAutoNextCountdown = false;
  bool _blendSubtitlesChecked = false;
  Timer? _autoNextSlideInTimer;
  Timer? _autoNextDismissTimer;
  Duration? _doubleTapStartPosition;

  StreamSubscription<Duration>? _positionSubscription;

  // Skip Times variables
  StreamSubscription? _durationSubscription;
  bool _toastShowing = false;
  String _toastMessage = '';
  Timer? _toastTimer;

  bool _isMuted = false;
  double _preMuteVolume = 100.0;
  Duration? _abRepeatA;
  Duration? _abRepeatB;
  bool _quickActionsExpanded = false;

  // Sleep timer variables
  Timer? _sleepTimer;
  int? _sleepTimerMinutes;
  int? _sleepTimerSecondsRemaining;
  Timer? _osdTimer;

  // Chapter variables
  List<VideoChapter> _chapters = [];
  bool _hasChapters = false;
  StreamSubscription? _playlistSubscription;
  int _chaptersLoadAttempts = 0;
  Timer? _chaptersRetryTimer;

  // Pinch to zoom
  final _scaleNotifier = ValueNotifier<double>(1.0);
  final _panNotifier = ValueNotifier<Offset>(Offset.zero);

  // Swipe to seek variables

  // Gesture detection flags
  DateTime? _lastSeekWarningTime;
  StreamSubscription<double>? _volumeSubscription;
  DateTime? _lastDragSeekTime;

  bool _isPositionDownloaded(Duration position) {
    if (widget.expectedSize <= 0) return true;
    final totalDuration = widget.player.state.duration;
    if (totalDuration.inMilliseconds <= 0) return false;

    final isDownloadedCompleted =
        widget.downloadedPrefixSize >= widget.expectedSize;
    if (isDownloadedCompleted) return true;

    final fraction = position.inSeconds / totalDuration.inSeconds;
    final byteOffset = fraction * widget.expectedSize;

    if (byteOffset < widget.downloadedPrefixSize) return true;

    final activeEnd = widget.activeDownloadOffset + widget.activeDownloadedSize;
    if (byteOffset >= widget.activeDownloadOffset && byteOffset < activeEnd) {
      return true;
    }

    return false;
  }

  void _throttledSeek(Duration target) {
    final now = DateTime.now();
    if (_lastDragSeekTime == null ||
        now.difference(_lastDragSeekTime!).inMilliseconds > 150) {
      _lastDragSeekTime = now;
      _performSeek(target);
    }
  }

  

  bool _isChapterOutro(
    VideoChapter ch,
    double start,
    double end,
    double totalDuration,
  ) {
    final titleLower = ch.title.toLowerCase().trim();
    return titleLower.contains('outro') ||
        titleLower.contains('ending') ||
        titleLower.contains('credits') ||
        titleLower.contains('credit') ||
        titleLower.contains('closing') ||
        titleLower.contains('post-credits') ||
        titleLower.contains('preview') ||
        titleLower.contains('teaser') ||
        titleLower.contains('epilogue') ||
        titleLower == 'ed' ||
        titleLower.startsWith('ed ') ||
        titleLower.endsWith(' ed') ||
        titleLower.contains('ed 1') ||
        titleLower.contains('ed 2') ||
        titleLower.contains('ed1') ||
        titleLower.contains('ed2');
  }

  void _showSkipToast(String msg) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() {
      _toastShowing = true;
      _toastMessage = msg;
    });
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _toastShowing = false;
        });
      }
    });
  }

  void _checkAbRepeat(Duration pos) {
    if (_abRepeatA != null && _abRepeatB != null) {
      if (pos >= _abRepeatB!) {
        _performSeek(_abRepeatA!);
      }
    }
  }

  void _toggleAbRepeat() {
    if (!mounted) return;
    final currentPos = widget.player.state.position;
    setState(() {
      if (_abRepeatA == null) {
        _abRepeatA = currentPos;
        _showSkipToast(AppLocalizations.of(context)!.abRepeatPointASet);
      } else if (_abRepeatB == null) {
        if (currentPos <= _abRepeatA!) {
          _showSkipToast(AppLocalizations.of(context)!.pointBMustBeAfterPointA);
          return;
        }
        _abRepeatB = currentPos;
        _showSkipToast(AppLocalizations.of(context)!.abRepeatLooping);
        _performSeek(_abRepeatA!);
      } else {
        _abRepeatA = null;
        _abRepeatB = null;
        _showSkipToast(AppLocalizations.of(context)!.abRepeatCleared);
      }
    });
  }

  void _toggleMute() {
    if (!mounted) return;
    setState(() {
      if (_isMuted) {
        _isMuted = false;
        _currentVolume = _preMuteVolume;
        FlutterVolumeController.setVolume(_currentVolume / 100.0);
        _showSkipToast(AppLocalizations.of(context)!.volumeRestored);
      } else {
        _isMuted = true;
        _preMuteVolume = _currentVolume;
        _currentVolume = 0.0;
        FlutterVolumeController.setVolume(0.0);
        _showSkipToast(AppLocalizations.of(context)!.volumeMuted);
      }
    });
  }

  Future<void> _takeScreenshot() async {
    try {
      final hasPermission = await ref
          .read(permissionServiceProvider)
          .requestStoragePermission();
      if (!hasPermission) {
        if (!mounted) return;
        _showSkipToast(AppLocalizations.of(context)!.storagePermissionDenied);
        return;
      }

      final Uint8List? screenshotBytes = await widget.player.screenshot(
        format: 'image/png',
      );
      if (!mounted) return;
      if (screenshotBytes == null || screenshotBytes.isEmpty) {
        _showSkipToast(AppLocalizations.of(context)!.failedToCaptureScreenshot);
        return;
      }

      final storage = ref.read(storageServiceProvider);
      final customPath = storage.getCustomDownloadDirectory();
      Directory? baseDir;

      if (customPath != null && customPath.isNotEmpty) {
        baseDir = Directory('$customPath/Screenshots');
      } else if (Platform.isAndroid) {
        final telstreamRoot = Directory(
          '/storage/emulated/0/TelStream/Screenshots',
        );
        final downloadDir = Directory(
          '/storage/emulated/0/Download/TelStream/Screenshots',
        );
        final picturesDir = Directory(
          '/storage/emulated/0/Pictures/TelStream/Screenshots',
        );

        try {
          if (!telstreamRoot.existsSync()) {
            telstreamRoot.createSync(recursive: true);
          }
          baseDir = telstreamRoot;
        } catch (_) {
          try {
            if (!downloadDir.existsSync()) {
              downloadDir.createSync(recursive: true);
            }
            baseDir = downloadDir;
          } catch (_) {
            try {
              if (!picturesDir.existsSync()) {
                picturesDir.createSync(recursive: true);
              }
              baseDir = picturesDir;
            } catch (_) {}
          }
        }
      }

      if (baseDir == null) {
        final docDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${docDir.path}/Screenshots');
      }

      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }

      final cleanTitle = widget.videoTitle.replaceAll(
        RegExp(r'[^\w\-\.]'),
        '_',
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath =
          '${baseDir.path}/Screenshot_${cleanTitle}_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(screenshotBytes);

      String displayPath = baseDir.path;
      if (displayPath.startsWith('/storage/emulated/0/')) {
        displayPath = displayPath.replaceFirst('/storage/emulated/0/', '');
      }
      if (!mounted) return;
      _showSkipToast(AppLocalizations.of(context)!.screenshotSavedTo(displayPath));
    } catch (e, stack) {
      Log.e('Failed to take screenshot', e, stack);
      if (!mounted) return;
      _showSkipToast(AppLocalizations.of(context)!.errorSavingScreenshot(e.toString()));
    }
  }

  Widget _buildQuickActionRow() {
    final List<Widget> items = [
      _buildCircularActionButton(
        icon: _isMuted ? Icons.volume_off : Icons.volume_up,
        label: AppLocalizations.of(context)!.mute,
        isActive: _isMuted,
        onTap: _toggleMute,
      ),
      _buildCircularActionButton(
        icon: Icons.speed_rounded,
        label: 'Speed',
        isActive: false,
        onTap: () {
          setState(() => _showMoreOptionsPanel = false);
          _speedPanelKey.currentState?.show();
        },
      ),
      _buildCircularActionButton(
        icon: Icons.screen_rotation,
        label: AppLocalizations.of(context)!.rotate,
        isActive: !_isFullscreen,
        onTap: _toggleFullscreen,
      ),
      if (_hasChapters)
        _buildCircularActionButton(
          icon: Icons.format_list_bulleted,
          label: AppLocalizations.of(context)!.chapters,
          isActive: (_chaptersPanelKey.currentState?.isVisible ?? false),
          onTap: () {
                    _hideTimer?.cancel();
                    setState(() => _showControls = false);
                    _chaptersPanelKey.currentState?.show();
                  },
        ),
      _buildCircularActionButton(
        icon: Icons.repeat,
        label: AppLocalizations.of(context)!.abRepeat,
        isActive: _abRepeatA != null,
        onTap: _toggleAbRepeat,
      ),
      _buildCircularActionButton(
        icon: Icons.equalizer,
        label: AppLocalizations.of(context)!.equalizer,
        isActive: ref.watch(videoSettingsProvider).audio.equalizerEnabled,
        onTap: _showEqualizerDialog,
      ),
      _buildCircularActionButton(
        icon: _sleepTimerSecondsRemaining != null
            ? Icons.snooze
            : Icons.snooze_outlined,
        label: AppLocalizations.of(context)!.sleepTimer,
        isActive: _sleepTimerSecondsRemaining != null,
        onTap: _showSleepTimerSelector,
      ),
      _buildCircularActionButton(
        icon: Icons.sync,
        label: AppLocalizations.of(context)!.avSync,
        isActive: _audioDelay != 0.0,
        onTap: _showAudioDelayDialog,
      ),
      _buildCircularActionButton(
        icon: Icons.analytics_outlined,
        label: AppLocalizations.of(context)!.stats,
        isActive: ref.watch(videoSettingsProvider).layout.showStatsForNerds,
        onTap: () {
          final s = ref.read(videoSettingsProvider);
          ref
              .read(videoSettingsProvider.notifier)
              .updateSettings(
                s.copyWith(layout: s.layout.copyWith(showStatsForNerds: !s.layout.showStatsForNerds)),
              );
        },
      ),
    ];

    if (items.length <= 3) {
      return Container(
        height: 75,
        margin: const EdgeInsets.only(top: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: items),
        ),
      );
    }

    final firstThree = items.sublist(0, 3);
    final remaining = items.sublist(3);

    return Container(
      height: 75,
      margin: const EdgeInsets.only(top: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ...firstThree,
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _quickActionsExpanded
                  ? Row(mainAxisSize: MainAxisSize.min, children: remaining)
                  : const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _quickActionsExpanded
                            ? Icons.arrow_back
                            : Icons.arrow_forward,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _quickActionsExpanded = !_quickActionsExpanded;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _quickActionsExpanded ? 'Less' : 'More',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final accentColor = customTheme?.settingsAccent ?? theme.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? accentColor.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? accentColor : Colors.white12,
                    width: isActive ? 1.5 : 1.0,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isActive
                      ? accentColor
                      : Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? accentColor : Colors.white70,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hrs = d.inHours;
      final m = (min % 60).toString().padLeft(2, '0');
      return '$hrs:$m:$sec';
    }
    return '$min:$sec';
  }

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final settings = ref.read(videoSettingsProvider);
      if (!settings.layout.showStatsForNerds || !mounted) {
        _statsTimer?.cancel();
        return;
      }

      final player = widget.player;
      final nativePlayer = player.platform;
      if (nativePlayer is NativePlayer) {
        try {
          final results = await Future.wait([
            nativePlayer.getProperty('hwdec-current').catchError((_) => 'no'),
            nativePlayer
                .getProperty('video-out-params/w')
                .catchError((_) => ''),
            nativePlayer
                .getProperty('video-out-params/h')
                .catchError((_) => ''),
            nativePlayer.getProperty('container-fps').catchError((_) => ''),
            nativePlayer
                .getProperty('demuxer-cache-duration')
                .catchError((_) => '0'),
            nativePlayer
                .getProperty('demuxer-cache-state')
                .catchError((_) => '{}'),
            nativePlayer.getProperty('frame-drop-count').catchError((_) => '0'),
          ]);

          final hwdec = results[0];
          final w = results[1];
          final h = results[2];
          final fps = results[3];
          final cacheDuration = results[4];
          final cacheStateStr = results[5];
          final frameDrops = results[6];

          double cacheMb = 0.0;
          if (cacheStateStr.isNotEmpty && cacheStateStr != '{}') {
            try {
              if (cacheStateStr.trim().startsWith('{')) {
                final bytesIdx = cacheStateStr.indexOf('"fw-bytes":');
                if (bytesIdx != -1) {
                  final endIdx = cacheStateStr.indexOf(',', bytesIdx);
                  final bytesStr = cacheStateStr
                      .substring(
                        bytesIdx + 11,
                        endIdx != -1 ? endIdx : cacheStateStr.length,
                      )
                      .replaceAll(RegExp(r'[^\d]'), '');
                  final bytesVal = int.tryParse(bytesStr) ?? 0;
                  cacheMb = bytesVal / (1024 * 1024);
                }
              } else {
                final match = RegExp(
                  r'fw-bytes=(\d+)',
                ).firstMatch(cacheStateStr);
                if (match != null) {
                  final bytesVal = int.tryParse(match.group(1) ?? '0') ?? 0;
                  cacheMb = bytesVal / (1024 * 1024);
                }
              }
            } catch (_) {}
          }

          final proxy = ref.read(streamingProxyServiceProvider).requireValue;
          int? activeFileId;
          final playingUrl =
              widget.player.state.playlist.index >= 0 &&
                  widget.player.state.playlist.index <
                      widget.player.state.playlist.medias.length
              ? widget
                    .player
                    .state
                    .playlist
                    .medias[widget.player.state.playlist.index]
                    .uri
              : '';
          if (StreamingProxyService.isProxyUrl(playingUrl)) {
            final uri = Uri.tryParse(playingUrl);
            if (uri != null) {
              final idStr = uri.queryParameters['fileId'];
              if (idStr != null) {
                activeFileId = int.tryParse(idStr);
              }
            }
          }

          String speedStr = '0 KB/s';
          if (activeFileId != null) {
            final cachedFile = proxy.getCachedFile(activeFileId);
            if (cachedFile != null) {
              final currentDownloaded = cachedFile.local.downloadedSize;
              final lastDownloaded =
                  _lastDownloadedBytes[activeFileId] ?? currentDownloaded;
              final diff = currentDownloaded - lastDownloaded;
              _lastDownloadedBytes[activeFileId] = currentDownloaded;

              if (diff > 0) {
                if (diff < 1024 * 1024) {
                  speedStr = '${(diff / 1024).toStringAsFixed(1)} KB/s';
                } else {
                  speedStr =
                      '${(diff / (1024 * 1024)).toStringAsFixed(2)} MB/s';
                }
              } else if (cachedFile.local.isDownloadingCompleted) {
                speedStr = 'Completed (Local Disk)';
              } else {
                speedStr = '0 KB/s (Idle)';
              }
            }
          }

          if (mounted) {
            setState(() {
              _nerdStats = {
                'Resolution & FPS': w.isNotEmpty && h.isNotEmpty
                    ? '$w x $h @ ${double.tryParse(fps)?.toStringAsFixed(2) ?? fps} fps'
                    : 'Loading...',
                'Decoder': hwdec == 'no' ? 'Software' : hwdec,
                'Forward Buffer':
                    '${cacheMb.toStringAsFixed(1)} MB (${double.tryParse(cacheDuration)?.toStringAsFixed(1) ?? cacheDuration}s)',
                'Download Speed': speedStr,
                'Frame Drops': frameDrops,
              };
            });
          }
        } catch (_) {}
      }
    });
  }

  int _outroThresholdSeconds = 45;

  @override
  void initState() {
    super.initState();
    _gestureHandler = VideoGestureHandler(
      player: widget.player,
      scaleNotifier: _scaleNotifier,
      panNotifier: _panNotifier,
      onSeekStart: () { _hideTimer?.cancel(); },
      onSeek: _performSeek,
      onHideTimerStart: _startHideTimer,
      onOSD: _showOSD,
      formatDuration: _formatDuration,
      isPositionDownloaded: _isPositionDownloaded,
      clampSeekTarget: _clampSeekTarget,
      setState: (VoidCallback fn) {
        if (mounted) setState(fn);
      },
      onSpeedChanged: (speed) => _adjustSyncForSpeed(speed),
    );
    _outroThresholdSeconds = ref.read(storageServiceProvider).getVideoSettings()['outro_threshold_seconds'] as int? ?? 45;
    final settings = ref.read(videoSettingsProvider);
    _nightModeActive = settings.audio.dynamicRangeCompression;
    if (settings.rememberSpeed) {
      final savedSpeed = ref.read(storageServiceProvider).getPlaybackSpeed();
      if (savedSpeed != 1.0) {
        Future.delayed(const Duration(milliseconds: 200), () {
          try {
            widget.player.setRate(savedSpeed);
            _adjustSyncForSpeed(savedSpeed);
          } catch (_) {}
        });
      }
    }
    _startHideTimer();
    _currentVolume = widget.player.state.volume;
    _initSystemVolumeAndBrightness();
    _initAspectRatio();
    if (widget.player.platform is NativePlayer) {
      try {
        (widget.player.platform as NativePlayer)
            .getProperty('audio-delay')
            .then((delayStr) {
              if (mounted) {
                setState(() {
                  _audioDelay = double.tryParse(delayStr) ?? 0.0;
                });
              }
            })
            .catchError((_) {});
      } catch (_) {}
    }
    _bufferingSubscription = widget.player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isBuffering = buffering;
        });
      }
    });
    _positionSubscription = widget.player.stream.position.listen((pos) {
      _checkAutoNextTrigger(pos);
      // _checkSkipTimes(pos);
      _checkAbRepeat(pos);
      if (!_blendSubtitlesChecked && pos.inSeconds > 0) {
        _blendSubtitlesChecked = true;
        _updateBlendSubtitlesForTrack(
          widget.player,
          widget.player.state.track.subtitle,
        );
      }
    });
    _durationSubscription = widget.player.stream.duration.listen((dur) {
      if (dur.inSeconds > 0) {
        _loadChapters();
        _updateBlendSubtitlesForTrack(
          widget.player,
          widget.player.state.track.subtitle,
        );
      }
    });
    _trackSubscription = widget.player.stream.track.listen((track) {
      _updateBlendSubtitlesForTrack(widget.player, track.subtitle);
    });
    _tracksListSubscription = widget.player.stream.tracks.listen((_) {
      _updateBlendSubtitlesForTrack(
        widget.player,
        widget.player.state.track.subtitle,
      );
      if (_trackPanelKey.currentState?.isVisible ?? false) {
        _loadTrackCodecs();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBlendSubtitlesForTrack(
        widget.player,
        widget.player.state.track.subtitle,
      );
    });
    _playlistSubscription = widget.player.stream.playlist.listen((_) {
      if (mounted) {
        setState(() {
          _chapters = [];
          _hasChapters = false;
          _chaptersLoadAttempts = 0;
          _autoNextCancelled = false;
          _autoNextTriggered = false;
          _showAutoNextCountdown = false;
          _autoNextSlideIn = false;
        });
      }
      Future.delayed(const Duration(milliseconds: 500), _loadChapters);
    });
    Future.delayed(const Duration(milliseconds: 500), _loadChapters);
  }

  @override
  void didUpdateWidget(CustomVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _trackSubscription?.cancel();
      _tracksListSubscription?.cancel();
      _bufferingSubscription?.cancel();
      _playlistSubscription?.cancel();
      _volumeSubscription?.cancel();

      _currentVolume = widget.player.state.volume;

      _bufferingSubscription = widget.player.stream.buffering.listen((
        buffering,
      ) {
        if (mounted) {
          setState(() {
            _isBuffering = buffering;
          });
        }
      });
      _positionSubscription = widget.player.stream.position.listen((pos) {
        _checkAutoNextTrigger(pos);
        _checkAbRepeat(pos);
        if (!_blendSubtitlesChecked && pos.inSeconds > 0) {
          _blendSubtitlesChecked = true;
          _updateBlendSubtitlesForTrack(
            widget.player,
            widget.player.state.track.subtitle,
          );
        }
      });
      _durationSubscription = widget.player.stream.duration.listen((dur) {
        if (dur.inSeconds > 0) {
          _loadChapters();
          _updateBlendSubtitlesForTrack(
            widget.player,
            widget.player.state.track.subtitle,
          );
        }
      });
      _trackSubscription = widget.player.stream.track.listen((track) {
        _updateBlendSubtitlesForTrack(widget.player, track.subtitle);
      });
      _tracksListSubscription = widget.player.stream.tracks.listen((_) {
        _updateBlendSubtitlesForTrack(
          widget.player,
          widget.player.state.track.subtitle,
        );
        if (_trackPanelKey.currentState?.isVisible ?? false) {
          _loadTrackCodecs();
        }
      });
      _playlistSubscription = widget.player.stream.playlist.listen((_) {
        if (mounted) {
          setState(() {
            _chapters = [];
            _hasChapters = false;
            _chaptersLoadAttempts = 0;
            _autoNextCancelled = false;
            _autoNextTriggered = false;
            _showAutoNextCountdown = false;
            _autoNextSlideIn = false;
          });
        }
        Future.delayed(const Duration(milliseconds: 500), _loadChapters);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateBlendSubtitlesForTrack(
          widget.player,
          widget.player.state.track.subtitle,
        );
      });
    }
  }

  Future<void> _initSystemVolumeAndBrightness() async {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
    } catch (_) {}

    try {
      final volume = await FlutterVolumeController.getVolume();
      if (volume != null) {
        _currentVolume = volume * 100.0;
        widget.player.setVolume(_currentVolume);
      }
    } catch (_) {}

    try {
      _volumeSubscription = FlutterVolumeController.addListener((volume) {
        if (mounted) {
          setState(() {
            _currentVolume = volume * 100.0;
            widget.player.setVolume(_currentVolume);
          });
        }
      });
    } catch (_) {}

    final savedBrightness = ref.read(storageServiceProvider).getBrightness();
    if (mounted) {
      setState(() {
        _currentBrightness = savedBrightness;
      });
    }

    try {
      await ScreenBrightness().setApplicationScreenBrightness(
        _currentBrightness,
      );
      _isPhysicalBrightnessSupported = true;
    } catch (_) {
      _isPhysicalBrightnessSupported = false;
    }
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _autoNextSlideInTimer?.cancel();
    _autoNextTimer?.cancel();
    _autoNextDismissTimer?.cancel();
    _toastTimer?.cancel();
    // _skipButtonCollapseTimer?.cancel();
    _chaptersRetryTimer?.cancel();
    _bufferingSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _volumeSubscription?.cancel();
    _brightnessSaveTimer?.cancel();
    _hideTimer?.cancel();
    _doubleTapOverlayTimer?.cancel();
    _doubleTapSeekTimer?.cancel();
    _sleepTimer?.cancel();
    _osdTimer?.cancel();
    _trackSubscription?.cancel();
    _tracksListSubscription?.cancel();
    _playlistSubscription?.cancel();
    try {
      FlutterVolumeController.removeListener();
    } catch (_) {}
    try {
      FlutterVolumeController.updateShowSystemUI(true);
    } catch (_) {}
    try {
      ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {}
    super.dispose();
  }

  void _checkAutoNextTrigger(Duration pos) {
    final settings = ref.read(videoSettingsProvider);
    if (!settings.autoplayNextVideo) return;
    if (widget.isPip || !widget.hasNextEpisode || widget.onNextEpisode == null) {
      return;
    }

    final dur = widget.player.state.duration;
    if (dur.inSeconds <= 0) return;

    // Safeguard: Only trigger autoplay next countdown if we are past the first 50% of the video.
    // This prevents premature trigger if the video is very short.
    if (pos.inSeconds < dur.inSeconds * 0.5) return;

    final remaining = dur.inSeconds - pos.inSeconds;

    final bool isOutro = _isCurrentPositionInOutro(pos);
    final outroThreshold = _outroThresholdSeconds;
    final bool shouldTrigger =
        isOutro || (remaining <= outroThreshold && remaining > 0);

    if (shouldTrigger && !_autoNextCancelled && !_autoNextTriggered) {
      _autoNextTriggered = true;
      _startAutoNextCountdown();
    } else if (!shouldTrigger) {
      if (_autoNextTriggered) {
        _cancelAutoNextCountdown();
        _autoNextTriggered = false;
      }
      _autoNextCancelled =
          false; // Reset cancelled state since we are back in normal play region
    }
  }

  void _startAutoNextCountdown() {
    _autoNextTimer?.cancel();
    _autoNextSlideInTimer?.cancel();
    _autoNextDismissTimer?.cancel();

    final outroThreshold = _outroThresholdSeconds;
    final dur = widget.player.state.duration;
    final pos = widget.player.state.position;
    final remaining = (dur.inSeconds - pos.inSeconds).clamp(1, outroThreshold);

    setState(() {
      _showAutoNextCountdown = true;
      _autoNextSecondsRemaining = remaining;
      _autoNextSlideIn = false;
    });

    _autoNextSlideInTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _autoNextSlideIn = true;
        });
      }
    });

    // Automatically slide out the card to the right side after 3 seconds if controls are not showing
    _autoNextDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showAutoNextCountdown && !_showControls) {
        setState(() {
          _autoNextSlideIn = false;
        });
      }
    });

    _autoNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (!widget.player.state.playing) {
          return; // Pause countdown if video is paused!
        }
        setState(() {
          if (_autoNextSecondsRemaining > 1) {
            _autoNextSecondsRemaining--;
          } else {
            _autoNextTimer?.cancel();
            _autoNextSlideInTimer?.cancel();
            _autoNextDismissTimer?.cancel();
            _showAutoNextCountdown = false;
            _autoNextSlideIn = false;
            if (widget.onNextEpisode != null) {
              widget.onNextEpisode!();
            }
          }
        });
      } else {
        _autoNextTimer?.cancel();
        _autoNextSlideInTimer?.cancel();
        _autoNextDismissTimer?.cancel();
      }
    });
  }

  void _cancelAutoNextCountdown() {
    _autoNextTimer?.cancel();
    _autoNextSlideInTimer?.cancel();
    _autoNextDismissTimer?.cancel();
    setState(() {
      _autoNextSlideIn = false;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showAutoNextCountdown = false;
        });
      }
    });
  }

  void _onCancelAutoNext() {
    _cancelAutoNextCountdown();
    setState(() {
      _autoNextCancelled = true;
    });
  }

  bool _isCurrentPositionInOutro(Duration position) {
    if (!_hasChapters || _chapters.isEmpty) return false;
    final totalDuration = widget.player.state.duration.inSeconds.toDouble();
    final posSeconds = position.inSeconds.toDouble();
    for (int i = 0; i < _chapters.length; i++) {
      final ch = _chapters[i];
      final start = ch.position.inSeconds.toDouble();
      final end = (i + 1 < _chapters.length)
          ? _chapters[i + 1].position.inSeconds.toDouble()
          : (totalDuration > 0 ? totalDuration : start + 90.0);
      if (_isChapterOutro(ch, start, end, totalDuration)) {
        if (posSeconds >= start && posSeconds < end) {
          return true;
        }
      }
    }
    return false;
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
          if (_showAutoNextCountdown) {
            _autoNextSlideIn = false;
          }
        });
      }
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    if ((_trackPanelKey.currentState?.isVisible ?? false) ||
        _showRatioPanel ||
        (_speedPanelKey.currentState?.isVisible ?? false) ||
        (_chaptersPanelKey.currentState?.isVisible ?? false) ||
        _showMoreOptionsPanel) {
      setState(() {
        
        _showRatioPanel = false;
        _speedPanelKey.currentState?.hide();
        _showMoreOptionsPanel = false;
        _showControls = true;
      });
      _startHideTimer();
      return;
    }
    setState(() {
      _showControls = !_showControls;
      if (_showAutoNextCountdown) {
        _autoNextSlideIn = _showControls;
      }
    });
    if (_showControls) _startHideTimer();
  }

  void _toggleFullscreen() {
    if (!mounted) return;
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _showSpeedSelectorDialog() {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() {
      _showMoreOptionsPanel = false;
      _speedPanelKey.currentState?.show();
      _showControls = false;
    });
  }

  void _handleDoubleTap(
    TapDownDetails details,
    double screenWidth,
    int seekDuration,
  ) {
    if (!mounted) return;
    if (_isLocked) return;

    final x = details.globalPosition.dx;
    final isLeft = x < screenWidth / 3;
    final isRight = x > screenWidth * 2 / 3;

    if (!isLeft && !isRight) {
      // Middle zone -> Play/Pause
      if (widget.player.state.playing) {
        widget.player.pause();
      } else {
        widget.player.play();
      }
      return;
    }

    _doubleTapOverlayTimer?.cancel();
    _doubleTapSeekTimer?.cancel();

    setState(() {
      if ((isLeft && _showRightSeekOverlay) ||
          (!isLeft && _showLeftSeekOverlay)) {
        // Switch sides, reset accumulation
        _doubleTapStartPosition = widget.player.state.position;
        _doubleTapSeekAccumulated = seekDuration;
        _showLeftSeekOverlay = isLeft;
        _showRightSeekOverlay = !isLeft;
      } else {
        // Same side or first tap in sequence
        if (_doubleTapStartPosition == null) {
          _doubleTapStartPosition = widget.player.state.position;
          _doubleTapSeekAccumulated = seekDuration;
        } else {
          _doubleTapSeekAccumulated += seekDuration;
        }
        if (isLeft) {
          _showLeftSeekOverlay = true;
          _showRightSeekOverlay = false;
        } else {
          _showRightSeekOverlay = true;
          _showLeftSeekOverlay = false;
        }
      }
      _doubleTapSeekOpacity = 1.0;
    });

    final target = isLeft
        ? _doubleTapStartPosition! -
              Duration(seconds: _doubleTapSeekAccumulated)
        : _doubleTapStartPosition! +
              Duration(seconds: _doubleTapSeekAccumulated);

    final dur = widget.player.state.duration;
    final clampedTarget = Duration(
      seconds: target.inSeconds.clamp(
        0,
        dur.inSeconds > 0 ? dur.inSeconds : 86400,
      ),
    );

    final safeTarget = _clampSeekTarget(clampedTarget, showMessage: true);

    _doubleTapSeekTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSeek(safeTarget);
      }
    });

    _doubleTapOverlayTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _doubleTapSeekOpacity = 0.0;
          _doubleTapStartPosition = null;
          _doubleTapSeekAccumulated = 0;
        });
      }
    });
  }

  void _performSeek(Duration target) {
    if (widget.onSeek != null) {
      widget.onSeek!(target);
    } else {
      widget.player.seek(target);
    }
  }
  void _showOSD(String text) {
    _osdTimer?.cancel();
    setState(() {
    });
    _osdTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
        });
      }
    });
  }

  String _formatSleepTimeRemaining(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _startSleepTimerSeconds(int seconds) {
    _cancelSleepTimer();
    setState(() {
      _sleepTimerMinutes = null;
      _sleepTimerSecondsRemaining = seconds;
    });
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_sleepTimerSecondsRemaining != null &&
            _sleepTimerSecondsRemaining! > 1) {
          setState(() {
            _sleepTimerSecondsRemaining = _sleepTimerSecondsRemaining! - 1;
          });
        } else {
          _triggerSleepStop();
        }
      } else {
        _sleepTimer?.cancel();
      }
    });
    _showOSD('Sleep Timer set: ${seconds}s');
  }

  void _startSleepTimer(int minutes) {
    _startSleepTimerSeconds(minutes * 60);
    setState(() {
      _sleepTimerMinutes = minutes;
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    setState(() {
      _sleepTimerMinutes = null;
      _sleepTimerSecondsRemaining = null;
    });
  }

  void _triggerSleepStop() {
    _cancelSleepTimer();
    widget.player.pause();
    widget.onBack();
  }

  void _showSleepTimerSelector() {
    showDialog(
      context: context,
      builder: (context) => SleepTimerPanel(
        sleepTimerMinutes: _sleepTimerMinutes,
        sleepTimerSecondsRemaining: _sleepTimerSecondsRemaining,
        formatSleepTimeRemaining: _formatSleepTimeRemaining,
        onCancelTimer: () {
          _cancelSleepTimer();
          _showOSD('Sleep Timer cancelled');
        },
        onStartTimer: _startSleepTimer,
      ),
    );
  }

  Future<void> _loadChapters() async {
    _chaptersRetryTimer?.cancel();
    try {
      final dynamic platform = widget.player.platform;
      final countStr = await platform.getProperty('chapter-list/count');
      if (countStr != null) {
        final count = int.tryParse(countStr);
        if (count != null && count > 0) {
          final List<VideoChapter> loadedChapters = [];
          final futures = <Future<List<String?>>>[];
          for (int i = 0; i < count; i++) {
            futures.add(
              Future.wait([
                platform.getProperty('chapter-list/$i/title'),
                platform.getProperty('chapter-list/$i/time'),
              ]),
            );
          }
          final results = await Future.wait(futures);
          for (int i = 0; i < count; i++) {
            final title = results[i][0] ?? 'Chapter ${i + 1}';
            final timeStr = results[i][1];
            final timeDouble = double.tryParse(timeStr ?? '');
            if (timeDouble != null) {
              loadedChapters.add(
                VideoChapter(
                  title: title,
                  position: Duration(milliseconds: (timeDouble * 1000).round()),
                ),
              );
            }
          }
          if (mounted) {
            setState(() {
              _chapters = loadedChapters;
              _hasChapters = loadedChapters.isNotEmpty;
              _chaptersLoadAttempts = 0;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted && _chaptersLoadAttempts < 5) {
      _chaptersLoadAttempts++;
      _chaptersRetryTimer = Timer(
        const Duration(milliseconds: 500),
        _loadChapters,
      );
    } else {
      if (mounted) {
        setState(() {
          _chapters = [];
          _hasChapters = false;
        });
      }
    }
  }


  

  

  Duration _clampSeekTarget(
    Duration targetPosition, {
    bool showMessage = true,
  }) {
    if (widget.onSeek != null) return targetPosition;
    if (widget.expectedSize <= 0) return targetPosition;
    final totalDuration = widget.player.state.duration;
    if (totalDuration.inMilliseconds <= 0) return targetPosition;

    final isDownloadedCompleted =
        widget.downloadedPrefixSize >= widget.expectedSize;
    if (isDownloadedCompleted) return targetPosition;

    final double fraction = widget.downloadedPrefixSize / widget.expectedSize;
    final maxPlayableMs = (totalDuration.inMilliseconds * fraction).round();

    if (targetPosition.inMilliseconds > maxPlayableMs) {
      if (showMessage) {
        final now = DateTime.now();
        if (_lastSeekWarningTime == null ||
            now.difference(_lastSeekWarningTime!).inSeconds > 2) {
          _lastSeekWarningTime = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Buffering... Please seek within the downloaded range (${(fraction * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.black87,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      final safeMs = (maxPlayableMs - 2000).clamp(0, maxPlayableMs);
      return Duration(milliseconds: safeMs);
    }
    return targetPosition;
  }



  void _updateAudioFilters() {
    try {
      if (widget.player.platform is NativePlayer) {
        final nativePlayer = widget.player.platform as NativePlayer;
        final filters = <String>[];
        if (_audioBoostActive) {
          filters.add('volume=volume=6dB:precision=fixed');
        }
        if (_nightModeActive) {
          filters.add('lavfi=[dynaudnorm]');
        }

        final settings = ref.read(videoSettingsProvider);
        if (settings.audio.equalizerEnabled) {
          final bands = settings.audio.equalizerBands;
          filters.add('equalizer=f=100:width_type=o:w=2.0:g=${bands[0]}');
          filters.add('equalizer=f=300:width_type=o:w=2.0:g=${bands[1]}');
          filters.add('equalizer=f=1000:width_type=o:w=2.0:g=${bands[2]}');
          filters.add('equalizer=f=3000:width_type=o:w=2.0:g=${bands[3]}');
          filters.add('equalizer=f=10000:width_type=o:w=2.0:g=${bands[4]}');
        }

        if (filters.isNotEmpty) {
          nativePlayer.setProperty('af', filters.join(','));
          Log.i('Applied audio filters: ${filters.join(',')}');
        } else {
          nativePlayer.setProperty('af', '');
          Log.i('Cleared all audio filters');
        }

        if (settings.audio.dynamicRangeCompression != _nightModeActive) {
          ref
              .read(videoSettingsProvider.notifier)
              .updateSettings(
                settings.copyWith(
                  audio: settings.audio.copyWith(
                    dynamicRangeCompression: !settings.audio.dynamicRangeCompression,
                  ),
                ),
              );
        }
      }
    } catch (e) {
      Log.w('Failed to update audio filters: $e');
    }
  }

  void _initAspectRatio() {
    final storage = ref.read(storageServiceProvider);
    _rememberRatio = storage.getRememberAspectRatio();
    _tapToSwitchRatio = storage.getTapToSwitchAspectRatio();
    if (_rememberRatio) {
      _currentAspectRatioString = storage.getSavedAspectRatio();
    } else {
      _currentAspectRatioString = 'fit';
    }
    _applyAspectRatioString(_currentAspectRatioString, save: false);
  }

  /// Dynamically adjusts mpv A/V sync properties based on current playback speed.
  /// At higher speeds, audio needs larger buffers and video sync needs more tolerance
  /// to prevent A/V desynchronization.
  void _adjustSyncForSpeed(double speed) {
    if (widget.player.platform is NativePlayer) {
      final nativePlayer = widget.player.platform as NativePlayer;
      
      if (speed > 1.5) {
        // High speed: increase audio buffer proportionally to prevent starvation
        // Formula: base 0.2s * speed factor, capped at 2.0s to avoid latency
        final audioBuffer = (0.2 * speed).clamp(0.2, 2.0);
        nativePlayer.setProperty('audio-buffer', audioBuffer.toStringAsFixed(2));
        
        // Allow video to drift more from display refresh at high speed
        // This prevents frame drops that cause video to run ahead of audio
        nativePlayer.setProperty('video-sync-max-video-change', '0.5');
        
        // Reduce interpolation at high speed - it causes frame timing issues above 2x
        if (speed > 2.0) {
          nativePlayer.setProperty('interpolation', 'no');
        } else {
          nativePlayer.setProperty('interpolation', 'yes');
        }
        
        // At very high speeds (>3x), use resample-vdrop which drops video frames
        // but maintains audio-video clock sync
        if (speed > 3.0) {
          nativePlayer.setProperty('video-sync', 'resample-vdrop');
        } else {
          nativePlayer.setProperty('video-sync', 'display-resample');
        }
        
        // Increase demuxer readahead at high speed so data keeps flowing
        final readahead = (180 * speed).clamp(180, 600).round();
        nativePlayer.setProperty('demuxer-readahead-secs', readahead.toString());
        
        // At extreme speeds, use scaletempo2 (better quality than scaletempo)
        if (speed > 2.0) {
          nativePlayer.setProperty('af', 'scaletempo2');
        }
        
        // At high speeds, subtitles flash by too fast - increase subtitle delay proportionally
        final baseDelay = ref.read(storageServiceProvider).getSubtitleDelay() ?? 0.0;
        final adjustedDelay = baseDelay + (speed - 1.0) * 0.3; // Add 0.3s per speed unit above 1.0
        nativePlayer.setProperty('sub-delay', adjustedDelay.toStringAsFixed(2));
      } else {
        // Normal speed: restore optimal quality settings
        nativePlayer.setProperty('audio-buffer', '0.2');
        nativePlayer.setProperty('video-sync', 'display-resample');
        nativePlayer.setProperty('interpolation', 'yes');
        nativePlayer.setProperty('video-sync-max-video-change', '0.04');
        nativePlayer.setProperty('demuxer-readahead-secs', '180');
        
        // Clear speed-specific audio filter if no user EQ/boost is active
        final settings = ref.read(videoSettingsProvider);
        if (!settings.audio.equalizerEnabled && !settings.audio.dynamicRangeCompression) {
          nativePlayer.setProperty('af', '');
        }
        
        // Restore original subtitle delay
        final baseDelay = ref.read(storageServiceProvider).getSubtitleDelay() ?? 0.0;
        nativePlayer.setProperty('sub-delay', baseDelay.toStringAsFixed(2));
      }
    }
  }

  void _applyAspectRatioString(String ratioString, {bool save = true}) {
    double? customRatio;
    BoxFit boxFit = BoxFit.contain;

    switch (ratioString) {
      case 'fit':
        boxFit = BoxFit.contain;
        customRatio = null;
        break;
      case 'fill':
        boxFit = BoxFit.cover;
        customRatio = null;
        break;
      case 'original':
        boxFit = BoxFit.none;
        customRatio = null;
        break;
      case 'stretch':
        boxFit = BoxFit.fill;
        customRatio = null;
        break;

      case '16:9':
        customRatio = 16.0 / 9.0;
        break;
      case '4:3':
        customRatio = 4.0 / 3.0;
        break;
      case '18:9':
        customRatio = 18.0 / 9.0;
        break;
      case '19.5:9':
        customRatio = 19.5 / 9.0;
        break;
      case '20:9':
        customRatio = 20.0 / 9.0;
        break;
      case '21:9':
        customRatio = 21.0 / 9.0;
        break;

      case '1.85:1':
        customRatio = 1.85;
        break;
      case '2.21:1':
        customRatio = 2.21;
        break;
      case '2.35:1':
        customRatio = 2.35;
        break;
      case '2.39:1':
        customRatio = 2.39;
        break;

      default:
        boxFit = BoxFit.contain;
        customRatio = null;
    }

    if (mounted) {
      _customAspectRatioNotifier.value = customRatio;
      _fitNotifier.value = boxFit;
      _scaleNotifier.value = 1.0;
      _panNotifier.value = Offset.zero;
      setState(() {
        _currentAspectRatioString = ratioString;
      });
    }

    if (save && _rememberRatio) {
      ref.read(storageServiceProvider).setSavedAspectRatio(ratioString);
    }
  }



  void _handleAspectRatioButtonTap() {
    if (_tapToSwitchRatio) {
      _cycleAspectRatio();
    } else {
      _showAspectRatioPanel();
    }
  }

  void _cycleAspectRatio() {
    const cycle = ['fit', 'original', 'fill', 'stretch', '16:9', '4:3', '21:9'];
    int currentIndex = cycle.indexOf(_currentAspectRatioString);
    if (currentIndex == -1) {
      currentIndex = 0;
    } else {
      currentIndex = (currentIndex + 1) % cycle.length;
    }
    final nextRatio = cycle[currentIndex];
    _applyAspectRatioString(nextRatio);

    setState(() {
    });
    _hideTimer?.cancel();
    _startHideTimer();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
      }
    });
  }

  void _showAspectRatioPanel() {
    setState(() {
      _showRatioPanel = true;
      _showControls = false;
    });
  }

  void _closeAspectRatioPanel() {
    setState(() {
      _showRatioPanel = false;
      _showControls = true;
    });
    _startHideTimer();
  }

  Future<void> _loadTrackCodecs() async {
    try {
      if (widget.player.platform is NativePlayer) {
        final nativePlayer = widget.player.platform as NativePlayer;
        final countStr = await nativePlayer.getProperty('track-list/count');
        final count = int.tryParse(countStr) ?? 0;
        final Map<String, String> codecs = {};
        for (int i = 0; i < count; i++) {
          final type = await nativePlayer.getProperty('track-list/$i/type');
          final id = await nativePlayer.getProperty('track-list/$i/id');
          final codec = await nativePlayer.getProperty('track-list/$i/codec');
          codecs['$type/$id'] = codec.toString();
        }
        if (mounted) {
          setState(() {
            _trackCodecs = codecs;
          });
        }
      }
    } catch (e) {
      Log.w('Failed to load track codecs: $e');
    }
  }

  void _showTrackSelector({required String title, required bool isSubtitle}) {
    _loadTrackCodecs();
    _trackPanelKey.currentState?.show(isSubtitle);
    setState(() {
      _showControls = false;
    });
  }

  void _handleTrackSelection(dynamic track) {
    final storage = ref.read(storageServiceProvider);
    final isSub = _trackPanelKey.currentState?.isSubtitle ?? true;
    
    if (isSub) {
      widget.player.setSubtitleTrack(track);
      final settings = ref.read(videoSettingsProvider);
      final isNativeSub = settings.subtitles.subtitleRendererMode == 'native';
      _applySubtitleProperty(
        'sub-visibility',
        (track.id == 'no' || !isNativeSub) ? 'no' : 'yes',
      );
      _updateBlendSubtitlesForTrack(widget.player, track);

      final activeAudio = widget.player.state.track.audio;
      String audioLangCategory = 'other';
      final lower = (activeAudio.language ?? activeAudio.title ?? '')
          .toLowerCase();
      if (lower.contains('jpn') ||
          lower.contains('ja') ||
          lower.contains('japanese')) {
        audioLangCategory = 'jpn';
      } else if (lower.contains('eng') ||
          lower.contains('en') ||
          lower.contains('english')) {
        audioLangCategory = 'eng';
      }

      final trackPrefVal = track.id == 'no'
          ? 'no'
          : (track.language ?? track.title ?? track.id);
      storage.setPreferredSubtitleTrackForAudioLanguage(
        audioLangCategory,
        trackPrefVal,
      );
      Log.i(
        'Saved subtitle preference ($trackPrefVal) for audio language category ($audioLangCategory)',
      );

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          final activeSub = widget.player.state.track.subtitle;
          Log.i('Active subtitle track verified: ${activeSub.id}');
          if (activeSub.id != track.id && track.id != 'no') {
            Log.w(
              'Discrepancy in subtitle track verification. Retrying setSubtitleTrack...',
            );
            widget.player.setSubtitleTrack(track);
          }
        }
      });
    } else {
      final activeSub = widget.player.state.track.subtitle;
      widget.player.setAudioTrack(track);
      final audioPrefVal = track.id == 'auto'
          ? 'auto'
          : (track.language ?? track.title ?? track.id);
      storage.setPreferredAudioTrack(audioPrefVal);
      Log.i('Saved audio preference ($audioPrefVal)');

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          final newTracks = widget.player.state.tracks.subtitle;
          SubtitleTrack matchedSub = activeSub;

          for (final t in newTracks) {
            if (t.id == activeSub.id) {
              matchedSub = t;
              break;
            }
          }

          if (matchedSub.id != activeSub.id) {
            for (final t in newTracks) {
              if ((t.title != null && t.title == activeSub.title) ||
                  (t.language != null && t.language == activeSub.language)) {
                matchedSub = t;
                break;
              }
            }
          }

          widget.player.setSubtitleTrack(matchedSub);
          _updateBlendSubtitlesForTrack(widget.player, matchedSub);
          Log.i(
            'Re-applied subtitle track after audio track change: ${matchedSub.id} (originally: ${activeSub.id})',
          );
        }
      });
    }


    // Force a buffer flush to prevent MPV from stalling when changing HTTP streams.
    // Seeking to the exact current position forces libavformat to re-init the stream and immediately resume.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && widget.player.state.playing) {
        widget.player.seek(widget.player.state.position);
        widget.player.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final settings = ref.watch(videoSettingsProvider);
    if (settings.layout.showStatsForNerds &&
        (_statsTimer == null || !_statsTimer!.isActive)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startStatsTimer();
      });
    }
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    final subtitleConfig = const SubtitleViewConfiguration(visible: false);

    if (widget.isDesktop) {
      return Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.space): const _PlayPauseIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekBackwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekForwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyF): const _FullscreenIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyM): const _MuteIntent(),
        },
        child: Actions(
          actions: {
            _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(onInvoke: (_) => widget.player.playOrPause()),
            _SeekBackwardIntent: CallbackAction<_SeekBackwardIntent>(onInvoke: (_) => _performSeek(widget.player.state.position - const Duration(seconds: 5))),
            _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(onInvoke: (_) => _performSeek(widget.player.state.position + const Duration(seconds: 5))),
            _FullscreenIntent: CallbackAction<_FullscreenIntent>(onInvoke: (_) => _toggleFullscreen()),
            _MuteIntent: CallbackAction<_MuteIntent>(onInvoke: (_) => _toggleMute()),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoLayer(
                  controller: widget.controller,
                  fitNotifier: _fitNotifier,
                  customAspectRatioNotifier: _customAspectRatioNotifier,
                  scaleNotifier: _scaleNotifier,
                  panNotifier: _panNotifier,
                  subtitleConfig: subtitleConfig,
                  isBuffering: _isBuffering,
                  customBuffering: widget.customBuffering,
                ),
                if (_showControls)
                  GestureDetector(
                    onTap: () {
                      if (widget.player.state.playing) {
                        widget.player.pause();
                      } else {
                        widget.player.play();
                      }
                      _startHideTimer();
                    },
                    child: Container(color: Colors.transparent),
                  ),
                AutoNextOverlay(
                  showAutoNextCountdown: _showAutoNextCountdown,
                  autoNextSlideIn: _autoNextSlideIn,
                  autoNextSecondsRemaining: _autoNextSecondsRemaining,
                  showControls: _showControls,
                  onCancelAutoNext: _onCancelAutoNext,
                  onPlayNow: () {
                    _cancelAutoNextCountdown();
                    if (widget.onNextEpisode != null) {
                      widget.onNextEpisode!();
                    }
                  },
                ),
                if (_toastShowing)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _toastMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                if (!_isBlendingSubtitles) SubtitleOverlay(player: widget.player),
                if (settings.layout.showStatsForNerds && _nerdStats.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: NerdStatsOverlay(nerdStats: _nerdStats),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.space): const _PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyF): const _FullscreenIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyM): const _MuteIntent(),
      },
      child: Actions(
        actions: {
          _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(onInvoke: (_) => widget.player.playOrPause()),
          _SeekBackwardIntent: CallbackAction<_SeekBackwardIntent>(onInvoke: (_) => _performSeek(widget.player.state.position - const Duration(seconds: 5))),
          _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(onInvoke: (_) => _performSeek(widget.player.state.position + const Duration(seconds: 5))),
          _FullscreenIntent: CallbackAction<_FullscreenIntent>(onInvoke: (_) => _toggleFullscreen()),
          _MuteIntent: CallbackAction<_MuteIntent>(onInvoke: (_) => _toggleMute()),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: _toggleControls,
            onScaleStart: (d) => _gestureHandler.handleScaleStart(d, isLocked: _isLocked),
      onScaleUpdate: (d) => _gestureHandler.handleScaleUpdate(
        d, screenWidth, settings.gestures.pinchToZoom,
        settings.gestures.volumeGestures, settings.gestures.brightnessGestures,
        settings.gestures.horizontalSwipeToSeek, settings.gestures,
        ref.read(storageServiceProvider), isLocked: _isLocked,
      ),
      onScaleEnd: (d) => _gestureHandler.handleScaleEnd(d),
      onDoubleTapDown: (details) => _handleDoubleTap(
        details,
        screenWidth,
        settings.gestures.doubleTapSeekDuration,
      ),
      onLongPressStart: (details) {
        if (_isLocked || !settings.layout.dynamicSpeedOverlay) return;
        final speed = settings.gestures.longPressSpeed;
        if (settings.gestures.longPressVibration) {
          HapticFeedback.heavyImpact();
        }
        _preLongPressSpeed = widget.player.state.rate;
        widget.player.setRate(speed);
        setState(() {
        });
      },
      onLongPressEnd: (details) {
        if (!settings.layout.dynamicSpeedOverlay) return;
        widget.player.setRate(_preLongPressSpeed);
        setState(() {
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer with Pinch to Zoom
            VideoLayer(
              controller: widget.controller,
              fitNotifier: _fitNotifier,
              customAspectRatioNotifier: _customAspectRatioNotifier,
              scaleNotifier: _scaleNotifier,
              panNotifier: _panNotifier,
              subtitleConfig: subtitleConfig,
              isBuffering: _isBuffering,
              customBuffering: widget.customBuffering,
            ),

          // Simulated Brightness
          if (!_isPhysicalBrightnessSupported && _currentBrightness < 1.0)
            IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 1.0 - _currentBrightness),
              ),
            ),

          if (!_isBlendingSubtitles) SubtitleOverlay(player: widget.player),
          if (_showLeftSeekOverlay)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: screenWidth * 0.35,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _doubleTapSeekOpacity,
                  duration: const Duration(milliseconds: 200),
                  onEnd: () {
                    if (_doubleTapSeekOpacity == 0.0) {
                      setState(() {
                        _showLeftSeekOverlay = false;
                        _doubleTapStartPosition = null;
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(screenWidth * 0.35),
                        bottomRight: Radius.circular(screenWidth * 0.35),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FlashingChevrons(isLeft: true),
                          const SizedBox(height: 8),
                          Text(
                            '-$_doubleTapSeekAccumulated seconds',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black54,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_showRightSeekOverlay)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: screenWidth * 0.35,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _doubleTapSeekOpacity,
                  duration: const Duration(milliseconds: 200),
                  onEnd: () {
                    if (_doubleTapSeekOpacity == 0.0) {
                      setState(() {
                        _showRightSeekOverlay = false;
                        _doubleTapStartPosition = null;
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(screenWidth * 0.35),
                        bottomLeft: Radius.circular(screenWidth * 0.35),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FlashingChevrons(isLeft: false),
                          const SizedBox(height: 8),
                          Text(
                            '+$_doubleTapSeekAccumulated seconds',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black54,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Indicators
          BrightnessIndicatorOverlay(brightness: _gestureHandler.currentBrightness, visible: _gestureHandler.showBrightnessIndicator && !_isLocked),
          VolumeIndicatorOverlay(volume: _gestureHandler.currentVolume, visible: _gestureHandler.showVolumeIndicator && !_isLocked),
          if (_gestureHandler.showSpeedIndicator && !_isLocked && _gestureHandler.dragStartFocalPoint != null)
            Positioned(
              top: 100,
              left: _gestureHandler.dragStartFocalPoint!.dx <= screenWidth / 2 ? 40 : null,
              right: _gestureHandler.dragStartFocalPoint!.dx > screenWidth / 2 ? 40 : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.speed, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    StreamBuilder<double>(
                      stream: widget.player.stream.rate,
                      builder: (context, snapshot) {
                        final speed = snapshot.data ?? widget.player.state.rate;
                        return Text(
                          '${speed.toStringAsFixed(2)}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          SeekIndicatorOverlay(direction: _gestureHandler.seekDirection, visible: _gestureHandler.showSeekIndicator && !_isLocked),

          // Locked overlay
          if (_isLocked && _showControls)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12, width: 1.0),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.lock, color: Colors.white),
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() => _isLocked = false);
                          _startHideTimer();
                        },
                        tooltip: 'Unlock Screen',
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Controls UI Overlay
          if (_showControls && !_isLocked)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.22, 0.78, 1.0],
                  ),
                ),
              ),
            ),

          if (_showControls &&
              !_isLocked &&
              !(_trackPanelKey.currentState?.isVisible ?? false) &&
              !_showRatioPanel &&
              !(_speedPanelKey.currentState?.isVisible ?? false) &&
              !_showMoreOptionsPanel) ...[
            // Top Bar & Quick Actions
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: PlayerHeaderBar(
                videoTitle: widget.videoTitle,
                onBack: widget.onBack,
                sleepTimerSecondsRemaining: _sleepTimerSecondsRemaining,
                formatSleepTimeRemaining: _formatSleepTimeRemaining,
                decoderModeLabel: _getDecoderModeLabel(),
                onToggleDecoderMode: _toggleDecoderMode,
                onShowSubtitles: () =>
                    _showTrackSelector(title: 'Subtitles', isSubtitle: true),
                onShowAudioTracks: () => _showTrackSelector(
                  title: 'Audio Tracks',
                  isSubtitle: false,
                ),
                onShowQueue: _showQueueManagerSheet,
                onShowMoreOptions: () {
                  _hideTimer?.cancel();
                  setState(() {
                    _showMoreOptionsPanel = true;
                    _showControls = false;
                  });
                },
                settingsAccent: settingsAccent,
              ),
            ),

            // Middle-Right Screenshot Camera Button
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Material3ExpressiveContainer(
                      shape: ExpressiveShape.squircle,
                      size: 44,
                      onTap: _takeScreenshot,
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Bar seekbar and playback controls
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerSeekBar(
                    player: widget.player,
                    downloadedPrefixSize: widget.downloadedPrefixSize,
                    expectedSize: widget.expectedSize,
                    activeDownloadOffset: widget.activeDownloadOffset,
                    activeDownloadedSize: widget.activeDownloadedSize,
                    seekbarStyle: settings.layout.seekbarStyle,
                    settingsAccent: settingsAccent,
                    isPositionDownloaded: _isPositionDownloaded,
                    throttledSeek: _throttledSeek,
                    cancelHideTimer: () => _hideTimer?.cancel(),
                    startHideTimer: _startHideTimer,
                    clampSeekTarget: (target) =>
                        _clampSeekTarget(target, showMessage: false),
                    onSeekPerformed: _performSeek,
                    chapters: _chapters,
                  ),
                  const SizedBox(height: 10),
                  isPortrait
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Row 1: Playback Controls (Previous, Play/Pause, Next) - STRICTLY CENTERED
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Material3ExpressiveContainer(
                                  shape: ExpressiveShape.capsule,
                                  size: 44,
                                  onTap: widget.hasPrevEpisode
                                      ? widget.onPrevEpisode
                                      : null,
                                  inactiveColor: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Icon(
                                    Icons.skip_previous_rounded,
                                    color: widget.hasPrevEpisode
                                        ? Colors.white
                                        : Colors.white24,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                StreamBuilder<bool>(
                                  stream: widget.player.stream.playing,
                                  builder: (context, snapshot) {
                                    return Material3ExpressiveSquigglyPlayButton(
                                      player: widget.player,
                                    );
                                  },
                                ),
                                const SizedBox(width: 24),
                                Material3ExpressiveContainer(
                                  shape: ExpressiveShape.capsule,
                                  size: 44,
                                  onTap: widget.hasNextEpisode
                                      ? widget.onNextEpisode
                                      : null,
                                  inactiveColor: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Icon(
                                    Icons.skip_next_rounded,
                                    color: widget.hasNextEpisode
                                        ? Colors.white
                                        : Colors.white24,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Row 2: Utility Controls (Lock, Spacer, +90s, Speed, Aspect Ratio)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Material3ExpressiveContainer(
                                  shape: ExpressiveShape.squircle,
                                  size: 40,
                                  onTap: () {
                                    setState(() => _isLocked = true);
                                    _startHideTimer();
                                  },
                                  child: const Icon(
                                    Icons.lock_open_rounded,
                                    color: Colors.white70,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          final target =
                                              widget.player.state.position +
                                              const Duration(seconds: 90);
                                          final safeTarget = _clampSeekTarget(
                                            target,
                                            showMessage: false,
                                          );
                                          _performSeek(safeTarget);
                                        },
                                        borderRadius: BorderRadius.circular(
                                          20,
                                        ),
                                        child: Container(
                                          height: 32,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.white24,
                                              width: 1,
                                            ),
                                            color: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.fast_forward,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '+90s',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: _showSpeedSelectorDialog,
                                      child: StreamBuilder<double>(
                                        stream: widget.player.stream.rate,
                                        builder: (context, snapshot) {
                                          final speed = snapshot.data ?? widget.player.state.rate;
                                          return Text(
                                            'Speed (${speed.toStringAsFixed(2)}x)',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.fit_screen_outlined,
                                        color: Colors.white,
                                      ),
                                      iconSize: 24,
                                      onPressed: _handleAspectRatioButtonTap,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 5.0,
                                        sigmaY: 5.0,
                                      ),
                                      child: Material3ExpressiveContainer(
                                        shape: ExpressiveShape.squircle,
                                        size: 40,
                                        onTap: () {
                                          setState(() => _isLocked = true);
                                          _startHideTimer();
                                        },
                                        child: const Icon(
                                          Icons.lock_open_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material3ExpressiveContainer(
                                      shape: ExpressiveShape.capsule,
                                      size: 44,
                                      onTap: widget.hasPrevEpisode
                                          ? widget.onPrevEpisode
                                          : null,
                                      inactiveColor: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: Icon(
                                        Icons.skip_previous_rounded,
                                        color: widget.hasPrevEpisode
                                            ? Colors.white
                                            : Colors.white24,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Material3ExpressiveSquigglyPlayButton(
                                      player: widget.player,
                                    ),
                                    const SizedBox(width: 24),
                                    Material3ExpressiveContainer(
                                      shape: ExpressiveShape.capsule,
                                      size: 44,
                                      onTap: widget.hasNextEpisode
                                          ? widget.onNextEpisode
                                          : null,
                                      inactiveColor: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: Icon(
                                        Icons.skip_next_rounded,
                                        color: widget.hasNextEpisode
                                            ? Colors.white
                                            : Colors.white24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            final target =
                                                widget.player.state.position +
                                                const Duration(seconds: 90);
                                            final safeTarget = _clampSeekTarget(
                                              target,
                                              showMessage: false,
                                            );
                                            _performSeek(safeTarget);
                                          },
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Container(
                                            height: 36,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: Colors.white24,
                                                width: 1,
                                              ),
                                              color: Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.fast_forward,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '+90s',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      TextButton(
                                        onPressed: _showSpeedSelectorDialog,
                                        child: StreamBuilder<double>(
                                          stream: widget.player.stream.rate,
                                          builder: (context, snapshot) {
                                            final speed = snapshot.data ?? widget.player.state.rate;
                                            return Text(
                                              'Speed (${speed.toStringAsFixed(2)}x)',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.fit_screen_outlined,
                                          color: Colors.white,
                                        ),
                                        iconSize: 24,
                                        onPressed: _handleAspectRatioButtonTap,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ],

          // Auto Play Next Countdown Overlay
          AutoNextOverlay(
            showAutoNextCountdown: _showAutoNextCountdown,
            autoNextSlideIn: _autoNextSlideIn,
            autoNextSecondsRemaining: _autoNextSecondsRemaining,
            showControls: _showControls,
            onCancelAutoNext: _onCancelAutoNext,
            onPlayNow: () {
              _cancelAutoNextCountdown();
              if (widget.onNextEpisode != null) {
                widget.onNextEpisode!();
              }
            },
          ),

          // Toast Message for Auto Skip / Actions
          if (_toastShowing)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        _toastMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Stats for Nerds Overlay
          if (settings.layout.showStatsForNerds && _nerdStats.isNotEmpty)
            Positioned(
              top: 185,
              left: 16,
              child: NerdStatsOverlay(nerdStats: _nerdStats),
            ),

          // Custom Track Selector Panel
          TrackSelectorPanel(
            key: _trackPanelKey,
            player: widget.player,
            trackCodecs: _trackCodecs,
            currentAudioDelay: _audioDelay,
            onAudioDelayChanged: (val) {
              if (mounted) {
                setState(() => _audioDelay = val);
              }
            },
            onTrackSelected: _handleTrackSelection,
            onPickLocalSubtitle: _pickLocalSubtitleFile,
            onOpenSubtitleDownloader: _showSubtitleDownloaderDialog,
            onVisibilityChanged: () => setState(() {}),
          ),

          // Custom Aspect Ratio Panel Background Cover
          if (_showRatioPanel)
            GestureDetector(
              onTap: () => setState(() => _showRatioPanel = false),
              child: Container(color: Colors.black26),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: isPortrait ? 0 : null,
            right: isPortrait ? 0 : (_showRatioPanel ? 0 : -400),
            top: isPortrait ? null : 0,
            bottom: isPortrait ? (_showRatioPanel ? 0 : -800) : 0,
            width: isPortrait ? null : 380,
            child: AspectRatioPanel(
              onClose: _closeAspectRatioPanel,
              currentFit: _fitNotifier.value,
              customAspectRatio: _customAspectRatioNotifier.value,
              onSelectRatio: _applyAspectRatioString,
              rememberRatio: _rememberRatio,
              onToggleRememberRatio: (val) {
                setState(() {
                  _rememberRatio = val;
                });
                ref.read(storageServiceProvider).setRememberAspectRatio(val);
                if (val) {
                  ref.read(storageServiceProvider).setSavedAspectRatio(_currentAspectRatioString);
                }
              },
              tapToSwitchRatio: _tapToSwitchRatio,
              onToggleTapToSwitch: (val) {
                setState(() {
                  _tapToSwitchRatio = val;
                });
                ref.read(storageServiceProvider).setTapToSwitchAspectRatio(val);
              },
            ),
          ),

                    ChaptersPanel(
            key: _chaptersPanelKey,
            player: widget.player,
            chapters: _chapters,
            onVisibilityChanged: () {
              if (!mounted) return;
              setState(() {
                _showControls = !(_chaptersPanelKey.currentState?.isVisible ?? false);
              });
            },
            onChapterSelected: (position, displayTitle) {
              final safeTarget = _clampSeekTarget(position, showMessage: false);
              _performSeek(safeTarget);
              setState(() {
              });
              Future.delayed(const Duration(milliseconds: 1000), () {
              });
            },
          ),

          // Custom Speed Selector Panel Background Cover
          SpeedSelectorPanel(
            key: _speedPanelKey,
            player: widget.player,
            onVisibilityChanged: () {
              setState(() {
                _showControls = !(_speedPanelKey.currentState?.isVisible ?? false);
              });
            },
            onSpeedChanged: (speed) {
              _adjustSyncForSpeed(speed);
            },
          ),

          // Custom More Options Panel Background Cover
          if (_showMoreOptionsPanel)
            GestureDetector(
              onTap: () => setState(() => _showMoreOptionsPanel = false),
              child: Container(color: Colors.black26),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: isPortrait ? 0 : null,
            right: isPortrait ? 0 : (_showMoreOptionsPanel ? 0 : -400),
            top: isPortrait ? null : 0,
            bottom: isPortrait ? (_showMoreOptionsPanel ? 0 : -800) : 0,
            width: isPortrait ? null : 380,
            child: MoreOptionsPanel(
              player: widget.player,
              quickActionRow: _buildQuickActionRow(),
              onClose: () => setState(() => _showMoreOptionsPanel = false),
              onShowToast: _showSkipToast,
            ),
          ),
        ],
      ),
    ),
        ),
      ),
    );
  }

    Future<void> _pickLocalSubtitleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub'],
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        final fileName = result.files.single.name;

        final tempDir = await getTemporaryDirectory();
        final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final targetFile = File('${tempDir.path}/local_$safeName');

        await pickedFile.copy(targetFile.path);
        Log.i('Local subtitle picked and copied to: ${targetFile.path}');

        widget.player.setSubtitleTrack(SubtitleTrack.uri(targetFile.path));

        if (mounted) {
          setState(() {
            
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Local subtitle loaded successfully: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Error picking local subtitle file', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load local subtitle: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSubtitleDownloaderDialog() {
    SubtitleDownloaderDialog.show(
      context,
      player: widget.player,
      defaultQuery: widget.videoTitle,
    );
  }

  void _showQueueManagerSheet() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return QueueDialogSheet(
          onStartHideTimer: _startHideTimer,
        );
      },
    ).then((_) {
      _startHideTimer();
    });
  }

  void _showEqualizerDialog() {
    EqualizerDialog.show(context, onFiltersUpdated: _updateAudioFilters);
  }

  void _showAudioDelayDialog() {
    AudioSyncDialog.show(
      context,
      player: widget.player,
      currentDelay: _audioDelay,
      onDelayChanged: (val) {
        setState(() {
          _audioDelay = val;
        });
      },
    );
  }

  Future<void> _updateBlendSubtitlesForTrack(
    Player player,
    SubtitleTrack track,
  ) async {
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        String targetId = track.id;
        if (targetId == 'auto') {
          final sid = await nativePlayer.getProperty('sid');
          if (sid == 'no' || sid == 'auto') {
            nativePlayer.setProperty('blend-subtitles', 'no');
            if (mounted && _isBlendingSubtitles) {
              setState(() {
                _isBlendingSubtitles = false;
              });
            }
            return;
          }
          targetId = sid;
        } else if (targetId == 'no') {
          nativePlayer.setProperty('blend-subtitles', 'no');
          if (mounted && _isBlendingSubtitles) {
            setState(() {
              _isBlendingSubtitles = false;
            });
          }
          return;
        }

        final settings = ref.read(videoSettingsProvider);
        final targetLibass = settings.subtitles.subtitleRendererMode == 'native';
        final useNativeBlending = targetLibass;

        if (useNativeBlending) {
          nativePlayer.setProperty('blend-subtitles', 'yes');
          Log.i(
            'Native blending subtitle enabled. Set blend-subtitles to yes.',
          );
          if (mounted && !_isBlendingSubtitles) {
            setState(() {
              _isBlendingSubtitles = true;
            });
          }
        } else {
          nativePlayer.setProperty('blend-subtitles', 'no');
          Log.i(
            'Native blending subtitle disabled. Set blend-subtitles to no.',
          );
          if (mounted && _isBlendingSubtitles) {
            setState(() {
              _isBlendingSubtitles = false;
            });
          }

          // Show SnackBar warning if on Android and using direct hardware decoding with a graphical/ASS track
          // ONLY if not in Flutter overlay mode (which handles rendering anyway)
          final isTargetAssOrPgs = settings.subtitles.subtitleRendererMode == 'native';
          if (Platform.isAndroid && mounted && isTargetAssOrPgs) {
            try {
              final countStr = await nativePlayer.getProperty(
                'track-list/count',
              );
              final count = int.tryParse(countStr) ?? 0;
              for (int i = 0; i < count; i++) {
                final type = await nativePlayer.getProperty(
                  'track-list/$i/type',
                );
                final id = await nativePlayer.getProperty('track-list/$i/id');
                if (type == 'sub' && id == targetId) {
                  final codec = (await nativePlayer.getProperty(
                    'track-list/$i/codec',
                  )).toLowerCase();
                  final isGraphical =
                      codec.contains('pgs') ||
                      codec.contains('hdmv') ||
                      codec.contains('dvd') ||
                      codec.contains('vob') ||
                      codec.contains('dvb') ||
                      codec == 'xsub';
                  final isAss = codec.contains('ass') || codec.contains('ssa');
                  if (mounted) {
                    if (isGraphical) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'PGS/graphical subtitles require HW+ (Compatible) or SW decoder to render on Android.',
                          ),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    } else if (isAss) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ASS/SSA subtitles rendered in text mode. Switch to HW+ or SW for full native styling.',
                          ),
                          backgroundColor: Colors.blueGrey,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                  break;
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      Log.e('Failed to check and update blend-subtitles for track', e);
    }
  }

  void _applySubtitleProperty(String name, String value) {
    try {
      if (widget.player.platform is NativePlayer) {
        final nativePlayer = widget.player.platform as NativePlayer;
        nativePlayer.setProperty(name, value);
        Log.i('Applied subtitle property dynamically: $name = $value');
      }
    } catch (e) {
      Log.e('Failed to apply subtitle property $name', e);
    }
  }

  String _getDecoderModeLabel() {
    final mode = ref.read(storageServiceProvider).getHardwareDecoderMode();
    if (mode == 'no') {
      return 'SW';
    } else if (mode == 'd3d11va') {
      return 'HW';
    } else if (mode == 'd3d11va-copy') {
      return 'HW+';
    } else if (mode == 'mediacodec') {
      return 'HW';
    } else if (mode == 'mediacodec-copy') {
      return 'HW+';
    }
    return 'HW';
  }

  void _toggleDecoderMode() async {
    final storage = ref.read(storageServiceProvider);
    final currentMode = storage.getHardwareDecoderMode();
    String nextMode;
    String toastText;

    if (Platform.isWindows) {
      if (currentMode == 'd3d11va-copy') {
        nextMode = 'd3d11va';
        toastText = 'Hardware Decoder: HW (d3d11va Direct)';
      } else if (currentMode == 'd3d11va') {
        nextMode = 'no';
        toastText = 'Hardware Decoder: SW (Software)';
      } else {
        nextMode = 'd3d11va-copy';
        toastText = 'Hardware Decoder: HW+ (d3d11va Copy-back)';
      }
    } else {
      if (currentMode == 'mediacodec') {
        nextMode = 'mediacodec-copy';
        toastText = 'Hardware Decoder: HW+ (Compatible)';
      } else if (currentMode == 'mediacodec-copy') {
        nextMode = 'no';
        toastText = 'Hardware Decoder: SW (Software)';
      } else {
        nextMode = 'mediacodec';
        toastText = 'Hardware Decoder: HW (Direct)';
      }
    }

    await storage.setHardwareDecoderMode(nextMode);

    try {
      if (widget.player.platform is NativePlayer) {
        final nativePlayer = widget.player.platform as NativePlayer;
        nativePlayer.setProperty('hwdec', nextMode);
      }
    } catch (e) {
      Log.w('Failed to apply hwdec change dynamically: $e');
    }

    _showSkipToast(toastText);
    setState(() {});
  }
}






