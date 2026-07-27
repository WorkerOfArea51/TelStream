import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/logger.dart';
import '../core/video_metadata/video_metadata.dart';

class VideoMetadataCache {
  static const String _keyPrefix = 'meta_cache_';
  static const _storage = FlutterSecureStorage();
  static const Duration _failureTtl = Duration(hours: 1);

  static String _getKey(int messageId) => '$_keyPrefix$messageId';

  static Future<VideoMetadata?> get(int messageId) async {
    try {
      final str = await _storage.read(key: _getKey(messageId));
      if (str == null) return null;

      final Map<String, dynamic> data = jsonDecode(str);
      
      // Check for cached failure
      if (data['isFailure'] == true) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
        if (DateTime.now().difference(timestamp) < _failureTtl) {
          // Still within failure TTL, return unknown
          return VideoMetadata.unknown();
        } else {
          // Failure expired, clear it and allow retry
          await _storage.delete(key: _getKey(messageId));
          return null;
        }
      }

      // Valid metadata
      if (data['metadata'] != null) {
        return VideoMetadata.fromFlatJson(data['metadata'] as Map<String, dynamic>);
      }
    } catch (e, st) {
      Log.e('Failed to read VideoMetadataCache for $messageId', e, st);
    }
    return null;
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

  static Future<void> saveFailure(int messageId) async {
    try {
      final data = {
        'isFailure': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await _storage.write(key: _getKey(messageId), value: jsonEncode(data));
    } catch (e, st) {
      Log.e('Failed to save VideoMetadataCache failure for $messageId', e, st);
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
