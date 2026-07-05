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
          doc['thumbnail'] = doc['thumbnail'] ?? null;
        }
      }
    } else if (type == 'file') {
      out['expected_size'] = out['expected_size'] ?? 0;
      final local = out['local'];
      if (local is Map<String, dynamic>) {
        local['download_offset'] = local['download_offset'] ?? 0;
        local['downloaded_size'] = local['downloaded_size'] ?? 0;
      }
    }

    return out;
  }
}
