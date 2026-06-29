import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logger.dart';
import '../core/utils/path_helper.dart';

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

  String? _localFontPath;
  String? get localFontPath => _localFontPath;

  Future<void> init() async {
    final directory = await getAppDirectory();
    final primaryPath = '${directory.path}/user_storage.json';
    final backupPath = '$primaryPath.bak';
    _file = File(primaryPath);
    final backupFile = File(backupPath);
    
    // Extract subtitle font for Android/iOS/Windows platforms to local storage
    try {
      final fontDir = Directory('${directory.path}/fonts');
      if (!await fontDir.exists()) {
        await fontDir.create(recursive: true);
      }
      
      final fontNames = [
        'Roboto-Regular.ttf',
        'Roboto.ttf',
        'Arial.ttf',
        'sans-serif.ttf',
        'DejaVuSans.ttf'
      ];
      
      final byteData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      
      for (final name in fontNames) {
        final fontFile = File('${fontDir.path}/$name');
        if (!await fontFile.exists()) {
          await fontFile.writeAsBytes(bytes);
          Log.i('Font asset copied: $name');
        }
      }
      _localFontPath = File('${fontDir.path}/Roboto-Regular.ttf').path;
    } catch (e, stack) {
      Log.e('Failed to copy subtitle font', e, stack);
    }
    
    bool loaded = false;
    
    if (await _file!.exists()) {
      try {
        final content = await _file!.readAsString();
        _data = json.decode(content);
        loaded = true;
        Log.i('User storage loaded successfully');
      } catch (e) {
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

    // Migrations
    final migratedKey = 'migrated_mediacodec_v3';
    if (_data[migratedKey] != true) {
      final currentMode = _data['hardware_decoder_mode'] as String?;
      if (currentMode == 'mediacodec' || currentMode == null) {
        _data['hardware_decoder_mode'] = 'mediacodec-copy';
      }
      _data[migratedKey] = true;
      await _save();
      Log.i('Migrated hardware_decoder_mode to copy-back mediacodec-copy.');
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
          await _file!.delete(); // Delete target file first to support Windows rename behavior
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

  String getAnimeLayout() {
    return _data['anime_layout_preference'] as String? ?? 'Grid';
  }

  Future<void> setAnimeLayout(String layout) async {
    _data['anime_layout_preference'] = layout;
    await _save();
  }

  String getMoviesLayout() {
    return _data['movies_layout_preference'] as String? ?? 'Grid';
  }

  Future<void> setMoviesLayout(String layout) async {
    _data['movies_layout_preference'] = layout;
    await _save();
  }

  String getWebSeriesLayout() {
    return _data['web_series_layout_preference'] as String? ?? 'Grid';
  }

  Future<void> setWebSeriesLayout(String layout) async {
    _data['web_series_layout_preference'] = layout;
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

  // --- Active (Incomplete) Downloads Queue ---

  Map<int, String> getActiveDownloads() {
    if (_data['active_downloads'] == null) return {};
    final Map<String, dynamic> rawMap = Map<String, dynamic>.from(_data['active_downloads']);
    return rawMap.map((key, value) => MapEntry(int.parse(key), value as String));
  }

  List<int> getActiveDownloadsOrder() {
    if (_data['active_downloads_order'] == null) return [];
    return List<int>.from(_data['active_downloads_order']);
  }

  Future<void> setActiveDownloadsOrder(List<int> order) async {
    _data['active_downloads_order'] = order;
    await _save();
  }

  Future<void> addActiveDownload(int fileId, String title) async {
    _data['active_downloads'] ??= <String, dynamic>{};
    _data['active_downloads'][fileId.toString()] = title;
    
    _data['active_downloads_order'] ??= <dynamic>[];
    final order = List<int>.from(_data['active_downloads_order']);
    if (!order.contains(fileId)) {
      order.add(fileId);
      _data['active_downloads_order'] = order;
    }
    
    await _save();
  }

  Future<void> removeActiveDownload(int fileId) async {
    if (_data['active_downloads'] != null) {
      _data['active_downloads'].remove(fileId.toString());
    }
    
    if (_data['active_downloads_order'] != null) {
      final order = List<int>.from(_data['active_downloads_order']);
      order.remove(fileId);
      _data['active_downloads_order'] = order;
    }
    
    await _save();
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

  // --- Aspect Ratio Preferences ---

  bool getRememberAspectRatio() {
    return _data['remember_ratio'] as bool? ?? false;
  }

  Future<void> setRememberAspectRatio(bool value) async {
    _data['remember_ratio'] = value;
    await _save();
  }

  bool getTapToSwitchAspectRatio() {
    return _data['tap_to_switch_ratio'] as bool? ?? false;
  }

  Future<void> setTapToSwitchAspectRatio(bool value) async {
    _data['tap_to_switch_ratio'] = value;
    await _save();
  }

  String getSavedAspectRatio() {
    return _data['saved_aspect_ratio'] as String? ?? 'fit';
  }

  Future<void> setSavedAspectRatio(String value) async {
    _data['saved_aspect_ratio'] = value;
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

  // --- Preferred Tracks Memory ---

  String? getPreferredSubtitleTrack() {
    return _data['preferred_subtitle_track'] as String?;
  }

  Future<void> setPreferredSubtitleTrack(String? value) async {
    _data['preferred_subtitle_track'] = value;
    await _save();
  }

  String? getPreferredAudioTrack() {
    return _data['preferred_audio_track'] as String?;
  }

  Future<void> setPreferredAudioTrack(String? value) async {
    _data['preferred_audio_track'] = value;
    await _save();
  }

  String? getPreferredSubtitleTrackForAudioLanguage(String audioLang) {
    _data['sub_pref_by_audio_lang'] ??= <String, dynamic>{};
    return _data['sub_pref_by_audio_lang'][audioLang] as String?;
  }

  Future<void> setPreferredSubtitleTrackForAudioLanguage(String audioLang, String? value) async {
    _data['sub_pref_by_audio_lang'] ??= <String, dynamic>{};
    if (value == null) {
      _data['sub_pref_by_audio_lang'].remove(audioLang);
    } else {
      _data['sub_pref_by_audio_lang'][audioLang] = value;
    }
    await _save();
  }



  // --- MAL ID Cache ---

  int? getMalIdForSeries(String seriesName) {
    _data['mal_id_cache'] ??= <String, dynamic>{};
    return _data['mal_id_cache'][seriesName] as int?;
  }

  Future<void> setMalIdForSeries(String seriesName, int malId) async {
    _data['mal_id_cache'] ??= <String, dynamic>{};
    _data['mal_id_cache'][seriesName] = malId;
    await _save();
  }

  // --- Season Release Year Cache ---

  int? getSeasonReleaseYear(String fullTitle) {
    _data['season_release_years'] ??= <String, dynamic>{};
    return _data['season_release_years'][fullTitle] as int?;
  }

  Future<void> setSeasonReleaseYear(String fullTitle, int year) async {
    _data['season_release_years'] ??= <String, dynamic>{};
    _data['season_release_years'][fullTitle] = year;
    await _save();
  }

  // --- AniList Cache & Token ---

  int? getAnilistIdForSeries(String seriesName) {
    _data['anilist_id_cache'] ??= <String, dynamic>{};
    return _data['anilist_id_cache'][seriesName] as int?;
  }

  Future<void> setAnilistIdForSeries(String seriesName, int anilistId) async {
    _data['anilist_id_cache'] ??= <String, dynamic>{};
    _data['anilist_id_cache'][seriesName] = anilistId;
    await _save();
  }

  String? getAnilistToken() {
    return _data['anilist_token'] as String?;
  }

  Future<void> setAnilistToken(String? value) async {
    _data['anilist_token'] = value;
    await _save();
  }

  // --- MAL Token ---

  String? getMalToken() {
    return _data['mal_token'] as String?;
  }

  Future<void> setMalToken(String? value) async {
    _data['mal_token'] = value;
    await _save();
  }

  // --- Trakt Cache & Token ---

  String? getTraktIdForSeries(String seriesName) {
    _data['trakt_id_cache'] ??= <String, dynamic>{};
    return _data['trakt_id_cache'][seriesName] as String?;
  }

  Future<void> setTraktIdForSeries(String seriesName, String traktId) async {
    _data['trakt_id_cache'] ??= <String, dynamic>{};
    _data['trakt_id_cache'][seriesName] = traktId;
    await _save();
  }

  String? getTraktToken() {
    return _data['trakt_token'] as String?;
  }

  Future<void> setTraktToken(String? value) async {
    _data['trakt_token'] = value;
    await _save();
  }

  // --- Subtitle Preferences ---

  double getSubtitleFontSize() {
    return (_data['subtitle_font_size'] as num?)?.toDouble() ?? 45.0;
  }

  Future<void> setSubtitleFontSize(double value) async {
    _data['subtitle_font_size'] = value;
    await _save();
  }

  String getSubtitleColor() {
    return _data['subtitle_color'] as String? ?? '#FFFFFF';
  }

  Future<void> setSubtitleColor(String value) async {
    _data['subtitle_color'] = value;
    await _save();
  }

  double getSubtitleDelay() {
    return (_data['subtitle_delay'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> setSubtitleDelay(double value) async {
    _data['subtitle_delay'] = value;
    await _save();
  }

  String getSubtitleFont() {
    return _data['subtitle_font'] as String? ?? 'Roboto';
  }

  Future<void> setSubtitleFont(String value) async {
    _data['subtitle_font'] = value;
    await _save();
  }

  bool getSubtitleSystemFonts() {
    return _data['subtitle_system_fonts'] as bool? ?? true;
  }

  Future<void> setSubtitleSystemFonts(bool value) async {
    _data['subtitle_system_fonts'] = value;
    await _save();
  }

  String getSubtitleRenderer() {
    return getVideoSettings()['subtitleRendererMode'] as String? ?? _data['subtitle_renderer'] as String? ?? 'flutter';
  }

  Future<void> setSubtitleRenderer(String value) async {
    _data['subtitle_renderer'] = value;
    await _save();
  }

  bool getHardwareAcceleration() {
    return _data['hardware_acceleration'] as bool? ?? true;
  }

  Future<void> setHardwareAcceleration(bool value) async {
    _data['hardware_acceleration'] = value;
    await _save();
  }

  String getHardwareDecoderMode() {
    final mode = _data['hardware_decoder_mode'] as String?;
    if (mode != null) return mode;
    // Fallback/migration from old boolean
    final oldAcc = getHardwareAcceleration();
    if (Platform.isWindows) {
      return oldAcc ? 'd3d11va' : 'no';
    }
    return oldAcc ? 'mediacodec-copy' : 'no';
  }

  Future<void> setHardwareDecoderMode(String value) async {
    _data['hardware_decoder_mode'] = value;
    // Keep backward compatibility boolean in sync
    _data['hardware_acceleration'] = (value != 'no');
    await _save();
  }

  // --- Audio Boost Preferences ---

  bool getVolumeBoostEnabled() {
    return _data['volume_boost_enabled'] as bool? ?? false;
  }

  Future<void> setVolumeBoostEnabled(bool value) async {
    _data['volume_boost_enabled'] = value;
    await _save();
  }

  // --- Network Profiles ---

  String getNetworkProfileMode() {
    return _data['network_profile_mode'] as String? ?? 'auto';
  }

  Future<void> setNetworkProfileMode(String value) async {
    _data['network_profile_mode'] = value;
    await _save();
  }

  // --- Series Files Mapping (for Cache Manager) ---

  Map<String, String> getSeriesFiles() {
    if (_data['series_files'] == null) return {};
    return Map<String, String>.from(_data['series_files']);
  }

  Future<void> associateFileWithSeries(String seriesName, int fileId) async {
    _data['series_files'] ??= <String, dynamic>{};
    _data['series_files'][fileId.toString()] = seriesName;
    await _save();
  }

  Future<void> removeSeriesFile(int fileId) async {
    if (_data['series_files'] != null) {
      _data['series_files'].remove(fileId.toString());
      await _save();
    }
  }

  Future<void> clearMetadataCache() async {
    _data['mal_id_cache'] = <String, dynamic>{};
    _data['season_release_years'] = <String, dynamic>{};
    _data['anilist_id_cache'] = <String, dynamic>{};
    _data['trakt_id_cache'] = <String, dynamic>{};
    await _save();
  }

  Future<void> unlinkTrackerForSeries(String seriesName, String trackerType) async {
    final cacheKey = trackerType == 'anilist'
        ? 'anilist_id_cache'
        : trackerType == 'mal'
            ? 'mal_id_cache'
            : 'trakt_id_cache';
    if (_data[cacheKey] != null) {
      (_data[cacheKey] as Map).remove(seriesName);
      await _save();
    }
  }

  List<String> getRecentNetworkStreams() {
    if (_data['recent_network_streams'] == null) return [];
    return List<String>.from(_data['recent_network_streams']);
  }

  Future<void> addRecentNetworkStream(String url) async {
    _data['recent_network_streams'] ??= <dynamic>[];
    final List<String> list = List<String>.from(_data['recent_network_streams']);
    list.remove(url);
    list.insert(0, url);
    if (list.length > 20) {
      list.removeLast();
    }
    _data['recent_network_streams'] = list;
    await _save();
  }

  Future<void> removeRecentNetworkStream(String url) async {
    if (_data['recent_network_streams'] != null) {
      final List<String> list = List<String>.from(_data['recent_network_streams']);
      list.remove(url);
      _data['recent_network_streams'] = list;
      await _save();
    }
  }

  List<String> getSearchHistory(String category) {
    if (_data['search_history'] == null) return [];
    final map = _data['search_history'] as Map<String, dynamic>;
    if (map[category] == null) return [];
    return List<String>.from(map[category] as List);
  }

  Future<void> saveSearchHistory(String category, List<String> list) async {
    _data['search_history'] ??= <String, dynamic>{};
    final map = _data['search_history'] as Map<String, dynamic>;
    final limited = list.take(10).toList();
    map[category] = limited;
    await _save();
  }

  String exportBackupData() {
    return json.encode(_data);
  }

  Future<void> importBackupData(Map<String, dynamic> data) async {
    _data = Map<String, dynamic>.from(data);
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

class RecentNetworkStreamsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return ref.watch(storageServiceProvider).getRecentNetworkStreams();
  }

  Future<void> addStream(String url) async {
    final storage = ref.read(storageServiceProvider);
    await storage.addRecentNetworkStream(url);
    state = storage.getRecentNetworkStreams();
  }

  Future<void> removeStream(String url) async {
    final storage = ref.read(storageServiceProvider);
    await storage.removeRecentNetworkStream(url);
    state = storage.getRecentNetworkStreams();
  }
}

final recentNetworkStreamsProvider = NotifierProvider<RecentNetworkStreamsNotifier, List<String>>(RecentNetworkStreamsNotifier.new);

class SearchHistoryNotifier extends Notifier<List<String>> {
  final String arg;
  SearchHistoryNotifier(this.arg);

  @override
  List<String> build() {
    return ref.watch(storageServiceProvider).getSearchHistory(arg);
  }

  Future<void> addQuery(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final storage = ref.read(storageServiceProvider);
    final current = storage.getSearchHistory(arg);
    final updated = List<String>.from(current);
    updated.remove(cleanQuery);
    updated.insert(0, cleanQuery);

    await storage.saveSearchHistory(arg, updated);
    state = storage.getSearchHistory(arg);
  }

  Future<void> removeQuery(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final storage = ref.read(storageServiceProvider);
    final current = storage.getSearchHistory(arg);
    final updated = List<String>.from(current)..remove(cleanQuery);

    await storage.saveSearchHistory(arg, updated);
    state = storage.getSearchHistory(arg);
  }

  Future<void> clearHistory() async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveSearchHistory(arg, []);
    state = [];
  }
}

final searchHistoryProvider = NotifierProvider.family<SearchHistoryNotifier, List<String>, String>(SearchHistoryNotifier.new);


