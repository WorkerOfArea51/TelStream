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
      // Merge favorites
      final List<dynamic> localFavs = localData['favorites'] ?? [];
      final List<dynamic> cloudFavs = cloudData['favorites'] ?? [];
      final mergedFavs = {...localFavs, ...cloudFavs}.toList();
      localData['favorites'] = mergedFavs;

      // Merge history (messageId -> position)
      final Map<String, dynamic> localHist = localData['history'] ?? {};
      final Map<String, dynamic> cloudHist = cloudData['history'] ?? {};
      for (final entry in cloudHist.entries) {
        final localPos = localHist[entry.key] ?? 0;
        final cloudPos = entry.value ?? 0;
        if (cloudPos > localPos) {
          localHist[entry.key] = cloudPos;
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

      // Merge history_log
      final List<dynamic> localLog = localData['history_log'] ?? [];
      final List<dynamic> cloudLog = cloudData['history_log'] ?? [];
      final Map<String, Map<String, dynamic>> logMap = {};
      for (final item in [...localLog, ...cloudLog]) {
        final messageId = item['messageId'];
        final key = '$messageId';
        final existing = logMap[key];
        if (existing == null || (item['timestamp'] ?? 0) > (existing['timestamp'] ?? 0)) {
          logMap[key] = Map<String, dynamic>.from(item);
        }
      }
      final sortedLog = logMap.values.toList()
        ..sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      if (sortedLog.length > 200) {
        localData['history_log'] = sortedLog.sublist(0, 200);
      } else {
        localData['history_log'] = sortedLog;
      }

      // Merge settings (keep cloud settings)
      if (cloudData.containsKey('video_settings')) {
        localData['video_settings'] = cloudData['video_settings'];
      }

      await storage.importBackupData(localData);

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

    if (mode == 'pinned') {
      td.Message? existingMsg;
      try {
        final res = await _tdlibService.sendAsync(td.GetChatPinnedMessage(chatId: chatId));
        if (res is td.Message && res.content is td.MessageText) {
          final text = (res.content as td.MessageText).text.text;
          if (text.startsWith('[TelStream Sync Data]')) {
            existingMsg = res;
          }
        }
      } catch (_) {}

      if (existingMsg == null) {
        try {
          final historyRes = await _tdlibService.sendAsync(td.GetChatHistory(
            chatId: chatId,
            fromMessageId: 0,
            offset: 0,
            limit: 50,
            onlyLocal: false,
          ));
          if (historyRes is td.Messages) {
            for (final msg in historyRes.messages) {
              if (msg.content is td.MessageText) {
                final text = (msg.content as td.MessageText).text.text;
                if (text.startsWith('[TelStream Sync Data]')) {
                  existingMsg = msg;
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }

      final contentText = '[TelStream Sync Data]\n$jsonPayload';

      if (existingMsg != null) {
        await _tdlibService.sendAsync(td.EditMessageText(
          chatId: chatId,
          messageId: existingMsg.id,
          inputMessageContent: td.InputMessageText(
            text: td.FormattedText(text: contentText, entities: const []),
            disableWebPagePreview: true,
            clearDraft: true,
          ),
        ));
        Log.i('Updated existing pinned sync message in Saved Messages.');
      } else {
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

        if (sendRes is td.Message) {
          await _tdlibService.sendAsync(td.PinChatMessage(
            chatId: chatId,
            messageId: sendRes.id,
            disableNotification: true,
            onlyForSelf: true,
          ));
          Log.i('Sent and pinned new sync message in Saved Messages.');
        }
      }
    } else if (mode == 'sequential') {
      final contentText = '[TelStream Progress Log]\n$jsonPayload';
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
      Log.i('Appended sequential progress log message in Saved Messages.');
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

    // Merge favorites
    final List<dynamic> localFavs = localData['favorites'] ?? [];
    final List<dynamic> cloudFavs = cloudData['favorites'] ?? [];
    final mergedFavs = {...localFavs, ...cloudFavs}.toList();
    localData['favorites'] = mergedFavs;

    // Merge history (messageId -> position)
    final Map<String, dynamic> localHist = localData['history'] ?? {};
    final Map<String, dynamic> cloudHist = cloudData['history'] ?? {};
    for (final entry in cloudHist.entries) {
      final localPos = localHist[entry.key] ?? 0;
      final cloudPos = entry.value ?? 0;
      if (cloudPos > localPos) {
        localHist[entry.key] = cloudPos;
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

    // Merge history_log
    final List<dynamic> localLog = localData['history_log'] ?? [];
    final List<dynamic> cloudLog = cloudData['history_log'] ?? [];
    final Map<String, Map<String, dynamic>> logMap = {};
    for (final item in [...localLog, ...cloudLog]) {
      final messageId = item['messageId'];
      final key = '$messageId';
      final existing = logMap[key];
      if (existing == null || (item['timestamp'] ?? 0) > (existing['timestamp'] ?? 0)) {
        logMap[key] = Map<String, dynamic>.from(item);
      }
    }
    final sortedLog = logMap.values.toList()
      ..sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    if (sortedLog.length > 200) {
      localData['history_log'] = sortedLog.sublist(0, 200);
    } else {
      localData['history_log'] = sortedLog;
    }

    // Overwrite settings with cloud settings if present
    if (cloudData.containsKey('video_settings')) {
      localData['video_settings'] = cloudData['video_settings'];
    }

    await storage.importBackupData(localData);

    // Invalidate providers
    ref.invalidate(videoSettingsProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(historyLogProvider);
    ref.invalidate(lastWatchedProvider);
    Log.i('Progress restored successfully from cloud.');
  }

  Future<Map<String, dynamic>?> _fetchCloudData() async {
    try {
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
          final res = await _tdlibService.sendAsync(td.GetChatPinnedMessage(chatId: chatId));
          if (res is td.Message && res.content is td.MessageText) {
            final text = (res.content as td.MessageText).text.text;
            if (text.startsWith('[TelStream Sync Data]')) {
              final jsonStr = text.replaceFirst('[TelStream Sync Data]\n', '').trim();
              return json.decode(jsonStr) as Map<String, dynamic>;
            }
          }
        } catch (_) {}

        final historyRes = await _tdlibService.sendAsync(td.GetChatHistory(
          chatId: chatId,
          fromMessageId: 0,
          offset: 0,
          limit: 50,
          onlyLocal: false,
        ));
        if (historyRes is td.Messages) {
          for (final msg in historyRes.messages) {
            if (msg.content is td.MessageText) {
              final text = (msg.content as td.MessageText).text.text;
              if (text.startsWith('[TelStream Sync Data]')) {
                final jsonStr = text.replaceFirst('[TelStream Sync Data]\n', '').trim();
                return json.decode(jsonStr) as Map<String, dynamic>;
              }
            }
          }
        }
      } else if (mode == 'sequential') {
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
              if (text.startsWith('[TelStream Progress Log]')) {
                final jsonStr = text.replaceFirst('[TelStream Progress Log]\n', '').trim();
                return json.decode(jsonStr) as Map<String, dynamic>;
              }
            }
          }
        }
      }
    } catch (e, stack) {
      Log.e('Failed to fetch cloud sync data', e, stack);
    }
    return null;
  }
}

final progressSyncServiceProvider = NotifierProvider<ProgressSyncNotifier, void>(ProgressSyncNotifier.new);
