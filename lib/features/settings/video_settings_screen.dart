import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

class VideoSettingsScreen extends ConsumerWidget {
  const VideoSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(videoSettingsProvider);
    final notifier = ref.read(videoSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      appBar: AppBar(
        title: const Text('Player Preferences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Player Layout'),
          _buildRadioGroup(
            title: 'Seekbar Style',
            options: const ['Standard', 'Wavy', 'Thick'],
            currentValue: settings.seekbarStyle,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(seekbarStyle: val)),
          ),
          _buildSwitch(
            title: 'Dynamic Speed Overlay',
            subtitle: 'Show advanced overlay for speed control during long press and swipe',
            value: settings.dynamicSpeedOverlay,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(dynamicSpeedOverlay: val)),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('General'),
          _buildSwitch(
            title: 'Save position on quit',
            value: settings.savePositionOnQuit,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(savePositionOnQuit: val)),
          ),
          _buildSwitch(
            title: 'Autoplay next video',
            subtitle: 'Automatically play next video when current ends',
            value: settings.autoplayNextVideo,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(autoplayNextVideo: val)),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Gestures'),
          _buildSwitch(
            title: 'Brightness gestures',
            value: settings.brightnessGestures,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(brightnessGestures: val)),
          ),
          _buildSwitch(
            title: 'Volume gestures',
            value: settings.volumeGestures,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(volumeGestures: val)),
          ),
          _buildSwitch(
            title: 'Horizontal swipe to seek',
            value: settings.horizontalSwipeToSeek,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(horizontalSwipeToSeek: val)),
          ),
          _buildSwitch(
            title: 'Pinch to zoom',
            value: settings.pinchToZoom,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(pinchToZoom: val)),
          ),
          ListTile(
            title: const Text('Double tap seek duration', style: TextStyle(color: Colors.white)),
            subtitle: Text('${settings.doubleTapSeekDuration}s', style: const TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () async {
              final newDuration = await showDialog<int>(
                context: context,
                builder: (context) => _SeekDurationDialog(current: settings.doubleTapSeekDuration),
              );
              if (newDuration != null) {
                notifier.updateSettings(settings.copyWith(doubleTapSeekDuration: newDuration));
              }
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Audio'),
          _buildSwitch(
            title: 'Enable audio pitch correction',
            subtitle: 'Prevents the audio from becoming high-pitched at faster speeds',
            value: settings.pitchCorrection,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(pitchCorrection: val)),
          ),
          _buildSwitch(
            title: 'Volume normalization',
            subtitle: 'Automatically adjust audio volume to maintain consistent loudness levels',
            value: settings.volumeNormalization,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(volumeNormalization: val)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildSwitch({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.white54)) : null,
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blueAccent,
      inactiveTrackColor: Colors.white12,
    );
  }

  Widget _buildRadioGroup({
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title, style: const TextStyle(color: Colors.white54)),
        ),
        ...options.map((option) => RadioListTile<String>(
          title: Text(option, style: const TextStyle(color: Colors.white)),
          value: option,
          groupValue: currentValue,
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          activeColor: Colors.blueAccent,
        )),
      ],
    );
  }
}

class _SeekDurationDialog extends StatefulWidget {
  final int current;

  const _SeekDurationDialog({required this.current});

  @override
  State<_SeekDurationDialog> createState() => _SeekDurationDialogState();
}

class _SeekDurationDialogState extends State<_SeekDurationDialog> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2640),
      title: const Text('Double tap seek duration', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_value seconds', style: const TextStyle(color: Colors.white, fontSize: 18)),
          Slider(
            value: _value.toDouble(),
            min: 5,
            max: 30,
            divisions: 5,
            activeColor: Colors.blueAccent,
            onChanged: (val) {
              setState(() {
                _value = val.toInt();
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _value),
          child: const Text('Save', style: TextStyle(color: Colors.blueAccent)),
        ),
      ],
    );
  }
}
