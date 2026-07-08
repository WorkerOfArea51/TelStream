import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;

import '../../models/anime_models.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import '../../services/storage_service.dart';
import 'desktop_state.dart';

class DesktopFeaturedCarousel extends StatefulWidget {
  final List<AnimeSeries> seriesList;
  final String categoryTitle;

  const DesktopFeaturedCarousel({
    super.key,
    required this.seriesList,
    required this.categoryTitle,
  });

  @override
  State<DesktopFeaturedCarousel> createState() => _DesktopFeaturedCarouselState();
}

class _DesktopFeaturedCarouselState extends State<DesktopFeaturedCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 0.85);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
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

    return Column(
      children: [
        SizedBox(
          height: 380,
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
              final latestPoster = series.seasons.isNotEmpty
                  ? series.seasons.first.posterMessage
                  : null;

              td.File? posterFile;
              td.Minithumbnail? minithumbnail;
              if (latestPoster != null &&
                  latestPoster.content is td.MessagePhoto) {
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
                  return Transform.scale(scale: value, child: child);
                },
                child: Consumer(
                  builder: (context, ref, child) {
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(desktopSelectedSeriesProvider.notifier).state = series;
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              TdThumbnail(
                                file: posterFile,
                                minithumbnail: minithumbnail,
                                autoDownload: true,
                                width: double.infinity,
                                height: double.infinity,
                                alignment: Alignment.topCenter,
                                borderRadius: BorderRadius.zero,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.2),
                                      Colors.black.withValues(alpha: 0.9),
                                    ],
                                    stops: const [0.4, 0.7, 1.0],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 24,
                                right: 24,
                                bottom: 24,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'FEATURED',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
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
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
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
              width: _currentPage == index ? 24 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? theme.primaryColor
                    : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class DesktopContinueWatchingShelf extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final List<AnimeSeries> seriesList;
  final WidgetRef ref;
  final String categoryTitle;

  const DesktopContinueWatchingShelf({
    super.key,
    required this.items,
    required this.seriesList,
    required this.ref,
    required this.categoryTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24.0, top: 8.0, bottom: 12.0),
          child: Row(
            children: [
              Icon(Icons.play_circle_outline, color: theme.primaryColor, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Continue Watching',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                matchedSeries = seriesList.firstWhere(
                  (s) => s.coreName == seriesName,
                );
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

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 260,
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GestureDetector(
                    onTap: () {
                      if (matchedSeries != null) {
                        ref.read(desktopSelectedSeriesProvider.notifier).state = matchedSeries;
                        td.Message? epMsg;
                        for (final season in matchedSeries.seasons) {
                          try {
                            epMsg = season.episodes.firstWhere((ep) => ep.id == msgId);
                            break;
                          } catch (_) {}
                        }
                        if (epMsg != null) {
                          ref.read(desktopSelectedEpisodeProvider.notifier).state = epMsg;
                        }
                      }
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          bottom: 56,
                          child: TdThumbnail(
                            file: posterFile,
                            minithumbnail: minithumbnail,
                            autoDownload: true,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned.fill(
                          bottom: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          bottom: 56,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white30),
                              ),
                              child: Icon(Icons.play_arrow, color: theme.primaryColor, size: 28),
                            ),
                          ),
                        ),
                        if (progress > 0)
                          Positioned(
                            bottom: 56,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.black,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                              minHeight: 3,
                            ),
                          ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 8,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      seriesName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      episodeTitle,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 16,
                                onPressed: () {
                                  ref.read(historyLogProvider.notifier).removeFromHistory(msgId);
                                },
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
      ],
    );
  }
}
