import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:math' as math;
import 'dart:async';
class Material3ExpressiveSquigglyPlayButton extends StatefulWidget {
  final Player player;
  final double size;
  final double iconSize;

  const Material3ExpressiveSquigglyPlayButton({
    super.key,
    required this.player,
    this.size = 52.0,
    this.iconSize = 30.0,
  });

  @override
  State<Material3ExpressiveSquigglyPlayButton> createState() =>
      _Material3ExpressiveSquigglyPlayButtonState();
}

class _Material3ExpressiveSquigglyPlayButtonState
    extends State<Material3ExpressiveSquigglyPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final StreamSubscription<bool> _playingSubscription;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.player.state.playing;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    if (_isPlaying) {
      _animationController.repeat();
    }

    _playingSubscription = widget.player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() {
        _isPlaying = playing;
      });
      if (playing) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    });
  }

  @override
  void dispose() {
    _playingSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double phase = _isPlaying
            ? _animationController.value * 2 * math.pi
            : 0.0;
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: SquigglyPainter(
            color: Colors.white,
            phase: phase,
            waves: 10,
            waveAmplitude: 3.5,
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              iconSize: widget.iconSize,
              padding: EdgeInsets.zero,
              onPressed: () {
                if (_isPlaying) {
                  widget.player.pause();
                } else {
                  widget.player.play();
                }
              },
            ),
          ),
        );
      },
    ),
  );
  }
}

class SquigglyPainter extends CustomPainter {
  final Color color;
  final double phase;
  final int waves;
  final double waveAmplitude;

  SquigglyPainter({
    required this.color,
    required this.phase,
    this.waves = 10,
    this.waveAmplitude = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final baseRadius = math.min(size.width, size.height) / 2 - waveAmplitude;

    final path = Path();
    const steps = 360;

    for (int i = 0; i <= steps; i++) {
      final angle = (i * 2 * math.pi) / steps;
      final radius =
          baseRadius + waveAmplitude * math.cos(waves * angle + phase);
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant SquigglyPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.phase != phase ||
        oldDelegate.waves != waves ||
        oldDelegate.waveAmplitude != waveAmplitude;
  }
}



