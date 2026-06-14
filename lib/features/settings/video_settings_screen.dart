import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../core/theme/app_theme.dart';

class VideoSettingsScreen extends ConsumerWidget {
  const VideoSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(videoSettingsProvider);
    final notifier = ref.read(videoSettingsProvider.notifier);

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsBg = customTheme?.settingsBackground ?? theme.scaffoldBackgroundColor;
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        title: Text('Player Preferences', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Player Layout'),
          _buildRadioGroup(
            context: context,
            title: 'Seekbar Style',
            options: const ['Standard', 'Wavy', 'Thick'],
            currentValue: settings.seekbarStyle,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(seekbarStyle: val)),
          ),
          _buildSwitch(
            context: context,
            title: 'Dynamic Speed Overlay',
            subtitle: 'Show advanced overlay for speed control during long press and swipe',
            value: settings.dynamicSpeedOverlay,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(dynamicSpeedOverlay: val)),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(context, 'General'),
          _buildSwitch(
            context: context,
            title: 'Save position on quit',
            value: settings.savePositionOnQuit,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(savePositionOnQuit: val)),
          ),
          _buildSwitch(
            context: context,
            title: 'Autoplay next video',
            subtitle: 'Automatically play next video when current ends',
            value: settings.autoplayNextVideo,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(autoplayNextVideo: val)),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Gestures'),
          _buildSwitch(
            context: context,
            title: 'Brightness gestures',
            value: settings.brightnessGestures,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(brightnessGestures: val)),
          ),
          _buildSwitch(
            context: context,
            title: 'Volume gestures',
            value: settings.volumeGestures,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(volumeGestures: val)),
          ),
          _buildSwitch(
            context: context,
            title: 'Horizontal swipe to seek',
            value: settings.horizontalSwipeToSeek,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(horizontalSwipeToSeek: val)),
          ),
          _buildSwitch(
            context: context,
            title: 'Pinch to zoom',
            value: settings.pinchToZoom,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(pinchToZoom: val)),
          ),
          ListTile(
            title: Text('Double tap seek duration', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('${settings.doubleTapSeekDuration}s', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
            onTap: () async {
              final newDuration = await showDialog<int>(
                context: context,
                builder: (context) => _SeekDurationDialog(current: settings.doubleTapSeekDuration, accentColor: settingsAccent),
              );
              if (newDuration != null) {
                notifier.updateSettings(settings.copyWith(doubleTapSeekDuration: newDuration));
              }
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Audio'),
          _buildSwitch(
            context: context,
            title: 'Enable audio pitch correction',
            subtitle: 'Prevents the audio from becoming high-pitched at faster speeds',
            value: settings.pitchCorrection,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(pitchCorrection: val)),
          ),
          _buildSwitch(
            context: context,
            title: 'Volume normalization',
            subtitle: 'Automatically adjust audio volume to maintain consistent loudness levels',
            value: settings.volumeNormalization,
            onChanged: (val) => notifier.updateSettings(settings.copyWith(volumeNormalization: val)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildSwitch({
    required BuildContext context,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    return SwitchListTile(
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)) : null,
      value: value,
      onChanged: onChanged,
      activeColor: settingsAccent,
      inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
    );
  }

  Widget _buildRadioGroup({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ),
        ...options.map((option) => RadioListTile<String>(
          title: Text(option, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          value: option,
          groupValue: currentValue,
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          activeColor: settingsAccent,
        )),
      ],
    );
  }
}

class _SeekDurationDialog extends StatefulWidget {
  final int current;
  final Color accentColor;

  const _SeekDurationDialog({required this.current, required this.accentColor});

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
    final isDark = theme.brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text('Double tap seek duration', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_value seconds', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18)),
          Slider(
            value: _value.toDouble(),
            min: 5,
            max: 30,
            divisions: 5,
            activeColor: widget.accentColor,
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
          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _value),
          child: Text('Save', style: TextStyle(color: widget.accentColor)),
        ),
      ],
    );
  }
}
