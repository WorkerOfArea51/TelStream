import 'package:flutter/material.dart';

class FlashingChevrons extends StatefulWidget {
  final bool isLeft;
  const FlashingChevrons({super.key, required this.isLeft});

  @override
  State<FlashingChevrons> createState() => _FlashingChevronsState();
}

class _FlashingChevronsState extends State<FlashingChevrons> with SingleTickerProviderStateMixin {
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
