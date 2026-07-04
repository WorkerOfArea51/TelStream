import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/logger.dart';

class FirebaseMetadataService {
  // Use String.fromEnvironment to securely inject the URL at compile time,
  // falling back to a default empty string if not provided.
  static const String _baseUrl = String.fromEnvironment(
    'FIREBASE_DB_URL',
    defaultValue: '',
  );

  static Map<String, String> _cache = {};

  /// Loads all metadata overrides from Firebase into local memory.
  /// This should be called once on app startup.
  static Future<void> loadAllMetadata() async {
    if (_baseUrl.isEmpty) {
      Log.w('Firebase DB URL is not set.');
      return;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/metadata.json')).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 && response.body != 'null') {
        final Map<String, dynamic> data = json.decode(response.body);
        _cache = data.map((key, value) => MapEntry(_decodeKey(key), value.toString()));
        Log.i('Successfully loaded ${_cache.length} metadata overrides from Firebase.');
      } else {
        Log.i('Firebase metadata is empty or returned status: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Failed to load metadata from Firebase', e);
    }
  }

  /// Gets the currently cached override for a specific folder.
  static String? getOverride(String coreName) {
    return _cache[coreName];
  }

  /// Saves a new override to Firebase and updates the local cache.
  static Future<void> saveOverride(String coreName, String ids) async {
    if (_baseUrl.isEmpty) {
      Log.w('Firebase DB URL is not set. Cannot save override.');
      return;
    }

    // Update local cache immediately for instant UI updates
    _cache[coreName] = ids;
    Log.i('Saved metadata override locally for $coreName -> $ids');

    // Sync to Firebase in the background
    try {
      final safeKey = _encodeKey(coreName);
      final response = await http.put(
        Uri.parse('$_baseUrl/metadata/$safeKey.json'),
        body: json.encode(ids),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Successfully synced metadata override to Firebase for $coreName');
      } else {
        Log.e('Failed to sync to Firebase. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      Log.e('Exception while syncing metadata to Firebase', e);
    }
  }

  /// Firebase keys cannot contain . # $ [ ]
  /// To be absolutely safe with any folder name, we encode the folder name as Base64Url.
  static String _encodeKey(String key) {
    return base64Url.encode(utf8.encode(key)).replaceAll('=', '');
  }

  /// Decodes the Base64Url string back into the folder name.
  static String _decodeKey(String encodedKey) {
    String normalized = encodedKey;
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return utf8.decode(base64Url.decode(normalized));
  }
}
