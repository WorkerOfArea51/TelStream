import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../pip_manager.dart';
import '../../../services/download_service.dart';

class QueueDialogSheet extends ConsumerWidget {
  final VoidCallback onStartHideTimer;

  const QueueDialogSheet({
    super.key,
    required this.onStartHideTimer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return StatefulBuilder(
      builder: (context, setModalState) {
        final pipState = ref.watch(pipControllerProvider);
        final queue = pipState?.queue ?? [];
        final currentIndex = pipState?.currentIndex;

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        color: settingsAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Play Queue (${queue.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => showAddFromDownloadsDialog(
                          context,
                          ref,
                          setModalState,
                        ),
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                        label: const Text(
                          'Add Downloads',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white60,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onStartHideTimer();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),
              Expanded(
                child: queue.isEmpty
                    ? const Center(
                        child: Text(
                          'Queue is empty',
                          style: TextStyle(color: Colors.white30),
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: queue.length,
                        onReorderItem: (oldIndex, newIndex) {
                          final rawNewIndex = oldIndex < newIndex
                              ? newIndex + 1
                              : newIndex;
                          ref
                              .read(pipControllerProvider.notifier)
                              .reorderQueue(oldIndex, rawNewIndex);
                          setModalState(() {});
                        },
                        itemBuilder: (context, index) {
                          final item = queue[index];
                          final isCurrent = index == currentIndex;

                          return ListTile(
                            key: ValueKey('${item.videoFileId}_$index'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            leading: Icon(
                              isCurrent
                                  ? Icons.play_arrow_rounded
                                  : Icons.drag_handle_rounded,
                              color: isCurrent
                                  ? settingsAccent
                                  : Colors.white38,
                            ),
                            title: Text(
                              item.videoTitle,
                              style: TextStyle(
                                color: isCurrent
                                    ? settingsAccent
                                    : Colors.white,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: item.seriesName.isNotEmpty
                                ? Text(
                                    item.seriesName,
                                    style: TextStyle(
                                      color: isCurrent
                                          ? settingsAccent.withValues(
                                              alpha: 0.7,
                                            )
                                          : Colors.white54,
                                      fontSize: 11,
                                    ),
                                  )
                                : null,
                            trailing: isCurrent
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: settingsAccent.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                    ),
                                    child: Text(
                                      'Playing',
                                      style: TextStyle(
                                        color: settingsAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(
                                            pipControllerProvider.notifier,
                                          )
                                          .removeFromQueue(index);
                                      setModalState(() {});
                                    },
                                  ),
                            onTap: isCurrent
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    ref
                                        .read(
                                          pipControllerProvider.notifier,
                                        )
                                        .playQueueIndex(context, index);
                                  },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void showAddFromDownloadsDialog(
  BuildContext context,
  WidgetRef ref,
  StateSetter setModalState,
) {
  final theme = Theme.of(context);
  final customTheme = theme.extension<AppThemeExtension>();
  final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

  final downloadTasks = ref.read(downloadControllerProvider);
  final completedDownloads = downloadTasks.entries
      .where(
        (entry) => entry.value.isCompleted && entry.value.localPath != null,
      )
      .toList();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.black.withValues(alpha: 0.95),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Completed Downloads',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 16),
            Expanded(
              child: completedDownloads.isEmpty
                  ? const Center(
                      child: Text(
                        'No completed downloads available',
                        style: TextStyle(color: Colors.white30, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: completedDownloads.length,
                      itemBuilder: (context, index) {
                        final entry = completedDownloads[index];
                        final task = entry.value;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: Icon(
                            Icons.download_done_rounded,
                            color: settingsAccent,
                          ),
                          title: Text(
                            task.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(
                            Icons.add_rounded,
                            color: Colors.blueAccent,
                          ),
                          onTap: () {
                            ref
                                .read(pipControllerProvider.notifier)
                                .addToQueue(
                                  PlayQueueItem(
                                    messageId: task.fileId,
                                    videoFileId: task.fileId,
                                    videoTitle: task.title,
                                    seriesName: 'Offline Library',
                                    networkUrl: task.localPath,
                                  ),
                                );
                            Navigator.pop(context);
                            setModalState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added to Queue: ${task.title}',
                                ),
                                backgroundColor: settingsAccent,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}
