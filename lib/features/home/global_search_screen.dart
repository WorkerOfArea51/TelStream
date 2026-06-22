import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../models/anime_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/constants.dart';
import '../../services/storage_service.dart';
import 'home_controller.dart';
import 'episode_list_screen.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    List<int> v0 = List.generate(b.length + 1, (i) => i);
    List<int> v1 = List.filled(b.length + 1, 0);
    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((min, val) => val < min ? val : min);
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[b.length];
  }

  List<AnimeSeries> _filterSeries(List<AnimeSeries> source, String query) {
    if (query.isEmpty) return [];
    final queryWords = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    return source.where((series) {
      final seriesName = series.coreName.toLowerCase();
      final seasonNames = series.seasons.map((s) => s.fullTitle.toLowerCase()).join(' ');
      final fullText = '$seriesName $seasonNames';
      final textWords = fullText.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();

      bool allWordsMatch = true;
      for (var qw in queryWords) {
        bool wordFound = false;
        for (var tw in textWords) {
          if (tw.startsWith(qw) || tw.contains(qw)) {
            wordFound = true;
            break;
          }
          if (qw.length > 4 && tw.length > 4) {
            if (_levenshtein(qw, tw) <= 2) {
              wordFound = true;
              break;
            }
          }
        }
        if (!wordFound) {
          allWordsMatch = false;
          break;
        }
      }
      return allWordsMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    final animeList = ref.watch(animeControllerProvider).value ?? [];
    final moviesList = ref.watch(moviesControllerProvider).value ?? [];
    final webSeriesList = ref.watch(webSeriesControllerProvider).value ?? [];
    final searchHistory = ref.watch(searchHistoryProvider('global'));

    final animeResults = _filterSeries(animeList, _query);
    final moviesResults = _filterSeries(moviesList, _query);
    final webSeriesResults = _filterSeries(webSeriesList, _query);

    final int totalResults = animeResults.length + moviesResults.length + webSeriesResults.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search Anime, Movies, Web Series...',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            border: InputBorder.none,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: settingsAccent),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                      });
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            setState(() {
              _query = val;
            });
          },
          onSubmitted: (val) {
            final clean = val.trim();
            if (clean.isNotEmpty) {
              ref.read(searchHistoryProvider('global').notifier).addQuery(clean);
            }
          },
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: _query.isEmpty
          ? (searchHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded, size: 72, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 16),
                      Text(
                        'Search library dynamically',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type letters to search with fuzzy tolerance',
                        style: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Searches',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            ref.read(searchHistoryProvider('global').notifier).clearHistory();
                          },
                          icon: Icon(Icons.delete_outline, size: 16, color: settingsAccent),
                          label: Text(
                            'Clear All',
                            style: TextStyle(color: settingsAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...searchHistory.map((q) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.history, color: isDark ? Colors.white30 : Colors.black26),
                          title: Text(
                            q,
                            style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              ref.read(searchHistoryProvider('global').notifier).removeQuery(q);
                            },
                          ),
                          onTap: () {
                            _searchController.text = q;
                            setState(() {
                              _query = q;
                            });
                          },
                        )),
                  ],
                ))
          : totalResults == 0
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sentiment_dissatisfied_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 16),
                      Text(
                        'No results found for "$_query"',
                        style: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    if (animeResults.isNotEmpty)
                      _buildCategorySection('Anime', animeResults, 'anime_search'),
                    if (moviesResults.isNotEmpty)
                      _buildCategorySection('Movies', moviesResults, 'movies_search'),
                    if (webSeriesResults.isNotEmpty)
                      _buildCategorySection('Web Series', webSeriesResults, 'web_series_search'),
                  ],
                ),
    );
  }

  Widget _buildCategorySection(String title, List<AnimeSeries> results, String heroPrefix) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: settingsAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$title (${results.length})',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final series = results[index];
            final season = series.seasons.first; // Navigate to first season by default
            final heroTag = '${heroPrefix}_${series.coreName}_$index';

            td.File? posterFile;
            td.Minithumbnail? minithumbnail;
            if (season.posterMessage.content is td.MessagePhoto) {
              final photo = season.posterMessage.content as td.MessagePhoto;
              if (photo.photo.sizes.isNotEmpty) {
                posterFile = photo.photo.sizes.last.photo;
              }
              minithumbnail = photo.photo.minithumbnail;
            }

            return GestureDetector(
              onTap: () {
                final clean = _query.trim();
                if (clean.isNotEmpty) {
                  ref.read(searchHistoryProvider('global').notifier).addQuery(clean);
                }
                Navigator.push(
                  context,
                  PremiumPageRoute(
                    child: EpisodeListScreen(
                      series: series,
                      season: season,
                      heroTag: heroTag,
                      categoryTitle: title,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Hero(
                        tag: heroTag,
                        child: TdThumbnail(
                          file: posterFile,
                          minithumbnail: minithumbnail,
                          autoDownload: true,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    series.coreName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
