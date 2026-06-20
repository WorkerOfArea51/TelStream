import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavyCircularProgressIndicator extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final Color? color;
  final Color backgroundColor;
  final double strokeWidth;
  final double waveAmplitude;
  final int waveCount;

  const WavyCircularProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor = Colors.white12,
    this.strokeWidth = 2.5,
    this.waveAmplitude = 1.5,
    this.waveCount = 8,
  });

  @override
  State<WavyCircularProgressIndicator> createState() => _WavyCircularProgressIndicatorState();
}

class _WavyCircularProgressIndicatorState extends State<WavyCircularProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = widget.color ?? theme.primaryColor;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(28, 28),
          painter: _WavyCirclePainter(
            value: widget.value,
            phase: _controller.value * 2 * math.pi,
            color: indicatorColor,
            backgroundColor: widget.backgroundColor,
            strokeWidth: widget.strokeWidth,
            waveAmplitude: widget.waveAmplitude,
            waveCount: widget.waveCount,
          ),
        );
      },
    );
  }
}

class _WavyCirclePainter extends CustomPainter {
  final double value;
  final double phase;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double waveAmplitude;
  final int waveCount;

  _WavyCirclePainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.waveAmplitude,
    required this.waveCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width - strokeWidth - waveAmplitude * 2) / 2;

    if (baseRadius <= 0) return;

    final paintBackground = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final paintProgress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // Start from top

    // Draw background wavy circle
    final bgPath = Path();
    final bgSteps = (2 * math.pi * 50).ceil().clamp(10, 300);
    for (int i = 0; i <= bgSteps; i++) {
      final theta = startAngle + (2 * math.pi * i / bgSteps);
      final angleForWave = (theta - startAngle) * waveCount;
      final r = baseRadius + math.sin(angleForWave - phase) * waveAmplitude;
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);

      if (i == 0) {
        bgPath.moveTo(x, y);
      } else {
        bgPath.lineTo(x, y);
      }
    }
    canvas.drawPath(bgPath, paintBackground);

    // Draw wavy progress path
    final progressAngle = value.clamp(0.0, 1.0) * 2 * math.pi;
    if (progressAngle <= 0) return;

    final path = Path();
    final steps = (progressAngle * 50).ceil().clamp(10, 300);

    for (int i = 0; i <= steps; i++) {
      final theta = startAngle + (progressAngle * i / steps);
      // Modulate radius based on angle and phase
      final angleForWave = (theta - startAngle) * waveCount;
      final r = baseRadius + math.sin(angleForWave - phase) * waveAmplitude;
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paintProgress);
  }

  @override
  bool shouldRepaint(covariant _WavyCirclePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.phase != phase;
  }
}

class WavyLinearProgressIndicator extends StatefulWidget {
  final double? value; // null for indeterminate, or 0.0 to 1.0
  final Color? color;
  final Color backgroundColor;
  final double strokeWidth;
  final double waveHeight;
  final double waveLength;

  const WavyLinearProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.backgroundColor = Colors.white10,
    this.strokeWidth = 3.5,
    this.waveHeight = 3.5,
    this.waveLength = 35.0,
  });

  @override
  State<WavyLinearProgressIndicator> createState() => _WavyLinearProgressIndicatorState();
}

class _WavyLinearProgressIndicatorState extends State<WavyLinearProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = widget.color ?? theme.primaryColor;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 16),
          painter: _WavyProgressPainter(
            value: widget.value,
            phase: _controller.value * 2 * math.pi,
            color: indicatorColor,
            backgroundColor: widget.backgroundColor,
            strokeWidth: widget.strokeWidth,
            waveHeight: widget.waveHeight,
            waveLength: widget.waveLength,
          ),
        );
      },
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  final double? value;
  final double phase;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double waveHeight;
  final double waveLength;

  _WavyProgressPainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.waveHeight,
    required this.waveLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintBackground = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintProgress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final width = size.width;

    // Draw background track (wavy line across the full width)
    final bgPath = Path();
    bgPath.moveTo(0, centerY);
    for (double x = 0; x <= width; x += 1) {
      final y = centerY + math.sin((x / waveLength) * 2 * math.pi - phase) * waveHeight;
      bgPath.lineTo(x, y);
    }
    canvas.drawPath(bgPath, paintBackground);

    if (value == null) {
      // Indeterminate wavy line across the entire width
      final path = Path();
      path.moveTo(0, centerY);
      for (double x = 0; x <= width; x += 1) {
        final y = centerY + math.sin((x / waveLength) * 2 * math.pi - phase) * waveHeight;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paintProgress);
    } else {
      // Determinate wavy progress
      final progressVal = value!.clamp(0.0, 1.0);
      final progressWidth = width * progressVal;

      if (progressWidth > 0) {
        final path = Path();
        path.moveTo(0, centerY);
        for (double x = 0; x <= progressWidth; x += 1) {
          final y = centerY + math.sin((x / waveLength) * 2 * math.pi - phase) * waveHeight;
          path.lineTo(x, y);
        }
        canvas.drawPath(path, paintProgress);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.phase != phase;
  }
}
