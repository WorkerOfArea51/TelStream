import 'dart:math' as math;

import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/utils/poster_thumbnail_extractor.dart';

import '../../models/anime_models.dart';
import '../../models/episode.dart';
import '../../models/video_source.dart';
import '../settings/settings_provider.dart';
import '../../services/metadata_service.dart';
import '../player/pip_manager.dart';
import '../../core/widgets/wavy_progress_indicators.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'home_controller.dart';
import '../../core/utils/title_normalizer.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../../core/widgets/aligned_name_text.dart';
import '../../services/tdlib_service.dart';

import '../../core/widgets/shimmer_card.dart';
import 'tracker_match_dialog.dart';

import '../../services/metadata_extraction_service.dart';
import '../../services/episode_grouper.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/firebase_metadata_service.dart';
import '../../core/constants.dart';
import 'widgets/admin_override_dialog.dart';
import '../player/widgets/quality_picker_sheet.dart';

class AndroidEpisodeListScreen extends ConsumerStatefulWidget {
  final AnimeSeason season;
  final AnimeSeries series;
  final String? heroTag;
  final String? categoryTitle;
  final int? highlightMessageId;
  final bool isEmbedded;
  final Function(int)? onSeasonChanged;
  final VoidCallback? onBack;

  const AndroidEpisodeListScreen({
    super.key,
    required this.season,
    required this.series,
    this.heroTag,
    this.categoryTitle,
    this.highlightMessageId,
    this.isEmbedded = false,
    this.onSeasonChanged,
    this.onBack,
  });

  @override
  ConsumerState<AndroidEpisodeListScreen> createState() => _AndroidEpisodeListScreenState();
}

class _AndroidEpisodeListScreenState extends ConsumerState<AndroidEpisodeListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimeSeason _selectedSeason;
  bool _isLoadingEpisodes = false;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _seasonScrollController = ScrollController();
  late List<GlobalKey> _seasonKeys;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.season;
    _seasonKeys = List.generate(widget.series.seasons.length, (index) => GlobalKey());

    if (widget.highlightMessageId != null) {
      bool found = false;
      for (final season in widget.series.seasons) {
        if (season.episodes.any((ep) => ep.defaultSource?.messageId == widget.highlightMessageId)) {
          _selectedSeason = season;
          found = true;
          break;
        }
      }
      if (!found) {
        AnimeSeason? bestMatch;
        for (final season in widget.series.seasons) {
          if (season.posterMessage.id < widget.highlightMessageId!) {
            if (bestMatch == null || season.posterMessage.id > bestMatch.posterMessage.id) {
              bestMatch = season;
            }
          }
        }
        if (bestMatch != null) {
          _selectedSeason = bestMatch;
        }
      }
    }

    if (_selectedSeason.episodes.isEmpty) {
      _loadEpisodesDynamically();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlightedEpisode();
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = widget.series.seasons.indexOf(_selectedSeason);
      if (index != -1) {
        _scrollToSelectedSeason(index, delay: true);
      }
    });
  }

  @override
  void didUpdateWidget(AndroidEpisodeListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.series.seasons.length != oldWidget.series.seasons.length) {
      _seasonKeys = List.generate(widget.series.seasons.length, (index) => GlobalKey());
    }
    if (widget.series != oldWidget.series || widget.season != oldWidget.season) {
      final matchingSeason = widget.series.seasons.firstWhere(
        (s) => s.seasonName == _selectedSeason.seasonName,
        orElse: () => widget.season,
      );
      setState(() {
        _selectedSeason = matchingSeason;
      });
      if (_selectedSeason.episodes.isEmpty) {
        _loadEpisodesDynamically();
      }
    }
  }

  void _scrollToHighlightedEpisode() {
    if (widget.highlightMessageId == null) return;
    final idx = _selectedSeason.episodes.indexWhere(
      (ep) => ep.defaultSource?.messageId == widget.highlightMessageId,
    );
    if (idx != -1) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        
        final scrollCtrl = widget.isEmbedded 
            ? PrimaryScrollController.of(context) 
            : _scrollController;
            
        if (scrollCtrl.hasClients) {
          final targetOffset = widget.isEmbedded 
              ? 500.0 + (idx * 104.0) 
              : 280.0 + (idx * 104.0);
              
          scrollCtrl.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _downloadAllEpisodes(AnimeSeason season) async {
    final settings = ref.read(videoSettingsProvider);
    String qualityRule = settings.batchDownloadQuality;

    if (qualityRule == 'Ask Each Time') {
      int maxSources = 0;
      final availableQualities = <String>{};
      for (final ep in season.episodes) {
        if (ep.sources.length > maxSources) {
          maxSources = ep.sources.length;
        }
        for (final src in ep.sources) {
          if (src.hasQualityLabel) {
            availableQualities.add(src.qualityLabel);
          }
        }
      }

      if (maxSources <= 1) {
        qualityRule = 'Highest Quality';
      } else {
        final sortedQualities = availableQualities.toList()..sort((a, b) {
          // simple sort for '2160p', '1080p', etc (descending)
          final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return numB.compareTo(numA);
        });

        final selectedRule = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(
              'Select Batch Download Quality', 
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'Highest Quality'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Highest Quality'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'Lowest Quality'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Lowest Quality'),
                ),
              ),
              if (sortedQualities.isNotEmpty) const Divider(height: 1),
              ...sortedQualities.map((q) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, q),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Prefer $q (fallback: highest)'),
                ),
              )),
            ],
          ),
        );

        if (selectedRule == null) return;
        qualityRule = selectedRule;
      }
    }

    final fileIds = <int>[];
    final titles = <String>[];
    final messageIds = <int>[];
    final chatIds = <int>[];

    final tdlib = ref.read(tdlibServiceProvider);
    for (final ep in season.episodes) {
      if (ep.sources.isEmpty) continue;

      final sortedSources = List<VideoSource>.from(ep.sources)
        ..sort((a, b) {
          final hA = a.metadata?.height ?? 0;
          final hB = b.metadata?.height ?? 0;
          if (hB != hA) return hB.compareTo(hA);
          return b.fileSizeBytes.compareTo(a.fileSizeBytes);
        });

      VideoSource targetSource;
      switch (qualityRule) {
        case 'Lowest Quality':
          targetSource = sortedSources.last;
          break;
        case '2160p':
        case '1440p':
        case '1080p':
        case '720p':
        case '480p':
        case '360p':
          final exact = sortedSources.firstWhere(
            (s) => s.qualityLabel == qualityRule,
            orElse: () => sortedSources.first, // fallback: highest
          );
          targetSource = exact;
          break;
        case 'Highest Quality':
        default:
          targetSource = sortedSources.first;
          break;
      }

      final msg = await tdlib.getMessage(targetSource.chatId, targetSource.messageId);
      if (msg == null) continue;
      final fileId = _extractFileId(msg);
      if (fileId != null && fileId != 0) {
        final title = TitleNormalizer.getMessageFileName(msg)
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'\.(mkv|mp4|avi|mov|webm|flv|wmv|ts|m4v|3gp)$', caseSensitive: false), '')
            .trim();
        fileIds.add(fileId);
        titles.add(title.isNotEmpty ? title : 'Episode ${msg.id}');
        messageIds.add(msg.id);
        chatIds.add(msg.chatId);
      }
    }

    if (fileIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noDownloadableEpisodes)),
        );
      }
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.downloadAll(fileIds.length.toString())),
        content: Text('This will download ${fileIds.length} episodes. '
            'Up to 3 will download simultaneously, the rest will be queued.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.downloadAllButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(downloadControllerProvider.notifier)
          .startBatchDownload(fileIds, titles, messageIds, chatIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.startedBatchDownload(fileIds.length.toString())),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    }
  }

  Future<void> _loadEpisodesDynamically() async {
    if (!context.mounted) return;
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

      final response = await tdlibService
          .sendAsync(
            td.GetChatHistory(
              chatId: chatId,
              fromMessageId: currentFromId,
              offset: -99,
              limit: 100,
              onlyLocal: false,
            ),
          )
          .timeout(
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
          final fileName = TitleNormalizer.getMessageFileName(msg).toLowerCase();
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

      final groupedEpisodes = EpisodeGrouper.groupEpisodes(collectedEpisodes);

      if (mounted) {
        setState(() {
          _selectedSeason = AnimeSeason(
            fullTitle: _selectedSeason.fullTitle,
            seasonName: _selectedSeason.seasonName,
            posterMessage: _selectedSeason.posterMessage,
            episodes: groupedEpisodes,
          );
          _isLoadingEpisodes = false;
        });

        // Inject these dynamically loaded episodes back into the global controller
        // so they get saved to the JSON cache and never have to be loaded again!
        final providerNotifier = widget.categoryTitle == 'Anime'
            ? ref.read(animeControllerProvider.notifier)
            : widget.categoryTitle == 'Movies'
                ? ref.read(moviesControllerProvider.notifier)
                : ref.read(webSeriesControllerProvider.notifier);
        
        providerNotifier.updateSeasonEpisodes(
          widget.series.coreName,
          _selectedSeason.posterMessage.id,
          groupedEpisodes,
        );
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
    _seasonScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedSeason(int index, {bool delay = false}) {
    if (index < 0 || index >= _seasonKeys.length) return;
    
    void doScroll() {
      if (!mounted) return;
      final context = _seasonKeys[index].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    }

    if (delay) {
      Future.delayed(const Duration(milliseconds: 400), doScroll);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    }
  }

  void _showSeasonAdminOverrideDialog(BuildContext context, String seasonName) async {
    final tdlibService = ref.read(tdlibServiceProvider);
    final me = await tdlibService.sendAsync(const td.GetMe());
    
    if (me is td.User && me.id == Constants.adminUserId) {
      if (!context.mounted) return;
        
      final overrideKey = '${widget.series.coreName}_$seasonName';
      final existingIds = ref.read(firebaseMetadataProvider.notifier).getOverride(overrideKey) ?? '';

      final result = await showDialog<String>(
        context: context,
        builder: (c) => AdminOverrideDialog(
          title: overrideKey,
          initialText: existingIds,
        ),
      );
      
      if (result != null && result.trim().isNotEmpty) {
        List<String> ids = [];
        final input = result.trim();
        if (input.startsWith('tt') || input.contains('imdb.com')) {
          ids = MetadataService.extractAllImdbIds(input);
        } else {
          ids = MetadataService.extractAllMalIds(input);
        }
        
        if (ids.isNotEmpty) {
          if (!context.mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => const AlertDialog(
              backgroundColor: Colors.black,
              content: Row(
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(width: 16),
                  Text('Fetching Season Metadata...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          );

          final metadataService = MetadataService();
          List<SeriesMetadata> preloadedData = [];
          for (final id in ids) {
            SeriesMetadata? meta;
            if (id.startsWith('tt')) {
              meta = await metadataService.fetchTmdbByImdbId(id);
            } else {
              meta = await metadataService.fetchMyAnimeListByMalId(id);
            }
            if (meta != null) preloadedData.add(meta);
          }

          if (context.mounted) Navigator.pop(context);

          await ref.read(firebaseMetadataProvider.notifier).saveOverride(
            widget.categoryTitle ?? 'Anime',
            overrideKey,
            ids.join(','),
            preloadedData: preloadedData,
          );
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Season Metadata Linked successfully! Tap another season and back to refresh.')),
            );
          }
        }
      }
    }
  }

  void _toggleFavorite() {
    ref.read(favoritesProvider.notifier).toggleFavorite(widget.series.coreName);
    final isFavNow = ref
        .read(favoritesProvider)
        .contains(widget.series.coreName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavNow ? 'Added to Favorites!' : 'Removed from Favorites',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildLocalBackdrop(
    td.File? posterFile,
    td.Minithumbnail? minithumbnail,
  ) {
    return TdThumbnail(
      file: posterFile,
      minithumbnail: minithumbnail,
      autoDownload: true,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.topCenter,
    );
  }



  @override
  Widget build(BuildContext context) {
    super.build(context);
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
    AnimeSeason selectedSeason = activeSeries.seasons.firstWhere(
      (s) => s.seasonName == _selectedSeason.seasonName,
      orElse: () => _selectedSeason,
    );

    // If the local _selectedSeason has dynamically loaded episodes but the provider's season doesn't yet, use the local one
    if (selectedSeason.episodes.isEmpty && _selectedSeason.episodes.isNotEmpty) {
      selectedSeason = _selectedSeason;
    }

    final isFavorite = ref
        .watch(favoritesProvider)
        .contains(widget.series.coreName);
    final effectiveHeroTag =
        widget.heroTag ?? 'hero_poster_grid_${widget.series.coreName}';

    final extracted = extractPosterThumbnail(selectedSeason.posterMessage);
    final posterFile = extracted.file;
    final minithumbnail = extracted.minithumbnail;

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

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
          backgroundColor: isFavorite
              ? theme.colorScheme.secondary
              : theme.cardColor,
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.white : theme.iconTheme.color,
          ),
        ),
        body: CustomScrollView(
          key: const PageStorageKey<String>('episode_list_scroll_view'),
          controller: widget.isEmbedded ? null : _scrollController,
          slivers: [
            if (!widget.isEmbedded)
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                leading: widget.onBack != null
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: widget.onBack,
                      )
                    : null,
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
                      Container(
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              theme.scaffoldBackgroundColor.withValues(
                                alpha: 0.8,
                              ),
                              theme.scaffoldBackgroundColor,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                              border: Border.all(
                                color: Colors.white12,
                                width: 0.5,
                              ),
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
                                    color: Theme.of(context).colorScheme.onSurface,
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
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    const Divider(color: Colors.white12, height: 1),
                  ],
                ),
              ),
            ),
              SliverToBoxAdapter(
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  child: SingleChildScrollView(
                    controller: _seasonScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: List.generate(widget.series.seasons.length, (index) {
                        final season = widget.series.seasons[index];
                        final isSelected =
                            season.seasonName == selectedSeason.seasonName;
                        
                        return Padding(
                          key: _seasonKeys[index],
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onLongPress: () => _showSeasonAdminOverrideDialog(context, season.seasonName),
                            child: ChoiceChip(
                              label: Text(
                                season.episodes.isNotEmpty
                                    ? '${season.seasonName} (${season.episodes.length} EP)'
                                    : season.seasonName,
                                style: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: theme.colorScheme.primary,
                              backgroundColor: theme.cardColor,
                              side: BorderSide(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.dividerColor,
                                width: 1,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedSeason = season;
                                  });
                                  _scrollToSelectedSeason(index);
                                  widget.onSeasonChanged?.call(index);
                                  if (season.episodes.isEmpty) {
                                    _loadEpisodesDynamically();
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              // Download All button
              if (selectedSeason.episodes.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _downloadAllEpisodes(selectedSeason),
                        icon: const Icon(Icons.download_for_offline_outlined),
                        label: Text('Download All (${selectedSeason.episodes.length} Episodes)'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),
            if (_isLoadingEpisodes)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const ShimmerEpisodeCard(),
                    childCount: 4,
                  ),
                ),
              )
            else if (_errorMessage != null)
              SliverToBoxAdapter(
                key: const ValueKey('error'),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_errorMessage',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor:
                              theme.primaryColor.computeLuminance() >
                                  0.5
                              ? Colors.black
                              : Colors.white,
                        ),
                        onPressed: _loadEpisodesDynamically,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final msg = selectedSeason.episodes[index];
                      final tdMsgId = msg.defaultSource?.messageId;
                      final isHighlighted =
                          tdMsgId != null && widget.highlightMessageId == tdMsgId;
                      return _EpisodeCardItem(
                        key: ValueKey(tdMsgId ?? index),
                        ep: msg,
                        index: index,
                        season: selectedSeason,
                        series: widget.series,
                        onLongPress: _showMarkWatchedDialog,
                        isHighlighted: isHighlighted,
                      ).animate()
                       .fadeIn(duration: 300.ms, delay: (index * 30).ms)
                       .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: (index * 30).ms);
                    },
                    childCount: selectedSeason.episodes.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  void _showMarkWatchedDialog(
    BuildContext context,
    Episode ep,
    int index,
    String title,
  ) {
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                title: const Text('Mark as Watched'),
                onTap: () async {
                  final msgId = ep.defaultSource?.messageId;
                  if (msgId == null) return;
                  int duration = (ep.defaultSource?.durationMillis ?? 0) ~/ 1000;
                  if (duration <= 0) {
                    duration = storage.getVideoDuration(msgId);
                  }
                  final resolvedDuration = duration > 0 ? duration : 1800;
                  if (duration <= 0) {
                    await storage.saveVideoDuration(msgId, resolvedDuration);
                  }
                  await storage.saveWatchPosition(msgId, resolvedDuration);

                  if (!storage.isIncognitoMode() &&
                      widget.series.coreName.isNotEmpty) {
                    await ref
                        .read(historyLogProvider.notifier)
                        .addToHistory(
                          seriesName: widget.series.coreName,
                          messageId: msgId,
                          episodeIndex: index,
                          episodeTitle: title.replaceFirst(
                            '${widget.series.coreName} - ',
                            '',
                          ),
                          positionInSeconds: resolvedDuration,
                          videoFileId: 0,
                        );
                  }

                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.unpublished_outlined,
                  color: Colors.redAccent,
                ),
                title: const Text('Mark as Unwatched'),
                onTap: () async {
                  if (ep.defaultSource?.messageId != null) {
                    await storage.saveWatchPosition(ep.defaultSource!.messageId, 0);
                  }
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.refresh_outlined,
                  color: Colors.blueAccent,
                ),
                title: const Text('Refresh Metadata'),
                onTap: () async {
                  Navigator.pop(context);  // Close the bottom sheet first.
                  if (!context.mounted) return;

                  // Show a "refreshing" snackbar.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Refreshing metadata...'),
                        ],
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  try {
                    await ref.read(metadataExtractionServiceProvider.notifier)
                       .extractMetadataForEpisode(ep, forceRefresh: true);

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Metadata refreshed.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to refresh metadata: $e'),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 3),
                      ),
                    );
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

int? _extractFileId(td.Message msg) {
  if (msg.content is td.MessageVideo) {
    return (msg.content as td.MessageVideo).video.video.id;
  }
  if (msg.content is td.MessageDocument) {
    return (msg.content as td.MessageDocument).document.document.id;
  }
  return null;
}

class _EpisodeCardItem extends ConsumerStatefulWidget {
  final Episode ep;
  final int index;
  final AnimeSeason season;
  final AnimeSeries series;
  final Function(BuildContext, Episode, int, String) onLongPress;
  final bool isHighlighted;

  const _EpisodeCardItem({
    super.key,
    required this.ep,
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
  bool _metadataRequested = false;
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

  /// Builds a clean title for the player header.
  /// For movies: just the episode title (e.g. "Nagabandham 2026").
  /// For series: "Series Name - EP - 01 - Episode Title".
  String _buildPlayerTitle(String coreName, String episodeTitle) {
    final cleanCore = TitleNormalizer.cleanDisplayTitle(coreName);
    final cleanEp = TitleNormalizer.cleanDisplayTitle(episodeTitle);

    // If the core name and episode title are the same (movie case), don't duplicate.
    if (cleanCore.toLowerCase() == cleanEp.toLowerCase()) {
      return cleanEp;
    }
    // If the episode title already starts with the core name, don't duplicate.
    if (cleanEp.toLowerCase().startsWith(cleanCore.toLowerCase())) {
      return cleanEp;
    }
    return '$cleanCore - $cleanEp';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String fileTitle = 'Episode ${widget.index + 1}';
    String metadata = '';
    int? fileId;

    final epMsgId = widget.ep.defaultSource?.messageId;
    if (epMsgId == null) {
      return const SizedBox();
    }
    
    fileTitle = widget.ep.title;
    fileId = 1; // mock
    final durationMillis = widget.ep.defaultSource?.durationMillis ?? 0;
    final sizeMb = (widget.ep.defaultSource!.fileSizeBytes / 1024 / 1024).toStringAsFixed(1);
    
    if (durationMillis > 0) {
      final duration = Duration(milliseconds: durationMillis);
      final h = duration.inHours;
      final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      final durStr = h > 0 ? '$h:$m:$s' : '$m:$s';
      metadata = '$durStr • $sizeMb MB';
    } else {
      metadata = '$sizeMb MB';
    }

    // removed dead code
    // Clean up episode title: Remove potential numerical prefix (e.g., "01. ", "1 - ")
    final epTitle = fileTitle.replaceFirst(RegExp(r'^\d+\s*[\.\-]\s*'), '');

    final downloadTasks = ref.watch(downloadControllerProvider);
    DownloadTask? task;
    for (final t in downloadTasks.values) {
      if (t.messageId == epMsgId || t.fileId == fileId) {
        task = t;
        break;
      }
    }

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    Widget trailingWidget;
    if (task == null) {
      trailingWidget = IconButton(
        icon: Icon(Icons.download, color: settingsAccent, size: 22),
        onPressed: () async {
          VideoSource? sourceToDownload;

          if (widget.ep.sources.length > 1) {
            final settings = ref.read(videoSettingsProvider);
            final defaultQuality = settings.defaultDownloadQuality;
            
            if (defaultQuality != 'Ask Each Time') {
              // Try to find the exact matching quality
              try {
                sourceToDownload = widget.ep.sources.firstWhere((s) => s.qualityLabel == defaultQuality);
              } catch (_) {
                // If not found, we fallback to asking
              }
            }

            if (sourceToDownload == null) {
              final result = await QualityPickerSheet.showSheet(context, widget.ep, fileTitle);
              if (result == null || result.action == QualityPickerAction.cancel || result.source == null) return;
              sourceToDownload = result.source;
            }
          } else {
            sourceToDownload = widget.ep.defaultSource;
          }

          if (sourceToDownload == null) return;

          ref.read(downloadControllerProvider.notifier).startDownload(
            0, // fallback fileId for sources, usually 0 is fine
            fileTitle,
            messageId: sourceToDownload.messageId,
            chatId: sourceToDownload.chatId,
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Starting download: $fileTitle (${sourceToDownload.qualityLabel})'),
                backgroundColor: theme.primaryColor,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      );
    } else if (!task.isCompleted) {
      trailingWidget = GestureDetector(
        onTap: () {
          ref
              .read(downloadControllerProvider.notifier)
              .cancelDownload(task!.fileId);
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
      trailingWidget = const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 22,
      );
    }

    final isDownloaded =
        task != null && task.isCompleted && task.localPath != null;
    final storage = ref.read(storageServiceProvider);
    final savedPos = storage.getWatchPosition(epMsgId);
    int duration = 0;
    final dm = widget.ep.defaultSource?.durationMillis ?? 0;
    duration = (dm > 0) ? (dm ~/ 1000) : storage.getVideoDuration(epMsgId);
    final double progressValue = (duration > 0)
        ? (savedPos / duration).clamp(0.0, 1.0)
        : 0.0;
    final isCompleted = progressValue > 0.9;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isTapped = true),
      onTapUp: (_) => setState(() => _isTapped = false),
      onTapCancel: () => setState(() => _isTapped = false),
      onTap: () {
        ref
            .read(pipControllerProvider.notifier)
            .playVideo(
              context,
              messageId: epMsgId,
              videoFileId: fileId!,
              videoTitle: _buildPlayerTitle(widget.series.coreName, fileTitle),
              episodeList: widget.season.episodes,
              currentEpisodeIndex: widget.index,
              seriesName: widget.series.coreName,
              networkUrl: isDownloaded ? task?.localPath : null,
              chatId: widget.ep.defaultSource?.chatId,
            );
      },
      onLongPress: () {
        widget.onLongPress(context, widget.ep, widget.index, fileTitle);
      },
      child: VisibilityDetector(
        key: Key('episode_${widget.ep.title}_$epMsgId'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0 && !_metadataRequested) {
            _metadataRequested = true;
            // Defer to next frame so a fast scroll-past doesn't trigger work.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(metadataExtractionServiceProvider.notifier)
                 .extractMetadataForEpisode(widget.ep);
            });
          }
        },
        child: Consumer(
        builder: (context, ref, child) {
          final pipState = ref.watch(pipControllerProvider);
          final isCurrentlyPlaying = (pipState != null && pipState.messageId == epMsgId);
          final shouldGlow = _isGlowing || isCurrentlyPlaying;

          return AnimatedScale(
            scale: _isTapped ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: isCurrentlyPlaying
                ? TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.4, end: 1.0),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeInOutSine,
                    builder: (context, value, child) {
                      final pulseValue = (math.sin(value * math.pi * 2) + 1) / 2; // 0.0 to 1.0
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: settingsAccent,
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: settingsAccent.withValues(alpha: 0.3 + (0.4 * pulseValue)),
                              blurRadius: 10 + (8 * pulseValue),
                              spreadRadius: 2 + (3 * pulseValue),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: child,
                      );
                    },
                    child: child,
                  )
                : Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: shouldGlow
                            ? settingsAccent
                            : theme.colorScheme.onSurface.withValues(
                                alpha: _isTapped ? 0.16 : 0.08,
                              ),
                        width: shouldGlow || _isTapped ? 1.8 : 1.0,
                      ),
                      boxShadow: [
                        if (shouldGlow)
                          BoxShadow(
                            color: settingsAccent.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1.5,
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: _isTapped ? 0.15 : 0.08,
                            ),
                            blurRadius: _isTapped ? 3 : 6,
                            offset: Offset(0, _isTapped ? 1.5 : 3),
                          ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
          );
        },
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
                      _buildEpisodeThumbnail(),
                      Container(color: Colors.black26),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white24,
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            isDownloaded
                                ? Icons.download_done_rounded
                                : Icons.play_arrow_rounded,
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
                                child: Container(color: settingsAccent),
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
                      AlignedNameText(
                        text: epTitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 12,
                            ),
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
                      if (ref.read(videoSettingsProvider).showQualityBadges) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: widget.ep.sources.map((src) {
                            // hasQualityLabel is true when filename label exists
                            // or when height > 0.
                            // Show "..." only when label is genuinely unknown
                            // (metadata extraction hasn't run or returned no dimensions).
                            final hasLabel = src.hasQualityLabel;
                            final label = hasLabel ? src.qualityLabel : '...';
                            // isContainerParsed is true only when the container
                            // has been parsed from the file header. Use it to
                            // visually distinguish confirmed vs unconfirmed.
                            final isConfirmed = src.isContainerParsed;
                            Widget badge = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: settingsAccent.withValues(alpha: hasLabel ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: settingsAccent.withValues(alpha: hasLabel ? 0.5 : 0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  // Unconfirmed badges are slightly faded so the
                                  // user can tell which ones have been parsed.
                                  color: hasLabel
                                      ? (isConfirmed
                                          ? settingsAccent
                                          : settingsAccent.withValues(alpha: 0.7))
                                      : settingsAccent.withValues(alpha: 0.5),
                                ),
                              ),
                            );
                            
                            if (label == '...') {
                              badge = GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Extracting metadata...'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                  ref.read(metadataExtractionServiceProvider.notifier)
                                     .extractMetadataForEpisode(widget.ep, forceRefresh: true);
                                },
                                child: badge,
                              );
                            }
                            return badge;
                          }).toList(),
                        ),
                      ],
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

  Widget _buildEpisodeThumbnail() {
    final thumbnailFileId = widget.ep.defaultSource?.thumbnailFileId;
    final minithumbnailData = widget.ep.defaultSource?.minithumbnailData;

    if (thumbnailFileId != null && thumbnailFileId != 0) {
      return TdThumbnail(
        file: td.File(
          id: thumbnailFileId,
          size: 0,
          expectedSize: 0,
          local: const td.LocalFile(path: '', canBeDownloaded: true, canBeDeleted: false, isDownloadingActive: false, isDownloadingCompleted: false, downloadOffset: 0, downloadedPrefixSize: 0, downloadedSize: 0),
          remote: const td.RemoteFile(id: '', uniqueId: '', isUploadingActive: false, isUploadingCompleted: false, uploadedSize: 0),
        ),
        minithumbnail: minithumbnailData != null && minithumbnailData.isNotEmpty 
            ? td.Minithumbnail(width: 160, height: 90, data: minithumbnailData) 
            : null,
        width: 160,
        height: 90,
        fit: BoxFit.cover,
      );
    }
    
    if (minithumbnailData != null && minithumbnailData.isNotEmpty) {
      try {
        final bytes = base64Decode(minithumbnailData);
        return Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildEpisodePlaceholder(),
        );
      } catch (_) {
        return _buildEpisodePlaceholder();
      }
    }
    return _buildEpisodePlaceholder();
  }

  Widget _buildEpisodePlaceholder({bool isDark = false}) {
    return Container(
      color: isDark ? const Color(0xFF1E1E2A) : const Color(0xFFF0F0F5),
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          size: 32,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    );
  }
}

class _TouchScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TouchScale({required this.child, required this.onTap});

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

class _SwipeToActionState extends State<_SwipeToAction>
    with SingleTickerProviderStateMixin {
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
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

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
