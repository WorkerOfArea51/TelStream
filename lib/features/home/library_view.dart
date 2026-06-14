import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../models/anime_models.dart';
import '../../services/storage_service.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    final state = ref.watch(provider);
    final favorites = ref.watch(favoritesProvider);
    final isDownloadedOnly = ref.watch(downloadedOnlyProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: subTextColor),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  ref.read(provider.notifier).search(val);
                },
              )
            : Text(
                '${ref.watch(provider.notifier).resolvedChatTitle} ${state.value != null ? "(${_getFilteredList(state.value!, favorites, isDownloadedOnly).length})" : ""}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: Icon(Icons.close, color: subTextColor),
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
              icon: Icon(Icons.search, color: subTextColor),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          PopupMenuButton<SortOrder>(
            icon: Icon(Icons.sort, color: subTextColor),
            color: theme.cardColor,
            onSelected: (SortOrder order) {
              ref.read(provider.notifier).setSortOrder(order);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: SortOrder.aToZ, child: Text('Name (A-Z)', style: TextStyle(color: textColor))),
              PopupMenuItem(value: SortOrder.zToA, child: Text('Name (Z-A)', style: TextStyle(color: textColor))),
              PopupMenuItem(value: SortOrder.newest, child: Text('Newest First', style: TextStyle(color: textColor))),
              PopupMenuItem(value: SortOrder.oldest, child: Text('Oldest First', style: TextStyle(color: textColor))),
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
              indicatorColor: theme.primaryColor,
              labelColor: theme.primaryColor,
              unselectedLabelColor: subTextColor,
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
            color: theme.primaryColor,
            backgroundColor: theme.cardColor,
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
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 96),
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
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: CircularProgressIndicator(color: theme.primaryColor),
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
        loading: () => Center(child: CircularProgressIndicator(color: theme.primaryColor)),
        error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    // Return Tachiyomi styled empty layout with beautiful kaomoji
    final kaomoji = _activeSubTabIndex == 1 ? '(・_・;)' : '(・○・;)';
    final message = _activeSubTabIndex == 1 ? 'No favorites in this category' : 'Your library is empty';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            kaomoji,
            style: TextStyle(fontSize: 48, color: theme.primaryColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: subTextColor, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              foregroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.primaryColor, width: 1),
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
    final theme = Theme.of(context);
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
              heroTag: 'hero_library_${widget.category.title}_${series.coreName}',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'hero_library_${widget.category.title}_${series.coreName}',
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
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.95),
                  ],
                  stops: const [0.4, 0.7, 1.0],
                ),
              ),
            ),
            
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: AlignedNameText(
                text: series.coreName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Glassmorphic pill badge for total episodes available
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_fill, color: theme.primaryColor, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      totalEpisodes.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
    _pageController = PageController(initialPage: 0, viewportFraction: 0.75);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          height: 360,
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
              td.Minithumbnail? minithumbnail;
              if (latestPoster != null && latestPoster.content is td.MessagePhoto) {
                final photo = latestPoster.content as td.MessagePhoto;
                if (photo.photo.sizes.isNotEmpty) {
                  posterFile = photo.photo.sizes.last.photo;
                }
                minithumbnail = photo.photo.minithumbnail;
              }

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.1)).clamp(0.9, 1.0);
                  } else {
                    value = _currentPage == index ? 1.0 : 0.9;
                  }
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      PremiumPageRoute(
                        child: EpisodeListScreen(
                          season: series.seasons.first,
                          series: series,
                          heroTag: 'hero_featured_${widget.categoryTitle}_${series.coreName}',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'FEATURED',
                                  style: TextStyle(
                                    color: theme.primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              AlignedNameText(
                                text: series.coreName,
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
                color: _currentPage == index ? theme.primaryColor : (isDark ? Colors.white24 : Colors.black26),
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
