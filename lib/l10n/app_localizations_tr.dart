// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'TelStream';

  @override
  String get settings => 'Settings';

  @override
  String get downloads => 'Downloads';

  @override
  String get downloadsManager => 'Downloads Manager';

  @override
  String get history => 'History';

  @override
  String get historyPlayback => 'History / Playback';

  @override
  String get airingCalendar => 'Airing Calendar';

  @override
  String get globalSearch => 'Global Search';

  @override
  String get networkStream => 'Network Stream';

  @override
  String get openStream => 'Open Stream...';

  @override
  String get more => 'More';

  @override
  String get myChannels => 'My Channels';

  @override
  String get addChannel => 'Add Channel';

  @override
  String get channelName => 'Channel Name';

  @override
  String get telegramLink => 'Telegram Link or @username';

  @override
  String get icon => 'Icon';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get saveAll => 'Save All';

  @override
  String get remove => 'Remove';

  @override
  String get removeChannel => 'Remove Channel?';

  @override
  String removeChannelConfirm(Object name) {
    return 'Are you sure you want to remove \"$name\"?';
  }

  @override
  String get noChannelsAdded => 'No channels added yet';

  @override
  String get noChannelsHint =>
      'Go to More → My Channels to add your own channels';

  @override
  String get addYourFirstChannel => 'Add Channel';

  @override
  String pendingResolution(Object link) {
    return 'Pending: $link';
  }

  @override
  String channelId(Object id) {
    return 'Channel ID: $id';
  }

  @override
  String get storage => 'Storage';

  @override
  String get storageManagement => 'Storage Management';

  @override
  String get storageManagementSubtitle =>
      'Device storage, cache limits, download folder';

  @override
  String get playback => 'Playback';

  @override
  String get videoPlayerPreferences => 'Video Player Preferences';

  @override
  String get videoPlayerSubtitle => 'Gestures, audio, subtitles, and player UI';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get colorTheme => 'Color Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get trackersIntegrations => 'Trackers & Integrations';

  @override
  String get trackerAccounts => 'Tracker Accounts';

  @override
  String get trackerAccountsSubtitle =>
      'MyAnimeList, AniList, and Trakt.tv syncing preferences.';

  @override
  String get diagnosticsBackups => 'Diagnostics & Backups';

  @override
  String get troubleshooting => 'Troubleshooting & Diagnostics';

  @override
  String get troubleshootingSubtitle =>
      'Diagnose hardware decoding and subtitle rendering issues.';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get backupRestoreSubtitle =>
      'Export or import settings and watch history.';

  @override
  String get about => 'About';

  @override
  String get whatsNew => 'What\'s New / Changelog';

  @override
  String get whatsNewSubtitle => 'View release notes for this version';

  @override
  String get logout => 'Logout from TelStream';

  @override
  String get libraryEmpty => 'Your library is empty';

  @override
  String get refreshLibrary => 'Refresh Library';

  @override
  String get search => 'Search';

  @override
  String get searchQuery => 'Search query...';

  @override
  String get searchHint => 'Search today\'s releases...';

  @override
  String get noRecommendations => 'No recommendations available';

  @override
  String downloadAll(Object count) {
    return 'Download All ($count Episodes)';
  }

  @override
  String downloadAllConfirm(Object count) {
    return 'This will download $count episodes. Up to 3 will download simultaneously, the rest will be queued.';
  }

  @override
  String get downloadAllButton => 'Download All';

  @override
  String startedBatchDownload(Object count) {
    return 'Started batch download for $count episodes';
  }

  @override
  String get noDownloadableEpisodes => 'No downloadable episodes found.';

  @override
  String get pauseAll => 'Pause All';

  @override
  String get resumeAll => 'Resume All';

  @override
  String get allDownloadsPaused => 'All downloads paused';

  @override
  String get allDownloadsResumed => 'All downloads resumed';

  @override
  String get wifiOnlyDownloads => 'WiFi Only Downloads';

  @override
  String get wifiOnlySubtitle => 'Pause downloads when on cellular data';

  @override
  String get activeQueue => 'Active / Queue';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get clearSeasonMetadata => 'Clear Season Metadata Cache';

  @override
  String get clearSeasonMetadataSubtitle =>
      'Delete cached season posters, cast, and plot info. App will re-fetch from TMDB on next visit.';

  @override
  String get clearSeasonMetadataConfirm =>
      'This will delete all cached season metadata (posters, cast, plot). The app will re-fetch from TMDB next time you open each season. Your settings and watch history will NOT be affected.';

  @override
  String get clear => 'Clear';

  @override
  String get seasonMetadataCleared => 'Season metadata cache cleared.';

  @override
  String get deleteDownload => 'Delete Download';

  @override
  String deleteDownloadConfirm(Object name) {
    return 'Are you sure you want to delete \"$name\" from your device? This cannot be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get fileDeleted => 'File deleted successfully';

  @override
  String failedToDelete(Object error) {
    return 'Failed to delete file: $error';
  }

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select App Language';

  @override
  String get english => 'English';

  @override
  String get russian => 'Русский';

  @override
  String get autoDownloadFirst => 'Auto-download first';

  @override
  String get noSubtitlesFound => 'No subtitles found for auto-download.';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get playbackSettings => 'Playback Settings';

  @override
  String get audioSettings => 'Audio Settings';

  @override
  String get videoSettings => 'Video Settings';

  @override
  String get connectionError => 'Connection Error';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String error(Object message) {
    return 'Error: $message';
  }

  @override
  String saveError(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String loadError(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String deleteError(Object error) {
    return 'Failed to delete: $error';
  }

  @override
  String uploadError(Object error) {
    return 'Failed to upload: $error';
  }

  @override
  String downloadError(Object error) {
    return 'Failed to download: $error';
  }

  @override
  String searchError(Object error) {
    return 'Failed to search: $error';
  }

  @override
  String updateError(Object error) {
    return 'Failed to update: $error';
  }

  @override
  String restoreError(Object error) {
    return 'Failed to restore: $error';
  }

  @override
  String backupError(Object error) {
    return 'Failed to backup: $error';
  }

  @override
  String get generalError => 'An error occurred. Please try again.';

  @override
  String get networkError => 'Network error. Please check your connection.';

  @override
  String get serverError => 'Server error. Please try again later.';

  @override
  String get notFoundError => 'Not found.';

  @override
  String get accessDeniedError => 'Access denied.';

  @override
  String get invalidURLError => 'Invalid URL.';

  @override
  String get timeoutError => 'Request timed out. Please try again.';

  @override
  String get unknownError => 'An unknown error occurred.';

  @override
  String get noData => 'No data available.';

  @override
  String get noResults => 'No results found.';

  @override
  String get noHistory => 'No history available.';

  @override
  String get noDownloads => 'No downloads available.';

  @override
  String get noFavorites => 'No favorites available.';

  @override
  String get noSettings => 'No settings available.';

  @override
  String get noPermissions => 'No permissions available.';

  @override
  String get noStorage => 'No storage available.';

  @override
  String get noNetwork => 'No network available.';

  @override
  String get noInternet => 'No internet connection.';

  @override
  String get noConnection => 'No connection.';

  @override
  String get noAccess => 'No access.';

  @override
  String get noContent => 'No content available.';

  @override
  String get noEpisodes => 'No episodes available.';

  @override
  String get noSeasons => 'No seasons available.';

  @override
  String get noSeries => 'No series available.';

  @override
  String get noMovies => 'No movies available.';

  @override
  String get noAnime => 'No anime available.';

  @override
  String get noWebSeries => 'No web series available.';

  @override
  String get noChannels => 'No channels available.';

  @override
  String get noSubtitles => 'No subtitles available.';

  @override
  String get noAudio => 'No audio available.';

  @override
  String get noVideo => 'No video available.';

  @override
  String get noImages => 'No images available.';

  @override
  String get noFiles => 'No files available.';

  @override
  String get noDocuments => 'No documents available.';

  @override
  String get noLinks => 'No links available.';

  @override
  String get noBookmarks => 'No bookmarks available.';

  @override
  String get noNotes => 'No notes available.';

  @override
  String get noTags => 'No tags available.';

  @override
  String get noCategories => 'No categories available.';

  @override
  String get noFilters => 'No filters available.';

  @override
  String get noSort => 'No sort available.';

  @override
  String get noView => 'No view available.';

  @override
  String get noLayout => 'No layout available.';

  @override
  String get noTheme => 'No theme available.';

  @override
  String get noColor => 'No color available.';

  @override
  String get noFont => 'No font available.';

  @override
  String get noSize => 'No size available.';

  @override
  String get noPosition => 'No position available.';

  @override
  String get noDuration => 'No duration available.';

  @override
  String get noSpeed => 'No speed available.';

  @override
  String get noVolume => 'No volume available.';

  @override
  String get noBrightness => 'No brightness available.';

  @override
  String get noContrast => 'No contrast available.';

  @override
  String get noSaturation => 'No saturation available.';

  @override
  String get noHue => 'No hue available.';

  @override
  String get noGamma => 'No gamma available.';

  @override
  String get noSharpness => 'No sharpness available.';

  @override
  String get noNoise => 'No noise available.';

  @override
  String get noBlur => 'No blur available.';

  @override
  String get noPixel => 'No pixel available.';

  @override
  String get noFrame => 'No frame available.';

  @override
  String get noField => 'No field available.';

  @override
  String get noValue => 'No value available.';

  @override
  String get noKey => 'No key available.';

  @override
  String get noDataAvailable => 'No data available.';

  @override
  String get noResultsFound => 'No results found.';

  @override
  String get noHistoryAvailable => 'No history available.';

  @override
  String get noDownloadsAvailable => 'No downloads available.';

  @override
  String get noFavoritesAvailable => 'No favorites available.';

  @override
  String get noSettingsAvailable => 'No settings available.';

  @override
  String get noPermissionsAvailable => 'No permissions available.';

  @override
  String get noStorageAvailable => 'No storage available.';

  @override
  String get noNetworkAvailable => 'No network available.';

  @override
  String get noInternetConnection => 'No internet connection.';

  @override
  String get noConnectionAvailable => 'No connection available.';

  @override
  String get noAccessAvailable => 'No access available.';

  @override
  String get noContentAvailable => 'No content available.';

  @override
  String get noEpisodesAvailable => 'No episodes available.';

  @override
  String get noSeasonsAvailable => 'No seasons available.';

  @override
  String get noSeriesAvailable => 'No series available.';

  @override
  String get noMoviesAvailable => 'No movies available.';

  @override
  String get noAnimeAvailable => 'No anime available.';

  @override
  String get noWebSeriesAvailable => 'No web series available.';

  @override
  String get noChannelsAvailable => 'No channels available.';

  @override
  String get noSubtitlesAvailable => 'No subtitles available.';

  @override
  String get noAudioAvailable => 'No audio available.';

  @override
  String get noVideoAvailable => 'No video available.';

  @override
  String get noImagesAvailable => 'No images available.';

  @override
  String get noFilesAvailable => 'No files available.';

  @override
  String get noDocumentsAvailable => 'No documents available.';

  @override
  String get noLinksAvailable => 'No links available.';

  @override
  String get noBookmarksAvailable => 'No bookmarks available.';

  @override
  String get noNotesAvailable => 'No notes available.';

  @override
  String get noTagsAvailable => 'No tags available.';

  @override
  String get noCategoriesAvailable => 'No categories available.';

  @override
  String get noFiltersAvailable => 'No filters available.';

  @override
  String get noSortAvailable => 'No sort available.';

  @override
  String get noViewAvailable => 'No view available.';

  @override
  String get noLayoutAvailable => 'No layout available.';

  @override
  String get noThemeAvailable => 'No theme available.';

  @override
  String get noColorAvailable => 'No color available.';

  @override
  String get noFontAvailable => 'No font available.';

  @override
  String get noSizeAvailable => 'No size available.';

  @override
  String get noPositionAvailable => 'No position available.';

  @override
  String get noDurationAvailable => 'No duration available.';

  @override
  String get noSpeedAvailable => 'No speed available.';

  @override
  String get noVolumeAvailable => 'No volume available.';

  @override
  String get noBrightnessAvailable => 'No brightness available.';

  @override
  String get noContrastAvailable => 'No contrast available.';

  @override
  String get noSaturationAvailable => 'No saturation available.';

  @override
  String get noHueAvailable => 'No hue available.';

  @override
  String get noGammaAvailable => 'No gamma available.';

  @override
  String get noSharpnessAvailable => 'No sharpness available.';

  @override
  String get noNoiseAvailable => 'No noise available.';

  @override
  String get noBlurAvailable => 'No blur available.';

  @override
  String get noPixelAvailable => 'No pixel available.';

  @override
  String get noFrameAvailable => 'No frame available.';

  @override
  String get noFieldAvailable => 'No field available.';

  @override
  String get noValueAvailable => 'No value available.';

  @override
  String get noKeyAvailable => 'No key available.';

  @override
  String get storageSubtitle => 'Device storage, cache limits, download folder';

  @override
  String get chooseLanguage => 'Choose app language';

  @override
  String get trackerSubtitle =>
      'MyAnimeList, AniList, and Trakt.tv syncing preferences.';

  @override
  String get troubleshootingDiagnostics => 'Troubleshooting & Diagnostics';

  @override
  String get backupSubtitle => 'Export or import settings and watch history.';

  @override
  String get whatsNewChangelog => 'What\'s New / Changelog';

  @override
  String get logoutFromTelStream => 'Logout from TelStream';

  @override
  String get sectionStorage => 'Storage';

  @override
  String get sectionPlayback => 'Playback';

  @override
  String get sectionGeneral => 'General';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionIntegrations => 'Integrations';

  @override
  String get sectionAdvanced => 'Advanced';

  @override
  String get sectionAccount => 'Account';

  @override
  String get systemDefault => 'System Default';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get enterCode => 'Enter code';

  @override
  String get smsSent =>
      'We have sent an SMS with an activation code to your phone number.';

  @override
  String get code => 'Code';

  @override
  String get enterActivationCode => 'Enter activation code';

  @override
  String get twoFAPassword => '2FA Password';

  @override
  String get twoFADesc =>
      'Your account is protected by a two-step verification password.';

  @override
  String get password => 'Password';

  @override
  String get searchCountry => 'Search Country';

  @override
  String get storagePermissionRequired =>
      'Storage permission is required to choose a custom downloads folder on this version of Android.';

  @override
  String get downloadFolderUpdated => 'Download folder updated to:';

  @override
  String get failedToSelectDirectory => 'Failed to select directory:';

  @override
  String get advancedCacheManager => 'Advanced Cache Manager';

  @override
  String get advancedCacheManagerSubtitle =>
      'View detailed storage cache breakdown and clear cache per series.';

  @override
  String get cacheSizeLimit => 'Cache Size Limit';

  @override
  String get unlimited => 'Unlimited';

  @override
  String get cacheAutoDeleteTTL => 'Cache Auto-Delete TTL';

  @override
  String get never => 'Never';

  @override
  String get downloadFolder => 'Download Folder';

  @override
  String get chooseCustomFolder => 'Choose Custom Folder';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get cacheSize => 'Cache Size';

  @override
  String get downloadsDirectory => 'Downloads Directory';

  @override
  String get deviceStorage => 'Device Storage';

  @override
  String get total => 'Total:';

  @override
  String get cache => 'Cache';

  @override
  String get freeSpace => 'Free Space';

  @override
  String get splashSubtitle => 'Fast. Secure. Powerful.';

  @override
  String get trackerSaved => 'Tracker settings saved successfully!';

  @override
  String get trackerAccountsTitle => 'Tracker Accounts';

  @override
  String get anilist => 'AniList';

  @override
  String get mal => 'MyAnimeList (MAL)';

  @override
  String get trakt => 'Trakt.tv';

  @override
  String get saveAccounts => 'Save Accounts';

  @override
  String get getToken => 'Get Token';
}
