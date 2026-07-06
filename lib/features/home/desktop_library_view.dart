import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;

import '../../core/constants.dart';
import '../../models/anime_models.dart';
import '../../services/storage_service.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import '../settings/settings_provider.dart';
import 'home_controller.dart';
import 'desktop_state.dart';
import 'desktop_library_widgets.dart';

class DesktopLibraryView extends ConsumerStatefulWidget {
  final ChannelCategory category;

  const DesktopLibraryView({super.key, required this.category});

  @override
  ConsumerState<DesktopLibraryView> createState() => _DesktopLibraryViewState();
}

class _DesktopLibraryViewState extends ConsumerState<DesktopLibraryView> {
  late final AsyncNotifierProvider<HomeController, List<AnimeSeries>> provider;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showFavoritesOnly = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    provider = widget.category.title == 'Anime'
        ? animeControllerProvider as AsyncNotifierProvider<HomeController, List<AnimeSeries>>
        : widget.category.title == 'Movies'
            ? moviesControllerProvider as AsyncNotifierProvider<HomeController, List<AnimeSeries>>
            : webSeriesControllerProvider as AsyncNotifierProvider<HomeController, List<AnimeSeries>>;

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(provider.notifier).loadMore();
      }
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() {});
    });
  }

  List<AnimeSeries> _getFilteredList(List<AnimeSeries> list) {
    final search = _searchController.text.toLowerCase();
    final storage = ref.read(storageServiceProvider);

    return list.where((series) {
      if (_showFavoritesOnly) {
        final isFav = storage.isFavorite(series.coreName);
        if (!isFav) return false;
      }
      if (search.isEmpty) return true;
      return series.coreName.toLowerCase().contains(search);
    }).toList();
  }

  Widget _buildContinueWatchingSliver(BuildContext context, List<AnimeSeries> allSeries) {
    final storage = ref.watch(storageServiceProvider);
    final history = storage.getHistoryLog();
    final continueWatchingItems = history.where((item) {
      return item['category'] == widget.category.title;
    }).toList();

    continueWatchingItems.sort((a, b) {
      final ta = a['timestamp'] as int? ?? 0;
      final tb = b['timestamp'] as int? ?? 0;
      return tb.compareTo(ta);
    });

    if (continueWatchingItems.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: DesktopContinueWatchingShelf(
        items: continueWatchingItems.take(10).toList(),
        seriesList: allSeries,
        ref: ref,
        categoryTitle: widget.category.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provider);
    final isSyncing = ref.watch(isSyncingProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(videoSettingsProvider);
    final layout = settings.getLayoutForCategory(widget.category.title);
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;
    final subTextColor = theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          state.when(
            data: (seriesList) {
              final filteredList = _getFilteredList(seriesList);

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Featured Carousel
                  if (!_isSearching && !_showFavoritesOnly && _searchController.text.isEmpty && filteredList.isNotEmpty)
                    SliverToBoxAdapter(
                      child: DesktopFeaturedCarousel(
                        seriesList: filteredList.take(6).toList(),
                        categoryTitle: widget.category.title,
                      ),
                    ),
                    
                  // Continue Watching
                  if (!_isSearching && !_showFavoritesOnly && _searchController.text.isEmpty && filteredList.isNotEmpty)
                    _buildContinueWatchingSliver(context, filteredList),

                  // Sort & Layout Bar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverSortHeaderDelegate(
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        color: theme.scaffoldBackgroundColor.withOpacity(0.95),
                        child: Row(
                          children: [
                            Text(
                              _showFavoritesOnly ? 'Favorites (${filteredList.length})' : 'All ${widget.category.title} (${filteredList.length})',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const Spacer(),
                            // Search Toggle
                            if (_isSearching) ...[
                              SizedBox(
                                width: 200,
                                height: 36,
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(color: textColor, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Search...',
                                    hintStyle: TextStyle(color: subTextColor),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: theme.cardColor,
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.close, size: 16, color: subTextColor),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _isSearching = false);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ] else
                              const SizedBox(width: 8),
                            
                            // Favorites Toggle
                            IconButton(
                              icon: Icon(
                                _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                                color: _showFavoritesOnly ? Colors.red : subTextColor,
                              ),
                              onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                            ),
                            
                            // Sort Dropdown
                            PopupMenuButton<SortOrder>(
                              icon: Icon(Icons.sort, color: subTextColor),
                              color: theme.cardColor,
                              onSelected: (SortOrder order) {
                                ref.read(provider.notifier).setSortOrder(order);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: SortOrder.aToZ,
                                  child: Text('Name (A-Z)', style: TextStyle(color: textColor)),
                                ),
                                PopupMenuItem(
                                  value: SortOrder.zToA,
                                  child: Text('Name (Z-A)', style: TextStyle(color: textColor)),
                                ),
                                PopupMenuItem(
                                  value: SortOrder.newest,
                                  child: Text('Newest First', style: TextStyle(color: textColor)),
                                ),
                                PopupMenuItem(
                                  value: SortOrder.oldest,
                                  child: Text('Oldest First', style: TextStyle(color: textColor)),
                                ),
                              ],
                            ),

                            // Layout Dropdown
                            PopupMenuButton<String>(
                              icon: Icon(
                                layout == 'Grid' ? Icons.grid_view : (layout == 'Compact' ? Icons.view_comfy : Icons.view_list),
                                color: subTextColor,
                              ),
                              color: theme.cardColor,
                              onSelected: (String value) {
                                ref
                                    .read(videoSettingsProvider.notifier)
                                    .updateSettings(
                                      settings.copyWithLayoutForCategory(
                                        widget.category.title,
                                        value,
                                      ),
                                    );
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'Grid', child: Text('Grid View', style: TextStyle(color: textColor))),
                                PopupMenuItem(value: 'Compact', child: Text('Compact View', style: TextStyle(color: textColor))),
                                PopupMenuItem(value: 'List', child: Text('List View', style: TextStyle(color: textColor))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Main Content
                  if (filteredList.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(
                              isSyncing ? 'Syncing...' : 'No ${widget.category.title} found',
                              style: const TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (layout == 'Grid')
                    SliverPadding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 80),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= filteredList.length) return const _DesktopShimmerCard();
                            return DesktopPosterCard(
                              series: filteredList[index],
                              categoryTitle: widget.category.title,
                            );
                          },
                          childCount: filteredList.length + (isSyncing ? 3 : 0),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= filteredList.length) return const SizedBox.shrink(); // Add shimmer later if needed
                            return DesktopListItem(
                              series: filteredList[index],
                              categoryTitle: widget.category.title,
                              isCompact: layout == 'Compact',
                            );
                          },
                          childCount: filteredList.length,
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ),
          if (isSyncing)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      const Text('Syncing cloud...', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SliverSortHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverSortHeaderDelegate({required this.child});

  @override
  double get minExtent => 56.0;
  @override
  double get maxExtent => 56.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SliverSortHeaderDelegate oldDelegate) {
    return true;
  }
}

class DesktopPosterCard extends ConsumerStatefulWidget {
  final AnimeSeries series;
  final String categoryTitle;

  const DesktopPosterCard({
    super.key,
    required this.series,
    required this.categoryTitle,
  });

  @override
  ConsumerState<DesktopPosterCard> createState() => _DesktopPosterCardState();
}

class _DesktopPosterCardState extends ConsumerState<DesktopPosterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    td.File? posterFile;
    td.Minithumbnail? minithumbnail;

    if (widget.series.seasons.isNotEmpty) {
      final latestPoster = widget.series.seasons.first.posterMessage;
      if (latestPoster.content is td.MessagePhoto) {
        final photo = latestPoster.content as td.MessagePhoto;
        if (photo.photo.sizes.isNotEmpty) {
          posterFile = photo.photo.sizes.last.photo;
        }
        minithumbnail = photo.photo.minithumbnail;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref.read(desktopSelectedSeriesProvider.notifier).state = widget.series;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]
                : [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: posterFile != null
                    ? TdThumbnail(
                        file: posterFile,
                        minithumbnail: minithumbnail,
                        autoDownload: true,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.zero,
                      )
                    : Container(color: Colors.grey[900]),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.series.coreName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.folder, size: 12, color: theme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.series.seasons.length} Season${widget.series.seasons.length > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopListItem extends ConsumerStatefulWidget {
  final AnimeSeries series;
  final String categoryTitle;
  final bool isCompact;

  const DesktopListItem({
    super.key,
    required this.series,
    required this.categoryTitle,
    this.isCompact = false,
  });

  @override
  ConsumerState<DesktopListItem> createState() => _DesktopListItemState();
}

class _DesktopListItemState extends ConsumerState<DesktopListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalEpisodes = widget.series.seasons.fold(0, (sum, s) => sum + s.episodes.length);
    td.File? posterFile;
    td.Minithumbnail? minithumbnail;

    if (widget.series.seasons.isNotEmpty) {
      final latestPoster = widget.series.seasons.first.posterMessage;
      if (latestPoster.content is td.MessagePhoto) {
        final photo = latestPoster.content as td.MessagePhoto;
        if (photo.photo.sizes.isNotEmpty) {
          posterFile = photo.photo.sizes.last.photo;
        }
        minithumbnail = photo.photo.minithumbnail;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref.read(desktopSelectedSeriesProvider.notifier).state = widget.series;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 12),
          height: widget.isCompact ? 70 : 100,
          decoration: BoxDecoration(
            color: _isHovered ? theme.primaryColor.withOpacity(0.1) : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? theme.primaryColor.withOpacity(0.5) : Colors.white10,
              width: _isHovered ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: widget.isCompact ? 40 : 60,
                height: widget.isCompact ? 56 : 84,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                clipBehavior: Clip.hardEdge,
                child: TdThumbnail(
                  file: posterFile,
                  minithumbnail: minithumbnail,
                  autoDownload: true,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
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
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!widget.isCompact) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.play_circle_outline, size: 12, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            '$totalEpisodes Episode${totalEpisodes > 1 ? "s" : ""}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopShimmerCard extends StatelessWidget {
  const _DesktopShimmerCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
