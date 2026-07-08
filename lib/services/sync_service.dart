import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../core/logger.dart';
import 'tdlib_service.dart';
import 'storage_service.dart';
import '../features/settings/settings_provider.dart';
import '../features/auth/auth_controller.dart';

class ProgressSyncNotifier extends Notifier<void> {
  late final TdlibService _tdlibService;
  Timer? _debounceTimer;

  @override
  void build() {
    _tdlibService = ref.watch(tdlibServiceProvider);
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _debounceTimer = null;
    });

    // Watch favoritesProvider and historyLogProvider for automatic background updates
    ref.listen(favoritesProvider, (prev, next) {
      _triggerDebouncedSync();
    });
    ref.listen(historyLogProvider, (prev, next) {
      _triggerDebouncedSync();
    });
  }

  void _triggerDebouncedSync() {
    final settings = ref.read(videoSettingsProvider);
    if (settings.progressSyncMode == 'disabled') return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 10), () {
      manualSync().catchError((e) {
        Log.e('Debounced cloud sync failed', e);
      });
    });
  }

  Map<String, dynamic> _mergeSyncData(Map<String, dynamic> localData, Map<String, dynamic> cloudData) {
    // Merge favorites
    final List<dynamic> localFavs = localData['favorites'] ?? [];
    final List<dynamic> cloudFavs = cloudData['favorites'] ?? [];
    final mergedFavs = {...localFavs, ...cloudFavs}.toList();
    localData['favorites'] = mergedFavs;

    // Merge history_log first so we can use it for history timestamp check
    final List<dynamic> localLog = localData['history_log'] ?? [];
    final List<dynamic> cloudLog = cloudData['history_log'] ?? [];
    final Map<String, Map<String, dynamic>> logMap = {};
    for (final item in [...localLog, ...cloudLog]) {
      final messageId = item['messageId'].toString();
      final existing = logMap[messageId];
      if (existing == null || (item['timestamp'] ?? 0) > (existing['timestamp'] ?? 0)) {
        logMap[messageId] = Map<String, dynamic>.from(item);
      }
    }
    final sortedLog = logMap.values.toList()
      ..sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    if (sortedLog.length > 200) {
      localData['history_log'] = sortedLog.sublist(0, 200);
    } else {
      localData['history_log'] = sortedLog;
    }

    // Merge history (messageId -> position) with timestamp awareness
    final Map<String, dynamic> localHist = localData['history'] ?? {};
    final Map<String, dynamic> cloudHist = cloudData['history'] ?? {};
    
    int getTimestamp(List<dynamic> logs, String msgId) {
      for (final log in logs) {
         if (log['messageId'].toString() == msgId) {
            return log['timestamp'] as int? ?? 0;
         }
      }
      return 0;
    }

    for (final entry in cloudHist.entries) {
      final msgId = entry.key;
      final cloudPos = entry.value ?? 0;
      final localPos = localHist[msgId] ?? 0;

      if (cloudPos != localPos) {
         final cloudTs = getTimestamp(cloudLog, msgId);
         final localTs = getTimestamp(localLog, msgId);
         if (cloudTs > localTs) {
            localHist[msgId] = cloudPos;
         } else if (localTs == 0 && cloudTs == 0) {
            // fallback
            if (cloudPos > localPos) {
               localHist[msgId] = cloudPos;
            }
         }
      }
    }
    localData['history'] = localHist;

    // Merge durations
    final Map<String, dynamic> localDur = localData['durations'] ?? {};
    final Map<String, dynamic> cloudDur = cloudData['durations'] ?? {};
    for (final entry in cloudDur.entries) {
      localDur[entry.key] = entry.value;
    }
    localData['durations'] = localDur;

    // Merge last_watched
    final Map<String, dynamic>? cloudLast = cloudData['last_watched'];
    if (cloudLast != null) {
      localData['last_watched'] = cloudLast;
    }

    // Merge settings (keep cloud settings)
    if (cloudData.containsKey('video_settings')) {
      localData['video_settings'] = cloudData['video_settings'];
    }

    return localData;
  }

  Future<void> manualSync() async {
    final authState = ref.read(authControllerProvider);
    if (authState.step != AuthStep.authenticated) {
      throw Exception("User is not authenticated with Telegram.");
    }

    Log.i('Starting manual cloud progress synchronization...');
    final cloudData = await _fetchCloudData();
    final storage = ref.read(storageServiceProvider);
    final localDataJson = storage.exportBackupData();
    final Map<String, dynamic> localData = json.decode(localDataJson);

    if (cloudData != null) {
      Log.i('Cloud sync data found. Merging cloud data into local storage...');
      final mergedData = _mergeSyncData(localData, cloudData);
      await storage.importBackupData(mergedData);

      // Invalidate providers
      ref.invalidate(videoSettingsProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(historyLogProvider);
      ref.invalidate(lastWatchedProvider);
      Log.i('Cloud and local data merged successfully.');
    }

    // Now upload local state to cloud
    final finalLocalData = json.decode(storage.exportBackupData());
    await syncData(finalLocalData);
    Log.i('Cloud progress sync completed successfully.');
  }

  Future<void> syncData(Map<String, dynamic> data) async {
    final settings = ref.read(videoSettingsProvider);
    final mode = settings.progressSyncMode;
    if (mode == 'disabled') return;

    final me = await _tdlibService.sendAsync(const td.GetMe());
    if (me is! td.User) throw Exception("Failed to get Telegram user details.");
    final userId = me.id;

    final chatRes = await _tdlibService.sendAsync(td.CreatePrivateChat(userId: userId, force: false));
    if (chatRes is! td.Chat) throw Exception("Failed to access Saved Messages chat.");
    final chatId = chatRes.id;

    // Prune unnecessary bulky/ephemeral cache mappings from backup payload to avoid Telegram message size limits
    final Map<String, dynamic> syncPayload = Map<String, dynamic>.from(data);
    syncPayload.remove('downloaded_files');
    syncPayload.remove('active_downloads');
    syncPayload.remove('active_downloads_order');
    syncPayload.remove('series_files');

    final jsonPayload = json.encode(syncPayload);

    final chunks = <String>[];
    for (var i = 0; i < jsonPayload.length; i += 4000) {
      chunks.add(jsonPayload.substring(i, i + 4000 > jsonPayload.length ? jsonPayload.length : i + 4000));
    }

    if (mode == 'pinned') {
      // Find all existing sync messages
      final existingMsgIds = <int>[];
      try {
        final historyRes = await _tdlibService.sendAsync(td.GetChatHistory(
          chatId: chatId,
          fromMessageId: 0,
          offset: 0,
          limit: 100,
          onlyLocal: false,
        ));
        if (historyRes is td.Messages) {
          for (final msg in historyRes.messages) {
            if (msg.content is td.MessageText) {
              final text = (msg.content as td.MessageText).text.text;
              if (text.startsWith('[TelStream Sync Data')) {
                existingMsgIds.add(msg.id);
              }
            }
          }
        }
      } catch (_) {}

      if (existingMsgIds.isNotEmpty) {
        await _tdlibService.sendAsync(td.DeleteMessages(
          chatId: chatId,
          messageIds: existingMsgIds,
          revoke: true,
        ));
      }

      for (var i = 0; i < chunks.length; i++) {
        final contentText = chunks.length == 1 
          ? '[TelStream Sync Data]\n${chunks[i]}' 
          : '[TelStream Sync Data Part ${i+1}/${chunks.length}]\n${chunks[i]}';
          
        final sendRes = await _tdlibService.sendAsync(td.SendMessage(
          chatId: chatId,
          messageThreadId: 0,
          replyTo: null,
          options: const td.MessageSendOptions(
            sendingId: 0,
            disableNotification: true,
            fromBackground: true,
            protectContent: false,
            updateOrderOfInstalledStickerSets: false,
            schedulingState: null,
          ),
          replyMarkup: null,
          inputMessageContent: td.InputMessageText(
            text: td.FormattedText(text: contentText, entities: const []),
            disableWebPagePreview: true,
            clearDraft: true,
          ),
        ));

        if (i == 0 && sendRes is td.Message) {
          await _tdlibService.sendAsync(td.PinChatMessage(
            chatId: chatId,
            messageId: sendRes.id,
            disableNotification: true,
            onlyForSelf: true,
          ));
        }
      }
      Log.i('Sent and pinned chunked sync messages in Saved Messages.');
    } else if (mode == 'sequential') {
      // Trim history: keep only the latest 50 TelStream messages
      try {
        final historyRes = await _tdlibService.sendAsync(td.GetChatHistory(
          chatId: chatId, fromMessageId: 0, offset: 0, limit: 100, onlyLocal: false,
        ));
        if (historyRes is td.Messages) {
          final oldMsgIds = <int>[];
          int kept = 0;
          for (final msg in historyRes.messages) {
            if (msg.content is td.MessageText) {
              final text = (msg.content as td.MessageText).text.text;
              if (text.startsWith('[TelStream Progress Log')) {
                kept++;
                if (kept > 50) oldMsgIds.add(msg.id);
              }
            }
          }
          if (oldMsgIds.isNotEmpty) {
            await _tdlibService.sendAsync(td.DeleteMessages(
              chatId: chatId, messageIds: oldMsgIds, revoke: true,
            ));
          }
        }
      } catch (_) {}

      for (var i = 0; i < chunks.length; i++) {
        final contentText = chunks.length == 1 
          ? '[TelStream Progress Log]\n${chunks[i]}' 
          : '[TelStream Progress Log Part ${i+1}/${chunks.length}]\n${chunks[i]}';
          
        await _tdlibService.sendAsync(td.SendMessage(
          chatId: chatId,
          messageThreadId: 0,
          replyTo: null,
          options: const td.MessageSendOptions(
            sendingId: 0,
            disableNotification: true,
            fromBackground: true,
            protectContent: false,
            updateOrderOfInstalledStickerSets: false,
            schedulingState: null,
          ),
          replyMarkup: null,
          inputMessageContent: td.InputMessageText(
            text: td.FormattedText(text: contentText, entities: const []),
            disableWebPagePreview: true,
            clearDraft: true,
          ),
        ));
      }
      Log.i('Appended sequential progress log messages in Saved Messages.');
    }
  }

  Future<void> restoreFromCloud() async {
    Log.i('Restoring progress from Telegram cloud sync...');
    final cloudData = await _fetchCloudData();
    if (cloudData == null) {
      Log.i('No cloud sync data found.');
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final localDataJson = storage.exportBackupData();
    final Map<String, dynamic> localData = json.decode(localDataJson);

    final mergedData = _mergeSyncData(localData, cloudData);
    await storage.importBackupData(mergedData);

    // Invalidate providers
    ref.invalidate(videoSettingsProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(historyLogProvider);
    ref.invalidate(lastWatchedProvider);
    Log.i('Progress restored successfully from cloud.');
  }

  Future<Map<String, dynamic>?> _fetchCloudData() async {
    final me = await _tdlibService.sendAsync(const td.GetMe());
    if (me is! td.User) return null;
    final userId = me.id;

    final chatRes = await _tdlibService.sendAsync(td.CreatePrivateChat(userId: userId, force: false));
    if (chatRes is! td.Chat) return null;
    final chatId = chatRes.id;

    final settings = ref.read(videoSettingsProvider);
    final mode = settings.progressSyncMode;

      if (mode == 'pinned') {
        try {
          final historyRes = await _tdlibService.sendAsync(td.GetChatHistory(
            chatId: chatId,
            fromMessageId: 0,
            offset: 0,
            limit: 100,
            onlyLocal: false,
          ));
          
          if (historyRes is td.Messages) {
            final Map<int, String> chunksMap = {};
            for (final msg in historyRes.messages) {
              if (msg.content is td.MessageText) {
                final text = (msg.content as td.MessageText).text.text;
                if (text.startsWith('[TelStream Sync Data Part ')) {
                   final match = RegExp(r'\[TelStream Sync Data Part (\d+)/(\d+)\]\n(.*)', dotAll: true).firstMatch(text);
                   if (match != null) {
                      final partIdx = int.parse(match.group(1)!);
                      chunksMap[partIdx] = match.group(3)!;
                   }
                } else if (text.startsWith('[TelStream Sync Data]\n')) {
                   final jsonString = text.substring('[TelStream Sync Data]\n'.length);
                   return json.decode(jsonString);
                }
              }
            }
            if (chunksMap.isNotEmpty) {
               final sortedKeys = chunksMap.keys.toList()..sort();
               String fullJson = '';
               for (final k in sortedKeys) {
                  fullJson += chunksMap[k]!;
               }
               return json.decode(fullJson);
            }
          }
        } catch (_) {}
      } else if (mode == 'sequential') {
        final historyRes = await _tdlibService.sendAsync(td.GetChatHistory(
          chatId: chatId,
          fromMessageId: 0,
          offset: 0,
          limit: 100,
          onlyLocal: false,
        ));
        if (historyRes is td.Messages) {
          final Map<int, String> chunksMap = {};
          int? totalParts;
          for (final msg in historyRes.messages) {
            if (msg.content is td.MessageText) {
              final text = (msg.content as td.MessageText).text.text;
              if (text.startsWith('[TelStream Progress Log Part ')) {
                final match = RegExp(r'\[TelStream Progress Log Part (\d+)/(\d+)\]\n(.*)', dotAll: true).firstMatch(text);
                if (match != null) {
                  final partIdx = int.parse(match.group(1)!);
                  totalParts ??= int.parse(match.group(2)!);
                  chunksMap[partIdx] = match.group(3)!;
                  if (chunksMap.length == totalParts) {
                    final sortedKeys = chunksMap.keys.toList()..sort();
                    String fullJson = '';
                    for (final k in sortedKeys) {
                      fullJson += chunksMap[k]!;
                    }
                    return json.decode(fullJson);
                  }
                }
              } else if (text.startsWith('[TelStream Progress Log]')) {
                final jsonStr = text.replaceFirst('[TelStream Progress Log]\n', '').trim();
                return json.decode(jsonStr) as Map<String, dynamic>;
              }
            }
          }
        }
      }

    return null;
  }
}

final progressSyncServiceProvider = NotifierProvider<ProgressSyncNotifier, void>(ProgressSyncNotifier.new);
