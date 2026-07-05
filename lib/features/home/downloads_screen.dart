import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../../core/theme/app_theme.dart';
import '../player/pip_manager.dart';
import '../settings/settings_provider.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const DownloadsScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

final fileSizesProvider = FutureProvider.autoDispose<Map<int, int>>((ref) async {
  final tasks = ref.watch(downloadControllerProvider);
  final completed = tasks.entries.where((e) => e.value.isCompleted && e.value.localPath != null).toList();
  final Map<int, int> sizes = {};
  await Future.wait(completed.map((entry) async {
    try {
      final f = File(entry.value.localPath!);
      if (await f.exists()) {
        sizes[entry.key] = await f.length();
      }
    } catch (_) {}
  }));
  return sizes;
});

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
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

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }

  Future<void> _deleteDownload(int fileId, String path, String title) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
        ),
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "$title" from your device? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
    final settings = ref.watch(videoSettingsProvider);
    final fileSizesAsync = ref.watch(fileSizesProvider);
    final fileSizes = fileSizesAsync.value ?? {};

    // Filter tasks
    final activeDownloadsRaw = downloadTasks.entries
        .where((entry) => !entry.value.isCompleted)
        .toList();

    final activeDownloadsOrder = ref.read(storageServiceProvider).getActiveDownloadsOrder();
    final List<MapEntry<int, DownloadTask>> activeDownloads = activeDownloadsRaw.toList()
      ..sort((a, b) {
        final indexA = activeDownloadsOrder.indexOf(a.key);
        final indexB = activeDownloadsOrder.indexOf(b.key);
        if (indexA == -1 && indexB == -1) return 0;
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });
    
    final completedDownloads = downloadTasks.entries
        .where((entry) => entry.value.isCompleted && entry.value.localPath != null)
        .toList();

    // Calculate completed sizes
    int totalBytes = 0;
    final List<MapEntry<int, DownloadTask>> filteredCompletedList = [];

    for (final entry in completedDownloads) {
      int size = fileSizes[entry.key] ?? 0;
      totalBytes += size;

      if (_query.isEmpty || entry.value.title.toLowerCase().contains(_query.toLowerCase())) {
        filteredCompletedList.add(entry);
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Downloads Manager',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: settingsAccent,
          labelColor: settingsAccent,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          tabs: const [
            Tab(text: 'Active / Queue'),
            Tab(text: 'Downloaded'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: ACTIVE DOWNLOADS
          Column(
            children: [
              // Download Scheduler Config Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, color: settingsAccent),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Download Scheduler',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Restrict downloads to off-peak hours',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: settings.downloadSchedulerEnabled,
                          onChanged: (val) {
                            ref.read(videoSettingsProvider.notifier).updateSettings(
                              settings.copyWith(downloadSchedulerEnabled: val),
                            );
                            ref.read(downloadControllerProvider.notifier).checkScheduler();
                          },
                          activeThumbColor: settingsAccent,
                        ),
                      ],
                    ),
                    if (settings.downloadSchedulerEnabled) ...[
                      const SizedBox(height: 16),
                      Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), height: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Time',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  initialValue: settings.downloadStartHour,
                                  dropdownColor: theme.cardColor,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: List.generate(24, (index) {
                                    return DropdownMenuItem(
                                      value: index,
                                      child: Text(_formatHour(index), style: const TextStyle(fontSize: 13)),
                                    );
                                  }),
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref.read(videoSettingsProvider.notifier).updateSettings(
                                        settings.copyWith(downloadStartHour: val),
                                      );
                                      ref.read(downloadControllerProvider.notifier).checkScheduler();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Time',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  initialValue: settings.downloadEndHour,
                                  dropdownColor: theme.cardColor,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: List.generate(24, (index) {
                                    return DropdownMenuItem(
                                      value: index,
                                      child: Text(_formatHour(index), style: const TextStyle(fontSize: 13)),
                                    );
                                  }),
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref.read(videoSettingsProvider.notifier).updateSettings(
                                        settings.copyWith(downloadEndHour: val),
                                      );
                                      ref.read(downloadControllerProvider.notifier).checkScheduler();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: activeDownloads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.downloading_rounded,
                              size: 72,
                              color: settingsAccent.withValues(alpha: 0.24),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No active downloads',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Queue some episodes to download them offline',
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: activeDownloads.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          ref.read(downloadControllerProvider.notifier).reorderActiveDownloads(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final entry = activeDownloads[index];
                          final fileId = entry.key;
                          final task = entry.value;

                          return Container(
                            key: ValueKey(fileId),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: task.progress,
                                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    task.isPaused
                                        ? theme.disabledColor
                                        : (task.isScheduled ? theme.disabledColor : settingsAccent),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  minHeight: 6,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '${(task.progress * 100).toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                color: task.isPaused
                                                    ? theme.disabledColor
                                                    : (task.isScheduled ? theme.disabledColor : settingsAccent),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (task.isPaused)
                                              Text(
                                                'Paused',
                                                style: TextStyle(
                                                  color: theme.disabledColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            else if (task.isScheduled)
                                              Text(
                                                'Scheduled (Off-Peak)',
                                                style: TextStyle(
                                                  color: theme.disabledColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            else ...[
                                              Text(
                                                task.speedString,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (!task.isPaused && !task.isScheduled && task.etaString.isNotEmpty && task.etaString != 'Calculating...')
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'ETA: ${task.etaString}',
                                              style: TextStyle(
                                                color: isDark ? Colors.white54 : Colors.black54,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            if (task.isPaused) {
                                              ref.read(downloadControllerProvider.notifier).resumeDownload(fileId);
                                            } else {
                                              ref.read(downloadControllerProvider.notifier).pauseDownload(fileId);
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: settingsAccent.withValues(alpha: 0.12),
                                            foregroundColor: settingsAccent,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: Icon(
                                            task.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            task.isPaused ? 'Resume' : 'Pause',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            ref.read(downloadControllerProvider.notifier).cancelDownload(fileId);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                                            foregroundColor: Colors.redAccent,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Cancel',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // TAB 2: COMPLETED DOWNLOADS
          Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search downloaded episodes...',
                      hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: settingsAccent),
                    ),
                    onChanged: (val) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 250), () {
                        if (mounted) {
                          setState(() {
                            _query = val;
                          });
                        }
                      });
                    },
                  ),
                ),
              ),
              // Disk Space Banner
              if (completedDownloads.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: theme.cardColor.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      Icon(Icons.storage_rounded, size: 16, color: settingsAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Total Offline Storage: ',
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                      ),
                      Text(
                        _formatSize(totalBytes),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${completedDownloads.length} files',
                        style: TextStyle(color: settingsAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: completedDownloads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_done_rounded, size: 72, color: isDark ? Colors.white24 : Colors.black12),
                            const SizedBox(height: 16),
                            Text(
                              'No downloads found',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Episodes you download will appear here offline',
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredCompletedList.isEmpty
                        ? Center(
                            child: Text(
                              'No matching downloads found',
                              style: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredCompletedList.length,
                            itemBuilder: (context, index) {
                              final entry = filteredCompletedList[index];
                              final fileId = entry.key;
                              final task = entry.value;
                              final path = task.localPath!;

                              int fileSize = fileSizes[fileId] ?? 0;

                              final storage = ref.read(storageServiceProvider);
                              final savedPos = storage.getWatchPosition(fileId);
                              final duration = storage.getVideoDuration(fileId);
                              final double progressValue = (duration > 0) ? (savedPos / duration).clamp(0.0, 1.0) : 0.0;
                              final isWatched = progressValue > 0.9;
                              final showProgressBar = progressValue > 0.01 && !isWatched;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: settingsAccent.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.play_arrow_rounded, color: settingsAccent, size: 28),
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
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Row(
                                          children: [
                                            if (isWatched) ...[
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
                                      trailing: Semantics(
                                        label: 'Delete ${task.title}',
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          onPressed: () => _deleteDownload(fileId, path, task.title),
                                        ),
                                      ),
                                      onTap: () {
                                        ref.read(pipControllerProvider.notifier).playVideo(
                                          context,
                                          messageId: fileId,
                                          videoFileId: fileId,
                                          videoTitle: task.title,
                                          seriesName: 'Offline Downloads',
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
        ],
      ),
    );
  }
}
