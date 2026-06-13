import 'package:flutter/material.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../models/anime_models.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import '../../core/widgets/wavy_progress_indicators.dart';
import '../player/pip_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';

class EpisodeListScreen extends ConsumerStatefulWidget {
  final AnimeSeason season;
  final AnimeSeries series;
  final String? heroTag;

  const EpisodeListScreen({
    Key? key,
    required this.season,
    required this.series,
    this.heroTag,
  }) : super(key: key);

  @override
  ConsumerState<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends ConsumerState<EpisodeListScreen> {
  late AnimeSeason _selectedSeason;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.season;
  }

  void _toggleFavorite() {
    ref.read(favoritesProvider.notifier).toggleFavorite(widget.series.coreName);
    final isFavNow = ref.read(favoritesProvider).contains(widget.series.coreName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavNow ? 'Added to Favorites!' : 'Removed from Favorites'),
          backgroundColor: isFavNow ? Colors.green : Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(favoritesProvider).contains(widget.series.coreName);
    final effectiveHeroTag = widget.heroTag ?? 'hero_poster_grid_${widget.series.coreName}';

    td.File? posterFile;
    td.Minithumbnail? minithumbnail;
    if (_selectedSeason.posterMessage.content is td.MessagePhoto) {
      final photo = _selectedSeason.posterMessage.content as td.MessagePhoto;
      if (photo.photo.sizes.isNotEmpty) {
        posterFile = photo.photo.sizes.last.photo;
      }
      minithumbnail = photo.photo.minithumbnail;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleFavorite,
        backgroundColor: isFavorite ? Colors.pinkAccent : Colors.white24,
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: Colors.white,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0A1128),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: AlignedNameText(
                text: _selectedSeason.fullTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: effectiveHeroTag,
                    child: TdThumbnail(
                      file: posterFile,
                      minithumbnail: minithumbnail,
                      autoDownload: true,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, const Color(0xFF0A1128)],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.series.seasons.length > 1)
            SliverToBoxAdapter(
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.series.seasons.length,
                  itemBuilder: (context, index) {
                    final season = widget.series.seasons[index];
                    final isSelected = season.seasonName == _selectedSeason.seasonName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(
                          season.seasonName,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.orange,
                        backgroundColor: const Color(0xFF1C1C1E),
                        side: BorderSide(
                          color: isSelected ? Colors.orange : Colors.white12,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedSeason = season;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final msg = _selectedSeason.episodes[index];
                  return _buildEpisodeItem(context, msg, index);
                },
                childCount: _selectedSeason.episodes.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeItem(BuildContext context, td.Message msg, int index) {
    String title = 'Episode ${index + 1}';
    String metadata = '';
    int? fileId;

    if (msg.content is td.MessageVideo) {
      final video = msg.content as td.MessageVideo;
      title = video.video.fileName;
      fileId = video.video.video.id;
      final sizeMb = (video.video.video.expectedSize / 1024 / 1024).toStringAsFixed(1);
      
      final duration = Duration(seconds: video.video.duration);
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      
      metadata = '$minutes:$seconds • $sizeMb MB';
    } else if (msg.content is td.MessageDocument) {
      final doc = msg.content as td.MessageDocument;
      title = doc.document.fileName;
      fileId = doc.document.document.id;
      final sizeMb = (doc.document.document.expectedSize / 1024 / 1024).toStringAsFixed(1);
      metadata = '$sizeMb MB';
    }

    if (fileId == null) return const SizedBox.shrink();

    final downloadTasks = ref.watch(downloadControllerProvider);
    final task = downloadTasks[fileId];

    Widget trailingWidget;
    if (task == null) {
      trailingWidget = IconButton(
        icon: const Icon(Icons.download, color: Colors.orangeAccent, size: 24),
        onPressed: () {
          ref.read(downloadControllerProvider.notifier).startDownload(fileId!, title);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Starting download: $title'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );
    } else if (!task.isCompleted) {
      trailingWidget = GestureDetector(
        onTap: () {
          ref.read(downloadControllerProvider.notifier).cancelDownload(fileId!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download cancelled: $title'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: WavyCircularProgressIndicator(
                  value: task.progress,
                  strokeWidth: 2.5,
                  color: Colors.orange,
                  backgroundColor: Colors.white12,
                ),
              ),
              const Icon(Icons.close, size: 14, color: Colors.orangeAccent),
            ],
          ),
        ),
      );
    } else {
      trailingWidget = const Padding(
        padding: EdgeInsets.only(right: 8.0),
        child: Icon(Icons.check_circle, color: Colors.green, size: 24),
      );
    }

    final isDownloaded = task != null && task.isCompleted && task.localPath != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isDownloaded 
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.blueAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDownloaded ? Icons.download_done : Icons.play_arrow_rounded, 
            color: isDownloaded ? Colors.green : Colors.blueAccent, 
            size: 30
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(
            isDownloaded ? '$metadata • Downloaded' : metadata,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        trailing: trailingWidget,
        onTap: () {
          ref.read(pipControllerProvider.notifier).playVideo(
            context,
            messageId: msg.id,
            videoFileId: fileId!,
            videoTitle: '${widget.series.coreName} - $title',
            episodeList: _selectedSeason.episodes,
            currentEpisodeIndex: index,
            seriesName: widget.series.coreName,
            networkUrl: isDownloaded ? task.localPath : null,
          );
        },
      ),
    );
  }
}
