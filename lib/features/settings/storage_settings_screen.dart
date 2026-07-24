import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import 'settings_provider.dart';
import '../../core/widgets/m3_animated_menu_tile.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logger.dart';
import '../../core/widgets/expressive_container.dart';
import '../../core/utils/path_helper.dart';
import 'advanced_cache_manager_screen.dart';
import '../../l10n/app_localizations.dart';

int? _cachedWindowsTotalStorage;
int? _cachedWindowsFreeStorage;
DateTime? _lastWindowsStorageCheck;

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
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
        if (_lastWindowsStorageCheck != null && 
            DateTime.now().difference(_lastWindowsStorageCheck!) < const Duration(seconds: 60) &&
            _cachedWindowsTotalStorage != null &&
            _cachedWindowsFreeStorage != null) {
          if (mounted) {
            setState(() {
              _totalStorageRaw = _cachedWindowsTotalStorage!;
              _freeStorageRaw = _cachedWindowsFreeStorage!;
              _totalStorageStr = _formatSizeString(_cachedWindowsTotalStorage!);
              _freeStorageStr = _formatSizeString(_cachedWindowsFreeStorage!);
            });
          }
          return;
        }

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
              _cachedWindowsTotalStorage = total;
              _cachedWindowsFreeStorage = free;
              _lastWindowsStorageCheck = DateTime.now();
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
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.storagePermissionRequired),
              backgroundColor: Colors.orange,
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
        await _loadStorageSpace();
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.downloadFolderUpdated} $selectedDirectory'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      Log.e('Failed to select directory', e, stackTrace);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.failedToSelectDirectory} $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _calculateCacheSize() async {
    if (!mounted) return;

    try {
      final docDir = await getAppDirectory();

      final int totalBytes = await compute((params) async {
        final docPath = params[0];
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

        return total;
      }, [docDir.path]);

      final storage = ref.read(storageServiceProvider);
      final downloadedFiles = storage.getDownloadedFiles();
      int dlSum = 0;
      final String normalizedDocPath = docDir.path.replaceAll('\\', '/');
      for (final path in downloadedFiles.values) {
        final file = File(path);
        if (file.existsSync()) {
          final normalizedFilePath = path.replaceAll('\\', '/');
          if (normalizedFilePath.startsWith(normalizedDocPath)) {
            dlSum += file.lengthSync();
          }
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
              Text(
                AppLocalizations.of(context)!.deviceStorage,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${AppLocalizations.of(context)!.total} $_totalStorageStr',
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
              _buildLegendItem(AppLocalizations.of(context)!.cache, _cacheSizeStr, settingsAccent),
              _buildLegendItem(AppLocalizations.of(context)!.downloads, _downloadsSizeStr, Colors.green),
              _buildLegendItem(AppLocalizations.of(context)!.freeSpace, _freeStorageStr, Colors.blueAccent),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsBg = customTheme?.settingsBackground ?? theme.scaffoldBackgroundColor;
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(videoSettingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        title: Text(l10n.storageManagement, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
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
              _buildStorageGauge(theme, settingsAccent, isDark),
              const SizedBox(height: 20),
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
                      title: l10n.advancedCacheManager,
                      subtitle: l10n.advancedCacheManagerSubtitle,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdvancedCacheManagerScreen()),
                        ).then((_) => _calculateCacheSize());
                      },
                    ),
                    Divider(color: theme.dividerColor, height: 1, indent: 56, endIndent: 16),
                    ListTile(
                      leading: Material3ExpressiveContainer(
                        shape: ExpressiveShape.squircle,
                        size: 38,
                        activeColor: theme.primaryColor,
                        isSelected: true,
                        child: const Icon(Icons.disc_full_rounded, color: Colors.white, size: 20),
                      ),
                      title: Text(l10n.cacheSizeLimit),
                      trailing: DropdownButton<int>(
                        value: settings.cache.cacheLimitMb,
                        dropdownColor: theme.cardColor,
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                        items: [
                          const DropdownMenuItem(value: 1024, child: Text('1 GB')),
                          const DropdownMenuItem(value: 2048, child: Text('2 GB')),
                          const DropdownMenuItem(value: 5120, child: Text('5 GB')),
                          DropdownMenuItem(value: -1, child: Text(l10n.unlimited)),
                        ],
                        onChanged: (int? value) {
                          if (value != null) {
                            ref.read(videoSettingsProvider.notifier).updateSettings(
                              settings.copyWith(cache: settings.cache.copyWith(cacheLimitMb: value))
                            );
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
                        child: const Icon(Icons.hourglass_empty_rounded, color: Colors.white, size: 20),
                      ),
                      title: Text(l10n.cacheAutoDeleteTTL),
                      trailing: DropdownButton<int>(
                        value: settings.cache.cacheTtlDays,
                        dropdownColor: theme.cardColor,
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
                        items: [
                          const DropdownMenuItem(value: 3, child: Text('3 Days')),
                          const DropdownMenuItem(value: 7, child: Text('7 Days')),
                          const DropdownMenuItem(value: 14, child: Text('14 Days')),
                          DropdownMenuItem(value: -1, child: Text(l10n.never)),
                        ],
                        onChanged: (int? value) {
                          if (value != null) {
                            ref.read(videoSettingsProvider.notifier).updateSettings(
                              settings.copyWith(cache: settings.cache.copyWith(cacheTtlDays: value))
                            );
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
                        child: const Icon(Icons.folder_rounded, color: Colors.white, size: 20),
                      ),
                      title: Text(l10n.downloadFolder),
                      subtitle: Text(_downloadPath, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
                      trailing: FilledButton.tonal(
                        onPressed: _selectDownloadDirectory,
                        child: Text(l10n.chooseCustomFolder),
                      ),
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
