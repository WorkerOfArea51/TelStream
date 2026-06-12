import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  File? _file;
  Map<String, dynamic> _data = {
    'history': <String, int>{}, // messageId (String) -> position in seconds
    'favorites': <String>[], // coreName
    'last_watched': null, // { 'seriesName': String, 'messageId': int, 'episodeIndex': int }
  };

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _file = File('${directory.path}/user_storage.json');
    
    if (await _file!.exists()) {
      try {
        final content = await _file!.readAsString();
        _data = json.decode(content);
      } catch (e) {
        // If file is corrupted, start fresh
      }
    }
  }

  Future<void> _save() async {
    if (_file != null) {
      await _file!.writeAsString(json.encode(_data));
    }
  }

  // --- Watch History ---

  Future<void> saveWatchPosition(int messageId, int positionInSeconds) async {
    _data['history'] ??= <String, dynamic>{};
    _data['history'][messageId.toString()] = positionInSeconds;
    await _save();
  }

  int getWatchPosition(int messageId) {
    if (_data['history'] == null) return 0;
    return _data['history'][messageId.toString()] ?? 0;
  }

  Future<void> setLastWatched(String seriesName, int messageId, int episodeIndex) async {
    _data['last_watched'] = {
      'seriesName': seriesName,
      'messageId': messageId,
      'episodeIndex': episodeIndex,
    };
    await _save();
  }

  Map<String, dynamic>? getLastWatched() {
    return _data['last_watched'];
  }

  // --- Favorites ---

  List<String> getFavorites() {
    if (_data['favorites'] == null) return [];
    return List<String>.from(_data['favorites']);
  }

  bool isFavorite(String coreName) {
    return getFavorites().contains(coreName);
  }

  Future<void> toggleFavorite(String coreName) async {
    _data['favorites'] ??= <dynamic>[];
    List<String> favs = List<String>.from(_data['favorites']);
    
    if (favs.contains(coreName)) {
      favs.remove(coreName);
    } else {
      favs.add(coreName);
    }
    
    _data['favorites'] = favs;
    await _save();
  }

  // --- Video Settings ---

  Map<String, dynamic> getVideoSettings() {
    if (_data['video_settings'] == null) return {};
    return Map<String, dynamic>.from(_data['video_settings']);
  }

  Future<void> updateVideoSettings(Map<String, dynamic> settings) async {
    _data['video_settings'] = settings;
    await _save();
  }
}

class FavoritesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return ref.watch(storageServiceProvider).getFavorites();
  }

  void toggleFavorite(String coreName) {
    final storage = ref.read(storageServiceProvider);
    storage.toggleFavorite(coreName);
    state = storage.getFavorites();
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<String>>(FavoritesNotifier.new);

class LastWatchedNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() {
    return ref.watch(storageServiceProvider).getLastWatched();
  }

  void updateLastWatched(String seriesName, int messageId, int episodeIndex) {
    ref.read(storageServiceProvider).setLastWatched(seriesName, messageId, episodeIndex);
    state = {
      'seriesName': seriesName,
      'messageId': messageId,
      'episodeIndex': episodeIndex,
    };
  }
}

final lastWatchedProvider = NotifierProvider<LastWatchedNotifier, Map<String, dynamic>?>(LastWatchedNotifier.new);
