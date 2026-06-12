import 'package:flutter/material.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../models/anime_models.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../player/pip_manager.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';

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
    if (widget.season.posterMessage.content is td.MessagePhoto) {
      final photo = widget.season.posterMessage.content as td.MessagePhoto;
      if (photo.photo.sizes.isNotEmpty) {
        posterFile = photo.photo.sizes.last.photo;
      }
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
              title: Text(
                widget.season.fullTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: effectiveHeroTag,
                    child: TdThumbnail(
                      file: posterFile,
                      width: double.infinity,
                      height: double.infinity,
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
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final msg = widget.season.episodes[index];
                  return _buildEpisodeItem(context, msg, index);
                },
                childCount: widget.season.episodes.length,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.blueAccent, size: 30),
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
            metadata,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        onTap: () {
          ref.read(pipControllerProvider.notifier).playVideo(
            context,
            messageId: msg.id,
            videoFileId: fileId!,
            videoTitle: '${widget.series.coreName} - $title',
            episodeList: widget.season.episodes,
            currentEpisodeIndex: index,
            seriesName: widget.series.coreName,
          );
        },
      ),
    );
  }
}
