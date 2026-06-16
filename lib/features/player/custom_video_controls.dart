import 'dart:async';
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

  const CustomVideoControls({
    Key? key,
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
  }) : super(key: key);

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
  double? _draggingValue;
  String _currentAspectRatioString = 'fit';
  double? _customAspectRatio;
  bool _rememberRatio = false;
  bool _tapToSwitchRatio = false;
  bool _showRatioPanel = false;
  
  StreamSubscription<bool>? _bufferingSubscription;
  bool _isBuffering = false;
  
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

  // Double tap seek variables
  bool _showLeftSeekOverlay = false;
  bool _showRightSeekOverlay = false;
  double _doubleTapSeekOpacity = 0.0;
  int _doubleTapSeekAccumulated = 0;
  Timer? _doubleTapOverlayTimer;
  Duration? _doubleTapStartPosition;

  // Auto next episode countdown
  bool _showAutoNextCountdown = false;
  int _autoNextSecondsRemaining = 15;
  Timer? _autoNextTimer;
  bool _autoNextCancelled = false;
  StreamSubscription<Duration>? _positionSubscription;
  bool _autoNextTriggered = false;

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
    });
    _playlistSubscription = widget.player.stream.playlist.listen((_) {
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
    
    if (remaining <= 15 && remaining > 0 && !_autoNextTriggered) {
      _autoNextTriggered = true;
      _startAutoNextCountdown();
    } else if (remaining > 15 && _autoNextTriggered) {
      _cancelAutoNextCountdown();
      _autoNextTriggered = false;
    }
  }

  void _startAutoNextCountdown() {
    _autoNextTimer?.cancel();
    setState(() {
      _showAutoNextCountdown = true;
      _autoNextSecondsRemaining = 15;
    });
    
    _autoNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_autoNextSecondsRemaining > 1) {
            _autoNextSecondsRemaining--;
          } else {
            _autoNextTimer?.cancel();
            _showAutoNextCountdown = false;
            if (widget.onNextEpisode != null) {
              widget.onNextEpisode!();
            }
          }
        });
      } else {
        _autoNextTimer?.cancel();
      }
    });
  }

  void _cancelAutoNextCountdown() {
    _autoNextTimer?.cancel();
    setState(() {
      _showAutoNextCountdown = false;
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
    _bufferingSubscription?.cancel();
    _positionSubscription?.cancel();
    _volumeSubscription?.cancel();
    _brightnessSaveTimer?.cancel();
    _hideTimer?.cancel();
    _doubleTapOverlayTimer?.cancel();
    _autoNextTimer?.cancel();
    _sleepTimer?.cancel();
    _osdTimer?.cancel();
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
      } else if (_currentSpeed == 1.5) {
        _currentSpeed = 2.0;
      } else {
        _currentSpeed = 1.0;
      }
    });
    widget.player.setRate(_currentSpeed);
  }

  void _handleDoubleTap(TapDownDetails details, double screenWidth, int seekDuration) {
    if (_isLocked) return;

    final isLeft = details.globalPosition.dx < screenWidth / 2;

    _doubleTapOverlayTimer?.cancel();

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
    _performSeek(safeTarget);

    _doubleTapOverlayTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _doubleTapSeekOpacity = 0.0;
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
                              color: settingsAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: settingsAccent.withOpacity(0.3)),
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
                                  color: isSelected ? settingsAccent : Colors.white.withOpacity(0.05),
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
                              style: TextStyle(color: settingsAccent.withOpacity(0.6), fontSize: 12),
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
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _chapters = [];
        _hasChapters = false;
      });
    }
  }

  bool _isCurrentPositionInIntro(Duration position) {
    if (!_hasChapters || _chapters.isEmpty) {
      return position.inSeconds >= 5 && position.inSeconds <= 300;
    }

    for (int i = 0; i < _chapters.length; i++) {
      final ch = _chapters[i];
      final titleLower = ch.title.toLowerCase();
      
      if (titleLower.contains('intro') ||
          titleLower.contains('opening') ||
          titleLower.contains('op') ||
          titleLower.contains('recap')) {
        
        final start = ch.position;
        final end = (i + 1 < _chapters.length) 
            ? _chapters[i + 1].position 
            : widget.player.state.duration;

        if (position >= start && position < end) {
          return true;
        }
      }
    }
    return false;
  }

  void _handleSkipIntroTap(Duration currentPos) {
    if (_hasChapters && _chapters.isNotEmpty) {
      for (int i = 0; i < _chapters.length; i++) {
        final ch = _chapters[i];
        final titleLower = ch.title.toLowerCase();
        if (titleLower.contains('intro') ||
            titleLower.contains('opening') ||
            titleLower.contains('op') ||
            titleLower.contains('recap')) {
          
          final start = ch.position;
          final end = (i + 1 < _chapters.length) 
              ? _chapters[i + 1].position 
              : widget.player.state.duration;

          if (currentPos >= start && currentPos < end) {
            final safeTarget = _clampSeekTarget(end, showMessage: true);
            _performSeek(safeTarget);
            _showOSD('Skipped Chapter: ${ch.title}');
            return;
          }
        }
      }
    }
    
    final target = currentPos + const Duration(seconds: 85);
    final safeTarget = _clampSeekTarget(target, showMessage: true);
    _performSeek(safeTarget);
    _showOSD('Skipped Intro (+85s)');
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
                    color: Colors.black.withOpacity(0.5),
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
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () {
                                      final safeTarget = _clampSeekTarget(chapter.position, showMessage: false);
                                      _performSeek(safeTarget);
                                      setState(() {
                                        _showChaptersPanel = false;
                                        _showSeekIndicator = true;
                                        _seekDirection = 'Chapter: ${chapter.title}';
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
                                            ? settingsAccent.withOpacity(0.12) 
                                            : Colors.white.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected 
                                              ? settingsAccent.withOpacity(0.4) 
                                              : Colors.white.withOpacity(0.05),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isSelected ? settingsAccent.withOpacity(0.2) : Colors.white10,
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
                                              chapter.title,
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
      if (_dragStartFocalPoint!.dx > screenWidth / 2 && volGestures) {
        setState(() {
          _currentVolume -= deltaY * 0.2;
          _currentVolume = _currentVolume.clamp(0.0, 100.0);
          try {
            FlutterVolumeController.setVolume(_currentVolume / 100.0);
          } catch (_) {}
          widget.player.setVolume(_currentVolume);
          _showVolumeIndicator = true;
        });
      } else if (_dragStartFocalPoint!.dx <= screenWidth / 2 && brightGestures) {
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
    setState(() {
      _showVolumeIndicator = false;
      _showBrightnessIndicator = false;
    });
    _dragStartFocalPoint = null;
    _isScaleGesture = false;
    _isVerticalDrag = false;
    _isHorizontalDrag = false;
    _startHideTimer();
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
            activeColor: Colors.green,
            activeTrackColor: Colors.green.withOpacity(0.3),
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
        color: Colors.black.withOpacity(0.92),
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
                        color: Colors.black.withOpacity(0.5),
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
                                          color: isSelected ? settingsAccent.withOpacity(0.2) : Colors.white10,
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
                                          color: isSelected ? Colors.redAccent.withOpacity(0.2) : Colors.white10,
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
                                            color: isSelected ? settingsAccent.withOpacity(0.2) : Colors.white10,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected ? settingsAccent.withOpacity(0.4) : Colors.white24,
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
                                            storage.setPreferredSubtitleTrack(track.id == 'no' ? 'no' : (track.language ?? track.title ?? track.id));
                                          } else {
                                            widget.player.setAudioTrack(track);
                                            storage.setPreferredAudioTrack(track.id == 'auto' ? 'auto' : (track.language ?? track.title ?? track.id));
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
                                                ? settingsAccent.withOpacity(0.12) 
                                                : Colors.white.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected 
                                                  ? settingsAccent.withOpacity(0.4) 
                                                  : Colors.white.withOpacity(0.05),
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
        widget.player.setRate(2.0);
        setState(() {
          _showSeekIndicator = true;
          _seekDirection = '2.0x Fast Forwarding';
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
                          controller: widget.controller,
                          controls: NoVideoControls,
                          fit: BoxFit.fill,
                        ),
                      ),
                    )
                  : Video(
                      controller: widget.controller,
                      controls: NoVideoControls,
                      fit: _fit,
                    ),
            ),
          ),
          
          // Simulated Brightness
          if (!_isPhysicalBrightnessSupported && _currentBrightness < 1.0)
            IgnorePointer(
              child: Container(color: Colors.black.withOpacity(1.0 - _currentBrightness)),
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
                          Colors.black.withOpacity(0.55),
                          Colors.black.withOpacity(0.0),
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
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.55),
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
            Positioned(top: 100, right: 40, child: _buildOSD(_currentVolume == 0 ? Icons.volume_off : Icons.volume_up, _currentVolume / 100)),
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
          if (_showAutoNextCountdown && !_isLocked)
            Positioned(
              bottom: _showControls ? 130 : 30,
              right: 30,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
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

          // Skip Intro Overlay Button
          StreamBuilder<Duration>(
            stream: widget.player.stream.position,
            builder: (context, snapshot) {
              final pos = snapshot.data ?? widget.player.state.position;
              final showSkip = !_isLocked && _isCurrentPositionInIntro(pos);
              
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                right: showSkip ? 32 : -200,
                bottom: _showControls ? 140 : 40,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: showSkip ? 1.0 : 0.0,
                  child: InkWell(
                    onTap: () => _handleSkipIntroTap(pos),
                    borderRadius: BorderRadius.circular(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fast_forward, color: settingsAccent, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Skip Intro',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Controls UI Overlay
          if (_showControls && !_isLocked)
            Container(color: Colors.black54),

          if (_showControls && !_isLocked && !_showTrackSelectorPanel && !_showRatioPanel) ...[
            // Top Bar
            Positioned(
              top: 40, left: 16, right: 16,
              child: Row(
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
                  IconButton(
                    icon: Icon(
                      _sleepTimerSecondsRemaining != null ? Icons.snooze : Icons.snooze_outlined,
                      color: _sleepTimerSecondsRemaining != null ? settingsAccent : Colors.white,
                    ),
                    onPressed: _showSleepTimerSelector,
                  ),
                  IconButton(
                    icon: const Icon(Icons.subtitles, color: Colors.white), 
                    onPressed: () => _showTrackSelector(
                      title: 'Subtitles',
                      isSubtitle: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.headphones, color: Colors.white), 
                    onPressed: () => _showTrackSelector(
                      title: 'Audio Tracks',
                      isSubtitle: false,
                    ),
                  ),
                ],
              ),
            ),
            
            // Center Play/Pause
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      Icons.skip_previous,
                      color: widget.hasPrevEpisode ? Colors.white : Colors.white24,
                    ),
                    onPressed: widget.hasPrevEpisode ? widget.onPrevEpisode : null,
                  ),
                  const SizedBox(width: 32),
                  StreamBuilder<bool>(
                    stream: widget.player.stream.playing,
                    builder: (context, snapshot) {
                      final playing = snapshot.data ?? widget.player.state.playing;
                      return IconButton(
                        iconSize: 64,
                        icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                        onPressed: () {
                          if (playing) {
                            widget.player.pause();
                          } else {
                            widget.player.play();
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      Icons.skip_next,
                      color: widget.hasNextEpisode ? Colors.white : Colors.white24,
                    ),
                    onPressed: widget.hasNextEpisode ? widget.onNextEpisode : null,
                  ),
                ],
              ),
            ),

            // Bottom Bar
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Action Row (mpvEx style)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.lock_open, 'Lock', () {
                        setState(() => _isLocked = true);
                        _startHideTimer();
                      }),
                      _buildActionButton(Icons.screen_rotation, 'Rotate', _toggleFullscreen),
                      _buildActionButton(
                        Icons.aspect_ratio,
                        'Fit: ${_getRatioLabel(_currentAspectRatioString)}',
                        _handleAspectRatioButtonTap,
                        onLongPress: _tapToSwitchRatio ? _showAspectRatioPanel : null,
                      ),
                      if (_hasChapters)
                        _buildActionButton(Icons.list, 'Chapters', _openChaptersPanel),
                      _buildActionButton(Icons.forward, '+85s', () {
                        final currentPos = widget.player.state.position;
                        final target = currentPos + const Duration(seconds: 85);
                        final safeTarget = _clampSeekTarget(target, showMessage: true);
                        _performSeek(safeTarget);
                        _showOSD('Skipped +85s');
                      }),
                      _buildActionButton(Icons.speed, '${_currentSpeed}x', _toggleSpeed),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Seekbar & Time
                  Row(
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
                                double max = dur.inMilliseconds.toDouble();
                                if (max == 0) max = pos.inMilliseconds.toDouble(); // fallback to prevent division by zero or stuck thumb
                                final val = pos.inMilliseconds.toDouble().clamp(0.0, max > 0 ? max : 1.0);
                                
                                return SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: settings.seekbarStyle == 'Thick' ? 8.0 : 4.0,
                                    trackShape: settings.seekbarStyle == 'Wavy'
                                        ? WavySliderTrackShape()
                                        : null,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                                    activeTrackColor: settingsAccent,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: settingsAccent,
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: max > 0 ? max : 1.0,
                                    value: _draggingValue ?? val,
                                    onChangeStart: (_) {
                                      _hideTimer?.cancel();
                                      setState(() {
                                        _draggingValue = val;
                                      });
                                    },
                                    onChanged: max > 0 ? (v) {
                                      setState(() {
                                        _draggingValue = v;
                                      });
                                    } : null,
                                    onChangeEnd: (v) {
                                      _startHideTimer();
                                      final target = Duration(milliseconds: v.toInt());
                                      final safeTarget = _clampSeekTarget(target, showMessage: false);
                                      _performSeek(safeTarget);
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
                  ),
                ],
              ),
            ),
          ],
          
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

  Widget _buildOSD(IconData icon, double value) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Container(
            width: 4, height: 100,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 4, height: 100 * value,
              decoration: BoxDecoration(color: settingsAccent, borderRadius: BorderRadius.circular(2)),
            ),
          ),
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

    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Path activePath = Path();
    final Path inactivePath = Path();

    const double waveAmplitude = 4.0;
    const double waveWavelength = 24.0;

    bool firstActive = true;
    bool firstInactive = true;
    
    final double midY = trackRect.top + trackRect.height / 2;

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
    canvas.drawPath(inactivePath, inactivePaint);
  }
}

class _FlashingChevrons extends StatefulWidget {
  final bool isLeft;
  const _FlashingChevrons({super.key, required this.isLeft});

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
