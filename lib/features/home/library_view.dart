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
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredList.length + (ref.watch(provider.notifier).hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == filteredList.length) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                
                final series = filteredList[index];
                return _buildGridItem(context, series);
              },
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
