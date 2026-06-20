import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';

class VideoSettingsScreen extends ConsumerWidget {
  const VideoSettingsScreen({super.key});

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
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildRadioGroup(
                  context: context,
                  title: 'Seekbar Style',
                  options: const ['Standard', 'Wavy', 'Thick'],
                  currentValue: settings.seekbarStyle,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(seekbarStyle: val)),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Dynamic Speed Overlay',
                  subtitle: 'Show advanced overlay for speed control during long press and swipe',
                  value: settings.dynamicSpeedOverlay,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(dynamicSpeedOverlay: val)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, 'General Settings'),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildSwitch(
                  context: context,
                  title: 'Save position on quit',
                  value: settings.savePositionOnQuit,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(savePositionOnQuit: val)),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Autoplay next video',
                  subtitle: 'Automatically play next video when current ends',
                  value: settings.autoplayNextVideo,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(autoplayNextVideo: val)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, 'Gestures'),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildSwitch(
                  context: context,
                  title: 'Brightness gestures',
                  value: settings.brightnessGestures,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(brightnessGestures: val)),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Volume gestures',
                  value: settings.volumeGestures,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(volumeGestures: val)),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Horizontal swipe to seek',
                  value: settings.horizontalSwipeToSeek,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(horizontalSwipeToSeek: val)),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Pinch to zoom',
                  value: settings.pinchToZoom,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(pinchToZoom: val)),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  title: Text('Left Vertical Swipe Gesture', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.leftSwipeGesture, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: settings.leftSwipeGesture,
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: const [
                      DropdownMenuItem(value: 'Brightness', child: Text('Brightness')),
                      DropdownMenuItem(value: 'Volume', child: Text('Volume')),
                      DropdownMenuItem(value: 'Speed', child: Text('Playback Speed')),
                      DropdownMenuItem(value: 'None', child: Text('None')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        notifier.updateSettings(settings.copyWith(leftSwipeGesture: value));
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  title: Text('Right Vertical Swipe Gesture', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.rightSwipeGesture, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: settings.rightSwipeGesture,
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: const [
                      DropdownMenuItem(value: 'Brightness', child: Text('Brightness')),
                      DropdownMenuItem(value: 'Volume', child: Text('Volume')),
                      DropdownMenuItem(value: 'Speed', child: Text('Playback Speed')),
                      DropdownMenuItem(value: 'None', child: Text('None')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        notifier.updateSettings(settings.copyWith(rightSwipeGesture: value));
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  title: Text('Double tap seek duration', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('${settings.doubleTapSeekDuration}s', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
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
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, 'Audio'),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildSwitch(
                  context: context,
                  title: 'Enable audio pitch correction',
                  subtitle: 'Prevents the audio from becoming high-pitched at faster speeds',
                  value: settings.pitchCorrection,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(pitchCorrection: val)),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Volume normalization',
                  subtitle: 'Automatically adjust audio volume to maintain consistent loudness levels',
                  value: settings.volumeNormalization,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(volumeNormalization: val)),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: '200% Volume Boost Limit',
                  subtitle: 'Allows dynamic audio amplification up to 200% via player controls and swipe gestures',
                  value: ref.watch(storageServiceProvider).getVolumeBoostEnabled(),
                  onChanged: (val) async {
                    await ref.read(storageServiceProvider).setVolumeBoostEnabled(val);
                    (context as Element).markNeedsBuild();
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Dynamic Range Compression (DRC)',
                  subtitle: 'Balance music and dialogue levels to prevent sudden volume spikes',
                  value: settings.dynamicRangeCompression,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(dynamicRangeCompression: val)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, 'Subtitles'),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildRadioGroup(
                  context: context,
                  title: 'Subtitle Renderer Mode',
                  options: const ['Native Blending', 'Flutter Text Overlay'],
                  currentValue: settings.subtitleRendererMode == 'flutter' ? 'Flutter Text Overlay' : 'Native Blending',
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(subtitleRendererMode: val == 'Flutter Text Overlay' ? 'flutter' : 'native')),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, 'Smart Playback & Streaming'),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  title: Text('Smart Outro Trigger Threshold', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    '${ref.watch(storageServiceProvider).getVideoSettings()["outro_threshold_seconds"] as int? ?? 45} seconds before end',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                  onTap: () async {
                    final current = ref.read(storageServiceProvider).getVideoSettings()["outro_threshold_seconds"] as int? ?? 45;
                    final newValue = await showDialog<int>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
                        ),
                        title: Text('Smart Outro Threshold', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        content: StatefulBuilder(
                          builder: (context, setDialogState) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Show the next episode autoplay prompt at:', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                                const SizedBox(height: 12),
                                DropdownButton<int>(
                                  value: current,
                                  dropdownColor: theme.cardColor,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 5, child: Text('5 Seconds before end')),
                                    DropdownMenuItem(value: 10, child: Text('10 Seconds before end')),
                                    DropdownMenuItem(value: 15, child: Text('15 Seconds before end')),
                                    DropdownMenuItem(value: 30, child: Text('30 Seconds before end')),
                                    DropdownMenuItem(value: 45, child: Text('45 Seconds before end')),
                                    DropdownMenuItem(value: 60, child: Text('60 Seconds before end')),
                                    DropdownMenuItem(value: 90, child: Text('90 Seconds before end')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      Navigator.pop(context, val);
                                    }
                                  },
                                ),
                              ],
                            );
                          }
                        ),
                      ),
                    );
                    if (newValue != null) {
                      final newMap = Map<String, dynamic>.from(ref.read(storageServiceProvider).getVideoSettings());
                      newMap["outro_threshold_seconds"] = newValue;
                      await ref.read(storageServiceProvider).updateVideoSettings(newMap);
                      (context as Element).markNeedsBuild();
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Adaptive Streaming Profile', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    settings.streamingProfile == 'Aggressive Buffer'
                        ? 'Aggressive Buffer (500MB buffer limit, 180s prefetch)'
                        : settings.streamingProfile == 'Mobile Saver'
                            ? 'Mobile Saver (40MB buffer limit, 45s prefetch)'
                            : 'Balanced (150MB buffer limit, 90s prefetch)',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.streamingProfile,
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: const [
                      DropdownMenuItem(value: 'Aggressive Buffer', child: Text('Aggressive Buffer')),
                      DropdownMenuItem(value: 'Balanced', child: Text('Balanced')),
                      DropdownMenuItem(value: 'Mobile Saver', child: Text('Mobile Saver')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        notifier.updateSettings(settings.copyWith(streamingProfile: value));
                      }
                    },
                  ),
                ),
              ],
            ),
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
    final isDark = theme.brightness == Brightness.dark;
    return SwitchListTile(
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)) : null,
      value: value,
      onChanged: onChanged,
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
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
        ),
        RadioGroup<String>(
          groupValue: currentValue,
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          child: Column(
            children: options.map((option) => RadioListTile<String>(
              title: Text(option, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              value: option,
            )).toList(),
          ),
        ),
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
