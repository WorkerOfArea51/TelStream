import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

class VideoSettingsScreen extends ConsumerWidget {
  const VideoSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(videoSettingsProvider);
    final notifier = ref.read(videoSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Player Preferences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(theme, 'Player Layout'),
          Card(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRadioGroup(
                  theme: theme,
                  title: 'Seekbar Style',
                  options: const ['Standard', 'Wavy', 'Thick'],
                  currentValue: settings.seekbarStyle,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(seekbarStyle: val)),
                ),
                const Divider(color: Colors.white10, height: 1),
                _buildSwitch(
                  theme: theme,
                  title: 'Dynamic Speed Overlay',
                  subtitle: 'Show advanced overlay for speed control during long press and swipe',
                  value: settings.dynamicSpeedOverlay,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(dynamicSpeedOverlay: val)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'General'),
          Card(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: Column(
              children: [
                _buildSwitch(
                  theme: theme,
                  title: 'Save position on quit',
                  value: settings.savePositionOnQuit,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(savePositionOnQuit: val)),
                ),
                const Divider(color: Colors.white10, height: 1),
                _buildSwitch(
                  theme: theme,
                  title: 'Autoplay next video',
                  subtitle: 'Automatically play next video when current ends',
                  value: settings.autoplayNextVideo,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(autoplayNextVideo: val)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Gestures'),
          Card(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: Column(
              children: [
                _buildSwitch(
                  theme: theme,
                  title: 'Brightness gestures',
                  value: settings.brightnessGestures,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(brightnessGestures: val)),
                ),
                const Divider(color: Colors.white10, height: 1),
                _buildSwitch(
                  theme: theme,
                  title: 'Volume gestures',
                  value: settings.volumeGestures,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(volumeGestures: val)),
                ),
                const Divider(color: Colors.white10, height: 1),
                _buildSwitch(
                  theme: theme,
                  title: 'Horizontal swipe to seek',
                  value: settings.horizontalSwipeToSeek,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(horizontalSwipeToSeek: val)),
                ),
                const Divider(color: Colors.white10, height: 1),
                _buildSwitch(
                  theme: theme,
                  title: 'Pinch to zoom',
                  value: settings.pinchToZoom,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(pinchToZoom: val)),
                ),
                const Divider(color: Colors.white10, height: 1),
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
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Audio'),
          Card(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: Column(
              children: [
                _buildSwitch(
                  theme: theme,
                  title: 'Enable audio pitch correction',
                  subtitle: 'Prevents the audio from becoming high-pitched at faster speeds',
                  value: settings.pitchCorrection,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(pitchCorrection: val)),
                ),
                const Divider(color: Colors.white10, height: 1),
                _buildSwitch(
                  theme: theme,
                  title: 'Volume normalization',
                  subtitle: 'Automatically adjust audio volume to maintain consistent loudness levels',
                  value: settings.volumeNormalization,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(volumeNormalization: val)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildSwitch({
    required ThemeData theme,
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
      activeColor: theme.primaryColor,
      inactiveTrackColor: Colors.white12,
    );
  }

  Widget _buildRadioGroup({
    required ThemeData theme,
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
          activeColor: theme.primaryColor,
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
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
      ),
      title: const Text('Double tap seek duration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_value seconds', style: const TextStyle(color: Colors.white, fontSize: 18)),
          Slider(
            value: _value.toDouble(),
            min: 5,
            max: 30,
            divisions: 5,
            activeColor: theme.primaryColor,
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
          child: Text('Save', style: TextStyle(color: theme.primaryColor)),
        ),
      ],
    );
  }
}
