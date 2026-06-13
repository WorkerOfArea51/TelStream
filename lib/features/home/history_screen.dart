import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../services/storage_service.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import '../player/pip_manager.dart';
import 'home_controller.dart';
import '../../models/anime_models.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyLogs = ref.watch(historyLogProvider);
    
    final animeList = ref.watch(animeControllerProvider).value ?? [];
    final moviesList = ref.watch(moviesControllerProvider).value ?? [];
    final webSeriesList = ref.watch(webSeriesControllerProvider).value ?? [];
    
    final allSeries = [...animeList, ...moviesList, ...webSeriesList];

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          if (historyLogs.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep, color: theme.primaryColor),
              onPressed: () => _confirmClearHistory(context, ref),
            ),
        ],
      ),
      body: historyLogs.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: historyLogs.length,
              itemBuilder: (context, index) {
                final log = historyLogs[index];
                
                // Find matching series and episode details
                AnimeSeries? matchedSeries;
                for (var series in allSeries) {
                  if (series.coreName == log['seriesName']) {
                    matchedSeries = series;
                    break;
                  }
                }

                td.Message? episodeMsg;
                td.File? posterFile;
                td.Minithumbnail? minithumbnail;
                int? fileId;
                String epFileName = '';

                if (matchedSeries != null && matchedSeries.seasons.isNotEmpty) {
                  final season = matchedSeries.seasons.first;
                  
                  // Poster file
                  final latestPoster = season.posterMessage;
                  if (latestPoster.content is td.MessagePhoto) {
                    final photo = latestPoster.content as td.MessagePhoto;
                    if (photo.photo.sizes.isNotEmpty) {
                      posterFile = photo.photo.sizes.last.photo;
                    }
                    minithumbnail = photo.photo.minithumbnail;
                  }

                  // Find episode message by index or messageId
                  final epIdx = log['episodeIndex'] as int;
                  if (epIdx >= 0 && epIdx < season.episodes.length) {
                    episodeMsg = season.episodes[epIdx];
                  } else {
                    // Try by messageId
                    final msgId = log['messageId'] as int;
                    for (var ep in season.episodes) {
                      if (ep.id == msgId) {
                        episodeMsg = ep;
                        break;
                      }
                    }
                  }

                  if (episodeMsg != null) {
                    if (episodeMsg.content is td.MessageVideo) {
                      final v = episodeMsg.content as td.MessageVideo;
                      fileId = v.video.video.id;
                      epFileName = v.video.fileName;
                    } else if (episodeMsg.content is td.MessageDocument) {
                      final d = episodeMsg.content as td.MessageDocument;
                      fileId = d.document.document.id;
                      epFileName = d.document.fileName;
                    }
                  }
                }

                final seriesName = matchedSeries != null ? matchedSeries.coreName : log['seriesName'] as String;
                final episodeTitle = log['episodeTitle'] as String;
                final timestamp = log['timestamp'] as int;
                final position = log['position'] as int;

                final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
                final timeAgo = _formatDateTime(dt);

                // Watch progress display (position in seconds -> readable format)
                final progressStr = position > 0 
                    ? 'Watched up to ${_formatDuration(position)}' 
                    : 'Started watching';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 64,
                        child: posterFile != null
                            ? TdThumbnail(file: posterFile, minithumbnail: minithumbnail)
                            : Container(
                                color: theme.primaryColor.withOpacity(0.1),
                                child: Icon(Icons.movie, color: theme.primaryColor, size: 28),
                              ),
                      ),
                    ),
                    title: AlignedNameText(
                      text: seriesName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          episodeTitle,
                          style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$progressStr • $timeAgo',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                      ],
                    ),
                    trailing: fileId != null && episodeMsg != null && matchedSeries != null
                        ? IconButton(
                            icon: Icon(Icons.play_circle_fill, color: theme.primaryColor, size: 32),
                            onPressed: () {
                              ref.read(pipControllerProvider.notifier).playVideo(
                                context,
                                messageId: episodeMsg!.id,
                                videoFileId: fileId!,
                                videoTitle: '$seriesName - ${epFileName.isNotEmpty ? epFileName : episodeTitle}',
                                episodeList: matchedSeries!.seasons.first.episodes,
                                currentEpisodeIndex: log['episodeIndex'] as int,
                                seriesName: seriesName,
                              );
                            },
                          )
                        : const Icon(Icons.play_circle_outline, color: Colors.white24, size: 28),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '(｡•́︿•̀｡)',
            style: TextStyle(fontSize: 48, color: theme.primaryColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'No watch history found',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dt);
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.toString();
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
        ),
        title: const Text('Clear History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to clear your watch history? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(historyLogProvider.notifier).clearHistory();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Watch history cleared'),
                  ),
                );
              }
            },
            child: Text('Clear', style: TextStyle(color: theme.primaryColor)),
          ),
        ],
      ),
    );
  }
}
