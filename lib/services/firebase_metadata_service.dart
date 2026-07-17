import 'dart:convert';
import 'package:http/http.dart' as http;
import 'metadata_service.dart';
import '../core/logger.dart';

class FirebaseMetadataService {
  // Use String.fromEnvironment to securely inject the URL at compile time,
  // falling back to a default empty string if not provided.
  static const String _baseUrl = String.fromEnvironment(
    'FIREBASE_DB_URL',
    defaultValue: '',
  );

  static Map<String, String> _cache = {};
  static final Map<String, List<SeriesMetadata>> _preloadedCache = {};

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
        final Map<String, String> newCache = {};
        
        data.forEach((key, value) {
          if (key.endsWith('_count')) return;
          
          if (value is Map<String, dynamic>) {
            // Check if this is a Category node containing encoded keys
            value.forEach((subKey, subValue) {
              if (subKey == '_count') return;
              if (subValue is Map<String, dynamic>) {
                final decodedKey = _decodeKey(subKey);
                newCache[decodedKey] = subValue.containsKey('id') ? subValue['id'].toString() : 'preloaded';
                
                if (subValue.containsKey('preloaded')) {
                  try {
                    final rawPreloaded = subValue['preloaded'];
                    List<SeriesMetadata> preloadedList = [];
                    if (rawPreloaded is List) {
                      preloadedList = rawPreloaded.where((e) => e != null).map((e) => SeriesMetadata.fromJson(e)).toList();
                    } else if (rawPreloaded is Map) {
                      // If it's a Map (e.g. {"0": {...}}), extract the values
                      final sortedKeys = rawPreloaded.keys.toList()..sort();
                      for (final k in sortedKeys) {
                        if (rawPreloaded[k] != null) {
                          preloadedList.add(SeriesMetadata.fromJson(rawPreloaded[k]));
                        }
                      }
                    }
                    if (preloadedList.isNotEmpty) {
                      _preloadedCache[decodedKey] = preloadedList;
                    }
                  } catch (e) {
                    Log.e('Failed to parse preloaded metadata for $decodedKey', e);
                  }
                } else if (subValue.containsKey('0') && subValue['0'] is Map) {
                  // Fallback: user created a '0' folder directly on the node instead of inside 'preloaded'
                  try {
                    _preloadedCache[decodedKey] = [SeriesMetadata.fromJson(subValue['0'])];
                  } catch (e) {
                    Log.e('Failed to parse manual metadata in 0 folder for $decodedKey', e);
                  }
                } else if (subValue.containsKey('posterUrl') || subValue.containsKey('synopsis') || subValue.containsKey('releaseYear')) {
                  // Fallback: allow manual entry of flat metadata fields directly on the node
                  try {
                    _preloadedCache[decodedKey] = [SeriesMetadata.fromJson(subValue)];
                  } catch (e) {
                    Log.e('Failed to parse direct manual metadata for $decodedKey', e);
                  }
                } else if (subValue.containsKey(decodedKey) && subValue[decodedKey] is Map) {
                  // Fallback: user imported a JSON file where the root key is the series name
                  try {
                    _preloadedCache[decodedKey] = [SeriesMetadata.fromJson(subValue[decodedKey])];
                  } catch (e) {
                    Log.e('Failed to parse imported JSON metadata for $decodedKey', e);
                  }
                }
              } else {
                newCache[_decodeKey(subKey)] = subValue.toString();
              }
            });
          } else {
            // Legacy flat structure
            newCache[_decodeKey(key)] = value.toString();
          }
        });
        
        _cache = newCache;
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

  /// Gets the preloaded metadata for a specific folder if it exists.
  static List<SeriesMetadata>? getPreloadedMetadata(String coreName) {
    return _preloadedCache[coreName];
  }

  /// Saves a new override to Firebase and updates the local cache.
  static Future<void> saveOverride(String category, String coreName, String ids, {List<SeriesMetadata>? preloadedData}) async {
    if (_baseUrl.isEmpty) {
      Log.w('Firebase DB URL is not set. Cannot save override.');
      return;
    }

    // Update local cache immediately for instant UI updates
    _cache[coreName] = ids;
    if (preloadedData != null) {
      _preloadedCache[coreName] = preloadedData;
    }
    Log.i('Saved metadata override locally for $coreName -> $ids');

    // Sync to Firebase in the background
    try {
      final safeKey = _encodeKey(coreName);
      final safeCategory = category.replaceAll(' ', ''); // E.g., 'Web Series' -> 'WebSeries'
      
      final Map<String, dynamic> payloadData = {
        'title': coreName,
        'id': ids,
      };
      
      if (preloadedData != null) {
        payloadData['preloaded'] = preloadedData.map((e) => e.toJson()).toList();
      }
      
      final payload = json.encode(payloadData);

      final response = await http.put(
        Uri.parse('$_baseUrl/metadata/$safeCategory/$safeKey.json'),
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Successfully synced metadata override to Firebase for $coreName in $safeCategory');
        
        // Update the count for this category
        try {
          final countRes = await http.get(Uri.parse('$_baseUrl/metadata/$safeCategory.json?shallow=true')).timeout(const Duration(seconds: 5));
          if (countRes.statusCode == 200 && countRes.body != 'null') {
            final Map<String, dynamic> catData = json.decode(countRes.body);
            int count = catData.keys.where((k) => k != '_count').length;
            await http.put(
              Uri.parse('$_baseUrl/metadata/${safeCategory}_count.json'),
              body: json.encode(count),
            );
            // Clean up the old mis-placed count
            await http.delete(Uri.parse('$_baseUrl/metadata/$safeCategory/_count.json'));
          }
        } catch (e) {
          Log.w('Failed to update category count');
        }
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
    try {
      String normalized = encodedKey;
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      return utf8.decode(base64Url.decode(normalized));
    } catch (e) {
      Log.w('Failed to decode key $encodedKey: $e');
      return encodedKey; // Fallback to raw key if decoding fails
    }
  }
}
