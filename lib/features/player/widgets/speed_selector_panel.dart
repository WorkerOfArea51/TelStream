import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/settings_provider.dart';
import '../../../core/widgets/expressive_container.dart';
import '../../../services/storage_service.dart';

class SpeedSelectorPanel extends ConsumerStatefulWidget {
  final Player player;
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onClose;

  const SpeedSelectorPanel({
    super.key,
    required this.player,
    required this.currentSpeed,
    required this.onSpeedChanged,
    required this.onClose,
  });

  @override
  ConsumerState<SpeedSelectorPanel> createState() => _SpeedSelectorPanelState();
}

class _SpeedSelectorPanelState extends ConsumerState<SpeedSelectorPanel> {
  String _currentScreen = 'main'; // 'main', 'advanced', 'long_press'
  late double _speed;

  @override
  void initState() {
    super.initState();
    _speed = widget.currentSpeed;
  }

  void _updateSpeed(double rate) {
    final roundedVal = double.parse(rate.toStringAsFixed(2));
    setState(() {
      _speed = roundedVal;
    });
    widget.player.setRate(roundedVal);
    widget.onSpeedChanged(roundedVal);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final settings = ref.watch(videoSettingsProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      height: isLandscape ? double.infinity : 400.0,
      decoration: BoxDecoration(
        color: const Color(0xEB0A0F1D), // Slate 950 with 92% opacity - clean translucency (no blur)
        borderRadius: isLandscape
            ? const BorderRadius.horizontal(left: Radius.circular(30))
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 45,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Header Bar with dynamic back/close buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  if (_currentScreen != 'main') ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          if (_currentScreen == 'long_press') {
                            _currentScreen = 'advanced';
                          } else {
                            _currentScreen = 'main';
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _currentScreen == 'main'
                        ? 'Speed'
                        : _currentScreen == 'advanced'
                            ? 'Advanced settings'
                            : 'Long-press speed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // Content Screens
            if (_currentScreen == 'main')
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Speed slider & value label
                    Center(
                      child: Text(
                        '${_speed.toStringAsFixed(2)}x',
                        style: TextStyle(
                          color: settingsAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: _speed.clamp(0.25, 8.0),
                        min: 0.25,
                        max: 8.0,
                        divisions: 77, // step of 0.1s mostly
                        activeColor: settingsAccent,
                        inactiveColor: Colors.white24,
                        onChanged: _updateSpeed,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('0.25', style: TextStyle(color: Colors.white30, fontSize: 11)),
                          Text('8.0', style: TextStyle(color: Colors.white30, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick select speed grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.7,
                      children: [0.25, 0.5, 1.0, 1.25, 1.5, 2.0, 4.0, 8.0].map((rate) {
                        final isSelected = _speed == rate;
                        return Material3ExpressiveContainer(
                          shape: ExpressiveShape.capsule,
                          onTap: () => _updateSpeed(rate),
                          isSelected: isSelected,
                          activeColor: settingsAccent,
                          inactiveColor: Colors.white.withValues(alpha: 0.08),
                          child: Center(
                            child: Text(
                              rate == 1.0 ? '1x' : '${rate}x',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 10),

                    // Advanced settings tile
                    InkWell(
                      onTap: () {
                        setState(() {
                          _currentScreen = 'advanced';
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Advanced settings',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Icon(Icons.chevron_right_rounded, color: settingsAccent, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_currentScreen == 'advanced')
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Remember speed switch
                    _buildSwitchTile(
                      title: 'Remember speed',
                      subtitle: 'Remember speed for all videos.',
                      value: settings.rememberSpeed,
                      onChanged: (val) {
                        ref.read(videoSettingsProvider.notifier).updateSettings(
                          settings.copyWith(rememberSpeed: val),
                        );
                        // Save speed to storage right away if enabling remember speed
                        if (val) {
                          ref.read(storageServiceProvider).setPlaybackSpeed(_speed);
                        }
                      },
                      settingsAccent: settingsAccent,
                    ),
                    const SizedBox(height: 12),

                    // Long press to speed up switch
                    _buildSwitchTile(
                      title: 'Long press to speed up',
                      subtitle: 'Speed up playback on holding the screen.',
                      value: settings.dynamicSpeedOverlay,
                      onChanged: (val) {
                        ref.read(videoSettingsProvider.notifier).updateSettings(
                          settings.copyWith(dynamicSpeedOverlay: val),
                        );
                      },
                      settingsAccent: settingsAccent,
                    ),
                    const SizedBox(height: 12),

                    // Long-press speed select tile
                    InkWell(
                      onTap: () {
                        setState(() {
                          _currentScreen = 'long_press';
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Long-press speed',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${settings.longPressSpeed.toStringAsFixed(1)}x',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                                ),
                              ],
                            ),
                            Icon(Icons.chevron_right_rounded, color: settingsAccent, size: 22),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Long press vibration switch
                    _buildSwitchTile(
                      title: 'Long press vibration',
                      subtitle: 'Vibrate on triggering long-press speed up.',
                      value: settings.longPressVibration,
                      onChanged: (val) {
                        ref.read(videoSettingsProvider.notifier).updateSettings(
                          settings.copyWith(longPressVibration: val),
                        );
                      },
                      settingsAccent: settingsAccent,
                    ),
                  ],
                ),
              )
            else if (_currentScreen == 'long_press')
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [1.5, 2.0, 3.0, 4.0].map((rate) {
                    final isSelected = settings.longPressSpeed == rate;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          ref.read(videoSettingsProvider.notifier).updateSettings(
                            settings.copyWith(longPressSpeed: rate),
                          );
                          setState(() {
                            _currentScreen = 'advanced';
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? settingsAccent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? settingsAccent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${rate.toStringAsFixed(1)}x',
                                style: TextStyle(
                                  color: isSelected ? settingsAccent : Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: settingsAccent, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color settingsAccent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: settingsAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
