import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;

import '../../models/anime_models.dart';
import '../../services/storage_service.dart';
import '../../services/metadata_service.dart';
import '../../services/firebase_metadata_service.dart';
import '../../services/download_service.dart';
import 'desktop_state.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import 'home_controller.dart';

class DesktopSeriesDetailsScreen extends ConsumerStatefulWidget {
  final AnimeSeries series;
  final String categoryTitle;

  const DesktopSeriesDetailsScreen({
    super.key,
    required this.series,
    required this.categoryTitle,
  });

  @override
  ConsumerState<DesktopSeriesDetailsScreen> createState() => _DesktopSeriesDetailsScreenState();
}

class _DesktopSeriesDetailsScreenState extends ConsumerState<DesktopSeriesDetailsScreen> {
  int _selectedSeasonIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMetadata = false;
  SeriesMetadata? _metadata;
  List<String>? _overrideIds;
  final Map<int, SeriesMetadata> _metadataCache = {};

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void didUpdateWidget(covariant DesktopSeriesDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
      if (widget.series.coreName != oldWidget.series.coreName) {
        _selectedSeasonIndex = 0;
        _metadata = null;
        _overrideIds = null;
        _metadataCache.clear();
        _loadMetadata();
      }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _prefetchOtherMetadata(List<String> ids) async {
    final metadataService = MetadataService();
    for (int i = 1; i < ids.length; i++) {
      if (!mounted) break;
      final targetId = ids[i];
      SeriesMetadata? newMeta;
      try {
        if (targetId.startsWith('tt')) {
          newMeta = await metadataService.fetchTmdbByImdbId(targetId);
        } else {
          newMeta = await metadataService.fetchJikanByMalId(targetId);
        }
      } catch (e) {
        debugPrint('Error prefetching metadata on desktop: $e');
      }
      if (mounted && newMeta != null) {
        setState(() {
          _metadataCache[i] = newMeta;
        });
      }
      await Future.delayed(const Duration(milliseconds: 350));
    }
  }

  Future<void> _loadMetadata() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMetadata = true;
    });

    try {
      final overrideId = FirebaseMetadataService.getOverride(widget.series.coreName);
      if (overrideId != null && overrideId.isNotEmpty) {
        final overrideIds = overrideId.split(',');
        _overrideIds = overrideIds;
        final firstId = overrideIds.first;
        final metadataService = MetadataService();
        
        SeriesMetadata? meta;
        if (firstId.startsWith('tt')) {
          meta = await metadataService.fetchTmdbByImdbId(firstId);
        } else {
          meta = await metadataService.fetchJikanByMalId(firstId);
        }
        if (mounted && meta != null) {
          setState(() {
            _metadata = meta;
            _metadataCache[0] = meta;
          });
          if (overrideIds.length > 1) {
            _prefetchOtherMetadata(overrideIds);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMetadata = false;
        });
      }
    }
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

  Widget _buildDetailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationTab() {
    if (_isLoadingMetadata) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_metadata == null) {
      return const Center(
        child: Text(
          'No additional information available.\n(Use the mobile app to link MAL/IMDb)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    final meta = _metadata!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta.synopsis.isNotEmpty) ...[
            const Text(
              'Synopsis',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              meta.synopsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
          if (meta.director.isNotEmpty) _buildDetailRow('Director', meta.director),
          if (meta.writers.isNotEmpty) _buildDetailRow('Writers', meta.writers),
          if (meta.cast.isNotEmpty) _buildDetailRow('Stars', meta.cast),
          if (meta.status.isNotEmpty) _buildDetailRow('Status', meta.status),
          if (meta.runtime.isNotEmpty) _buildDetailRow('Duration', meta.runtime),
          if (meta.episodesCount.isNotEmpty) _buildDetailRow('Episodes', meta.episodesCount),
          if (meta.userScore.isNotEmpty) _buildDetailRow('Score', meta.userScore),
          if (meta.rank.isNotEmpty) _buildDetailRow('Rank', meta.rank),
          if (meta.airedDates.isNotEmpty) _buildDetailRow('Aired', meta.airedDates),
          if (meta.source.isNotEmpty) _buildDetailRow('Source', meta.source),
          if (meta.spokenLanguages.isNotEmpty) _buildDetailRow('Languages', meta.spokenLanguages),
          if (meta.budgetRevenue.isNotEmpty) _buildDetailRow('Financials', meta.budgetRevenue),
          if (meta.productionCompanies.isNotEmpty) _buildDetailRow('Studios', meta.productionCompanies),
        ],
      ),
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

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      if (_metadata != null && _metadata!.airedDates.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _metadata!.airedDates,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
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
          
          const TabBar(
            tabs: [
              Tab(text: 'Episodes'),
              Tab(text: 'Information'),
            ],
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            dividerColor: Colors.transparent,
          ),

          Expanded(
            child: TabBarView(
              children: [
                // Episodes Tab
                Column(
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
                              onChanged: (val) async {
                                if (val != null) {
                                  setState(() => _selectedSeasonIndex = val);
                                  if (_overrideIds != null && _overrideIds!.length > val) {
                                    if (_metadataCache.containsKey(val)) {
                                      setState(() {
                                        _metadata = _metadataCache[val];
                                      });
                                    } else {
                                      // Fallback fetch if it wasn't prefetched fast enough
                                      setState(() => _isLoadingMetadata = true);
                                      final targetId = _overrideIds![val];
                                      final metadataService = MetadataService();
                                      SeriesMetadata? newMeta;
                                      if (targetId.startsWith('tt')) {
                                        newMeta = await metadataService.fetchTmdbByImdbId(targetId);
                                      } else {
                                        newMeta = await metadataService.fetchJikanByMalId(targetId);
                                      }
                                      if (mounted) {
                                        setState(() {
                                          if (newMeta != null) {
                                            _metadataCache[val] = newMeta;
                                            _metadata = newMeta;
                                          }
                                          _isLoadingMetadata = false;
                                        });
                                      }
                                    }
                                  }
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
                  ],
                ),
                
                // Information Tab
                _buildInformationTab(),
              ],
            ),
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
