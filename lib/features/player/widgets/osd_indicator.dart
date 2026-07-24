import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class OSDIndicator extends StatelessWidget {
  final IconData icon;
  final double value;
  final bool isBoosted;

  const OSDIndicator({
    super.key,
    required this.icon,
    required this.value,
    this.isBoosted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final displayValue = value.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: isBoosted ? Colors.amber : Colors.white, size: 28),
          const SizedBox(height: 8),
          Container(
            width: 4,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 4,
              height: 100 * displayValue,
              decoration: BoxDecoration(
                color: isBoosted ? Colors.amber : settingsAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (isBoosted) ...[
            const SizedBox(height: 4),
            const Text(
              'BOOST',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
