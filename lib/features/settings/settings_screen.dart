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

  int _cacheSizeRaw = 0;
  int _downloadsSizeRaw = 0;
  String _cacheSizeStr = "0.0 MB";
  String _downloadsSizeStr = "0.0 MB";

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

      final int totalBytes = await compute((params) async {
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

      // Calculate download sizes
      final storage = ref.read(storageServiceProvider);
      final downloadedFiles = storage.getDownloadedFiles();
      int dlSum = 0;
      for (final path in downloadedFiles.values) {
        final file = File(path);
        if (file.existsSync()) {
          dlSum += file.lengthSync();
        }
      }

      int cacheBytes = totalBytes - dlSum;
      if (cacheBytes < 0) cacheBytes = 0;

      if (!mounted) return;
      setState(() {
        _downloadsSizeRaw = dlSum;
        _cacheSizeRaw = cacheBytes;

        _downloadsSizeStr = _formatSizeString(dlSum);
        _cacheSizeStr = _formatSizeString(cacheBytes);
        
        _cacheSize = _cacheSizeStr;
      });
    } catch (e, stackTrace) {
      Log.e('Failed to calculate cache size', e, stackTrace);
      if (mounted) setState(() => _cacheSize = "Unknown");
    }
  }

  String _formatSizeString(int size) {
    if (size < 1024 * 1024) {
      return "${(size / 1024).toStringAsFixed(1)} KB";
    } else if (size < 1024 * 1024 * 1024) {
      return "${(size / (1024 * 1024)).toStringAsFixed(1)} MB";
    } else {
      return "${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
    }
  }

  void _showTmdbApiKeyDialog() {
    final theme = Theme.of(context);
    final storage = ref.read(storageServiceProvider);
    final controller = TextEditingController(text: storage.getTmdbApiKey() ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
        ),
        title: const Text('TMDB API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your custom TMDB v3 API Key. Leave empty to use the public default key.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'e.g. 829f046ef3294326127b407137f6...',
                hintStyle: TextStyle(color: Colors.white24),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await storage.setTmdbApiKey(controller.text.trim());
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('TMDB API Key updated successfully!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageGauge(ThemeData theme, Color settingsAccent, bool isDark) {
    final total = 128.0 * 1024 * 1024 * 1024;
    final free = 45.0 * 1024 * 1024 * 1024;
    final cache = _cacheSizeRaw.toDouble();
    final downloads = _downloadsSizeRaw.toDouble();
    final other = total - free - cache - downloads;

    final double cachePct = cache / total;
    final double downloadsPct = downloads / total;
    final double freePct = free / total;
    final double otherPct = other / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Device Storage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                'Total: 128 GB',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (cachePct > 0.005)
                    Expanded(
                      flex: (cachePct * 1000).round(),
                      child: Container(color: settingsAccent),
                    ),
                  if (downloadsPct > 0.005)
                    Expanded(
                      flex: (downloadsPct * 1000).round(),
                      child: Container(color: Colors.green),
                    ),
                  if (otherPct > 0.005)
                    Expanded(
                      flex: (otherPct * 1000).round(),
                      child: Container(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                  if (freePct > 0.005)
                    Expanded(
                      flex: (freePct * 1000).round(),
                      child: Container(color: Colors.blueAccent),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('Cache', _cacheSizeStr, settingsAccent),
              _buildLegendItem('Downloads', _downloadsSizeStr, Colors.green),
              _buildLegendItem('Free Space', '45 GB', Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
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
          _buildStorageGauge(theme, settingsAccent, isDark),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          ListTile(
            tileColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.movie_filter_outlined, color: isDark ? Colors.tealAccent : Colors.teal),
            title: const Text('TMDB Custom API Key'),
            subtitle: Text(
              ref.read(storageServiceProvider).getTmdbApiKey()?.isNotEmpty == true
                  ? 'Using Custom API Key'
                  : 'Using System Default Key',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
            ),
            trailing: Icon(Icons.vpn_key, color: isDark ? Colors.white70 : Colors.black54, size: 20),
            onTap: _showTmdbApiKeyDialog,
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
