import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';

class SpeedSelectorDialog extends StatefulWidget {
  final Player player;
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const SpeedSelectorDialog({
    super.key,
    required this.player,
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  static void show(
    BuildContext context, {
    required Player player,
    required double currentSpeed,
    required ValueChanged<double> onSpeedChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SpeedSelectorDialog(
          player: player,
          currentSpeed: currentSpeed,
          onSpeedChanged: onSpeedChanged,
        );
      },
    );
  }

  @override
  State<SpeedSelectorDialog> createState() => _SpeedSelectorDialogState();
}

class _SpeedSelectorDialogState extends State<SpeedSelectorDialog> {
  late double _speed;

  @override
  void initState() {
    super.initState();
    _speed = widget.currentSpeed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final presetRates = const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.speed, color: settingsAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Playback Speed',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 8),
          const SizedBox(height: 8),
          
          // Grid of speed chips
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: presetRates.map((rate) {
              final isSelected = _speed == rate;
              return ChoiceChip(
                label: Text('${rate}x'),
                selected: isSelected,
                selectedColor: settingsAccent,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _speed = rate;
                    });
                    widget.player.setRate(rate);
                    widget.onSpeedChanged(rate);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Slider for fine-tuning
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fine Tuning',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_speed.toStringAsFixed(2)}x',
                style: TextStyle(color: settingsAccent, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _speed,
            min: 0.25,
            max: 4.0,
            divisions: 75, // 0.05 step
            activeColor: settingsAccent,
            inactiveColor: Colors.white24,
            onChanged: (val) {
              final roundedVal = double.parse(val.toStringAsFixed(2));
              setState(() {
                _speed = roundedVal;
              });
              widget.player.setRate(roundedVal);
              widget.onSpeedChanged(roundedVal);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
