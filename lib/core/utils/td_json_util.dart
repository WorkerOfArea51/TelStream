class TdJsonUtil {
  static bool _needsString(String? type, String key) {
    if (key == 'media_album_id' || 
        key == 'custom_emoji_id' ||
        key == 'sticker_set_id' ||
        key == 'sticker_id' ||
        key == 'background_id' ||
        key == 'chat_photo_id' ||
        key == 'sound_id' ||
        key == 'story_sound_id' ||
        key == 'inline_query_id' ||
        key == 'game_id' ||
        key == 'cryptocurrency_amount') {
      return true;
    }
    if (key == 'id') {
      const stringIdTypes = {
        'background', 'callServer', 'chatEvent', 'chatPhoto', 'connectedWebsite',
        'game', 'notificationSound', 'paymentForm', 'poll', 'profilePhoto',
        'pushReceiverId', 'session'
      };
      return stringIdTypes.contains(type);
    }
    if (key == 'order' && type == 'chatPosition') return true;
    if (key == 'value' && type == 'optionValueInteger') return true;
    return false;
  }

  /// Mutates the input map in-place for maximum performance on huge TDLib JSON trees.
  static Map<String, dynamic> sanitize(Map<String, dynamic> input) {
    final type = input['@type'] as String?;

    for (final entry in input.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        sanitize(value);
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          final item = value[i];
          if (item is Map<String, dynamic>) {
            sanitize(item);
          }
        }
      } else if (value is int && _needsString(type, key)) {
        input[key] = value.toString();
      }
    }

    if (type == null) return input;

    switch (type) {
      case 'messageVideo':
        input['has_stickers'] ??= false;
        break;
      case 'messageDocument':
        final doc = input['document'];
        if (doc is Map<String, dynamic> && doc['@type'] == 'document') {
          doc['thumbnail'] = doc['thumbnail'];
        }
        break;
      case 'file':
        input['expected_size'] ??= 0;
        final local = input['local'];
        if (local is Map<String, dynamic>) {
          local['download_offset'] ??= 0;
          local['downloaded_size'] ??= 0;
        }
        break;
      case 'user':
        input['is_contact'] ??= false;
        input['is_mutual_contact'] ??= false;
        input['is_close_friend'] ??= false;
        input['is_verified'] ??= false;
        input['is_premium'] ??= false;
        input['is_support'] ??= false;
        input['is_scam'] ??= false;
        input['is_fake'] ??= false;
        input['has_active_stories'] ??= false;
        input['has_unread_active_stories'] ??= false;
        input['have_access'] ??= false;
        input['added_to_attachment_menu'] ??= false;
        input['restriction_reason'] ??= '';
        input['language_code'] ??= '';
        input['phone_number'] ??= '';
        input['first_name'] ??= '';
        input['last_name'] ??= '';
        break;
      case 'userFullInfo':
        input['group_in_common_count'] ??= 0;
        input['is_blocked'] ??= false;
        input['can_be_called'] ??= false;
        input['supports_video_calls'] ??= false;
        input['has_private_calls'] ??= false;
        input['has_private_forwards'] ??= false;
        input['has_restricted_voice_and_video_messages'] ??= false;
        input['has_pinned_stories'] ??= false;
        input['need_phone_number_privacy_exception'] ??= false;
        break;
      case 'chatMemberStatusCreator':
      case 'chatMemberStatusAdministrator':
        input['custom_title'] ??= "";
        break;
      case 'scopeNotificationSettings':
        input['disable_mention_notifications'] ??= false;
        input['disable_pinned_message_notifications'] ??= false;
        input['show_preview'] ??= false;
        input['use_default_mute_stories'] ??= false;
        input['mute_stories'] ??= false;
        input['story_sound_id'] ??= "0";
        input['show_story_sender'] ??= false;
        break;
      case 'chatNotificationSettings':
        input['use_default_disable_pinned_message_notifications'] ??= false;
        input['use_default_disable_mention_notifications'] ??= false;
        input['use_default_show_preview'] ??= false;
        input['disable_pinned_message_notifications'] ??= false;
        input['disable_mention_notifications'] ??= false;
        input['show_preview'] ??= false;
        input['use_default_mute_stories'] ??= false;
        input['mute_stories'] ??= false;
        input['use_default_story_sound'] ??= false;
        input['story_sound_id'] ??= "0";
        input['use_default_show_story_sender'] ??= false;
        input['show_story_sender'] ??= false;
        break;
      case 'attachmentMenuBot':
        input['request_write_access'] ??= false;
        input['supports_settings'] ??= false;
        break;
      case 'stickerSetInfo':
      case 'stickerSet':
        if (input['thumbnail_outline'] is Map) {
          input['thumbnail_outline'] = [];
        }
        input['sticker_format'] ??= {'@type': 'stickerFormatWebp'};
        break;
      case 'updateInstalledStickerSets':
        final list = input['sticker_set_ids'];
        if (list is List) {
          input['sticker_set_ids'] = list.map((e) {
            if (e is num) return e.toInt();
            if (e is String) return int.tryParse(e) ?? 0;
            return 0;
          }).toList();
        }
        break;
      case 'updateTrendingStickerSets':
        final sets = input['sticker_sets'];
        if (sets is List) {
          for (var s in sets) {
            if (s is Map && s['thumbnail_outline'] is Map) {
              s['thumbnail_outline'] = [];
            }
          }
        }
        break;
      case 'chatPermissions':
        input['can_send_basic_messages'] ??= false;
        input['can_send_audios'] ??= false;
        input['can_send_documents'] ??= false;
        input['can_send_photos'] ??= false;
        input['can_send_videos'] ??= false;
        input['can_send_video_notes'] ??= false;
        input['can_send_voice_notes'] ??= false;
        input['can_send_polls'] ??= false;
        input['can_send_other_messages'] ??= false;
        input['can_add_web_page_previews'] ??= false;
        input['can_change_info'] ??= false;
        input['can_invite_users'] ??= false;
        input['can_pin_messages'] ??= false;
        input['can_manage_topics'] ??= false;
        break;
      case 'message':
        input['restriction_reason'] ??= "";
        input['is_outgoing'] ??= false;
        input['is_pinned'] ??= false;
        input['can_be_edited'] ??= false;
        input['can_be_forwarded'] ??= false;
        input['can_be_saved'] ??= false;
        input['can_be_deleted_only_for_self'] ??= false;
        input['can_be_deleted_for_all_users'] ??= false;
        input['can_get_added_reactions'] ??= false;
        input['can_get_statistics'] ??= false;
        input['can_get_message_thread'] ??= false;
        input['can_get_viewers'] ??= false;
        input['can_get_media_timestamp_links'] ??= false;
        input['can_report_reactions'] ??= false;
        input['has_timestamped_media'] ??= false;
        input['is_channel_post'] ??= false;
        input['is_topic_message'] ??= false;
        input['contains_unread_mention'] ??= false;
        input['media_album_id'] ??= "0";
        input['message_thread_id'] ??= 0;
        input['self_destruct_in'] ??= 0.0;
        input['auto_delete_in'] ??= 0.0;
        input['via_bot_user_id'] ??= 0;
        break;
      case 'chat':
        input['has_protected_content'] ??= false;
        input['is_translatable'] ??= false;
        input['is_marked_as_unread'] ??= false;
        input['is_blocked'] ??= false;
        input['has_scheduled_messages'] ??= false;
        input['can_be_deleted_only_for_self'] ??= false;
        input['can_be_deleted_for_all_users'] ??= false;
        input['can_be_reported'] ??= false;
        input['default_disable_notification'] ??= false;
        input['theme_name'] ??= "";
        input['unread_count'] ??= 0;
        input['last_read_inbox_message_id'] ??= 0;
        input['last_read_outbox_message_id'] ??= 0;
        input['unread_mention_count'] ??= 0;
        input['unread_reaction_count'] ??= 0;
        input['message_auto_delete_time'] ??= 0;
        input['reply_markup_message_id'] ??= 0;
        break;
      case 'supergroup':
        input['has_location'] ??= false;
        input['sign_messages'] ??= false;
        input['join_to_send_messages'] ??= false;
        input['join_by_request'] ??= false;
        input['is_slow_mode_enabled'] ??= false;
        input['is_channel'] ??= false;
        input['is_broadcast_group'] ??= false;
        input['is_forum'] ??= false;
        input['is_verified'] ??= false;
        input['is_scam'] ??= false;
        input['is_fake'] ??= false;
        input['has_linked_chat'] ??= false;
        input['restriction_reason'] ??= "";
        break;
      case 'targetChatChosen':
        input['allow_user_chats'] ??= false;
        input['allow_bot_chats'] ??= false;
        input['allow_group_chats'] ??= false;
        input['allow_channel_chats'] ??= false;
        break;
    }

    return input;
  }
}
