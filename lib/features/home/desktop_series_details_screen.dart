import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;

import '../../models/anime_models.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import 'desktop_state.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import 'home_controller.dart';
import '../player/pip_manager.dart';

class DesktopSeriesDetailsScreen extends ConsumerStatefulWidget {
  final AnimeSeries series;
  final String categoryTitle;
  final VoidCallback onBack;

  const DesktopSeriesDetailsScreen({
    super.key,
    required this.series,
    required this.categoryTitle,
    required this.onBack,
  });

  @override
  ConsumerState<DesktopSeriesDetailsScreen> createState() => _DesktopSeriesDetailsScreenState();
}

class _DesktopSeriesDetailsScreenState extends ConsumerState<DesktopSeriesDetailsScreen> {
  int _selectedSeasonIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant DesktopSeriesDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
      if (widget.series.coreName != oldWidget.series.coreName) {
        _selectedSeasonIndex = 0;
      }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  void _playEpisode(BuildContext context, td.Message episode, int index) {
    ref.read(desktopSelectedEpisodeProvider.notifier).state = episode;
    
    // Add to history
    final fileTitle = HomeController.getMessageFileName(episode);
    int videoId = 0;
    if (episode.content is td.MessageVideo) {
      videoId = (episode.content as td.MessageVideo).video.video.id;
    } else if (episode.content is td.MessageDocument) {
      videoId = (episode.content as td.MessageDocument).document.document.id;
    }

    ref.read(historyLogProvider.notifier).addToHistory(
      messageId: episode.id,
      seriesName: widget.series.coreName,
      episodeTitle: fileTitle,
      episodeIndex: index,
      positionInSeconds: 0,
      videoFileId: videoId,
    );
    
    // Trigger video playback on Desktop
    ref.read(pipControllerProvider.notifier).playVideo(
      context,
      messageId: episode.id,
      videoFileId: videoId,
      videoTitle: fileTitle,
      episodeList: widget.series.seasons[_selectedSeasonIndex].episodes,
      currentEpisodeIndex: index,
      seriesName: widget.series.coreName,
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final season = widget.series.seasons.isNotEmpty ? widget.series.seasons[_selectedSeasonIndex] : null;
    final episodes = season?.episodes ?? [];
    final history = ref.watch(historyLogProvider);
    final storage = ref.watch(storageServiceProvider);

    final watchedIds = history.map((e) => e['messageId'] as int).toSet();
    final isFavorite = storage.isFavorite(widget.series.coreName);

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AlignedNameText(
                        text: widget.series.coreName,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      storage.toggleFavorite(widget.series.coreName);
                    });
                  },
                  tooltip: 'Favorite',
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
                  children: [
                    if (widget.series.seasons.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        alignment: Alignment.centerLeft,
                        child: DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: DropdownButton<int>(
                              value: _selectedSeasonIndex,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              dropdownColor: theme.colorScheme.surface,
                              items: List.generate(
                                widget.series.seasons.length,
                                (index) => DropdownMenuItem(
                                  value: index,
                                  child: Text(
                                    'Season ${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedSeasonIndex = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ),

                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: episodes.length,
                        itemBuilder: (context, index) {
                          final episode = episodes[index];
                          final isWatched = watchedIds.contains(episode.id);
                          
                          double progress = 0;
                          if (isWatched) {
                            try {
                              final histItem = history.firstWhere((e) => e['messageId'] == episode.id);
                              final pos = histItem['position'] as int;
                              final dur = storage.getVideoDuration(episode.id);
                              if (dur > 0) progress = pos / dur;
                            } catch (_) {}
                          }

                          return _DesktopEpisodeItem(
                            episode: episode,
                            index: index,
                            isWatched: isWatched,
                            progress: progress,
                            onTap: () => _playEpisode(context, episode, index),
                          );
                        },
                      ),
                    ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopEpisodeItem extends ConsumerStatefulWidget {
  final td.Message episode;
  final int index;
  final bool isWatched;
  final double progress;
  final VoidCallback onTap;

  const _DesktopEpisodeItem({
    required this.episode,
    required this.index,
    required this.isWatched,
    required this.progress,
    required this.onTap,
  });

  @override
  ConsumerState<_DesktopEpisodeItem> createState() => _DesktopEpisodeItemState();
}

class _DesktopEpisodeItemState extends ConsumerState<_DesktopEpisodeItem> {
  bool _isHovered = false;

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    td.File? file;
    td.Minithumbnail? mini;
    int size = 0;
    int? fileId;
    
    if (widget.episode.content is td.MessageVideo) {
      final video = widget.episode.content as td.MessageVideo;
      file = video.video.thumbnail?.file;
      mini = video.video.minithumbnail;
      size = video.video.video.expectedSize;
      fileId = video.video.video.id;
    } else if (widget.episode.content is td.MessageDocument) {
      final doc = widget.episode.content as td.MessageDocument;
      file = doc.document.thumbnail?.file;
      mini = doc.document.minithumbnail;
      size = doc.document.document.expectedSize;
      fileId = doc.document.document.id;
    }

    String epName = HomeController.getMessageFileName(widget.episode).replaceAll('_', ' ').replaceAll('.mkv', '').replaceAll('.mp4', '');
    if (epName.length > 50) epName = '${epName.substring(0, 47)}...';

    // Download Logic
    final downloadTasks = ref.watch(downloadControllerProvider);
    DownloadTask? task;
    for (final t in downloadTasks.values) {
      if (t.messageId == widget.episode.id || t.fileId == fileId) {
        task = t;
        break;
      }
    }
    
    final isDownloaded = task != null && task.isCompleted && task.localPath != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered ? theme.primaryColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? theme.primaryColor.withOpacity(0.5) : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (file != null)
                        TdThumbnail(
                          file: file,
                          minithumbnail: mini,
                          autoDownload: true,
                          width: 120,
                          height: 68,
                          borderRadius: BorderRadius.zero,
                        )
                      else
                        Container(color: Colors.grey[800], child: const Icon(Icons.movie, color: Colors.white24)),
                      
                      if (widget.isWatched && widget.progress > 0.05)
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: LinearProgressIndicator(
                            value: widget.progress,
                            backgroundColor: Colors.black54,
                            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                            minHeight: 4,
                          ),
                        ),
                      
                      if (_isHovered)
                        Container(
                          color: Colors.black45,
                          child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      epName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.sd_storage_outlined, size: 12, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text(
                          _formatSize(size),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        if (isDownloaded) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.download_done, size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          const Text('Downloaded', style: TextStyle(color: Colors.green, fontSize: 11)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Download Button
              if (fileId != null)
                if (task == null)
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white54, size: 20),
                    onPressed: () {
                      ref.read(downloadControllerProvider.notifier).startDownload(
                        fileId!,
                        epName,
                        messageId: widget.episode.id,
                        chatId: widget.episode.chatId,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Starting download: $epName'), duration: const Duration(seconds: 2)),
                      );
                    },
                    tooltip: 'Download',
                  )
                else if (!isDownloaded)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: task.progress / 100,
                          strokeWidth: 2,
                          color: theme.primaryColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Colors.white),
                        onPressed: () {
                          ref.read(downloadControllerProvider.notifier).cancelDownload(task!.fileId);
                        },
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
