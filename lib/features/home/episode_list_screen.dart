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

  const EpisodeListScreen({
    super.key,
    required this.season,
    required this.series,
    this.heroTag,
    this.categoryTitle,
  });

  @override
  ConsumerState<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends ConsumerState<EpisodeListScreen> {
  late AnimeSeason _selectedSeason;
  bool _isLoadingEpisodes = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.season;
    if (_selectedSeason.episodes.isEmpty) {
      _loadEpisodesDynamically();
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
        offset: -100,
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
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    final title = _selectedSeason.fullTitle;

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
                                  : '${_selectedSeason.episodes.length} Episode${_selectedSeason.episodes.length > 1 ? "s" : ""}',
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
                            });
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

    final epTitle = fileTitle;

    final downloadTasks = ref.watch(downloadControllerProvider);
    final task = downloadTasks[fileId];

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
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
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
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
        onLongPress: () {
          _showMarkWatchedDialog(context, msg, index, fileTitle);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
