import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'metadata_service.dart';
import '../core/logger.dart';

class FirebaseMetadataState {
  final Map<String, String> cache;
  final Map<String, List<SeriesMetadata>> preloadedCache;
  final bool isLoading;

  FirebaseMetadataState({
    required this.cache,
    required this.preloadedCache,
    this.isLoading = false,
  });

  FirebaseMetadataState copyWith({
    Map<String, String>? cache,
    Map<String, List<SeriesMetadata>>? preloadedCache,
    bool? isLoading,
  }) {
    return FirebaseMetadataState(
      cache: cache ?? this.cache,
      preloadedCache: preloadedCache ?? this.preloadedCache,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FirebaseMetadataNotifier extends Notifier<FirebaseMetadataState> {
  static const String _baseUrl = String.fromEnvironment(
    'FIREBASE_DB_URL',
    defaultValue: '',
  );

  @override
  FirebaseMetadataState build() {
    return FirebaseMetadataState(cache: {}, preloadedCache: {});
  }

  Future<void> loadAllMetadata() async {
    if (_baseUrl.isEmpty) {
      Log.w('Firebase DB URL is not set.');
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final response = await http.get(Uri.parse('$_baseUrl/metadata.json')).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 && response.body != 'null') {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, String> newCache = {};
        final Map<String, List<SeriesMetadata>> newPreloadedCache = {};
        
        data.forEach((key, value) {
          if (key.endsWith('_count')) return;
          
          if (value is Map<String, dynamic>) {
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
                      final sortedKeys = rawPreloaded.keys.toList()..sort();
                      for (final k in sortedKeys) {
                        if (rawPreloaded[k] != null) {
                          preloadedList.add(SeriesMetadata.fromJson(rawPreloaded[k]));
                        }
                      }
                    }
                    if (preloadedList.isNotEmpty) {
                      newPreloadedCache[decodedKey] = preloadedList;
                    }
                  } catch (e) {
                    Log.e('Failed to parse preloaded metadata for $decodedKey', e);
                  }
                } else if (subValue.containsKey('0') && subValue['0'] is Map) {
                  try {
                    newPreloadedCache[decodedKey] = [SeriesMetadata.fromJson(subValue['0'])];
                  } catch (e) {
                    Log.e('Failed to parse manual metadata in 0 folder for $decodedKey', e);
                  }
                } else if (subValue.containsKey('posterUrl') || subValue.containsKey('synopsis') || subValue.containsKey('releaseYear')) {
                  try {
                    newPreloadedCache[decodedKey] = [SeriesMetadata.fromJson(subValue)];
                  } catch (e) {
                    Log.e('Failed to parse direct manual metadata for $decodedKey', e);
                  }
                } else if (subValue.containsKey(decodedKey) && subValue[decodedKey] is Map) {
                  try {
                    newPreloadedCache[decodedKey] = [SeriesMetadata.fromJson(subValue[decodedKey])];
                  } catch (e) {
                    Log.e('Failed to parse imported JSON metadata for $decodedKey', e);
                  }
                }
              } else {
                newCache[_decodeKey(subKey)] = subValue.toString();
              }
            });
          } else {
            newCache[_decodeKey(key)] = value.toString();
          }
        });
        
        state = state.copyWith(cache: newCache, preloadedCache: newPreloadedCache, isLoading: false);
        Log.i('Successfully loaded ${newCache.length} metadata overrides from Firebase.');
      } else {
        Log.i('Firebase metadata is empty or returned status: ${response.statusCode}');
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      Log.e('Failed to load metadata from Firebase', e);
      state = state.copyWith(isLoading: false);
    }
  }

  String? getOverride(String coreName) {
    return state.cache[coreName];
  }

  List<SeriesMetadata>? getPreloadedMetadata(String coreName) {
    return state.preloadedCache[coreName];
  }

  Future<void> saveOverride(String category, String coreName, String ids, {List<SeriesMetadata>? preloadedData}) async {
    if (_baseUrl.isEmpty) {
      Log.w('Firebase DB URL is not set. Cannot save override.');
      return;
    }

    final newCache = Map<String, String>.from(state.cache);
    newCache[coreName] = ids;

    final newPreloadedCache = Map<String, List<SeriesMetadata>>.from(state.preloadedCache);
    if (preloadedData != null) {
      newPreloadedCache[coreName] = preloadedData;
    }

    state = state.copyWith(cache: newCache, preloadedCache: newPreloadedCache);
    Log.i('Saved metadata override locally for $coreName -> $ids');

    try {
      final safeKey = _encodeKey(coreName);
      final safeCategory = category.replaceAll(' ', '');
      
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
        try {
          final countRes = await http.get(Uri.parse('$_baseUrl/metadata/$safeCategory.json?shallow=true')).timeout(const Duration(seconds: 5));
          if (countRes.statusCode == 200 && countRes.body != 'null') {
            final Map<String, dynamic> catData = json.decode(countRes.body);
            int count = catData.keys.where((k) => k != '_count').length;
            await http.put(
              Uri.parse('$_baseUrl/metadata/${safeCategory}_count.json'),
              body: json.encode(count),
            );
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

  static String _encodeKey(String key) {
    return base64Url.encode(utf8.encode(key)).replaceAll('=', '');
  }

  static String _decodeKey(String encodedKey) {
    try {
      String normalized = encodedKey;
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      return utf8.decode(base64Url.decode(normalized));
    } catch (e) {
      Log.w('Failed to decode key $encodedKey: $e');
      return encodedKey;
    }
  }
}

final firebaseMetadataProvider = NotifierProvider<FirebaseMetadataNotifier, FirebaseMetadataState>(() {
  return FirebaseMetadataNotifier();
});
