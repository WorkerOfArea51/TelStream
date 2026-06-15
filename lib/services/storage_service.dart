import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../core/logger.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  File? _file;
  Future? _writeChain;
  Map<String, dynamic> _data = {
    'history': <String, int>{}, // messageId (String) -> position in seconds
    'favorites': <String>[], // coreName
    'last_watched': null, // { 'seriesName': String, 'messageId': int, 'episodeIndex': int }
  };

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    final primaryPath = '${directory.path}/user_storage.json';
    final backupPath = '$primaryPath.bak';
    _file = File(primaryPath);
    final backupFile = File(backupPath);
    
    bool loaded = false;
    
    if (await _file!.exists()) {
      try {
        final content = await _file!.readAsString();
        _data = json.decode(content);
        loaded = true;
        Log.i('User storage loaded successfully');
      } catch (e, stackTrace) {
        Log.w('Primary user storage corrupted, trying backup: $e');
      }
    }
    
    if (!loaded && await backupFile.exists()) {
      try {
        final content = await backupFile.readAsString();
        _data = json.decode(content);
        loaded = true;
        Log.i('User storage loaded successfully from backup file');
        // Restore primary from backup
        await backupFile.copy(_file!.path);
      } catch (e, stackTrace) {
        Log.e('Backup user storage also corrupted', e, stackTrace);
      }
    }
    
    if (!loaded) {
      Log.w('No valid user storage found, starting fresh');
      _data = {
        'history': <String, int>{},
        'favorites': <String>[],
        'last_watched': null,
      };
      await _save(); // Initialize file
    }
  }

  Future<void> _save() async {
    final completer = Completer<void>();
    final previous = _writeChain;
    _writeChain = completer.future;
    
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    
    try {
      await _executeSave();
    } finally {
      completer.complete();
    }
  }

  Future<void> _executeSave() async {
    if (_file != null) {
      try {
        final tmpFile = File('${_file!.path}.tmp');
        final backupFile = File('${_file!.path}.bak');
        final content = json.encode(_data);
        
        await tmpFile.writeAsString(content);
        
        final tempContent = await tmpFile.readAsString();
        json.decode(tempContent); // Verify valid JSON
        
        if (await _file!.exists()) {
          if (await backupFile.exists()) {
            await backupFile.delete();
          }
          await _file!.copy(backupFile.path);
        }
        
        await tmpFile.rename(_file!.path);
      } catch (e, stackTrace) {
        Log.e('Failed to save user storage atomically', e, stackTrace);
      }
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
    required int videoFileId,
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
      'videoFileId': videoFileId,
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
    _data['durations'] = {};
    await _save();
  }

  // --- Video Durations ---

  Future<void> saveVideoDuration(int messageId, int durationInSeconds) async {
    if (isIncognitoMode()) return;
    _data['durations'] ??= <String, dynamic>{};
    _data['durations'][messageId.toString()] = durationInSeconds;
    await _save();
  }

  int getVideoDuration(int messageId) {
    if (_data['durations'] == null) return 0;
    return _data['durations'][messageId.toString()] ?? 0;
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

  // --- Theme Selection ---

  String getTheme() {
    return _data['theme'] as String? ?? 'classic';
  }

  Future<void> setTheme(String themeName) async {
    _data['theme'] = themeName;
    await _save();
  }

  String getThemeMode() {
    return _data['theme_mode'] as String? ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    _data['theme_mode'] = mode;
    await _save();
  }

  // --- Version Control / Changelog ---

  String getLastSeenVersion() {
    return _data['last_seen_version'] as String? ?? '';
  }

  Future<void> setLastSeenVersion(String version) async {
    _data['last_seen_version'] = version;
    await _save();
  }

  // --- Screen Brightness Memory ---

  double getBrightness() {
    return (_data['brightness'] as num?)?.toDouble() ?? 0.7;
  }

  Future<void> setBrightness(double value) async {
    _data['brightness'] = value;
    await _save();
  }

  // --- Incremental Channel Sync Checkpoints ---

  int getLastIndexedMessageId(int channelId) {
    _data['last_indexed_message_ids'] ??= <String, dynamic>{};
    return _data['last_indexed_message_ids'][channelId.toString()] ?? 0;
  }

  Future<void> setLastIndexedMessageId(int channelId, int messageId) async {
    _data['last_indexed_message_ids'] ??= <String, dynamic>{};
    _data['last_indexed_message_ids'][channelId.toString()] = messageId;
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
    required int videoFileId,
  }) async {
    final storage = ref.read(storageServiceProvider);
    await storage.addToHistoryLog(
      seriesName: seriesName,
      messageId: messageId,
      episodeIndex: episodeIndex,
      episodeTitle: episodeTitle,
      positionInSeconds: positionInSeconds,
      videoFileId: videoFileId,
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


