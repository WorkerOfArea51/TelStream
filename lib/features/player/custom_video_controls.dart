import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../settings/settings_provider.dart';
import '../../core/theme/app_theme.dart';

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

  // Double tap seek variables
  bool _showLeftSeekOverlay = false;
  bool _showRightSeekOverlay = false;
  double _doubleTapSeekOpacity = 0.0;
  int _doubleTapSeekAccumulated = 0;
  Timer? _doubleTapOverlayTimer;
  Duration? _doubleTapStartPosition;


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

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _currentVolume = widget.player.state.volume;
    _bufferingSubscription = widget.player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isBuffering = buffering;
        });
      }
    });
  }

  @override
  void dispose() {
    _bufferingSubscription?.cancel();
    _hideTimer?.cancel();
    _doubleTapOverlayTimer?.cancel();
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
    widget.player.seek(safeTarget);

    _doubleTapOverlayTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _doubleTapSeekOpacity = 0.0;
        });
      }
    });
  }

  Duration _clampSeekTarget(Duration targetPosition, {bool showMessage = true}) {
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
          widget.player.setVolume(_currentVolume);
          _showVolumeIndicator = true;
        });
      } else if (_dragStartFocalPoint!.dx <= screenWidth / 2 && brightGestures) {
        setState(() {
          _currentBrightness -= deltaY / 300;
          _currentBrightness = _currentBrightness.clamp(0.0, 1.0);
          _showBrightnessIndicator = true;
        });
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
      widget.player.seek(safeTarget);
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

  void _toggleFit() {
    setState(() {
      _scale = 1.0;
      _panOffset = Offset.zero;
      if (_fit == BoxFit.contain) {
        _fit = BoxFit.cover;
      } else if (_fit == BoxFit.cover) {
        _fit = BoxFit.fill;
      } else {
        _fit = BoxFit.contain;
      }
      _showSeekIndicator = true;
      _seekDirection = 'Aspect Ratio: ${_getFitLabel(_fit)}';
    });
    _hideTimer?.cancel();
    _startHideTimer();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _showSeekIndicator = false);
      }
    });
  }

  String _getFitLabel(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'Fit';
      case BoxFit.cover:
        return 'Zoom';
      case BoxFit.fill:
        return 'Stretch';
      default:
        return 'Fit';
    }
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
                                          if (_trackSelectorIsSubtitle) {
                                            widget.player.setSubtitleTrack(track);
                                          } else {
                                            widget.player.setAudioTrack(track);
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
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.orange,
              ),
            ),
          Transform.translate(
            offset: _panOffset,
            child: Transform.scale(
              scale: _scale,
              child: Video(
                controller: widget.controller,
                controls: NoVideoControls,
                fit: _fit,
              ),
            ),
          ),
          
          // Simulated Brightness
          if (_currentBrightness < 1.0)
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

          // Controls UI Overlay
          if (_showControls && !_isLocked)
            Container(color: Colors.black54),

          if (_showControls && !_isLocked) ...[
            // Top Bar
            Positioned(
              top: 40, left: 16, right: 16,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
                  Expanded(
                    child: Text(widget.videoTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                        'Fit: ${_getFitLabel(_fit)}',
                        _toggleFit,
                      ),
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
                          return Text(_formatDuration(pos), style: const TextStyle(color: Colors.white));
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
                                    value: val,
                                    onChangeStart: (_) => _hideTimer?.cancel(),
                                    onChanged: max > 0 ? (v) {
                                      final target = Duration(milliseconds: v.toInt());
                                      final safeTarget = _clampSeekTarget(target, showMessage: false);
                                      widget.player.seek(safeTarget);
                                    } : null,
                                    onChangeEnd: (_) => _startHideTimer(),
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
            bottom: _showTrackSelectorPanel ? 0 : -350,
            child: _buildCustomTrackSelectorPanel(),
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

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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

    const double waveAmplitude = 3.0;
    const double waveWavelength = 15.0;

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
