import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../models/anime_models.dart';
import '../../services/storage_service.dart';
import '../../core/widgets/td_thumbnail.dart';
import 'home_controller.dart';
import 'episode_list_screen.dart';

class LibraryView extends ConsumerStatefulWidget {
  final ChannelCategory category;
  
  const LibraryView({
    super.key,
    required this.category,
  });

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> with SingleTickerProviderStateMixin {
  late final AsyncNotifierProvider<HomeController, List<AnimeSeries>> provider;
  late final TabController _subTabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isSearching = false;
  int _activeSubTabIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Select provider based on category
    provider = widget.category.title == 'Anime'
        ? animeControllerProvider as AsyncNotifierProvider<HomeController, List<AnimeSeries>>
        : widget.category.title == 'Movies'
            ? moviesControllerProvider as AsyncNotifierProvider<HomeController, List<AnimeSeries>>
            : webSeriesControllerProvider as AsyncNotifierProvider<HomeController, List<AnimeSeries>>;
            
    _subTabController = TabController(length: 2, vsync: this);
    _subTabController.addListener(() {
      if (!_subTabController.indexIsChanging) {
        setState(() {
          _activeSubTabIndex = _subTabController.index;
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(provider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _subTabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provider);
        final favorites = ref.watch(favoritesProvider);
    final isDownloadedOnly = ref.watch(downloadedOnlyProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  ref.read(provider.notifier).search(val);
                },
              )
            : Text(
                '${ref.watch(provider.notifier).resolvedChatTitle} ${state.value != null ? "(${_getFilteredList(state.value!, favorites, isDownloadedOnly).length})" : ""}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
                ref.read(provider.notifier).search('');
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          PopupMenuButton<SortOrder>(
            icon: const Icon(Icons.sort, color: Colors.white70),
            color: const Color(0xFF1C1C1E),
            onSelected: (SortOrder order) {
              ref.read(provider.notifier).setSortOrder(order);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: SortOrder.aToZ, child: Text('Name (A-Z)', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: SortOrder.zToA, child: Text('Name (Z-A)', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: SortOrder.newest, child: Text('Newest First', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: SortOrder.oldest, child: Text('Oldest First', style: TextStyle(color: Colors.white))),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _subTabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.orange,
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.white60,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Favorites'),
              ],
            ),
          ),
        ),
      ),
      body: state.when(
        skipLoadingOnRefresh: false,
        data: (seriesList) {
          final filteredList = _getFilteredList(seriesList, favorites, isDownloadedOnly);
          
          if (filteredList.isEmpty) {
            return _buildEmptyState();
          }

          // Automatically load more if we have very few series and there is more content
          if (filteredList.length < 6 && ref.read(provider.notifier).hasMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(provider.notifier).loadMore();
            });
          }

          return RefreshIndicator(
            color: Colors.orange,
            backgroundColor: const Color(0xFF1C1C1E),
            onRefresh: () async {
              ref.invalidate(provider);
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (!_isSearching && _activeSubTabIndex == 0 && _searchController.text.isEmpty && filteredList.isNotEmpty)
                  SliverToBoxAdapter(
                    child: FeaturedCarousel(
                      seriesList: filteredList.take(5).toList(),
                      categoryTitle: widget.category.title,
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == filteredList.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: CircularProgressIndicator(color: Colors.orange),
                            ),
                          );
                        }
                        
                        final series = filteredList[index];
                        return _buildGridItem(context, series);
                      },
                      childCount: filteredList.length + (ref.watch(provider.notifier).hasMore ? 1 : 0),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  List<AnimeSeries> _getFilteredList(List<AnimeSeries> list, List<String> favorites, bool isDownloadedOnly) {
    var result = list;
    if (_activeSubTabIndex == 1) {
      result = result.where((s) => favorites.contains(s.coreName)).toList();
    }
    if (isDownloadedOnly) {
      final history = ref.read(storageServiceProvider).getHistoryLog();
      final watchedSeriesNames = history.map((e) => e['seriesName'] as String).toSet();
      result = result.where((s) => watchedSeriesNames.contains(s.coreName)).toList();
    }
    return result;
  }

  Widget _buildEmptyState() {
    // Return Tachiyomi styled empty layout with beautiful kaomoji
    final kaomoji = _activeSubTabIndex == 1 ? '(・_・;)' : '(・○・;)';
    final message = _activeSubTabIndex == 1 ? 'No favorites in this category' : 'Your library is empty';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            kaomoji,
            style: const TextStyle(fontSize: 48, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.withValues(alpha: 0.1),
              foregroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.orange, width: 1),
              ),
            ),
            onPressed: () {
              ref.invalidate(provider);
            },
            child: const Text('Refresh Library'),
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
              heroTag: 'hero_library_${widget.category.title}_${series.coreName}',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'hero_library_${widget.category.title}_${series.coreName}',
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
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                series.coreName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Top-left Orange Badge (total episodes available)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  totalEpisodes.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeaturedCarousel extends StatefulWidget {
  final List<AnimeSeries> seriesList;
  final String categoryTitle;

  const FeaturedCarousel({
    Key? key,
    required this.seriesList,
    required this.categoryTitle,
  }) : super(key: key);

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (widget.seriesList.isEmpty) return;
      final nextPage = (_currentPage + 1) % widget.seriesList.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seriesList.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.seriesList.length,
            itemBuilder: (context, index) {
              final series = widget.seriesList[index];
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
                        heroTag: 'hero_featured_${widget.categoryTitle}_${series.coreName}',
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'hero_featured_${widget.categoryTitle}_${series.coreName}',
                        child: TdThumbnail(
                          file: posterFile,
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
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.9),
                            ],
                            stops: const [0.4, 0.7, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'FEATURED',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              series.coreName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.seriesList.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index ? Colors.orange : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
