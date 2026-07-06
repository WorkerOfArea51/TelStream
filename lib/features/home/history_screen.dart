import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../services/storage_service.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/widgets/aligned_name_text.dart';
import '../player/pip_manager.dart';
import 'home_controller.dart';
import '../../models/anime_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants.dart';
import 'dart:io';
import 'android_episode_list_screen.dart';
import 'desktop_state.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedSeries = {};

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dt);
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.toString();
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _confirmClearHistory(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
        ),
        title: Text('Clear History', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to clear your watch history? This cannot be undone.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(historyLogProvider.notifier).clearHistory();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Watch history cleared'),
                  ),
                );
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyLogs = ref.watch(historyLogProvider);
    
    final animeList = ref.watch(animeControllerProvider).value ?? [];
    final moviesList = ref.watch(moviesControllerProvider).value ?? [];
    final webSeriesList = ref.watch(webSeriesControllerProvider).value ?? [];
    
    final allSeries = [...animeList, ...moviesList, ...webSeriesList];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    // Filter logs based on master search query
    final filteredLogs = historyLogs.where((log) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final seriesName = (log['seriesName'] as String).toLowerCase();
      final episodeTitle = (log['episodeTitle'] as String).toLowerCase();
      return seriesName.contains(query) || episodeTitle.contains(query);
    }).toList();

    // Group logs by seriesName
    final Map<String, List<Map<String, dynamic>>> groupedLogs = {};
    for (final log in filteredLogs) {
      final seriesName = log['seriesName'] as String;
      groupedLogs.putIfAbsent(seriesName, () => []).add(log);
    }

    // Sort series names by newest watch timestamp first
    final sortedSeriesNames = groupedLogs.keys.toList()
      ..sort((a, b) {
        final timeA = groupedLogs[a]!.first['timestamp'] as int;
        final timeB = groupedLogs[b]!.first['timestamp'] as int;
        return timeB.compareTo(timeA);
      });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Watch History',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          if (historyLogs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.orangeAccent),
              onPressed: () => _confirmClearHistory(context),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search history...',
                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: settingsAccent),
                ),
                onChanged: (val) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 250), () {
                    if (mounted) {
                      setState(() {
                        _searchQuery = val;
                      });
                    }
                  });
                },
              ),
            ),
          ),
        ),
      ),
      body: historyLogs.isEmpty
          ? _buildEmptyState()
          : filteredLogs.isEmpty
              ? Center(
                  child: Text(
                    'No matching history entries',
                    style: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedSeriesNames.length,
                  itemBuilder: (context, index) {
                    final seriesName = sortedSeriesNames[index];
                    final seriesLogs = groupedLogs[seriesName]!;
                    final isExpanded = _expandedSeries.contains(seriesName);

                    // Resolve series details
                    AnimeSeries? matchedSeries;
                    for (var series in allSeries) {
                      if (series.coreName == seriesName) {
                        matchedSeries = series;
                        break;
                      }
                    }

                    // Resolve poster from first season
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

                    final totalEpCount = seriesLogs.length;
                    final newestLog = seriesLogs.first;
                    final newestTime = DateTime.fromMillisecondsSinceEpoch(newestLog['timestamp'] as int);
                    final newestTimeStr = _formatDateTime(newestTime);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24), // M3 design
                        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: matchedSeries != null ? Hero(
                              tag: 'hero_history_${matchedSeries.coreName}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 44,
                                  height: 58,
                                  child: posterFile != null
                                      ? TdThumbnail(file: posterFile, minithumbnail: minithumbnail)
                                      : Container(
                                          color: settingsAccent.withValues(alpha: 0.1),
                                          child: Icon(Icons.movie_rounded, color: settingsAccent, size: 24),
                                        ),
                                ),
                              ),
                            ) : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 44,
                                height: 58,
                                child: posterFile != null
                                    ? TdThumbnail(file: posterFile, minithumbnail: minithumbnail)
                                    : Container(
                                        color: settingsAccent.withValues(alpha: 0.1),
                                        child: Icon(Icons.movie_rounded, color: settingsAccent, size: 24),
                                      ),
                              ),
                            ),
                            title: AlignedNameText(
                              text: seriesName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '$totalEpCount watched • Last: $newestTimeStr',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            trailing: Icon(
                              isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedSeries.remove(seriesName);
                                } else {
                                  _expandedSeries.add(seriesName);
                                }
                              });
                            },
                          ),
                          if (isExpanded) ...[
                            const Divider(color: Colors.white10, height: 1),
                            Column(
                              children: List.generate(seriesLogs.length, (epIndex) {
                                final log = seriesLogs[epIndex];
                                final msgId = log['messageId'] as int;
                                final episodeTitle = log['episodeTitle'] as String;
                                final timestamp = log['timestamp'] as int;
                                final position = log['position'] as int;

                                final epTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
                                final epTimeStr = _formatDateTime(epTime);

                                // Resolve episode Details
                                td.Message? episodeMsg;
                                AnimeSeason? matchedSeason;
                                int? episodeListIndex;
                                int? fileId;
                                String epFileName = '';

                                if (matchedSeries != null) {
                                  // Find in seasons
                                  for (var season in matchedSeries.seasons) {
                                    final idx = season.episodes.indexWhere((ep) => ep.id == msgId);
                                    if (idx != -1) {
                                      episodeMsg = season.episodes[idx];
                                      matchedSeason = season;
                                      episodeListIndex = idx;
                                      break;
                                    }
                                  }

                                  // Fallback to first season index
                                  if (episodeMsg == null && matchedSeries.seasons.isNotEmpty) {
                                    final firstSeason = matchedSeries.seasons.first;
                                    final epIdx = log['episodeIndex'] as int;
                                    if (epIdx >= 0 && epIdx < firstSeason.episodes.length) {
                                      episodeMsg = firstSeason.episodes[epIdx];
                                      matchedSeason = firstSeason;
                                      episodeListIndex = epIdx;
                                    }
                                  }

                                  if (episodeMsg != null) {
                                    if (episodeMsg.content is td.MessageVideo) {
                                      final v = episodeMsg.content as td.MessageVideo;
                                      fileId = v.video.video.id;
                                      epFileName = v.video.fileName;
                                    } else if (episodeMsg.content is td.MessageDocument) {
                                      final d = episodeMsg.content as td.MessageDocument;
                                      fileId = d.document.document.id;
                                      epFileName = d.document.fileName;
                                    }
                                  }
                                }

                                fileId ??= log['videoFileId'] as int?;

                                final progressStr = position > 0 
                                    ? 'Watched to ${_formatDuration(position)}' 
                                    : 'Started';

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  color: epIndex % 2 == 0 
                                      ? (isDark ? Colors.white.withValues(alpha: 0.01) : Colors.black.withValues(alpha: 0.01))
                                      : Colors.transparent,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              episodeTitle,
                                              style: TextStyle(
                                                color: settingsAccent,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$progressStr • $epTimeStr',
                                              style: TextStyle(
                                                color: isDark ? Colors.white38 : Colors.black38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      fileId != null && matchedSeries != null && matchedSeries.seasons.isNotEmpty
                                          ? Semantics(
                                              label: 'Play ${matchedSeries.coreName} $episodeTitle',
                                              button: true,
                                              child: IconButton(
                                                icon: Icon(Icons.play_circle_fill_rounded, color: settingsAccent, size: 28),
                                                tooltip: 'Play Episode',
                                                onPressed: () {
                                                  final targetSeason = matchedSeason ?? matchedSeries!.seasons.first;
                                                  if (Platform.isWindows) {
                                                    ref.read(desktopSelectedSeriesProvider.notifier).state = matchedSeries;
                                                  } else {
                                                    Navigator.push(
                                                      context,
                                                      PremiumPageRoute(
                                                        child: AndroidEpisodeListScreen(
                                                          season: targetSeason,
                                                          series: matchedSeries!,
                                                          heroTag: 'hero_history_${matchedSeries!.coreName}',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  
                                                  Future.delayed(const Duration(milliseconds: 50), () {
                                                    if (context.mounted) {
                                                      ref.read(pipControllerProvider.notifier).playVideo(
                                                        context,
                                                        messageId: episodeMsg?.id ?? log['messageId'] as int,
                                                        videoFileId: fileId!,
                                                        videoTitle: '$seriesName - ${epFileName.isNotEmpty ? epFileName : episodeTitle}',
                                                        episodeList: targetSeason.episodes,
                                                        currentEpisodeIndex: episodeListIndex ?? log['episodeIndex'] as int,
                                                        seriesName: seriesName,
                                                      );
                                                    }
                                                  });
                                                },
                                              ),
                                            )
                                          : const Icon(Icons.play_circle_outline, color: Colors.white24, size: 24),
                                    ],
                                  ),
                                );
                              },
                            )),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '(｡•́︿•̀｡)',
            style: const TextStyle(fontSize: 48, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'No watch history found',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
