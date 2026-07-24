import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../../../services/storage_service.dart';
import '../../settings/settings_provider.dart';

class VideoGestureHandler {
  final Player player;
  final ValueNotifier<double> scaleNotifier;
  final ValueNotifier<Offset> panNotifier;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onHideTimerStart;
  final void Function(String) onOSD;
  final String Function(Duration) formatDuration;
  final bool Function(Duration) isPositionDownloaded;
  final Duration Function(Duration, {bool showMessage}) clampSeekTarget;
  final void Function(VoidCallback) setState;

  // Gesture state
  Offset? dragStartFocalPoint;
  bool isScaleGesture = false;
  bool isVerticalDrag = false;
  bool isHorizontalDrag = false;
  bool isSwipingToSeek = false;
  Duration swipeTargetPosition = Duration.zero;
  Duration swipeStartPosition = Duration.zero;
  double baseScale = 1.0;
  Offset basePanOffset = Offset.zero;
  double currentVolume = 100.0;
  double currentBrightness = 1.0;
  bool showVolumeIndicator = false;
  bool showBrightnessIndicator = false;
  bool showSpeedIndicator = false;
  bool showSeekIndicator = false;
  String seekDirection = '';
  DateTime? lastSeekWarningTime;
  DateTime lastVolumeCallTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastBrightnessCallTime = DateTime.fromMillisecondsSinceEpoch(0);

  VideoGestureHandler({
    required this.player,
    required this.scaleNotifier,
    required this.panNotifier,
    required this.onSeekStart,
    required this.onSeek,
    required this.onHideTimerStart,
    required this.onOSD,
    required this.formatDuration,
    required this.isPositionDownloaded,
    required this.clampSeekTarget,
    required this.setState,
  });

  void handleScaleStart(ScaleStartDetails details, {bool isLocked = false}) {
    if (isLocked) return;
    dragStartFocalPoint = details.focalPoint;
    isScaleGesture = false;
    isVerticalDrag = false;
    isHorizontalDrag = false;

    baseScale = scaleNotifier.value;
    basePanOffset = panNotifier.value;

    swipeStartPosition = player.state.position;
    swipeTargetPosition = swipeStartPosition;

    onHideTimerStart();
  }

  void handleScaleUpdate(
    ScaleUpdateDetails details,
    double screenWidth,
    bool pinchToZoom,
    bool volGestures,
    bool brightGestures,
    bool swipeSeek,
    GestureSettings gestureSettings,
    StorageService storageService,
    {bool isLocked = false}
  ) {
    if (isLocked) return;

    if (details.pointerCount > 1) {
      if (pinchToZoom) {
        isScaleGesture = true;
        setState(() {
          scaleNotifier.value = (baseScale * details.scale).clamp(1.0, 4.0);
          if (scaleNotifier.value == 1.0) panNotifier.value = Offset.zero;
        });
      }
      return;
    }

    if (isScaleGesture) return;

    if (dragStartFocalPoint != null &&
        !isVerticalDrag &&
        !isHorizontalDrag) {
      final double deltaX = (details.focalPoint.dx - dragStartFocalPoint!.dx)
          .abs();
      final double deltaY = (details.focalPoint.dy - dragStartFocalPoint!.dy)
          .abs();

      if (deltaX > 10 || deltaY > 10) {
        if (deltaX > deltaY) {
          if (swipeSeek) {
            isHorizontalDrag = true;
            isSwipingToSeek = true;
          }
        } else {
          isVerticalDrag = true;
        }
      }
      return;
    }

    if (isHorizontalDrag && isSwipingToSeek) {
      final duration = player.state.duration;
      if (duration.inSeconds == 0) return;

      final double totalDeltaX =
          details.focalPoint.dx - dragStartFocalPoint!.dx;
      double sensitivityMultiplier = 1.0;
      if (gestureSettings.gestureSensitivity == 'Low') {
        sensitivityMultiplier = 0.5;
      } else if (gestureSettings.gestureSensitivity == 'High') {
        sensitivityMultiplier = 1.5;
      }
      final secondsOffset =
          ((totalDeltaX / (screenWidth / 2)) * 60 * sensitivityMultiplier)
              .toInt();

      setState(() {
        final newSeconds = (swipeStartPosition.inSeconds + secondsOffset)
            .clamp(0, duration.inSeconds);
        swipeTargetPosition = Duration(seconds: newSeconds);
        showSeekIndicator = true;

        final diff =
            swipeTargetPosition.inSeconds - swipeStartPosition.inSeconds;
        final sign = diff >= 0 ? '+' : '';
        seekDirection =
            'Swipe: ${formatDuration(swipeTargetPosition)} ($sign${diff}s)';
      });
    } else if (isVerticalDrag && scaleNotifier.value <= 1.0) {
      final double deltaY = details.focalPointDelta.dy;
      final isLeft = dragStartFocalPoint!.dx <= screenWidth / 2;
      final action = isLeft
          ? gestureSettings.leftSwipeGesture
          : gestureSettings.rightSwipeGesture;

      if (action == 'Volume' && volGestures) {
        performVerticalSwipeAction('Volume', deltaY, gestureSettings, storageService);
      } else if (action == 'Brightness' && brightGestures) {
        performVerticalSwipeAction('Brightness', deltaY, gestureSettings, storageService);
      } else if (action == 'Speed') {
        performVerticalSwipeAction('Speed', deltaY, gestureSettings, storageService);
      }
    } else if (scaleNotifier.value > 1.0) {
      setState(() {
        panNotifier.value =
            basePanOffset + (details.focalPoint - dragStartFocalPoint!);
      });
    }
  }

  void handleScaleEnd(ScaleEndDetails details) {
    if (isSwipingToSeek) {
      setState(() {
        isSwipingToSeek = false;
        showSeekIndicator = false;
      });
      final safeTarget = clampSeekTarget(
        swipeTargetPosition,
        showMessage: true,
      );
      onSeek(safeTarget);
    }
    if (showSpeedIndicator) {
      player.seek(player.state.position);
    }

    if (showVolumeIndicator) {
      try {
        FlutterVolumeController.setVolume(
          (currentVolume / 100.0).clamp(0.0, 1.0),
        );
      } catch (_) {}
    }
    if (showBrightnessIndicator) {
      try {
        ScreenBrightness().setApplicationScreenBrightness(currentBrightness);
      } catch (_) {}
    }

    setState(() {
      showVolumeIndicator = false;
      showBrightnessIndicator = false;
      showSpeedIndicator = false;
    });
    dragStartFocalPoint = null;
    isScaleGesture = false;
    isVerticalDrag = false;
    isHorizontalDrag = false;
    onHideTimerStart();
  }

  void performVerticalSwipeAction(
    String actionType, 
    double deltaY,
    GestureSettings gestureSettings,
    StorageService storageService,
  ) {
    double sensitivityMultiplier = 1.0;
    if (gestureSettings.gestureSensitivity == 'Low') {
      sensitivityMultiplier = 0.5;
    } else if (gestureSettings.gestureSensitivity == 'High') {
      sensitivityMultiplier = 1.5;
    }

    if (actionType == 'Volume') {
      final bool volumeBoost = storageService.getVolumeBoostEnabled();
      final maxVol = volumeBoost ? 200.0 : 100.0;
      setState(() {
        currentVolume -= deltaY * 0.2 * sensitivityMultiplier;
        currentVolume = currentVolume.clamp(0.0, maxVol);

        final now = DateTime.now();
        if (now.difference(lastVolumeCallTime) >
            const Duration(milliseconds: 80)) {
          lastVolumeCallTime = now;
          try {
            FlutterVolumeController.setVolume(
              (currentVolume / 100.0).clamp(0.0, 1.0),
            );
          } catch (_) {}
        }

        player.setVolume(currentVolume);
        showVolumeIndicator = true;
      });
    } else if (actionType == 'Brightness') {
      setState(() {
        currentBrightness -= (deltaY / 300) * sensitivityMultiplier;
        currentBrightness = currentBrightness.clamp(0.0, 1.0);

        final now = DateTime.now();
        if (now.difference(lastBrightnessCallTime) >
            const Duration(milliseconds: 80)) {
          lastBrightnessCallTime = now;
          try {
            ScreenBrightness().setApplicationScreenBrightness(
              currentBrightness,
            );
          } catch (_) {
          }
        }

        showBrightnessIndicator = true;
      });
    } else if (actionType == 'Speed') {
      setState(() {
        double newSpeed = player.state.rate - (deltaY * 0.005 * sensitivityMultiplier);
        newSpeed = newSpeed.clamp(0.25, 4.0);
        newSpeed = double.parse(newSpeed.toStringAsFixed(2));
        player.setRate(newSpeed);
        showSpeedIndicator = true;
      });
    }
  }
}
