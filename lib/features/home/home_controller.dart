import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../../models/anime_models.dart';
import '../../core/logger.dart';
import '../player/pip_manager.dart';

enum SortOrder { newest, oldest, aToZ, zToA }

abstract class HomeController extends AsyncNotifier<List<AnimeSeries>> {
  int _lastMessageId = 0;
  bool _hasMore = true;
  String _currentQuery = '';
  bool _isLoadingMore = false;
  SortOrder _sortOrder = SortOrder.newest;
  
  final List<td.Message> _rawMessages = [];
  final Set<int> _rawMessageIds = {};

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  SortOrder get sortOrder => _sortOrder;

  ChannelCategory get category;
  List<AnimeSeries> _allSeries = [];
  String _resolvedChatTitle = 'Loading...';
  String get resolvedChatTitle => _resolvedChatTitle;

  bool _showFavoritesOnly = false;
  bool get showFavoritesOnly => _showFavoritesOnly;

  StreamSubscription? _updateSubscription;
  bool _cacheLoadComplete = false;
  bool _isFetchingReleaseYears = false;
  Timer? _releaseYearsTimer;

  @override
  FutureOr<List<AnimeSeries>> build() async {
    final storage = ref.read(storageServiceProvider);
    final lastSeen = storage.getLastSeenVersion();
    if (lastSeen != Constants.currentVersion) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        for (final cat in Constants.categories) {
          final cachePath = '${directory.path}/catalog_cache_${cat.title.replaceAll(' ', '_')}.json';
          final file = File(cachePath);
          if (await file.exists()) {
            await file.delete();
            Log.i('Deleted obsolete cache file due to version upgrade: $cachePath');
          }
        }
      } catch (e, stack) {
        Log.e('Failed to delete obsolete cache files', e, stack);
      }
      await storage.setLastSeenVersion(Constants.currentVersion);
    }

    final tdlibService = ref.watch(tdlibServiceProvider);
    
    ref.listen(favoritesProvider, (previous, next) {
      if (_showFavoritesOnly && state.value != null) {
        state = AsyncValue.data(_applySearchAndSort(_allSeries));
      }
    });

    _updateSubscription?.cancel();
    _updateSubscription = tdlibService.updates.listen((event) {
      if (event is td.UpdateNewMessage) {
        if (event.message.chatId == category.channelId) {
          if (!_rawMessageIds.contains(event.message.id)) {
            _rawMessages.insert(0, event.message);
            _rawMessageIds.add(event.message.id);
            _allSeries = _parseMessages(_rawMessages);
            if (state.value != null) {
              state = AsyncValue.data(_applySearchAndSort(_allSeries));
            }
            _triggerReleaseYearsSync();
            if (_cacheLoadComplete) {
              _saveCatalogCache();
            }
          }
        }
      }
    });

    ref.onDispose(() {
      _updateSubscription?.cancel();
      _releaseYearsTimer?.cancel();
    });

    _triggerReleaseYearsSync();

    final initialList = await _fetchInitial();
    
    // Schedule background sync to start in the next event loop tick,
    // ensuring the provider is fully built and state is set before updating it.
    Future.delayed(const Duration(milliseconds: 200), () {
      _syncFromNetwork();
    });
    
    return initialList;
  }

  void setSortOrder(SortOrder order) {
    _sortOrder = order;
    if (state.value != null) {
      state = AsyncValue.data(_applySearchAndSort(_allSeries));
    }
  }

  void toggleFavoritesFilter() {
    _showFavoritesOnly = !_showFavoritesOnly;
    if (state.value != null) {
      state = AsyncValue.data(_applySearchAndSort(_allSeries));
    }
  }

  void search(String query) async {
    if (_currentQuery == query) return;
    _currentQuery = query;
    
    if (state.value != null || _allSeries.isNotEmpty) {
      state = AsyncValue.data(_applySearchAndSort(_allSeries));
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    
    try {
      int startingLength = _allSeries.length;
      int iterations = 0;
      bool changed = false;
      while (_allSeries.length < startingLength + 10 && _hasMore && iterations < 5) {
        iterations++;
        final moreMessages = await _fetchMessages(fromId: _lastMessageId, onlyLocal: false);
        if (moreMessages.isEmpty) {
          break;
        }
        for (final msg in moreMessages) {
          if (!_rawMessageIds.contains(msg.id)) {
            _rawMessages.add(msg);
            _rawMessageIds.add(msg.id);
            changed = true;
          }
        }
        
        _rawMessages.sort((a, b) => b.id.compareTo(a.id));
        _allSeries = _parseMessages(_rawMessages);
        state = AsyncValue.data(_applySearchAndSort(_allSeries));
        _triggerReleaseYearsSync();
      }
      if (changed && _cacheLoadComplete) {
        _saveCatalogCache();
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<List<AnimeSeries>> _fetchInitial() async {
    _hasMore = true;
    _lastMessageId = 0;
    _rawMessages.clear();
    _rawMessageIds.clear();
    
    final tdlibService = ref.read(tdlibServiceProvider);
    
    // Helper to send request with a safety timeout to prevent hanging
    Future<td.TdObject> sendWithTimeout(td.TdFunction request) {
      return tdlibService.sendAsync(request).timeout(
        const Duration(seconds: 6),
        onTimeout: () => td.TdError(code: 408, message: "Request Timeout"),
      );
    }
    
    // 1. Try to get chat directly first (highly optimized for subsequent launches)
    td.TdObject chatRes = await sendWithTimeout(td.GetChat(chatId: category.channelId));
    
    // 2. Fallback strategy if chat is not found in local TDLib database
    if (chatRes is td.TdError) {
      // Fallback A: Sync chat list (limit 100) first to see if chat is loaded from main list
      try {
        await sendWithTimeout(td.LoadChats(
          chatList: const td.ChatListMain(),
          limit: 100,
        ));
        chatRes = await sendWithTimeout(td.GetChat(chatId: category.channelId));
      } catch (_) {}
      
      // Fallback B: Resolve invite link to load its info
      if (chatRes is td.TdError) {
        try {
          await sendWithTimeout(td.CheckChatInviteLink(inviteLink: category.inviteLink));
          chatRes = await sendWithTimeout(td.GetChat(chatId: category.channelId));
        } catch (_) {}
      }
      
      // Fallback C: Join chat via invite link
      if (chatRes is td.TdError) {
        try {
          await sendWithTimeout(td.JoinChatByInviteLink(inviteLink: category.inviteLink));
          chatRes = await sendWithTimeout(td.GetChat(chatId: category.channelId));
        } catch (_) {}
      }
    }

    if (chatRes is td.TdError) {
      throw Exception("GetChat failed: ${chatRes.message} (Code: ${chatRes.code})");
    }

    if (chatRes is td.Chat) {
      _resolvedChatTitle = chatRes.title;
    }

    // 1. Try loading catalog cache first
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cachePath = '${directory.path}/catalog_cache_${category.title.replaceAll(' ', '_')}.json';
      final file = File(cachePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        final List<AnimeSeries> cachedList = jsonList.map((s) => AnimeSeries.fromJson(s as Map<String, dynamic>)).toList();
        
        _allSeries = cachedList;
        _rawMessages.clear();
        _rawMessageIds.clear();
        
        for (final series in _allSeries) {
          for (final season in series.seasons) {
            if (!_rawMessageIds.contains(season.posterMessage.id)) {
              _rawMessages.add(season.posterMessage);
              _rawMessageIds.add(season.posterMessage.id);
            }
            for (final ep in season.episodes) {
              if (!_rawMessageIds.contains(ep.id)) {
                _rawMessages.add(ep);
                _rawMessageIds.add(ep.id);
              }
            }
          }
        }
        
        _rawMessages.sort((a, b) => b.id.compareTo(a.id));
        _cacheLoadComplete = true; // Cache loading completes the full load, subsequent sync starts incremental
        Log.i('Loaded ${cachedList.length} series from catalog cache for category ${category.title}');
        return _applySearchAndSort(_allSeries);
      }
    } catch (e, stack) {
      Log.e('Failed to load catalog cache for ${category.title}, falling back to local DB loop', e, stack);
    }

    // Fallback: load using onlyLocal: true from TDLib local database
    int iterations = 0;
    int currentFromId = 0;
    while (_hasMore && iterations < 200) {
      iterations++;
      final localMessages = await _fetchMessages(fromId: currentFromId, onlyLocal: true);
      if (localMessages.isEmpty) {
        break;
      }
      for (final msg in localMessages) {
        if (!_rawMessageIds.contains(msg.id)) {
          _rawMessages.add(msg);
          _rawMessageIds.add(msg.id);
        }
      }
      _allSeries = _parseMessages(_rawMessages);
      currentFromId = _rawMessages.last.id;
    }
    _cacheLoadComplete = !_hasMore;
    return _applySearchAndSort(_allSeries);
  }

  Future<void> _saveCatalogCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cachePath = '${directory.path}/catalog_cache_${category.title.replaceAll(' ', '_')}.json';
      final file = File(cachePath);
      final jsonList = _allSeries.map((s) => s.toJson()).toList();
      final content = json.encode(jsonList);
      await file.writeAsString(content);
      Log.i('Saved catalog cache for category ${category.title} to $cachePath');
    } catch (e, stack) {
      Log.e('Failed to save catalog cache for ${category.title}', e, stack);
    }
  }

  Future<void> _syncFromNetwork() async {
    try {
      _hasMore = true; // Reset _hasMore to allow background network fetching
      final storage = ref.read(storageServiceProvider);
      int currentFromId = 0;
      bool changed = false;
      bool reachedEnd = false;
      
      DateTime lastUiUpdateTime = DateTime.now();

      // Sync messages incrementally from the network in the background
      while (_hasMore) {
        try {
          // Yield execution and pause TDLib requests while video is actively playing to maximize streaming bandwidth
          while (ref.read(pipControllerProvider) != null) {
            await Future.delayed(const Duration(seconds: 2));
          }

          final networkMessages = _cacheLoadComplete
              ? await _fetchMessages(fromId: currentFromId, onlyLocal: false)
              : await _fetchMessagesParallel(fromId: currentFromId);

          if (networkMessages.isEmpty) {
            if (!_hasMore) {
              break; // Truly reached the end of history
            }
            // Temporary network / cache delay, wait a bit and try again
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
          
          for (final msg in networkMessages) {
            if (_rawMessageIds.contains(msg.id) && _cacheLoadComplete) {
              reachedEnd = true;
              _hasMore = false;
              break;
            }
            if (!_rawMessageIds.contains(msg.id)) {
              _rawMessages.add(msg);
              _rawMessageIds.add(msg.id);
              changed = true;
            }
          }
          
          if (reachedEnd) {
            break;
          }
          
          currentFromId = networkMessages.last.id;
          
          if (changed) {
            final now = DateTime.now();
            final isNearEnd = reachedEnd || !_hasMore;
            if (isNearEnd || now.difference(lastUiUpdateTime) > const Duration(milliseconds: 1500)) {
              _rawMessages.sort((a, b) => b.id.compareTo(a.id));
              _allSeries = _parseMessages(_rawMessages);
              state = AsyncValue.data(_applySearchAndSort(_allSeries));
              _triggerReleaseYearsSync();
              if (_cacheLoadComplete) {
                _saveCatalogCache();
              }
              lastUiUpdateTime = now;
              changed = false; // Reset changed flag
            }
          }
          
          // Brief pause to respect Telegram rate limits and yield UI thread
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e, stackTrace) {
          Log.e("Error during background sync iteration", e, stackTrace);
          // Wait a bit before retrying the next iteration to prevent hammering the network
          await Future.delayed(const Duration(seconds: 4));
        }
      }

      // Final UI update to guarantee that any pending changes are flushed
      if (changed) {
        _rawMessages.sort((a, b) => b.id.compareTo(a.id));
        _allSeries = _parseMessages(_rawMessages);
        state = AsyncValue.data(_applySearchAndSort(_allSeries));
        _triggerReleaseYearsSync();
      }

      // Update the indexing checkpoint if we have indexed items
      if (_rawMessages.isNotEmpty) {
        await storage.setLastIndexedMessageId(category.channelId, _rawMessages.first.id);
      }

      _cacheLoadComplete = true;
      _saveCatalogCache();
    } catch (e, stackTrace) {
      Log.e("Background sync error", e, stackTrace);
    }
  }

  Future<List<td.Message>> _fetchMessages({required int fromId, required bool onlyLocal}) async {
    final tdlibService = ref.read(tdlibServiceProvider);
    td.TdObject? response;
    int retries = 0;

    final fetchedBatch = <td.Message>[];
    final fetchedBatchIds = <int>{};
    int currentFromId = fromId;
    
    // Fetch larger chunks so we get posters more reliably
    while (fetchedBatch.length < 100 && retries < 5) {
      response = await tdlibService.sendAsync(td.GetChatHistory(
        chatId: category.channelId,
        fromMessageId: currentFromId,
        offset: 0,
        limit: 100 - fetchedBatch.length,
        onlyLocal: onlyLocal,
      )).timeout(
        onlyLocal ? const Duration(seconds: 2) : const Duration(seconds: 10),
        onTimeout: () => td.TdError(code: 408, message: "Request Timeout"),
      );

      if (response is td.TdError) {
        if (onlyLocal) {
          break; // Return early if local check fails/is empty
        }
        throw Exception("GetChatHistory failed: ${response.message} (Code: ${response.code})");
      }

      List<td.Message> fetched = [];
      if (response is td.Messages) {
        fetched = response.messages;
      } else if (response is td.FoundMessages) {
        fetched = response.messages;
      }

      // TDLib GetChatHistory returns messages inclusive of fromMessageId.
      // So a response is considered to have "no new messages" if:
      // 1. The list is empty.
      // 2. The list only contains the starting message we queried from.
      final bool gotNewMessages = fetched.isNotEmpty &&
          !(fetched.length == 1 && fetched.first.id == currentFromId);

      if (!gotNewMessages) {
        // If we got a completely empty list, it means the server has no more messages (end of history).
        if (fetched.isEmpty) {
          _hasMore = false;
          break;
        }

        // If we already successfully fetched some messages in this batch, return them
        // and keep _hasMore = true so the next pagination can attempt to fetch further.
        if (fetchedBatch.isNotEmpty || onlyLocal) {
          break;
        }
        
        // If we got only the starting message, wait and retry.
        if (retries < 5) {
          retries++;
          await Future.delayed(const Duration(seconds: 1));
          continue;
        } else {
          // If we retried 5 times and still got only the starting message, 
          // do NOT set _hasMore = false (unless currentFromId is very small).
          // Just break the batch loop so we return empty, allowing the background sync
          // to try again after a pause.
          if (currentFromId <= 5) {
            _hasMore = false;
          }
          break;
        }
      }
      
      int nextFromId = fetched.last.id;
      
      for (final msg in fetched) {
        if (!fetchedBatchIds.contains(msg.id)) {
          fetchedBatch.add(msg);
          fetchedBatchIds.add(msg.id);
        }
      }
      
      if (nextFromId == currentFromId) {
        // Safe check to avoid infinite loops
        _hasMore = false;
        break;
      }
      
      currentFromId = nextFromId;
      if (!onlyLocal) {
        _lastMessageId = currentFromId;
      }
    }

    return fetchedBatch;
  }

  Future<List<td.Message>> _fetchMessagesParallel({required int fromId, int chunkCount = 5}) async {
    final tdlibService = ref.read(tdlibServiceProvider);
    bool hadError = false;
    
    final futures = List.generate(chunkCount, (i) {
      final offset = i * 100;
      return tdlibService.sendAsync(td.GetChatHistory(
        chatId: category.channelId,
        fromMessageId: fromId,
        offset: offset,
        limit: 100,
        onlyLocal: false,
      )).timeout(
        const Duration(seconds: 12),
        onTimeout: () => td.TdError(code: 408, message: "Request Timeout"),
      ).then<List<td.Message>>((response) {
        if (response is td.TdError) {
          Log.w("Parallel GetChatHistory error for offset $offset: ${response.message}");
          hadError = true;
          return const <td.Message>[];
        }
        
        List<td.Message> fetched = [];
        if (response is td.Messages) {
          fetched = response.messages;
        } else if (response is td.FoundMessages) {
          fetched = response.messages;
        }
        return fetched;
      }).catchError((e, stack) {
        Log.e("Parallel GetChatHistory failed for offset $offset", e, stack);
        hadError = true;
        return const <td.Message>[];
      });
    });

    final results = await Future.wait(futures);
    
    final List<td.Message> combined = [];
    final Set<int> seenIds = {};
    for (final list in results) {
      for (final msg in list) {
        if (!seenIds.contains(msg.id)) {
          combined.add(msg);
          seenIds.add(msg.id);
        }
      }
    }
    
    combined.sort((a, b) => b.id.compareTo(a.id));
    
    if (!hadError && combined.length < chunkCount * 100) {
      _hasMore = false;
    }
    
    return combined;
  }

  static String normalizeSeriesName(String name, {bool isMovie = false}) {
    var normalized = name.trim();

    // 1. Remove bracketed text at the end, e.g. [1080p], (Movie), etc.
    normalized = normalized.replaceAll(RegExp(r'\s*[\[\(].*?[\]\)]\s*$'), '');

    if (!isMovie) {
      // 2. Remove trailing season / part / movie indicators.
      
      // Pattern A: trailing season/s/part with digit or Roman numeral
      // e.g. "season 2", "s3", "part II", "part 2"
      // Note: We avoid stripping "six" by requiring a space/separator when single-letter 's' is followed by a Roman numeral.
      normalized = normalized.replaceAll(RegExp(r'(?:\s*[-–—:|]\s*)?\b(?:(?:season|part)\s*(?:\d+|[ivxIVX]+)|s\s*\d+|s\s+[ivxIVX]+)\b', caseSensitive: false), '');

      // Pattern B: trailing final season/chapters/act/arc indicators
      // e.g. "final season", "final chapters", "final chapter", "final act", "final arc", "final"
      normalized = normalized.replaceAll(RegExp(r'(?:\s*[-–—:|]\s*)?\b(?:the\s+)?final\s+(?:season|chapters?|act|arcs?|part)?\b', caseSensitive: false), '');

      // Pattern C: trailing movie / ova / oad / special / specials / prequel / sequel tags
      normalized = normalized.replaceAll(RegExp(r'(?:\s*[-–—:|]\s*)?\b(?:the\s+)?(?:movie|ova|oad|specials?|prequels?|sequels?)\b', caseSensitive: false), '');

      // Pattern D: trailing Roman numerals at the end of the string
      // e.g. "II", "III", etc.
      normalized = normalized.replaceAll(RegExp(r'\s*\b[ivxIVX]+\b$', caseSensitive: false), '');

      // Pattern E: trailing single digits (0-9) NOT preceded by "no" or "vol"
      // e.g. "Log Horizon 2", "Jujutsu Kaisen 0"
      normalized = normalized.replaceAll(RegExp(r'(?<!\bno)(?<!\bno\.)(?<!\bvol)(?<!\bvol\.)\s+\b\d\b$', caseSensitive: false), '');

      // Pattern F: trailing single letter "S" (case insensitive) preceded by space (e.g. "Dragon Maid S")
      normalized = normalized.replaceAll(RegExp(r'\s+\b[sS]\b$'), '');

      // Pattern G: trailing known OVA/Movie subtitles that do not contain standard keywords (e.g. "Memory Snow", "Frozen Bond", "Hyouketsu no Kizuna")
      normalized = normalized.replaceAll(RegExp(r'(?:\s*[-–—:|]\s*)?\b(?:Memory\s+Snow|Frozen\s+Bond|Hyouketsu\s+no\s+Kizuna)\b', caseSensitive: false), '');

      // 3. Remove common trailing subtitles after a colon if the prefix has length > 3 and doesn't end with "Re"
      if (normalized.contains(':')) {
        final parts = normalized.split(':');
        final prefix = parts[0].trim();
        final isRePrefix = RegExp(r'\b[rR][eE]\b$').hasMatch(prefix);
        if (prefix.length > 3 && !isRePrefix) {
          normalized = prefix;
        }
      }
    }

    // 4. Remove bracketed text at the end again (e.g. if a year or tag was left trailing after season/part/colon stripping)
    normalized = normalized.replaceAll(RegExp(r'\s*[\[\(].*?[\]\)]\s*$'), '');

    // Also clean up any trailing dashes, colons, or punctuation left over from the replacements
    normalized = normalized.replaceAll(RegExp(r'\s*[-–—:|]+\s*$'), '');

    return normalized.trim();
  }

  static String parseSeasonName(String fullTitle, String baseName) {
    final ft = fullTitle.trim();
    final bn = baseName.trim();
    
    // Extract year suffix (like (2024) or [2024]) from the full title to preserve and append it.
    final yearMatch = RegExp(r'[\[\(](\d{4})[\]\)]').firstMatch(ft);
    if (yearMatch != null) {
      final year = yearMatch.group(1)!;
      final cleanFullTitle = ft.replaceAll(RegExp(r'\s*[\[\(]\d{4}[\]\)]\s*'), ' ').trim();
      final cleanSeason = parseSeasonName(cleanFullTitle, bn);
      if (cleanSeason.contains(year)) {
        return cleanSeason;
      }
      return '$cleanSeason ($year)';
    }

    if (ft.toLowerCase() == bn.toLowerCase()) {
      return 'Season 1';
    }
    
    if (ft.length <= bn.length) {
      return 'Season 1';
    }

    var diff = ft.substring(bn.length).trim();
    // Remove leading dashes, colons, spaces, punctuation
    diff = diff.replaceAll(RegExp(r'^[-–—:|,\s]+'), '').trim();
    
    if (diff.isEmpty) {
      return 'Season 1';
    }
    
    // Check if diff is a Roman numeral (e.g. "II", "III")
    if (RegExp(r'^[ivxIVX]+$').hasMatch(diff)) {
      return 'Season $diff';
    }
    
    // Check if diff is just a single digit (e.g. "2", "3")
    if (RegExp(r'^\d+$').hasMatch(diff)) {
      return 'Season $diff';
    }

    // Check if diff is an ordinal season pattern like "2nd", "2nd Season", "Season 2nd"
    final ordinalMatch = RegExp(r'^(\d+)(?:st|nd|rd|th)(?:\s+season)?$', caseSensitive: false).firstMatch(diff);
    if (ordinalMatch != null) {
      return 'Season ${ordinalMatch.group(1)}';
    }
    
    final ordinalMatch2 = RegExp(r'^season\s+(\d+)(?:st|nd|rd|th)$', caseSensitive: false).firstMatch(diff);
    if (ordinalMatch2 != null) {
      return 'Season ${ordinalMatch2.group(1)}';
    }
    
    // Check if diff starts with "Season" or "S" (case insensitive)
    final seasonNumMatch = RegExp(r'^(?:season\s*(\d+|[ivxIVX]+)|s\s*(\d+)|s\s+([ivxIVX]+))$', caseSensitive: false).firstMatch(diff);
    if (seasonNumMatch != null) {
      final val = seasonNumMatch.group(1) ?? seasonNumMatch.group(2) ?? seasonNumMatch.group(3)!;
      return 'Season $val';
    }
    
    if (diff.toLowerCase() == 'final season' || diff.toLowerCase() == 'final_season') {
      return 'Final Season';
    }
    
    if (diff.toLowerCase() == 's') {
      return 'Season S';
    }
    
    if (diff.toLowerCase() == 'movie' || diff.toLowerCase() == 'the movie') {
      return 'Movie';
    }
    
    // Otherwise, capitalize first letter of each word
    return diff.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  List<AnimeSeries> _parseMessages(List<td.Message> raw) {
    List<AnimeSeries> seriesList = [];
    Map<String, AnimeSeries> seriesMap = {};
    List<td.Message> currentEpisodes = [];

    for (final msg in raw) {
      if (msg.content is td.MessageVideo) {
        currentEpisodes.add(msg);
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
          currentEpisodes.add(msg);
        }
      } else if (msg.content is td.MessagePhoto) {
        final photo = msg.content as td.MessagePhoto;
        final captionText = photo.caption.text;
        
        if (captionText.isNotEmpty) {
          final lines = captionText.split('\n');
          final fullTitle = lines.first.trim();
          final isMovie = category.title == 'Movies';
          final baseName = normalizeSeriesName(fullTitle, isMovie: isMovie);
          
          final newSeason = AnimeSeason(
            fullTitle: fullTitle,
            seasonName: parseSeasonName(fullTitle, baseName),
            posterMessage: msg,
            episodes: currentEpisodes.reversed.toList(),
          );
          
          final canonicalKey = baseName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          
          // Prefix/substring grouping to merge movies and seasons under a clean core folder
          // For movies category, we keep each movie alone (no folder merging)
          String matchedKey = isMovie ? '${canonicalKey}_${msg.id}' : canonicalKey;
          if (!isMovie) {
            for (final existingKey in seriesMap.keys) {
            if (existingKey.length >= 7 && canonicalKey.length >= 7) {
              if (canonicalKey.startsWith(existingKey)) {
                matchedKey = existingKey;
                break;
              } else if (existingKey.startsWith(canonicalKey)) {
                // If the new one is shorter, update the core name and key mapping
                matchedKey = existingKey;
                final existingSeries = seriesMap[existingKey]!;
                if (baseName.length < existingSeries.coreName.length) {
                  seriesMap[existingKey] = AnimeSeries(
                    coreName: baseName,
                    seasons: existingSeries.seasons,
                  );
                  final idx = seriesList.indexOf(existingSeries);
                  if (idx != -1) {
                    seriesList[idx] = seriesMap[existingKey]!;
                  }
                  break;
                }
              }
            }
          }
        }
          
          if (!seriesMap.containsKey(matchedKey)) {
            seriesMap[matchedKey] = AnimeSeries(coreName: baseName, seasons: []);
            seriesList.add(seriesMap[matchedKey]!);
          }
          
          seriesMap[matchedKey]!.seasons.insert(0, newSeason);
          currentEpisodes = [];
        }
      }
    }

    return seriesList;
  }

  List<AnimeSeries> _applySearchAndSort(List<AnimeSeries> list) {
    final storage = ref.read(storageServiceProvider);
    
    // 0. Apply Favorites Filter
    List<AnimeSeries> favoritesFiltered = list;
    if (_showFavoritesOnly) {
      final favs = storage.getFavorites();
      favoritesFiltered = list.where((s) => favs.contains(s.coreName)).toList();
    }

    // 1. Apply Search Filter
    List<AnimeSeries> filtered = favoritesFiltered;
    if (_currentQuery.isNotEmpty) {
      final queryWords = _currentQuery.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      
      filtered = favoritesFiltered.where((series) {
        final seriesName = series.coreName.toLowerCase();
        final seasonNames = series.seasons.map((s) => s.fullTitle.toLowerCase()).join(' ');
        final releaseYears = series.seasons
            .map((s) => s.getReleaseYear(storage))
            .where((y) => y != null && y > 0)
            .join(' ');
        final fullText = '$seriesName $seasonNames $releaseYears';
        
        final textWords = fullText.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
        
        bool allWordsMatch = true;
        for (var qw in queryWords) {
          bool wordFound = false;
          for (var tw in textWords) {
            if (tw.startsWith(qw) || tw.contains(qw)) {
              wordFound = true;
              break;
            }
            // Fuzzy match (Levenshtein) for typos (e.g. deliusion -> delusion)
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

    List<AnimeSeries> sorted = List.from(filtered);

    // 3. Apply Sorting
    switch (_sortOrder) {
      case SortOrder.aToZ:
        sorted.sort((a, b) => a.coreName.compareTo(b.coreName));
        break;
      case SortOrder.zToA:
        sorted.sort((a, b) => b.coreName.compareTo(a.coreName));
        break;
      case SortOrder.newest:
        break;
      case SortOrder.oldest:
        sorted = sorted.reversed.toList();
        break;
    }

    // 4. Sort seasons within each series strictly chronologically by their Telegram message ID ascending (older/earlier posts first)
    for (var series in sorted) {
      series.seasons.sort((a, b) => a.posterMessage.id.compareTo(b.posterMessage.id));
    }
    
    return sorted;
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
    return v1[b.length];
  }

  void _triggerReleaseYearsSync() {
    _releaseYearsTimer?.cancel();
    _releaseYearsTimer = Timer(const Duration(seconds: 2), () {
      if (!_isFetchingReleaseYears) {
        _fetchReleaseYearsInBackground();
      }
    });
  }

  Future<void> _fetchReleaseYearsInBackground() async {
    if (_isFetchingReleaseYears) return;
    _isFetchingReleaseYears = true;

    try {
      final storage = ref.read(storageServiceProvider);
      final List<AnimeSeason> seasonsToFetch = [];
      final List<AnimeSeries> seriesCopy = List.from(_allSeries);
      
      for (final series in seriesCopy) {
        for (final season in series.seasons) {
          final title = season.fullTitle;
          final lowerTitle = title.toLowerCase();
          
          if (lowerTitle.contains('arc') || lowerTitle.contains('saga')) {
            continue;
          }
          
          final cachedYear = storage.getSeasonReleaseYear(title);
          if (cachedYear != null) {
            continue;
          }
          
          seasonsToFetch.add(season);
        }
      }

      if (seasonsToFetch.isEmpty) {
        _isFetchingReleaseYears = false;
        return;
      }

      Log.i('Starting background release year fetch for ${seasonsToFetch.length} seasons in category ${category.title}');

      for (final season in seasonsToFetch) {
        while (ref.read(pipControllerProvider) != null) {
          await Future.delayed(const Duration(seconds: 3));
        }

        final title = season.fullTitle;
        int? fetchedYear;
        
        try {
          if (category.title == 'Anime') {
            fetchedYear = await _fetchAnimeReleaseYearFromMal(title);
          } else {
            fetchedYear = await _fetchMediaReleaseYearFromTrakt(title);
          }
        } catch (e, stack) {
          Log.e('Failed to fetch release year for: $title', e, stack);
        }

        if (fetchedYear != null) {
          await storage.setSeasonReleaseYear(title, fetchedYear);
          Log.i('Cached release year for "$title": $fetchedYear');
          
          if (state.value != null) {
            state = AsyncValue.data(_applySearchAndSort(_allSeries));
          }
        }

        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (e, stack) {
      Log.e('Error in background release year fetch loop', e, stack);
    } finally {
      _isFetchingReleaseYears = false;
    }
  }

  Future<int?> _fetchAnimeReleaseYearFromMal(String title) async {
    try {
      final query = Uri.encodeComponent(title);
      final url = 'https://api.jikan.moe/v4/anime?q=$query&limit=1';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          final anime = data['data'][0];
          int? year;
          if (anime['year'] != null) {
            year = anime['year'] as int?;
          }
          if (year == null && anime['aired'] != null) {
            final prop = anime['aired']['prop'];
            if (prop != null && prop['from'] != null) {
              year = prop['from']['year'] as int?;
            }
            if (year == null && anime['aired']['from'] != null) {
              final fromStr = anime['aired']['from'] as String;
              year = DateTime.tryParse(fromStr)?.year;
            }
          }
          if (year != null) {
            return year;
          }
        }
        return 0; // No results found, cache 0
      } else if (response.statusCode == 404) {
        return 0; // Not found, cache 0
      } else {
        Log.w('Jikan API returned status code ${response.statusCode} for query "$title"');
        return null; // HTTP error, retry later
      }
    } catch (e, stack) {
      Log.e('Error calling Jikan API for query "$title"', e, stack);
      return null;
    }
  }

  Future<int?> _fetchMediaReleaseYearFromTrakt(String title) async {
    try {
      final query = Uri.encodeComponent(title);
      final type = category.title == 'Movies' ? 'movie' : 'show';
      final url = 'https://api.trakt.tv/search/$type?query=$query&limit=1';
      
      final headers = {
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': '05553e1be851c22a76f7df2b8a7c29be60cb5038ecbe6e80b2a7587dfb38ea47',
      };

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final first = data[0];
          if (first['type'] != null && first[first['type']] != null) {
            final media = first[first['type']];
            final year = media['year'] as int?;
            if (year != null) {
              return year;
            }
          }
        }
        return 0; // No results found, cache 0
      } else if (response.statusCode == 404) {
        return 0; // Not found, cache 0
      } else {
        Log.w('Trakt API returned status code ${response.statusCode} for query "$title"');
        return null; // HTTP error, retry later
      }
    } catch (e, stack) {
      Log.e('Error calling Trakt API for query "$title"', e, stack);
      return null;
    }
  }
}

class AnimeController extends HomeController {
  @override
  ChannelCategory get category => Constants.categories[0];
}

class MoviesController extends HomeController {
  @override
  ChannelCategory get category => Constants.categories[1];
}

class WebSeriesController extends HomeController {
  @override
  ChannelCategory get category => Constants.categories[2];
}

final animeControllerProvider = AsyncNotifierProvider<AnimeController, List<AnimeSeries>>(AnimeController.new);
final moviesControllerProvider = AsyncNotifierProvider<MoviesController, List<AnimeSeries>>(MoviesController.new);
final webSeriesControllerProvider = AsyncNotifierProvider<WebSeriesController, List<AnimeSeries>>(WebSeriesController.new);

class SeasonSortKey implements Comparable<SeasonSortKey> {
  final int seasonNum;
  final double partNum;
  final int messageId;
  final String original;
  final int releaseYear;
  final bool isExplicit;

  SeasonSortKey({
    required this.seasonNum,
    required this.partNum,
    required this.messageId,
    required this.original,
    required this.releaseYear,
    required this.isExplicit,
  });

  static int _parseRomanNumeral(String r) {
    switch (r.toLowerCase()) {
      case 'i': return 1;
      case 'ii': return 2;
      case 'iii': return 3;
      case 'iv': return 4;
      case 'v': return 5;
      case 'vi': return 6;
      case 'vii': return 7;
      case 'viii': return 8;
      case 'ix': return 9;
      case 'x': return 10;
      default: return 1;
    }
  }

  static SeasonSortKey fromSeason(AnimeSeason season, StorageService storage) {
    final name = season.seasonName;
    final lower = name.toLowerCase();
    final fullTitleLower = season.fullTitle.toLowerCase();
    int sNum = 1; // Default to 1 (base Season 1) if no numbers detected, so it sorts before Season 2+
    double pNum = 0.0;
    int year = 0;
    bool explicit = false;

    // Check if season fullTitle or name contains "arc" or "saga"
    if (fullTitleLower.contains('arc') || fullTitleLower.contains('saga') ||
        lower.contains('arc') || lower.contains('saga')) {
      year = 0; // Bypasses release year lookup
    } else {
      year = season.getReleaseYear(storage) ?? 0;
    }

    // Clean the name of part/volume indicators first to avoid matching their digits as season number.
    final lowerForSeason = lower
        .replaceAll(RegExp(r'\bpart\s*(\d+|[ivxIVX]+)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bvol(?:ume)?\s*(\d+|[ivxIVX]+)\b', caseSensitive: false), '')
        .trim();

    // Check for special keywords first
    if (lowerForSeason.contains('final season') || lowerForSeason.contains('final_season')) {
      sNum = 99;
      explicit = true;
    } else if (lowerForSeason.contains('ova') || lowerForSeason.contains('special') || lowerForSeason.contains('movie')) {
      sNum = 100;
      explicit = false;
    } else if (lowerForSeason.trim() == 'season s' || lowerForSeason.trim() == 's') {
      sNum = 2; // S suffix usually represents second season / sequel
      explicit = true;
    } else {
      // 1. Look for Roman numerals first
      final romanMatch = RegExp(r'\b(i|ii|iii|iv|v|vi|vii|viii|ix|x)\b', caseSensitive: false).firstMatch(lowerForSeason);
      if (romanMatch != null) {
        sNum = _parseRomanNumeral(romanMatch.group(1)!);
        explicit = true;
      } else {
        // 2. Look for "season X" or "sX"
        final match = RegExp(r'(?:season|s)\s*(\d+)').firstMatch(lowerForSeason);
        if (match != null) {
          sNum = int.tryParse(match.group(1)!) ?? 1;
          explicit = true;
        } else if (fullTitleLower.contains('arc') || fullTitleLower.contains('saga') ||
                   lowerForSeason.contains('arc') || lowerForSeason.contains('saga')) {
          // Default to season 1 for all arcs/sagas unless they have an explicit season X tag
          sNum = 1;
          explicit = false;
        } else {
          // Look for a number at the start of the string (e.g. "1.Agent..." or "14.Lost...")
          final matchStart = RegExp(r'^\s*(\d+)').firstMatch(lowerForSeason);
          if (matchStart != null) {
            sNum = int.tryParse(matchStart.group(1)!) ?? 1;
            explicit = true;
          } else {
            // Look for any other isolated number in the season name
            final matchAny = RegExp(r'\b(\d+)\b').firstMatch(lowerForSeason);
            if (matchAny != null) {
              sNum = int.tryParse(matchAny.group(1)!) ?? 1;
              explicit = true;
            }
          }
        }
      }
    }

    // Look for "part X"
    final partMatch = RegExp(r'part\s*(\d+)').firstMatch(lower);
    if (partMatch != null) {
      pNum = double.tryParse(partMatch.group(1)!) ?? 0.0;
    } else if (lower.contains('final chapters') || lower.contains('final chapter')) {
      pNum = 9.0;
    }

    return SeasonSortKey(
      seasonNum: sNum,
      partNum: pNum,
      messageId: season.posterMessage.id,
      original: name,
      releaseYear: year,
      isExplicit: explicit,
    );
  }

  @override
  int compareTo(SeasonSortKey other) {
    return messageId.compareTo(other.messageId);
  }
}
