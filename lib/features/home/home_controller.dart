import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../core/secrets.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';

import '../../models/anime_models.dart';
import '../../core/logger.dart';
import '../player/pip_manager.dart';
import '../../core/utils/path_helper.dart';
import 'package:synchronized/synchronized.dart';

class ParseMessagesArgs {
  final List<td.Message> raw;
  final bool isMovie;
  ParseMessagesArgs(this.raw, this.isMovie);
}

Future<List<AnimeSeries>> parseMessagesWithYield(List<td.Message> raw, bool isMovie) async {
  
  // 1. Separate poster messages and episode messages
  final List<td.Message> posterMessages = [];
  final List<td.Message> episodeMessages = [];

  int count = 0;
  for (final msg in raw) {
    count++;
    if (msg.content is td.MessagePhoto) {
      final photo = msg.content as td.MessagePhoto;
      if (photo.caption.text.isNotEmpty) {
        posterMessages.add(msg);
      }
    } else if (msg.content is td.MessageVideo) {
      episodeMessages.add(msg);
    } else if (msg.content is td.MessageDocument) {
      final fileName = HomeController.getMessageFileName(msg).toLowerCase();
      final doc = msg.content as td.MessageDocument;
      if (doc.document.mimeType.startsWith('video/') ||
          fileName.endsWith('.mkv') ||
          fileName.endsWith('.mp4') ||
          fileName.endsWith('.avi') ||
          fileName.endsWith('.mov') ||
          fileName.endsWith('.webm') ||
          fileName.endsWith('.flv') ||
          fileName.endsWith('.wmv')) {
        episodeMessages.add(msg);
      }
    }
    // Yield every 50 messages to prevent UI lag
    if (count % 50 == 0) await Future.delayed(const Duration(milliseconds: 1));
  }

  // 2. Pre-process poster details & initialize series map/list
  final List<Map<String, dynamic>> posterDetails = [];
  final Map<String, AnimeSeries> seriesMap = {};
  final List<AnimeSeries> seriesList = [];

  for (final pMsg in posterMessages) {
    final photo = pMsg.content as td.MessagePhoto;
    final captionText = photo.caption.text;
    final lines = captionText.split('\n');
    final fullTitle = lines.first.trim();
    final baseName = HomeController.normalizeSeriesName(fullTitle, isMovie: isMovie);
    
    final canonicalKey = baseName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    String matchedKey = isMovie ? '${canonicalKey}_${pMsg.id}' : canonicalKey;

    if (!isMovie) {
      for (final existingKey in seriesMap.keys) {
        if (existingKey.length >= 7 && canonicalKey.length >= 7) {
          // Bypass prefix/substring grouping for franchise sequels/spinoffs
          bool isFranchiseBypass = false;
          const franchisePrefixes = ['dragonball', 'naruto', 'onepiece', 'bleach'];
          for (final prefix in franchisePrefixes) {
            if ((canonicalKey.startsWith(prefix) || existingKey.startsWith(prefix)) &&
                canonicalKey != existingKey) {
              isFranchiseBypass = true;
              break;
            }
          }
          if (isFranchiseBypass) continue;

          if (canonicalKey.startsWith(existingKey)) {
            matchedKey = existingKey;
            break;
          } else if (existingKey.startsWith(canonicalKey)) {
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

    posterDetails.add({
      'message': pMsg,
      'fullTitle': fullTitle,
      'baseName': baseName,
      'matchedKey': matchedKey,
      'episodesList': <td.Message>[],
    });
    
    if (posterDetails.length % 100 == 0) await Future.delayed(Duration.zero);
  }

  // 3. Match each episode message to its preceding poster message (pure sequential chronological)
  int epCount = 0;
  for (final ep in episodeMessages) {
    Map<String, dynamic>? selectedPoster;
    int maxPrecedingId = -1;

    for (final pd in posterDetails) {
      final pMsg = pd['message'] as td.Message;
      if (pMsg.id < ep.id && pMsg.id > maxPrecedingId) {
        maxPrecedingId = pMsg.id;
        selectedPoster = pd;
      }
    }
    
    // Fallback: If no preceding poster, use the closest poster overall
    if (selectedPoster == null && posterDetails.isNotEmpty) {
      int minDistance = -1;
      for (final pd in posterDetails) {
        final pMsg = pd['message'] as td.Message;
        final dist = (ep.id - pMsg.id).abs();
        if (minDistance == -1 || dist < minDistance) {
          minDistance = dist;
          selectedPoster = pd;
        }
      }
    }

    if (selectedPoster != null) {
      (selectedPoster['episodesList'] as List<td.Message>).add(ep);
    } else {
      // No poster found — create a standalone poster from the video itself.
      // This handles user channels where videos are posted without preceding text/photo posts.
      final epFileName = HomeController.getMessageFileName(ep);
      final epTitle = epFileName.isNotEmpty 
          ? epFileName.replaceAll(RegExp(r'\.(mkv|mp4|avi|mov|webm|flv|wmv|ts|m4v|3gp)$', caseSensitive: false), '').replaceAll('_', ' ').trim()
          : 'Video ${ep.id}';
      final epBaseName = HomeController.normalizeSeriesName(epTitle, isMovie: isMovie);
      final epKey = isMovie ? '${epBaseName}_${ep.id}' : epBaseName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      
      // Create a synthetic poster entry using the video message itself as the "poster"
      final standalonePoster = {
        'message': ep,
        'fullTitle': epTitle,
        'baseName': epBaseName,
        'matchedKey': epKey,
        'episodesList': <td.Message>[ep],
      };
      posterDetails.add(standalonePoster);
      
      if (!seriesMap.containsKey(epKey)) {
        seriesMap[epKey] = AnimeSeries(coreName: epBaseName, seasons: []);
        seriesList.add(seriesMap[epKey]!);
      }
    }
    
    // Yield to keep UI smooth
    epCount++;
    if (epCount % 50 == 0) await Future.delayed(const Duration(milliseconds: 1));
  }

  // 4. Assemble seasons and populate the series list
  for (final pd in posterDetails) {
    final pMsg = pd['message'] as td.Message;
    final fullTitle = pd['fullTitle'] as String;
    final baseName = pd['baseName'] as String;
    final matchedKey = pd['matchedKey'] as String;
    final rawEps = pd['episodesList'] as List<td.Message>;

    // Sort episodes inside the season numerically by episode number parsed from filename
    final sortedEpisodes = List<td.Message>.from(rawEps)
      ..sort((a, b) {
        final epA = HomeController.parseEpisodeNumber(a);
        final epB = HomeController.parseEpisodeNumber(b);
        if (epA != epB) {
          return epA.compareTo(epB);
        }
        return a.id.compareTo(b.id);
      });

    final newSeason = AnimeSeason(
      fullTitle: fullTitle,
      seasonName: HomeController.parseSeasonName(fullTitle, baseName, isMovie: isMovie),
      posterMessage: pMsg,
      episodes: sortedEpisodes,
    );

    final series = seriesMap[matchedKey];
    if (series != null) {
      final existingIndex = series.seasons.indexWhere((s) => s.posterMessage.id == pMsg.id);
      if (existingIndex != -1) {
        series.seasons[existingIndex] = newSeason;
      } else {
        series.seasons.add(newSeason);
      }
    }
  }

  return seriesList;
}



enum ConnectionStatus { connected, connecting, waitingForNetwork, unknown }
class ConnectionStateNotifier extends Notifier<ConnectionStatus> { @override ConnectionStatus build() => ConnectionStatus.unknown; }
final connectionStateProvider = NotifierProvider<ConnectionStateNotifier, ConnectionStatus>(ConnectionStateNotifier.new);
class IsSyncingNotifier extends Notifier<bool> { @override bool build() => false; }
final isSyncingProvider = NotifierProvider<IsSyncingNotifier, bool>(IsSyncingNotifier.new);

enum SortOrder { newest, oldest, aToZ, zToA }

abstract class HomeController extends AsyncNotifier<List<AnimeSeries>> {
  static final _bracketSuffixRegex = RegExp(r'\s*[\[\(].*?[\]\)]\s*$');
  static final _seasonSuffixRegex = RegExp(r'(?:\s*[-–—:|]\s*)?\b(?:(?:season|part)\s*(?:\d+|[ivxIVX]+)|s\s*\d+|s\s+[ivxIVX]+)\b', caseSensitive: false);
  static final _finalSeasonRegex = RegExp(r'(?:\s*[-–—:|]\s*)?\b(?:the\s+)?final\s+(?:season|chapters?|act|arcs?|part)?\b', caseSensitive: false);
  static final _movieOvaRegex = RegExp(r'(?:\s*[-–—:|]\s*)?\b(?:the\s+)?(?:movie|ova|oad|specials?|prequels?|sequels?)\b', caseSensitive: false);
  static final _romanNumeralRegex = RegExp(r'\s*\b[ivxIVX]+\b$', caseSensitive: false);
  static final _singleDigitRegex = RegExp(r'(?<!\bno)(?<!\bno\.)(?<!\bvol)(?<!\bvol\.)\s+\b\d\b$', caseSensitive: false);
  static final _singleLetterSRegex = RegExp(r'\s+\b[sS]\b$');
  static final _customSubtitlesRegex = RegExp(r'(?:\s*[-–—:|]\s*)?\b(?:Memory\s+Snow|Frozen\s+Bond|Hyouketsu\s+no\s+Kizuna)\b', caseSensitive: false);
  static final _rootARegex = RegExp(r'(?:\s*[-–—:|]\s*)?(?:root\s*a|root\s*alpha|√\s*a)\b', caseSensitive: false);
  static final _rePrefixRegex = RegExp(r'\b[rR][eE]\b$');
  static final _trailingPunctuationRegex = RegExp(r'\s*[-–—:|]+\s*$');

  int _lastMessageId = 0;
  bool _hasMore = true;
  String _currentQuery = '';
  bool _isLoadingMore = false;
  SortOrder _sortOrder = SortOrder.newest;
  
  final List<td.Message> _rawMessages = [];
  final Set<int> _rawMessageIds = {};
  final _mutationLock = Lock();

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  SortOrder get sortOrder => _sortOrder;

  ChannelCategory get category;
  List<AnimeSeries> _allSeries = [];
  List<AnimeSeries> get allSeries => _allSeries;
  late String _resolvedChatTitle = category.title;
  String get resolvedChatTitle => _resolvedChatTitle;

  bool _showFavoritesOnly = false;
  bool get showFavoritesOnly => _showFavoritesOnly;

  StreamSubscription? _updateSubscription;
  bool _cacheLoadComplete = false;
  bool _isFetchingReleaseYears = false;
  Timer? _releaseYearsTimer;
  Timer? _cacheWriteDebounce;
  bool _isDisposed = false;

  void _scheduleCatalogCacheWrite() {
    _cacheWriteDebounce?.cancel();
    _cacheWriteDebounce = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed) _saveCatalogCache();
    });
  }

  @override
  FutureOr<List<AnimeSeries>> build() async {
    final storage = ref.read(storageServiceProvider);
    final lastSeen = storage.getLastSeenVersion();
    if (lastSeen != Constants.currentVersion) {
      try {
        final directory = await getAppDirectory();
        for (final cat in Constants.categories) {
          final cachePath = '${directory.path}/catalog_cache_${cat.channelId}.json';
          final file = File(cachePath);
          try {
            if (await file.exists()) {
              await file.delete();
              Log.i('Deleted obsolete cache file due to version upgrade: $cachePath');
            }
          } catch (e) {
            Log.w('Could not delete cache file $cachePath (might be deleted by another thread): $e');
          }
        }
      } catch (e, stack) {
        Log.e('Failed to delete obsolete cache files', e, stack);
      }
      await storage.setLastSeenVersion(Constants.currentVersion);
    }

    final tdlibService = ref.watch(tdlibServiceProvider);
    
    ref.listen(favoritesProvider, (previous, next) async {
      if (_showFavoritesOnly && state.value != null) {
        if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
      }
    });

    _updateSubscription?.cancel();
    _updateSubscription = tdlibService.updates.listen((event) async {
      if (event is td.UpdateNewMessage) {
        if (event.message.chatId == category.channelId) {
          await _mutationLock.synchronized(() async {
            if (!_rawMessageIds.contains(event.message.id)) {
              _rawMessages.insert(0, event.message);
              _rawMessageIds.add(event.message.id);
              final changed = await _upsertMessageIncrementally(event.message);
              if (changed && state.value != null) {
                if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
              }
              _triggerReleaseYearsSync();
              if (_cacheLoadComplete) {
                _scheduleCatalogCacheWrite();
              }
            }
          });
        }
      } else if (event is td.UpdateMessageContent) {
        if (event.chatId == category.channelId) {
          _fetchAndAndUpdateSingleMessage(event.messageId, tdlibService);
        }
      } else if (event is td.UpdateMessageEdited) {
        if (event.chatId == category.channelId) {
          _fetchAndAndUpdateSingleMessage(event.messageId, tdlibService);
        }
      } else if (event is td.UpdateDeleteMessages) {
        if (event.chatId == category.channelId && !event.fromCache) {
          await _mutationLock.synchronized(() async {
            bool changed = false;
            for (final id in event.messageIds) {
              final removedIndex = _rawMessages.indexWhere((m) => m.id == id);
              if (removedIndex != -1) {
                _rawMessages.removeAt(removedIndex);
                _rawMessageIds.remove(id);
                changed = true;
              }
            }
            if (changed) {
              _allSeries = await _parseMessages(_rawMessages);
              if (state.value != null) {
                if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
              }
              if (_cacheLoadComplete) {
                _scheduleCatalogCacheWrite();
              }
              Log.i('Real-time deleted messages from catalog: ${event.messageIds}');
            }
          });
        }
      } else if (event is td.UpdateConnectionState) {
        final state = event.state;
        final isConnected = state is td.ConnectionStateReady;
        final isConnecting = state is td.ConnectionStateConnecting;
        final isWaiting = state is td.ConnectionStateWaitingForNetwork;

        if (isConnected) {
          ref.read(connectionStateProvider.notifier).state = ConnectionStatus.connected;
        } else if (isConnecting) {
          ref.read(connectionStateProvider.notifier).state = ConnectionStatus.connecting;
        } else if (isWaiting) {
          ref.read(connectionStateProvider.notifier).state = ConnectionStatus.waitingForNetwork;
        } else {
          ref.read(connectionStateProvider.notifier).state = ConnectionStatus.unknown;
        }

        if (isConnected && _cacheLoadComplete && !_isDisposed) {
          Log.i('Network reconnected, triggering background sync for ${category.title}');
          return _syncFromNetwork();
        }
      }
    });

    ref.onDispose(() {
      _isDisposed = true;
      _updateSubscription?.cancel();
      _releaseYearsTimer?.cancel();
    });

    _triggerReleaseYearsSync();
    
    Log.i('Initializing HomeController for category: ${category.title}');
    try {
      final initialList = await _fetchInitial();
      
      // Schedule background sync to start in the next event loop tick,
      // ensuring the provider is fully built and state is set before updating it.
      Future.delayed(const Duration(milliseconds: 200), () async {
        if (_isDisposed) return;
        try {
          await _syncFromNetwork();
        } catch (e, stack) {
          Log.e('Background sync failed for category: ${category.title}', e, stack);
        }
      });
      
      return initialList;
    } catch (e, stack) {
      Log.e('HomeController initialization failed for category: ${category.title}', e, stack);
      rethrow;
    }
  }

  void setSortOrder(SortOrder order) async {
    _sortOrder = order;
    if (state.value != null) {
      if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
    }
  }

  void toggleFavoritesFilter() async {
    _showFavoritesOnly = !_showFavoritesOnly;
    if (state.value != null) {
      if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
    }
  }

  void search(String query) async {
    if (_currentQuery == query) return;
    _currentQuery = query;
    
    if (state.value != null || _allSeries.isNotEmpty) {
      if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
    }
  }

  List<int> getAvailableYears() {
    final storage = ref.read(storageServiceProvider);
    final Set<int> years = {};
    for (final series in _allSeries) {
      for (final season in series.seasons) {
        final yr = season.getReleaseYear(storage);
        if (yr != null && yr > 0) {
          years.add(yr);
        }
      }
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  static List<AnimeSeries> _parseCacheJson(String content) {
    final List<dynamic> jsonList = json.decode(content);
    return jsonList.map((s) => AnimeSeries.fromJson(s as Map<String, dynamic>)).toList();
  }

  void updateSeasonEpisodes(String coreName, int posterId, List<td.Message> episodes) async {
    bool changed = false;
    await _mutationLock.synchronized(() async {
      for (int i = 0; i < _allSeries.length; i++) {
        if (_allSeries[i].coreName == coreName) {
          for (int j = 0; j < _allSeries[i].seasons.length; j++) {
            if (_allSeries[i].seasons[j].posterMessage.id == posterId) {
              _allSeries[i].seasons[j] = _allSeries[i].seasons[j].copyWith(episodes: episodes);
              changed = true;
              break;
            }
          }
        }
        if (changed) break;
      }
      
      if (changed) {
        for (final ep in episodes) {
          if (!_rawMessageIds.contains(ep.id)) {
            _rawMessages.add(ep);
            _rawMessageIds.add(ep.id);
          }
        }
      }
    });

    if (changed) {
      if (state.value != null && !_isDisposed) {
        state = AsyncValue.data(await _applySearchAndSort(_allSeries));
      }
      if (_cacheLoadComplete) {
        _scheduleCatalogCacheWrite();
      }
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
        await _mutationLock.synchronized(() async {
          for (final msg in moreMessages) {
            if (!_rawMessageIds.contains(msg.id)) {
              _rawMessages.add(msg);
              _rawMessageIds.add(msg.id);
              changed = true;
            }
          }
          
          if (changed) {
            _rawMessages.sort((a, b) => b.id.compareTo(a.id));
            _allSeries = await _parseMessages(_rawMessages);
            if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
            _triggerReleaseYearsSync();
          }
        });
      }
      if (changed && _cacheLoadComplete) {
        _scheduleCatalogCacheWrite();
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<List<AnimeSeries>> _fetchInitial() async {
    Log.i('[_fetchInitial] Started for category: ${category.title} (Channel: ${category.channelId})');
    _hasMore = true;
    _lastMessageId = 0;
    
    // 1. Try loading catalog cache FIRST (instant return, no network or stagger delay)
    try {
      final directory = await getAppDirectory();
      final cachePath = '${directory.path}/catalog_cache_${category.channelId}.json';
      final file = File(cachePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<AnimeSeries> cachedList = await compute(_parseCacheJson, content);
        
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
        _hasMore = false; // Prevent UI from calling loadMore() on startup
        Log.i('Loaded ${cachedList.length} series from catalog cache for category ${category.title} instantly');
        return await _applySearchAndSort(_allSeries);
      }
    } catch (e, stack) {
      Log.e('Failed to load catalog cache for ${category.title}, falling back to TDLib local DB load', e, stack);
    }

    // 2. Cache miss fallback: Load from local DB (occurs on absolute first launch ever)
    final tdlibService = ref.read(tdlibServiceProvider);
    
    // Stagger startup requests to prevent concurrent connection sessions to TDLib (runs asynchronously)
    if (category.isMovie) {
      await Future.delayed(const Duration(milliseconds: 1500));
    } else if (category.title == 'Web Series') {
      await Future.delayed(const Duration(milliseconds: 3000));
    }
    
    // Helper to send request with a safety timeout to prevent hanging
    Future<td.TdObject> sendWithTimeout(td.TdFunction request) {
      return tdlibService.sendAsync(request).timeout(
        const Duration(seconds: 10),
        onTimeout: () => td.TdError(code: 408, message: "Request Timeout"),
      );
    }
    
    // Ensure TDLib has loaded the chat (needed for user-added channels 
    // that aren't in the main chat list yet)
    try {
      await sendWithTimeout(td.OpenChat(chatId: category.channelId));
    } catch (_) {
      // OpenChat may fail if chat is already open — that's OK
    }
    
    td.TdObject chatRes = await sendWithTimeout(td.GetChat(chatId: category.channelId));
    if (chatRes is td.TdError) {
      try {
        await sendWithTimeout(const td.LoadChats(chatList: td.ChatListMain(), limit: 100));
        chatRes = await sendWithTimeout(td.GetChat(chatId: category.channelId));
      } catch (_) {}
      
      if (chatRes is td.TdError) {
        try {
          await sendWithTimeout(td.CheckChatInviteLink(inviteLink: category.inviteLink));
          chatRes = await sendWithTimeout(td.GetChat(chatId: category.channelId));
        } catch (_) {}
      }
      
      if (chatRes is td.TdError) {
        try {
          final joinRes = await sendWithTimeout(td.JoinChatByInviteLink(inviteLink: category.inviteLink));
          if (joinRes is td.Chat) {
            chatRes = joinRes;
          } else {
            chatRes = await sendWithTimeout(td.GetChat(chatId: category.channelId));
          }
        } catch (_) {}
      }
      
      int retries = 0;
      // Resilient polling loop: allow up to 30 seconds for TDLib to sync the chat from the network on a slow PC
      while (chatRes is td.TdError && retries < 30 && !_isDisposed) {
        await Future.delayed(const Duration(seconds: 1));
        chatRes = await sendWithTimeout(td.GetChat(chatId: category.channelId));
        retries++;
      }
    }

    if (chatRes is td.TdError) {
      throw Exception("GetChat fallback failed/timed out during initial load after 60s: ${chatRes.message} (Code: ${chatRes.code})");
    }

    if (chatRes is td.Chat) {
      _resolvedChatTitle = chatRes.title;
    }

    _rawMessages.clear();
    _rawMessageIds.clear();
    int iterations = 0;
    int currentFromId = 0;
    while (_hasMore && iterations < 200 && !_isDisposed) {
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
      currentFromId = _rawMessages.last.id;
      
      // Yield to the UI thread to prevent ANR during massive local DB loading
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    if (_isDisposed) {
      Log.i("Provider was disposed during DB load, aborting cleanly.");
      return [];
    }
    
    _allSeries = await _parseMessages(_rawMessages);
    _cacheLoadComplete = !_hasMore;
    Log.i('[_fetchInitial] Completed for category: ${category.title}, found ${_allSeries.length} series');
    return await _applySearchAndSort(_allSeries);
  }

  Future<void> _saveCatalogCache() async {
    try {
      final directory = await getAppDirectory();
      final cachePath = '${directory.path}/catalog_cache_${category.channelId}.json';
      final file = File(cachePath);
      
      final List<Map<String, dynamic>> jsonList = [];
      for (int i = 0; i < _allSeries.length; i++) {
        if (i > 0 && i % 100 == 0) await Future.delayed(const Duration(milliseconds: 1));
        jsonList.add(_allSeries[i].toJson());
      }
      
      final content = await compute(jsonEncode, jsonList);
      await file.writeAsString(content);
      Log.i('Saved catalog cache for category ${category.title} to $cachePath');
    } catch (e, stack) {
      Log.e('Failed to save catalog cache for ${category.title}', e, stack);
    }
  }

  Future<void> _syncFromNetwork({bool forceDeep = false}) async {
    Log.i('[_syncFromNetwork] Scheduling background sync for category: ${category.title} (forceDeep: $forceDeep)');

    // Stagger startup requests to prevent concurrent connection sessions to TDLib (runs asynchronously in background)
    if (!forceDeep) {
      if (category.isMovie) {
        await Future.delayed(const Duration(seconds: 3));
      } else if (category.title == 'Web Series') {
        await Future.delayed(const Duration(seconds: 6));
      }
    }

    Log.i('[_syncFromNetwork] Starting background sync execution for category: ${category.title}');

    ref.read(isSyncingProvider.notifier).state = true;
    DateTime? lastSyncDuringPlayback;
    try {
      final tdlibService = ref.read(tdlibServiceProvider);
      
      // Ensure chat title is resolved if it was loaded directly from cache miss
      if (_resolvedChatTitle == category.title) {
        try {
          final chatRes = await tdlibService.sendAsync(td.GetChat(chatId: category.channelId));
          if (chatRes is td.Chat) {
            _resolvedChatTitle = chatRes.title;
            if (!_isDisposed && state.value != null) {
              state = AsyncValue.data(state.value!);
            }
          }
        } catch (_) {}
      }

      _hasMore = true; // Reset _hasMore to allow background network fetching
      final storage = ref.read(storageServiceProvider);
      int currentFromId = 0;
      bool changed = false;
      bool reachedEnd = false;
      
      DateTime lastUiUpdateTime = DateTime.now();

      // Sync messages incrementally from the network in the background
      while (_hasMore && !_isDisposed) {
        try {
          if (ref.read(pipControllerProvider) != null) {
            final now = DateTime.now();
            final lastRun = lastSyncDuringPlayback ?? DateTime.fromMillisecondsSinceEpoch(0);
            final elapsed = now.difference(lastRun);
            if (elapsed < const Duration(seconds: 60)) {
              await Future.delayed(const Duration(seconds: 5));
              continue;
            }
            lastSyncDuringPlayback = now;
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
          
          await _mutationLock.synchronized(() async {
            for (final msg in networkMessages) {
              
              final existingIndex = _rawMessages.indexWhere((m) => m.id == msg.id);
              if (existingIndex != -1) {
                // Always overwrite existing message to capture any edits/updates (e.g. video files updated/replaced)
                _rawMessages[existingIndex] = msg;
                changed = true;
              } else {
                _rawMessages.add(msg);
                _rawMessageIds.add(msg.id);
                changed = true;
              }
            }
            
            if (changed) {
              final now = DateTime.now();
              final isNearEnd = reachedEnd || !_hasMore;
              if (isNearEnd || now.difference(lastUiUpdateTime) > const Duration(milliseconds: 1500)) {
                _rawMessages.sort((a, b) => b.id.compareTo(a.id));
                _allSeries = await _parseMessages(_rawMessages);
                if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
                _triggerReleaseYearsSync();
                if (_cacheLoadComplete) {
                  _scheduleCatalogCacheWrite();
                }
                lastUiUpdateTime = now;
                changed = false; // Reset changed flag
              }
            }
          });
          
          if (reachedEnd) {
            break;
          }
          currentFromId = networkMessages.last.id;
          
          // Brief pause to respect Telegram rate limits and yield UI thread
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e, stackTrace) {
          Log.e("Error during background sync iteration", e, stackTrace);
          // Wait a bit before retrying the next iteration to prevent hammering the network
          await Future.delayed(const Duration(seconds: 4));
        }
      }

      // Final UI update to guarantee that any pending changes are flushed
      if (_isDisposed) return;
      if (changed) {
        _rawMessages.sort((a, b) => b.id.compareTo(a.id));
        _allSeries = await _parseMessages(_rawMessages);
        if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
        _triggerReleaseYearsSync();
      }

      // Update the indexing checkpoint if we have indexed items
      if (_rawMessages.isNotEmpty) {
        await storage.setLastIndexedMessageId(category.channelId, _rawMessages.first.id);
      }

      _cacheLoadComplete = true;
      _scheduleCatalogCacheWrite();
    } catch (e, stackTrace) {
      Log.e("Background sync error", e, stackTrace);
    } finally {
      if (!_isDisposed) {
        ref.read(isSyncingProvider.notifier).state = false;
      }
    }
  }

  Future<void> triggerManualSync() {
    return _syncFromNetwork(forceDeep: true);
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
        if (response.code == 400 && response.message == "Chat not found") {
          Log.w("GetChatHistory failed: Chat not found for ID ${category.channelId}. Breaking loop.");
          break;
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
          if (!onlyLocal && fromId != 0) {
            _hasMore = false;
          }
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
          if (currentFromId <= 5 && !onlyLocal) {
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

  Future<List<td.Message>> _fetchMessagesParallel({required int fromId}) async {
    // Sequentially fetch messages to prevent Telegram rate-limiting / FLOOD_WAIT blocks
    return _fetchMessages(fromId: fromId, onlyLocal: false);
  }

  static String normalizeSeriesName(String name, {bool isMovie = false}) {
    var normalized = name.trim();

    // 1. Remove bracketed text at the end, e.g. [1080p], (Movie), etc.
    normalized = normalized.replaceAll(_bracketSuffixRegex, '');

    if (!isMovie) {
      // 2. Remove trailing season / part / movie indicators.
      normalized = normalized.replaceAll(_seasonSuffixRegex, '');
      normalized = normalized.replaceAll(_finalSeasonRegex, '');
      normalized = normalized.replaceAll(_movieOvaRegex, '');
      normalized = normalized.replaceAll(_romanNumeralRegex, '');
      normalized = normalized.replaceAll(_singleDigitRegex, '');
      normalized = normalized.replaceAll(_singleLetterSRegex, '');
      normalized = normalized.replaceAll(_customSubtitlesRegex, '');
      normalized = normalized.replaceAll(_rootARegex, '');

      // 3. Remove common trailing subtitles after a colon if the prefix has length > 3 and doesn't end with "Re"
      if (normalized.contains(':')) {
        final parts = normalized.split(':');
        final prefix = parts[0].trim();
        final isRePrefix = _rePrefixRegex.hasMatch(prefix);
        if (prefix.length > 3 && !isRePrefix) {
          normalized = prefix;
        }
      }
    }

    // 4. Remove bracketed text at the end again (e.g. if a year or tag was left trailing after season/part/colon stripping)
    normalized = normalized.replaceAll(_bracketSuffixRegex, '');

    // Also clean up any trailing dashes, colons, or punctuation left over from the replacements
    normalized = normalized.replaceAll(_trailingPunctuationRegex, '');

    return normalized.trim();
  }

  static String parseSeasonName(String fullTitle, String baseName, {bool isMovie = false}) {
    final ft = fullTitle.trim();
    final bn = baseName.trim();
    
    // Extract year suffix (like (2024) or [2024]) from the full title to preserve and append it.
    final yearMatch = RegExp(r'[\[\(](\d{4})[\]\)]').firstMatch(ft);
    if (yearMatch != null) {
      final year = yearMatch.group(1)!;
      final cleanFullTitle = ft.replaceAll(RegExp(r'\s*[\[\(]\d{4}[\]\)]\s*'), ' ').trim();
      final cleanSeason = parseSeasonName(cleanFullTitle, bn, isMovie: isMovie);
      if (cleanSeason.contains(year)) {
        return cleanSeason;
      }
      return '$cleanSeason ($year)';
    }

    if (ft.toLowerCase() == bn.toLowerCase()) {
      return isMovie ? 'Movie' : 'Season 1';
    }
    
    if (ft.length <= bn.length) {
      return isMovie ? 'Movie' : 'Season 1';
    }

    var diff = ft.substring(bn.length).trim();
    // Remove leading dashes, colons, spaces, punctuation
    diff = diff.replaceAll(RegExp(r'^[-–—:|,\s]+'), '').trim();
    
    if (diff.isEmpty) {
      return isMovie ? 'Movie' : 'Season 1';
    }

    // Check if diff is Root A or √A
    if (RegExp(r'^(?:√\s*a|root\s*a|root\s*alpha)$', caseSensitive: false).hasMatch(diff)) {
      return '√A';
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


  @visibleForTesting
  StorageService? testStorage;

  Future<bool> _upsertMessageIncrementally(td.Message msg) async {
    if (msg.content is td.MessagePhoto) {
      final photo = msg.content as td.MessagePhoto;
      if (photo.caption.text.isEmpty) return false;
      
      final fullTitle = photo.caption.text.split('\n').first.trim();
      final isMovie = category.isMovie;
      final baseName = normalizeSeriesName(fullTitle, isMovie: isMovie);
      
      AnimeSeries? existingSeries;
      for (final s in _allSeries) {
        if (s.coreName == baseName) {
          existingSeries = s;
          break;
        }
      }
      
      final newSeason = AnimeSeason(
        fullTitle: fullTitle,
        seasonName: parseSeasonName(fullTitle, baseName, isMovie: isMovie),
        posterMessage: msg,
        episodes: [],
      );
      
      if (existingSeries != null) {
        final existingIndex = existingSeries.seasons.indexWhere((s) => s.posterMessage.id == msg.id);
        if (existingIndex == -1) {
          existingSeries.seasons.add(newSeason);
          return true;
        }
        return false;
      } else {
        _allSeries.insert(0, AnimeSeries(coreName: baseName, seasons: [newSeason]));
        return true;
      }
    } else if (msg.content is td.MessageVideo || msg.content is td.MessageDocument) {
      td.Message? selectedPoster;
      int maxPrecedingId = -1;
      
      for (final pMsg in _rawMessages) {
        if (pMsg.content is td.MessagePhoto && (pMsg.content as td.MessagePhoto).caption.text.isNotEmpty) {
          if (pMsg.id < msg.id && pMsg.id > maxPrecedingId) {
            maxPrecedingId = pMsg.id;
            selectedPoster = pMsg;
          }
        }
      }
      
      if (selectedPoster == null) return false;
      
      for (final s in _allSeries) {
        for (int i = 0; i < s.seasons.length; i++) {
          if (s.seasons[i].posterMessage.id == selectedPoster.id) {
            final exists = s.seasons[i].episodes.any((e) => e.id == msg.id);
            if (!exists) {
              s.seasons[i].episodes.add(msg);
              s.seasons[i].episodes.sort((a, b) {
                final epA = parseEpisodeNumber(a);
                final epB = parseEpisodeNumber(b);
                if (epA != epB) return epA.compareTo(epB);
                return a.id.compareTo(b.id);
              });
              return true;
            }
            return false;
          }
        }
      }
    }
    return false;
  }

  @visibleForTesting
  Future<List<AnimeSeries>> parseMessagesForTesting(List<td.Message> raw) async {
    return await parseMessagesWithYield(raw, category.isMovie);
  }

  @visibleForTesting
  Future<List<AnimeSeries>> applySearchAndSortForTesting(List<AnimeSeries> series) => _applySearchAndSort(series);

  Future<List<AnimeSeries>> _parseMessages(List<td.Message> raw) async {
    return await parseMessagesWithYield(raw, category.isMovie);
  }

  static String getMessageFileName(td.Message msg) {
    String fileName = '';
    String caption = '';

    if (msg.content is td.MessageVideo) {
      final video = msg.content as td.MessageVideo;
      fileName = video.video.fileName;
      caption = video.caption.text;
    } else if (msg.content is td.MessageDocument) {
      final doc = msg.content as td.MessageDocument;
      fileName = doc.document.fileName;
      caption = doc.caption.text;
    }

    if (caption.isNotEmpty) {
      final firstLine = caption.split('\n').first.trim();
      final lowerFirst = firstLine.toLowerCase();
      // If the first line of the caption is the full filename (ends with a known video extension)
      if (lowerFirst.endsWith('.mkv') || lowerFirst.endsWith('.mp4') || lowerFirst.endsWith('.avi') || lowerFirst.endsWith('.webm')) {
        return firstLine;
      }
      
      // Alternatively, if the original fileName was truncated by Telegram (usually at 60-64 chars) 
      // and the caption shares a prefix with it, the caption is likely the full name.
      if (fileName.length >= 50) {
        final baseName = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        final prefix = baseName.length > 20 ? baseName.substring(0, 20) : baseName;
        
        final cleanPrefix = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        final cleanFirstLine = firstLine.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        
        if (firstLine.length > fileName.length && cleanFirstLine.startsWith(cleanPrefix)) {
          return firstLine;
        }
      }
    }

    return fileName;
  }

  static int parseEpisodeNumber(td.Message ep) {
    String fileName = getMessageFileName(ep);
    
    final name = fileName.toLowerCase();
    
    // 1. Match patterns like e06, ep06, ep.06, ep - 06, episode 06, episode - 06, ep_06
    final epMatch = RegExp(
      r'\b(?:ep|episode|e|eps)\.?\s*[-–—_]*\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(name);
    if (epMatch != null) {
      return int.tryParse(epMatch.group(1)!) ?? 9999;
    }
    
    // 2. Match standalone numbers followed by common extensions or separators
    final standaloneMatch = RegExp(
      r'(?:[-–—_]\s*|^)(\d+)(?:\s*[-–—_]|\.mkv|\.mp4|\.avi|\.webm|\.mov|\.flv|\.wmv|\.3gp|\.m4v|\.ts)\b',
      caseSensitive: false,
    ).firstMatch(name);
    if (standaloneMatch != null) {
      return int.tryParse(standaloneMatch.group(1)!) ?? 9999;
    }
    
    // 3. Fallback: match any digits in the filename
    final fallbackMatch = RegExp(r'(\d+)').firstMatch(name);
    if (fallbackMatch != null) {
      return int.tryParse(fallbackMatch.group(1)!) ?? 9999;
    }
    
    return 9999;
  }
  
  Future<List<AnimeSeries>> _applySearchAndSort(List<AnimeSeries> list) async {
    final StorageService storage = testStorage ?? ref.read(storageServiceProvider);
    final favs = storage.getFavorites();
    final releaseYears = <String, int>{};
    
    for (final s in list) {
      for (final season in s.seasons) {
        releaseYears[season.fullTitle] = season.getReleaseYear(storage) ?? 0;
      }
    }
    
    final payload = _SearchPayload(
      list: list,
      currentQuery: _currentQuery,
      sortOrder: _sortOrder,
      favorites: favs.toSet(),
      showFavoritesOnly: _showFavoritesOnly,
      releaseYears: releaseYears,
    );
    
    if (list.length < 50) {
      return _computeSearchAndSortIsolate(payload);
    }
    return await compute(_computeSearchAndSortIsolate, payload);
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
          
          final cachedYear = storage.getSeasonReleaseYear(title);
          // Retries queries that returned 0 (failed/unset) in older versions. Skip valid years (>0) and permanent skips (-1).
          if (cachedYear != null && cachedYear != 0) {
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
      int updateCount = 0;

      for (final season in seasonsToFetch) {
        if (_isDisposed) return;
        // Cap PiP-wait at 5 minutes (100 * 3s); skip this season if still blocked.
        int waitTicks = 0;
        while (ref.read(pipControllerProvider) != null && !_isDisposed && waitTicks < 100) {
          await Future.delayed(const Duration(seconds: 3));
          waitTicks++;
        }
        if (_isDisposed) return;
        if (ref.read(pipControllerProvider) != null) {
          // PiP still active after 5min — skip this season, try the next.
          continue;
        }

        final title = season.fullTitle;
        final cleanTitle = normalizeSeriesName(title, isMovie: category.isMovie);
        int? fetchedYear;
        
        try {
          if (category.title == 'Anime') {
            fetchedYear = await _fetchAnimeReleaseYearFromMal(cleanTitle);
          } else {
            fetchedYear = await _fetchMediaReleaseYearFromTmdb(cleanTitle);
          }
        } catch (e, stack) {
          Log.e('Failed to fetch release year for: $cleanTitle (original: $title)', e, stack);
        }

        if (_isDisposed) return;

        if (fetchedYear != null) {
          await storage.setSeasonReleaseYear(title, fetchedYear);
          Log.i('Cached release year for "$title": $fetchedYear');
          
          updateCount++;
          if (updateCount % 4 == 0 || season == seasonsToFetch.last) {
            if (state.value != null && !_isDisposed) {
              if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
            }
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

  Future<int?> _fetchMediaReleaseYearFromTmdb(String title) async {
    try {
      final apiKey = Secrets.tmdbApiKey;
      if (apiKey.isNotEmpty && apiKey != 'YOUR_TMDB_API_KEY') {
        final query = Uri.encodeComponent(title);
        final isMovie = category.isMovie;
        final path = isMovie ? 'movie' : 'tv';
        final url = 'https://api.themoviedb.org/3/search/$path?api_key=$apiKey&query=$query&page=1';

        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List<dynamic>? results = data['results'];
          if (results != null && results.isNotEmpty) {
            final first = results[0];
            final dateStr = isMovie 
                ? first['release_date'] as String? 
                : first['first_air_date'] as String?;
                
            if (dateStr != null && dateStr.isNotEmpty) {
              final parts = dateStr.split('-');
              if (parts.isNotEmpty) {
                final year = int.tryParse(parts[0]);
                if (year != null && year > 0) {
                  Log.i('Successfully fetched release year from TMDB for $title: $year');
                  return year;
                }
              }
            }
          }
        } else {
          Log.w('TMDB API returned status code ${response.statusCode} for query "$title", falling back to Trakt');
        }
      } else {
        Log.w('TMDB API Key is placeholder, falling back to Trakt');
      }
    } catch (e) {
      Log.w('Error calling TMDB API for query "$title", falling back: $e');
    }

    // TVmaze Fallback for Web Series shows (No API key required)
    if (category.title == 'Web Series') {
      final tvmazeYear = await _fetchMediaReleaseYearFromTvmaze(title);
      if (tvmazeYear != null) return tvmazeYear;
    }

    // Secondary fallback to Trakt
    return _fetchMediaReleaseYearFromTraktFallback(title);
  }

  Future<int?> _fetchMediaReleaseYearFromTvmaze(String title) async {
    try {
      final query = Uri.encodeComponent(title);
      final url = 'https://api.tvmaze.com/singlesearch/shows?q=$query';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final premiered = data['premiered'] as String?;
        if (premiered != null && premiered.isNotEmpty) {
          final parts = premiered.split('-');
          if (parts.isNotEmpty) {
            final year = int.tryParse(parts[0]);
            if (year != null && year > 0) {
              Log.i('Successfully fetched release year from TVmaze for $title: $year');
              return year;
            }
          }
        }
        return -1; // Cache as -1 to indicate permanent skip (not found)
      } else if (response.statusCode == 404) {
        return -1; // Not found on TVmaze, permanent skip
      } else {
        Log.w('TVmaze returned status code ${response.statusCode} for query "$title"');
        return null; // Temporary HTTP error, retry later
      }
    } catch (e, stack) {
      Log.e('Error calling TVmaze API for query "$title"', e, stack);
      return null;
    }
  }

  Future<int?> _fetchMediaReleaseYearFromTraktFallback(String title) async {
    try {
      final query = Uri.encodeComponent(title);
      final type = category.isMovie ? 'movie' : 'show';
      final url = 'https://api.trakt.tv/search/$type?query=$query&limit=1';
      
      final headers = {
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': Secrets.traktApiKey,
      };

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final first = data[0];
          if (first['type'] != null && first[first['type']] != null) {
            final media = first[first['type']];
            final year = media['year'] as int?;
            if (year != null && year > 0) {
              Log.i('Successfully fetched release year from Trakt fallback for $title: $year');
              return year;
            }
          }
        }
        return -1; // No results found, cache -1 to permanently skip
      } else if (response.statusCode == 404) {
        return -1; // Not found, cache -1 to permanently skip
      } else {
        Log.w('Trakt Fallback API returned status code ${response.statusCode} for query "$title"');
        return null; // HTTP error, retry later
      }
    } catch (e, stack) {
      Log.e('Error calling Trakt Fallback API for query "$title"', e, stack);
      return null;
    }
  }
  bool _updateMessageIncrementally(td.Message editedMsg) {
    bool found = false;
    for (final s in _allSeries) {
      for (final season in s.seasons) {
        if (season.posterMessage.id == editedMsg.id) {
          season.posterMessage = editedMsg;
          found = true;
          break;
        }
        final epIndex = season.episodes.indexWhere((e) => e.id == editedMsg.id);
        if (epIndex != -1) {
          season.episodes[epIndex] = editedMsg;
          // Re-sort episodes in case the filename/caption changed
          season.episodes.sort((a, b) {
            final epA = parseEpisodeNumber(a);
            final epB = parseEpisodeNumber(b);
            if (epA != epB) return epA.compareTo(epB);
            return a.id.compareTo(b.id);
          });
          found = true;
          break;
        }
      }
      if (found) break;
    }
    return found;
  }

  void _fetchAndAndUpdateSingleMessage(int messageId, TdlibService tdlibService) async {
    try {
      final res = await tdlibService.sendAsync(td.GetMessage(
        chatId: category.channelId,
        messageId: messageId,
      ));
      if (res is td.Message) {
        final idx = _rawMessages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          _rawMessages[idx] = res;
          
          final changed = _updateMessageIncrementally(res);
          
          if (changed && state.value != null) {
            // Update UI state without a full heavy parse
            if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
          }
          if (_cacheLoadComplete) {
            _scheduleCatalogCacheWrite();
          }
          Log.i('Real-time updated edited message in catalog incrementally: $messageId');
        }
      }
    } catch (e) {
      Log.w('Failed to get updated message: $e');
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

/// Family provider for user-added channels. Each user channel gets 
/// its own HomeController instance with the correct channel ID.
final userChannelControllerProvider = AsyncNotifierProvider.family<UserChannelController, List<AnimeSeries>, ChannelCategory>(
  UserChannelController.new,
);

class UserChannelController extends HomeController {
  final ChannelCategory _category;
  
  UserChannelController(this._category);
  
  @override
  ChannelCategory get category => _category;
}

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
    } else if (RegExp(r'^(?:√\s*a|root\s*a|root\s*alpha)$', caseSensitive: false).hasMatch(lowerForSeason)) {
      sNum = 2; // Root A / √A is the second season of Tokyo Ghoul
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

class _SearchPayload {
  final List<AnimeSeries> list;
  final String currentQuery;
  final SortOrder sortOrder;
  final Set<String> favorites;
  final bool showFavoritesOnly;
  final Map<String, int> releaseYears;

  _SearchPayload({
    required this.list,
    required this.currentQuery,
    required this.sortOrder,
    required this.favorites,
    required this.showFavoritesOnly,
    required this.releaseYears,
  });
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

List<AnimeSeries> _computeSearchAndSortIsolate(_SearchPayload payload) {
  List<AnimeSeries> favoritesFiltered = payload.list;
  if (payload.showFavoritesOnly) {
    favoritesFiltered = payload.list.where((s) => payload.favorites.contains(s.coreName)).toList();
  }

  List<AnimeSeries> filtered = favoritesFiltered;
  if (payload.currentQuery.isNotEmpty) {
    final queryWords = payload.currentQuery.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    
    filtered = favoritesFiltered.where((series) {
      final seriesName = series.coreName.toLowerCase();
      final seasonNames = series.seasons.map((s) => s.fullTitle.toLowerCase()).join(' ');
      final releaseYears = series.seasons
          .map((s) => payload.releaseYears[s.fullTitle])
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

  switch (payload.sortOrder) {
    case SortOrder.aToZ:
      sorted.sort((a, b) => a.coreName.compareTo(b.coreName));
      break;
    case SortOrder.zToA:
      sorted.sort((a, b) => b.coreName.compareTo(a.coreName));
      break;
    case SortOrder.newest:
      sorted.sort((a, b) {
        final idA = a.seasons.isNotEmpty ? a.seasons.last.posterMessage.id : 0;
        final idB = b.seasons.isNotEmpty ? b.seasons.last.posterMessage.id : 0;
        return idB.compareTo(idA);
      });
      break;
    case SortOrder.oldest:
      sorted.sort((a, b) {
        final idA = a.seasons.isNotEmpty ? a.seasons.first.posterMessage.id : 0;
        final idB = b.seasons.isNotEmpty ? b.seasons.first.posterMessage.id : 0;
        return idA.compareTo(idB);
      });
      break;
  }

  for (var series in sorted) {
    final key = series.coreName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (key == 'naruto') {
      series.seasons.sort((a, b) {
        // Can't use storage in isolate, so use basic parsing
        final matchA = RegExp(r'season\s*(\d+)', caseSensitive: false).firstMatch(a.seasonName);
        final matchB = RegExp(r'season\s*(\d+)', caseSensitive: false).firstMatch(b.seasonName);
        final sA = matchA != null ? (int.tryParse(matchA.group(1)!) ?? 0) : 0;
        final sB = matchB != null ? (int.tryParse(matchB.group(1)!) ?? 0) : 0;
        int cmp = sA.compareTo(sB);
        if (cmp != 0) return cmp;
        return a.posterMessage.id.compareTo(b.posterMessage.id);
      });
    } else {
      series.seasons.sort((a, b) => a.posterMessage.id.compareTo(b.posterMessage.id));
    }
  }

  return sorted;
}



