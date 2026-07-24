import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/seek_duration_dialog.dart';
import 'widgets/subtitle_size_dialog.dart';
import 'widgets/subtitle_color_dialog.dart';
import 'widgets/subtitle_delay_dialog.dart';
import 'settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';

class VideoSettingsScreen extends ConsumerStatefulWidget {
  const VideoSettingsScreen({super.key});

  @override
  ConsumerState<VideoSettingsScreen> createState() => _VideoSettingsScreenState();
}

class _VideoSettingsScreenState extends ConsumerState<VideoSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(videoSettingsProvider);
    final notifier = ref.read(videoSettingsProvider.notifier);
    final storage = ref.watch(storageServiceProvider);

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
                  currentValue: settings.layout.seekbarStyle,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(layout: settings.layout.copyWith(seekbarStyle: val))),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Dynamic Speed Overlay',
                  subtitle: 'Show advanced overlay for speed control during long press and swipe',
                  value: settings.layout.dynamicSpeedOverlay,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(layout: settings.layout.copyWith(dynamicSpeedOverlay: val))),
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
                  value: settings.gestures.brightnessGestures,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(gestures: settings.gestures.copyWith(brightnessGestures: val))),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Volume gestures',
                  value: settings.gestures.volumeGestures,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(gestures: settings.gestures.copyWith(volumeGestures: val))),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Horizontal swipe to seek',
                  value: settings.gestures.horizontalSwipeToSeek,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(gestures: settings.gestures.copyWith(horizontalSwipeToSeek: val))),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Pinch to zoom',
                  value: settings.gestures.pinchToZoom,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(gestures: settings.gestures.copyWith(pinchToZoom: val))),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  title: Text('Left Vertical Swipe Gesture', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.gestures.leftSwipeGesture, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: settings.gestures.leftSwipeGesture,
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
                        notifier.updateSettings(settings.copyWith(gestures: settings.gestures.copyWith(leftSwipeGesture: value)));
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  title: Text('Right Vertical Swipe Gesture', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.gestures.rightSwipeGesture, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: settings.gestures.rightSwipeGesture,
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
                        notifier.updateSettings(settings.copyWith(gestures: settings.gestures.copyWith(rightSwipeGesture: value)));
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  title: Text('Gesture Sensitivity', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.gestures.gestureSensitivity, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: settings.gestures.gestureSensitivity,
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: const [
                      DropdownMenuItem(value: 'Low', child: Text('Low (0.5x)')),
                      DropdownMenuItem(value: 'Normal', child: Text('Normal (1.0x)')),
                      DropdownMenuItem(value: 'High', child: Text('High (1.5x)')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        notifier.updateSettings(settings.copyWith(gestures: settings.gestures.copyWith(gestureSensitivity: value)));
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  title: Text('Long Press Playback Speed', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('${settings.gestures.longPressSpeed}x', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<double>(
                    value: settings.gestures.longPressSpeed,
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: const [
                      DropdownMenuItem(value: 1.0, child: Text('1.0x (Disabled)')),
                      DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                      DropdownMenuItem(value: 1.5, child: Text('1.5x (Recommended)')),
                      DropdownMenuItem(value: 1.75, child: Text('1.75x')),
                      DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                      DropdownMenuItem(value: 2.5, child: Text('2.5x')),
                      DropdownMenuItem(value: 3.0, child: Text('3.0x')),
                    ],
                    onChanged: (double? value) {
                      if (value != null) {
                        notifier.updateSettings(settings.copyWith(gestures: settings.gestures.copyWith(longPressSpeed: value)));
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  title: Text('Double tap seek duration', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('${settings.gestures.doubleTapSeekDuration}s', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                  onTap: () async {
                    final newDuration = await showDialog<int>(
                      context: context,
                      builder: (context) => SeekDurationDialog(current: settings.gestures.doubleTapSeekDuration, accentColor: settingsAccent),
                    );
                    if (newDuration != null) {
                      notifier.updateSettings(settings.copyWith(gestures: settings.gestures.copyWith(doubleTapSeekDuration: newDuration)));
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
                  value: settings.audio.pitchCorrection,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(audio: settings.audio.copyWith(pitchCorrection: val))),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildSwitch(
                  context: context,
                  title: 'Volume normalization',
                  subtitle: 'Automatically adjust audio volume to maintain consistent loudness levels',
                  value: settings.audio.volumeNormalization,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(audio: settings.audio.copyWith(volumeNormalization: val))),
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
                  value: settings.audio.dynamicRangeCompression,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(audio: settings.audio.copyWith(dynamicRangeCompression: val))),
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
                  options: const ['Flutter Text Overlay', 'Native Blending'],
                  currentValue: settings.subtitles.subtitleRendererMode == 'flutter' ? 'Flutter Text Overlay' : 'Native Blending',
                  onChanged: (val) {
                    final mode = val == 'Flutter Text Overlay' ? 'flutter' : 'native';
                    notifier.updateSettings(settings.copyWith(subtitles: settings.subtitles.copyWith(subtitleRendererMode: mode)));
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildRadioGroup(
                  context: context,
                  title: 'Preferred Provider',
                  options: const ['OpenSubtitles v2', 'SubDL'],
                  currentValue: settings.subtitles.preferredSubtitleProvider == 'subdl' ? 'SubDL' : 'OpenSubtitles v2',
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(subtitles: settings.subtitles.copyWith(preferredSubtitleProvider: val == 'SubDL' ? 'subdl' : 'opensubtitles'))),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('OpenSubtitles API Key', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    storage.getOpenSubtitlesApiKey().isEmpty
                        ? 'Not configured (Search will be public/limited)'
                        : '••••••••${storage.getOpenSubtitlesApiKey().length > 4 ? storage.getOpenSubtitlesApiKey().substring(storage.getOpenSubtitlesApiKey().length - 4) : ""}',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () async {
                    final newKey = await _showTextFieldDialog(
                      context,
                      'OpenSubtitles API Key',
                      'Enter your OpenSubtitles REST API key:',
                      storage.getOpenSubtitlesApiKey(),
                    );
                    if (newKey != null) {
                      await storage.setOpenSubtitlesApiKey(newKey);
                      setState(() {});
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('SubDL API Key', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    storage.getSubdlApiKey().isEmpty
                        ? 'Not configured (Required for SubDL search)'
                        : '••••••••${storage.getSubdlApiKey().length > 4 ? storage.getSubdlApiKey().substring(storage.getSubdlApiKey().length - 4) : ""}',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () async {
                    final newKey = await _showTextFieldDialog(
                      context,
                      'SubDL API Key',
                      'Enter your SubDL API key:',
                      storage.getSubdlApiKey(),
                    );
                    if (newKey != null) {
                      await storage.setSubdlApiKey(newKey);
                      setState(() {});
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Subtitle Font Size', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('${settings.subtitles.subtitleFontSize.toInt()} px', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                  onTap: () async {
                    final newSize = await showDialog<double>(
                      context: context,
                      builder: (context) => SubtitleSizeDialog(
                        current: settings.subtitles.subtitleFontSize,
                        currentColor: settings.subtitles.subtitleColor,
                        currentFont: settings.subtitles.subtitleFont,
                        accentColor: settingsAccent,
                      ),
                    );
                    if (newSize != null) {
                      notifier.updateSettings(settings.copyWith(subtitles: settings.subtitles.copyWith(subtitleFontSize: newSize)));
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Subtitle Color', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _parseHexColor(settings.subtitles.subtitleColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(settings.subtitles.subtitleColor, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                    ],
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                  onTap: () async {
                    final newColor = await showDialog<String>(
                      context: context,
                      builder: (context) => SubtitleColorDialog(
                        current: settings.subtitles.subtitleColor,
                        currentSize: settings.subtitles.subtitleFontSize,
                        currentFont: settings.subtitles.subtitleFont,
                        accentColor: settingsAccent,
                      ),
                    );
                    if (newColor != null) {
                      notifier.updateSettings(settings.copyWith(subtitles: settings.subtitles.copyWith(subtitleColor: newColor)));
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Subtitle Delay Offset', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    settings.subtitles.subtitleDelay == 0.0
                        ? 'No default delay'
                        : settings.subtitles.subtitleDelay > 0.0
                            ? '+${settings.subtitles.subtitleDelay.toStringAsFixed(1)}s delay'
                            : '${settings.subtitles.subtitleDelay.toStringAsFixed(1)}s delay',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                  onTap: () async {
                    final newDelay = await showDialog<double>(
                      context: context,
                      builder: (context) => SubtitleDelayDialog(
                        current: settings.subtitles.subtitleDelay,
                        accentColor: settingsAccent,
                      ),
                    );
                    if (newDelay != null) {
                      notifier.updateSettings(settings.copyWith(subtitles: settings.subtitles.copyWith(subtitleDelay: newDelay)));
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Subtitle Font Family', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.subtitles.subtitleFont, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                  onTap: () async {
                    final newFont = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
                        ),
                        title: Text('Font Family', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            'Roboto',
                            'Arial',
                            'DejaVuSans',
                            'sans-serif',
                          ].map((f) => ListTile(
                            title: Text(f, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontFamily: f == 'DejaVuSans' ? 'DejaVuSans' : f)),
                            trailing: settings.subtitles.subtitleFont == f ? Icon(Icons.check, color: settingsAccent) : null,
                            onTap: () => Navigator.pop(context, f),
                          )).toList(),
                        ),
                      ),
                    );
                    if (newFont != null) {
                      notifier.updateSettings(settings.copyWith(subtitles: settings.subtitles.copyWith(subtitleFont: newFont)));
                    }
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

          const SizedBox(height: 20),
          _buildSectionHeader(context, 'Downloads'),
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
                  title: Text('Download Speed Limit', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.downloadSpeedLimit, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: settings.downloadSpeedLimit,
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: const [
                      DropdownMenuItem(value: 'Unlimited', child: Text('Unlimited')),
                      DropdownMenuItem(value: '50 KB/s', child: Text('50 KB/s')),
                      DropdownMenuItem(value: '100 KB/s', child: Text('100 KB/s')),
                      DropdownMenuItem(value: '250 KB/s', child: Text('250 KB/s')),
                      DropdownMenuItem(value: '500 KB/s', child: Text('500 KB/s')),
                      DropdownMenuItem(value: '1 MB/s', child: Text('1 MB/s')),
                      DropdownMenuItem(value: '2 MB/s', child: Text('2 MB/s')),
                      DropdownMenuItem(value: '5 MB/s', child: Text('5 MB/s')),
                      DropdownMenuItem(value: '10 MB/s', child: Text('10 MB/s')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        notifier.updateSettings(settings.copyWith(downloadSpeedLimit: value));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, 'Advanced Options'),
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
                  title: Text('Custom MPV Options', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    settings.customMpvOptions.isEmpty
                        ? 'None (e.g. demuxer-max-bytes=100M,speed=1.1)'
                        : settings.customMpvOptions,
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () async {
                    final newVal = await _showTextFieldDialog(
                      context,
                      'Custom MPV Options',
                      'Specify custom startup options passed to MPV (comma-separated):',
                      settings.customMpvOptions,
                    );
                    if (newVal != null) {
                      notifier.updateSettings(settings.copyWith(customMpvOptions: newVal));
                    }
                  },
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

  Color _parseHexColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      } else if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
    } catch (_) {}
    return Colors.white;
  }

  Future<String?> _showTextFieldDialog(
    BuildContext context,
    String title,
    String labelText,
    String initialValue,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
        ),
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(labelText, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Paste key here...',
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Save', style: TextStyle(color: theme.primaryColor)),
          ),
        ],
      ),
    );
  }
}



