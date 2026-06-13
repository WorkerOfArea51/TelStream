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
      int iterations = 0;
      while (_allSeries.length < startingLength + 10 && _hasMore && iterations < 5) {
        iterations++;
        final moreMessages = await _fetchMessages(fromId: _lastMessageId, onlyLocal: false);
        if (moreMessages.isEmpty) {
          break;
        }
        for (final msg in moreMessages) {
          if (!_rawMessages.any((m) => m.id == msg.id)) {
            _rawMessages.add(msg);
          }
        }
        
        _rawMessages.sort((a, b) => b.id.compareTo(a.id));
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

    // 1. First, load the initial batch using onlyLocal: true to render instantly
    int iterations = 0;
    int currentFromId = 0;
    while (_allSeries.length < 10 && _hasMore && iterations < 10) {
      iterations++;
      final localMessages = await _fetchMessages(fromId: currentFromId, onlyLocal: true);
      if (localMessages.isEmpty) {
        break;
      }
      for (final msg in localMessages) {
        if (!_rawMessages.any((m) => m.id == msg.id)) {
          _rawMessages.add(msg);
        }
      }
      _allSeries = _parseMessages(_rawMessages);
      currentFromId = _rawMessages.last.id;
    }
    
    // 2. Immediately kick off background network sync to fetch any updates/new releases
    _syncFromNetwork();
    
    return _applySearchAndSort(_allSeries);
  }

  Future<void> _syncFromNetwork() async {
    try {
      int iterations = 0;
      int currentFromId = 0;
      bool changed = false;
      
      // Sync up to 300 messages to catch up on any updates since last launch
      while (iterations < 3) {
        iterations++;
        final networkMessages = await _fetchMessages(fromId: currentFromId, onlyLocal: false);
        if (networkMessages.isEmpty) {
          break;
        }
        
        for (final msg in networkMessages) {
          if (!_rawMessages.any((m) => m.id == msg.id)) {
            _rawMessages.add(msg);
            changed = true;
          }
        }
        
        currentFromId = networkMessages.last.id;
      }
      
      if (changed) {
        _rawMessages.sort((a, b) => b.id.compareTo(a.id));
        _allSeries = _parseMessages(_rawMessages);
        state = AsyncValue.data(_applySearchAndSort(_allSeries));
      }
    } catch (e) {
      print("Network sync error: $e");
    }
  }

  Future<List<td.Message>> _fetchMessages({required int fromId, required bool onlyLocal}) async {
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
        // If we already successfully fetched some messages in this batch, return them
        // and keep _hasMore = true so the next pagination can attempt to fetch further.
        if (fetchedBatch.isNotEmpty || onlyLocal) {
          break;
        }
        
        // If we got nothing at all, wait and retry to allow TDLib's background sync to complete.
        if (retries < 3) {
          retries++;
          await Future.delayed(const Duration(seconds: 1));
          continue;
        } else {
          // No messages found even after retries; we've truly hit the end of history.
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

    // 4. Sort seasons within each series chronologically (using hybrid parsed rules + message post date order)
    for (var series in sorted) {
      series.seasons.sort((a, b) {
        return SeasonSortKey.fromSeason(a).compareTo(SeasonSortKey.fromSeason(b));
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

class SeasonSortKey implements Comparable<SeasonSortKey> {
  final int seasonNum;
  final double partNum;
  final int messageId;
  final String original;

  SeasonSortKey({
    required this.seasonNum,
    required this.partNum,
    required this.messageId,
    required this.original,
  });

  static SeasonSortKey fromSeason(AnimeSeason season) {
    final name = season.seasonName;
    final lower = name.toLowerCase();
    int sNum = 0; // Default to 0 for custom arc names/no numbers detected
    double pNum = 0.0;

    // Check for special keywords first
    if (lower.contains('final season') || lower.contains('final_season')) {
      sNum = 99;
    } else if (lower.contains('ova') || lower.contains('special') || lower.contains('movie')) {
      sNum = 100;
    } else {
      // Look for "season X" or "sX"
      final match = RegExp(r'(?:season|s)\s*(\d+)').firstMatch(lower);
      if (match != null) {
        sNum = int.tryParse(match.group(1)!) ?? 0;
      } else {
        // Look for any isolated number in the season name
        final matchAny = RegExp(r'\b(\d+)\b').firstMatch(lower);
        if (matchAny != null) {
          sNum = int.tryParse(matchAny.group(1)!) ?? 0;
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
    );
  }

  @override
  int compareTo(SeasonSortKey other) {
    // 1. Compare season number
    if (seasonNum != other.seasonNum) {
      return seasonNum.compareTo(other.seasonNum);
    }
    
    // 2. Compare part numbers
    if (partNum != other.partNum) {
      return partNum.compareTo(other.partNum);
    }
    
    // 3. Fallback: Sort by Telegram message ID ascending (older/earlier posts first)
    if (messageId != other.messageId) {
      return messageId.compareTo(other.messageId);
    }
    
    // 4. Ultimate fallback to alphabetical name
    return original.compareTo(other.original);
  }
}
