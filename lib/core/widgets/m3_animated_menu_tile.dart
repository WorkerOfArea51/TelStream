import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'expressive_container.dart';

class M3AnimatedMenuTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;

  const M3AnimatedMenuTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  State<M3AnimatedMenuTile> createState() => _M3AnimatedMenuTileState();
}

class _M3AnimatedMenuTileState extends State<M3AnimatedMenuTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.08), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.05), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white38 : Colors.black54;

    return ListTile(
      leading: Material3ExpressiveContainer(
        shape: ExpressiveShape.squircle,
        size: 38,
        activeColor: theme.primaryColor,
        isSelected: true, // Forces solid color accent background
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double rotation = 0.0;
            if (widget.icon == Icons.settings || widget.icon == Icons.settings_outlined) {
              rotation = _controller.value * 0.5 * math.pi;
            } else if (widget.icon == Icons.history) {
              rotation = -_rotationAnimation.value * math.pi;
            } else {
              rotation = _rotationAnimation.value * math.pi;
            }

            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: rotation,
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
            );
          },
        ),
      ),
      title: Text(
        widget.title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: widget.subtitle != null
          ? Text(widget.subtitle!, style: TextStyle(color: subTextColor, fontSize: 12))
          : null,
      trailing: widget.trailing ?? Icon(Icons.chevron_right, color: subTextColor.withValues(alpha: 0.5), size: 20),
      onTap: _handleTap,
    ).animate(
      onPlay: (controller) => controller.forward(),
    ).fadeIn(
      duration: 200.ms,
    ).slideX(
      begin: 0.1, end: 0,
      duration: 200.ms,
    );
  }
}
