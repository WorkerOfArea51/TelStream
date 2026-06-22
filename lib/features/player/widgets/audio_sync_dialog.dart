import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';

class AudioSyncDialog extends StatefulWidget {
  final Player player;
  final double currentDelay;
  final ValueChanged<double> onDelayChanged;

  const AudioSyncDialog({
    super.key,
    required this.player,
    required this.currentDelay,
    required this.onDelayChanged,
  });

  static void show(
    BuildContext context, {
    required Player player,
    required double currentDelay,
    required ValueChanged<double> onDelayChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return AudioSyncDialog(
          player: player,
          currentDelay: currentDelay,
          onDelayChanged: onDelayChanged,
        );
      },
    );
  }

  @override
  State<AudioSyncDialog> createState() => _AudioSyncDialogState();
}

class _AudioSyncDialogState extends State<AudioSyncDialog> {
  late double _delay;

  @override
  void initState() {
    super.initState();
    _delay = widget.currentDelay;
  }

  void _updateDelay(double val) {
    // Round to 1 decimal place to stick to 0.1s increments
    final roundedVal = double.parse(val.toStringAsFixed(1));
    setState(() {
      _delay = roundedVal;
    });
    if (widget.player.platform is NativePlayer) {
      try {
        (widget.player.platform as NativePlayer).setProperty('audio-delay', roundedVal.toString());
      } catch (_) {}
    }
    widget.onDelayChanged(roundedVal);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

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
                  Icon(Icons.sync, color: settingsAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Audio / Video Sync Offset',
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
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Audio Delay',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_delay > 0 ? '+' : ''}${_delay.toStringAsFixed(1)}s',
                style: TextStyle(color: settingsAccent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _delay,
            min: -5.0,
            max: 5.0,
            divisions: 100,
            activeColor: settingsAccent,
            inactiveColor: Colors.white24,
            onChanged: _updateDelay,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '← Audio Earlier (Negative)',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              TextButton(
                onPressed: () => _updateDelay(0.0),
                child: Text('Reset to 0.0s', style: TextStyle(color: settingsAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const Text(
                'Audio Later (Positive) →',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _delay > 0 
                ? 'Delaying audio by ${_delay.toStringAsFixed(1)}s. Use this if the audio is playing ahead of the video (common with Bluetooth headphones).'
                : _delay < 0
                    ? 'Advancing audio by ${(-_delay).toStringAsFixed(1)}s. Use this if the audio is playing behind the video.'
                    : 'Audio and video sync is default.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
