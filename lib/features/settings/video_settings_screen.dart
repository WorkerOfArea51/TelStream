import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';

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
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Auto skip intros & outros',
                  subtitle: 'Automatically skip openings and endings when detected',
                  value: settings.autoSkipIntroOutro,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(autoSkipIntroOutro: val)),
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
                  title: Text('Double Tap Gesture Action', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.doubleTapAction, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: settings.doubleTapAction,
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: const [
                      DropdownMenuItem(value: 'Seek', child: Text('Fast Forward/Rewind')),
                      DropdownMenuItem(value: 'Play/Pause', child: Text('Play/Pause')),
                      DropdownMenuItem(value: 'None', child: Text('None')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        notifier.updateSettings(settings.copyWith(doubleTapAction: value));
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
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, 'Subtitles & Acceleration'),
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
                  title: 'Use System Fonts (Android)',
                  subtitle: 'Enables system font provider (e.g. Arial, fallback glyphs) for subtitle rendering. Recommended to fix missing/invisible subtitles.',
                  value: ref.watch(storageServiceProvider).getSubtitleSystemFonts(),
                  onChanged: (val) async {
                    await ref.read(storageServiceProvider).setSubtitleSystemFonts(val);
                    (context as Element).markNeedsBuild();
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Subtitle Renderer', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    ref.watch(storageServiceProvider).getSubtitleRenderer() == "flutter"
                        ? 'Flutter (Highly compatible, recommended on Android)'
                        : 'Native libass (Supports stylized typesetting)',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: ref.watch(storageServiceProvider).getSubtitleRenderer(),
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: const [
                      DropdownMenuItem(value: 'flutter', child: Text('Flutter (Compatible)')),
                      DropdownMenuItem(value: 'native', child: Text('Native (libass)')),
                    ],
                    onChanged: (String? value) async {
                      if (value != null) {
                        await ref.read(storageServiceProvider).setSubtitleRenderer(value);
                        (context as Element).markNeedsBuild();
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Hardware Acceleration',
                  subtitle: 'Enable GPU-accelerated video decoding. Disable this if subtitles do not display or if you experience rendering glitches on Android.',
                  value: ref.watch(storageServiceProvider).getHardwareAcceleration(),
                  onChanged: (val) async {
                    await ref.read(storageServiceProvider).setHardwareAcceleration(val);
                    (context as Element).markNeedsBuild();
                  },
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
                          side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
                        ),
                        title: Text('Smart Outro Threshold', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        content: StatefulBuilder(
                          builder: (context, setDialogState) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Show the next episode autoplay prompt at:', style: TextStyle(fontSize: 13, color: Colors.white70)),
                                const SizedBox(height: 12),
                                DropdownButton<int>(
                                  value: current,
                                  dropdownColor: theme.cardColor,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  isExpanded: true,
                                  items: const [
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
        ...options.map((option) => RadioListTile<String>(
          title: Text(option, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          value: option,
          groupValue: currentValue,
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
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
