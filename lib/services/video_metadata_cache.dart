import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/logger.dart';
import '../core/video_metadata/video_metadata.dart';


/// Result type for [VideoMetadataCache.get]. Callers MUST pattern-match
/// against this — never against the value being null/unknown.
sealed class VideoMetadataCacheResult {
  const VideoMetadataCacheResult();
}

class CachedMetadata extends VideoMetadataCacheResult {
  final VideoMetadata metadata;
  const CachedMetadata(this.metadata);
}

class CachedFailure extends VideoMetadataCacheResult {
  final String? reason;
  const CachedFailure({this.reason});
}

class CacheMiss extends VideoMetadataCacheResult {
  const CacheMiss();
}

class VideoMetadataCache {
  static const String _keyPrefix = 'meta_cache_';
  static const _storage = FlutterSecureStorage();
  static const Duration _failureTtl = Duration(hours: 1);

  static String _getKey(int messageId) => '$_keyPrefix$messageId';

  static Future<VideoMetadataCacheResult> get(int messageId) async {
    try {
      final str = await _storage.read(key: _getKey(messageId));
      if (str == null) return const CacheMiss();

      final Map<String, dynamic> data = jsonDecode(str);

      if (data['isFailure'] == true) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
        if (DateTime.now().difference(timestamp) < _failureTtl) {
          return CachedFailure(reason: data['reason'] as String?);
        } else {
          await _storage.delete(key: _getKey(messageId));
          return const CacheMiss();
        }
      }

      if (data['metadata'] != null) {
        return CachedMetadata(
          VideoMetadata.fromFlatJson(data['metadata'] as Map<String, dynamic>),
        );
      }
      return const CacheMiss();
    } catch (e, st) {
      Log.e('Failed to read VideoMetadataCache for $messageId', e, st);
      return const CacheMiss();
    }
  }

  static Future<void> save(int messageId, VideoMetadata metadata) async {
    try {
      final data = {
        'isFailure': false,
        'metadata': metadata.toFlatJson(),
      };
      await _storage.write(key: _getKey(messageId), value: jsonEncode(data));
    } catch (e, st) {
      Log.e('Failed to save VideoMetadataCache for $messageId', e, st);
    }
  }

  static Future<void> saveFailure(int messageId, {String? reason}) async {
    try {
      final data = {
        'isFailure': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        // ignore: use_null_aware_elements
        if (reason != null) 'reason': reason,
      };
      await _storage.write(key: _getKey(messageId), value: jsonEncode(data));
    } catch (e, st) {
      Log.e('Failed to save VideoMetadataCache failure for $messageId', e, st);
    }
  }

  
  static Future<void> clearForMessage(int messageId) async {
    try {
      await _storage.delete(key: _getKey(messageId));
    } catch (e, st) {
      Log.e('Failed to clear VideoMetadataCache for $messageId', e, st);
    }
  }

  static Future<void> clearAll() async {
    try {
      final all = await _storage.readAll();
      for (final key in all.keys) {
        if (key.startsWith(_keyPrefix)) {
          await _storage.delete(key: key);
        }
      }
    } catch (e, st) {
      Log.e('Failed to clear VideoMetadataCache', e, st);
    }
  }
}
