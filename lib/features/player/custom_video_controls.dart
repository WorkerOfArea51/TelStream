import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../settings/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../services/subtitle_downloader_service.dart';
import '../../services/skip_times_service.dart';
import '../../core/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/permission_service.dart';
import 'pip_manager.dart';
import '../../services/download_service.dart';

class CustomVideoControls extends ConsumerStatefulWidget {
  final Player player;
  final VideoController controller;
  final String videoTitle;
  final bool isPip;
  final int downloadedPrefixSize;
  final int expectedSize;
  final VoidCallback onBack;
  final bool hasPrevEpisode;
  final bool hasNextEpisode;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onAutoNextCancelled;
  final ValueChanged<Duration>? onSeek;
  final bool customBuffering;
  final String seriesName;
  final int currentEpisodeIndex;

  const CustomVideoControls({
    super.key,
    required this.player,
    required this.controller,
    required this.videoTitle,
    required this.isPip,
    required this.downloadedPrefixSize,
    required this.expectedSize,
    required this.onBack,
    this.hasPrevEpisode = false,
    this.hasNextEpisode = false,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.onAutoNextCancelled,
    this.onSeek,
    this.customBuffering = false,
    this.seriesName = '',
    this.currentEpisodeIndex = 0,
  });

  @override
  ConsumerState<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends ConsumerState<CustomVideoControls> {
  bool _showControls = true;
  Timer? _hideTimer;
  
  bool _isLocked = false;
  bool _isFullscreen = true;
  double _currentSpeed = 1.0;
  BoxFit _fit = BoxFit.contain;
  String _currentAspectRatioString = 'fit';
  double? _customAspectRatio;
  bool _rememberRatio = false;
  bool _tapToSwitchRatio = false;
  bool _showRatioPanel = false;
  
  StreamSubscription<bool>? _bufferingSubscription;
  bool _isBuffering = false;
  bool _isBlendingSubtitles = false;
  StreamSubscription<Track>? _trackSubscription;
  StreamSubscription? _tracksListSubscription;
  
  bool _showTrackSelectorPanel = false;
  String _trackSelectorTitle = '';
  bool _trackSelectorIsSubtitle = false;
  
  // Gestures
  double _currentVolume = 100.0;
  double _currentBrightness = 1.0;
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  bool _showSeekIndicator = false;
  String _seekDirection = '';
  bool _isPhysicalBrightnessSupported = false;
  Timer? _brightnessSaveTimer;
  bool _audioBoostActive = false;
  bool _nightModeActive = false;
  bool _showSpeedIndicator = false;

  // Double tap seek variables
  bool _showLeftSeekOverlay = false;
  bool _showRightSeekOverlay = false;
  double _doubleTapSeekOpacity = 0.0;
  int _doubleTapSeekAccumulated = 0;
  Timer? _doubleTapOverlayTimer;
  Timer? _doubleTapSeekTimer;
  Duration? _doubleTapStartPosition;

  // Auto next episode countdown
  bool _showAutoNextCountdown = false;
  int _autoNextSecondsRemaining = 15;
  Timer? _autoNextTimer;
  bool _autoNextCancelled = false;
  StreamSubscription<Duration>? _positionSubscription;
  bool _autoNextTriggered = false;

  // Skip Times variables
  StreamSubscription? _durationSubscription;
  List<SkipInterval> _apiSkipIntervals = [];
  // List<SkipInterval> _chapterSkipIntervals = [];
  // List<SkipInterval> _skipIntervals = [];
  bool _skipTimesLoaded = false;
  bool _isLoadingSkipTimes = false;
  // bool _introSkipped = false;
  // bool _outroSkipped = false;
  // bool _showIntroOverlay = false;
  // bool _showOutroOverlay = false;
  // bool _isSkipButtonExpanded = true;
  // Timer? _skipButtonCollapseTimer;
  // SkipInterval? _currentActiveOP;
  // SkipInterval? _currentActiveED;
  bool _toastShowing = false;
  String _toastMessage = '';
  Timer? _toastTimer;

  bool _isMuted = false;
  double _preMuteVolume = 100.0;
  Duration? _abRepeatA;
  Duration? _abRepeatB;
  bool _quickActionsExpanded = false;
  bool _autoNextSlideIn = false;
  Timer? _autoNextSlideInTimer;

  // Sleep timer variables
  Timer? _sleepTimer;
  int? _sleepTimerMinutes;
  int? _sleepTimerSecondsRemaining;
  Timer? _osdTimer;

  // Chapter variables
  List<VideoChapter> _chapters = [];
  bool _hasChapters = false;
  bool _showChaptersPanel = false;
  StreamSubscription? _playlistSubscription;
  int _chaptersLoadAttempts = 0;
  Timer? _chaptersRetryTimer;

  // Pinch to zoom
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _basePanOffset = Offset.zero;

  // Swipe to seek variables
  bool _isSwipingToSeek = false;
  Duration _swipeTargetPosition = Duration.zero;
  Duration _swipeStartPosition = Duration.zero;

  // Gesture detection flags
  bool _isScaleGesture = false;
  bool _isVerticalDrag = false;
  bool _isHorizontalDrag = false;
  Offset? _dragStartFocalPoint;
  DateTime? _lastSeekWarningTime;
  StreamSubscription<double>? _volumeSubscription;
  DateTime? _lastDragSeekTime;

  bool _isPositionDownloaded(Duration position) {
    if (widget.expectedSize <= 0) return true;
    final totalDuration = widget.player.state.duration;
    if (totalDuration.inMilliseconds <= 0) return false;
    
    final isDownloadedCompleted = widget.downloadedPrefixSize >= widget.expectedSize;
    if (isDownloadedCompleted) return true;
    
    final fraction = position.inSeconds / totalDuration.inSeconds;
    final byteOffset = fraction * widget.expectedSize;
    return byteOffset < widget.downloadedPrefixSize;
  }

  void _throttledSeek(Duration target) {
    final now = DateTime.now();
    if (_lastDragSeekTime == null || now.difference(_lastDragSeekTime!).inMilliseconds > 150) {
      _lastDragSeekTime = now;
      _performSeek(target);
    }
  }

  void _loadSkipTimes(double duration) async {
    if (_skipTimesLoaded || _isLoadingSkipTimes || duration <= 0) return;
    _isLoadingSkipTimes = true;
    try {
      final skipTimesService = ref.read(skipTimesServiceProvider);
      final intervals = await skipTimesService.fetchSkipTimes(
        seriesName: widget.seriesName,
        episodeNumber: widget.currentEpisodeIndex + 1,
        totalDuration: duration,
        videoTitle: widget.videoTitle,
      );
      if (mounted) {
        setState(() {
          _apiSkipIntervals = intervals;
          _skipTimesLoaded = true;
        });
        Log.i('Loaded ${_apiSkipIntervals.length} skip intervals for ${widget.seriesName}');
        _refreshSkipIntervals();
      }
    } catch (e, stack) {
      Log.e('Error loading skip times', e, stack);
    } finally {
      _isLoadingSkipTimes = false;
    }
  }

  bool _isChapterIntro(VideoChapter ch, double start, double end) {
    final titleLower = ch.title.toLowerCase().trim();
    return titleLower.contains('intro') ||
        titleLower.contains('opening') ||
        titleLower.contains('theme') ||
        titleLower.contains('title sequence') ||
        titleLower.contains('main title') ||
        titleLower.contains('title screen') ||
        titleLower.contains('opening credits') ||
        titleLower == 'op' ||
        titleLower.startsWith('op ') ||
        titleLower.endsWith(' op') ||
        titleLower.contains('op 1') ||
        titleLower.contains('op 2') ||
        titleLower.contains('op1') ||
        titleLower.contains('op2');
  }

  bool _isChapterOutro(VideoChapter ch, double start, double end, double totalDuration) {
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

  List<SkipInterval> _extractSkipTimesFromChapters() {
    final List<SkipInterval> intervals = [];
    if (_chapters.isEmpty) return intervals;
    
    final totalDuration = widget.player.state.duration.inSeconds.toDouble();
    
    for (int i = 0; i < _chapters.length; i++) {
      final ch = _chapters[i];
      final start = ch.position.inSeconds.toDouble();
      final end = (i + 1 < _chapters.length)
          ? _chapters[i + 1].position.inSeconds.toDouble()
          : (totalDuration > 0 ? totalDuration : start + 90.0);
          
      final isOp = _isChapterIntro(ch, start, end);
      final isEd = _isChapterOutro(ch, start, end, totalDuration);
      
      if (isOp || isEd) {
        intervals.add(SkipInterval(
          startTime: start,
          endTime: end,
          type: isOp ? 'op' : 'ed',
        ));
      }
    }
    return intervals;
  }

  void _refreshSkipIntervals() {
    final duration = widget.player.state.duration.inSeconds.toDouble();
    if (duration <= 0) return;

    final chapterIntervals = _extractSkipTimesFromChapters();
    
    // Heuristics
    final isAnime = duration >= 1080 && duration <= 1680;
    final List<SkipInterval> heuristics = [];

    // Combine API and Chapter intervals first to check if they have OP/ED
    final List<SkipInterval> currentMerged = [..._apiSkipIntervals, ...chapterIntervals];
    final hasOP = currentMerged.any((interval) => interval.type == 'op');
    final hasED = currentMerged.any((interval) => interval.type == 'ed');

    if (isAnime) {
      if (!hasOP) {
        heuristics.add(const SkipInterval(
          startTime: 10.0,
          endTime: 240.0, // Show for the first 4 minutes
          type: 'op_heuristic',
        ));
      }
      if (!hasED) {
        heuristics.add(SkipInterval(
          startTime: duration - 180.0,
          endTime: duration - 30.0,
          type: 'ed_heuristic',
        ));
      }
    }

    if (mounted) {
      setState(() {
        // _chapterSkipIntervals = chapterIntervals;
        // _skipIntervals = [..._apiSkipIntervals, ..._chapterSkipIntervals, ...heuristics];
      });
    }
  }

  // void _triggerSkipButtonCollapseTimer() {
  //   _skipButtonCollapseTimer?.cancel();
  //   setState(() {
  //     _isSkipButtonExpanded = true;
  //   });
  //   _skipButtonCollapseTimer = Timer(const Duration(seconds: 2), () {
  //     if (mounted) {
  //       setState(() {
  //         _isSkipButtonExpanded = false;
  //       });
  //     }
  //   });
  // }
  // 
  // void _checkSkipTimes(Duration pos) {
  //   if (_skipIntervals.isEmpty) return;
  //   
  //   final settings = ref.read(videoSettingsProvider);
  //   final currentSecs = pos.inSeconds.toDouble();
  // 
  //   // Check if we are inside any OP or ED interval
  //   SkipInterval? activeOP;
  //   SkipInterval? activeED;
  // 
  //   for (final interval in _skipIntervals) {
  //     if (currentSecs >= interval.startTime && currentSecs < interval.endTime) {
  //       if (interval.type == 'op' || interval.type == 'op_heuristic') {
  //         activeOP = interval;
  //       } else if (interval.type == 'ed' || interval.type == 'ed_heuristic') {
  //         activeED = interval;
  //       }
  //     }
  //   }
  // 
  //   // Handle Intro (OP)
  //   if (activeOP != null) {
  //     _currentActiveOP = activeOP;
  //     final isHeuristic = activeOP.type == 'op_heuristic';
  //     if (settings.autoSkipIntroOutro && !isHeuristic) {
  //       if (!_introSkipped) {
  //         _introSkipped = true;
  //         final target = Duration(seconds: activeOP.endTime.toInt());
  //         final safeTarget = _clampSeekTarget(target, showMessage: false);
  //         _performSeek(safeTarget);
  //         _showSkipToast('Auto-skipped Intro');
  //       }
  //     } else {
  //       if (!_showIntroOverlay) {
  //         _triggerSkipButtonCollapseTimer();
  //         setState(() {
  //           _showIntroOverlay = true;
  //         });
  //       }
  //     }
  //   } else {
  //     _currentActiveOP = null;
  //     _introSkipped = false;
  //     if (_showIntroOverlay) {
  //       setState(() {
  //         _showIntroOverlay = false;
  //         _isSkipButtonExpanded = true;
  //         _skipButtonCollapseTimer?.cancel();
  //       });
  //     }
  //   }
  // 
  //   // Handle Outro (ED)
  //   if (activeED != null) {
  //     _currentActiveED = activeED;
  //     final isHeuristic = activeED.type == 'ed_heuristic';
  //     if (settings.autoSkipIntroOutro && !isHeuristic) {
  //       if (!_outroSkipped) {
  //         _outroSkipped = true;
  //         if (widget.hasNextEpisode && widget.onNextEpisode != null) {
  //           widget.onNextEpisode!();
  //           _showSkipToast('Auto-playing Next Episode');
  //         } else {
  //           final target = Duration(seconds: activeED.endTime.toInt());
  //           final safeTarget = _clampSeekTarget(target, showMessage: false);
  //           _performSeek(safeTarget);
  //           _showSkipToast('Auto-skipped Outro');
  //         }
  //       }
  //     } else {
  //       if (!_showOutroOverlay) {
  //         _triggerSkipButtonCollapseTimer();
  //         setState(() {
  //           _showOutroOverlay = true;
  //         });
  //       }
  //     }
  //   } else {
  //     _currentActiveED = null;
  //     _outroSkipped = false;
  //     if (_showOutroOverlay) {
  //       setState(() {
  //         _showOutroOverlay = false;
  //         _isSkipButtonExpanded = true;
  //         _skipButtonCollapseTimer?.cancel();
  //       });
  //     }
  //   }
  // }

  void _showSkipToast(String msg) {
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
    final currentPos = widget.player.state.position;
    setState(() {
      if (_abRepeatA == null) {
        _abRepeatA = currentPos;
        _showSkipToast('A-B Repeat: Point A set');
      } else if (_abRepeatB == null) {
        if (currentPos <= _abRepeatA!) {
          _showSkipToast('Point B must be after Point A');
          return;
        }
        _abRepeatB = currentPos;
        _showSkipToast('A-B Repeat: Repeating loop');
        _performSeek(_abRepeatA!);
      } else {
        _abRepeatA = null;
        _abRepeatB = null;
        _showSkipToast('A-B Repeat: Cleared');
      }
    });
  }

  void _toggleMute() {
    setState(() {
      if (_isMuted) {
        _isMuted = false;
        _currentVolume = _preMuteVolume;
        FlutterVolumeController.setVolume(_currentVolume / 100.0);
        _showSkipToast('Volume restored');
      } else {
        _isMuted = true;
        _preMuteVolume = _currentVolume;
        _currentVolume = 0.0;
        FlutterVolumeController.setVolume(0.0);
        _showSkipToast('Volume muted');
      }
    });
  }

  Future<void> _takeScreenshot() async {
    try {
      final hasPermission = await ref.read(permissionServiceProvider).requestStoragePermission();
      if (!hasPermission) {
        _showSkipToast('Storage permission denied');
        return;
      }

      final Uint8List? screenshotBytes = await widget.player.screenshot(format: 'image/png');
      if (screenshotBytes == null || screenshotBytes.isEmpty) {
        _showSkipToast('Failed to capture screenshot');
        return;
      }

      final storage = ref.read(storageServiceProvider);
      final customPath = storage.getCustomDownloadDirectory();
      Directory? baseDir;

      if (customPath != null && customPath.isNotEmpty) {
        baseDir = Directory('$customPath/Screenshots');
      } else if (Platform.isAndroid) {
        final telstreamRoot = Directory('/storage/emulated/0/TelStream/Screenshots');
        final downloadDir = Directory('/storage/emulated/0/Download/TelStream/Screenshots');
        final picturesDir = Directory('/storage/emulated/0/Pictures/TelStream/Screenshots');

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

      final cleanTitle = widget.videoTitle.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${baseDir.path}/Screenshot_${cleanTitle}_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(screenshotBytes);

      String displayPath = baseDir.path;
      if (displayPath.startsWith('/storage/emulated/0/')) {
        displayPath = displayPath.replaceFirst('/storage/emulated/0/', '');
      }
      _showSkipToast('Screenshot saved to $displayPath');
    } catch (e, stack) {
      Log.e('Failed to take screenshot', e, stack);
      _showSkipToast('Error saving screenshot: $e');
    }
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive ? Colors.white24 : Colors.black38,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: IconButton(
              iconSize: 20,
              padding: EdgeInsets.zero,
              icon: Icon(icon, color: Colors.white),
              onPressed: onTap,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow() {
    final List<Widget> items = [
      _buildCircularActionButton(
        icon: _isMuted ? Icons.volume_off : Icons.volume_up,
        label: 'Mute',
        isActive: _isMuted,
        onTap: _toggleMute,
      ),
      _buildCircularActionButton(
        icon: Icons.screen_rotation,
        label: 'Rotate',
        isActive: !_isFullscreen,
        onTap: _toggleFullscreen,
      ),
      if (_hasChapters)
        _buildCircularActionButton(
          icon: Icons.format_list_bulleted,
          label: 'Chapters',
          isActive: _showChaptersPanel,
          onTap: _openChaptersPanel,
        ),
      _buildCircularActionButton(
        icon: Icons.repeat,
        label: 'A-B Repeat',
        isActive: _abRepeatA != null,
        onTap: _toggleAbRepeat,
      ),
      _buildCircularActionButton(
        icon: _sleepTimerSecondsRemaining != null ? Icons.snooze : Icons.snooze_outlined,
        label: 'Sleep Timer',
        isActive: _sleepTimerSecondsRemaining != null,
        onTap: _showSleepTimerSelector,
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
          child: Row(
            children: items,
          ),
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
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: remaining,
                    )
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
                        _quickActionsExpanded ? Icons.arrow_back : Icons.arrow_forward,
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
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildCheckboxToggle({
  //   required String label,
  //   required bool value,
  //   required ValueChanged<bool?> onChanged,
  //   required Color settingsAccent,
  // }) {
  //   return GestureDetector(
  //     onTap: () => onChanged(!value),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         SizedBox(
  //           width: 20,
  //           height: 20,
  //           child: Checkbox(
  //             value: value,
  //             onChanged: onChanged,
  //             activeColor: settingsAccent,
  //             checkColor: settingsAccent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
  //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  //             side: const BorderSide(color: Colors.white30, width: 1.5),
  //           ),
  //         ),
  //         const SizedBox(width: 8),
  //         Text(
  //           label,
  //           style: const TextStyle(
  //             color: Colors.white70,
  //             fontSize: 12,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _currentVolume = widget.player.state.volume;
    _initSystemVolumeAndBrightness();
    _initAspectRatio();
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
    });
    _durationSubscription = widget.player.stream.duration.listen((dur) {
      if (dur.inSeconds > 0) {
        _loadSkipTimes(dur.inSeconds.toDouble());
        _loadChapters();
        _refreshSkipIntervals();
      }
    });
    _trackSubscription = widget.player.stream.track.listen((track) {
      _updateBlendSubtitlesForTrack(widget.player, track.subtitle);
    });
    _tracksListSubscription = widget.player.stream.tracks.listen((_) {
      _updateBlendSubtitlesForTrack(widget.player, widget.player.state.track.subtitle);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBlendSubtitlesForTrack(widget.player, widget.player.state.track.subtitle);
    });
    _playlistSubscription = widget.player.stream.playlist.listen((_) {
      if (mounted) {
        setState(() {
          _chapters = [];
          _hasChapters = false;
          _apiSkipIntervals = [];
          // _chapterSkipIntervals = [];
          // _skipIntervals = [];
          _skipTimesLoaded = false;
          // _introSkipped = false;
          // _outroSkipped = false;
          // _showIntroOverlay = false;
          // _showOutroOverlay = false;
          // _isSkipButtonExpanded = true;
          // _skipButtonCollapseTimer?.cancel();
          _chaptersLoadAttempts = 0;
        });
      }
      Future.delayed(const Duration(milliseconds: 500), _loadChapters);
    });
    Future.delayed(const Duration(milliseconds: 500), _loadChapters);
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
        if (mounted && !_showVolumeIndicator) {
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
      await ScreenBrightness().setApplicationScreenBrightness(_currentBrightness);
      _isPhysicalBrightnessSupported = true;
    } catch (_) {
      _isPhysicalBrightnessSupported = false;
    }
  }

  void _checkAutoNextTrigger(Duration pos) {
    if (widget.isPip || _autoNextCancelled || !widget.hasNextEpisode || widget.onNextEpisode == null) return;
    
    final dur = widget.player.state.duration;
    if (dur.inSeconds <= 0) return;

    final remaining = dur.inSeconds - pos.inSeconds;
    
    final bool isOutro = _isCurrentPositionInOutro(pos);
    final outroThreshold = ref.read(storageServiceProvider).getVideoSettings()['outro_threshold_seconds'] as int? ?? 45;
    final bool shouldTrigger = isOutro || (remaining <= outroThreshold && remaining > 0);

    if (shouldTrigger && !_autoNextTriggered) {
      _autoNextTriggered = true;
      _startAutoNextCountdown();
    } else if (!shouldTrigger && _autoNextTriggered) {
      _cancelAutoNextCountdown();
      _autoNextTriggered = false;
    }
  }

  void _startAutoNextCountdown() {
    _autoNextTimer?.cancel();
    _autoNextSlideInTimer?.cancel();
    setState(() {
      _showAutoNextCountdown = true;
      _autoNextSecondsRemaining = 15;
      _autoNextSlideIn = false;
    });
    
    _autoNextSlideInTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _autoNextSlideIn = true;
        });
      }
    });
    
    _autoNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_autoNextSecondsRemaining > 1) {
            _autoNextSecondsRemaining--;
          } else {
            _autoNextTimer?.cancel();
            _autoNextSlideInTimer?.cancel();
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
      }
    });
  }

  void _cancelAutoNextCountdown() {
    _autoNextTimer?.cancel();
    _autoNextSlideInTimer?.cancel();
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
    if (widget.onAutoNextCancelled != null) {
      widget.onAutoNextCancelled!();
    }
  }

  @override
  void dispose() {
    _autoNextSlideInTimer?.cancel();
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
    _autoNextTimer?.cancel();
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

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) _startHideTimer();
  }

  void _toggleFullscreen() {
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

  void _toggleSpeed() {
    setState(() {
      if (_currentSpeed == 1.0) {
        _currentSpeed = 1.25;
      } else if (_currentSpeed == 1.25) {
        _currentSpeed = 1.5;
      } else {
        _currentSpeed = 1.0;
      }
    });
    widget.player.setRate(_currentSpeed);
  }

  void _handleDoubleTap(TapDownDetails details, double screenWidth, int seekDuration) {
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
      if ((isLeft && _showRightSeekOverlay) || (!isLeft && _showLeftSeekOverlay)) {
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
        ? _doubleTapStartPosition! - Duration(seconds: _doubleTapSeekAccumulated)
        : _doubleTapStartPosition! + Duration(seconds: _doubleTapSeekAccumulated);

    final dur = widget.player.state.duration;
    final clampedTarget = Duration(
        seconds: target.inSeconds.clamp(0, dur.inSeconds > 0 ? dur.inSeconds : 86400));

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

  void _saveBrightnessDebounced(double value) {
    _brightnessSaveTimer?.cancel();
    _brightnessSaveTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(storageServiceProvider).setBrightness(value);
    });
  }

  void _showOSD(String text) {
    _osdTimer?.cancel();
    setState(() {
      _showSeekIndicator = true;
      _seekDirection = text;
    });
    _osdTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSeekIndicator = false;
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
        if (_sleepTimerSecondsRemaining != null && _sleepTimerSecondsRemaining! > 1) {
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
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xE60F172A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.snooze, color: settingsAccent, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Sleep Timer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select when the video should stop playing and close.',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        if (_sleepTimerSecondsRemaining != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: settingsAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: settingsAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Active Timer: ${_formatSleepTimeRemaining(_sleepTimerSecondsRemaining!)}',
                                  style: TextStyle(
                                    color: settingsAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _cancelSleepTimer();
                                    setDialogState(() {});
                                    setState(() {});
                                    _showOSD('Sleep Timer cancelled');
                                    Navigator.of(context).pop();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Cancel Timer',
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [15, 30, 45, 60].map((mins) {
                            final isSelected = _sleepTimerMinutes == mins;
                            return InkWell(
                              onTap: () {
                                _startSleepTimer(mins);
                                Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 100,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? settingsAccent : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? settingsAccent : Colors.white10,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$mins',
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Mins',
                                      style: TextStyle(
                                        color: isSelected ? Colors.black87 : Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              _startSleepTimerSeconds(10);
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Test with 10s',
                              style: TextStyle(color: settingsAccent.withValues(alpha: 0.6), fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
          for (int i = 0; i < count; i++) {
            final title = await platform.getProperty('chapter-list/$i/title') ?? 'Chapter ${i + 1}';
            final timeStr = await platform.getProperty('chapter-list/$i/time');
            final timeDouble = double.tryParse(timeStr ?? '');
            if (timeDouble != null) {
              loadedChapters.add(VideoChapter(
                title: title,
                position: Duration(milliseconds: (timeDouble * 1000).round()),
              ));
            }
          }
          if (mounted) {
            setState(() {
              _chapters = loadedChapters;
              _hasChapters = loadedChapters.isNotEmpty;
              _chaptersLoadAttempts = 0;
            });
            _refreshSkipIntervals();
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted && _chaptersLoadAttempts < 5) {
      _chaptersLoadAttempts++;
      _chaptersRetryTimer = Timer(const Duration(milliseconds: 500), _loadChapters);
    } else {
      if (mounted) {
        setState(() {
          _chapters = [];
          _hasChapters = false;
        });
      }
    }
  }


  int _getActiveChapterIndex(Duration currentPos) {
    if (_chapters.isEmpty) return -1;
    for (int i = 0; i < _chapters.length; i++) {
      final start = _chapters[i].position;
      final end = (i + 1 < _chapters.length) 
          ? _chapters[i + 1].position 
          : widget.player.state.duration;
      if (currentPos >= start && currentPos < end) {
        return i;
      }
    }
    return 0;
  }

  void _openChaptersPanel() {
    setState(() {
      _showChaptersPanel = true;
      _showControls = false;
    });
  }

  Widget _buildCustomChaptersPanel() {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      initialData: widget.player.state.position,
      builder: (context, snapshot) {
        final currentPos = snapshot.data ?? widget.player.state.position;
        final activeIndex = _getActiveChapterIndex(currentPos);

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              height: 340,
              decoration: BoxDecoration(
                color: const Color(0xE60F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 25,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 45,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.list,
                            color: settingsAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Chapters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => setState(() => _showChaptersPanel = false),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(color: Colors.white12, height: 1),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _chapters.isEmpty
                          ? const Center(
                              child: Text(
                                'No chapters available',
                                style: TextStyle(color: Colors.white38, fontSize: 15),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: _chapters.length,
                              itemBuilder: (context, index) {
                                final chapter = _chapters[index];
                                final isSelected = index == activeIndex;
                                
                                final start = chapter.position.inSeconds.toDouble();
                                final totalDuration = widget.player.state.duration.inSeconds.toDouble();
                                final end = (index + 1 < _chapters.length)
                                    ? _chapters[index + 1].position.inSeconds.toDouble()
                                    : (totalDuration > 0 ? totalDuration : start + 90.0);
                                    
                                String displayTitle = chapter.title;
                                if (_isChapterIntro(chapter, start, end)) {
                                  displayTitle = 'Intro';
                                } else if (_isChapterOutro(chapter, start, end, totalDuration)) {
                                  displayTitle = 'Credits';
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () {
                                      final safeTarget = _clampSeekTarget(chapter.position, showMessage: false);
                                      _performSeek(safeTarget);
                                      setState(() {
                                        _showChaptersPanel = false;
                                        _showSeekIndicator = true;
                                        _seekDirection = 'Chapter: $displayTitle';
                                      });
                                      Future.delayed(const Duration(milliseconds: 1000), () {
                                        if (mounted) {
                                          setState(() => _showSeekIndicator = false);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? settingsAccent.withValues(alpha: 0.12) 
                                            : Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected 
                                              ? settingsAccent.withValues(alpha: 0.4) 
                                              : Colors.white.withValues(alpha: 0.05),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isSelected ? settingsAccent.withValues(alpha: 0.2) : Colors.white10,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _formatDuration(chapter.position),
                                              style: TextStyle(
                                                color: isSelected ? settingsAccent : Colors.white70,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              displayTitle,
                                              style: TextStyle(
                                                color: isSelected ? settingsAccent : Colors.white,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(
                                              Icons.play_circle_filled,
                                              color: settingsAccent,
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Duration _clampSeekTarget(Duration targetPosition, {bool showMessage = true}) {
    if (widget.onSeek != null) return targetPosition;
    if (widget.expectedSize <= 0) return targetPosition;
    final totalDuration = widget.player.state.duration;
    if (totalDuration.inMilliseconds <= 0) return targetPosition;

    final isDownloadedCompleted = widget.downloadedPrefixSize >= widget.expectedSize;
    if (isDownloadedCompleted) return targetPosition;

    final double fraction = widget.downloadedPrefixSize / widget.expectedSize;
    final maxPlayableMs = (totalDuration.inMilliseconds * fraction).round();

    if (targetPosition.inMilliseconds > maxPlayableMs) {
      if (showMessage) {
        final now = DateTime.now();
        if (_lastSeekWarningTime == null || now.difference(_lastSeekWarningTime!).inSeconds > 2) {
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

  void _handleScaleStart(ScaleStartDetails details) {
    if (_isLocked) return;
    _dragStartFocalPoint = details.focalPoint;
    _isScaleGesture = false;
    _isVerticalDrag = false;
    _isHorizontalDrag = false;
    
    _baseScale = _scale;
    _basePanOffset = _panOffset;
    
    _swipeStartPosition = widget.player.state.position;
    _swipeTargetPosition = _swipeStartPosition;
    
    _hideTimer?.cancel();
  }

  void _handleScaleUpdate(
    ScaleUpdateDetails details,
    double screenWidth,
    bool pinchToZoom,
    bool volGestures,
    bool brightGestures,
    bool swipeSeek,
  ) {
    if (_isLocked) return;

    // 1. Pinch to zoom (multi-touch)
    if (details.pointerCount > 1) {
      if (pinchToZoom) {
        _isScaleGesture = true;
        setState(() {
          _scale = (_baseScale * details.scale).clamp(1.0, 4.0);
          if (_scale == 1.0) _panOffset = Offset.zero;
        });
      }
      return;
    }

    if (_isScaleGesture) return;

    // 2. Determine drag type
    if (_dragStartFocalPoint != null && !_isVerticalDrag && !_isHorizontalDrag) {
      final double deltaX = (details.focalPoint.dx - _dragStartFocalPoint!.dx).abs();
      final double deltaY = (details.focalPoint.dy - _dragStartFocalPoint!.dy).abs();
      
      if (deltaX > 10 || deltaY > 10) {
        if (deltaX > deltaY) {
          if (swipeSeek) {
            _isHorizontalDrag = true;
            _isSwipingToSeek = true;
          }
        } else {
          _isVerticalDrag = true;
        }
      }
      return;
    }

    // 3. Perform actions
    if (_isHorizontalDrag && _isSwipingToSeek) {
      final duration = widget.player.state.duration;
      if (duration.inSeconds == 0) return;

      final double totalDeltaX = details.focalPoint.dx - _dragStartFocalPoint!.dx;
      final secondsOffset = ((totalDeltaX / (screenWidth / 2)) * 60).toInt();
      
      setState(() {
        final newSeconds = (_swipeStartPosition.inSeconds + secondsOffset)
            .clamp(0, duration.inSeconds);
        _swipeTargetPosition = Duration(seconds: newSeconds);
        _showSeekIndicator = true;
        
        final diff = _swipeTargetPosition.inSeconds - _swipeStartPosition.inSeconds;
        final sign = diff >= 0 ? '+' : '';
        _seekDirection = 'Swipe: ${_formatDuration(_swipeTargetPosition)} ($sign${diff}s)';
      });
    } else if (_isVerticalDrag && _scale <= 1.0) {
      final double deltaY = details.focalPointDelta.dy;
      final settings = ref.read(videoSettingsProvider);
      final isLeft = _dragStartFocalPoint!.dx <= screenWidth / 2;
      final action = isLeft ? settings.leftSwipeGesture : settings.rightSwipeGesture;
      
      if (action == 'Volume' && volGestures) {
        _performVerticalSwipeAction('Volume', deltaY);
      } else if (action == 'Brightness' && brightGestures) {
        _performVerticalSwipeAction('Brightness', deltaY);
      } else if (action == 'Speed') {
        _performVerticalSwipeAction('Speed', deltaY);
      }
    } else if (_scale > 1.0) {
      setState(() {
        _panOffset = _basePanOffset + (details.focalPoint - _dragStartFocalPoint!);
      });
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isSwipingToSeek) {
      setState(() {
        _isSwipingToSeek = false;
        _showSeekIndicator = false;
      });
      final safeTarget = _clampSeekTarget(_swipeTargetPosition, showMessage: true);
      _performSeek(safeTarget);
    }
    if (_showSpeedIndicator) {
      widget.player.seek(widget.player.state.position);
    }
    setState(() {
      _showVolumeIndicator = false;
      _showBrightnessIndicator = false;
      _showSpeedIndicator = false;
    });
    _dragStartFocalPoint = null;
    _isScaleGesture = false;
    _isVerticalDrag = false;
    _isHorizontalDrag = false;
    _startHideTimer();
  }

  void _performVerticalSwipeAction(String actionType, double deltaY) {
    if (actionType == 'Volume') {
      final bool volumeBoost = ref.read(storageServiceProvider).getVolumeBoostEnabled();
      final maxVol = volumeBoost ? 200.0 : 100.0;
      setState(() {
        _currentVolume -= deltaY * 0.2;
        _currentVolume = _currentVolume.clamp(0.0, maxVol);
        try {
          FlutterVolumeController.setVolume((_currentVolume / 100.0).clamp(0.0, 1.0));
        } catch (_) {}
        widget.player.setVolume(_currentVolume);
        _showVolumeIndicator = true;
      });
    } else if (actionType == 'Brightness') {
      setState(() {
        _currentBrightness -= deltaY / 300;
        _currentBrightness = _currentBrightness.clamp(0.0, 1.0);
        try {
          ScreenBrightness().setApplicationScreenBrightness(_currentBrightness);
          _isPhysicalBrightnessSupported = true;
        } catch (_) {
          _isPhysicalBrightnessSupported = false;
        }
        _showBrightnessIndicator = true;
      });
      _saveBrightnessDebounced(_currentBrightness);
    } else if (actionType == 'Speed') {
      setState(() {
        _currentSpeed -= deltaY * 0.005;
        _currentSpeed = _currentSpeed.clamp(0.25, 4.0);
        _currentSpeed = double.parse(_currentSpeed.toStringAsFixed(2));
        widget.player.setRate(_currentSpeed);
        _showSpeedIndicator = true;
      });
    }
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
          filters.add('lavfi=[acompressor]');
        }
        
        if (filters.isNotEmpty) {
          nativePlayer.setProperty('af', filters.join(','));
          Log.i('Applied audio filters: ${filters.join(',')}');
        } else {
          nativePlayer.setProperty('af', '');
          Log.i('Cleared all audio filters');
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
      setState(() {
        _currentAspectRatioString = ratioString;
        _customAspectRatio = customRatio;
        _fit = boxFit;
        _scale = 1.0;
        _panOffset = Offset.zero;
      });
    }

    if (save && _rememberRatio) {
      ref.read(storageServiceProvider).setSavedAspectRatio(ratioString);
    }
  }

  String _getRatioLabel(String value) {
    switch (value) {
      case 'fit': return 'Fit';
      case 'fill': return 'Fill';
      case 'original': return 'Original';
      case 'stretch': return 'Stretch';
      default: return value;
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
    const cycle = ['fit', 'fill', 'stretch', '16:9', '21:9'];
    int currentIndex = cycle.indexOf(_currentAspectRatioString);
    if (currentIndex == -1) {
      currentIndex = 0;
    } else {
      currentIndex = (currentIndex + 1) % cycle.length;
    }
    final nextRatio = cycle[currentIndex];
    _applyAspectRatioString(nextRatio);

    setState(() {
      _showSeekIndicator = true;
      _seekDirection = 'Aspect Ratio: ${_getRatioLabel(nextRatio)}';
    });
    _hideTimer?.cancel();
    _startHideTimer();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _showSeekIndicator = false);
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

  Widget _buildScreenRatioButton(String ratioId, IconData icon, String label) {
    final isSelected = _currentAspectRatioString == ratioId;
    return GestureDetector(
      onTap: () => _applyAspectRatioString(ratioId),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.green : Colors.white10,
              border: Border.all(color: isSelected ? Colors.green : Colors.transparent, width: 2),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.green : Colors.white70,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillRatioButton(String ratioId) {
    final isSelected = _currentAspectRatioString == ratioId;
    return GestureDetector(
      onTap: () => _applyAspectRatioString(ratioId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? Colors.green : Colors.white10,
          border: Border.all(color: isSelected ? Colors.green : Colors.white24, width: 1),
        ),
        child: Text(
          ratioId,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _buildRatioPanel() {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _closeAspectRatioPanel,
              ),
              const Text(
                'Ratio',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Screen', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScreenRatioButton('fit', Icons.fit_screen, 'Fit'),
                      _buildScreenRatioButton('fill', Icons.fullscreen, 'Fill'),
                      _buildScreenRatioButton('original', Icons.center_focus_strong, 'Original'),
                      _buildScreenRatioButton('stretch', Icons.open_in_full, 'Stretch'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Standard', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPillRatioButton('16:9'),
                        _buildPillRatioButton('4:3'),
                        _buildPillRatioButton('18:9'),
                        _buildPillRatioButton('19.5:9'),
                        _buildPillRatioButton('20:9'),
                        _buildPillRatioButton('21:9'),
                      ].map((w) => Padding(padding: const EdgeInsets.only(right: 8.0), child: w)).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Cinema', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPillRatioButton('1.85:1'),
                        _buildPillRatioButton('2.21:1'),
                        _buildPillRatioButton('2.35:1'),
                        _buildPillRatioButton('2.39:1'),
                      ].map((w) => Padding(padding: const EdgeInsets.only(right: 8.0), child: w)).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 8),
                  _buildSwitchRow(
                    title: 'Remember ratio',
                    subtitle: 'Remember ratio for all videos.',
                    value: _rememberRatio,
                    onChanged: (val) {
                      setState(() {
                        _rememberRatio = val;
                      });
                      ref.read(storageServiceProvider).setRememberAspectRatio(val);
                      if (val) {
                        ref.read(storageServiceProvider).setSavedAspectRatio(_currentAspectRatioString);
                      }
                    },
                  ),
                  _buildSwitchRow(
                    title: 'Tap ratios to switch directly',
                    subtitle: 'Tap to switch, long press for the full menu.',
                    value: _tapToSwitchRatio,
                    onChanged: (val) {
                      setState(() {
                        _tapToSwitchRatio = val;
                      });
                      ref.read(storageServiceProvider).setTapToSwitchAspectRatio(val);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTrackSelector({required String title, required bool isSubtitle}) {
    setState(() {
      _showTrackSelectorPanel = true;
      _trackSelectorTitle = title;
      _trackSelectorIsSubtitle = isSubtitle;
      _showControls = false;
    });
  }

  Widget _buildCustomTrackSelectorPanel() {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return StreamBuilder<Tracks>(
      stream: widget.player.stream.tracks,
      initialData: widget.player.state.tracks,
      builder: (context, tracksSnapshot) {
        return StreamBuilder<Track>(
          stream: widget.player.stream.track,
          initialData: widget.player.state.track,
          builder: (context, trackSnapshot) {
            final tracksObj = tracksSnapshot.data;
            final currentTrackObj = trackSnapshot.data;
            
            final List<dynamic> rawTracks = _trackSelectorIsSubtitle
                ? (tracksObj?.subtitle ?? [])
                : (tracksObj?.audio ?? []);
            final currentTrack = _trackSelectorIsSubtitle
                ? currentTrackObj?.subtitle
                : currentTrackObj?.audio;
            
            final List<dynamic> options = [];
            if (_trackSelectorIsSubtitle) {
              options.add(SubtitleTrack.no());
              options.add(SubtitleTrack.auto());
            } else {
              options.add(AudioTrack.auto());
            }
            
            for (final track in rawTracks) {
              if (track.id != 'no' && track.id != 'auto') {
                options.add(track);
              }
            }
            
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  height: 340,
                  decoration: BoxDecoration(
                    color: const Color(0xE60F172A), // Slate 900 with 90% opacity
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 45,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _trackSelectorIsSubtitle ? Icons.subtitles : Icons.headphones,
                                color: settingsAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _trackSelectorIsSubtitle ? 'Subtitles' : 'Audio Tracks',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              if (_trackSelectorIsSubtitle) ...[
                                IconButton(
                                  icon: const Icon(Icons.cloud_download, color: Colors.white),
                                  tooltip: 'Download Subtitles Online',
                                  onPressed: _showSubtitleDownloaderDialog,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.tune, color: Colors.white),
                                  onPressed: _showSubtitleCustomizerDialog,
                                ),
                              ]
                              else
                                IconButton(
                                  icon: const Icon(Icons.tune, color: Colors.white),
                                  onPressed: _showAudioCustomizerDialog,
                                ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white60),
                                onPressed: () => setState(() => _showTrackSelectorPanel = false),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Divider(color: Colors.white12, height: 1),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: options.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No tracks available',
                                    style: TextStyle(color: Colors.white38, fontSize: 15),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final track = options[index];
                                    final isSelected = currentTrack != null &&
                                        track.id == currentTrack.id &&
                                        track.title == currentTrack.title &&
                                        track.language == currentTrack.language;
                                    
                                    Widget titleWidget;
                                    Widget? leadingWidget;
                                    
                                    if (track.id == 'auto') {
                                      leadingWidget = Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? settingsAccent.withValues(alpha: 0.2) : Colors.white10,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.autorenew,
                                          color: isSelected ? settingsAccent : Colors.white70,
                                          size: 18,
                                        ),
                                      );
                                      titleWidget = const Text(
                                        'Automatic Select',
                                        style: TextStyle(fontSize: 15),
                                      );
                                    } else if (track.id == 'no') {
                                      leadingWidget = Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white10,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.block,
                                          color: isSelected ? Colors.redAccent : Colors.white70,
                                          size: 18,
                                        ),
                                      );
                                      titleWidget = const Text(
                                        'Disable (None)',
                                        style: TextStyle(fontSize: 15),
                                      );
                                    } else {
                                      final lang = (track.language ?? '').toUpperCase();
                                      final tTitle = track.title ?? 'Track ${track.id}';
                                      
                                      if (lang.isNotEmpty) {
                                        leadingWidget = Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isSelected ? settingsAccent.withValues(alpha: 0.2) : Colors.white10,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected ? settingsAccent.withValues(alpha: 0.4) : Colors.white24,
                                            ),
                                          ),
                                          child: Text(
                                            lang,
                                            style: TextStyle(
                                              color: isSelected ? settingsAccent : Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      titleWidget = Text(
                                        tTitle,
                                        style: const TextStyle(fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () {
                                          final storage = ref.read(storageServiceProvider);
                                          if (_trackSelectorIsSubtitle) {
                                            widget.player.setSubtitleTrack(track);
                                            _applySubtitleProperty('sub-visibility', track.id == 'no' ? 'no' : 'yes');
                                            _updateBlendSubtitlesForTrack(widget.player, track);
                                            
                                            // Classify current audio track language to save preference under that category
                                            final activeAudio = widget.player.state.track.audio;
                                            String audioLangCategory = 'other';
                                            final lower = (activeAudio.language ?? activeAudio.title ?? '').toLowerCase();
                                            if (lower.contains('jpn') || lower.contains('ja') || lower.contains('japanese')) {
                                              audioLangCategory = 'jpn';
                                            } else if (lower.contains('eng') || lower.contains('en') || lower.contains('english')) {
                                              audioLangCategory = 'eng';
                                            }
                                            
                                            final trackPrefVal = track.id == 'no' ? 'no' : (track.language ?? track.title ?? track.id);
                                            storage.setPreferredSubtitleTrackForAudioLanguage(audioLangCategory, trackPrefVal);
                                            Log.i('Saved subtitle preference ($trackPrefVal) for audio language category ($audioLangCategory)');

                                            // Verify track change after brief delay
                                            Future.delayed(const Duration(milliseconds: 300), () {
                                              if (mounted) {
                                                final activeSub = widget.player.state.track.subtitle;
                                                Log.i('Active subtitle track verified: ${activeSub.id}');
                                                if (activeSub.id != track.id && track.id != 'no') {
                                                  Log.w('Discrepancy in subtitle track verification. Retrying setSubtitleTrack...');
                                                  widget.player.setSubtitleTrack(track);
                                                }
                                              }
                                            });
                                          } else {
                                            widget.player.setAudioTrack(track);
                                            final audioPrefVal = track.id == 'auto' ? 'auto' : (track.language ?? track.title ?? track.id);
                                            storage.setPreferredAudioTrack(audioPrefVal);
                                            Log.i('Saved audio preference ($audioPrefVal)');

                                            // Classify the newly selected audio track to dynamically auto-apply matching subtitle preferences
                                            final lower = (track.language ?? track.title ?? '').toLowerCase();
                                            String newAudioLangCategory = 'other';
                                            if (lower.contains('jpn') || lower.contains('ja') || lower.contains('japanese')) {
                                              newAudioLangCategory = 'jpn';
                                            } else if (lower.contains('eng') || lower.contains('en') || lower.contains('english')) {
                                              newAudioLangCategory = 'eng';
                                            }

                                            final prefSub = storage.getPreferredSubtitleTrackForAudioLanguage(newAudioLangCategory);
                                            final tracks = widget.player.state.tracks;

                                            if (prefSub != null) {
                                              if (prefSub == 'no') {
                                                if (widget.player.state.track.subtitle != SubtitleTrack.no()) {
                                                  widget.player.setSubtitleTrack(SubtitleTrack.no());
                                                }
                                              } else {
                                                for (final t in tracks.subtitle) {
                                                  final identifier = (t.language ?? t.title ?? t.id).toLowerCase();
                                                  if (identifier == prefSub.toLowerCase() ||
                                                      (t.title != null && t.title!.toLowerCase().contains(prefSub.toLowerCase())) ||
                                                      (t.language != null && t.language!.toLowerCase().contains(prefSub.toLowerCase()))) {
                                                    if (widget.player.state.track.subtitle != t) {
                                                      widget.player.setSubtitleTrack(t);
                                                    }
                                                    break;
                                                  }
                                                }
                                              }
                                            } else {
                                              // Apply smart default fallbacks on audio track change if no user preference exists yet
                                              if (newAudioLangCategory == 'eng') {
                                                if (widget.player.state.track.subtitle != SubtitleTrack.no()) {
                                                  widget.player.setSubtitleTrack(SubtitleTrack.no());
                                                }
                                              } else if (tracks.subtitle.isNotEmpty) {
                                                SubtitleTrack? targetSubTrack;
                                                for (final t in tracks.subtitle) {
                                                  final l = (t.language ?? t.title ?? '').toLowerCase();
                                                  if (l.contains('eng') || l.contains('en') || l.contains('english')) {
                                                    targetSubTrack = t;
                                                    break;
                                                  }
                                                }
                                                targetSubTrack ??= tracks.subtitle.firstWhere(
                                                  (t) => t.id != 'no' && t.id != 'auto',
                                                  orElse: () => tracks.subtitle.first,
                                                );
                                                if (widget.player.state.track.subtitle != targetSubTrack) {
                                                  widget.player.setSubtitleTrack(targetSubTrack);
                                                }
                                              }
                                            }
                                          }
                                          setState(() {
                                            _showTrackSelectorPanel = false;
                                            _showSeekIndicator = true;
                                            _seekDirection = '$_trackSelectorTitle: ${track.id == 'auto' ? 'Auto' : track.id == 'no' ? 'None' : (track.title ?? 'Track ${track.id}')}';
                                          });
                                          Future.delayed(const Duration(milliseconds: 1000), () {
                                            if (mounted) {
                                              setState(() => _showSeekIndicator = false);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isSelected 
                                                ? settingsAccent.withValues(alpha: 0.12) 
                                                : Colors.white.withValues(alpha: 0.04),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected 
                                                  ? settingsAccent.withValues(alpha: 0.4) 
                                                  : Colors.white.withValues(alpha: 0.05),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              if (leadingWidget != null) ...[
                                                leadingWidget,
                                                const SizedBox(width: 12),
                                              ],
                                              Expanded(
                                                child: DefaultTextStyle(
                                                  style: TextStyle(
                                                    color: isSelected ? settingsAccent : Colors.white,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                  child: titleWidget,
                                                ),
                                              ),
                                              if (isSelected)
                                                Icon(
                                                  Icons.check_circle,
                                                  color: settingsAccent,
                                                  size: 20,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final settings = ref.watch(videoSettingsProvider);
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    final subtitleConfig = SubtitleViewConfiguration(
      visible: !_isBlendingSubtitles,
    );

    return GestureDetector(
      onTap: _toggleControls,
      onScaleStart: _handleScaleStart,
      onScaleUpdate: (details) => _handleScaleUpdate(
        details,
        screenWidth,
        settings.pinchToZoom,
        settings.volumeGestures,
        settings.brightnessGestures,
        settings.horizontalSwipeToSeek,
      ),
      onScaleEnd: _handleScaleEnd,
      onDoubleTapDown: (details) => _handleDoubleTap(details, screenWidth, settings.doubleTapSeekDuration),
      onLongPressStart: (details) {
        if (_isLocked || !settings.dynamicSpeedOverlay) return;
        widget.player.setRate(1.5);
        setState(() {
          _showSeekIndicator = true;
          _seekDirection = '1.5x Fast Forwarding';
        });
      },
      onLongPressEnd: (details) {
        if (!settings.dynamicSpeedOverlay) return;
        widget.player.setRate(_currentSpeed);
        setState(() {
          _showSeekIndicator = false;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer with Pinch to Zoom
          if (_isBuffering || widget.customBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.orange,
              ),
            ),
          Transform.translate(
            offset: _panOffset,
            child: Transform.scale(
              scale: _scale,
              child: _customAspectRatio != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _customAspectRatio!,
                        child: Video(
                          key: ValueKey(_isBlendingSubtitles),
                          controller: widget.controller,
                          controls: NoVideoControls,
                          fit: BoxFit.fill,
                          subtitleViewConfiguration: subtitleConfig,
                        ),
                      ),
                    )
                  : Video(
                      key: ValueKey(_isBlendingSubtitles),
                      controller: widget.controller,
                      controls: NoVideoControls,
                      fit: _fit,
                      subtitleViewConfiguration: subtitleConfig,
                    ),
            ),
          ),
          
          // Simulated Brightness
          if (!_isPhysicalBrightnessSupported && _currentBrightness < 1.0)
            IgnorePointer(
              child: Container(color: Colors.black.withValues(alpha: 1.0 - _currentBrightness)),
            ),

          // Double Tap Seek Overlays
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
                          const _FlashingChevrons(isLeft: true),
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
                          const _FlashingChevrons(isLeft: false),
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
          if (_showBrightnessIndicator && !_isLocked)
            Positioned(top: 100, left: 40, child: _buildOSD(Icons.light_mode, _currentBrightness)),
          if (_showVolumeIndicator && !_isLocked)
            Positioned(
              top: 100, right: 40,
              child: _buildOSD(
                _currentVolume == 0 ? Icons.volume_off : Icons.volume_up,
                _currentVolume > 100 ? (_currentVolume - 100) / 100 : _currentVolume / 100,
                isBoosted: _currentVolume > 100,
              ),
            ),
          if (_showSpeedIndicator && !_isLocked && _dragStartFocalPoint != null)
            Positioned(
              top: 100,
              left: _dragStartFocalPoint!.dx <= screenWidth / 2 ? 40 : null,
              right: _dragStartFocalPoint!.dx > screenWidth / 2 ? 40 : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    const Icon(Icons.speed, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      '${_currentSpeed.toStringAsFixed(2)}x',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (_showSeekIndicator && !_isLocked)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(_seekDirection, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),

          // Locked overlay
          if (_isLocked && _showControls)
            Positioned(
              left: 16,
              bottom: 40,
              child: _buildActionButton(Icons.lock, 'Unlock', () {
                setState(() => _isLocked = false);
                _startHideTimer();
              }),
            ),

          // Auto Play Next Countdown Overlay
          if (_showAutoNextCountdown || _autoNextSlideIn)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              bottom: _showControls ? 130 : 30,
              right: _autoNextSlideIn ? 30 : -350,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next episode starts in $_autoNextSecondsRemaining seconds...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _onCancelAutoNext,
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: settingsAccent,
                                foregroundColor: settingsAccent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _cancelAutoNextCountdown();
                                if (widget.onNextEpisode != null) {
                                  widget.onNextEpisode!();
                                }
                              },
                              child: const Text('Play Now'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),



          // Controls UI Overlay
          if (_showControls && !_isLocked)
            Container(color: Colors.black54),

          if (_showControls && !_isLocked && !_showTrackSelectorPanel && !_showRatioPanel) ...[
            // Top Bar & Quick Actions
            Positioned(
              top: 40, left: 16, right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
                      Expanded(
                        child: Text(widget.videoTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (_sleepTimerSecondsRemaining != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Text(
                            _formatSleepTimeRemaining(_sleepTimerSecondsRemaining!),
                            style: TextStyle(
                              color: settingsAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54, width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: InkWell(
                          onTap: _toggleDecoderMode,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              _getDecoderModeLabel(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.closed_caption_outlined, color: Colors.white), 
                        onPressed: () => _showTrackSelector(
                          title: 'Subtitles',
                          isSubtitle: true,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.music_note_outlined, color: Colors.white), 
                        onPressed: () => _showTrackSelector(
                          title: 'Audio Tracks',
                          isSubtitle: false,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_play_outlined, color: Colors.white),
                        onPressed: _showQueueManagerSheet,
                      ),
                    ],
                  ),
                  _buildQuickActionRow(),
                ],
              ),
            ),
            
            // Middle-Right Screenshot Camera Button
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                    iconSize: 28,
                    onPressed: _takeScreenshot,
                  ),
                ),
              ),
            ),

            // Bottom Bar seekbar and playback controls
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerSeekBar(
                    player: widget.player,
                    downloadedPrefixSize: widget.downloadedPrefixSize,
                    expectedSize: widget.expectedSize,
                    seekbarStyle: settings.seekbarStyle,
                    settingsAccent: settingsAccent,
                    isPositionDownloaded: _isPositionDownloaded,
                    throttledSeek: _throttledSeek,
                    cancelHideTimer: () => _hideTimer?.cancel(),
                    startHideTimer: _startHideTimer,
                    clampSeekTarget: (target) => _clampSeekTarget(target, showMessage: false),
                    onSeekPerformed: _performSeek,
                    chapters: _chapters,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.lock_open_outlined, color: Colors.white70),
                              iconSize: 24,
                              onPressed: () {
                                setState(() => _isLocked = true);
                                _startHideTimer();
                              },
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Visibility(
                              visible: false,
                              maintainSize: true,
                              child: TextButton(
                                onPressed: null,
                                child: const Text(
                                  '90s+',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              iconSize: 28,
                              icon: Icon(
                                Icons.skip_previous,
                                color: widget.hasPrevEpisode ? Colors.white : Colors.white24,
                              ),
                              onPressed: widget.hasPrevEpisode ? widget.onPrevEpisode : null,
                            ),
                            const SizedBox(width: 16),
                            StreamBuilder<bool>(
                              stream: widget.player.stream.playing,
                              builder: (context, snapshot) {
                                final playing = snapshot.data ?? widget.player.state.playing;
                                return Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: IconButton(
                                    icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                                    iconSize: 32,
                                    onPressed: () {
                                      if (playing) {
                                        widget.player.pause();
                                      } else {
                                        widget.player.play();
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              iconSize: 28,
                              icon: Icon(
                                Icons.skip_next,
                                color: widget.hasNextEpisode ? Colors.white : Colors.white24,
                              ),
                              onPressed: widget.hasNextEpisode ? widget.onNextEpisode : null,
                            ),
                            const SizedBox(width: 16),
                            TextButton(
                              onPressed: () {
                                final target = widget.player.state.position + const Duration(seconds: 90);
                                final safeTarget = _clampSeekTarget(target, showMessage: false);
                                _performSeek(safeTarget);
                              },
                              child: const Text(
                                '90s+',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: _toggleSpeed,
                                  child: Text(
                                    'Speed (${_currentSpeed}x)',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.fit_screen_outlined, color: Colors.white),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          
          // Custom Track Selector Modal Panel Background Blur
          if (_showTrackSelectorPanel)
            GestureDetector(
              onTap: () => setState(() => _showTrackSelectorPanel = false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black38,
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _showTrackSelectorPanel ? 0 : -800,
            child: _buildCustomTrackSelectorPanel(),
          ),

          // Custom Aspect Ratio Panel Background Blur
          if (_showRatioPanel)
            GestureDetector(
              onTap: () => setState(() => _showRatioPanel = false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black38,
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _showRatioPanel ? 0 : -800,
            child: _buildRatioPanel(),
          ),

          // Custom Chapters Panel Background Blur
          if (_showChaptersPanel)
            GestureDetector(
              onTap: () => setState(() => _showChaptersPanel = false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black38,
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _showChaptersPanel ? 0 : -800,
            child: _buildCustomChaptersPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildOSD(IconData icon, double value, {bool isBoosted = false}) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final displayValue = value.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, color: isBoosted ? Colors.amber : Colors.white, size: 28),
          const SizedBox(height: 8),
          Container(
            width: 4, height: 100,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 4, height: 100 * displayValue,
              decoration: BoxDecoration(
                color: isBoosted ? Colors.amber : settingsAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (isBoosted) ...[
            const SizedBox(height: 4),
            const Text(
              'BOOST',
              style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {VoidCallback? onLongPress}) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showSubtitleDownloaderDialog() {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    // Clean current video title as search query default
    String defaultQuery = widget.videoTitle;
    defaultQuery = defaultQuery.replaceAll(RegExp(r'[\[\(]\d{3,4}p[\]\)]', caseSensitive: false), '');
    defaultQuery = defaultQuery.replaceAll(RegExp(r'(Dual|Multi)[-\s]Audio', caseSensitive: false), '');
    defaultQuery = defaultQuery.replaceAll(RegExp(r'(10bit|x265|hevc|x264|h264|bdrip|web-rip|webrip)', caseSensitive: false), '');
    defaultQuery = defaultQuery.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    defaultQuery = defaultQuery.replaceAll(RegExp(r'\([^)]*\)'), '');
    defaultQuery = defaultQuery.replaceAll(RegExp(r'[-\s:]+\s*(Season\s+\d+|S\d+)', caseSensitive: false), '');
    defaultQuery = defaultQuery.replaceAll(RegExp(r'\.(mkv|mp4|avi|mov|webm)$', caseSensitive: false), '');
    defaultQuery = defaultQuery.replaceAll(RegExp(r'[\s\-:]+$'), '');
    defaultQuery = defaultQuery.replaceAll(RegExp(r'\s+'), ' ').trim();

    final queryController = TextEditingController(text: defaultQuery);
    String selectedLangCode = 'eng';
    
    final downloader = ref.read(subtitleDownloaderServiceProvider);
    List<SubtitleMatch> searchResults = [];
    bool isSearching = false;
    String? downloadingId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Online Subtitle Downloader',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  
                  // Search Controls Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: queryController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search query...',
                            hintStyle: const TextStyle(color: Colors.white24),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: selectedLangCode,
                        dropdownColor: Colors.black,
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'eng', child: Text('English')),
                          DropdownMenuItem(value: 'spa', child: Text('Spanish')),
                          DropdownMenuItem(value: 'fre', child: Text('French')),
                          DropdownMenuItem(value: 'ger', child: Text('German')),
                          DropdownMenuItem(value: 'ind', child: Text('Indonesian')),
                          DropdownMenuItem(value: 'ara', child: Text('Arabic')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedLangCode = val);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: settingsAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: isSearching
                            ? null
                            : () async {
                                setModalState(() {
                                  isSearching = true;
                                  searchResults = [];
                                });
                                final res = await downloader.searchSubtitles(
                                  queryController.text.trim(),
                                  lang: selectedLangCode,
                                );
                                setModalState(() {
                                  isSearching = false;
                                  searchResults = res;
                                });
                              },
                        child: const Icon(Icons.search, color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Results list
                  Expanded(
                    child: isSearching
                        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                        : searchResults.isEmpty
                            ? const Center(
                                child: Text(
                                  'Search for subtitles to display results',
                                  style: TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                itemCount: searchResults.length,
                                itemBuilder: (context, index) {
                                  final sub = searchResults[index];
                                  final isDownloading = downloadingId == sub.id;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        sub.fileName,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        sub.language,
                                        style: TextStyle(color: settingsAccent, fontSize: 11),
                                      ),
                                      trailing: isDownloading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.orange,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.download_rounded, color: Colors.white70),
                                      onTap: isDownloading
                                          ? null
                                          : () async {
                                              setModalState(() => downloadingId = sub.id);
                                              final localPath = await downloader.downloadSubtitle(
                                                sub.downloadUrl,
                                                sub.fileName,
                                              );
                                              setModalState(() => downloadingId = null);
                                              
                                              if (localPath != null) {
                                                widget.player.setSubtitleTrack(SubtitleTrack.uri(localPath));
                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Subtitle loaded: ${sub.fileName}'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                }
                                              } else {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Failed to download subtitle file'),
                                                      backgroundColor: Colors.redAccent,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQueueManagerSheet() {
    _hideTimer?.cancel();
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final pipState = ref.watch(pipControllerProvider);
            if (pipState == null) {
              return const SizedBox(
                height: 100,
                child: Center(child: Text('No active queue', style: TextStyle(color: Colors.white70))),
              );
            }

            final queue = pipState.queue;
            final currentIndex = pipState.currentIndex;

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.playlist_play_rounded, color: settingsAccent, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'Play Queue (${queue.length})',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _showAddFromDownloadsDialog(context, setModalState),
                            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.blueAccent),
                            label: const Text('Add Downloads', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () {
                              Navigator.pop(context);
                              _startHideTimer();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  Expanded(
                    child: queue.isEmpty
                        ? const Center(child: Text('Queue is empty', style: TextStyle(color: Colors.white30)))
                        : ReorderableListView.builder(
                            itemCount: queue.length,
                            onReorderItem: (oldIndex, newIndex) {
                              // onReorderItem provides the adjusted newIndex (as if the item is already removed).
                              // Since pipControllerProvider.reorderQueue expects the raw onReorder index, we adjust it back.
                              final rawNewIndex = oldIndex < newIndex ? newIndex + 1 : newIndex;
                              ref.read(pipControllerProvider.notifier).reorderQueue(oldIndex, rawNewIndex);
                              setModalState(() {});
                            },
                            itemBuilder: (context, index) {
                              final item = queue[index];
                              final isCurrent = index == currentIndex;

                              return ListTile(
                                key: ValueKey('${item.videoFileId}_$index'),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: Icon(
                                  isCurrent ? Icons.play_arrow_rounded : Icons.drag_handle_rounded,
                                  color: isCurrent ? settingsAccent : Colors.white38,
                                ),
                                title: Text(
                                  item.videoTitle,
                                  style: TextStyle(
                                    color: isCurrent ? settingsAccent : Colors.white,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: item.seriesName.isNotEmpty
                                    ? Text(
                                        item.seriesName,
                                        style: TextStyle(
                                          color: isCurrent ? settingsAccent.withValues(alpha: 0.7) : Colors.white54,
                                          fontSize: 11,
                                        ),
                                      )
                                    : null,
                                trailing: isCurrent
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: settingsAccent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Playing',
                                          style: TextStyle(color: settingsAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                        onPressed: () {
                                          ref.read(pipControllerProvider.notifier).removeFromQueue(index);
                                          setModalState(() {});
                                        },
                                      ),
                                onTap: isCurrent
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        ref.read(pipControllerProvider.notifier).playQueueIndex(context, index);
                                      },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _startHideTimer();
    });
  }

  void _showAddFromDownloadsDialog(BuildContext context, StateSetter setModalState) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    final downloadTasks = ref.read(downloadControllerProvider);
    final completedDownloads = downloadTasks.entries
        .where((entry) => entry.value.isCompleted && entry.value.localPath != null)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Completed Downloads',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),
              Expanded(
                child: completedDownloads.isEmpty
                    ? const Center(
                        child: Text(
                          'No completed downloads available',
                          style: TextStyle(color: Colors.white30, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: completedDownloads.length,
                        itemBuilder: (context, index) {
                          final entry = completedDownloads[index];
                          final task = entry.value;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: Icon(Icons.download_done_rounded, color: settingsAccent),
                            title: Text(
                              task.title,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.add_rounded, color: Colors.blueAccent),
                            onTap: () {
                              ref.read(pipControllerProvider.notifier).addToQueue(
                                PlayQueueItem(
                                  messageId: task.fileId,
                                  videoFileId: task.fileId,
                                  videoTitle: task.title,
                                  seriesName: 'Offline Library',
                                  networkUrl: task.localPath,
                                ),
                              );
                              Navigator.pop(context);
                              setModalState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added to Queue: ${task.title}'),
                                  backgroundColor: settingsAccent,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubtitleCustomizerDialog() {
    final storage = ref.read(storageServiceProvider);

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final delay = storage.getSubtitleDelay();

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtitle Delay Sync',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Delay Sync: ${delay >= 0 ? "+" : ""}${delay.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      TextButton(
                        onPressed: () {
                          storage.setSubtitleDelay(0.0);
                          _applySubtitleProperty('sub-delay', '0.0');
                          setState(() {});
                          setModalState(() {});
                        },
                        child: const Text('Reset', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ],
                  ),
                  Slider(
                    value: delay,
                    min: -10.0,
                    max: 10.0,
                    divisions: 200,
                    activeColor: settingsAccent,
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      final roundedVal = (val * 10).round() / 10;
                      storage.setSubtitleDelay(roundedVal);
                      _applySubtitleProperty('sub-delay', roundedVal.toString());
                      setState(() {});
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAudioCustomizerDialog() {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Audio Enhancements',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Audio Boost', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Amplifies low dialog volume by adding dynamic software gain up to +6dB', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    value: _audioBoostActive,
                    activeThumbColor: settingsAccent,
                    onChanged: (val) {
                      setModalState(() {
                        _audioBoostActive = val;
                      });
                      setState(() {
                        _audioBoostActive = val;
                      });
                      _updateAudioFilters();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Night Mode (DRC)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Dynamic Range Compression levels volume spikes - quiet dialogs get louder, action blasts get quieter', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    value: _nightModeActive,
                    activeThumbColor: settingsAccent,
                    onChanged: (val) {
                      setModalState(() {
                        _nightModeActive = val;
                      });
                      setState(() {
                        _nightModeActive = val;
                      });
                      _updateAudioFilters();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }



  Future<void> _updateBlendSubtitlesForTrack(Player player, SubtitleTrack track) async {
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        if (track.id == 'no' || track.id == 'auto') {
          nativePlayer.setProperty('blend-subtitles', 'no');
          if (mounted && _isBlendingSubtitles) {
            setState(() {
              _isBlendingSubtitles = false;
            });
          }
          return;
        }
        
        final countStr = await nativePlayer.getProperty('track-list/count');
        final count = int.tryParse(countStr) ?? 0;
        for (int i = 0; i < count; i++) {
          final type = await nativePlayer.getProperty('track-list/$i/type');
          if (type == 'sub') {
            final id = await nativePlayer.getProperty('track-list/$i/id');
            if (id == track.id) {
              final codec = (await nativePlayer.getProperty('track-list/$i/codec')).toLowerCase();
              Log.i('Selected subtitle track ID ${track.id} has codec: $codec');
              
              final isGraphical = codec.contains('pgs') || 
                                  codec.contains('hdmv') || 
                                  codec.contains('dvd') || 
                                  codec.contains('vob') || 
                                  codec.contains('dvb') ||
                                  codec == 'xsub';
              final isAss = codec.contains('ass') || codec.contains('ssa');
              final isGraphicalOrAss = isGraphical || isAss;
                                       
              final hwdec = ref.read(storageServiceProvider).getHardwareDecoderMode();
              final isDirectHw = Platform.isAndroid && hwdec == 'mediacodec';
              
              if (isGraphicalOrAss && !isDirectHw) {
                nativePlayer.setProperty('blend-subtitles', 'yes');
                Log.i('Native blending subtitle enabled. Set blend-subtitles to yes.');
                if (mounted && !_isBlendingSubtitles) {
                  setState(() {
                    _isBlendingSubtitles = true;
                  });
                }
              } else {
                nativePlayer.setProperty('blend-subtitles', 'no');
                Log.i('Native blending subtitle disabled (Direct HW or Text-only). Set blend-subtitles to no.');
                if (mounted && _isBlendingSubtitles) {
                  setState(() {
                    _isBlendingSubtitles = false;
                  });
                }
              }
              
              // Show SnackBar warning if on Android and using direct hardware decoding
              if (Platform.isAndroid && isDirectHw && mounted) {
                if (isGraphical) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PGS/graphical subtitles require HW+ (Compatible) or SW decoder to render on Android.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 4),
                    ),
                  );
                } else if (isAss) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ASS/SSA subtitles rendered in text mode. Switch to HW+ or SW for full native styling.'),
                      backgroundColor: Colors.blueGrey,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              }
              return;
            }
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

    await storage.setHardwareDecoderMode(nextMode);

    try {
      if (widget.player.platform is NativePlayer) {
        final nativePlayer = widget.player.platform as NativePlayer;
        if (nextMode != 'no') {
          if (Platform.isAndroid) {
            nativePlayer.setProperty('hwdec', nextMode);
          } else {
            nativePlayer.setProperty('hwdec', 'auto');
          }
        } else {
          nativePlayer.setProperty('hwdec', 'no');
        }
      }
    } catch (e) {
      Log.w('Failed to apply hwdec change dynamically: $e');
    }

    _showSkipToast(toastText);
    setState(() {});
  }

  bool _isCurrentPositionInOutro(Duration position) {
    if (!_hasChapters || _chapters.isEmpty) return false;
    final totalDuration = widget.player.state.duration.inSeconds.toDouble();
    for (int i = 0; i < _chapters.length; i++) {
      final ch = _chapters[i];
      final start = ch.position.inSeconds.toDouble();
      final end = (i + 1 < _chapters.length)
          ? _chapters[i + 1].position.inSeconds.toDouble()
          : (totalDuration > 0 ? totalDuration : start + 90.0);
      if (_isChapterOutro(ch, start, end, totalDuration)) {
        if (position >= ch.position) {
          return true;
        }
      }
    }
    return false;
  }
}

class PlayerSeekBar extends StatefulWidget {
  final Player player;
  final int downloadedPrefixSize;
  final int expectedSize;
  final String seekbarStyle;
  final Color settingsAccent;
  final ValueChanged<Duration> onSeekPerformed;
  final bool Function(Duration) isPositionDownloaded;
  final void Function(Duration) throttledSeek;
  final VoidCallback cancelHideTimer;
  final VoidCallback startHideTimer;
  final Duration Function(Duration) clampSeekTarget;
  final List<VideoChapter> chapters;

  const PlayerSeekBar({
    super.key,
    required this.player,
    required this.downloadedPrefixSize,
    required this.expectedSize,
    required this.seekbarStyle,
    required this.settingsAccent,
    required this.onSeekPerformed,
    required this.isPositionDownloaded,
    required this.throttledSeek,
    required this.cancelHideTimer,
    required this.startHideTimer,
    required this.clampSeekTarget,
    required this.chapters,
  });

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _draggingValue;

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

  @override
  Widget build(BuildContext context) {
    double downloadedRatio = widget.expectedSize > 0
        ? (widget.downloadedPrefixSize / widget.expectedSize).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      children: [
        StreamBuilder<Duration>(
          stream: widget.player.stream.position,
          builder: (context, snapshot) {
            final pos = snapshot.data ?? widget.player.state.position;
            final displayPos = _draggingValue != null
                ? Duration(milliseconds: _draggingValue!.toInt())
                : pos;
            return Text(_formatDuration(displayPos), style: const TextStyle(color: Colors.white));
          },
        ),
        Expanded(
          child: StreamBuilder<Duration>(
            stream: widget.player.stream.position,
            builder: (context, posSnap) {
              return StreamBuilder<Duration>(
                stream: widget.player.stream.duration,
                builder: (context, durSnap) {
                  final pos = posSnap.data ?? widget.player.state.position;
                  final dur = durSnap.data ?? widget.player.state.duration;
                  double maxVal = dur.inMilliseconds.toDouble();
                  if (maxVal == 0) maxVal = pos.inMilliseconds.toDouble(); // fallback
                  final val = pos.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);

                  final SliderTrackShape baseTrackShape = widget.seekbarStyle == 'Wavy'
                      ? WavySliderTrackShape()
                      : widget.seekbarStyle == 'Thick'
                          ? const RectangularSliderTrackShape()
                          : const RoundedRectSliderTrackShape();

                  final trackShape = ChapterSliderTrackShape(
                    delegate: baseTrackShape,
                    chapters: widget.chapters,
                    totalDuration: dur,
                  );

                  return SliderTheme(
                    data: SliderThemeData(
                      trackHeight: widget.seekbarStyle == 'Thick' ? 8.0 : 4.0,
                      trackShape: trackShape,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                      activeTrackColor: widget.settingsAccent,
                      secondaryActiveTrackColor: widget.settingsAccent.withValues(alpha: 0.35),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: widget.settingsAccent,
                    ),
                    child: Slider(
                      min: 0,
                      max: maxVal > 0 ? maxVal : 1.0,
                      value: _draggingValue ?? val,
                      secondaryTrackValue: (maxVal * downloadedRatio).clamp(0.0, maxVal),
                      onChangeStart: (_) {
                        widget.cancelHideTimer();
                        setState(() {
                          _draggingValue = val;
                        });
                      },
                      onChanged: maxVal > 0
                          ? (v) {
                              setState(() {
                                _draggingValue = v;
                              });
                              final target = Duration(milliseconds: v.toInt());
                              if (widget.isPositionDownloaded(target)) {
                                widget.throttledSeek(target);
                              }
                            }
                          : null,
                      onChangeEnd: (v) {
                        widget.startHideTimer();
                        final target = Duration(milliseconds: v.toInt());
                        final safeTarget = widget.clampSeekTarget(target);
                        widget.onSeekPerformed(safeTarget);
                        setState(() {
                          _draggingValue = null;
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        StreamBuilder<Duration>(
          stream: widget.player.stream.duration,
          builder: (context, snapshot) {
            final dur = snapshot.data ?? widget.player.state.duration;
            return Text(dur.inSeconds == 0 ? '--:--' : _formatDuration(dur), style: const TextStyle(color: Colors.white));
          },
        ),
      ],
    );
  }
}

class WavySliderTrackShape extends RectangularSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final Paint secondaryPaint = Paint()
      ..color = sliderTheme.secondaryActiveTrackColor ?? (sliderTheme.activeTrackColor?.withValues(alpha: 0.35) ?? Colors.blueAccent.withValues(alpha: 0.35))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Path activePath = Path();
    final Path secondaryPath = Path();
    final Path inactivePath = Path();

    const double waveAmplitude = 4.0;
    const double waveWavelength = 24.0;

    bool firstActive = true;
    bool firstSecondary = true;
    bool firstInactive = true;
    
    final double midY = trackRect.top + trackRect.height / 2;
    final double secondaryX = secondaryOffset?.dx ?? thumbCenter.dx;

    for (double x = trackRect.left; x <= trackRect.right; x += 1.0) {
      final double relativeX = x - trackRect.left;
      final double y = midY + waveAmplitude * math.sin(relativeX * 2 * math.pi / waveWavelength);

      if (x <= thumbCenter.dx) {
        if (firstActive) {
          activePath.moveTo(x, y);
          firstActive = false;
        } else {
          activePath.lineTo(x, y);
        }
      } else if (x <= secondaryX) {
        if (firstSecondary) {
          secondaryPath.moveTo(x - 1, y);
          secondaryPath.lineTo(x, y);
          firstSecondary = false;
        } else {
          secondaryPath.lineTo(x, y);
        }
      } else {
        if (firstInactive) {
          inactivePath.moveTo(x - 1, midY);
          inactivePath.lineTo(x, y);
          firstInactive = false;
        } else {
          inactivePath.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(activePath, activePaint);
    if (secondaryX > thumbCenter.dx) {
      canvas.drawPath(secondaryPath, secondaryPaint);
    }
    canvas.drawPath(inactivePath, inactivePaint);
  }
}

class _FlashingChevrons extends StatefulWidget {
  final bool isLeft;
  const _FlashingChevrons({required this.isLeft});

  @override
  State<_FlashingChevrons> createState() => _FlashingChevronsState();
}

class _FlashingChevronsState extends State<_FlashingChevrons> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        
        double getOpacity(int index) {
          double phase = index / 3.0;
          double t = (val - phase) % 1.0;
          if (t < 0.5) {
            return _lerp(0.2, 1.0, t / 0.5);
          } else {
            return _lerp(1.0, 0.2, (t - 0.5) / 0.5);
          }
        }

        final widgets = List.generate(3, (i) {
          final opacityIdx = widget.isLeft ? (2 - i) : i;
          return Opacity(
            opacity: getOpacity(opacityIdx),
            child: Icon(
              widget.isLeft ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_right,
              color: Colors.white,
              size: 32,
            ),
          );
        });

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: widgets,
        );
      },
    );
  }
}

class VideoChapter {
  final String title;
  final Duration position;

  const VideoChapter({required this.title, required this.position});
}

class ChapterSliderTrackShape extends SliderTrackShape {
  final SliderTrackShape delegate;
  final List<VideoChapter> chapters;
  final Duration totalDuration;

  ChapterSliderTrackShape({
    required this.delegate,
    required this.chapters,
    required this.totalDuration,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    return delegate.getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    delegate.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    if (chapters.isEmpty || totalDuration.inMilliseconds <= 0) return;

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final double trackWidth = trackRect.width;
    final double trackLeft = trackRect.left;

    final Canvas canvas = context.canvas;
    final Paint tickPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final chapter in chapters) {
      final double fraction = chapter.position.inMilliseconds / totalDuration.inMilliseconds;
      if (fraction <= 0.0 || fraction >= 1.0) continue;

      final double tickX = trackLeft + fraction * trackWidth;

      canvas.drawLine(
        Offset(tickX, trackRect.top - 1.0),
        Offset(tickX, trackRect.bottom + 1.0),
        tickPaint,
      );
    }
  }
}
