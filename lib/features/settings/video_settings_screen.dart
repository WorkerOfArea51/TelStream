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
                  title: Text('Gesture Sensitivity', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.gestureSensitivity, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: settings.gestureSensitivity,
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
                        notifier.updateSettings(settings.copyWith(gestureSensitivity: value));
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  title: Text('Long Press Playback Speed', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('${settings.longPressSpeed}x', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: DropdownButton<double>(
                    value: settings.longPressSpeed,
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
                        notifier.updateSettings(settings.copyWith(longPressSpeed: value));
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
                  options: const ['Flutter Text Overlay', 'Native Blending'],
                  currentValue: settings.subtitleRendererMode == 'flutter' ? 'Flutter Text Overlay' : 'Native Blending',
                  onChanged: (val) {
                    final mode = val == 'Flutter Text Overlay' ? 'flutter' : 'native';
                    notifier.updateSettings(settings.copyWith(subtitleRendererMode: mode));
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                _buildRadioGroup(
                  context: context,
                  title: 'Preferred Provider',
                  options: const ['OpenSubtitles v2', 'SubDL'],
                  currentValue: settings.preferredSubtitleProvider == 'subdl' ? 'SubDL' : 'OpenSubtitles v2',
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(
                    preferredSubtitleProvider: val == 'SubDL' ? 'subdl' : 'opensubtitles',
                  )),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('OpenSubtitles API Key', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    settings.openSubtitlesApiKey.isEmpty
                        ? 'Not configured (Search will be public/limited)'
                        : '••••••••${settings.openSubtitlesApiKey.length > 4 ? settings.openSubtitlesApiKey.substring(settings.openSubtitlesApiKey.length - 4) : ""}',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () async {
                    final newKey = await _showTextFieldDialog(
                      context,
                      'OpenSubtitles API Key',
                      'Enter your OpenSubtitles REST API key:',
                      settings.openSubtitlesApiKey,
                    );
                    if (newKey != null) {
                      notifier.updateSettings(settings.copyWith(openSubtitlesApiKey: newKey));
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('SubDL API Key', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    settings.subdlApiKey.isEmpty
                        ? 'Not configured (Required for SubDL search)'
                        : '••••••••${settings.subdlApiKey.length > 4 ? settings.subdlApiKey.substring(settings.subdlApiKey.length - 4) : ""}',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () async {
                    final newKey = await _showTextFieldDialog(
                      context,
                      'SubDL API Key',
                      'Enter your SubDL API key:',
                      settings.subdlApiKey,
                    );
                    if (newKey != null) {
                      notifier.updateSettings(settings.copyWith(subdlApiKey: newKey));
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Subtitle Font Size', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('${settings.subtitleFontSize.toInt()} px', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                  onTap: () async {
                    final newSize = await showDialog<double>(
                      context: context,
                      builder: (context) => _SubtitleSizeDialog(
                        current: settings.subtitleFontSize,
                        currentColor: settings.subtitleColor,
                        currentFont: settings.subtitleFont,
                        accentColor: settingsAccent,
                      ),
                    );
                    if (newSize != null) {
                      notifier.updateSettings(settings.copyWith(subtitleFontSize: newSize));
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
                          color: _parseHexColor(settings.subtitleColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(settings.subtitleColor, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                    ],
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                  onTap: () async {
                    final newColor = await showDialog<String>(
                      context: context,
                      builder: (context) => _SubtitleColorDialog(
                        current: settings.subtitleColor,
                        currentSize: settings.subtitleFontSize,
                        currentFont: settings.subtitleFont,
                        accentColor: settingsAccent,
                      ),
                    );
                    if (newColor != null) {
                      notifier.updateSettings(settings.copyWith(subtitleColor: newColor));
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Subtitle Delay Offset', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                    settings.subtitleDelay == 0.0
                        ? 'No default delay'
                        : settings.subtitleDelay > 0.0
                            ? '+${settings.subtitleDelay.toStringAsFixed(1)}s delay'
                            : '${settings.subtitleDelay.toStringAsFixed(1)}s delay',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
                  onTap: () async {
                    final newDelay = await showDialog<double>(
                      context: context,
                      builder: (context) => _SubtitleDelayDialog(
                        current: settings.subtitleDelay,
                        accentColor: settingsAccent,
                      ),
                    );
                    if (newDelay != null) {
                      notifier.updateSettings(settings.copyWith(subtitleDelay: newDelay));
                    }
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Subtitle Font Family', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text(settings.subtitleFont, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
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
                            trailing: settings.subtitleFont == f ? Icon(Icons.check, color: settingsAccent) : null,
                            onTap: () => Navigator.pop(context, f),
                          )).toList(),
                        ),
                      ),
                    );
                    if (newFont != null) {
                      notifier.updateSettings(settings.copyWith(subtitleFont: newFont));
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

class _SubtitleSizeDialog extends StatefulWidget {
  final double current;
  final String currentColor;
  final String currentFont;
  final Color accentColor;

  const _SubtitleSizeDialog({
    required this.current,
    required this.currentColor,
    required this.currentFont,
    required this.accentColor,
  });

  @override
  State<_SubtitleSizeDialog> createState() => _SubtitleSizeDialogState();
}

class _SubtitleSizeDialogState extends State<_SubtitleSizeDialog> {
  late double _value;

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

  @override
  void initState() {
    super.initState();
    _value = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    String resolvedFontFamily = 'Roboto';
    if (widget.currentFont.toLowerCase().contains('arial')) {
      resolvedFontFamily = 'Arial';
    } else if (widget.currentFont.toLowerCase().contains('dejavu')) {
      resolvedFontFamily = 'DejaVuSans';
    } else if (widget.currentFont.toLowerCase().contains('sans-serif')) {
      resolvedFontFamily = 'sans-serif';
    } else if (widget.currentFont.toLowerCase().contains('roboto')) {
      resolvedFontFamily = 'Roboto';
    }

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
      ),
      title: Text('Subtitle Font Size', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Hello World',
              style: TextStyle(
                fontSize: _value,
                color: _parseHexColor(widget.currentColor),
                fontFamily: resolvedFontFamily,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
                  Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
                  Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
                  Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('${_value.toInt()} px', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18)),
          Slider(
            value: _value,
            min: 15,
            max: 80,
            divisions: 65,
            activeColor: widget.accentColor,
            onChanged: (val) {
              setState(() {
                _value = val;
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

class _SubtitleColorDialog extends StatefulWidget {
  final String current;
  final double currentSize;
  final String currentFont;
  final Color accentColor;

  const _SubtitleColorDialog({
    required this.current,
    required this.currentSize,
    required this.currentFont,
    required this.accentColor,
  });

  @override
  State<_SubtitleColorDialog> createState() => _SubtitleColorDialogState();
}

class _SubtitleColorDialogState extends State<_SubtitleColorDialog> {
  late String _selectedHex;
  final _customController = TextEditingController();

  final List<Map<String, String>> _predefinedColors = [
    {'name': 'White', 'hex': '#FFFFFF'},
    {'name': 'Yellow', 'hex': '#FFFF00'},
    {'name': 'Green', 'hex': '#00FF00'},
    {'name': 'Cyan', 'hex': '#00FFFF'},
    {'name': 'Red', 'hex': '#FF0000'},
    {'name': 'Light Blue', 'hex': '#33B5E5'},
    {'name': 'Amber', 'hex': '#FFBB33'},
  ];

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

  @override
  void initState() {
    super.initState();
    _selectedHex = widget.current.toUpperCase();
    if (!_selectedHex.startsWith('#')) {
      _selectedHex = '#$_selectedHex';
    }
    _customController.text = _selectedHex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    String resolvedFontFamily = 'Roboto';
    if (widget.currentFont.toLowerCase().contains('arial')) {
      resolvedFontFamily = 'Arial';
    } else if (widget.currentFont.toLowerCase().contains('dejavu')) {
      resolvedFontFamily = 'DejaVuSans';
    } else if (widget.currentFont.toLowerCase().contains('sans-serif')) {
      resolvedFontFamily = 'sans-serif';
    } else if (widget.currentFont.toLowerCase().contains('roboto')) {
      resolvedFontFamily = 'Roboto';
    }

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
      ),
      title: Text('Subtitle Color', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              height: 100,
              width: double.maxFinite,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Hello World',
                style: TextStyle(
                  fontSize: widget.currentSize,
                  color: _parseHexColor(_selectedHex),
                  fontFamily: resolvedFontFamily,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
                    Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
                    Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
                    Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _predefinedColors.map((colorMap) {
                final hex = colorMap['hex']!;
                final color = _parseHexColor(hex);
                final isSelected = _selectedHex == hex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedHex = hex;
                      _customController.text = hex;
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? widget.accentColor : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Custom Hex Color',
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                hintText: '#FFFFFF',
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) {
                if (val.startsWith('#') && (val.length == 7 || val.length == 9)) {
                  setState(() {
                    _selectedHex = val.toUpperCase();
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedHex),
          child: Text('Save', style: TextStyle(color: widget.accentColor)),
        ),
      ],
    );
  }
}

class _SubtitleDelayDialog extends StatefulWidget {
  final double current;
  final Color accentColor;

  const _SubtitleDelayDialog({required this.current, required this.accentColor});

  @override
  State<_SubtitleDelayDialog> createState() => _SubtitleDelayDialogState();
}

class _SubtitleDelayDialogState extends State<_SubtitleDelayDialog> {
  late double _value;

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
      ),
      title: Text('Subtitle Delay Offset', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _value == 0.0
                ? 'No Delay'
                : _value > 0.0
                    ? '+${_value.toStringAsFixed(1)} seconds'
                    : '${_value.toStringAsFixed(1)} seconds',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18),
          ),
          Slider(
            value: _value,
            min: -10.0,
            max: 10.0,
            divisions: 200,
            activeColor: widget.accentColor,
            onChanged: (val) {
              setState(() {
                _value = double.parse(val.toStringAsFixed(1));
              });
            },
          ),
          Text(
            'Positive: Subtitles appear later\nNegative: Subtitles appear earlier',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11),
            textAlign: TextAlign.center,
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
