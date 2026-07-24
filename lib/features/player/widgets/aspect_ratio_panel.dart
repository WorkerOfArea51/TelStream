import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AspectRatioPanel extends ConsumerWidget {
  final VoidCallback onClose;
  final BoxFit currentFit;
  final double? customAspectRatio;
  final void Function(String ratioId) onSelectRatio;
  final bool rememberRatio;
  final ValueChanged<bool> onToggleRememberRatio;
  final bool tapToSwitchRatio;
  final ValueChanged<bool> onToggleTapToSwitch;

  const AspectRatioPanel({
    super.key,
    required this.onClose,
    required this.currentFit,
    required this.customAspectRatio,
    required this.onSelectRatio,
    required this.rememberRatio,
    required this.onToggleRememberRatio,
    required this.tapToSwitchRatio,
    required this.onToggleTapToSwitch,
  });

  bool _isRatioActive(String ratioId) {
    if (ratioId == 'fit' && currentFit == BoxFit.contain && customAspectRatio == null) return true;
    if (ratioId == 'fill' && currentFit == BoxFit.cover && customAspectRatio == null) return true;
    if (ratioId == 'stretch' && currentFit == BoxFit.fill && customAspectRatio == null) return true;
    if (ratioId == '16:9' && currentFit == BoxFit.contain && customAspectRatio == 16 / 9) return true;
    if (ratioId == '4:3' && currentFit == BoxFit.contain && customAspectRatio == 4 / 3) return true;
    if (ratioId == '21:9' && currentFit == BoxFit.contain && customAspectRatio == 21 / 9) return true;
    return false;
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color settingsAccent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: settingsAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildScreenRatioButton(
    String ratioId,
    String label,
    IconData icon,
    Color settingsAccent,
  ) {
    final active = _isRatioActive(ratioId);
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelectRatio(ratioId),
        child: AnimatedContainer(
          duration: Duration.zero,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: active
                ? settingsAccent.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? settingsAccent : Colors.white10,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: active ? settingsAccent : Colors.white70,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: active ? settingsAccent : Colors.white70,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillRatioButton(String ratioId, Color settingsAccent) {
    final active = _isRatioActive(ratioId);
    return GestureDetector(
      onTap: () => onSelectRatio(ratioId),
      child: AnimatedContainer(
        duration: Duration.zero,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? settingsAccent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? settingsAccent : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Text(
          ratioId,
          style: TextStyle(
            color: active ? settingsAccent : Colors.white70,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: isLandscape ? double.infinity : screenHeight * 0.85,
      ),
      height: isLandscape ? double.infinity : null,
      decoration: BoxDecoration(
        color: const Color(0xEB0A0F1D),
        borderRadius: isLandscape
            ? const BorderRadius.horizontal(left: Radius.circular(30))
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: isLandscape ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onClose,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Aspect Ratio & Resize',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 12),
                      child: Text(
                        'Screen Fit',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _buildScreenRatioButton('fit', 'Fit (Auto)', Icons.aspect_ratio_rounded, settingsAccent),
                        const SizedBox(width: 12),
                        _buildScreenRatioButton('stretch', 'Stretch', Icons.settings_overscan_rounded, settingsAccent),
                        const SizedBox(width: 12),
                        _buildScreenRatioButton('fill', 'Crop (Zoom)', Icons.crop_free_rounded, settingsAccent),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 12),
                      child: Text(
                        'Fixed Ratios',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildPillRatioButton('16:9', settingsAccent),
                        _buildPillRatioButton('4:3', settingsAccent),
                        _buildPillRatioButton('18:9', settingsAccent),
                        _buildPillRatioButton('21:9', settingsAccent),
                        _buildPillRatioButton('1.85:1', settingsAccent),
                        _buildPillRatioButton('2.35:1', settingsAccent),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),
                    _buildSwitchRow(
                      title: 'Remember ratio',
                      subtitle: 'Remember ratio for all videos.',
                      value: rememberRatio,
                      onChanged: onToggleRememberRatio,
                      settingsAccent: settingsAccent,
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchRow(
                      title: 'Tap ratios to switch directly',
                      subtitle: 'Tap to switch, long press for the full menu.',
                      value: tapToSwitchRatio,
                      onChanged: onToggleTapToSwitch,
                      settingsAccent: settingsAccent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
