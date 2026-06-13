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

  // --- Settings Toggles ---

  bool isIncognitoMode() {
    return _data['incognito_mode'] ?? false;
  }

  Future<void> setIncognitoMode(bool value) async {
    _data['incognito_mode'] = value;
    await _save();
  }

  bool isDownloadedOnly() {
    return _data['downloaded_only'] ?? false;
  }

  Future<void> setDownloadedOnly(bool value) async {
    _data['downloaded_only'] = value;
    await _save();
  }

  // --- Watch History ---

  Future<void> saveWatchPosition(int messageId, int positionInSeconds) async {
    if (isIncognitoMode()) return;
    _data['history'] ??= <String, dynamic>{};
    _data['history'][messageId.toString()] = positionInSeconds;
    await _save();
  }

  int getWatchPosition(int messageId) {
    if (_data['history'] == null) return 0;
    return _data['history'][messageId.toString()] ?? 0;
  }

  Future<void> setLastWatched(String seriesName, int messageId, int episodeIndex) async {
    if (isIncognitoMode()) return;
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

  // --- Structured History Log ---

  Future<void> addToHistoryLog({
    required String seriesName,
    required int messageId,
    required int episodeIndex,
    required String episodeTitle,
    required int positionInSeconds,
  }) async {
    if (isIncognitoMode()) return;
    
    _data['history_log'] ??= [];
    final List<dynamic> logs = List.from(_data['history_log']);
    
    // Remove if already exists for this episode/series to avoid duplicates in the timeline
    logs.removeWhere((item) => 
      item['seriesName'] == seriesName && 
      item['episodeIndex'] == episodeIndex
    );
    
    logs.insert(0, {
      'seriesName': seriesName,
      'messageId': messageId,
      'episodeIndex': episodeIndex,
      'episodeTitle': episodeTitle,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'position': positionInSeconds,
    });
    
    // Limit log size to 200 items
    if (logs.length > 200) {
      logs.removeLast();
    }
    
    _data['history_log'] = logs;
    await _save();
  }

  List<Map<String, dynamic>> getHistoryLog() {
    if (_data['history_log'] == null) return [];
    return List<Map<String, dynamic>>.from(
      (_data['history_log'] as List).map((item) => Map<String, dynamic>.from(item))
    );
  }

  Future<void> clearHistoryLog() async {
    _data['history_log'] = [];
    _data['history'] = {};
    _data['last_watched'] = null;
    await _save();
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

  // --- Download Directory ---

  String? getCustomDownloadDirectory() {
    return _data['custom_download_directory'] as String?;
  }

  Future<void> setCustomDownloadDirectory(String? path) async {
    _data['custom_download_directory'] = path;
    await _save();
  }

  // --- Downloaded Files Tracker ---

  Map<int, String> getDownloadedFiles() {
    if (_data['downloaded_files'] == null) return {};
    final Map<String, dynamic> rawMap = Map<String, dynamic>.from(_data['downloaded_files']);
    return rawMap.map((key, value) => MapEntry(int.parse(key), value as String));
  }

  Future<void> addDownloadedFile(int fileId, String filePath) async {
    _data['downloaded_files'] ??= <String, dynamic>{};
    _data['downloaded_files'][fileId.toString()] = filePath;
    await _save();
  }

  Future<void> removeDownloadedFile(int fileId) async {
    if (_data['downloaded_files'] != null) {
      _data['downloaded_files'].remove(fileId.toString());
      await _save();
    }
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

class DownloadedOnlyNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(storageServiceProvider).isDownloadedOnly();
  }

  Future<void> toggle(bool value) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setDownloadedOnly(value);
    state = value;
  }
}

final downloadedOnlyProvider = NotifierProvider<DownloadedOnlyNotifier, bool>(DownloadedOnlyNotifier.new);

class IncognitoModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(storageServiceProvider).isIncognitoMode();
  }

  Future<void> toggle(bool value) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setIncognitoMode(value);
    state = value;
  }
}

final incognitoModeProvider = NotifierProvider<IncognitoModeNotifier, bool>(IncognitoModeNotifier.new);

class HistoryLogNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    return ref.watch(storageServiceProvider).getHistoryLog();
  }

  Future<void> addToHistory({
    required String seriesName,
    required int messageId,
    required int episodeIndex,
    required String episodeTitle,
    required int positionInSeconds,
  }) async {
    final storage = ref.read(storageServiceProvider);
    await storage.addToHistoryLog(
      seriesName: seriesName,
      messageId: messageId,
      episodeIndex: episodeIndex,
      episodeTitle: episodeTitle,
      positionInSeconds: positionInSeconds,
    );
    state = storage.getHistoryLog();
  }

  Future<void> clearHistory() async {
    final storage = ref.read(storageServiceProvider);
    await storage.clearHistoryLog();
    state = [];
  }
}

final historyLogProvider = NotifierProvider<HistoryLogNotifier, List<Map<String, dynamic>>>(HistoryLogNotifier.new);


