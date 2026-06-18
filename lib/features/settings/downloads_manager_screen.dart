import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/download_service.dart';
import '../../core/theme/app_theme.dart';
import 'settings_provider.dart';

class DownloadsManagerScreen extends ConsumerWidget {
  const DownloadsManagerScreen({Key? key}) : super(key: key);

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final settingsBg = customTheme?.settingsBackground ?? theme.scaffoldBackgroundColor;

    final downloadTasks = ref.watch(downloadControllerProvider);
    final activeDownloads = downloadTasks.entries
        .where((entry) => !entry.value.isCompleted)
        .toList();
    final settings = ref.watch(videoSettingsProvider);

    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        title: Text(
          'Active Downloads',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: Column(
        children: [
          // Pre-download Queue Scheduler Config Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24), // M3 rounded corners
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.08),
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
                      activeColor: settingsAccent,
                    ),
                  ],
                ),
                if (settings.downloadSchedulerEnabled) ...[
                  const SizedBox(height: 16),
                  Divider(color: theme.colorScheme.onSurface.withOpacity(0.08), height: 1),
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
                              value: settings.downloadStartHour,
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
                              value: settings.downloadEndHour,
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
                          color: settingsAccent.withOpacity(0.24),
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: activeDownloads.length,
                    itemBuilder: (context, index) {
                      final entry = activeDownloads[index];
                      final fileId = entry.key;
                      final task = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24), // M3 rounded corners
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withOpacity(0.08),
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
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                                  onPressed: () {
                                    ref.read(downloadControllerProvider.notifier).cancelDownload(fileId);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: task.progress,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                task.isScheduled ? theme.disabledColor : settingsAccent,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 6,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(task.progress * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: task.isScheduled ? theme.disabledColor : settingsAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (task.isScheduled) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.disabledColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Scheduled (Off-Peak)',
                                          style: TextStyle(
                                            color: isDark ? Colors.white60 : Colors.black54,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        task.speedString,
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (task.etaString.isNotEmpty && task.etaString != 'Calculating...') ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white30 : Colors.black26,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          task.etaString,
                                          style: TextStyle(
                                            color: isDark ? Colors.white54 : Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
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
    );
  }
}
