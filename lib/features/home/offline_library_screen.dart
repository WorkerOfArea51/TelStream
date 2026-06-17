import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../../core/theme/app_theme.dart';
import '../player/pip_manager.dart';

class OfflineLibraryScreen extends ConsumerStatefulWidget {
  const OfflineLibraryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OfflineLibraryScreen> createState() => _OfflineLibraryScreenState();
}

class _OfflineLibraryScreenState extends ConsumerState<OfflineLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _deleteDownload(int fileId, String path, String title) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
        ),
        title: Text('Delete Episode', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$title" from your device? This cannot be undone.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        final storage = ref.read(storageServiceProvider);
        await storage.removeDownloadedFile(fileId);
        await ref.read(downloadControllerProvider.notifier).reloadDownloads();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete file: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    final downloadTasks = ref.watch(downloadControllerProvider);
    final completedDownloads = downloadTasks.entries
        .where((entry) => entry.value.isCompleted && entry.value.localPath != null)
        .toList();

    int totalBytes = 0;
    final List<MapEntry<int, DownloadTask>> filteredList = [];

    for (final entry in completedDownloads) {
      final path = entry.value.localPath!;
      final file = File(path);
      int size = 0;
      try {
        if (file.existsSync()) {
          size = file.lengthSync();
          totalBytes += size;
        }
      } catch (_) {}

      if (_query.isEmpty || entry.value.title.toLowerCase().contains(_query.toLowerCase())) {
        filteredList.add(entry);
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'True Offline Library',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20), // M3 rounded styling
                border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search offline episodes...',
                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: settingsAccent),
                ),
                onChanged: (val) {
                  setState(() {
                    _query = val;
                  });
                },
              ),
            ),
          ),
        ),
      ),
      body: completedDownloads.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.offline_pin_rounded, size: 72, color: settingsAccent.withOpacity(0.24)),
                  const SizedBox(height: 16),
                  Text(
                    'Your offline library is empty',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Downloaded videos will automatically appear here',
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Disk space banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: settingsAccent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.storage_rounded, size: 16, color: settingsAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Offline Storage: ',
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                      ),
                      Text(
                        _formatSize(totalBytes),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${completedDownloads.length} Episodes',
                        style: TextStyle(color: settingsAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Text(
                            'No matching episodes found',
                            style: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final entry = filteredList[index];
                            final fileId = entry.key;
                            final task = entry.value;
                            final path = task.localPath!;
                            
                            int fileSize = 0;
                            try {
                              fileSize = File(path).lengthSync();
                            } catch (_) {}

                            final storage = ref.read(storageServiceProvider);
                            final savedPos = storage.getWatchPosition(fileId);
                            final duration = storage.getVideoDuration(fileId);
                            final double progressValue = (duration > 0) ? (savedPos / duration).clamp(0.0, 1.0) : 0.0;
                            final isCompleted = progressValue > 0.95;
                            final showProgressBar = progressValue > 0.01 && !isCompleted;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(24), // Premium M3 shape
                                border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: settingsAccent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(Icons.play_arrow_rounded, color: settingsAccent, size: 30),
                                    ),
                                    title: Text(
                                      task.title,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Row(
                                        children: [
                                          if (isCompleted) ...[
                                            const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            _formatSize(fileSize),
                                            style: TextStyle(
                                              color: isDark ? Colors.white54 : Colors.black54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                      onPressed: () => _deleteDownload(fileId, path, task.title),
                                    ),
                                    onTap: () {
                                      // Play local file offline directly
                                      ref.read(pipControllerProvider.notifier).playVideo(
                                        context,
                                        messageId: fileId,
                                        videoFileId: fileId,
                                        videoTitle: task.title,
                                        seriesName: 'Offline Library',
                                        networkUrl: path,
                                      );
                                    },
                                  ),
                                  if (showProgressBar)
                                    LinearProgressIndicator(
                                      value: progressValue,
                                      minHeight: 3,
                                      backgroundColor: Colors.transparent,
                                      valueColor: AlwaysStoppedAnimation<Color>(settingsAccent),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
