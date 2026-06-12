import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import 'home_controller.dart';
import 'episode_list_screen.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../models/anime_models.dart';
import '../settings/settings_screen.dart';

import '../../services/storage_service.dart';
import '../player/pip_manager.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: Constants.categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      appBar: AppBar(
        title: const Text(
          'TelStream',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              (() {
                if (_currentIndex == 0) {
                  return ref.watch(animeControllerProvider.notifier).showFavoritesOnly;
                } else if (_currentIndex == 1) {
                  return ref.watch(moviesControllerProvider.notifier).showFavoritesOnly;
                } else {
                  return ref.watch(webSeriesControllerProvider.notifier).showFavoritesOnly;
                }
              })()
                  ? Icons.favorite 
                  : Icons.favorite_border,
              color: Colors.pinkAccent,
            ),
            onPressed: () {
              if (_currentIndex == 0) {
                ref.read(animeControllerProvider.notifier).toggleFavoritesFilter();
              } else if (_currentIndex == 1) {
                ref.read(moviesControllerProvider.notifier).toggleFavoritesFilter();
              } else {
                ref.read(webSeriesControllerProvider.notifier).toggleFavoritesFilter();
              }
              setState(() {}); // refresh the icon
            },
          ),
          PopupMenuButton<SortOrder>(
            icon: const Icon(Icons.sort, color: Colors.white70),
            color: const Color(0xFF0A1128),
            onSelected: (SortOrder order) {
              if (_currentIndex == 0) {
                ref.read(animeControllerProvider.notifier).setSortOrder(order);
              } else if (_currentIndex == 1) {
                ref.read(moviesControllerProvider.notifier).setSortOrder(order);
              } else {
                ref.read(webSeriesControllerProvider.notifier).setSortOrder(order);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOrder>>[
              const PopupMenuItem<SortOrder>(
                value: SortOrder.aToZ,
                child: Text('Name (A - Z)', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem<SortOrder>(
                value: SortOrder.zToA,
                child: Text('Name (Z - A)', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem<SortOrder>(
                value: SortOrder.newest,
                child: Text('Newest First', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem<SortOrder>(
                value: SortOrder.oldest,
                child: Text('Oldest First', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Anime'),
            Tab(text: 'Movies'),
            Tab(text: 'Web Series'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: Constants.categories.map((c) => CategoryView(category: c)).toList(),
      ),
    );
  }
}

class CategoryView extends ConsumerStatefulWidget {
  final ChannelCategory category;
  final AsyncNotifierProvider<HomeController, List<AnimeSeries>> provider;
  
  CategoryView({Key? key, required this.category}) 
    : provider = category.title == 'Anime' 
          ? animeControllerProvider as AsyncNotifierProvider<HomeController, List<AnimeSeries>>
          : category.title == 'Movies' 
              ? moviesControllerProvider as AsyncNotifierProvider<HomeController, List<AnimeSeries>>
              : webSeriesControllerProvider as AsyncNotifierProvider<HomeController, List<AnimeSeries>>,
      super(key: key);

  @override
  ConsumerState<CategoryView> createState() => _CategoryViewState();
}

class _CategoryViewState extends ConsumerState<CategoryView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _heroPageController = PageController(viewportFraction: 0.9);
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(widget.provider.notifier).loadMore();
      }
    });

    _heroTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_heroPageController.hasClients) {
        int nextPage = _heroPageController.page!.round() + 1;
        if (nextPage >= 3) { // 3 is the max items in our hero slider
          nextPage = 0;
          _heroPageController.animateToPage(nextPage, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
        } else {
          _heroPageController.animateToPage(nextPage, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _heroPageController.dispose();
    _heroTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.provider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final stateVal = ref.read(widget.provider).value;
          if (stateVal != null && stateVal.isNotEmpty) {
            final randomSeries = (stateVal.toList()..shuffle()).first;
            if (randomSeries.seasons.isNotEmpty && randomSeries.seasons.first.episodes.isNotEmpty) {
              final firstMsg = randomSeries.seasons.first.episodes.first;
              int? fileId;
              String title = 'Episode 1';
              if (firstMsg.content is td.MessageVideo) {
                final v = firstMsg.content as td.MessageVideo;
                fileId = v.video.video.id;
                title = v.video.fileName;
              } else if (firstMsg.content is td.MessageDocument) {
                final d = firstMsg.content as td.MessageDocument;
                fileId = d.document.document.id;
                title = d.document.fileName;
              }
              if (fileId != null) {
                ref.read(pipControllerProvider.notifier).playVideo(
                  context,
                  messageId: firstMsg.id,
                  videoFileId: fileId,
                  videoTitle: '${randomSeries.coreName} - $title',
                  episodeList: randomSeries.seasons.first.episodes,
                  currentEpisodeIndex: 0,
                  seriesName: randomSeries.coreName,
                );
              }
            }
          }
        },
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.shuffle, color: Colors.white),
        label: const Text('Surprise Me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // Grid View
          Positioned.fill(
            child: state.when(
            data: (seriesList) {
              if (seriesList.isEmpty) {
                return Center(
                  child: Text('No media found in ${widget.category.title}.', style: const TextStyle(color: Colors.white54)),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(widget.provider);
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 80)), // Space for Glassmorphic Search Bar
                    if (seriesList.isNotEmpty && _searchController.text.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildContinueWatchingRow(context, seriesList),
                      ),
                      
                    if (seriesList.isNotEmpty && _searchController.text.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildHeroSlider(context, seriesList.take(3).toList()),
                      ),
                    
                    if (seriesList.isNotEmpty && _searchController.text.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(left: 16, top: 24, bottom: 8),
                          child: Text('More Series', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final isSearch = _searchController.text.isNotEmpty;
                            final offset = isSearch ? 0 : (seriesList.length >= 3 ? 3 : seriesList.length);
                            final actualIndex = index + offset;
                            
                            if (actualIndex == seriesList.length) {
                              return ref.watch(widget.provider.notifier).hasMore 
                                  ? const Center(child: CircularProgressIndicator()) 
                                  : null;
                            }
                            if (actualIndex > seriesList.length) return null;

                            return _buildGridItem(context, seriesList[actualIndex]);
                          },
                          childCount: (seriesList.length - (_searchController.text.isNotEmpty ? 0 : (seriesList.length >= 3 ? 3 : seriesList.length))) + (ref.watch(widget.provider.notifier).hasMore ? 1 : 0),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)), // Space for FAB
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          ),
        ),

        // Glassmorphic Search Bar Overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 16.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.category.title}...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(widget.provider.notifier).search('');
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(widget.provider.notifier).search(value);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildContinueWatchingRow(BuildContext context, List<AnimeSeries> seriesList) {
    final lastWatched = ref.watch(lastWatchedProvider);
    if (lastWatched == null) return const SizedBox.shrink();

    final seriesName = lastWatched['seriesName'] as String;
    final episodeIndex = lastWatched['episodeIndex'] as int;

    // Find the series
    AnimeSeries? targetSeries;
    for (var s in seriesList) {
      if (s.coreName == seriesName) {
        targetSeries = s;
        break;
      }
    }

    if (targetSeries == null || targetSeries.seasons.isEmpty) return const SizedBox.shrink();
    if (episodeIndex >= targetSeries.seasons.first.episodes.length) return const SizedBox.shrink();

    final episodeMsg = targetSeries.seasons.first.episodes[episodeIndex];
    int? fileId;
    String title = 'Episode ${episodeIndex + 1}';
    if (episodeMsg.content is td.MessageVideo) {
      final v = episodeMsg.content as td.MessageVideo;
      fileId = v.video.video.id;
      title = v.video.fileName;
    } else if (episodeMsg.content is td.MessageDocument) {
      final d = episodeMsg.content as td.MessageDocument;
      fileId = d.document.document.id;
      title = d.document.fileName;
    }

    if (fileId == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.blueAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Continue Watching', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text(
                  '$seriesName - $title',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              ref.read(pipControllerProvider.notifier).playVideo(
                context,
                messageId: episodeMsg.id,
                videoFileId: fileId!,
                videoTitle: '$seriesName - $title',
                episodeList: targetSeries!.seasons.first.episodes,
                currentEpisodeIndex: episodeIndex,
                seriesName: seriesName,
              );
            },
            child: const Text('Resume', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, AnimeSeries series) {
    final totalEpisodes = series.seasons.fold(0, (sum, s) => sum + s.episodes.length);
    final latestPoster = series.seasons.isNotEmpty ? series.seasons.first.posterMessage : null;
    
    td.File? posterFile;
    if (latestPoster != null && latestPoster.content is td.MessagePhoto) {
      final photo = latestPoster.content as td.MessagePhoto;
      if (photo.photo.sizes.isNotEmpty) {
        posterFile = photo.photo.sizes.last.photo;
      }
    }

    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EpisodeListScreen(
                              season: series.seasons.first,
                              series: series,
                              heroTag: 'hero_poster_grid_${series.coreName}',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          // Removed expensive shadows for buttery smooth scrolling
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'hero_poster_grid_${series.coreName}',
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
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
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
                                  Text(
                                    series.coreName,
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
                                    '${series.seasons.length} Seasons • $totalEpisodes Episodes',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const Positioned(
                              top: 8,
                              left: 8,
                              child: Icon(Icons.movie_creation, color: Colors.white70, size: 16),
                            ),
                          ],
                        ),
                      ),
                    );
  }

  Widget _buildHeroSlider(BuildContext context, List<AnimeSeries> topSeries) {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _heroPageController,
        itemCount: topSeries.length,
        itemBuilder: (context, index) {
          final series = topSeries[index];
          final latestPoster = series.seasons.isNotEmpty ? series.seasons.first.posterMessage : null;
          
          td.File? posterFile;
          if (latestPoster != null && latestPoster.content is td.MessagePhoto) {
            final photo = latestPoster.content as td.MessagePhoto;
            if (photo.photo.sizes.isNotEmpty) {
              posterFile = photo.photo.sizes.last.photo;
            }
          }

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EpisodeListScreen(
                  season: series.seasons.first,
                  series: series,
                  heroTag: 'hero_poster_carousel_${series.coreName}',
                ),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.05),
                // Removed expensive shadow
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'hero_poster_carousel_${series.coreName}',
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
                        colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4)),
                          child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          series.coreName,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EpisodeListScreen(
                                    season: series.seasons.first,
                                    series: series,
                                    heroTag: 'hero_poster_${series.coreName}',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow, size: 16),
                              label: const Text('Watch Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
