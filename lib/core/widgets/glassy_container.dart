import 'dart:ui';
import 'package:flutter/material.dart';

class GlassyContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color backgroundColor;
  final Color borderColor;
  final double? width;
  final double? height;

  const GlassyContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.blur = 10.0,
    this.backgroundColor = const Color(0x1AFFFFFF), // 10% white
    this.borderColor = const Color(0x33FFFFFF), // 20% white
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
