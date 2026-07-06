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

  /// Pure function that sanitizes TDLib JSON.
  /// It creates a NEW map instead of mutating the input map,
  /// preventing ConcurrentModificationException and side effects.
  static Map<String, dynamic> sanitize(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    final type = input['@type'] as String?;

    for (final entry in input.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        out[key] = sanitize(value);
      } else if (value is List) {
        out[key] = value.map((item) {
          if (item is Map<String, dynamic>) return sanitize(item);
          return item;
        }).toList();
      } else {
        // Fix for TDLib dart package bug where int64 (that fits in 53 bits) is serialized as int but expects String during fromJson
        if (value is int && _needsString(type, key)) {
          out[key] = value.toString();
        } else {
          out[key] = value;
        }
      }
    }

    // Type-specific sanitization on the new map
    final outType = out['@type'];
    if (outType == 'messageVideo') {
      out['has_stickers'] = out['has_stickers'] ?? false;
    } else if (outType == 'messageDocument') {
      final doc = out['document'];
      if (doc is Map<String, dynamic>) {
        final docType = doc['@type'];
        if (docType == 'document') {
          doc['thumbnail'] = doc['thumbnail'];
        }
      }
    } else if (outType == 'file') {
      out['expected_size'] = out['expected_size'] ?? 0;
      final local = out['local'];
      if (local is Map<String, dynamic>) {
        local['download_offset'] = local['download_offset'] ?? 0;
        local['downloaded_size'] = local['downloaded_size'] ?? 0;
      }
    } else if (outType == 'user') {
      out['has_active_stories'] = out['has_active_stories'] ?? false;
    } else if (outType == 'attachmentMenuBot') {
      out['request_write_access'] = out['request_write_access'] ?? false;
      out['supports_settings'] = out['supports_settings'] ?? false;
    } else if (outType == 'scopeNotificationSettings') {
      out['disable_mention_notifications'] = out['disable_mention_notifications'] ?? false;
    } else if (outType == 'stickerSetInfo') {
      if (out['thumbnail_outline'] is Map) {
        out['thumbnail_outline'] = [];
      }
      out['sticker_format'] = out['sticker_format'] ?? {'@type': 'stickerFormatWebp'};
    } else if (outType == 'stickerSet') {
      out['sticker_format'] = out['sticker_format'] ?? {'@type': 'stickerFormatWebp'};
    } else if (outType == 'updateInstalledStickerSets') {
      if (out['sticker_set_ids'] is List) {
        out['sticker_set_ids'] = (out['sticker_set_ids'] as List).map((e) => e is String ? int.tryParse(e) ?? 0 : e).toList();
      }
    } else if (outType == 'updateTrendingStickerSets') {
      // Fix stickerSetInfo inside trending sticker sets if needed, though they are inside sticker_sets list
      if (out['sticker_sets'] is List) {
        for (var s in out['sticker_sets']) {
          if (s is Map && s['thumbnail_outline'] is Map) {
            s['thumbnail_outline'] = [];
          }
        }
      }
    } else if (outType == 'chatPermissions') {
      out['can_send_basic_messages'] = out['can_send_basic_messages'] ?? false;
      out['can_send_audios'] = out['can_send_audios'] ?? false;
      out['can_send_documents'] = out['can_send_documents'] ?? false;
      out['can_send_photos'] = out['can_send_photos'] ?? false;
      out['can_send_videos'] = out['can_send_videos'] ?? false;
      out['can_send_video_notes'] = out['can_send_video_notes'] ?? false;
      out['can_send_voice_notes'] = out['can_send_voice_notes'] ?? false;
      out['can_send_polls'] = out['can_send_polls'] ?? false;
      out['can_send_other_messages'] = out['can_send_other_messages'] ?? false;
      out['can_add_web_page_previews'] = out['can_add_web_page_previews'] ?? false;
      out['can_change_info'] = out['can_change_info'] ?? false;
      out['can_invite_users'] = out['can_invite_users'] ?? false;
      out['can_pin_messages'] = out['can_pin_messages'] ?? false;
      out['can_manage_topics'] = out['can_manage_topics'] ?? false;
    } else if (outType == 'message') {
      out['is_outgoing'] = out['is_outgoing'] ?? false;
      out['is_pinned'] = out['is_pinned'] ?? false;
      out['can_be_edited'] = out['can_be_edited'] ?? false;
      out['can_be_forwarded'] = out['can_be_forwarded'] ?? false;
      out['can_be_saved'] = out['can_be_saved'] ?? false;
      out['can_be_deleted_only_for_self'] = out['can_be_deleted_only_for_self'] ?? false;
      out['can_be_deleted_for_all_users'] = out['can_be_deleted_for_all_users'] ?? false;
      out['can_get_added_reactions'] = out['can_get_added_reactions'] ?? false;
      out['can_get_statistics'] = out['can_get_statistics'] ?? false;
      out['can_get_message_thread'] = out['can_get_message_thread'] ?? false;
      out['can_get_viewers'] = out['can_get_viewers'] ?? false;
      out['can_get_media_timestamp_links'] = out['can_get_media_timestamp_links'] ?? false;
      out['can_report_reactions'] = out['can_report_reactions'] ?? false;
      out['has_timestamped_media'] = out['has_timestamped_media'] ?? false;
      out['is_channel_post'] = out['is_channel_post'] ?? false;
      out['is_topic_message'] = out['is_topic_message'] ?? false;
      out['contains_unread_mention'] = out['contains_unread_mention'] ?? false;
    } else if (outType == 'chat') {
      out['has_protected_content'] = out['has_protected_content'] ?? false;
      out['is_translatable'] = out['is_translatable'] ?? false;
      out['is_marked_as_unread'] = out['is_marked_as_unread'] ?? false;
      out['is_blocked'] = out['is_blocked'] ?? false;
      out['has_scheduled_messages'] = out['has_scheduled_messages'] ?? false;
      out['can_be_deleted_only_for_self'] = out['can_be_deleted_only_for_self'] ?? false;
      out['can_be_deleted_for_all_users'] = out['can_be_deleted_for_all_users'] ?? false;
      out['can_be_reported'] = out['can_be_reported'] ?? false;
    }

    return out;
  }
}
