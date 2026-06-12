import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../../models/anime_models.dart';

enum SortOrder { newest, oldest, aToZ, zToA }

abstract class HomeController extends AsyncNotifier<List<AnimeSeries>> {
  int _lastMessageId = 0;
  bool _hasMore = true;
  String _currentQuery = '';
  bool _isLoadingMore = false;
  SortOrder _sortOrder = SortOrder.newest;
  
  final List<td.Message> _rawMessages = [];

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

  @override
  FutureOr<List<AnimeSeries>> build() async {
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
          if (!_rawMessages.any((m) => m.id == event.message.id)) {
            _rawMessages.insert(0, event.message);
            _allSeries = _parseMessages(_rawMessages);
            if (state.value != null) {
              state = AsyncValue.data(_applySearchAndSort(_allSeries));
            }
          }
        }
      }
    });

    ref.onDispose(() {
      _updateSubscription?.cancel();
    });

    return _fetchInitial();
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

  void search(String query) {
    if (_currentQuery == query) return;
    _currentQuery = query;
    if (state.value != null) {
      state = AsyncValue.data(_applySearchAndSort(_allSeries));
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    
    try {
      int startingLength = _allSeries.length;
      while (_allSeries.length < startingLength + 10 && _hasMore) {
        final moreMessages = await _fetchMessages(fromId: _lastMessageId);
        for (final msg in moreMessages) {
          if (!_rawMessages.any((m) => m.id == msg.id)) {
            _rawMessages.add(msg);
          }
        }
        
        _allSeries = _parseMessages(_rawMessages);
        state = AsyncValue.data(_applySearchAndSort(_allSeries));
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<List<AnimeSeries>> _fetchInitial() async {
    _hasMore = true;
    _lastMessageId = 0;
    _rawMessages.clear();
    
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

    int iterations = 0;
    while (_allSeries.length < 10 && _hasMore && iterations < 10) {
      iterations++;
      final initialMessages = await _fetchMessages(fromId: _lastMessageId);
      if (initialMessages.isEmpty) {
        _hasMore = false;
        break;
      }
      for (final msg in initialMessages) {
        if (!_rawMessages.any((m) => m.id == msg.id)) {
          _rawMessages.add(msg);
        }
      }
      _allSeries = _parseMessages(_rawMessages);
    }
    
    return _applySearchAndSort(_allSeries);
  }

  Future<List<td.Message>> _fetchMessages({required int fromId}) async {
    final tdlibService = ref.read(tdlibServiceProvider);
    td.TdObject? response;
    int retries = 0;

    final fetchedBatch = <td.Message>[];
    int currentFromId = fromId;
    
    // Fetch larger chunks so we get posters more reliably
    while (fetchedBatch.length < 100 && retries < 3) {
      response = await tdlibService.sendAsync(td.GetChatHistory(
        chatId: category.channelId,
        fromMessageId: currentFromId,
        offset: 0,
        limit: 100 - fetchedBatch.length,
        onlyLocal: false,
      )).timeout(
        const Duration(seconds: 10),
        onTimeout: () => td.TdError(code: 408, message: "Request Timeout"),
      );

      if (response is td.TdError) {
        throw Exception("GetChatHistory failed: ${response.message} (Code: ${response.code})");
      }

      List<td.Message> fetched = [];
      if (response is td.Messages) {
        fetched = response.messages;
      } else if (response is td.FoundMessages) {
        fetched = response.messages;
      }

      if (fetched.isEmpty) {
        if (retries < 3) {
          retries++;
          await Future.delayed(const Duration(seconds: 1));
          continue;
        } else {
          _hasMore = false;
          break; 
        }
      }
      
      int nextFromId = fetched.last.id;
      
      for (final msg in fetched) {
        if (!fetchedBatch.any((m) => m.id == msg.id)) {
          fetchedBatch.add(msg);
        }
      }
      
      if (nextFromId == currentFromId) {
        _hasMore = false;
        break;
      }
      
      currentFromId = nextFromId;
      _lastMessageId = currentFromId;
    }

    return fetchedBatch;
  }

  String _normalizeSeriesName(String name) {
    var normalized = name.trim();
    // Remove "season X", "sX", "part X", "ova", etc.
    final regex = RegExp(r'(?:\s*-\s*|\s*:?\s*)?(?:season|s|part)\s*\d+.*', caseSensitive: false);
    normalized = normalized.replaceAll(regex, '');
    
    // Remove common trailing subtitles after a colon
    if (normalized.contains(':')) {
      normalized = normalized.split(':')[0].trim();
    }
    
    return normalized.trim();
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
        if (doc.document.mimeType.startsWith('video/') || doc.document.fileName.toLowerCase().endsWith('.mkv')) {
          currentEpisodes.add(msg);
        }
      } else if (msg.content is td.MessagePhoto) {
        final photo = msg.content as td.MessagePhoto;
        final captionText = photo.caption.text;
        
        if (captionText.isNotEmpty) {
          final lines = captionText.split('\n');
          final fullTitle = lines.first.trim();
          final baseName = _normalizeSeriesName(fullTitle);
          
          final newSeason = AnimeSeason(
            fullTitle: fullTitle,
            seasonName: fullTitle == baseName ? 'Season 1' : fullTitle.replaceFirst(baseName, '').replaceAll(':', '').trim(),
            posterMessage: msg,
            episodes: currentEpisodes.reversed.toList(),
          );
          
          if (!seriesMap.containsKey(baseName)) {
            seriesMap[baseName] = AnimeSeries(coreName: baseName, seasons: []);
            seriesList.add(seriesMap[baseName]!);
          }
          
          seriesMap[baseName]!.seasons.insert(0, newSeason);
          currentEpisodes = [];
        }
      }
    }

    return seriesList;
  }

  List<AnimeSeries> _applySearchAndSort(List<AnimeSeries> list) {
    // 0. Apply Favorites Filter
    List<AnimeSeries> favoritesFiltered = list;
    if (_showFavoritesOnly) {
      final storage = ref.read(storageServiceProvider);
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
        final fullText = '$seriesName $seasonNames';
        
        final textWords = fullText.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
        
        bool allWordsMatch = true;
        for (var qw in queryWords) {
          bool wordFound = false;
          for (var tw in textWords) {
            if (tw == qw || tw.contains(qw) || qw.contains(tw)) {
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

    // 4. Sort seasons within each series alphabetically (natural sort approach)
    for (var series in sorted) {
      series.seasons.sort((a, b) {
        final padA = a.seasonName.replaceAllMapped(RegExp(r'\d+'), (m) => m[0]!.padLeft(5, '0'));
        final padB = b.seasonName.replaceAllMapped(RegExp(r'\d+'), (m) => m[0]!.padLeft(5, '0'));
        return padA.compareTo(padB);
      });
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
