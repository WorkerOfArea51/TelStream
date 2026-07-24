import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AutoNextOverlay extends StatelessWidget {
  final bool showAutoNextCountdown;
  final bool autoNextSlideIn;
  final int autoNextSecondsRemaining;
  final bool showControls;
  final VoidCallback onCancelAutoNext;
  final VoidCallback onPlayNow;

  const AutoNextOverlay({
    super.key,
    required this.showAutoNextCountdown,
    required this.autoNextSlideIn,
    required this.autoNextSecondsRemaining,
    required this.showControls,
    required this.onCancelAutoNext,
    required this.onPlayNow,
  });

  @override
  Widget build(BuildContext context) {
    if (!showAutoNextCountdown && !autoNextSlideIn) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      bottom: showControls ? 130 : 30,
      right: autoNextSlideIn ? 30 : -350,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: 320,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next episode starts in $autoNextSecondsRemaining seconds...',
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
                      onPressed: onCancelAutoNext,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: settingsAccent,
                        foregroundColor: settingsAccent.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onPlayNow,
                      child: const Text('Play Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
