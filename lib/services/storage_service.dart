import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synchronized/synchronized.dart';
import '../core/logger.dart';
import '../core/utils/path_helper.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  File? _file;
  final Lock _lock = Lock();
  final _secureStorage = const FlutterSecureStorage();
  String? _anilistTokenCache;
  String? _malTokenCache;
  String? _traktTokenCache;
  String? _openSubtitlesApiKeyCache;
  String? _subdlApiKeyCache;

  Map<String, dynamic> _data = {
    'history': <String, int>{}, // messageId (String) -> position in seconds
    'favorites': <String>[], // coreName
    'last_watched':
        null, // { 'seriesName': String, 'messageId': int, 'episodeIndex': int }
  };

  String? _localFontPath;
  String? get localFontPath => _localFontPath;

  bool _isInitialized = false;
  
  void _checkInit() {
    if (!_isInitialized) {
      Log.e('CRITICAL: StorageService accessed before init() completed!');
      // throw StateError('StorageService not initialized'); // Too risky to throw right now without knowing app init flow, but logging it as critical.
    }
  }

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
        'DejaVuSans.ttf',
      ];

      _localFontPath = File('${fontDir.path}/Roboto-Regular.ttf').path;

      bool needsWrite = false;
      for (final name in fontNames) {
        if (!await File('${fontDir.path}/$name').exists()) {
          needsWrite = true;
          break;
        }
      }

      if (needsWrite) {
        final byteData = await rootBundle.load(
          'assets/fonts/Roboto-Regular.ttf',
        );
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
      }
    } catch (e, stack) {
      Log.e('Failed to copy subtitle font', e, stack);
    }

    bool loaded = false;

    if (await _file!.exists()) {
      try {
        final content = await _file!.readAsString();
        final decoded = json.decode(content);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'Storage file does not contain a JSON object',
          );
        }
        _data = decoded;
        loaded = true;
        Log.i('User storage loaded successfully');
      } catch (e) {
        Log.w('Primary user storage corrupted, trying backup: $e');
      }
    }

    if (!loaded && await backupFile.exists()) {
      try {
        final content = await backupFile.readAsString();
        final decoded = json.decode(content);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'Backup storage file does not contain a JSON object',
          );
        }
        _data = decoded;
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
    // Secure Storage Token Migration
    _anilistTokenCache = await _secureStorage.read(key: 'anilist_token');
    _malTokenCache = await _secureStorage.read(key: 'mal_token');
    _traktTokenCache = await _secureStorage.read(key: 'trakt_token');
    _openSubtitlesApiKeyCache = await _secureStorage.read(key: 'os_api_key');
    _subdlApiKeyCache = await _secureStorage.read(key: 'subdl_api_key');

    bool requiresMigrationSave = false;
    if (_data.containsKey('anilist_token')) {
      _anilistTokenCache = _data['anilist_token'] as String?;
      if (_anilistTokenCache != null) {
        await _secureStorage.write(
          key: 'anilist_token',
          value: _anilistTokenCache,
        );
      }
      _data.remove('anilist_token');
      requiresMigrationSave = true;
    }
    if (_data.containsKey('mal_token')) {
      _malTokenCache = _data['mal_token'] as String?;
      if (_malTokenCache != null) {
        await _secureStorage.write(key: 'mal_token', value: _malTokenCache);
      }
      _data.remove('mal_token');
      requiresMigrationSave = true;
    }
    if (_data.containsKey('trakt_token')) {
      _traktTokenCache = _data['trakt_token'] as String?;
      if (_traktTokenCache != null) {
        await _secureStorage.write(key: 'trakt_token', value: _traktTokenCache);
      }
      _data.remove('trakt_token');
      requiresMigrationSave = true;
    }

    if (_data.containsKey('video_settings')) {
      final vs = _data['video_settings'] as Map<String, dynamic>;
      if (vs.containsKey('openSubtitlesApiKey')) {
        _openSubtitlesApiKeyCache = vs['openSubtitlesApiKey'] as String?;
        if (_openSubtitlesApiKeyCache != null) {
          await _secureStorage.write(key: 'os_api_key', value: _openSubtitlesApiKeyCache);
        }
        vs.remove('openSubtitlesApiKey');
        requiresMigrationSave = true;
      }
      if (vs.containsKey('subdlApiKey')) {
        _subdlApiKeyCache = vs['subdlApiKey'] as String?;
        if (_subdlApiKeyCache != null) {
          await _secureStorage.write(key: 'subdl_api_key', value: _subdlApiKeyCache);
        }
        vs.remove('subdlApiKey');
        requiresMigrationSave = true;
      }
    }

    if (requiresMigrationSave) {
      await _save();
      Log.i('Migrated OAuth tokens to secure storage.');
    }
    
    _isInitialized = true;
  }

  Timer? _debounceTimer;
  bool _dirty = false;
  Completer<void>? _saveCompleter;

  Future<void> _save() async {
    _dirty = true;
    _debounceTimer?.cancel();
    _saveCompleter ??= Completer<void>();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        await _lock.synchronized(() async {
          if (_dirty) {
            await _executeSave();
            _dirty = false;
          }
        });
        final c = _saveCompleter;
        _saveCompleter = null;
        if (c != null && !c.isCompleted) {
          c.complete();
        }
      } catch (e, st) {
        final c = _saveCompleter;
        _saveCompleter = null;
        if (c != null && !c.isCompleted) {
          c.completeError(e, st);
        }
      }
    });
    return _saveCompleter!.future;
  }

  Future<void> flush() async {
    await _lock.synchronized(() async {
      if (_dirty) {
        await _executeSave();
        _dirty = false;
      }
    });
  }

  Future<void> _executeSave() async {
    if (_file != null) {
      try {
        final snapshot = json.decode(json.encode(_data)) as Map<String, dynamic>;
        final tmpFile = File('${_file!.path}.tmp');
        final backupFile = File('${_file!.path}.bak');
        final content = json.encode(snapshot);

        await tmpFile.writeAsString(content);

        final tempContent = await tmpFile.readAsString();
        json.decode(tempContent); // Verify valid JSON

        if (await _file!.exists()) {
          if (await backupFile.exists()) {
            await backupFile.delete();
          }
          await _file!.copy(backupFile.path);
        }

        try {
          await tmpFile.rename(_file!.path);
        } on PathExistsException {
          await tmpFile.copy(_file!.path);
          try { await tmpFile.delete(); } catch (_) {}
        } catch (_) {
          await tmpFile.copy(_file!.path);
          try { await tmpFile.delete(); } catch (_) {}
        }
      } catch (e, stackTrace) {
        Log.e('Failed to save user storage atomically', e, stackTrace);
      }
    }
  }

  // --- Settings Toggles ---

  bool isIncognitoMode() {
    _checkInit();
    return _data['incognito_mode'] ?? false;
  }

  Future<void> setIncognitoMode(bool value) async {
    _data['incognito_mode'] = value;
    await _save();
  }

  bool isDownloadedOnly() {
    _checkInit();
    return _data['downloaded_only'] ?? false;
  }

  Future<void> setDownloadedOnly(bool value) async {
    _data['downloaded_only'] = value;
    await _save();
  }

  double getPlaybackSpeed() {
    _checkInit();
    return (_data['playback_speed'] as num?)?.toDouble() ?? 1.0;
  }

  Future<void> setPlaybackSpeed(double value) async {
    _data['playback_speed'] = value;
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
    final history = _data['history'];
    if (history is Map) {
      final val = history[messageId.toString()];
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
    }
    return 0;
  }

  Future<void> setLastWatched(
    String seriesName,
    int messageId,
    int episodeIndex,
  ) async {
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

    final logsData = _data['history_log'];
    final List<dynamic> logs = logsData is List ? List.from(logsData) : [];

    // Remove if already exists for this messageId to avoid duplicates in the timeline
    logs.removeWhere((item) => item is Map && item['messageId'] == messageId);

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
    final logs = _data['history_log'];
    if (logs is! List) return [];
    return logs.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> removeFromHistoryLog(int messageId) async {
    final logsData = _data['history_log'];
    if (logsData is! List) return;
    final List<dynamic> logs = List.from(logsData);
    logs.removeWhere((item) => item is Map && item['messageId'] == messageId);
    _data['history_log'] = logs;
    await _save();
  }

  Future<void> clearHistoryLog() async {
    _data['history_log'] = [];
    _data['history'] = {};
    _data['last_watched'] = null;
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
    final favs = _data['favorites'];
    if (favs is! List) return [];
    return favs.whereType<String>().toList();
  }

  bool isFavorite(String coreName) {
    return getFavorites().contains(coreName);
  }

  Future<void> toggleFavorite(String coreName) async {
    final favsData = _data['favorites'];
    List<String> favs = favsData is List ? favsData.whereType<String>().toList() : [];

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
    final vs = _data['video_settings'];
    if (vs is! Map) return {};
    return Map<String, dynamic>.from(vs);
  }

  Future<void> updateVideoSettings(Map<String, dynamic> settings) async {
    _data['video_settings'] = settings;
    await _save();
  }

  Future<void> updateVideoSettingsBatch(Map<String, dynamic> settings, String animeLayout, String moviesLayout, String webSeriesLayout) async {
    _data['video_settings'] = settings;
    _data['anime_layout_preference'] = animeLayout;
    _data['movies_layout_preference'] = moviesLayout;
    _data['web_series_layout_preference'] = webSeriesLayout;
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
    final df = _data['downloaded_files'];
    if (df is! Map) return {};
    final result = <int, String>{};
    for (final entry in df.entries) {
      final parsedKey = int.tryParse(entry.key.toString());
      if (parsedKey != null && entry.value is String) {
        result[parsedKey] = entry.value as String;
      }
    }
    return result;
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
    final ad = _data['active_downloads'];
    if (ad is! Map) return {};
    final result = <int, String>{};
    for (final entry in ad.entries) {
      final parsedKey = int.tryParse(entry.key.toString());
      if (parsedKey != null && entry.value is String) {
        result[parsedKey] = entry.value as String;
      }
    }
    return result;
  }

  List<int> getActiveDownloadsOrder() {
    final ado = _data['active_downloads_order'];
    if (ado is! List) return [];
    return ado.whereType<int>().toList();
  }

  Future<void> setActiveDownloadsOrder(List<int> order) async {
    _data['active_downloads_order'] = order;
    await _save();
  }

  Future<void> addActiveDownload(int fileId, String title) async {
    _data['active_downloads'] ??= <String, dynamic>{};
    _data['active_downloads'][fileId.toString()] = title;

    final ado = _data['active_downloads_order'];
    final order = ado is List ? ado.whereType<int>().toList() : <int>[];
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

    final ado = _data['active_downloads_order'];
    if (ado is List) {
      final order = ado.whereType<int>().toList();
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

  Future<void> setPreferredSubtitleTrackForAudioLanguage(
    String audioLang,
    String? value,
  ) async {
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
    return _anilistTokenCache;
  }

  Future<void> setAnilistToken(String? value) async {
    _anilistTokenCache = value;
    if (value == null) {
      await _secureStorage.delete(key: 'anilist_token');
    } else {
      await _secureStorage.write(key: 'anilist_token', value: value);
    }
  }

  // --- MAL Token ---

  String? getMalToken() {
    return _malTokenCache;
  }

  Future<void> setMalToken(String? value) async {
    _malTokenCache = value;
    if (value == null) {
      await _secureStorage.delete(key: 'mal_token');
    } else {
      await _secureStorage.write(key: 'mal_token', value: value);
    }
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
    return _traktTokenCache;
  }

  Future<void> setTraktToken(String? value) async {
    _traktTokenCache = value;
    if (value == null) {
      await _secureStorage.delete(key: 'trakt_token');
    } else {
      await _secureStorage.write(key: 'trakt_token', value: value);
    }
  }

  String getOpenSubtitlesApiKey() {
    return _openSubtitlesApiKeyCache ?? '';
  }

  Future<void> setOpenSubtitlesApiKey(String? value) async {
    _openSubtitlesApiKeyCache = value;
    if (value == null || value.isEmpty) {
      await _secureStorage.delete(key: 'os_api_key');
    } else {
      await _secureStorage.write(key: 'os_api_key', value: value);
    }
  }

  String getSubdlApiKey() {
    return _subdlApiKeyCache ?? '';
  }

  Future<void> setSubdlApiKey(String? value) async {
    _subdlApiKeyCache = value;
    if (value == null || value.isEmpty) {
      await _secureStorage.delete(key: 'subdl_api_key');
    } else {
      await _secureStorage.write(key: 'subdl_api_key', value: value);
    }
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
    return getVideoSettings()['subtitleRendererMode'] as String? ??
        _data['subtitle_renderer'] as String? ??
        'flutter';
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
      return oldAcc ? 'd3d11va-copy' : 'no';
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
    final sf = _data['series_files'];
    if (sf is! Map) return {};
    final result = <String, String>{};
    for (final entry in sf.entries) {
      if (entry.value is String) {
        result[entry.key.toString()] = entry.value as String;
      }
    }
    return result;
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

  Future<void> unlinkTrackerForSeries(
    String seriesName,
    String trackerType,
  ) async {
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
    final rns = _data['recent_network_streams'];
    if (rns is! List) return [];
    return rns.whereType<String>().toList();
  }

  Future<void> addRecentNetworkStream(String url) async {
    final rns = _data['recent_network_streams'];
    final List<String> list = rns is List ? rns.whereType<String>().toList() : [];
    list.remove(url);
    list.insert(0, url);
    if (list.length > 20) {
      list.removeLast();
    }
    _data['recent_network_streams'] = list;
    await _save();
  }

  Future<void> removeRecentNetworkStream(String url) async {
    final rns = _data['recent_network_streams'];
    if (rns is List) {
      final List<String> list = rns.whereType<String>().toList();
      list.remove(url);
      _data['recent_network_streams'] = list;
      await _save();
    }
  }

  List<String> getSearchHistory(String category) {
    final sh = _data['search_history'];
    if (sh is! Map) return [];
    final list = sh[category];
    if (list is! List) return [];
    return list.whereType<String>().toList();
  }

  Future<void> saveSearchHistory(String category, List<String> list) async {
    final sh = _data['search_history'];
    final map = sh is Map ? Map<String, dynamic>.from(sh) : <String, dynamic>{};
    final limited = list.take(10).toList();
    map[category] = limited;
    _data['search_history'] = map;
    await _save();
  }

  String exportBackupData() {
    return json.encode(_data);
  }

  Future<void> importBackupData(Map<String, dynamic> data) async {
    await _lock.synchronized(() async {
      try {
        final deepCopy = json.decode(json.encode(data)) as Map<String, dynamic>;
        if (deepCopy['history'] is! Map) deepCopy['history'] = {};
        if (deepCopy['favorites'] is! List) deepCopy['favorites'] = [];

        // Re-run secure-storage migration for token fields in imported backup
        for (final tokenKey in ['anilist_token', 'mal_token', 'trakt_token']) {
          if (deepCopy.containsKey(tokenKey)) {
            final tokenValue = deepCopy[tokenKey] as String?;
            if (tokenValue != null && tokenValue.isNotEmpty) {
              await _secureStorage.write(key: tokenKey, value: tokenValue);
            }
            deepCopy.remove(tokenKey);
          }
        }

        _data = deepCopy;
        _dirty = true;
        await _executeSave();
        _dirty = false;
      } catch (e, stack) {
        Log.e('Failed to import backup data', e, stack);
      }
    });
  }

  Map<String, int> getScreenTimeDailyLogs() {
    if (_data['screen_time_daily_logs'] == null) return <String, int>{};
    final Map<String, dynamic> rawMap = _data['screen_time_daily_logs'];
    return rawMap.map((key, value) => MapEntry(key, value as int));
  }

  Future<void> incrementScreenTime(int seconds) async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    _data['screen_time_daily_logs'] ??= <String, dynamic>{};
    final Map<String, dynamic> logs = _data['screen_time_daily_logs'];
    final current = logs[todayStr] as int? ?? 0;
    logs[todayStr] = current + seconds;
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

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<String>>(
  FavoritesNotifier.new,
);

class LastWatchedNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() {
    return ref.watch(storageServiceProvider).getLastWatched();
  }

  void updateLastWatched(String seriesName, int messageId, int episodeIndex) {
    ref
        .read(storageServiceProvider)
        .setLastWatched(seriesName, messageId, episodeIndex);
    state = {
      'seriesName': seriesName,
      'messageId': messageId,
      'episodeIndex': episodeIndex,
    };
  }
}

final lastWatchedProvider =
    NotifierProvider<LastWatchedNotifier, Map<String, dynamic>?>(
      LastWatchedNotifier.new,
    );

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

final downloadedOnlyProvider = NotifierProvider<DownloadedOnlyNotifier, bool>(
  DownloadedOnlyNotifier.new,
);

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

final incognitoModeProvider = NotifierProvider<IncognitoModeNotifier, bool>(
  IncognitoModeNotifier.new,
);

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

  Future<void> removeFromHistory(int messageId) async {
    final storage = ref.read(storageServiceProvider);
    await storage.removeFromHistoryLog(messageId);
    state = storage.getHistoryLog();
  }

  Future<void> clearHistory() async {
    final storage = ref.read(storageServiceProvider);
    await storage.clearHistoryLog();
    state = [];
  }
}

final historyLogProvider =
    NotifierProvider<HistoryLogNotifier, List<Map<String, dynamic>>>(
      HistoryLogNotifier.new,
    );

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

final recentNetworkStreamsProvider =
    NotifierProvider<RecentNetworkStreamsNotifier, List<String>>(
      RecentNetworkStreamsNotifier.new,
    );

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

final searchHistoryProvider =
    NotifierProvider.family<SearchHistoryNotifier, List<String>, String>(
      SearchHistoryNotifier.new,
    );

