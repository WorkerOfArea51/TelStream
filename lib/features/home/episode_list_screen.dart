import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:palette_generator/palette_generator.dart';
import '../../models/anime_models.dart';
import '../player/pip_manager.dart';
import '../../core/widgets/wavy_progress_indicators.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../../services/tdlib_service.dart';
import '../../services/tmdb_service.dart';
import '../../core/logger.dart';
import '../../core/widgets/shimmer_card.dart';

class EpisodeListScreen extends ConsumerStatefulWidget {
  final AnimeSeason season;
  final AnimeSeries series;
  final String? heroTag;

  const EpisodeListScreen({
    Key? key,
    required this.season,
    required this.series,
    this.heroTag,
  }) : super(key: key);

  @override
  ConsumerState<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends ConsumerState<EpisodeListScreen> {
  late AnimeSeason _selectedSeason;
  bool _isLoadingEpisodes = false;
  String? _errorMessage;
  TmdbSeriesMetadata? _tmdbMetadata;
  List<TmdbEpisodeMetadata> _tmdbEpisodes = [];
  Color? _extractedAccentColor;
  StreamSubscription? _posterUpdateSub;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.season;
    _loadTmdbMetadata();
    _extractColorFromPoster();
    if (_selectedSeason.episodes.isEmpty) {
      _loadEpisodesDynamically();
    }
  }

  Future<void> _loadTmdbMetadata() async {
    if (!mounted) return;
    setState(() {
      _tmdbMetadata = null;
      _tmdbEpisodes = [];
    });

    try {
      final tmdbService = ref.read(tmdbServiceProvider);
      final metadata = await tmdbService.fetchMetadata(widget.series.coreName);
      if (metadata != null && mounted) {
        setState(() {
          _tmdbMetadata = metadata;
        });

        int seasonNum = 1;
        final match = RegExp(r'\d+').firstMatch(_selectedSeason.seasonName);
        if (match != null) {
          seasonNum = int.tryParse(match.group(0)!) ?? 1;
        }

        final eps = await tmdbService.fetchSeasonEpisodes(metadata.tmdbId, seasonNum);
        if (eps.isNotEmpty && mounted) {
          setState(() {
            _tmdbEpisodes = eps;
          });
        }
        
        // Extract theme color from network poster
        _extractColorFromPoster();
      }
    } catch (e, stack) {
      Log.e('Failed to load TMDB details for ${widget.series.coreName}', e, stack);
    } finally {
      // Done loading
    }
  }

  Future<void> _loadEpisodesDynamically() async {
    if (!mounted) return;
    setState(() {
      _isLoadingEpisodes = true;
      _errorMessage = null;
    });

    try {
      final tdlibService = ref.read(tdlibServiceProvider);
      final posterId = _selectedSeason.posterMessage.id;
      final chatId = _selectedSeason.posterMessage.chatId;
      
      final List<td.Message> collectedEpisodes = [];
      int currentFromId = posterId;

      final response = await tdlibService.sendAsync(td.GetChatHistory(
        chatId: chatId,
        fromMessageId: currentFromId,
        offset: 0,
        limit: 100,
        onlyLocal: false,
      )).timeout(
        const Duration(seconds: 10),
        onTimeout: () => td.TdError(code: 408, message: "Request Timeout"),
      );

      if (response is td.TdError) {
        throw Exception("Failed to load episodes: ${response.message}");
      }

      List<td.Message> fetched = [];
      if (response is td.Messages) {
        fetched = response.messages;
      } else if (response is td.FoundMessages) {
        fetched = response.messages;
      }

      for (final msg in fetched) {
        if (msg.id == posterId) continue;

        if (msg.content is td.MessageVideo) {
          collectedEpisodes.add(msg);
        } else if (msg.content is td.MessageDocument) {
          final doc = msg.content as td.MessageDocument;
          final fileName = doc.document.fileName.toLowerCase();
          if (doc.document.mimeType.startsWith('video/') ||
              fileName.endsWith('.mkv') ||
              fileName.endsWith('.mp4') ||
              fileName.endsWith('.avi') ||
              fileName.endsWith('.mov') ||
              fileName.endsWith('.webm') ||
              fileName.endsWith('.flv') ||
              fileName.endsWith('.wmv')) {
            collectedEpisodes.add(msg);
          }
        } else if (msg.content is td.MessagePhoto) {
          break;
        }
      }

      if (mounted) {
        setState(() {
          _selectedSeason = AnimeSeason(
            fullTitle: _selectedSeason.fullTitle,
            seasonName: _selectedSeason.seasonName,
            posterMessage: _selectedSeason.posterMessage,
            episodes: collectedEpisodes.reversed.toList(),
          );
          _isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingEpisodes = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _posterUpdateSub?.cancel();
    super.dispose();
  }

  Future<void> _extractColorFromPoster() async {
    if (!mounted) return;

    // Try network image first if TMDB metadata has posterPath
    final posterUrl = _tmdbMetadata?.posterPath;
    if (posterUrl != null && posterUrl.isNotEmpty) {
      try {
        final palette = await PaletteGenerator.fromImageProvider(
          NetworkImage(posterUrl),
          maximumColorCount: 16,
        );
        final color = palette.vibrantColor?.color ?? palette.dominantColor?.color;
        if (color != null && mounted) {
          setState(() {
            _extractedAccentColor = color;
          });
          return;
        }
      } catch (e) {
        Log.w('Failed to extract color from TMDB network poster: $e');
      }
    }

    // Fallback to Telegram local file poster
    td.File? posterFile;
    if (_selectedSeason.posterMessage.content is td.MessagePhoto) {
      final photo = _selectedSeason.posterMessage.content as td.MessagePhoto;
      if (photo.photo.sizes.isNotEmpty) {
        posterFile = photo.photo.sizes.last.photo;
      }
    }

    if (posterFile != null) {
      if (posterFile.local.path.isNotEmpty) {
        // File is already downloaded
        try {
          final file = File(posterFile.local.path);
          if (await file.exists()) {
            final palette = await PaletteGenerator.fromImageProvider(
              FileImage(file),
              maximumColorCount: 16,
            );
            final color = palette.vibrantColor?.color ?? palette.dominantColor?.color;
            if (color != null && mounted) {
              setState(() {
                _extractedAccentColor = color;
              });
            }
          }
        } catch (e) {
          Log.w('Failed to extract color from local Telegram poster: $e');
        }
      } else {
        // File is not downloaded yet, subscribe to updates
        _subscribeToPosterUpdates(posterFile.id);
      }
    }
  }

  void _subscribeToPosterUpdates(int fileId) {
    _posterUpdateSub?.cancel();
    final tdlibService = ref.read(tdlibServiceProvider);

    // Trigger download of the poster file if it hasn't started
    tdlibService.send(td.DownloadFile(
      fileId: fileId,
      priority: 16,
      offset: 0,
      limit: 0,
      synchronous: false,
    ));

    _posterUpdateSub = tdlibService.updates.listen((event) async {
      if (event is td.UpdateFile && event.file.id == fileId) {
        if (event.file.local.isDownloadingCompleted && event.file.local.path.isNotEmpty) {
          _posterUpdateSub?.cancel();
          _posterUpdateSub = null;
          try {
            final file = File(event.file.local.path);
            if (await file.exists()) {
              final palette = await PaletteGenerator.fromImageProvider(
                FileImage(file),
                maximumColorCount: 16,
              );
              final color = palette.vibrantColor?.color ?? palette.dominantColor?.color;
              if (color != null && mounted) {
                setState(() {
                  _extractedAccentColor = color;
                });
              }
            }
          } catch (e) {
            Log.w('Failed to extract color from downloaded Telegram poster: $e');
          }
        }
      }
    });
  }

  void _toggleFavorite() {
    ref.read(favoritesProvider.notifier).toggleFavorite(widget.series.coreName);
    final isFavNow = ref.read(favoritesProvider).contains(widget.series.coreName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavNow ? 'Added to Favorites!' : 'Removed from Favorites'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  int _parseEpisodeNumber(String fileName, int indexFallback) {
    final regexes = [
      RegExp(r'e(\d+)', caseSensitive: false),
      RegExp(r'ep(?:isode)?\.?\s*(\d+)', caseSensitive: false),
      RegExp(r'\b(\d+)\b'),
    ];
    for (final reg in regexes) {
      final match = reg.firstMatch(fileName);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? (indexFallback + 1);
      }
    }
    return indexFallback + 1;
  }

  Widget _buildLocalBackdrop(td.File? posterFile, td.Minithumbnail? minithumbnail) {
    return TdThumbnail(
      file: posterFile,
      minithumbnail: minithumbnail,
      autoDownload: true,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.topCenter,
    );
  }

  Widget _buildResumePlayButton(BuildContext context, Color accentColor) {
    final storage = ref.read(storageServiceProvider);
    final lastWatchedMap = storage.getLastWatched();
    
    int resumeIndex = 0;
    String btnText = 'Play Season 1';
    
    if (lastWatchedMap != null && lastWatchedMap['seriesName'] == widget.series.coreName) {
      resumeIndex = lastWatchedMap['episodeIndex'] as int? ?? 0;
      if (resumeIndex < _selectedSeason.episodes.length) {
        btnText = 'Resume Episode ${resumeIndex + 1}';
      }
    } else if (_selectedSeason.episodes.isNotEmpty) {
      btnText = 'Play Episode 1';
    }

    if (_selectedSeason.episodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: accentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 28),
          label: Text(
            btnText,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          onPressed: () {
            final msg = _selectedSeason.episodes[resumeIndex];
            int? fileId;
            String title = 'Episode ${resumeIndex + 1}';
            if (msg.content is td.MessageVideo) {
              final video = msg.content as td.MessageVideo;
              fileId = video.video.video.id;
              title = video.video.fileName;
            } else if (msg.content is td.MessageDocument) {
              final doc = msg.content as td.MessageDocument;
              fileId = doc.document.document.id;
              title = doc.document.fileName;
            }

            if (fileId != null) {
              final task = ref.read(downloadControllerProvider)[fileId];
              final isDownloaded = task != null && task.isCompleted && task.localPath != null;

              ref.read(pipControllerProvider.notifier).playVideo(
                context,
                messageId: msg.id,
                videoFileId: fileId,
                videoTitle: '${widget.series.coreName} - $title',
                episodeList: _selectedSeason.episodes,
                currentEpisodeIndex: resumeIndex,
                seriesName: widget.series.coreName,
                networkUrl: isDownloaded ? task.localPath : null,
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(favoritesProvider).contains(widget.series.coreName);
    final effectiveHeroTag = widget.heroTag ?? 'hero_poster_grid_${widget.series.coreName}';

    td.File? posterFile;
    td.Minithumbnail? minithumbnail;
    if (_selectedSeason.posterMessage.content is td.MessagePhoto) {
      final photo = _selectedSeason.posterMessage.content as td.MessagePhoto;
      if (photo.photo.sizes.isNotEmpty) {
        posterFile = photo.photo.sizes.last.photo;
      }
      minithumbnail = photo.photo.minithumbnail;
    }

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = _extractedAccentColor ?? customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    final posterUrl = _tmdbMetadata?.posterPath;
    final backdropUrl = _tmdbMetadata?.backdropPath;
    final title = _tmdbMetadata?.title ?? _selectedSeason.fullTitle;
    final rating = _tmdbMetadata?.rating ?? 0.0;
    final releaseDate = _tmdbMetadata?.releaseDate ?? '';
    final genres = _tmdbMetadata?.genres ?? [];
    final overview = _tmdbMetadata?.overview ?? "No overview available from TMDB. Enjoy streaming.";

    return Theme(
      data: theme.copyWith(
        primaryColor: settingsAccent,
        colorScheme: theme.colorScheme.copyWith(
          primary: settingsAccent,
          secondary: settingsAccent,
        ),
      ),
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleFavorite,
        backgroundColor: isFavorite ? theme.colorScheme.secondary : theme.cardColor,
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? Colors.white : theme.iconTheme.color,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdropUrl != null)
                    Image.network(
                      backdropUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildLocalBackdrop(posterFile, minithumbnail),
                    )
                  else
                    _buildLocalBackdrop(posterFile, minithumbnail),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(color: Colors.black.withOpacity(0.4)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          theme.scaffoldBackgroundColor.withOpacity(0.8),
                          theme.scaffoldBackgroundColor
                        ],
                        stops: const [0.4, 0.8, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 105,
                        height: 155,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(color: Colors.white12, width: 0.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Hero(
                          tag: effectiveHeroTag,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                TdThumbnail(
                                  file: posterFile,
                                  minithumbnail: minithumbnail,
                                  autoDownload: true,
                                  borderRadius: BorderRadius.zero,
                                ),
                                if (posterUrl != null)
                                  Image.network(
                                    posterUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const SizedBox.shrink();
                                    },
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (releaseDate.isNotEmpty) ...[
                                  Text('  •  ', style: TextStyle(color: isDark ? Colors.white30 : Colors.black26)),
                                  Text(
                                    releaseDate.split('-').first,
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (genres.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: genres.take(3).map((g) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: settingsAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: settingsAccent.withOpacity(0.2), width: 0.5),
                                  ),
                                  child: Text(
                                    g,
                                    style: TextStyle(
                                      color: settingsAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    overview,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _buildResumePlayButton(context, settingsAccent),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                ],
              ),
            ),
          ),
          if (widget.series.seasons.length > 1)
            SliverToBoxAdapter(
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.series.seasons.length,
                  itemBuilder: (context, index) {
                    final season = widget.series.seasons[index];
                    final isSelected = season.seasonName == _selectedSeason.seasonName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(
                          season.seasonName,
                          style: TextStyle(
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.cardColor,
                        side: BorderSide(
                          color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                          width: 1,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedSeason = season;
                              _extractedAccentColor = null;
                            });
                            _loadTmdbMetadata();
                            _extractColorFromPoster();
                            if (season.episodes.isEmpty) {
                              _loadEpisodesDynamically();
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_isLoadingEpisodes)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const ShimmerEpisodeCard(),
                childCount: 4,
              ),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage', style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: theme.primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        ),
                        onPressed: _loadEpisodesDynamically,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final msg = _selectedSeason.episodes[index];
                    return _buildEpisodeCardItem(context, msg, index);
                  },
                  childCount: _selectedSeason.episodes.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    ),
  );
}

  Widget _buildEpisodeCardItem(BuildContext context, td.Message msg, int index) {
    String fileTitle = 'Episode ${index + 1}';
    String metadata = '';
    int? fileId;

    if (msg.content is td.MessageVideo) {
      final video = msg.content as td.MessageVideo;
      fileTitle = video.video.fileName;
      fileId = video.video.video.id;
      final sizeMb = (video.video.video.expectedSize / 1024 / 1024).toStringAsFixed(1);
      final duration = Duration(seconds: video.video.duration);
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      metadata = '$minutes:$seconds • $sizeMb MB';
    } else if (msg.content is td.MessageDocument) {
      final doc = msg.content as td.MessageDocument;
      fileTitle = doc.document.fileName;
      fileId = doc.document.document.id;
      final sizeMb = (doc.document.document.expectedSize / 1024 / 1024).toStringAsFixed(1);
      metadata = '$sizeMb MB';
    }

    if (fileId == null) return const SizedBox.shrink();

    // Parse episode index and query TMDB still/info
    final parsedEpNum = _parseEpisodeNumber(fileTitle, index);
    TmdbEpisodeMetadata? mappedEpisode;
    for (final ep in _tmdbEpisodes) {
      if (ep.episodeNumber == parsedEpNum) {
        mappedEpisode = ep;
        break;
      }
    }

    final epTitle = mappedEpisode?.title ?? fileTitle;
    final epOverview = mappedEpisode?.overview ?? 'No description available for this episode.';
    final epStillUrl = mappedEpisode?.stillPath;

    final downloadTasks = ref.watch(downloadControllerProvider);
    final task = downloadTasks[fileId];

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = _extractedAccentColor ?? customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    Widget trailingWidget;
    if (task == null) {
      trailingWidget = IconButton(
        icon: Icon(Icons.download, color: settingsAccent, size: 22),
        onPressed: () {
          ref.read(downloadControllerProvider.notifier).startDownload(fileId!, fileTitle);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Starting download: $fileTitle'),
              backgroundColor: theme.primaryColor,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );
    } else if (!task.isCompleted) {
      trailingWidget = GestureDetector(
        onTap: () {
          ref.read(downloadControllerProvider.notifier).cancelDownload(fileId!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download cancelled'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: WavyCircularProgressIndicator(
                value: task.progress,
                strokeWidth: 2.0,
                color: settingsAccent,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            Icon(Icons.close, size: 12, color: settingsAccent),
          ],
        ),
      );
    } else {
      trailingWidget = const Icon(Icons.check_circle, color: Colors.green, size: 22);
    }

    final isDownloaded = task != null && task.isCompleted && task.localPath != null;
    final storage = ref.read(storageServiceProvider);
    final savedPos = storage.getWatchPosition(msg.id);
    int duration = 0;
    if (msg.content is td.MessageVideo) {
      duration = (msg.content as td.MessageVideo).video.duration;
    } else {
      duration = storage.getVideoDuration(msg.id);
    }
    final double progressValue = (duration > 0) ? (savedPos / duration).clamp(0.0, 1.0) : 0.0;
    final isCompleted = progressValue > 0.9;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(pipControllerProvider.notifier).playVideo(
            context,
            messageId: msg.id,
            videoFileId: fileId!,
            videoTitle: '${widget.series.coreName} - $fileTitle',
            episodeList: _selectedSeason.episodes,
            currentEpisodeIndex: index,
            seriesName: widget.series.coreName,
            networkUrl: isDownloaded ? task.localPath : null,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Episode Thumbnail/Still preview
                  Container(
                    width: 105,
                    height: 65,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (epStillUrl != null)
                          Image.network(
                            epStillUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildEpisodePlaceholder(msg),
                          )
                        else
                          _buildEpisodePlaceholder(msg),
                        Container(color: Colors.black26),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Icon(
                              isDownloaded ? Icons.download_done_rounded : Icons.play_arrow_rounded,
                              color: isDownloaded ? Colors.green : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        if (progressValue > 0.0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 3,
                              color: Colors.black38,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: progressValue,
                                  child: Container(
                                    color: settingsAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Episode information details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. $epTitle',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isCompleted) ...[
                              const Icon(Icons.check_circle, color: Colors.green, size: 12),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              isDownloaded ? '$metadata • Downloaded' : metadata,
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          epOverview,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 11,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailingWidget,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodePlaceholder(td.Message msg) {
    td.File? previewFile;
    td.Minithumbnail? mini;
    if (msg.content is td.MessageVideo) {
      final video = msg.content as td.MessageVideo;
      if (video.video.thumbnail != null) {
        previewFile = video.video.thumbnail!.file;
      }
      mini = video.video.minithumbnail;
    }
    return TdThumbnail(
      file: previewFile,
      minithumbnail: mini,
      autoDownload: true,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
