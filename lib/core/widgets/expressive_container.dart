import 'dart:math' as math;
import 'package:flutter/material.dart';

enum ExpressiveShape {
  squiggly,
  capsule,
  squircle,
  circle,
}

class Material3ExpressiveContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final ExpressiveShape shape;
  final bool isSelected;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;
  final bool animateWavy;

  const Material3ExpressiveContainer({
    super.key,
    required this.child,
    this.onTap,
    this.shape = ExpressiveShape.circle,
    this.isSelected = false,
    this.activeColor,
    this.inactiveColor,
    this.size = 48.0,
    this.animateWavy = true,
  });

  @override
  State<Material3ExpressiveContainer> createState() => _Material3ExpressiveContainerState();
}

class _Material3ExpressiveContainerState extends State<Material3ExpressiveContainer>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _waveController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.90,
      upperBound: 1.0,
      value: 1.0,
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    if (widget.isSelected && widget.animateWavy && widget.shape == ExpressiveShape.squiggly) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant Material3ExpressiveContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected || widget.shape != oldWidget.shape) {
      if (widget.isSelected && widget.animateWavy && widget.shape == ExpressiveShape.squiggly) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _scaleController.reverse();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _scaleController.forward();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      _scaleController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCol = widget.activeColor ?? theme.primaryColor;
    final inactiveCol = widget.inactiveColor ?? Colors.white.withValues(alpha: 0.12);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleController,
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              final double phase = (widget.isSelected && widget.animateWavy)
                  ? _waveController.value * 2 * math.pi
                  : 0.0;

              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _ExpressiveShapePainter(
                  shape: widget.shape,
                  isSelected: widget.isSelected,
                  isHovered: _isHovered,
                  activeColor: activeCol,
                  inactiveColor: inactiveCol,
                  phase: phase,
                ),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: widget.isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      child: IconTheme(
                        data: IconThemeData(
                          color: widget.isSelected ? Colors.black : Colors.white,
                          size: widget.size * 0.5,
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExpressiveShapePainter extends CustomPainter {
  final ExpressiveShape shape;
  final bool isSelected;
  final bool isHovered;
  final Color activeColor;
  final Color inactiveColor;
  final double phase;

  _ExpressiveShapePainter({
    required this.shape,
    required this.isSelected,
    required this.isHovered,
    required this.activeColor,
    required this.inactiveColor,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final baseRadius = math.min(size.width, size.height) / 2;

    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    if (isSelected) {
      paint.color = activeColor;
    } else if (isHovered) {
      paint.color = inactiveColor.withValues(alpha: 0.24);
    } else {
      paint.color = inactiveColor;
    }

    final path = Path();

    switch (shape) {
      case ExpressiveShape.squiggly:
        const steps = 360;
        final waveAmp = baseRadius * 0.08;
        final effectiveRadius = baseRadius - waveAmp;
        for (int i = 0; i <= steps; i++) {
          final angle = (i * 2 * math.pi) / steps;
          final radius = effectiveRadius + waveAmp * math.cos(10 * angle + phase);
          final x = centerX + radius * math.cos(angle);
          final y = centerY + radius * math.sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;

      case ExpressiveShape.capsule:
        final rect = Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: size.width,
          height: size.height,
        );
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(baseRadius));
        canvas.drawRRect(rrect, paint);
        break;

      case ExpressiveShape.squircle:
        final rect = Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: size.width,
          height: size.height,
        );
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.32));
        canvas.drawRRect(rrect, paint);
        break;

      case ExpressiveShape.circle:
        canvas.drawCircle(Offset(centerX, centerY), baseRadius, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ExpressiveShapePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isHovered != isHovered ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.phase != phase;
  }
}
