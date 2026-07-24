import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../../core/utils/title_normalizer.dart';
import '../../services/series_parser.dart';
import '../../services/release_year_service.dart';
import '../../services/search_sort_engine.dart';


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




enum ConnectionStatus { connected, connecting, waitingForNetwork, unknown }
class ConnectionStateNotifier extends Notifier<ConnectionStatus> { @override ConnectionStatus build() => ConnectionStatus.unknown; }
final connectionStateProvider = NotifierProvider<ConnectionStateNotifier, ConnectionStatus>(ConnectionStateNotifier.new);
class IsSyncingNotifier extends Notifier<bool> { @override bool build() => false; }
final isSyncingProvider = NotifierProvider<IsSyncingNotifier, bool>(IsSyncingNotifier.new);

enum SortOrder { newest, oldest, aToZ, zToA }

abstract class HomeController extends AsyncNotifier<List<AnimeSeries>> {

  int _lastMessageId = 0;
  bool _hasMore = true;
  int? _emptyFetchCount;
  String _currentQuery = '';
  bool _isLoadingMore = false;
  SortOrder _sortOrder = SortOrder.newest;
  
  /// Maximum number of raw messages to retain per chat.
  /// Prevents unbounded memory growth for channels with thousands of videos.
  /// Older messages are trimmed when this cap is exceeded.
  static const int _maxMessagesPerChat = 2000;

  final List<td.Message> _rawMessages = [];
  final Set<int> _rawMessageIds = {};
  final _mutationLock = Lock();

  /// Trim oldest messages when the list exceeds the cap.
  /// This keeps memory bounded while preserving the most recent content.
  void _trimMessages() {
    if (_rawMessages.length <= _maxMessagesPerChat) return;
    final excess = _rawMessages.length - _maxMessagesPerChat;
    // Messages are sorted newest-first (b.id.compareTo(a.id))
    // so removing from the end removes the oldest.
    final removed = _rawMessages.sublist(_rawMessages.length - excess);
    for (final m in removed) {
      _rawMessageIds.remove(m.id);
    }
    _rawMessages.removeRange(_rawMessages.length - excess, _rawMessages.length);
    Log.i('Trimmed $excess oldest messages (cap: $_maxMessagesPerChat, remaining: ${_rawMessages.length})');
  }

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
              _trimMessages();
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
        // Note: UpdateDeleteMessages does NOT have a chatId field in TDLib.
        // We must check if any of the deleted message IDs exist in our local cache.
        if (!event.fromCache) {
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

  int _loadMoreRetries = 0;
  
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    if (_loadMoreRetries >= 3) {
      Log.w('loadMore: 3 consecutive retries with no new content, stopping.');
      return;
    }
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
      _trimMessages();
            _allSeries = await _parseMessages(_rawMessages);
            if (!_isDisposed) state = AsyncValue.data(await _applySearchAndSort(_allSeries));
            _triggerReleaseYearsSync();
          }
        });
      }
      if (changed && _cacheLoadComplete) {
        _scheduleCatalogCacheWrite();
      }
      if (!changed) {
        _loadMoreRetries++;
      } else {
        _loadMoreRetries = 0;
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
      _trimMessages();
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
      // OpenChat may fail if chat is already open â€” that's OK
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
    while (_hasMore && iterations < 200 && !_isDisposed && _rawMessages.length < _maxMessagesPerChat) {
      iterations++;
      final localMessages = await _fetchMessages(fromId: currentFromId, onlyLocal: true);
      if (localMessages.isEmpty) {
        // Local DB is empty (new channel) â€” try network fetch for initial data
        if (iterations == 1 && _rawMessages.isEmpty) {
          Log.i('Local DB empty for ${category.title}, fetching from network...');
          final networkMessages = await _fetchMessages(fromId: 0, onlyLocal: false);
          if (networkMessages.isNotEmpty) {
            for (final msg in networkMessages) {
              if (!_rawMessageIds.contains(msg.id)) {
                _rawMessages.add(msg);
                _rawMessageIds.add(msg.id);
              }
            }
            _trimMessages();
            if (_rawMessages.isNotEmpty) {
              currentFromId = _rawMessages.last.id;
            }
            await Future.delayed(const Duration(milliseconds: 10));
            continue;
          }
        }
        break;
      }
      for (final msg in localMessages) {
        if (!_rawMessageIds.contains(msg.id)) {
          _rawMessages.add(msg);
          _rawMessageIds.add(msg.id);
        }
      }
      _trimMessages();
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
      
      final content = await Isolate.run(() {
        final List<Map<String, dynamic>> jsonList = _allSeries.map((s) => s.toJson()).toList();
        return jsonEncode(jsonList);
      });
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
            // But don't retry forever â€” max 5 empty responses
            _emptyFetchCount = (_emptyFetchCount ?? 0) + 1;
            if ((_emptyFetchCount ?? 0) >= 5) {
              Log.w('Sync: 5 consecutive empty fetches, stopping sync for ${category.title}');
              _hasMore = false;
              break;
            }
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
          
          _emptyFetchCount = 0;
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
              final isNearEnd = !_hasMore;
              if (isNearEnd || now.difference(lastUiUpdateTime) > const Duration(milliseconds: 1500)) {
                _rawMessages.sort((a, b) => b.id.compareTo(a.id));
      _trimMessages();
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
      _trimMessages();
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




  @visibleForTesting
  StorageService? testStorage;

  Future<bool> _upsertMessageIncrementally(td.Message msg) async {
    if (msg.content is td.MessagePhoto) {
      final photo = msg.content as td.MessagePhoto;
      if (photo.caption.text.isEmpty) return false;
      
      final fullTitle = photo.caption.text.split('\n').first.trim();
      final isMovie = category.isMovie;
      final baseName = TitleNormalizer.normalizeSeriesName(fullTitle, isMovie: isMovie);
      
      AnimeSeries? existingSeries;
      for (final s in _allSeries) {
        if (s.coreName == baseName) {
          existingSeries = s;
          break;
        }
      }
      
      final newSeason = AnimeSeason(
        fullTitle: fullTitle,
        seasonName: TitleNormalizer.parseSeasonName(fullTitle, baseName, isMovie: isMovie),
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
                final epA = TitleNormalizer.parseEpisodeNumber(a);
                final epB = TitleNormalizer.parseEpisodeNumber(b);
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
    final isMovie = category.isMovie;
    return await Isolate.run(() => SeriesParser.parseMessagesBackground(raw, isMovie));
  }

  @visibleForTesting
  Future<List<AnimeSeries>> applySearchAndSortForTesting(List<AnimeSeries> series) => _applySearchAndSort(series);

  Future<List<AnimeSeries>> _parseMessages(List<td.Message> raw) async {
    final isMovie = category.isMovie;
    return await Isolate.run(() => SeriesParser.parseMessagesBackground(raw, isMovie));
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
    
    final payload = SearchPayload(
      list: list,
      currentQuery: _currentQuery,
      sortOrder: _sortOrder,
      favorites: favs.toSet(),
      showFavoritesOnly: _showFavoritesOnly,
      releaseYears: releaseYears,
    );
    
    if (list.length < 50) {
      return SearchSortEngine.computeSearchAndSort(payload);
    }
    return await compute(SearchSortEngine.computeSearchAndSort, payload);
  }



  void _triggerReleaseYearsSync() {
    _releaseYearsTimer?.cancel();
    _releaseYearsTimer = Timer(const Duration(seconds: 2), () {
      if (!_isFetchingReleaseYears) {
        _isFetchingReleaseYears = true;
        ReleaseYearService().fetchReleaseYearsInBackground(
          _allSeries,
          category,
          ref.read(storageServiceProvider),
          () {
            if (!_isDisposed && state.value != null) {
              _applySearchAndSort(_allSeries).then((sorted) {
                if (!_isDisposed) state = AsyncValue.data(sorted);
              });
            }
          },
          () => _isFetchingReleaseYears = false,
        );
      }
    });
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
            final epA = TitleNormalizer.parseEpisodeNumber(a);
            final epB = TitleNormalizer.parseEpisodeNumber(b);
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







