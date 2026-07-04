import 'dart:ui';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tdlib/td_api.dart' as td;

import '../../models/anime_models.dart';
import '../player/pip_manager.dart';
import '../../core/widgets/wavy_progress_indicators.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_controller.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../../services/tdlib_service.dart';

import '../../core/widgets/shimmer_card.dart';
import 'tracker_match_dialog.dart';

class EpisodeListScreen extends ConsumerStatefulWidget {
  final AnimeSeason season;
  final AnimeSeries series;
  final String? heroTag;
  final String? categoryTitle;
  final int? highlightMessageId;
  final bool isEmbedded;

  const EpisodeListScreen({
    super.key,
    required this.season,
    required this.series,
    this.heroTag,
    this.categoryTitle,
    this.highlightMessageId,
    this.isEmbedded = false,
    this.onSeasonChanged,
  });

  final Function(int)? onSeasonChanged;

  @override
  ConsumerState<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends ConsumerState<EpisodeListScreen> {
  late AnimeSeason _selectedSeason;
  bool _isLoadingEpisodes = false;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.season;

    if (widget.highlightMessageId != null) {
      for (final season in widget.series.seasons) {
        if (season.episodes.any((ep) => ep.id == widget.highlightMessageId)) {
          _selectedSeason = season;
          break;
        }
      }
    }

    if (_selectedSeason.episodes.isEmpty) {
      _loadEpisodesDynamically();
    } else {
      _scrollToHighlightedEpisode();
    }
  }

  void _scrollToHighlightedEpisode() {
    if (widget.highlightMessageId == null) return;
    final idx = _selectedSeason.episodes.indexWhere((ep) => ep.id == widget.highlightMessageId);
    if (idx != -1) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted || !_scrollController.hasClients) return;
        final targetOffset = 280.0 + (idx * 104.0);
        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      });
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
        offset: -99,
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
        _scrollToHighlightedEpisode();
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
    _scrollController.dispose();
    super.dispose();
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
        btnText = widget.categoryTitle == 'Movies' ? 'Resume Movie' : 'Resume Episode ${resumeIndex + 1}';
      }
    } else if (_selectedSeason.episodes.isNotEmpty) {
      btnText = widget.categoryTitle == 'Movies' ? 'Play Movie' : 'Play Episode 1';
    }

    if (_selectedSeason.episodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: _TouchScale(
          onTap: () {
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
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch HomeController provider to dynamically update the view with synchronized edits in real-time
    final provider = widget.categoryTitle == 'Anime'
        ? animeControllerProvider
        : widget.categoryTitle == 'Movies'
            ? moviesControllerProvider
            : webSeriesControllerProvider;

    final seriesListAsync = ref.watch(provider);
    final seriesList = seriesListAsync.value ?? [];
    final activeSeries = seriesList.firstWhere(
      (s) => s.coreName == widget.series.coreName,
      orElse: () => widget.series,
    );
    final selectedSeason = activeSeries.seasons.firstWhere(
      (s) => s.seasonName == _selectedSeason.seasonName,
      orElse: () => _selectedSeason,
    );

    final isFavorite = ref.watch(favoritesProvider).contains(widget.series.coreName);
    final effectiveHeroTag = widget.heroTag ?? 'hero_poster_grid_${widget.series.coreName}';

    td.File? posterFile;
    td.Minithumbnail? minithumbnail;
    if (selectedSeason.posterMessage.content is td.MessagePhoto) {
      final photo = selectedSeason.posterMessage.content as td.MessagePhoto;
      if (photo.photo.sizes.isNotEmpty) {
        posterFile = photo.photo.sizes.last.photo;
      }
      minithumbnail = photo.photo.minithumbnail;
    }

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    final title = selectedSeason.fullTitle;

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
        controller: _scrollController,
        slivers: [
          if (!widget.isEmbedded)
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              actions: [
                IconButton(
                  icon: const Icon(Icons.link, color: Colors.white),
                  tooltip: 'Tracker Matcher',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => TrackerMatchDialog(
                        seriesName: widget.series.coreName,
                      ),
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildLocalBackdrop(posterFile, minithumbnail),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(color: Colors.black.withValues(alpha: 0.4)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
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
                  if (!widget.isEmbedded) ...[
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
                                color: Colors.black.withValues(alpha: 0.4),
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
                              child: TdThumbnail(
                                file: posterFile,
                                minithumbnail: minithumbnail,
                                autoDownload: true,
                                borderRadius: BorderRadius.zero,
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
                              Text(
                                widget.categoryTitle == 'Movies'
                                    ? 'Movie'
                                    : '${selectedSeason.episodes.length} Episode${selectedSeason.episodes.length > 1 ? "s" : ""}',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
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
                    final isSelected = season.seasonName == selectedSeason.seasonName;
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
                            });
                            widget.onSeasonChanged?.call(index);
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
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _isLoadingEpisodes
                  ? ListView.builder(
                      key: const ValueKey('loading'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: 4,
                      itemBuilder: (context, index) => const ShimmerEpisodeCard(),
                    )
                  : _errorMessage != null
                      ? Center(
                          key: const ValueKey('error'),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
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
                        )
                       : ListView.builder(
                          key: ValueKey('${selectedSeason.seasonName}_${selectedSeason.episodes.length}'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: selectedSeason.episodes.length,
                          itemBuilder: (context, index) {
                            final msg = selectedSeason.episodes[index];
                            final isHighlighted = widget.highlightMessageId == msg.id;
                            return _EpisodeCardItem(
                              key: ValueKey(msg.id),
                              msg: msg,
                              index: index,
                              season: selectedSeason,
                              series: widget.series,
                              onLongPress: _showMarkWatchedDialog,
                              isHighlighted: isHighlighted,
                            );
                          },
                        ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    ),
  );
}

  void _showMarkWatchedDialog(BuildContext context, td.Message msg, int index, String title) {
    final storage = ref.read(storageServiceProvider);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                title: const Text('Mark as Watched'),
                onTap: () async {
                  int duration = 0;
                  if (msg.content is td.MessageVideo) {
                    duration = (msg.content as td.MessageVideo).video.duration;
                  } else {
                    duration = storage.getVideoDuration(msg.id);
                  }
                  final resolvedDuration = duration > 0 ? duration : 1800;
                  if (duration <= 0) {
                    await storage.saveVideoDuration(msg.id, resolvedDuration);
                  }
                  await storage.saveWatchPosition(msg.id, resolvedDuration);
                  
                  if (!storage.isIncognitoMode() && widget.series.coreName.isNotEmpty) {
                    await ref.read(historyLogProvider.notifier).addToHistory(
                      seriesName: widget.series.coreName,
                      messageId: msg.id,
                      episodeIndex: index,
                      episodeTitle: title.replaceFirst('${widget.series.coreName} - ', ''),
                      positionInSeconds: resolvedDuration,
                      videoFileId: msg.content is td.MessageVideo
                          ? (msg.content as td.MessageVideo).video.video.id
                          : (msg.content as td.MessageDocument).document.document.id,
                    );
                  }
                  
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.unpublished_outlined, color: Colors.redAccent),
                title: const Text('Mark as Unwatched'),
                onTap: () async {
                  await storage.saveWatchPosition(msg.id, 0);
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _EpisodeCardItem extends ConsumerStatefulWidget {
  final td.Message msg;
  final int index;
  final AnimeSeason season;
  final AnimeSeries series;
  final Function(BuildContext, td.Message, int, String) onLongPress;
  final bool isHighlighted;

  const _EpisodeCardItem({
    super.key,
    required this.msg,
    required this.index,
    required this.season,
    required this.series,
    required this.onLongPress,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<_EpisodeCardItem> createState() => _EpisodeCardItemState();
}

class _EpisodeCardItemState extends ConsumerState<_EpisodeCardItem> {
  bool _isTapped = false;
  bool _isGlowing = false;
  Timer? _glowTimer;

  @override
  void initState() {
    super.initState();
    _isGlowing = widget.isHighlighted;
    if (_isGlowing) {
      _glowTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isGlowing = false;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(_EpisodeCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _glowTimer?.cancel();
      setState(() {
        _isGlowing = true;
      });
      _glowTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isGlowing = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _glowTimer?.cancel();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    String fileTitle = 'Episode ${widget.index + 1}';
    String metadata = '';
    int? fileId;

    if (widget.msg.content is td.MessageVideo) {
      final video = widget.msg.content as td.MessageVideo;
      fileTitle = video.video.fileName;
      fileId = video.video.video.id;
      final sizeMb = (video.video.video.expectedSize / 1024 / 1024).toStringAsFixed(1);
      final duration = Duration(seconds: video.video.duration);
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      metadata = '$minutes:$seconds • $sizeMb MB';
    } else if (widget.msg.content is td.MessageDocument) {
      final doc = widget.msg.content as td.MessageDocument;
      fileTitle = doc.document.fileName;
      fileId = doc.document.document.id;
      final sizeMb = (doc.document.document.expectedSize / 1024 / 1024).toStringAsFixed(1);
      metadata = '$sizeMb MB';
    }

    if (fileId == null) return const SizedBox.shrink();

    final epTitle = fileTitle;
    final downloadTasks = ref.watch(downloadControllerProvider);
    DownloadTask? task;
    for (final t in downloadTasks.values) {
      if (t.messageId == widget.msg.id || t.fileId == fileId) {
        task = t;
        break;
      }
    }

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    Widget trailingWidget;
    if (task == null) {
      trailingWidget = IconButton(
        icon: Icon(Icons.download, color: settingsAccent, size: 22),
        onPressed: () {
          ref.read(downloadControllerProvider.notifier).startDownload(
            fileId!,
            fileTitle,
            messageId: widget.msg.id,
            chatId: widget.msg.chatId,
          );
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
          ref.read(downloadControllerProvider.notifier).cancelDownload(task!.fileId);
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
    final savedPos = storage.getWatchPosition(widget.msg.id);
    int duration = 0;
    if (widget.msg.content is td.MessageVideo) {
      duration = (widget.msg.content as td.MessageVideo).video.duration;
    } else {
      duration = storage.getVideoDuration(widget.msg.id);
    }
    final double progressValue = (duration > 0) ? (savedPos / duration).clamp(0.0, 1.0) : 0.0;
    final isCompleted = progressValue > 0.9;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isTapped = true),
      onTapUp: (_) => setState(() => _isTapped = false),
      onTapCancel: () => setState(() => _isTapped = false),
      onTap: () {
        ref.read(pipControllerProvider.notifier).playVideo(
          context,
          messageId: widget.msg.id,
          videoFileId: fileId!,
          videoTitle: '${widget.series.coreName} - $fileTitle',
          episodeList: widget.season.episodes,
          currentEpisodeIndex: widget.index,
          seriesName: widget.series.coreName,
          networkUrl: isDownloaded ? task?.localPath : null,
        );
      },
      onLongPress: () {
        widget.onLongPress(context, widget.msg, widget.index, fileTitle);
      },
      child: AnimatedScale(
        scale: _isTapped ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isGlowing
                  ? settingsAccent
                  : theme.colorScheme.onSurface.withValues(alpha: _isTapped ? 0.16 : 0.08),
              width: _isGlowing || _isTapped ? 1.8 : 1.0,
            ),
            boxShadow: [
              if (_isGlowing)
                BoxShadow(
                  color: settingsAccent.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1.5,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isTapped ? 0.15 : 0.08),
                  blurRadius: _isTapped ? 3 : 6,
                  offset: Offset(0, _isTapped ? 1.5 : 3),
                ),
            ],
          ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                        _buildEpisodePlaceholder(widget.msg),
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
                          widget.series.seasons.length == 1 && widget.season.episodes.length == 1 
                              ? epTitle 
                              : '${widget.index + 1}. $epTitle',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 3,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailingWidget,
                ],
              ),
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
    } else if (msg.content is td.MessageDocument) {
      final doc = msg.content as td.MessageDocument;
      if (doc.document.thumbnail != null) {
        previewFile = doc.document.thumbnail!.file;
      }
      mini = doc.document.minithumbnail;
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

class _TouchScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TouchScale({
    required this.child,
    required this.onTap,
  });

  @override
  State<_TouchScale> createState() => _TouchScaleState();
}

class _TouchScaleState extends State<_TouchScale> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isTapped = true),
      onTapUp: (_) => setState(() => _isTapped = false),
      onTapCancel: () => setState(() => _isTapped = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isTapped ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _SwipeToAction extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final Color accentColor;

  const _SwipeToAction({
    required this.child,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.accentColor,
  });

  @override
  State<_SwipeToAction> createState() => _SwipeToActionState();
}

class _SwipeToActionState extends State<_SwipeToAction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  static const double _threshold = 80.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta!;
      if (_dragOffset.abs() > _threshold) {
        final over = _dragOffset.abs() - _threshold;
        _dragOffset = _dragOffset.sign * (_threshold + over * 0.3);
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset > _threshold) {
      widget.onSwipeRight();
    } else if (_dragOffset < -_threshold) {
      widget.onSwipeLeft();
    }

    final start = _dragOffset;
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    
    late VoidCallback listener;
    listener = () {
      setState(() {
        _dragOffset = start * (1.0 - curve.value);
      });
    };
    _controller.addListener(listener);
    _controller.forward(from: 0.0).then((_) {
      _controller.removeListener(listener);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showRightIcon = _dragOffset > 10;
    final showLeftIcon = _dragOffset < -10;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedOpacity(
                  opacity: showRightIcon ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.only(left: 20),
                    alignment: Alignment.centerLeft,
                    child: AnimatedScale(
                      scale: _dragOffset > _threshold ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: showLeftIcon ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    child: AnimatedScale(
                      scale: _dragOffset < -_threshold ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.download_rounded,
                        color: widget.accentColor,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          behavior: HitTestBehavior.opaque,
          child: Transform.translate(
            offset: Offset(_dragOffset, 0.0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
