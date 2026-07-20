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
import 'language_settings_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/expressive_container.dart';
import '../../core/widgets/whats_new_dialog.dart';
import '../../services/storage_service.dart';
import '../home/widgets/telegram_profile_card.dart';
import 'dart:io' show Platform;

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

  Widget _buildSectionHeader(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
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
    final storage = ref.read(storageServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        title: Text(l10n.settings, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Profile card (desktop only)
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
                const TelegramProfileCard(),
                const SizedBox(height: 24),
              ],

              // === STORAGE ===
              _buildSectionHeader(l10n.sectionStorage, settingsAccent),
              _buildSectionCard(
                theme: theme,
                children: [
                  M3AnimatedMenuTile(
                    icon: Icons.storage_rounded,
                    title: l10n.storageManagement,
                    subtitle: l10n.storageSubtitle,
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const StorageSettingsScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // === PLAYBACK ===
              _buildSectionHeader(l10n.sectionPlayback, settingsAccent),
              _buildSectionCard(
                theme: theme,
                children: [
                  M3AnimatedMenuTile(
                    icon: Icons.video_settings,
                    title: l10n.videoPlayerPreferences,
                    subtitle: l10n.videoPlayerSubtitle,
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const VideoSettingsScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // === GENERAL ===
              _buildSectionHeader(l10n.sectionGeneral, settingsAccent),
              _buildSectionCard(
                theme: theme,
                children: [
                  M3AnimatedMenuTile(
                    icon: Icons.language,
                    title: l10n.language,
                    subtitle: l10n.chooseLanguage,
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LanguageSettingsScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // === APPEARANCE ===
              _buildSectionHeader(l10n.sectionAppearance, settingsAccent),
              _buildSectionCard(
                theme: theme,
                children: [
                  // Theme Mode - SegmentedButton
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
                    title: Text(l10n.themeMode),
                    subtitle: Text(
                      storage.getThemeMode().toUpperCase(),
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
                    ),
                    trailing: DropdownButton<String>(
                      value: () {
                        final mode = storage.getThemeMode();
                        return mode == 'amoled' ? 'dark' : mode;
                      }(),
                      dropdownColor: theme.cardColor,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                      items: [
                        DropdownMenuItem(value: 'system', child: Text(l10n.system)),
                        DropdownMenuItem(value: 'light', child: Text(l10n.light)),
                        DropdownMenuItem(value: 'dark', child: Text(l10n.dark)),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          ref.read(appThemeProvider.notifier).updateThemeMode(value);
                        }
                      },
                    ),
                  ),
                  Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                  // Color Theme - Visual picker
                  ListTile(
                    leading: Material3ExpressiveContainer(
                      shape: ExpressiveShape.squircle,
                      size: 38,
                      activeColor: theme.primaryColor,
                      isSelected: true,
                      child: const Icon(Icons.palette_rounded, color: Colors.white, size: 20),
                    ),
                    title: Text(l10n.colorTheme),
                    subtitle: Text(
                      themeState.activePreset.name,
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show color swatches for each theme
                        ...appThemes.map((preset) {
                          final isSelected = preset.id == themeState.colorThemeId;
                          return GestureDetector(
                            onTap: () => ref.read(appThemeProvider.notifier).updateColorTheme(preset.id),
                            child: Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: preset.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // === TRACKERS ===
              _buildSectionHeader(l10n.sectionIntegrations, settingsAccent),
              _buildSectionCard(
                theme: theme,
                children: [
                  M3AnimatedMenuTile(
                    icon: Icons.sync_alt,
                    title: l10n.trackerAccounts,
                    subtitle: l10n.trackerSubtitle,
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TrackerSettingsScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // === DIAGNOSTICS ===
              _buildSectionHeader(l10n.sectionAdvanced, settingsAccent),
              _buildSectionCard(
                theme: theme,
                children: [
                  M3AnimatedMenuTile(
                    icon: Icons.build_circle_rounded,
                    title: l10n.troubleshootingDiagnostics,
                    subtitle: l10n.troubleshootingSubtitle,
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DiagnosticsScreen())),
                  ),
                  Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                  M3AnimatedMenuTile(
                    icon: Icons.settings_backup_restore_rounded,
                    title: l10n.backupRestore,
                    subtitle: l10n.backupSubtitle,
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BackupManagerScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // === ABOUT ===
              _buildSectionHeader(l10n.sectionAccount, settingsAccent), // Or another string
              _buildSectionCard(
                theme: theme,
                children: [
                  M3AnimatedMenuTile(
                    icon: Icons.history_edu_rounded,
                    title: l10n.whatsNewChangelog,
                    subtitle: l10n.whatsNewSubtitle,
                    onTap: () => WhatsNewDialog.show(context),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // === LOGOUT (separate card) ===
              _buildSectionCard(
                theme: theme,
                children: [
                  M3AnimatedMenuTile(
                    icon: Icons.logout,
                    iconColor: Colors.redAccent,
                    title: l10n.logoutFromTelStream,
                    trailing: const SizedBox.shrink(),
                    onTap: _logout,
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
