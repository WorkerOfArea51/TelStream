import 'package:flutter/material.dart';
import 'osd_indicator.dart';

class VolumeIndicatorOverlay extends StatelessWidget {
  final double volume;
  final bool visible;

  const VolumeIndicatorOverlay({
    super.key,
    required this.volume,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      top: 100,
      right: 40,
      child: OSDIndicator(
        icon: volume == 0 ? Icons.volume_off : Icons.volume_up,
        value: volume > 100 ? (volume - 100) / 100 : volume / 100,
        isBoosted: volume > 100,
      ),
    );
  }
}

class BrightnessIndicatorOverlay extends StatelessWidget {
  final double brightness;
  final bool visible;

  const BrightnessIndicatorOverlay({
    super.key,
    required this.brightness,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      top: 100,
      left: 40,
      child: OSDIndicator(
        icon: Icons.light_mode,
        value: brightness,
      ),
    );
  }
}

class SeekIndicatorOverlay extends StatelessWidget {
  final String direction;
  final bool visible;

  const SeekIndicatorOverlay({
    super.key,
    required this.direction,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            direction,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
