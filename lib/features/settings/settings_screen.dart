import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/permission_service.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../player/pip_manager.dart';
import 'settings_provider.dart';
import 'video_settings_screen.dart';
import '../../core/widgets/whats_new_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logger.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _cacheSize = "Calculating...";
  String _downloadPath = "Default (App Private)";

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
    _loadDownloadPath();
  }

  Future<void> _loadDownloadPath() async {
    final customPath = ref.read(storageServiceProvider).getCustomDownloadDirectory();
    setState(() {
      _downloadPath = customPath ?? "Default (App Private)";
    });
  }

  Future<void> _selectDownloadDirectory() async {
    final permissionGranted = await ref.read(permissionServiceProvider).requestStoragePermission();

    if (!permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to choose a custom downloads folder on this version of Android.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        await ref.read(storageServiceProvider).setCustomDownloadDirectory(selectedDirectory);
        setState(() {
          _downloadPath = selectedDirectory;
        });
        await ref.read(downloadControllerProvider.notifier).reloadDownloads();
        await _calculateCacheSize();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download folder updated to: $selectedDirectory'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      Log.e('Failed to select directory', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select directory: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _calculateCacheSize() async {
    if (!mounted) return;
    setState(() => _cacheSize = "Calculating...");

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final customPath = ref.read(storageServiceProvider).getCustomDownloadDirectory();

      final int size = await compute((params) async {
        final docPath = params[0] as String;
        final customPath = params[1] as String?;
        int total = 0;

        try {
          final docDir = Directory(docPath);
          if (docDir.existsSync()) {
            for (final entity in docDir.listSync(recursive: true, followLinks: false)) {
              if (entity is File) {
                total += entity.lengthSync();
              }
            }
          }
        } catch (_) {}

        if (customPath != null && customPath.isNotEmpty) {
          try {
            final customDir = Directory(customPath);
            if (customDir.existsSync()) {
              for (final entity in customDir.listSync(recursive: true, followLinks: false)) {
                if (entity is File) {
                  total += entity.lengthSync();
                }
              }
            }
          } catch (_) {}
        }
        return total;
      }, [docDir.path, customPath]);

      if (!mounted) return;
      setState(() {
        if (size < 1024 * 1024) {
          _cacheSize = "${(size / 1024).toStringAsFixed(1)} KB";
        } else if (size < 1024 * 1024 * 1024) {
          _cacheSize = "${(size / (1024 * 1024)).toStringAsFixed(1)} MB";
        } else {
          _cacheSize = "${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
        }
      });
    } catch (e, stackTrace) {
      Log.e('Failed to calculate cache size', e, stackTrace);
      if (mounted) setState(() => _cacheSize = "Unknown");
    }
  }

  void _clearCache() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clearing cache (including images)...'), duration: Duration(milliseconds: 800)),
    );

    final storage = ref.read(storageServiceProvider);
    final excludedPaths = storage.getDownloadedFiles().values.toList();

    await ref.read(tdlibServiceProvider).clearVideoCache(includePhotos: true, excludedPaths: excludedPaths);
    await _calculateCacheSize();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared successfully!'), backgroundColor: Colors.green),
    );
  }

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
    final settings = ref.watch(videoSettingsProvider);

    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Storage Management', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.storage, color: isDark ? Colors.white70 : Colors.black54),
            title: const Text('App Cache Size'),
            trailing: Text(_cacheSize, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.cleaning_services, color: Colors.redAccent),
            title: const Text('Clear Cache'),
            subtitle: Text('TelStream caches videos and poster images. Clearing this deletes them and frees up storage.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            onTap: _clearCache,
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.disc_full, color: isDark ? Colors.white70 : Colors.black54),
            title: const Text('Cache Size Limit'),
            trailing: DropdownButton<int>(
              value: settings.cacheLimitMb,
              dropdownColor: theme.cardColor,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
              items: const [
                DropdownMenuItem(value: 1024, child: Text('1 GB')),
                DropdownMenuItem(value: 2048, child: Text('2 GB')),
                DropdownMenuItem(value: 5120, child: Text('5 GB')),
                DropdownMenuItem(value: -1, child: Text('Unlimited')),
              ],
              onChanged: (int? value) {
                if (value != null) {
                  ref.read(videoSettingsProvider.notifier).updateSettings(
                    settings.copyWith(cacheLimitMb: value)
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.hourglass_empty, color: isDark ? Colors.white70 : Colors.black54),
            title: const Text('Cache Auto-Delete TTL'),
            trailing: DropdownButton<int>(
              value: settings.cacheTtlDays,
              dropdownColor: theme.cardColor,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
              items: const [
                DropdownMenuItem(value: 3, child: Text('3 Days')),
                DropdownMenuItem(value: 7, child: Text('7 Days')),
                DropdownMenuItem(value: 14, child: Text('14 Days')),
                DropdownMenuItem(value: -1, child: Text('Never')),
              ],
              onChanged: (int? value) {
                if (value != null) {
                  ref.read(videoSettingsProvider.notifier).updateSettings(
                    settings.copyWith(cacheTtlDays: value)
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.folder, color: isDark ? Colors.orangeAccent : Colors.orange),
            title: const Text('Download Folder'),
            subtitle: Text(_downloadPath, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
            trailing: Icon(Icons.folder_open, color: isDark ? Colors.white70 : Colors.black54, size: 20),
            onTap: _selectDownloadDirectory,
          ),

          const SizedBox(height: 32),
          Text('Playback', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.video_settings, color: isDark ? Colors.white70 : Colors.black54),
            title: const Text('Video Player Preferences'),
            subtitle: Text('Gestures, audio, subtitles, and player UI', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoSettingsScreen()));
            },
          ),
          
          const SizedBox(height: 32),
          Text('Appearance', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(
              themeState.themeMode == ThemeMode.light
                  ? Icons.light_mode
                  : themeState.themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.settings_brightness,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            title: const Text('Theme Mode'),
            subtitle: Text(
              ref.read(storageServiceProvider).getThemeMode().toUpperCase(),
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
            ),
            trailing: DropdownButton<String>(
              value: ref.read(storageServiceProvider).getThemeMode(),
              dropdownColor: theme.cardColor,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('System')),
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
                DropdownMenuItem(value: 'amoled', child: Text('AMOLED Dark')),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  ref.read(appThemeProvider.notifier).updateThemeMode(value);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.palette, color: isDark ? Colors.white70 : Colors.black54),
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
                return DropdownMenuItem(
                  value: preset.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: preset.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(preset.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  ref.read(appThemeProvider.notifier).updateColorTheme(value);
                }
              },
            ),
          ),

          const SizedBox(height: 32),
          Text('Account', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout from TelStream'),
            onTap: _logout,
          ),

          const SizedBox(height: 32),
          Text('Info', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.history_edu_rounded, color: isDark ? Colors.white70 : Colors.black54),
            title: const Text("What's New / Changelog"),
            subtitle: Text("View release notes for this version", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black54),
            onTap: () => WhatsNewDialog.show(context),
          ),
        ],
      ),
    );
  }
}
