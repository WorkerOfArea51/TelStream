import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/m3_animated_menu_tile.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../player/pip_manager.dart';
import 'video_settings_screen.dart';
import 'tracker_settings_screen.dart';
import 'diagnostics_screen.dart';
import 'backup_manager_screen.dart';
import 'storage_settings_screen.dart';
import '../../core/widgets/expressive_container.dart';
import '../../core/widgets/whats_new_dialog.dart';
import '../../services/storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  void _logout() async {
    ref.read(pipControllerProvider.notifier).close();
    ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsBg = customTheme?.settingsBackground ?? theme.scaffoldBackgroundColor;
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    
    final themeState = ref.watch(appThemeProvider);

    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Storage', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: M3AnimatedMenuTile(
              icon: Icons.storage_rounded,
              title: 'Storage Management',
              subtitle: 'Device storage, cache limits, download folder',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StorageSettingsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          Text('Playback', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: M3AnimatedMenuTile(
              icon: Icons.video_settings,
              title: 'Video Player Preferences',
              subtitle: 'Gestures, audio, subtitles, and player UI',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoSettingsScreen()));
              },
            ),
          ),
          
          const SizedBox(height: 24),
          Text('Appearance', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
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
                  leading: Material3ExpressiveContainer(
                    shape: ExpressiveShape.squircle,
                    size: 38,
                    activeColor: theme.primaryColor,
                    isSelected: true,
                    child: Icon(
                      themeState.themeMode == ThemeMode.light
                          ? Icons.light_mode_rounded
                          : themeState.themeMode == ThemeMode.dark
                              ? Icons.dark_mode_rounded
                              : Icons.settings_brightness_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: const Text('Theme Mode'),
                  subtitle: Text(
                    ref.read(storageServiceProvider).getThemeMode().toUpperCase(),
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: () {
                      final mode = ref.read(storageServiceProvider).getThemeMode();
                      return mode == 'amoled' ? 'dark' : mode;
                    }(),
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('System')),
                      DropdownMenuItem(value: 'light', child: Text('Light')),
                      DropdownMenuItem(value: 'dark', child: Text('Dark')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        ref.read(appThemeProvider.notifier).updateThemeMode(value);
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: Material3ExpressiveContainer(
                    shape: ExpressiveShape.squircle,
                    size: 38,
                    activeColor: theme.primaryColor,
                    isSelected: true,
                    child: const Icon(Icons.palette_rounded, color: Colors.white, size: 20),
                  ),
                  title: const Text('Color Theme'),
                  subtitle: Text(
                    themeState.activePreset.name,
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: themeState.colorThemeId,
                    dropdownColor: theme.cardColor,
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                    items: appThemes.map((preset) {
                      return DropdownMenuItem<String>(
                        value: preset.id,
                        child: Text(preset.name),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        ref.read(appThemeProvider.notifier).updateColorTheme(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text('Trackers & Integrations', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: M3AnimatedMenuTile(
              icon: Icons.sync_alt,
              title: 'Tracker Accounts',
              subtitle: 'MyAnimeList, AniList, and Trakt.tv syncing preferences.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrackerSettingsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          Text('Diagnostics & Backups', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
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
                 M3AnimatedMenuTile(
                  icon: Icons.build_circle_rounded,
                  title: 'Troubleshooting & Diagnostics',
                  subtitle: 'Diagnose hardware decoding and subtitle rendering issues.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                    );
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                M3AnimatedMenuTile(
                  icon: Icons.settings_backup_restore_rounded,
                  title: 'Backup & Restore',
                  subtitle: 'Export or import settings and watch history.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BackupManagerScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text('Account & Info', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
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
                M3AnimatedMenuTile(
                  icon: Icons.history_edu_rounded,
                  title: "What's New / Changelog",
                  subtitle: "View release notes for this version",
                  onTap: () => WhatsNewDialog.show(context),
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                M3AnimatedMenuTile(
                  icon: Icons.logout,
                  iconColor: Colors.redAccent,
                  title: 'Logout from TelStream',
                  trailing: const SizedBox.shrink(), // No chevron for logout action
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
