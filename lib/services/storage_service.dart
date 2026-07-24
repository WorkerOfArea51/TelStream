import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/path_helper.dart';
import '../core/logger.dart';
import '../core/constants.dart';

import 'storage/json_file_persistence.dart';
import 'storage/watch_history_store.dart';
import 'storage/settings_store.dart';
import 'storage/download_store.dart';
import 'storage/secure_token_store.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  final JsonFilePersistence _persistence = JsonFilePersistence();
  late final WatchHistoryStore watchHistory = WatchHistoryStore(_persistence);
  late final SettingsStore settings = SettingsStore(_persistence);
  late final DownloadStore downloads = DownloadStore(_persistence);
  late final SecureTokenStore secureTokens = SecureTokenStore();

  String? _localFontPath;
  String? get localFontPath => _localFontPath;

  Future<void> init() async {
    await _persistence.init();
    await secureTokens.init();

    // Extract subtitle font
    try {
      final directory = await getAppDirectory();
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
        final byteData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

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
  }

  Future<void> flush() => _persistence.flush();

  // --- Delegate to SettingsStore ---
  String getAppLanguage() => settings.getAppLanguage();
  Future<void> setAppLanguage(String lang) => settings.setAppLanguage(lang);
  bool isIncognitoMode() => settings.isIncognitoMode();
  Future<void> setIncognitoMode(bool value) => settings.setIncognitoMode(value);
  bool isDownloadedOnly() => settings.isDownloadedOnly();
  Future<void> setDownloadedOnly(bool value) => settings.setDownloadedOnly(value);
  String getTheme() => settings.getTheme();
  Future<void> setTheme(String themeName) => settings.setTheme(themeName);
  String getThemeMode() => settings.getThemeMode();
  Future<void> setThemeMode(String mode) => settings.setThemeMode(mode);
  String? getLocale() => settings.getLocale();
  Future<void> setLocale(String localeCode) => settings.setLocale(localeCode);
  String getLastSeenVersion() => settings.getLastSeenVersion();
  Future<void> setLastSeenVersion(String version) => settings.setLastSeenVersion(version);

  // Player Settings
  double getPlaybackSpeed() => settings.getPlaybackSpeed();
  Future<void> setPlaybackSpeed(double value) => settings.setPlaybackSpeed(value);
  double getBrightness() => settings.getBrightness();
  Future<void> setBrightness(double value) => settings.setBrightness(value);
  bool getRememberAspectRatio() => settings.getRememberAspectRatio();
  Future<void> setRememberAspectRatio(bool value) => settings.setRememberAspectRatio(value);
  bool getTapToSwitchAspectRatio() => settings.getTapToSwitchAspectRatio();
  Future<void> setTapToSwitchAspectRatio(bool value) => settings.setTapToSwitchAspectRatio(value);
  String getSavedAspectRatio() => settings.getSavedAspectRatio();
  Future<void> setSavedAspectRatio(String value) => settings.setSavedAspectRatio(value);

  // Subtitles
  double getSubtitleFontSize() => settings.getSubtitleFontSize();
  Future<void> setSubtitleFontSize(double value) => settings.setSubtitleFontSize(value);
  String getSubtitleColor() => settings.getSubtitleColor();
  Future<void> setSubtitleColor(String value) => settings.setSubtitleColor(value);
  double getSubtitleDelay() => settings.getSubtitleDelay();
  Future<void> setSubtitleDelay(double value) => settings.setSubtitleDelay(value);
  String getSubtitleFont() => settings.getSubtitleFont();
  Future<void> setSubtitleFont(String value) => settings.setSubtitleFont(value);
  bool getSubtitleSystemFonts() => settings.getSubtitleSystemFonts();
  Future<void> setSubtitleSystemFonts(bool value) => settings.setSubtitleSystemFonts(value);
  String getSubtitleRenderer() => settings.getSubtitleRenderer();
  Future<void> setSubtitleRenderer(String value) => settings.setSubtitleRenderer(value);
  String? getPreferredSubtitleTrack() => settings.getPreferredSubtitleTrack();
  Future<void> setPreferredSubtitleTrack(String? value) => settings.setPreferredSubtitleTrack(value);
  String? getPreferredAudioTrack() => settings.getPreferredAudioTrack();
  Future<void> setPreferredAudioTrack(String? value) => settings.setPreferredAudioTrack(value);
  String? getPreferredSubtitleTrackForAudioLanguage(String audioLang) => settings.getPreferredSubtitleTrackForAudioLanguage(audioLang);
  Future<void> setPreferredSubtitleTrackForAudioLanguage(String audioLang, String? subTrackName) => settings.setPreferredSubtitleTrackForAudioLanguage(audioLang, subTrackName);

  // Hardware & Network
  bool getHardwareAcceleration() => settings.getHardwareAcceleration();
  Future<void> setHardwareAcceleration(bool value) => settings.setHardwareAcceleration(value);
  String getHardwareDecoderMode() => settings.getHardwareDecoderMode();
  Future<void> setHardwareDecoderMode(String value) => settings.setHardwareDecoderMode(value);
  bool getVolumeBoostEnabled() => settings.getVolumeBoostEnabled();
  Future<void> setVolumeBoostEnabled(bool value) => settings.setVolumeBoostEnabled(value);
  String getNetworkProfileMode() => settings.getNetworkProfileMode();
  Future<void> setNetworkProfileMode(String value) => settings.setNetworkProfileMode(value);

  Map<String, dynamic> getVideoSettings() => settings.getVideoSettings();
  Future<void> updateVideoSettings(Map<String, dynamic> settingsData) => settings.updateVideoSettings(settingsData);
  Future<void> updateVideoSettingsBatch(Map<String, dynamic> settingsData, String animeLayout, String moviesLayout, String webSeriesLayout) => settings.updateVideoSettingsBatch(settingsData, animeLayout, moviesLayout, webSeriesLayout);

  // Layouts
  String getAnimeLayout() => settings.getAnimeLayout();
  Future<void> setAnimeLayout(String layout) => settings.setAnimeLayout(layout);
  String getMoviesLayout() => settings.getMoviesLayout();
  Future<void> setMoviesLayout(String layout) => settings.setMoviesLayout(layout);
  String getWebSeriesLayout() => settings.getWebSeriesLayout();
  Future<void> setWebSeriesLayout(String layout) => settings.setWebSeriesLayout(layout);

  // Caches
  int? getMalIdForSeries(String seriesName) => settings.getMalIdForSeries(seriesName);
  Future<void> setMalIdForSeries(String seriesName, int malId) => settings.setMalIdForSeries(seriesName, malId);
  int? getSeasonReleaseYear(String fullTitle) => settings.getSeasonReleaseYear(fullTitle);
  Future<void> setSeasonReleaseYear(String fullTitle, int year) => settings.setSeasonReleaseYear(fullTitle, year);
  int? getAnilistIdForSeries(String seriesName) => settings.getAnilistIdForSeries(seriesName);
  Future<void> setAnilistIdForSeries(String seriesName, int anilistId) => settings.setAnilistIdForSeries(seriesName, anilistId);
  String? getTraktIdForSeries(String seriesName) => settings.getTraktIdForSeries(seriesName);
  Future<void> setTraktIdForSeries(String seriesName, String traktId) => settings.setTraktIdForSeries(seriesName, traktId);
  Future<void> clearMetadataCache() => settings.clearMetadataCache();
  Map<String, dynamic>? getSeasonMetadataCache(String key) => settings.getSeasonMetadataCache(key);
  Future<void> saveSeasonMetadataCache(String key, Map<String, dynamic> metadata) => settings.saveSeasonMetadataCache(key, metadata);
  Future<void> clearSeasonMetadataCache() => settings.clearSeasonMetadataCache();

  // Favorites & Collections
  List<String> getFavorites() => settings.getFavorites();
  bool isFavorite(String coreName) => settings.isFavorite(coreName);
  Future<void> toggleFavorite(String coreName) => settings.toggleFavorite(coreName);

  // Network Streams
  List<String> getRecentNetworkStreams() => settings.getRecentNetworkStreams();
  Future<void> addRecentNetworkStream(String url) => settings.addRecentNetworkStream(url);
  Future<void> removeRecentNetworkStream(String url) => settings.removeRecentNetworkStream(url);

  // Search History
  List<String> getSearchHistory(String category) => settings.getSearchHistory(category);
  Future<void> saveSearchHistory(String category, List<String> list) => settings.saveSearchHistory(category, list);

  // Screen Time
  Map<String, int> getScreenTimeDailyLogs() => settings.getScreenTimeDailyLogs();
  Future<void> incrementScreenTime(int seconds) => settings.incrementScreenTime(seconds);

  // Series Files
  Map<String, String> getSeriesFiles() => settings.getSeriesFiles();
  Future<void> associateFileWithSeries(String seriesName, int fileId) => settings.associateFileWithSeries(seriesName, fileId);
  Future<void> removeSeriesFile(int fileId) => settings.removeSeriesFile(fileId);

  // User Channels
  List<UserChannel> getUserChannels() {
    final raw = settings.getUserChannelsRaw();
    final result = <UserChannel>[];
    for (final item in raw) {
      try {
        result.add(UserChannel.fromJson(item));
      } catch (_) {}
    }
    return result;
  }
  Future<void> addUserChannel(UserChannel channel) async {
    final channels = getUserChannels();
    if (channels.any((c) => c.channelId == channel.channelId)) return;
    channels.add(channel);
    await settings.setUserChannelsRaw(channels.map((e) => e.toJson()).toList());
  }
  Future<void> removeUserChannel(String id) async {
    final channels = getUserChannels();
    channels.removeWhere((c) => c.id == id);
    await settings.setUserChannelsRaw(channels.map((e) => e.toJson()).toList());
  }
  Future<void> clearUserChannels() async {
    await settings.setUserChannelsRaw([]);
  }
  bool isUserChannel(int channelId) => getUserChannels().any((c) => c.channelId == channelId);

  // --- Delegate to SecureTokenStore ---
  String? getAnilistToken() => secureTokens.getAnilistToken();
  Future<void> setAnilistToken(String? value) => secureTokens.setAnilistToken(value);
  String? getMalToken() => secureTokens.getMalToken();
  Future<void> setMalToken(String? value) => secureTokens.setMalToken(value);
  String? getTraktToken() => secureTokens.getTraktToken();
  Future<void> setTraktToken(String? value) => secureTokens.setTraktToken(value);
  String getOpenSubtitlesApiKey() => secureTokens.getOpenSubtitlesApiKey();
  Future<void> setOpenSubtitlesApiKey(String? value) => secureTokens.setOpenSubtitlesApiKey(value);
  String getSubdlApiKey() => secureTokens.getSubdlApiKey();
  Future<void> setSubdlApiKey(String? value) => secureTokens.setSubdlApiKey(value);

  // --- Delegate to DownloadStore ---
  Map<int, String> getDownloadedFiles() => downloads.getDownloadedFiles();
  Future<void> addDownloadedFile(int fileId, String filePath) => downloads.addDownloadedFile(fileId, filePath);
  Future<void> removeDownloadedFile(int fileId) => downloads.removeDownloadedFile(fileId);
  Map<int, String> getActiveDownloads() => downloads.getActiveDownloads();
  List<int> getActiveDownloadsOrder() => downloads.getActiveDownloadsOrder();
  Future<void> setActiveDownloadsOrder(List<int> order) => downloads.setActiveDownloadsOrder(order);
  Future<void> addActiveDownload(int fileId, String title) => downloads.addActiveDownload(fileId, title);
  Future<void> removeActiveDownload(int fileId) => downloads.removeActiveDownload(fileId);
  String? getCustomDownloadDirectory() => downloads.getCustomDownloadDirectory();
  Future<void> setCustomDownloadDirectory(String? path) => downloads.setCustomDownloadDirectory(path);

  // --- Delegate to WatchHistoryStore ---
  Future<void> saveWatchPosition(int messageId, int positionInSeconds) => watchHistory.saveWatchPosition(messageId, positionInSeconds);
  int getWatchPosition(int messageId) => watchHistory.getWatchPosition(messageId);
  Future<void> setLastWatched(String seriesName, int messageId, int episodeIndex) => watchHistory.setLastWatched(seriesName, messageId, episodeIndex);
  Map<String, dynamic>? getLastWatched() => watchHistory.getLastWatched();
  Future<void> addToHistoryLog({required String seriesName, required int messageId, required int episodeIndex, required String episodeTitle, required int positionInSeconds, required int videoFileId}) => watchHistory.addToHistoryLog(seriesName: seriesName, messageId: messageId, episodeIndex: episodeIndex, episodeTitle: episodeTitle, positionInSeconds: positionInSeconds, videoFileId: videoFileId);
  List<Map<String, dynamic>> getHistoryLog() => watchHistory.getHistoryLog();
  Future<void> removeFromHistoryLog(int messageId) => watchHistory.removeFromHistoryLog(messageId);
  Future<void> clearHistoryLog() => watchHistory.clearHistoryLog();
  Future<void> saveVideoDuration(int messageId, int durationInSeconds) => watchHistory.saveVideoDuration(messageId, durationInSeconds);
  int getVideoDuration(int messageId) => watchHistory.getVideoDuration(messageId);

  // Other remaining helpers that were in StorageService:
  int getLastIndexedMessageId(int channelId) {
    _persistence.data['indexed_message_id_cache'] ??= <String, dynamic>{};
    return _persistence.data['indexed_message_id_cache'][channelId.toString()] as int? ?? 0;
  }
  Future<void> setLastIndexedMessageId(int channelId, int messageId) async {
    _persistence.data['indexed_message_id_cache'] ??= <String, dynamic>{};
    _persistence.data['indexed_message_id_cache'][channelId.toString()] = messageId;
    await _persistence.save();
  }

  Future<void> unlinkTrackerForSeries(String seriesName, String trackerType) async {
    final cacheKey = trackerType == 'anilist' ? 'anilist_id_cache' : trackerType == 'mal' ? 'mal_id_cache' : 'trakt_id_cache';
    if (_persistence.data[cacheKey] != null) {
      (_persistence.data[cacheKey] as Map).remove(seriesName);
      await _persistence.save();
    }
  }

  String exportBackupData() {
    return 'Not implemented';
  }
  Future<void> importBackupData(Map<String, dynamic> data) async {
    // Not implemented
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
