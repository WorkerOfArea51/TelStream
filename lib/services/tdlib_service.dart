import 'dart:async';
import 'dart:io';
import 'dart:ffi';
import 'dart:convert';
import 'dart:math';
import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tdlib/td_client.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:path_provider/path_provider.dart';
import '../core/logger.dart';
import '../core/utils/path_helper.dart';

final tdlibServiceProvider = Provider<TdlibService>((ref) {
  final service = TdlibService();
  ref.onDispose(() => service.destroy());
  return service;
});

class TdlibService {
  int? _clientId;
  bool _isDestroyed = false;
  
  late final DynamicLibrary _lib;
  late final Pointer<Utf8> Function(double timeout) _nativeReceive;
  bool _libInitialized = false;
  
  final _updatesController = StreamController<td.TdObject>.broadcast();
  Stream<td.TdObject> get updates => _updatesController.stream;

  Future<void> _closePreviousClient() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/last_client_id.txt');
      if (await file.exists()) {
        final content = await file.readAsString();
        final lastId = int.tryParse(content.trim());
        if (lastId != null && lastId > 0) {
          try {
            tdSend(lastId, const td.Close());
          } catch (_) {}
          // Give the previous client a short moment to close databases and release locks
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCurrentClient(int id) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/last_client_id.txt');
      await file.writeAsString(id.toString());
    } catch (_) {}
  }

  Future<String> _loadOrCreateDbEncryptionKey() async {
    const storage = FlutterSecureStorage();
    String? key = await storage.read(key: 'tdlib_db_key');
    if (key == null || key.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64Encode(values);
      await storage.write(key: 'tdlib_db_key', value: key);
    } else if (key.contains('-') || key.contains('_')) {
      key = key.replaceAll('-', '+').replaceAll('_', '/');
      await storage.write(key: 'tdlib_db_key', value: key);
    }
    return key;
  }

  Future<void> init(
    int apiId,
    String apiHash, {
    List<String>? excludedPaths,
    double? limitMb,
    int? ttlDays,
  }) async {
    if (_clientId != null) {
      try {
        tdSend(_clientId!, const td.Close());
      } catch (_) {}
      _clientId = null;
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      // Close previous client ID from last session/hot restart to release database lock
      await _closePreviousClient();
    }

    _clientId = tdCreate();
    if (_clientId != null && _clientId! > 0) {
      await _saveCurrentClient(_clientId!);
    }
    
    final appDocDir = await getAppDirectory();
    final safePath = appDocDir.path.replaceAll('\\', '/');
    final logPath = '$safePath/tdlib.log';

    send(td.SetLogStream(
      logStream: td.LogStreamFile(
        path: logPath,
        maxFileSize: 10 * 1024 * 1024,
        redirectStderr: true,
      ),
    ));
    send(const td.SetLogVerbosityLevel(newVerbosityLevel: 2));
    _initNativeLibrary();
    _startEventLoop();

    final dbKey = await _loadOrCreateDbEncryptionKey();
    
    const storage = FlutterSecureStorage();
    final isMigrated = await storage.read(key: 'tdlib_db_migrated');
    bool needsMigration = isMigrated != 'true';
    
    String deviceModel = 'Unknown';
    if (Platform.isAndroid) deviceModel = 'Android';
    else if (Platform.isIOS) deviceModel = 'iOS';
    else if (Platform.isMacOS) deviceModel = 'macOS';
    else if (Platform.isWindows) deviceModel = 'Windows';
    else if (Platform.isLinux) deviceModel = 'Linux';

    final params = td.SetTdlibParameters(
      useTestDc: false,
      databaseDirectory: safePath,
      filesDirectory: safePath,
      useFileDatabase: true,
      useChatInfoDatabase: true,
      useMessageDatabase: true,
      useSecretChats: false,
      apiId: apiId,
      apiHash: apiHash,
      systemLanguageCode: 'en',
      deviceModel: deviceModel,
      systemVersion: Platform.operatingSystemVersion.replaceAll(RegExp(r'[^\x20-\x7E]'), ''),
      applicationVersion: '1.0',
      enableStorageOptimizer: true,
      ignoreFileNames: false,
      databaseEncryptionKey: needsMigration ? '' : dbKey, 
    );
    send(params);

    if (needsMigration) {
      send(td.SetDatabaseEncryptionKey(newEncryptionKey: dbKey));
      await storage.write(key: 'tdlib_db_migrated', value: 'true');
    }

    // Give TDLib a moment to initialize its DB, then prune cached video files
    Future.delayed(const Duration(seconds: 5), () {
      pruneCache(
        excludedPaths: excludedPaths ?? [],
        limitMb: limitMb,
        ttlDays: ttlDays,
      );
    });
  }

  Future<void> pruneCache({
    required List<String> excludedPaths,
    double? limitMb,
    int? ttlDays,
  }) async {
    try {
      final appDocDir = await getAppDirectory();
      final targetDirs = [
        'videos',
        'documents',
        'temp',
        'voice',
        'music',
        'video_notes',
        'stickers',
        'animations',
        'photos'
      ];
      
      final List<File> cacheFiles = [];
      final List<td.FileType> optimizeTypes = [
        const td.FileTypeVideo(),
        const td.FileTypeDocument(),
        const td.FileTypeAnimation(),
        const td.FileTypeAudio(),
        const td.FileTypeVoiceNote(),
      ];

      // 1. Run TDLib's OptimizeStorage first
      try {
        await sendAsync(td.OptimizeStorage(
          size: limitMb != null ? (limitMb * 1024 * 1024).round() : 0,
          ttl: ttlDays != null ? ttlDays * 24 * 3600 : 0,
          count: 0,
          immunityDelay: 0,
          fileTypes: optimizeTypes,
          chatIds: [],
          excludeChatIds: [],
          returnDeletedFileStatistics: false,
          chatLimit: 0,
        ));
      } catch (e, stackTrace) {
        Log.e('TDLib OptimizeStorage failed', e, stackTrace);
      }

      // 2. Scan and prune local files manually based on TTL and Size Limit
      final now = DateTime.now();
      final double limitBytes = (limitMb ?? 2048.0) * 1024 * 1024;
      
      for (final dirName in targetDirs) {
        final dir = Directory('${appDocDir.path}/$dirName');
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              final path = entity.path.toLowerCase();
              final isDatabase = path.endsWith('.db') || 
                                 path.endsWith('.db-journal') || 
                                 path.endsWith('.db-wal') || 
                                 path.endsWith('.db-shm') || 
                                 path.endsWith('.bin') ||
                                 path.endsWith('.binlog') ||
                                 path.endsWith('.key');
                                 
              if (!isDatabase) {
                final bool isExcluded = excludedPaths.any((ex) => ex.toLowerCase() == path);
                if (!isExcluded) {
                  cacheFiles.add(entity);
                }
              }
            }
          }
        }
      }

      // TTL Check: Delete files older than ttlDays
      if (ttlDays != null && ttlDays > 0) {
        final threshold = now.subtract(Duration(days: ttlDays));
        final List<File> toRemove = [];
        for (final file in cacheFiles) {
          try {
            final lastModified = await file.lastModified();
            if (lastModified.isBefore(threshold)) {
              final size = await file.length();
              await file.delete();
              Log.i('TTL CACHE PRUNED: ${file.path} ($size bytes, age: ${now.difference(lastModified).inDays} days)');
              toRemove.add(file);
            }
          } catch (_) {}
        }
        cacheFiles.removeWhere((f) => toRemove.contains(f));
      }

      // Limit Check: Sort remaining files by lastModified ascending and prune oldest if size exceeds limit
      double totalSize = 0;
      final List<MapEntry<File, DateTime>> fileStats = [];
      for (final file in cacheFiles) {
        try {
          final size = await file.length();
          final mTime = await file.lastModified();
          totalSize += size;
          fileStats.add(MapEntry(file, mTime));
        } catch (_) {}
      }

      if (limitMb != null && limitMb > 0 && totalSize > limitBytes) {
        fileStats.sort((a, b) => a.value.compareTo(b.value));
        
        double currentSize = totalSize;
        for (final entry in fileStats) {
          if (currentSize <= limitBytes) break;
          try {
            final size = await entry.key.length();
            await entry.key.delete();
            currentSize -= size;
            Log.i('SIZE LIMIT CACHE PRUNED: ${entry.key.path} ($size bytes)');
          } catch (_) {}
        }
      }

    } catch (e, stackTrace) {
      Log.e('CACHE PRUNE ERROR', e, stackTrace);
    }
  }

  Future<void> clearVideoCache({bool includePhotos = false, List<String>? excludedPaths}) async {
    try {
      final List<td.FileType> fileTypes = [
        const td.FileTypeVideo(),
        const td.FileTypeDocument(),
        const td.FileTypeAnimation(),
        const td.FileTypeAudio(),
        const td.FileTypeVoiceNote(),
      ];
      if (includePhotos) {
        fileTypes.add(const td.FileTypePhoto());
        fileTypes.add(const td.FileTypeThumbnail());
      }

      await sendAsync(td.OptimizeStorage(
        size: 0,
        ttl: 0,
        count: 0,
        immunityDelay: 0,
        fileTypes: fileTypes,
        chatIds: [],
        excludeChatIds: [],
        returnDeletedFileStatistics: false,
        chatLimit: 0,
      ));
    } catch (_) {}

    try {
      final appDocDir = await getAppDirectory();
      final targetDirs = [
        'videos',
        'documents',
        'temp',
        'voice',
        'music',
        'video_notes',
        'stickers',
        'animations',
      ];
      if (includePhotos) {
        targetDirs.add('photos');
      }
      
      for (final dirName in targetDirs) {
        final dir = Directory('${appDocDir.path}/$dirName');
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              final path = entity.path.toLowerCase();
              final isDatabase = path.endsWith('.db') || 
                                 path.endsWith('.db-journal') || 
                                 path.endsWith('.db-wal') || 
                                 path.endsWith('.db-shm') || 
                                 path.endsWith('.bin') ||
                                 path.endsWith('.binlog') ||
                                 path.endsWith('.key');
                                 
              if (!isDatabase) {
                try {
                  final bool isExcluded = excludedPaths?.any((ex) => ex.toLowerCase() == path) ?? false;
                  if (!isExcluded) {
                    final size = await entity.length();
                    await entity.delete();
                    Log.i('CACHE DELETED: $path ($size bytes)');
                  }
                } catch (e, stackTrace) {
                  Log.e('CACHE DELETE FAILED: $path', e, stackTrace);
                }
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      Log.e('CACHE SCAN ERROR', e, stackTrace);
    }
  }

  Future<void> compactDatabase() async {
    try {
      Log.i('TDLib compactDatabase initiated.');
      // Optimize storage to trigger general database defragmentation and vacuum SQLite pages
      await sendAsync(const td.OptimizeStorage(
        size: 0,
        ttl: 0,
        count: 0,
        immunityDelay: 0,
        fileTypes: [],
        chatIds: [],
        excludeChatIds: [],
        returnDeletedFileStatistics: false,
        chatLimit: 0,
      ));
      Log.i('TDLib compactDatabase completed successfully.');
    } catch (e, stack) {
      Log.e('TDLib Database compaction failed', e, stack);
    }
  }

  final Map<int, Completer<td.TdObject>> _pendingRequests = {};
  int _requestId = 0;

  void _initNativeLibrary() {
    if (_libInitialized) return;
    try {
      final libName = Platform.isWindows ? 'tdjson.dll' : (Platform.isAndroid ? 'libtdjson.so' : 'libtdjson.so');
      _lib = DynamicLibrary.open(libName);
      final receivePtr = _lib.lookup<NativeFunction<Pointer<Utf8> Function(Double)>>('td_receive');
      _nativeReceive = receivePtr.asFunction<Pointer<Utf8> Function(double)>();
      _libInitialized = true;
      Log.i('TDLib direct FFI receive library loaded successfully.');
    } catch (e, stack) {
      Log.e('Failed to load native library for custom FFI receive', e, stack);
    }
  }

  static Map<String, dynamic> sanitizeJson(Map<String, dynamic> json) {
    // 1. Recursively sanitize all children first
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        json[key] = sanitizeJson(value);
      } else if (value is List) {
        json[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return sanitizeJson(item);
          }
          return item;
        }).toList();
      }
    });

    // 2. Perform target type-sanitization based on @type to prevent Dart null-safety TypeErrors
    final type = json['@type'];
    if (type == null) return json;

    switch (type) {
      case 'user':
        json['is_contact'] ??= false;
        json['is_mutual_contact'] ??= false;
        json['is_close_friend'] ??= false;
        json['is_verified'] ??= false;
        json['is_premium'] ??= false;
        json['is_support'] ??= false;
        json['is_scam'] ??= false;
        json['is_fake'] ??= false;
        json['has_active_stories'] ??= false;
        json['has_unread_active_stories'] ??= false;
        json['have_access'] ??= false;
        json['added_to_attachment_menu'] ??= false;
        json['restriction_reason'] ??= '';
        json['language_code'] ??= '';
        json['first_name'] ??= '';
        json['last_name'] ??= '';
        json['phone_number'] ??= '';
        json['status'] ??= {'@type': 'userStatusEmpty'};
        json['type'] ??= {'@type': 'userTypeRegular'};
        break;
      case 'chatPermissions':
        json['can_send_messages'] ??= false;
        json['can_send_media_messages'] ??= false;
        json['can_send_polls'] ??= false;
        json['can_send_other_messages'] ??= false;
        json['can_add_web_page_previews'] ??= false;
        json['can_change_info'] ??= false;
        json['can_invite_users'] ??= false;
        json['can_pin_messages'] ??= false;
        json['can_manage_topics'] ??= false;
        break;
      case 'targetChatChosen':
        json['allow_user_chats'] ??= false;
        json['allow_bot_chats'] ??= false;
        json['allow_group_chats'] ??= false;
        json['allow_channel_chats'] ??= false;
        break;
      case 'attachmentMenuBot':
        json['supports_self_audios'] ??= false;
        json['supports_self_videos'] ??= false;
        json['supports_self_documents'] ??= false;
        json['supports_self_animations'] ??= false;
        json['supports_self_photos'] ??= false;
        json['supports_self_voice_notes'] ??= false;
        json['supports_self_video_notes'] ??= false;
        json['supports_self_locations'] ??= false;
        json['supports_self_contacts'] ??= false;
        json['supports_channel_chats'] ??= false;
        json['supports_group_chats'] ??= false;
        json['supports_private_chats'] ??= false;
        json['supports_bot_chats'] ??= false;
        json['supports_attachment_menu'] ??= false;
        json['supports_side_menu'] ??= false;
        json['supports_inline_queries'] ??= false;
        json['supports_settings'] ??= false;
        json['is_added'] ??= false;
        json['show_in_attachment_menu'] ??= false;
        json['show_in_side_menu'] ??= false;
        json['show_in_editor'] ??= false;
        break;
      case 'chatFolderInfo':
        json['title'] ??= '';
        json['icon_name'] ??= '';
        json['is_shareable'] ??= false;
        json['has_my_invitation_links'] ??= false;
        break;
      case 'scopeNotificationSettings':
        json['mute_for'] ??= 0;
        json['sound_id'] = json['sound_id']?.toString() ?? '0';
        json['show_preview'] ??= false;
        json['use_default_mute_stories'] ??= false;
        json['mute_stories'] ??= false;
        json['story_sound_id'] = json['story_sound_id']?.toString() ?? '0';
        json['show_story_sender'] ??= false;
        json['disable_pinned_message_notifications'] ??= false;
        json['disable_mention_notifications'] ??= false;
        break;
      case 'chatNotificationSettings':
        json['use_default_mute_for'] ??= false;
        json['mute_for'] ??= 0;
        json['use_default_sound'] ??= false;
        json['sound_id'] = json['sound_id']?.toString() ?? '0';
        json['use_default_show_preview'] ??= false;
        json['show_preview'] ??= false;
        json['use_default_mute_stories'] ??= false;
        json['mute_stories'] ??= false;
        json['use_default_story_sound'] ??= false;
        json['story_sound_id'] = json['story_sound_id']?.toString() ?? '0';
        json['use_default_show_story_sender'] ??= false;
        json['show_story_sender'] ??= false;
        json['use_default_disable_pinned_message_notifications'] ??= false;
        json['disable_pinned_message_notifications'] ??= false;
        json['use_default_disable_mention_notifications'] ??= false;
        json['disable_mention_notifications'] ??= false;
        break;
      case 'chat':
        json['title'] ??= '';
        json['is_blocked'] ??= false;
        json['is_marked_as_unread'] ??= false;
        json['is_sponsor'] ??= false;
        json['has_scheduled_messages'] ??= false;
        json['can_be_deleted_only_for_self'] ??= false;
        json['can_be_deleted_for_all_users'] ??= false;
        json['can_be_reported'] ??= false;
        json['default_disable_notification'] ??= false;
        json['unread_count'] ??= 0;
        json['last_read_inbox_message_id'] ??= 0;
        json['last_read_outbox_message_id'] ??= 0;
        json['unread_mention_count'] ??= 0;
        json['unread_reaction_count'] ??= 0;
        json['has_protected_content'] ??= false;
        json['is_translatable'] ??= false;
        json['message_auto_delete_time'] ??= 0;
        json['theme_name'] ??= '';
        json['reply_markup_message_id'] ??= 0;
        json['client_data'] ??= '';
        json['permissions'] ??= {'@type': 'chatPermissions'};
        json['notification_settings'] ??= {'@type': 'chatNotificationSettings'};
        json['available_reactions'] ??= {'@type': 'chatAvailableReactionsAll'};
        json['video_chat'] ??= {'@type': 'videoChat', 'group_call_id': 0, 'has_participants': false};
        break;
      case 'videoChat':
        json['group_call_id'] ??= 0;
        json['has_participants'] ??= false;
        break;
      case 'chatMemberStatusCreator':
        json['custom_title'] ??= '';
        json['is_anonymous'] ??= false;
        json['is_member'] ??= false;
        break;
      case 'chatMemberStatusAdministrator':
        json['custom_title'] ??= '';
        json['can_be_edited'] ??= false;
        json['rights'] ??= {
          '@type': 'chatAdministratorRights',
          'can_post_messages': false,
          'can_edit_messages': false,
          'can_delete_messages': false,
          'can_restrict_members': false,
          'can_promote_members': false,
          'can_change_info': false,
          'can_invite_users': false,
          'can_pin_messages': false,
          'can_manage_topics': false,
          'can_manage_video_chats': false,
          'is_anonymous': false
        };
        break;
      case 'userFullInfo':
        json['is_blocked'] ??= false;
        json['can_be_called'] ??= false;
        json['supports_video_calls'] ??= false;
        json['has_private_calls'] ??= false;
        json['has_private_forwards'] ??= false;
        json['has_restricted_voice_and_video_note_messages'] ??= false;
        json['has_pinned_stories'] ??= false;
        json['need_phone_number_privacy_exception'] ??= false;
        json['group_in_common_count'] ??= 0;
        if (json['bio'] is String) {
          json['bio'] = {
            '@type': 'formattedText',
            'text': json['bio'],
            'entities': []
          };
        }
        break;
      case 'supergroup':
        json['username'] ??= '';
        json['is_verified'] ??= false;
        json['has_sensitive_content'] ??= false;
        json['is_scam'] ??= false;
        json['is_fake'] ??= false;
        json['is_forum'] ??= false;
        json['has_active_stories'] ??= false;
        json['has_unread_active_stories'] ??= false;
        json['sign_messages'] ??= false;
        json['join_to_send_messages'] ??= false;
        json['join_by_request'] ??= false;
        json['is_broadcast_group'] ??= false;
        json['is_channel'] ??= false;
        json['is_slow_mode_enabled'] ??= false;
        json['has_location'] ??= false;
        json['has_linked_chat'] ??= false;
        json['member_count'] ??= 0;
        json['date'] ??= 0;
        json['restriction_reason'] ??= '';
        json['status'] ??= {'@type': 'chatMemberStatusMember'};
        break;
      case 'message':
        json['is_outgoing'] ??= false;
        json['is_pinned'] ??= false;
        json['can_be_edited'] ??= false;
        json['can_be_forwarded'] ??= false;
        json['can_be_saved'] ??= false;
        json['can_be_deleted_only_for_self'] ??= false;
        json['can_be_deleted_for_all_users'] ??= false;
        json['can_get_added_reactions'] ??= false;
        json['can_get_statistics'] ??= false;
        json['can_get_message_thread'] ??= false;
        json['can_get_viewers'] ??= false;
        json['can_get_media_timestamp_links'] ??= false;
        json['can_report_reactions'] ??= false;
        json['has_timestamped_media'] ??= false;
        json['is_channel_post'] ??= false;
        json['is_topic_message'] ??= false;
        json['contains_unread_mention'] ??= false;
        json['message_thread_id'] ??= 0;
        json['self_destruct_time'] ??= 0;
        json['self_destruct_in'] ??= 0.0;
        json['auto_delete_in'] ??= 0.0;
        json['via_bot_user_id'] ??= 0;
        json['author_signature'] ??= '';
        json['media_album_id'] = json['media_album_id']?.toString() ?? '0';
        json['restriction_reason'] ??= '';
        json['date'] ??= 0;
        json['edit_date'] ??= 0;
        break;
    }

    return json;
  }

  void _startEventLoop() async {
    while (!_isDestroyed) {
      try {
        while (!_isDestroyed) {
          td.TdObject? event;
          if (_libInitialized) {
            final rawPtr = _nativeReceive(0.0);
            if (rawPtr == nullptr) {
              break;
            }
            final jsonStr = rawPtr.toDartString();
            final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
            final sanitized = sanitizeJson(jsonMap);
            event = td.convertToObject(jsonEncode(sanitized));
          } else {
            event = tdReceive(0.0);
            if (event == null) {
              break;
            }
          }

          if (event == null) {
            continue;
          }

          // Filter out false-positive TdError events caused by closing inactive client IDs on startup
          if (event is td.TdError && (event.message == "Invalid TDLib instance specified" || event.message.contains("Invalid TDLib instance"))) {
            continue;
          }
          if (event.extra is int) {
            final id = event.extra as int;
            if (_pendingRequests.containsKey(id)) {
              _pendingRequests[id]!.complete(event);
              _pendingRequests.remove(id);
              continue;
            }
          }
          _updatesController.add(event);
        }
      } catch (e, stack) {
        Log.e("Exception inside TDLib event loop", e, stack);
      }
      await Future.delayed(const Duration(milliseconds: 5));
    }
  }

  void send(td.TdFunction request, {dynamic extra}) {
    if (_clientId != null) {
      tdSend(_clientId!, request, extra);
    }
  }

  Future<td.TdObject> sendAsync(td.TdFunction request) {
    final id = ++_requestId;
    final completer = Completer<td.TdObject>();
    _pendingRequests[id] = completer;
    
    // Automatically clean up after 30 seconds to prevent memory leaks if TDLib never responds
    Future.delayed(const Duration(seconds: 30), () {
      if (_pendingRequests.containsKey(id)) {
        _pendingRequests.remove(id);
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('TDLib response timeout', const Duration(seconds: 30)));
        }
      }
    });

    send(request, extra: id);
    return completer.future;
  }

  void loadChatsInBackground() {
    Future(() async {
      int chatsLoaded = 0;
      while (chatsLoaded < 500) {
        if (_isDestroyed || _clientId == null) break;
        final res = await sendAsync(td.LoadChats(
          chatList: const td.ChatListMain(),
          limit: 100,
        )).timeout(
          const Duration(seconds: 10),
          onTimeout: () => td.TdError(code: 408, message: "Request Timeout"),
        );
        if (res is td.TdError) {
          break; // End of list or error
        }
        chatsLoaded += 100;
        await Future.delayed(const Duration(milliseconds: 200));
      }
    });
  }

  void destroy() {
    _isDestroyed = true;
    _updatesController.close();
    if (_clientId != null) {
      try {
        tdSend(_clientId!, const td.Close());
      } catch (_) {}
      _clientId = null;
    }
  }

  Future<void> saveMetadataOverride(String folderName, String imdbOrMalId) async {
    try {
      final channelId = await getOrCreateMetadataChannel();
      if (channelId == 0) return;
      
      final data = jsonEncode({'folder': folderName, 'id': imdbOrMalId});
      final inputMessageContent = td.InputMessageText(
        text: td.FormattedText(text: data, entities: []),
        disableWebPagePreview: true,
        clearDraft: true,
      );
      
      await sendAsync(td.SendMessage(
        chatId: channelId,
        messageThreadId: 0,
        replyTo: null,
        options: const td.MessageSendOptions(
          disableNotification: true,
          fromBackground: true,
          protectContent: false,
          updateOrderOfInstalledStickerSets: false,
        ),
        replyMarkup: null,
        inputMessageContent: inputMessageContent,
      ));
      
      const storage = FlutterSecureStorage();
      final cacheKey = 'metadata_override_$folderName';
      await storage.write(key: cacheKey, value: imdbOrMalId);
      
      Log.i('Saved metadata override for $folderName -> $imdbOrMalId');
    } catch (e) {
      Log.e('Failed to save metadata override', e);
    }
  }

  Future<int> getOrCreateMetadataChannel() async {
    const storage = FlutterSecureStorage();
    final cachedId = await storage.read(key: 'metadata_channel_id');
    if (cachedId != null && int.tryParse(cachedId) != null) {
      return int.parse(cachedId);
    }
    
    try {
      final newChat = await sendAsync(const td.CreateNewSupergroupChat(
        title: 'TelStream Metadata',
        isForBroadcast: true,
        isChannel: true,
        description: 'Hidden channel storing metadata overrides for TelStream',
        location: null,
        messageAutoDeleteTime: 0,
        forImport: false,
      ));
      
      if (newChat is td.Chat) {
        await storage.write(key: 'metadata_channel_id', value: newChat.id.toString());
        return newChat.id;
      }
    } catch (e) {
      Log.e('Failed to create metadata channel', e);
    }
    return 0;
  }
}
