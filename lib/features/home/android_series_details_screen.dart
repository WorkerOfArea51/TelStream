import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/constants.dart';
import '../../services/metadata_service.dart';
import '../../models/anime_models.dart';
import 'android_episode_list_screen.dart';
import 'home_controller.dart';
import '../../services/firebase_metadata_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_service.dart';
import '../../core/logger.dart';
class AndroidSeriesDetailsScreen extends ConsumerStatefulWidget {
  final AnimeSeries series;
  final String categoryTitle;
  final SeriesMetadata? metadata;
  final List<String>? overrideIds;
  final List<SeriesMetadata>? preloadedMetadata;
  final VoidCallback? onBack;
  final int initialSeasonIndex;

  const AndroidSeriesDetailsScreen({
    super.key,
    required this.series,
    required this.categoryTitle,
    this.metadata,
    this.overrideIds,
    this.preloadedMetadata,
    this.onBack,
    this.initialSeasonIndex = 0,
  });

  @override
  ConsumerState<AndroidSeriesDetailsScreen> createState() =>
      _AndroidSeriesDetailsScreenState();
}

class _AndroidSeriesDetailsScreenState extends ConsumerState<AndroidSeriesDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  YoutubePlayerController? _ytController;
  bool _trailerPlaying = false;
  SeriesMetadata? _currentMetadata;
  bool _isLoadingMetadata = false;
  int _selectedSeasonIndex = 0;
  List<String>? _overrideIds;
  final Map<int, SeriesMetadata> _metadataCache = {};

  @override
  void initState() {
    super.initState();
    _currentMetadata = widget.metadata;
    _overrideIds = widget.overrideIds;
    _selectedSeasonIndex = widget.initialSeasonIndex;
    _tabController = TabController(length: 3, vsync: this);

    _initYtController(_currentMetadata);
    
    if (_currentMetadata != null) {
      _metadataCache[0] = _currentMetadata!;
      if (widget.preloadedMetadata != null && widget.preloadedMetadata!.isNotEmpty) {
        for (int i = 0; i < widget.preloadedMetadata!.length; i++) {
          _metadataCache[i] = widget.preloadedMetadata![i];
        }
      } else if (_overrideIds != null && _overrideIds!.length > 1) {
        _prefetchOtherMetadata(_overrideIds!);
      }
    } else {
      if (widget.preloadedMetadata != null && widget.preloadedMetadata!.isNotEmpty) {
        for (int i = 0; i < widget.preloadedMetadata!.length; i++) {
          _metadataCache[i] = widget.preloadedMetadata![i];
        }
        if (_metadataCache.containsKey(0) && _metadataCache[0]!.title.isNotEmpty) {
          _currentMetadata = _metadataCache[0];
          _initYtController(_currentMetadata);
        }
      } else {
        _checkAndFetchMetadata();
      }
    }
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
        debugPrint('Error prefetching metadata: $e');
      }
      if (mounted && newMeta != null) {
        setState(() {
          _metadataCache[i] = newMeta!;
        });
      }
      await Future.delayed(const Duration(milliseconds: 350));
    }
  }

  Future<void> _checkAndFetchMetadata() async {
    final currentSeason = widget.series.seasons.isNotEmpty ? widget.series.seasons[0].seasonName : '';
    String? overrideStr = FirebaseMetadataService.getOverride('${widget.series.coreName}_$currentSeason');
    
    if (overrideStr == null || overrideStr.isEmpty) {
      overrideStr = FirebaseMetadataService.getOverride(widget.series.coreName);
    }
    
    if (overrideStr != null && overrideStr.isNotEmpty) {
      final ids = overrideStr.split(',');
      
      final currentSeasonIndex = widget.series.seasons.indexWhere(
        (s) => s.seasonName == currentSeason,
      );
      final seasonNumber = currentSeasonIndex >= 0 ? currentSeasonIndex + 1 : 1;

      if (mounted) {
        setState(() {
          _overrideIds = ids;
          _isLoadingMetadata = true;
        });
      }
      
      // Check local cache first for instant loading
      final storage = ref.read(storageServiceProvider);
      final cacheKey = 'season_meta_${widget.series.coreName}_${seasonNumber - 1}';
      final cachedJson = storage.getSeasonMetadataCache(cacheKey);
      if (cachedJson != null) {
        final cachedMeta = SeriesMetadata.fromJson(cachedJson);
        if (mounted) {
          setState(() {
            _currentMetadata = cachedMeta;
            _metadataCache[seasonNumber - 1] = cachedMeta;
            _isLoadingMetadata = false;
          });
          _initYtController(_currentMetadata);
        }
        return;
      }

      final targetId = ids.first;
      final metadataService = MetadataService();
      SeriesMetadata? newMeta;
      if (targetId.startsWith('tt')) {
        newMeta = await metadataService.fetchTmdbSeasonByImdbId(targetId, seasonNumber);
      } else {
        newMeta = await metadataService.fetchJikanByMalId(targetId);
      }
      
      if (mounted) {
        setState(() {
          if (newMeta != null) {
            _currentMetadata = newMeta;
            _metadataCache[0] = newMeta;
          }
          _isLoadingMetadata = false;
          _initYtController(_currentMetadata);
        });
        if (_overrideIds != null && _overrideIds!.length > 1) {
          _prefetchOtherMetadata(_overrideIds!);
        }
      }
    }
  }

  void _initYtController(SeriesMetadata? meta) {
    if (meta != null && meta.trailerYoutubeId.isNotEmpty) {
      bool isDesktop =
          !kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
      if (!isDesktop) {
        _ytController = YoutubePlayerController.fromVideoId(
          videoId: meta.trailerYoutubeId,
          autoPlay: false,
          params: const YoutubePlayerParams(
            showControls: true,
            mute: false,
            showFullscreenButton: true,
            loop: false,
          ),
        );
      }
    } else {
      _ytController?.close();
      _ytController = null;
    }
  }

  Future<void> _onSeasonChanged(int newIndex) async {
    final newSeasonName = widget.series.seasons.length > newIndex ? widget.series.seasons[newIndex].seasonName : '';
    final seasonOverrideStr = FirebaseMetadataService.getOverride('${widget.series.coreName}_$newSeasonName');
    
    if ((_overrideIds == null || _overrideIds!.isEmpty) && (seasonOverrideStr == null || seasonOverrideStr.isEmpty)) {
      return;
    }

    if (_metadataCache.containsKey(newIndex) && (seasonOverrideStr == null || seasonOverrideStr.isEmpty)) {
      setState(() {
        _selectedSeasonIndex = newIndex;
        _currentMetadata = _metadataCache[newIndex];
        _trailerPlaying = false;
        _initYtController(_currentMetadata);
      });
      return;
    }

    String targetId = '';
    if (seasonOverrideStr != null && seasonOverrideStr.isNotEmpty) {
      targetId = seasonOverrideStr.split(',').first;
    } else {
      int idIndex = newIndex < _overrideIds!.length
          ? newIndex
          : _overrideIds!.length - 1;
      targetId = _overrideIds![idIndex];
    }

    setState(() {
      _selectedSeasonIndex = newIndex;
      _isLoadingMetadata = true;
      _trailerPlaying = false;
    });

    SeriesMetadata? newMeta;
    final metadataService = MetadataService();
    if (targetId.startsWith('tt')) {
      // Fetch season-specific metadata from TMDB
      // Season numbers are 1-indexed (index 0 = Season 1)
      newMeta = await metadataService.fetchTmdbSeasonByImdbId(targetId, newIndex + 1);
    } else {
      newMeta = await metadataService.fetchJikanByMalId(targetId);
    }

    if (mounted) {
      setState(() {
        if (newMeta != null) {
          _metadataCache[newIndex] = newMeta;
          _currentMetadata = newMeta;
        } else {
          // If metadata fetch fails, reset currentMetadata so it doesn't bleed from the previous season
          _currentMetadata = null;
        }
        _isLoadingMetadata = false;
        _initYtController(_currentMetadata);
      });
    }

    // Persist season metadata to storage for instant loading next time
    if (newMeta != null) {
      try {
        final storage = ref.read(storageServiceProvider);
        final cacheKey = 'season_meta_${widget.series.coreName}_$newIndex';
        await storage.saveSeasonMetadataCache(cacheKey, newMeta.toJson());
      } catch (e) {
        Log.w('Failed to cache season metadata: $e');
      }
    }
  }

  void _openRecommendation(BuildContext context, RelatedContent rec) async {
    final isMovie = widget.categoryTitle.toLowerCase() == 'movies';
    SeriesMetadata? fetchedMeta;
    
    if (!isMovie) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
      try {
        fetchedMeta = await MetadataService().fetchJikanByMalId(rec.id.toString());
      } catch (_) {}
      if (context.mounted) Navigator.pop(context);
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(fetchedMeta?.title.isNotEmpty == true ? fetchedMeta!.title : rec.title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rec.posterUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    rec.posterUrl,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                fetchedMeta?.synopsis.isNotEmpty == true 
                    ? fetchedMeta!.synopsis 
                    : (rec.synopsis.isNotEmpty ? rec.synopsis : 'Recommendation from TMDB/Jikan.'),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _handleWatchNow(context, rec, fetchedMeta: fetchedMeta),
                  child: const Text(
                    'Watch Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleWatchNow(BuildContext context, RelatedContent rec, {SeriesMetadata? fetchedMeta}) async {
    Navigator.pop(context); // Close the popup first

    final isMovie = widget.categoryTitle.toLowerCase() == 'movies';
    final normalizedRecTitle = HomeController.normalizeSeriesName(
      rec.title,
      isMovie: isMovie,
    );
    final normalizedFetchedTitle = fetchedMeta != null ? HomeController.normalizeSeriesName(fetchedMeta.title, isMovie: isMovie) : null;

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

    String cleanString(String input) {
      var s = input.replaceAll('_', ' ').replaceAll('-', ' ');
      s = s.replaceAll(RegExp(r'\b(?:19|20)\d{2}\b'), '');
      s = s.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
      s = s.replaceAll(RegExp(r'\s+'), ' ');
      return s.trim().toLowerCase();
    }

    final targetClean = cleanString(rec.title);
    final targetFetchedClean = fetchedMeta != null ? cleanString(fetchedMeta.title) : null;
    final targetIdStr = rec.id.toString();

    // 1. Try to match by explicit Override ID first
    for (final s in allSeries) {
      final overrideIdStr = FirebaseMetadataService.getOverride(s.coreName);
      if (overrideIdStr != null && overrideIdStr.isNotEmpty) {
        final overrideIds = overrideIdStr.split(',');
        if (overrideIds.contains(targetIdStr)) {
          matchedSeries = s;
          break;
        }
      }
    }

    // 2. Fallback to Exact Title Match
    if (matchedSeries == null) {
      for (final s in allSeries) {
        final sClean = cleanString(s.coreName);
        if (sClean == targetClean || (targetFetchedClean != null && sClean == targetFetchedClean)) {
          matchedSeries = s;
          break;
        }
      }
    }

    // 3. Smart Substring Fallback Match
    if (matchedSeries == null) {
      for (final s in allSeries) {
        final sClean = cleanString(s.coreName);
        // Ensure library item name is at least 3 chars to prevent false positives like matching "a"
        if (sClean.length > 2 && (targetClean.contains(sClean) || (targetFetchedClean != null && targetFetchedClean.contains(sClean)))) {
          matchedSeries = s;
          break; // Use the first decent match
        }
      }
    }

    if (matchedSeries != null) {
      // It's uploaded! Fetch override if exists, then navigate
      final overrideId = FirebaseMetadataService.getOverride(
        matchedSeries.coreName,
      );

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

      // Smart initial season selection based on recommendation title
      int initialSeasonIndex = 0;
      for (int i = 0; i < matchedSeries.seasons.length; i++) {
        final season = matchedSeries.seasons[i];
        final cleanSeasonTitle = cleanString(season.fullTitle);
        final cleanSeasonName = cleanString(season.seasonName);
        if (cleanSeasonTitle == targetClean || cleanSeasonName == targetClean) {
          initialSeasonIndex = i;
          break;
        }
      }
      if (initialSeasonIndex == 0) {
        for (int i = 0; i < matchedSeries.seasons.length; i++) {
          final season = matchedSeries.seasons[i];
          final cleanSeasonTitle = cleanString(season.fullTitle);
          if (cleanSeasonTitle.contains(targetClean) || targetClean.contains(cleanSeasonTitle)) {
            initialSeasonIndex = i;
            break;
          }
        }
      }

      if (context.mounted) {
        Navigator.push(
          context,
          PremiumPageRoute(
            child: AndroidSeriesDetailsScreen(
              series: matchedSeries,
              categoryTitle: widget.categoryTitle,
              metadata: newMeta,
              overrideIds: overrideIds,
              initialSeasonIndex: initialSeasonIndex,
            ),
          ),
        );
      }
    } else {
      // Not uploaded, show friendly popup
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Not Available',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'This movie/series is not available yet. Please go to the About page and request it on Telegram!',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('OK', style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
        );
      }
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
    AsyncValue<List<AnimeSeries>> homeState;
    if (widget.categoryTitle.toLowerCase() == 'movies') {
      homeState = ref.watch(moviesControllerProvider);
    } else if (widget.categoryTitle.toLowerCase() == 'web series') {
      homeState = ref.watch(webSeriesControllerProvider);
    } else {
      homeState = ref.watch(animeControllerProvider);
    }
    
    AnimeSeries latestSeries = widget.series;
    if (homeState is AsyncData && homeState.value != null) {
      try {
        latestSeries = homeState.value!.firstWhere((s) => s.coreName == widget.series.coreName);
      } catch (_) {}
    }

    if (_isLoadingMetadata) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (_currentMetadata == null) {
      if (latestSeries.seasons.isEmpty) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack ?? () => Navigator.pop(context),
            ),
          ),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No episodes available for this series yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
        );
      }
      final safeIndex = _selectedSeasonIndex < latestSeries.seasons.length ? _selectedSeasonIndex : 0;
      return AndroidEpisodeListScreen(
        season: latestSeries.seasons[safeIndex],
        series: latestSeries,
        heroTag: 'hero_library_${widget.categoryTitle}_${latestSeries.coreName}',
        categoryTitle: widget.categoryTitle,
        isEmbedded: false,
        onSeasonChanged: _onSeasonChanged,
        onBack: widget.onBack,
      );
    }

    final meta = _currentMetadata!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        key: ValueKey(_selectedSeasonIndex),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            if (_trailerPlaying && _ytController != null)
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    _buildHero(meta),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 10),
                          ],
                        ),
                        onPressed: widget.onBack ?? () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            if (!(_trailerPlaying && _ytController != null))
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(background: _buildHero(meta)),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: widget.onBack ?? () => Navigator.pop(context),
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          meta.releaseYear,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            meta.maturityRating,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cast: ${meta.cast}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
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
                    Tab(
                      text: widget.categoryTitle.toLowerCase() == 'movies'
                          ? 'Media'
                          : 'Episodes',
                    ),
                    const Tab(text: 'More Details'),
                    const Tab(text: 'More Like This'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            if (latestSeries.seasons.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No episodes available',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              AndroidEpisodeListScreen(
                season: latestSeries.seasons.length > _selectedSeasonIndex ? latestSeries.seasons[_selectedSeasonIndex] : latestSeries.seasons[0],
                series: latestSeries,
                heroTag: 'hero_library_details_${latestSeries.coreName}',
                categoryTitle: widget.categoryTitle,
                isEmbedded: true,
                onSeasonChanged: _onSeasonChanged,
              ),
            _buildMoreDetailsTab(meta),
            _buildMoreLikeThisTab(meta),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(SeriesMetadata meta) {
    if (_ytController != null && _trailerPlaying) {
      return Container(
        color: Colors.black,
        child: SafeArea(
          child: AspectRatio(
            aspectRatio:
                1.1, // Gives enough vertical space for YouTube settings menu to not clip
            child: YoutubePlayer(
              controller: _ytController!,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(),
                ),
                Factory<HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                ),
              },
            ),
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
                Colors.black.withValues(alpha: 0.3),
                Colors.transparent,
                Colors.black,
              ],
            ),
          ),
        ),
        if (meta.trailerYoutubeId.isNotEmpty)
          Center(
            child: IconButton(
              iconSize: 64,
              icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              onPressed: () async {
                bool isDesktop =
                    !kIsWeb &&
                    (Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS);
                if (isDesktop || _ytController == null) {
                  final url = Uri.parse(
                    'https://www.youtube.com/watch?v=${meta.trailerYoutubeId}',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                } else {
                  setState(() => _trailerPlaying = true);
                }
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.black, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

extension on _AndroidSeriesDetailsScreenState {
  Widget _buildMoreDetailsTab(SeriesMetadata meta) {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('more_details_tab'),
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta.director.isNotEmpty)
            _buildDetailRow('Director', meta.director),
          if (meta.writers.isNotEmpty) _buildDetailRow('Writers', meta.writers),
          if (meta.cast.isNotEmpty) _buildDetailRow('Stars', meta.cast),
          if (meta.status.isNotEmpty) _buildDetailRow('Status', meta.status),
          if (meta.runtime.isNotEmpty)
            _buildDetailRow('Duration', meta.runtime),
          if (meta.episodesCount.isNotEmpty)
            _buildDetailRow('Episodes', meta.episodesCount),
          if (meta.userScore.isNotEmpty)
            _buildDetailRow('Score', meta.userScore),
          if (meta.rank.isNotEmpty) _buildDetailRow('Rank', meta.rank),
          if (meta.airedDates.isNotEmpty)
            _buildDetailRow('Aired', meta.airedDates),
          if (meta.source.isNotEmpty) _buildDetailRow('Source', meta.source),
          if (meta.spokenLanguages.isNotEmpty)
            _buildDetailRow('Languages', meta.spokenLanguages),
          if (meta.budgetRevenue.isNotEmpty)
            _buildDetailRow('Financials', meta.budgetRevenue),
          if (meta.productionCompanies.isNotEmpty)
            _buildDetailRow('Studios', meta.productionCompanies),

          if (widget.categoryTitle.toLowerCase() == 'anime' &&
              meta.malId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: 24.0,
                bottom: 16.0,
                left: 16.0,
                right: 16.0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(
                      'https://myanimelist.net/anime/${meta.malId}',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  label: const Text(
                    'Check on MyAnimeList',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E51A2), // MAL Blue
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            )
          else if (meta.imdbId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: 24.0,
                bottom: 16.0,
                left: 16.0,
                right: 16.0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(
                      'https://www.imdb.com/title/${meta.imdbId}/',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new, color: Colors.black),
                  label: const Text(
                    'Check on IMDB',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber, // IMDB Yellow
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
        child: Text(
          'No recommendations available',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return GridView.builder(
      key: const PageStorageKey<String>('more_like_this_tab'),
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
                : Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(Icons.movie, color: Colors.white54),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
