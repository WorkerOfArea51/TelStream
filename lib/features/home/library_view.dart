import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../models/anime_models.dart';
import '../../services/storage_service.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import '../../core/widgets/shimmer_card.dart';
import 'home_controller.dart';
import 'episode_list_screen.dart';
import '../player/pip_manager.dart';
import '../settings/settings_provider.dart';

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

  int _getCrossAxisCount(BuildContext context, String layout) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = layout == 'Compact';
    final isList = layout == 'List';
    
    if (isList) return 1;
    
    if (width > 1600) {
      return isCompact ? 10 : 8;
    } else if (width > 1200) {
      return isCompact ? 8 : 6;
    } else if (width > 800) {
      return isCompact ? 6 : 4;
    } else {
      return isCompact ? 3 : 2; // Mobile fallback
    }
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
    final settings = ref.watch(videoSettingsProvider);
    final layout = settings.getLayoutForCategory(widget.category.title);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(116),
        child: Container(
          color: theme.cardColor,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _isSearching
                            ? Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(color: textColor),
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Search...',
                                    hintStyle: TextStyle(color: subTextColor),
                                    border: InputBorder.none,
                                    icon: Icon(Icons.search, color: subTextColor, size: 20),
                                  ),
                                  onChanged: (val) {
                                    ref.read(provider.notifier).search(val);
                                  },
                                ),
                              )
                            : Text(
                                '${ref.watch(provider.notifier).resolvedChatTitle} ${state.value != null ? "(${_getFilteredList(state.value!, favorites, isDownloadedOnly).length})" : ""}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                              ),
                      ),
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
                      PopupMenuButton<String>(
                        icon: Icon(
                          layout == 'Grid'
                              ? Icons.grid_view
                              : layout == 'Compact'
                                  ? Icons.apps
                                  : Icons.view_list,
                          color: subTextColor,
                        ),
                        color: theme.cardColor,
                        onSelected: (String selectedLayout) {
                          ref.read(videoSettingsProvider.notifier).updateSettings(
                            settings.copyWithLayoutForCategory(widget.category.title, selectedLayout),
                          );
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'Grid',
                            child: Row(
                              children: [
                                Icon(Icons.grid_view, color: layout == 'Grid' ? theme.primaryColor : subTextColor),
                                const SizedBox(width: 12),
                                Text('Grid View', style: TextStyle(color: textColor)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'Compact',
                            child: Row(
                              children: [
                                Icon(Icons.apps, color: layout == 'Compact' ? theme.primaryColor : subTextColor),
                                const SizedBox(width: 12),
                                Text('Compact Grid', style: TextStyle(color: textColor)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'List',
                            child: Row(
                              children: [
                                Icon(Icons.view_list, color: layout == 'List' ? theme.primaryColor : subTextColor),
                                const SizedBox(width: 12),
                                Text('List View', style: TextStyle(color: textColor)),
                              ],
                            ),
                          ),
                        ],
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
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _subTabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: theme.primaryColor,
                    labelColor: theme.primaryColor,
                    unselectedLabelColor: subTextColor,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Favorites'),
                    ],
                  ),
                ),
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
                if (!_isSearching && _activeSubTabIndex == 0 && _searchController.text.isEmpty && filteredList.isNotEmpty)
                  _buildContinueWatchingSliver(context, filteredList),
                SliverPadding(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 96),
                  sliver: layout == 'List'
                      ? SliverList(
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
                              return _LibraryListItem(
                                series: series,
                                categoryTitle: widget.category.title,
                              );
                            },
                            childCount: filteredList.length + (ref.watch(provider.notifier).hasMore ? 1 : 0),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _getCrossAxisCount(context, layout),
                            childAspectRatio: layout == 'Compact' ? 0.7 : 0.72,
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
                              if (layout == 'Compact') {
                                return _LibraryCompactItem(
                                  series: series,
                                  categoryTitle: widget.category.title,
                                );
                              }
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
        loading: () {
          final settings = ref.watch(videoSettingsProvider);
          final layout = settings.getLayoutForCategory(widget.category.title);
          if (layout == 'List') {
            return ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 96),
              itemCount: 6,
              itemBuilder: (context, index) => const _LibraryListShimmerItem(),
            );
          }
          final isCompact = layout == 'Compact';
          return GridView.builder(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 96),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context, layout),
              childAspectRatio: isCompact ? 0.7 : 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => const ShimmerCard(),
          );
        },
        error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
      ),
    );
  }

  Widget _buildContinueWatchingSliver(BuildContext context, List<AnimeSeries> seriesList) {
    final history = ref.watch(historyLogProvider);
    final storage = ref.read(storageServiceProvider);

    final continueWatchingItems = history.where((item) {
      final hasSeries = seriesList.any((s) => s.coreName == item['seriesName']);
      if (!hasSeries) return false;

      final msgId = item['messageId'] as int;
      final pos = item['position'] as int;
      final dur = storage.getVideoDuration(msgId);
      if (dur > 0) {
        final progress = pos / dur;
        return progress < 0.95 && progress > 0.01;
      }
      return pos > 0;
    }).toList();

    if (continueWatchingItems.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: ContinueWatchingShelf(
        items: continueWatchingItems,
        seriesList: seriesList,
        ref: ref,
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
              backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
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
    return _LibraryGridItem(
      series: series,
      categoryTitle: widget.category.title,
    );
  }
}

class _LibraryGridItem extends StatefulWidget {
  final AnimeSeries series;
  final String categoryTitle;

  const _LibraryGridItem({
    required this.series,
    required this.categoryTitle,
  });

  @override
  State<_LibraryGridItem> createState() => _LibraryGridItemState();
}

class _LibraryGridItemState extends State<_LibraryGridItem> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalEpisodes = widget.series.seasons.fold(0, (sum, s) => sum + s.episodes.length);
    final latestPoster = widget.series.seasons.isNotEmpty ? widget.series.seasons.first.posterMessage : null;
    
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
      onTapDown: (_) => setState(() => _isTapped = true),
      onTapUp: (_) => setState(() => _isTapped = false),
      onTapCancel: () => setState(() => _isTapped = false),
      onTap: () {
        Navigator.push(
          context,
          PremiumPageRoute(
            child: EpisodeListScreen(
              season: widget.series.seasons.first,
              series: widget.series,
              heroTag: 'hero_library_${widget.categoryTitle}_${widget.series.coreName}',
              categoryTitle: widget.categoryTitle,
            ),
          ),
        );
      },
      child: AnimatedScale(
        scale: _isTapped ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: _isTapped ? 0.16 : 0.08),
              width: _isTapped ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: _isTapped ? 4 : 8,
                offset: Offset(0, _isTapped ? 2 : 4),
              )
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'hero_library_${widget.categoryTitle}_${widget.series.coreName}',
                child: TdThumbnail(
                  file: posterFile,
                  minithumbnail: minithumbnail,
                  autoDownload: true,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
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
                      Colors.black.withValues(alpha: 0.95),
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
                  text: widget.series.coreName,
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
                    color: Colors.black.withValues(alpha: 0.65),
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
      ),
    );
  }
}

class FeaturedCarousel extends StatefulWidget {
  final List<AnimeSeries> seriesList;
  final String categoryTitle;

  const FeaturedCarousel({
    super.key,
    required this.seriesList,
    required this.categoryTitle,
  });

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
                          categoryTitle: widget.categoryTitle,
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

class ContinueWatchingShelf extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final List<AnimeSeries> seriesList;
  final WidgetRef ref;

  const ContinueWatchingShelf({
    super.key,
    required this.items,
    required this.seriesList,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 12.0),
          child: Row(
            children: [
              Icon(Icons.play_circle_outline, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Continue Watching',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final seriesName = item['seriesName'] as String;
              final episodeTitle = item['episodeTitle'] as String;
              final msgId = item['messageId'] as int;
              final pos = item['position'] as int;
              
              final storage = ref.read(storageServiceProvider);
              final dur = storage.getVideoDuration(msgId);
              
              double progress = 0.0;
              if (dur > 0) {
                progress = (pos / dur).clamp(0.0, 1.0);
              }

              // Resolve poster
              AnimeSeries? matchedSeries;
              try {
                matchedSeries = seriesList.firstWhere((s) => s.coreName == seriesName);
              } catch (_) {}

              td.File? posterFile;
              td.Minithumbnail? minithumbnail;
              if (matchedSeries != null && matchedSeries.seasons.isNotEmpty) {
                final latestPoster = matchedSeries.seasons.first.posterMessage;
                if (latestPoster.content is td.MessagePhoto) {
                  final photo = latestPoster.content as td.MessagePhoto;
                  if (photo.photo.sizes.isNotEmpty) {
                    posterFile = photo.photo.sizes.last.photo;
                  }
                  minithumbnail = photo.photo.minithumbnail;
                }
              }

              return Container(
                width: 220,
                margin: const EdgeInsets.symmetric(horizontal: 6.0),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20), // Premium M3 Expressive card style
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    // Play video
                    List<td.Message>? episodeList;
                    int? episodeIndex;
                    int? videoFileId;

                    if (matchedSeries != null) {
                      for (final season in matchedSeries.seasons) {
                        if (season.episodes.isNotEmpty) {
                          final idx = season.episodes.indexWhere((ep) => ep.id == msgId);
                          if (idx != -1) {
                            episodeList = season.episodes;
                            episodeIndex = idx;
                            break;
                          }
                        }
                      }
                    }

                    if (episodeList != null && episodeIndex != null) {
                      final msg = episodeList[episodeIndex];
                      if (msg.content is td.MessageVideo) {
                        videoFileId = (msg.content as td.MessageVideo).video.video.id;
                      } else if (msg.content is td.MessageDocument) {
                        videoFileId = (msg.content as td.MessageDocument).document.document.id;
                      }
                    }

                    // Fallback to stored id if we couldn't resolve it from active episodes
                    videoFileId ??= item['videoFileId'] as int?;

                    if (videoFileId != null) {
                      ref.read(pipControllerProvider.notifier).playVideo(
                        context,
                        messageId: msgId,
                        videoFileId: videoFileId,
                        videoTitle: '$seriesName - $episodeTitle',
                        episodeList: episodeList,
                        currentEpisodeIndex: episodeIndex,
                        seriesName: seriesName,
                      );
                    }
                  },
                  child: Stack(
                    children: [
                      // Thumbnail
                      Positioned.fill(
                        bottom: 48,
                        child: TdThumbnail(
                          file: posterFile,
                          minithumbnail: minithumbnail,
                          autoDownload: true,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      // Semi-transparent gradient over thumbnail
                      Positioned.fill(
                        bottom: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Play icon overlay
                      Positioned(
                        top: 24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              color: theme.primaryColor,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      // Metadata area
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seriesName,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              episodeTitle,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                      // Progress Bar
                      if (progress > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _LibraryCompactItem extends StatefulWidget {
  final AnimeSeries series;
  final String categoryTitle;

  const _LibraryCompactItem({
    required this.series,
    required this.categoryTitle,
  });

  @override
  State<_LibraryCompactItem> createState() => _LibraryCompactItemState();
}

class _LibraryCompactItemState extends State<_LibraryCompactItem> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalEpisodes = widget.series.seasons.fold(0, (sum, s) => sum + s.episodes.length);
    final latestPoster = widget.series.seasons.isNotEmpty ? widget.series.seasons.first.posterMessage : null;
    
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
      onTapDown: (_) => setState(() => _isTapped = true),
      onTapUp: (_) => setState(() => _isTapped = false),
      onTapCancel: () => setState(() => _isTapped = false),
      onTap: () {
        Navigator.push(
          context,
          PremiumPageRoute(
            child: EpisodeListScreen(
              season: widget.series.seasons.first,
              series: widget.series,
              heroTag: 'hero_library_${widget.categoryTitle}_${widget.series.coreName}',
              categoryTitle: widget.categoryTitle,
            ),
          ),
        );
      },
      child: AnimatedScale(
        scale: _isTapped ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: _isTapped ? 0.16 : 0.08),
              width: _isTapped ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: _isTapped ? 4 : 8,
                offset: Offset(0, _isTapped ? 2 : 4),
              )
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'hero_library_${widget.categoryTitle}_${widget.series.coreName}',
                child: TdThumbnail(
                  file: posterFile,
                  minithumbnail: minithumbnail,
                  autoDownload: true,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
                ),
              ),
              
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill, color: theme.primaryColor, size: 9),
                      const SizedBox(width: 3),
                      Text(
                        totalEpisodes.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
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
      ),
    );
  }
}

class _LibraryListItem extends ConsumerStatefulWidget {
  final AnimeSeries series;
  final String categoryTitle;

  const _LibraryListItem({
    required this.series,
    required this.categoryTitle,
  });

  @override
  ConsumerState<_LibraryListItem> createState() => _LibraryListItemState();
}

class _LibraryListItemState extends ConsumerState<_LibraryListItem> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    final storage = ref.read(storageServiceProvider);

    final totalEpisodes = widget.series.seasons.fold(0, (sum, s) => sum + s.episodes.length);

    final years = widget.series.seasons
        .map((s) => s.getReleaseYear(storage))
        .where((y) => y != null && y > 0)
        .cast<int>()
        .toSet()
        .toList();
    years.sort();
    
    final String yearsText;
    if (years.isEmpty) {
      yearsText = '';
    } else if (years.length == 1) {
      yearsText = years.first.toString();
    } else {
      yearsText = '${years.first}–${years.last}';
    }

    final latestPoster = widget.series.seasons.isNotEmpty ? widget.series.seasons.first.posterMessage : null;
    
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
      onTapDown: (_) => setState(() => _isTapped = true),
      onTapUp: (_) => setState(() => _isTapped = false),
      onTapCancel: () => setState(() => _isTapped = false),
      onTap: () {
        Navigator.push(
          context,
          PremiumPageRoute(
            child: EpisodeListScreen(
              season: widget.series.seasons.first,
              series: widget.series,
              heroTag: 'hero_library_${widget.categoryTitle}_${widget.series.coreName}',
              categoryTitle: widget.categoryTitle,
            ),
          ),
        );
      },
      child: AnimatedScale(
        scale: _isTapped ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: _isTapped ? 0.16 : 0.08),
              width: _isTapped ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: _isTapped ? 2 : 4,
                offset: Offset(0, _isTapped ? 1 : 2),
              )
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.hardEdge,
                child: Hero(
                  tag: 'hero_library_${widget.categoryTitle}_${widget.series.coreName}',
                  child: TdThumbnail(
                    file: posterFile,
                    minithumbnail: minithumbnail,
                    autoDownload: true,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AlignedNameText(
                      text: widget.series.coreName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (widget.categoryTitle == 'Movies') ...[
                          Icon(Icons.movie, size: 12, color: subTextColor),
                          const SizedBox(width: 4),
                          Text(
                            'Movie',
                            style: TextStyle(color: subTextColor, fontSize: 12),
                          ),
                        ] else ...[
                          Icon(Icons.play_circle_outline, size: 12, color: subTextColor),
                          const SizedBox(width: 4),
                          Text(
                            '$totalEpisodes Episode${totalEpisodes > 1 ? "s" : ""}',
                            style: TextStyle(color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    if (yearsText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: subTextColor),
                          const SizedBox(width: 4),
                          Text(
                            yearsText,
                            style: TextStyle(color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: subTextColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryListShimmerItem extends StatelessWidget {
  const _LibraryListShimmerItem();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;

    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 84,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
