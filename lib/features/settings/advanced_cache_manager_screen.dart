import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logger.dart';

class SeriesCacheInfo {
  final String seriesName;
  final int totalSize;
  final int fileCount;
  final List<int> fileIds;

  SeriesCacheInfo({
    required this.seriesName,
    required this.totalSize,
    required this.fileCount,
    required this.fileIds,
  });
}

class AdvancedCacheManagerScreen extends ConsumerStatefulWidget {
  const AdvancedCacheManagerScreen({super.key});

  @override
  ConsumerState<AdvancedCacheManagerScreen> createState() => _AdvancedCacheManagerScreenState();
}

class _AdvancedCacheManagerScreenState extends ConsumerState<AdvancedCacheManagerScreen> {
  bool _isLoading = true;
  List<SeriesCacheInfo> _seriesCache = [];

  int _videosSize = 0;
  int _docsSize = 0;
  int _photosSize = 0;
  int _tempSize = 0;
  int _totalCacheSize = 0;

  @override
  void initState() {
    super.initState();
    _loadAllCacheData();
  }

  Future<void> _loadAllCacheData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final docDir = await getApplicationDocumentsDirectory();
      
      // Calculate directory sizes in the background to avoid locking UI
      final dirSizes = await compute(_getDirSizesIsolate, docDir.path);

      if (mounted) {
        setState(() {
          _videosSize = dirSizes[0];
          _docsSize = dirSizes[1];
          _photosSize = dirSizes[2];
          _tempSize = dirSizes[3];
          _totalCacheSize = _videosSize + _docsSize + _photosSize + _tempSize;
        });
      }

      // Now query TDLib for series details
      final storage = ref.read(storageServiceProvider);
      final tdlib = ref.read(tdlibServiceProvider);
      final seriesFiles = storage.getSeriesFiles(); // Map<String, String>: fileId -> seriesName

      final Map<String, List<int>> grouped = {};
      seriesFiles.forEach((fileIdStr, series) {
        final fileId = int.tryParse(fileIdStr);
        if (fileId != null) {
          grouped.putIfAbsent(series, () => []).add(fileId);
        }
      });

      final List<SeriesCacheInfo> list = [];
      
      for (final entry in grouped.entries) {
        final seriesName = entry.key;
        final fileIds = entry.value;
        int totalSize = 0;
        int cachedCount = 0;

        for (final fid in fileIds) {
          try {
            final res = await tdlib.sendAsync(td.GetFile(fileId: fid)).timeout(const Duration(milliseconds: 1000));
            if (res is td.File) {
              final size = res.local.downloadedSize;
              if (size > 0) {
                totalSize += size;
                cachedCount++;
              }
            }
          } catch (_) {}
        }

        if (totalSize > 0) {
          list.add(SeriesCacheInfo(
            seriesName: seriesName,
            totalSize: totalSize,
            fileCount: cachedCount,
            fileIds: fileIds,
          ));
        }
      }

      // Sort by size descending
      list.sort((a, b) => b.totalSize.compareTo(a.totalSize));

      if (mounted) {
        setState(() {
          _seriesCache = list;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      Log.e('Failed to load advanced cache details', e, stack);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  Future<void> _clearCacheForSeries(SeriesCacheInfo info) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          title: const Text('Clear Series Cache'),
          content: Text('Are you sure you want to clear all cached episodes for "${info.seriesName}"? This will free up ${_formatSize(info.totalSize)}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (confirmed == true) {
      final tdlib = ref.read(tdlibServiceProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clearing cache for: ${info.seriesName}...'), duration: const Duration(seconds: 1)),
        );
      }

      for (final fid in info.fileIds) {
        try {
          await tdlib.sendAsync(td.DeleteFile(fileId: fid));
        } catch (_) {}
      }

      await _loadAllCacheData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _clearAllTemporaryCache() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          title: const Text('Clear All Cache'),
          content: Text('Are you sure you want to clear the entire streaming cache? This will delete all cached videos, temp files, and images, freeing up ${_formatSize(_totalCacheSize)}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear All', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (confirmed == true) {
      final tdlib = ref.read(tdlibServiceProvider);
      final storage = ref.read(storageServiceProvider);
      final excludedPaths = storage.getDownloadedFiles().values.toList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clearing entire cache...'), duration: Duration(seconds: 1)),
        );
      }

      await tdlib.clearVideoCache(includePhotos: true, excludedPaths: excludedPaths);
      await _loadAllCacheData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All cache cleared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _pruneFullyWatchedVideos() async {
    final theme = Theme.of(context);
    final storage = ref.read(storageServiceProvider);
    final historyLogs = storage.getHistoryLog();
    
    // Find all files that are watched >90%
    final List<Map<String, dynamic>> watchedLogsToPrune = [];
    final Set<int> fileIdsToPrune = {};

    for (final log in historyLogs) {
      final messageId = log['messageId'] as int?;
      final fileId = log['videoFileId'] as int?;
      if (messageId != null && fileId != null) {
        final duration = storage.getVideoDuration(messageId);
        final position = storage.getWatchPosition(messageId);
        if (duration > 0 && (position / duration) >= 0.90) {
          watchedLogsToPrune.add(log);
          fileIdsToPrune.add(fileId);
        }
      }
    }

    if (watchedLogsToPrune.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            title: const Text('Prune Watched Videos'),
            content: const Text('No fully watched episodes (>90% progress) were found to prune.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          title: const Text('Prune Watched Videos'),
          content: Text(
            'Are you sure you want to delete local downloads and streaming cache files for the ${watchedLogsToPrune.length} fully watched episodes (>90% progress)?\n\n'
            'This will delete files for:\n'
            '${watchedLogsToPrune.map((l) => '• ${l['seriesName']} - ${l['episodeTitle'] ?? 'Ep ${l['episodeIndex'] + 1}'}').join('\n')}'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Prune', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (confirmed == true) {
      if (mounted) {
        setState(() => _isLoading = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pruning watched videos...'), duration: Duration(seconds: 2)),
        );
      }

      final tdlib = ref.read(tdlibServiceProvider);
      final downloadController = ref.read(downloadControllerProvider.notifier);
      final downloadedFiles = storage.getDownloadedFiles();

      int prunedCount = 0;
      for (final fileId in fileIdsToPrune) {
        try {
          if (downloadedFiles.containsKey(fileId)) {
            await downloadController.deleteDownloadedFile(fileId);
          }
          await tdlib.sendAsync(td.DeleteFile(fileId: fileId));
          await storage.removeSeriesFile(fileId);
          prunedCount++;
        } catch (e) {
          Log.e('Failed to prune fileId $fileId: $e');
        }
      }

      await _loadAllCacheData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully pruned $prunedCount fully watched files.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _clearMetadataCacheAction() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          title: const Text('Clear Metadata Cache'),
          content: const Text('Are you sure you want to clear the cached search IDs and release years? This will force the app to fetch metadata from trackers again next time the catalog is sorted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear Cache', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clearing metadata cache...'), duration: Duration(seconds: 1)),
        );
      }

      await ref.read(storageServiceProvider).clearMetadataCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata cache cleared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _compactDatabaseAction() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          title: const Text('Compact & Defragment Database'),
          content: const Text(
            'This will defragment SQLite indexes and optimize TDLib storage to reclaim empty disk space.\n\n'
            'This action is safe and does not delete your login session or watched history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Optimize Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (confirmed == true) {
      if (mounted) {
        setState(() => _isLoading = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Optimizing & compacting databases...'), duration: Duration(seconds: 2)),
        );
      }

      try {
        await ref.read(tdlibServiceProvider).compactDatabase();
      } catch (e) {
        Log.e('Compaction action failed: $e');
      }

      await _loadAllCacheData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database compacted and defragmented successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsBg = customTheme?.settingsBackground ?? theme.scaffoldBackgroundColor;
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        title: Text(
          'Advanced Cache Manager',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          if (!_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.auto_delete_outlined, color: Colors.orangeAccent),
              tooltip: 'Prune Watched Videos',
              onPressed: _pruneFullyWatchedVideos,
            ),
            if (_totalCacheSize > 0)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                tooltip: 'Clear All Cache',
                onPressed: _clearAllTemporaryCache,
              ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllCacheData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Breakdown Header Card
                  Container(
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
                              'Cache Statistics',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              _formatSize(_totalCacheSize),
                              style: TextStyle(
                                color: settingsAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_totalCacheSize > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 10,
                              width: double.infinity,
                              child: Row(
                                children: [
                                  if (_videosSize > 0)
                                    Expanded(
                                      flex: ((_videosSize / _totalCacheSize) * 1000).round().clamp(1, 1000),
                                      child: Container(color: Colors.orangeAccent),
                                    ),
                                  if (_docsSize > 0)
                                    Expanded(
                                      flex: ((_docsSize / _totalCacheSize) * 1000).round().clamp(1, 1000),
                                      child: Container(color: Colors.blueAccent),
                                    ),
                                  if (_photosSize > 0)
                                    Expanded(
                                      flex: ((_photosSize / _totalCacheSize) * 1000).round().clamp(1, 1000),
                                      child: Container(color: Colors.greenAccent),
                                    ),
                                  if (_tempSize > 0)
                                    Expanded(
                                      flex: ((_tempSize / _totalCacheSize) * 1000).round().clamp(1, 1000),
                                      child: Container(color: Colors.redAccent),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildBreakdownRow('Videos & MKV Streams', _videosSize, Colors.orangeAccent),
                        const SizedBox(height: 10),
                        _buildBreakdownRow('Embedded Subtitles & Docs', _docsSize, Colors.blueAccent),
                        const SizedBox(height: 10),
                        _buildBreakdownRow('Poster Images & Thumbnails', _photosSize, Colors.greenAccent),
                        const SizedBox(height: 10),
                        _buildBreakdownRow('Temporary Cache Buffers', _tempSize, Colors.redAccent),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Metadata & Index Cache',
                    style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: settingsAccent.withValues(alpha: 0.12),
                        child: Icon(Icons.cloud_sync, color: settingsAccent),
                      ),
                      title: const Text(
                        'Clear Metadata Cache',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Clears cached MAL/AniList/Trakt IDs and anime release years, forcing catalog sorting to resync.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                        onPressed: _clearMetadataCacheAction,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Database & Storage Maintenance',
                    style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: settingsAccent.withValues(alpha: 0.12),
                        child: Icon(Icons.storage, color: settingsAccent),
                      ),
                      title: const Text(
                        'Defragment & Compact Database',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Vacuums indices and compacts SQLite storage to reclaim disk space (safe, session-friendly).',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.cleaning_services, color: settingsAccent),
                        onPressed: _compactDatabaseAction,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Cache by Series',
                    style: TextStyle(color: settingsAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  if (_seriesCache.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.movie_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                            const SizedBox(height: 8),
                            Text(
                              'No cached series streams found',
                              style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _seriesCache.length,
                      itemBuilder: (context, index) {
                        final info = _seriesCache[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: settingsAccent.withValues(alpha: 0.12),
                              child: Icon(Icons.video_library_rounded, color: settingsAccent),
                            ),
                            title: Text(
                              info.seriesName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_formatSize(info.totalSize)} • ${info.fileCount} episodes cached',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _clearCacheForSeries(info),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildBreakdownRow(String label, int bytes, Color indicatorColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
        Text(
          _formatSize(bytes),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  static List<int> _getDirSizesIsolate(String docPath) {
    int vSize = 0;
    int dSize = 0;
    int pSize = 0;
    int tSize = 0;

    int getDirSize(String path) {
      int size = 0;
      try {
        final dir = Directory(path);
        if (dir.existsSync()) {
          for (final f in dir.listSync(recursive: true, followLinks: false)) {
            if (f is File) {
              size += f.lengthSync();
            }
          }
        }
      } catch (_) {}
      return size;
    }

    vSize = getDirSize('$docPath/videos');
    dSize = getDirSize('$docPath/documents');
    pSize = getDirSize('$docPath/photos');
    tSize = getDirSize('$docPath/temp');

    return [vSize, dSize, pSize, tSize];
  }
}
