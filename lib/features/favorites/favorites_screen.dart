import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../../models/anime_models.dart';
import '../home/home_controller.dart';
import '../home/android_series_details_screen.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../l10n/app_localizations.dart';

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
        title: Text(AppLocalizations.of(context)!.myList, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading && favoriteSeries.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _buildFavoritesBody(context, ref, favoriteSeries),
    );
  }

  Widget _buildFavoritesBody(BuildContext context, WidgetRef ref, List<AnimeSeries> favoriteSeries) {
    final theme = Theme.of(context);

    if (favoriteSeries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_rounded, 
              size: 80, 
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noFavoritesYet, 
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 20, 
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                AppLocalizations.of(context)!.tapHeartToFavorite, 
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final moviesList = ref.read(moviesControllerProvider).value ?? [];
    final webSeriesList = ref.read(webSeriesControllerProvider).value ?? [];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveCrossAxisCount(context, itemWidth: 150),
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: favoriteSeries.length,
      itemBuilder: (context, index) {
        final series = favoriteSeries[index];
        final isMovie = moviesList.any((s) => s.coreName == series.coreName);
        final isWebSeries = webSeriesList.any((s) => s.coreName == series.coreName);
        final categoryTitle = isMovie ? AppLocalizations.of(context)!.categoryMovies : (isWebSeries ? AppLocalizations.of(context)!.categoryWebSeries : AppLocalizations.of(context)!.categoryAnime);
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
            if (series.seasons.isEmpty) return;
            Navigator.push(
              context,
              PremiumPageRoute(
                child: AndroidSeriesDetailsScreen(
                  series: series,
                  categoryTitle: categoryTitle,
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
                      Text(
                        isMovie ? AppLocalizations.of(context)!.movie : AppLocalizations.of(context)!.nEpisodesPlural(totalEpisodes),
                        style: TextStyle(
                          color: isMovie ? Colors.amber : Colors.blue,
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
