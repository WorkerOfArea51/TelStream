import 'json_file_persistence.dart';
import 'dart:io';

class SettingsStore {
  final JsonFilePersistence _persistence;

  SettingsStore(this._persistence);

  Map<String, dynamic> get data => _persistence.data;

  Future<void> save() => _persistence.save();

  // --- General ---
  
  String getAppLanguage() => data['app_language'] as String? ?? 'en';
  Future<void> setAppLanguage(String lang) async {
    data['app_language'] = lang;
    await save();
  }

  bool isIncognitoMode() => data['incognito'] == true;
  Future<void> setIncognitoMode(bool value) async {
    data['incognito'] = value;
    await save();
  }

  bool isDownloadedOnly() => data['downloaded_only'] == true;
  Future<void> setDownloadedOnly(bool value) async {
    data['downloaded_only'] = value;
    await save();
  }

  String getTheme() => data['theme'] as String? ?? 'classic';
  Future<void> setTheme(String themeName) async {
    data['theme'] = themeName;
    await save();
  }

  String getThemeMode() => data['theme_mode'] as String? ?? 'system';
  Future<void> setThemeMode(String mode) async {
    data['theme_mode'] = mode;
    await save();
  }

  String? getLocale() => data['locale'] as String?;
  Future<void> setLocale(String localeCode) async {
    data['locale'] = localeCode;
    await save();
  }

  String getLastSeenVersion() => data['last_seen_version'] as String? ?? '';
  Future<void> setLastSeenVersion(String version) async {
    data['last_seen_version'] = version;
    await save();
  }

  // --- Player Settings ---
  
  double getPlaybackSpeed() => (data['playback_speed'] as num?)?.toDouble() ?? 1.0;
  Future<void> setPlaybackSpeed(double value) async {
    data['playback_speed'] = value;
    await save();
  }

  double getBrightness() => (data['brightness'] as num?)?.toDouble() ?? -1.0;
  Future<void> setBrightness(double value) async {
    data['brightness'] = value;
    await save();
  }

  bool getRememberAspectRatio() => data['remember_aspect_ratio'] as bool? ?? false;
  Future<void> setRememberAspectRatio(bool value) async {
    data['remember_aspect_ratio'] = value;
    await save();
  }

  bool getTapToSwitchAspectRatio() => data['tap_to_switch_aspect_ratio'] as bool? ?? true;
  Future<void> setTapToSwitchAspectRatio(bool value) async {
    data['tap_to_switch_aspect_ratio'] = value;
    await save();
  }

  String getSavedAspectRatio() => data['saved_aspect_ratio'] as String? ?? 'contain';
  Future<void> setSavedAspectRatio(String value) async {
    data['saved_aspect_ratio'] = value;
    await save();
  }

  // --- Subtitles ---
  
  double getSubtitleFontSize() => (data['subtitle_font_size'] as num?)?.toDouble() ?? 20.0;
  Future<void> setSubtitleFontSize(double value) async {
    data['subtitle_font_size'] = value;
    await save();
  }

  String getSubtitleColor() => data['subtitle_color'] as String? ?? '#FFFFFF';
  Future<void> setSubtitleColor(String value) async {
    data['subtitle_color'] = value;
    await save();
  }

  double getSubtitleDelay() => (data['subtitle_delay'] as num?)?.toDouble() ?? 0.0;
  Future<void> setSubtitleDelay(double value) async {
    data['subtitle_delay'] = value;
    await save();
  }

  String getSubtitleFont() => data['subtitle_font'] as String? ?? 'Roboto';
  Future<void> setSubtitleFont(String value) async {
    data['subtitle_font'] = value;
    await save();
  }

  bool getSubtitleSystemFonts() => data['subtitle_system_fonts'] as bool? ?? true;
  Future<void> setSubtitleSystemFonts(bool value) async {
    data['subtitle_system_fonts'] = value;
    await save();
  }

  String getSubtitleRenderer() {
    return getVideoSettings()['subtitleRendererMode'] as String? ??
        data['subtitle_renderer'] as String? ??
        'flutter';
  }
  Future<void> setSubtitleRenderer(String value) async {
    data['subtitle_renderer'] = value;
    await save();
  }

  String? getPreferredSubtitleTrack() => data['preferred_subtitle_track'] as String?;
  Future<void> setPreferredSubtitleTrack(String? value) async {
    data['preferred_subtitle_track'] = value;
    await save();
  }

  String? getPreferredAudioTrack() => data['preferred_audio_track'] as String?;
  Future<void> setPreferredAudioTrack(String? value) async {
    data['preferred_audio_track'] = value;
    await save();
  }

  String? getPreferredSubtitleTrackForAudioLanguage(String audioLang) {
    data['preferred_sub_for_audio'] ??= <String, dynamic>{};
    return data['preferred_sub_for_audio'][audioLang] as String?;
  }
  Future<void> setPreferredSubtitleTrackForAudioLanguage(String audioLang, String? subTrackName) async {
    data['preferred_sub_for_audio'] ??= <String, dynamic>{};
    if (subTrackName == null) {
      (data['preferred_sub_for_audio'] as Map).remove(audioLang);
    } else {
      data['preferred_sub_for_audio'][audioLang] = subTrackName;
    }
    await save();
  }

  // --- Hardware & Network ---
  
  bool getHardwareAcceleration() => data['hardware_acceleration'] as bool? ?? true;
  Future<void> setHardwareAcceleration(bool value) async {
    data['hardware_acceleration'] = value;
    await save();
  }

  String getHardwareDecoderMode() {
    final mode = data['hardware_decoder_mode'] as String?;
    if (mode != null) return mode;
    final oldAcc = getHardwareAcceleration();
    if (Platform.isWindows) {
      return oldAcc ? 'd3d11va-copy' : 'no';
    }
    return oldAcc ? 'mediacodec-copy' : 'no';
  }
  Future<void> setHardwareDecoderMode(String value) async {
    data['hardware_decoder_mode'] = value;
    await save();
  }

  bool getVolumeBoostEnabled() => data['volume_boost_enabled'] as bool? ?? false;
  Future<void> setVolumeBoostEnabled(bool value) async {
    data['volume_boost_enabled'] = value;
    await save();
  }

  String getNetworkProfileMode() => data['network_profile_mode'] as String? ?? 'balanced';
  Future<void> setNetworkProfileMode(String value) async {
    data['network_profile_mode'] = value;
    await save();
  }

  Map<String, dynamic> getVideoSettings() {
    final vs = data['video_settings'];
    if (vs is! Map) return {};
    return Map<String, dynamic>.from(vs);
  }
  Future<void> updateVideoSettings(Map<String, dynamic> settings) async {
    data['video_settings'] = settings;
    await save();
  }
  Future<void> updateVideoSettingsBatch(Map<String, dynamic> settings, String animeLayout, String moviesLayout, String webSeriesLayout) async {
    data['video_settings'] = settings;
    data['anime_layout'] = animeLayout;
    data['movies_layout'] = moviesLayout;
    data['webseries_layout'] = webSeriesLayout;
    await save();
  }

  // --- Layouts ---
  
  String getAnimeLayout() => data['anime_layout'] as String? ?? 'list';
  Future<void> setAnimeLayout(String layout) async {
    data['anime_layout'] = layout;
    await save();
  }

  String getMoviesLayout() => data['movies_layout'] as String? ?? 'grid';
  Future<void> setMoviesLayout(String layout) async {
    data['movies_layout'] = layout;
    await save();
  }

  String getWebSeriesLayout() => data['webseries_layout'] as String? ?? 'grid';
  Future<void> setWebSeriesLayout(String layout) async {
    data['webseries_layout'] = layout;
    await save();
  }

  // --- Caches ---
  
  void _enforceDiskLruCache(String cacheKey, {int maxEntries = 500}) {
    if (data[cacheKey] == null || data[cacheKey] is! Map) return;
    
    final map = data[cacheKey] as Map<String, dynamic>;
    if (map.length > maxEntries) {
      final keysToRemove = map.keys.take(map.length - maxEntries).toList();
      for (final k in keysToRemove) {
        map.remove(k);
      }
    }
  }

  int? getMalIdForSeries(String seriesName) {
    data['mal_id_cache'] ??= <String, dynamic>{};
    return data['mal_id_cache'][seriesName] as int?;
  }
  Future<void> setMalIdForSeries(String seriesName, int malId) async {
    data['mal_id_cache'] ??= <String, dynamic>{};
    // Ensure LRU behavior by re-inserting
    data['mal_id_cache'].remove(seriesName);
    data['mal_id_cache'][seriesName] = malId;
    _enforceDiskLruCache('mal_id_cache');
    await save();
  }

  int? getSeasonReleaseYear(String fullTitle) {
    data['season_year_cache'] ??= <String, dynamic>{};
    return data['season_year_cache'][fullTitle] as int?;
  }
  Future<void> setSeasonReleaseYear(String fullTitle, int year) async {
    data['season_year_cache'] ??= <String, dynamic>{};
    data['season_year_cache'].remove(fullTitle);
    data['season_year_cache'][fullTitle] = year;
    _enforceDiskLruCache('season_year_cache');
    await save();
  }

  int? getAnilistIdForSeries(String seriesName) {
    data['anilist_id_cache'] ??= <String, dynamic>{};
    return data['anilist_id_cache'][seriesName] as int?;
  }
  Future<void> setAnilistIdForSeries(String seriesName, int anilistId) async {
    data['anilist_id_cache'] ??= <String, dynamic>{};
    data['anilist_id_cache'].remove(seriesName);
    data['anilist_id_cache'][seriesName] = anilistId;
    _enforceDiskLruCache('anilist_id_cache');
    await save();
  }

  String? getTraktIdForSeries(String seriesName) {
    data['trakt_id_cache'] ??= <String, dynamic>{};
    return data['trakt_id_cache'][seriesName] as String?;
  }
  Future<void> setTraktIdForSeries(String seriesName, String traktId) async {
    data['trakt_id_cache'] ??= <String, dynamic>{};
    data['trakt_id_cache'][seriesName] = traktId;
    await save();
  }

  Future<void> clearMetadataCache() async {
    data.remove('season_year_cache');
    data.remove('anilist_id_cache');
    data.remove('mal_id_cache');
    data.remove('trakt_id_cache');
    data.remove('season_metadata_cache');
    await save();
  }


  Map<String, dynamic>? getSeriesMetadataCache(String key) {
    data['series_metadata_cache'] ??= <String, dynamic>{};
    return data['series_metadata_cache'][key] as Map<String, dynamic>?;
  }
  Future<void> saveSeriesMetadataCache(String key, Map<String, dynamic> metadata) async {
    data['series_metadata_cache'] ??= <String, dynamic>{};
    data['series_metadata_cache'][key] = metadata;
    _enforceDiskLruCache('series_metadata_cache');
    await save();
  }

  Map<String, dynamic>? getSeasonMetadataCache(String key) {
    data['season_metadata_cache'] ??= <String, dynamic>{};
    return data['season_metadata_cache'][key] as Map<String, dynamic>?;
  }
  Future<void> saveSeasonMetadataCache(String key, Map<String, dynamic> metadata) async {
    data['season_metadata_cache'] ??= <String, dynamic>{};
    data['season_metadata_cache'][key] = metadata;
    await save();
  }
  Future<void> clearSeasonMetadataCache() async {
    data.remove('season_metadata_cache');
    await save();
  }

  // --- Favorites & Collections ---
  
  List<String> getFavorites() {
    final favs = data['favorites'];
    if (favs is! List) return [];
    return favs.whereType<String>().toList();
  }
  bool isFavorite(String coreName) => getFavorites().contains(coreName);
  Future<void> toggleFavorite(String coreName) async {
    final favsData = data['favorites'];
    List<String> favs = favsData is List ? favsData.whereType<String>().toList() : [];
    if (favs.contains(coreName)) {
      favs.remove(coreName);
    } else {
      favs.add(coreName);
    }
    data['favorites'] = favs;
    await save();
  }

  // --- Network Streams ---

  List<String> getRecentNetworkStreams() {
    final rns = data['recent_network_streams'];
    if (rns is! List) return [];
    return rns.whereType<String>().toList();
  }
  Future<void> addRecentNetworkStream(String url) async {
    final rns = data['recent_network_streams'];
    final List<String> list = rns is List ? rns.whereType<String>().toList() : [];
    list.remove(url);
    list.insert(0, url);
    if (list.length > 20) list.removeLast();
    data['recent_network_streams'] = list;
    await save();
  }
  Future<void> removeRecentNetworkStream(String url) async {
    final rns = data['recent_network_streams'];
    if (rns is List) {
      final List<String> list = rns.whereType<String>().toList();
      list.remove(url);
      data['recent_network_streams'] = list;
      await save();
    }
  }

  // --- Search History ---

  List<String> getSearchHistory(String category) {
    final sh = data['search_history'];
    if (sh is! Map) return [];
    final list = sh[category];
    if (list is! List) return [];
    return list.whereType<String>().toList();
  }
  Future<void> saveSearchHistory(String category, List<String> list) async {
    final sh = data['search_history'];
    final map = sh is Map ? Map<String, dynamic>.from(sh) : <String, dynamic>{};
    final limited = list.take(10).toList();
    map[category] = limited;
    data['search_history'] = map;
    await save();
  }

  // --- Screen Time ---

  Map<String, int> getScreenTimeDailyLogs() {
    if (data['screen_time_daily_logs'] == null) return <String, int>{};
    final Map<String, dynamic> rawMap = data['screen_time_daily_logs'];
    return rawMap.map((key, value) => MapEntry(key, value as int));
  }
  Future<void> incrementScreenTime(int seconds) async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    data['screen_time_daily_logs'] ??= <String, dynamic>{};
    final Map<String, dynamic> logs = data['screen_time_daily_logs'];
    final current = logs[todayStr] as int? ?? 0;
    logs[todayStr] = current + seconds;
    await save();
  }

  // --- Series Files ---

  Map<String, String> getSeriesFiles() {
    final sf = data['series_files'];
    if (sf is! Map) return {};
    final result = <String, String>{};
    for (final entry in sf.entries) {
      if (entry.value is String) result[entry.key.toString()] = entry.value as String;
    }
    return result;
  }
  Future<void> associateFileWithSeries(String seriesName, int fileId) async {
    data['series_files'] ??= <String, dynamic>{};
    data['series_files'][seriesName] = fileId.toString();
    await save();
  }
  Future<void> removeSeriesFile(int fileId) async {
    if (data['series_files'] != null) {
      final map = data['series_files'] as Map;
      map.removeWhere((key, value) => value == fileId.toString());
      await save();
    }
  }

  // --- User Channels ---
  
  List<Map<String, dynamic>> getUserChannelsRaw() {
    final raw = data['user_channels'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  Future<void> setUserChannelsRaw(List<Map<String, dynamic>> channels) async {
    data['user_channels'] = channels;
    await save();
  }
}
