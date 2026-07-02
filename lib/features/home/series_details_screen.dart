import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../services/metadata_service.dart';
import '../../models/anime_models.dart';
import 'episode_list_screen.dart';
import 'home_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SeriesDetailsScreen extends ConsumerStatefulWidget {
  final AnimeSeries series;
  final String categoryTitle;
  final SeriesMetadata? metadata;
  final List<String>? overrideIds;

  const SeriesDetailsScreen({
    super.key,
    required this.series,
    required this.categoryTitle,
    this.metadata,
    this.overrideIds,
  });

  @override
  ConsumerState<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends ConsumerState<SeriesDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  YoutubePlayerController? _ytController;
  bool _trailerPlaying = false;
  SeriesMetadata? _currentMetadata;
  bool _isLoadingMetadata = false;

  @override
  void initState() {
    super.initState();
    _currentMetadata = widget.metadata;
    _tabController = TabController(length: 3, vsync: this);
    
    _initYtController(_currentMetadata);
  }

  void _initYtController(SeriesMetadata? meta) {
    if (meta != null && meta.trailerYoutubeId.isNotEmpty) {
      _ytController = YoutubePlayerController.fromVideoId(
        videoId: widget.metadata!.trailerYoutubeId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          mute: false,
          showFullscreenButton: true,
          loop: false,
        ),
      );
    } else {
      _ytController?.close();
      _ytController = null;
    }
  }

  Future<void> _onSeasonChanged(int newIndex) async {
    if (widget.overrideIds == null || widget.overrideIds!.isEmpty) return;
    
    int idIndex = newIndex < widget.overrideIds!.length ? newIndex : widget.overrideIds!.length - 1;
    String targetId = widget.overrideIds![idIndex];
    
    setState(() {
      _isLoadingMetadata = true;
      _trailerPlaying = false;
    });
    
    SeriesMetadata? newMeta;
    final metadataService = MetadataService();
    if (targetId.startsWith('tt')) {
      newMeta = await metadataService.fetchTmdbByImdbId(targetId);
    } else {
      newMeta = await metadataService.fetchJikanByMalId(targetId);
    }
    
    if (mounted) {
      setState(() {
        _currentMetadata = newMeta ?? _currentMetadata;
        _isLoadingMetadata = false;
        _initYtController(_currentMetadata);
      });
    }
  }

  Future<void> _openRecommendation(BuildContext context, RelatedContent rec) async {
    final isMovie = widget.categoryTitle.toLowerCase() == 'movies';
    final normalizedRecTitle = HomeController.normalizeSeriesName(rec.title, isMovie: isMovie);
    
    AsyncValue<List<AnimeSeries>> seriesState;
    if (isMovie) {
      seriesState = ref.read(moviesControllerProvider);
    } else if (widget.categoryTitle.toLowerCase() == 'web series') {
      seriesState = ref.read(webSeriesControllerProvider);
    } else {
      seriesState = ref.read(animeControllerProvider);
    }
    
    final allSeries = seriesState.value ?? [];
    AnimeSeries? matchedSeries;
    
    for (final s in allSeries) {
      if (s.coreName.toLowerCase() == normalizedRecTitle.toLowerCase()) {
        matchedSeries = s;
        break;
      }
    }
    
    if (matchedSeries != null) {
      // It's uploaded! Fetch override if exists, then navigate
      const secureStorage = FlutterSecureStorage();
      final overrideId = await secureStorage.read(key: 'metadata_override_${matchedSeries.coreName}');
      
      List<String>? overrideIds;
      SeriesMetadata? newMeta;
      
      if (overrideId != null && overrideId.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()),
        );
        
        overrideIds = overrideId.split(',');
        final firstId = overrideIds.first;
        final metadataService = MetadataService();
        
        if (widget.categoryTitle.toLowerCase() == 'anime') {
          newMeta = await metadataService.fetchJikanByMalId(firstId);
        } else {
          newMeta = await metadataService.fetchTmdbByImdbId(firstId);
        }
        
        if (context.mounted) Navigator.pop(context);
      }
      
      if (context.mounted) {
        Navigator.push(
          context,
          PremiumPageRoute(
            child: SeriesDetailsScreen(
              series: matchedSeries,
              categoryTitle: widget.categoryTitle,
              metadata: newMeta,
              overrideIds: overrideIds,
            ),
          ),
        );
      }
    } else {
      // Not uploaded, show the dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(rec.title, style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rec.posterUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(rec.posterUrl, height: 200, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 16),
                Text(
                  rec.synopsis.isNotEmpty ? rec.synopsis : 'Recommendation from TMDB/Jikan.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ytController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMetadata == null) {
      return EpisodeListScreen(
        season: widget.series.seasons.first,
        series: widget.series,
        heroTag: 'hero_library_${widget.categoryTitle}_${widget.series.coreName}',
        categoryTitle: widget.categoryTitle,
        isEmbedded: false,
        onSeasonChanged: _onSeasonChanged,
      );
    }

    final meta = _currentMetadata!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHero(meta),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(meta.releaseYear, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                        child: Text(meta.maturityRating, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meta.genres.join(', '),
                          style: const TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  Text(
                    meta.synopsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cast: ${meta.cast}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.red,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(text: widget.categoryTitle.toLowerCase() == 'movies' ? 'Media' : 'Episodes'),
                  const Tab(text: 'More Details'),
                  const Tab(text: 'More Like This'),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                EpisodeListScreen(
                  season: widget.series.seasons.first,
                  series: widget.series,
                  heroTag: 'hero_library_details_${widget.series.coreName}',
                  categoryTitle: widget.categoryTitle,
                  isEmbedded: true,
                  onSeasonChanged: _onSeasonChanged,
                ),
                _buildMoreDetailsTab(meta),
                _buildMoreLikeThisTab(meta),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(SeriesMetadata meta) {
    if (_ytController != null && _trailerPlaying) {
      return Container(
        color: Colors.black,
        child: SafeArea(
          child: YoutubePlayer(
            controller: _ytController!,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          meta.backdropUrl.isNotEmpty ? meta.backdropUrl : meta.posterUrl,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.grey[900]),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.transparent,
                Colors.black,
              ],
            ),
          ),
        ),
        if (_ytController != null)
          Center(
            child: IconButton(
              iconSize: 64,
              icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              onPressed: () {
                setState(() => _trailerPlaying = true);
              },
            ),
          ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.black,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

extension on _SeriesDetailsScreenState {
  Widget _buildMoreDetailsTab(SeriesMetadata meta) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta.status.isNotEmpty) _buildDetailRow('Status', meta.status),
          if (meta.runtime.isNotEmpty) _buildDetailRow('Duration', meta.runtime),
          if (meta.releaseYear.isNotEmpty) _buildDetailRow('Release Year', meta.releaseYear),
          if (meta.maturityRating.isNotEmpty) _buildDetailRow('Age Rating', meta.maturityRating),
          if (meta.genres.isNotEmpty) _buildDetailRow('Genres', meta.genres.join(', ')),
          if (meta.productionCompanies.isNotEmpty) _buildDetailRow('Studios', meta.productionCompanies),
          if (meta.cast.isNotEmpty && meta.cast != 'Anime Cast') _buildDetailRow('Cast', meta.cast),
          const SizedBox(height: 24),
          const Text('Synopsis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(meta.synopsis, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreLikeThisTab(SeriesMetadata meta) {
    if (meta.recommendations.isEmpty) {
      return const Center(
        child: Text('No recommendations available', style: TextStyle(color: Colors.white54)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: meta.recommendations.length,
      itemBuilder: (context, index) {
        final rec = meta.recommendations[index];
        return GestureDetector(
          onTap: () => _openRecommendation(context, rec),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: rec.posterUrl.isNotEmpty
                ? Image.network(rec.posterUrl, fit: BoxFit.cover)
                : Container(color: Colors.grey[800], child: const Center(child: Icon(Icons.movie, color: Colors.white54))),
          ),
        );
      },
    );
  }
}
