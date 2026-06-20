import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../../models/anime_models.dart';
import '../home/home_controller.dart';
import '../home/episode_list_screen.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animeState = ref.watch(animeControllerProvider);
    final moviesState = ref.watch(moviesControllerProvider);
    final webSeriesState = ref.watch(webSeriesControllerProvider);

    final favorites = ref.watch(favoritesProvider);

    // Combine lists from all loaded states
    final List<AnimeSeries> allSeries = [];
    if (animeState.value != null) allSeries.addAll(animeState.value!);
    if (moviesState.value != null) allSeries.addAll(moviesState.value!);
    if (webSeriesState.value != null) allSeries.addAll(webSeriesState.value!);

    // Filter duplicates by name
    final seenNames = <String>{};
    final uniqueSeries = allSeries.where((s) => seenNames.add(s.coreName)).toList();
    final favoriteSeries = uniqueSeries.where((s) => favorites.contains(s.coreName)).toList();

    final isLoading = animeState.isLoading || moviesState.isLoading || webSeriesState.isLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('My List', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading && favoriteSeries.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _buildFavoritesBody(context, favoriteSeries),
    );
  }

  Widget _buildFavoritesBody(BuildContext context, List<AnimeSeries> favoriteSeries) {
    if (favoriteSeries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.white24),
            SizedBox(height: 16),
            Text('No favorites yet.', style: TextStyle(color: Colors.white54, fontSize: 18)),
            SizedBox(height: 8),
            Text('Tap the heart icon on any series to add it here!', style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: favoriteSeries.length,
      itemBuilder: (context, index) {
        final series = favoriteSeries[index];
        final totalEpisodes = series.seasons.fold(0, (sum, s) => sum + s.episodes.length);
        final latestPoster = series.seasons.isNotEmpty ? series.seasons.first.posterMessage : null;
        
        td.File? posterFile;
        td.Minithumbnail? minithumbnail;
        if (latestPoster != null && latestPoster.content is td.MessagePhoto) {
          final photo = latestPoster.content as td.MessagePhoto;
          if (photo.photo.sizes.isNotEmpty) {
            posterFile = photo.photo.sizes.last.photo;
          }
          minithumbnail = photo.photo.minithumbnail;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PremiumPageRoute(
                child: EpisodeListScreen(
                  season: series.seasons.first,
                  series: series,
                  heroTag: 'hero_poster_fav_${series.coreName}',
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'hero_poster_fav_${series.coreName}',
                  child: TdThumbnail(
                    file: posterFile,
                    minithumbnail: minithumbnail,
                    autoDownload: true,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                  
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AlignedNameText(
                        text: series.coreName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalEpisodes Episodes',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
