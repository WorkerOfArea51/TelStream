import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../player/pip_manager.dart';
import 'settings_provider.dart';
import '../../core/widgets/m3_animated_menu_tile.dart';
import 'video_settings_screen.dart';
import 'advanced_cache_manager_screen.dart';
import 'tracker_settings_screen.dart';
import 'diagnostics_screen.dart';
import 'backup_manager_screen.dart';
import '../../core/widgets/whats_new_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logger.dart';
import '../../core/utils/path_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _downloadPath = "Default (App Private)";

  int _cacheSizeRaw = 0;
  int _downloadsSizeRaw = 0;
  String _cacheSizeStr = "0.0 MB";
  String _downloadsSizeStr = "0.0 MB";

  int _totalStorageRaw = 128 * 1024 * 1024 * 1024;
  int _freeStorageRaw = 45 * 1024 * 1024 * 1024;
  String _totalStorageStr = "128 GB";
  String _freeStorageStr = "45 GB";

  static const _updaterChannel = MethodChannel('com.darkmatter.telstream/updater');

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
    _loadDownloadPath();
    _loadStorageSpace();
  }

  Future<void> _loadStorageSpace() async {
    try {
      if (Platform.isAndroid) {
        final Map<dynamic, dynamic>? res = await _updaterChannel.invokeMethod('getStorageSpace');
        if (res != null) {
          final total = res['total'] as int;
          final free = res['free'] as int;
          if (mounted) {
            setState(() {
              _totalStorageRaw = total;
              _freeStorageRaw = free;
              _totalStorageStr = _formatSizeString(total);
              _freeStorageStr = _formatSizeString(free);
            });
          }
        }
      } else if (Platform.isWindows) {
        final customPath = ref.read(storageServiceProvider).getCustomDownloadDirectory();
        String path = customPath ?? '';
        if (path.isEmpty) {
          final appDir = await getAppDirectory();
          path = appDir.path;
        }
        String driveLetter = 'C';
        final driveMatch = RegExp(r'^([a-zA-Z]):').firstMatch(path);
        if (driveMatch != null) {
          driveLetter = driveMatch.group(1)!;
        }

        final res = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Get-Volume -DriveLetter $driveLetter | Select-Object Size, SizeRemaining | ConvertTo-Json'
        ]);
        if (res.exitCode == 0) {
          final data = json.decode(res.stdout);
          if (data is Map) {
            final total = data['Size'] as int? ?? (128 * 1024 * 1024 * 1024);
            final free = data['SizeRemaining'] as int? ?? (45 * 1024 * 1024 * 1024);
            if (mounted) {
              setState(() {
                _totalStorageRaw = total;
                _freeStorageRaw = free;
                _totalStorageStr = _formatSizeString(total);
                _freeStorageStr = _formatSizeString(free);
              });
            }
          }
        }
      }
    } catch (e) {
      Log.w('Failed to get dynamic storage space: $e');
    }
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
        await _loadStorageSpace(); // Re-load storage space for the new drive!
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

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final customPath = ref.read(storageServiceProvider).getCustomDownloadDirectory();

      final int totalBytes = await compute((params) async {
        final docPath = params[0] as String;
        final customPath = params[1];
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
      });
    } catch (e, stackTrace) {
      Log.e('Failed to calculate cache size', e, stackTrace);
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



  Widget _buildStorageGauge(ThemeData theme, Color settingsAccent, bool isDark) {
    final total = _totalStorageRaw.toDouble();
    final free = _freeStorageRaw.toDouble();
    final cache = _cacheSizeRaw.toDouble();
    final downloads = _downloadsSizeRaw.toDouble();
    final other = (total - free - cache - downloads).clamp(0.0, total);

    final double cachePct = cache / total;
    final double downloadsPct = downloads / total;
    final double freePct = free / total;
    final double otherPct = other / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
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
                'Total: $_totalStorageStr',
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
              _buildLegendItem('Free Space', _freeStorageStr, Colors.blueAccent),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Storage Management', style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildStorageGauge(theme, settingsAccent, isDark),
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
                  icon: Icons.cleaning_services,
                  iconColor: Colors.redAccent,
                  title: 'Advanced Cache Manager',
                  subtitle: 'View detailed storage cache breakdown and clear cache per series.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdvancedCacheManagerScreen()),
                    ).then((_) => _calculateCacheSize());
                  },
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
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
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
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
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.folder, color: isDark ? Colors.orangeAccent : Colors.orange),
                  title: const Text('Download Folder'),
                  subtitle: Text(_downloadPath, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
                  trailing: Icon(Icons.folder_open, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                  onTap: _selectDownloadDirectory,
                ),

              ],
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
                Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                ListTile(
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
