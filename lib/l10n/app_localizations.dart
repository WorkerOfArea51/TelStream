import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('ja'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TelStream'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloadsManager.
  ///
  /// In en, this message translates to:
  /// **'Downloads Manager'**
  String get downloadsManager;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @historyPlayback.
  ///
  /// In en, this message translates to:
  /// **'History / Playback'**
  String get historyPlayback;

  /// No description provided for @airingCalendar.
  ///
  /// In en, this message translates to:
  /// **'Airing Calendar'**
  String get airingCalendar;

  /// No description provided for @globalSearch.
  ///
  /// In en, this message translates to:
  /// **'Global Search'**
  String get globalSearch;

  /// No description provided for @networkStream.
  ///
  /// In en, this message translates to:
  /// **'Network Stream'**
  String get networkStream;

  /// No description provided for @openStream.
  ///
  /// In en, this message translates to:
  /// **'Open Stream...'**
  String get openStream;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @myChannels.
  ///
  /// In en, this message translates to:
  /// **'My Channels'**
  String get myChannels;

  /// No description provided for @addChannel.
  ///
  /// In en, this message translates to:
  /// **'Add Channel'**
  String get addChannel;

  /// No description provided for @channelName.
  ///
  /// In en, this message translates to:
  /// **'Channel Name'**
  String get channelName;

  /// No description provided for @telegramLink.
  ///
  /// In en, this message translates to:
  /// **'Telegram Link or @username'**
  String get telegramLink;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAll.
  ///
  /// In en, this message translates to:
  /// **'Save All'**
  String get saveAll;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeChannel.
  ///
  /// In en, this message translates to:
  /// **'Remove Channel?'**
  String get removeChannel;

  /// No description provided for @removeChannelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{name}\"?'**
  String removeChannelConfirm(Object name);

  /// No description provided for @noChannelsAdded.
  ///
  /// In en, this message translates to:
  /// **'No channels added yet'**
  String get noChannelsAdded;

  /// No description provided for @noChannelsHint.
  ///
  /// In en, this message translates to:
  /// **'Go to More → My Channels to add your own channels'**
  String get noChannelsHint;

  /// No description provided for @addYourFirstChannel.
  ///
  /// In en, this message translates to:
  /// **'Add Channel'**
  String get addYourFirstChannel;

  /// No description provided for @pendingResolution.
  ///
  /// In en, this message translates to:
  /// **'Pending: {link}'**
  String pendingResolution(Object link);

  /// No description provided for @channelId.
  ///
  /// In en, this message translates to:
  /// **'Channel ID: {id}'**
  String channelId(Object id);

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @storageManagement.
  ///
  /// In en, this message translates to:
  /// **'Storage Management'**
  String get storageManagement;

  /// No description provided for @storageManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Device storage, cache limits, download folder'**
  String get storageManagementSubtitle;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @videoPlayerPreferences.
  ///
  /// In en, this message translates to:
  /// **'Video Player Preferences'**
  String get videoPlayerPreferences;

  /// No description provided for @videoPlayerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Gestures, audio, subtitles, and player UI'**
  String get videoPlayerSubtitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @colorTheme.
  ///
  /// In en, this message translates to:
  /// **'Color Theme'**
  String get colorTheme;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @trackersIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Trackers & Integrations'**
  String get trackersIntegrations;

  /// No description provided for @trackerAccounts.
  ///
  /// In en, this message translates to:
  /// **'Tracker Accounts'**
  String get trackerAccounts;

  /// No description provided for @trackerAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MyAnimeList, AniList, and Trakt.tv syncing preferences.'**
  String get trackerAccountsSubtitle;

  /// No description provided for @diagnosticsBackups.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics & Backups'**
  String get diagnosticsBackups;

  /// No description provided for @troubleshooting.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting & Diagnostics'**
  String get troubleshooting;

  /// No description provided for @troubleshootingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnose hardware decoding and subtitle rendering issues.'**
  String get troubleshootingSubtitle;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// No description provided for @backupRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export or import settings and watch history.'**
  String get backupRestoreSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s New / Changelog'**
  String get whatsNew;

  /// No description provided for @whatsNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View release notes for this version'**
  String get whatsNewSubtitle;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout from TelStream'**
  String get logout;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmpty;

  /// No description provided for @refreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refresh Library'**
  String get refreshLibrary;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchQuery.
  ///
  /// In en, this message translates to:
  /// **'Search query...'**
  String get searchQuery;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search today\'s releases...'**
  String get searchHint;

  /// No description provided for @noRecommendations.
  ///
  /// In en, this message translates to:
  /// **'No recommendations available'**
  String get noRecommendations;

  /// No description provided for @downloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download All ({count} Episodes)'**
  String downloadAll(Object count);

  /// No description provided for @downloadAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will download {count} episodes. Up to 3 will download simultaneously, the rest will be queued.'**
  String downloadAllConfirm(Object count);

  /// No description provided for @downloadAllButton.
  ///
  /// In en, this message translates to:
  /// **'Download All'**
  String get downloadAllButton;

  /// No description provided for @startedBatchDownload.
  ///
  /// In en, this message translates to:
  /// **'Started batch download for {count} episodes'**
  String startedBatchDownload(Object count);

  /// No description provided for @noDownloadableEpisodes.
  ///
  /// In en, this message translates to:
  /// **'No downloadable episodes found.'**
  String get noDownloadableEpisodes;

  /// No description provided for @pauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause All'**
  String get pauseAll;

  /// No description provided for @resumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume All'**
  String get resumeAll;

  /// No description provided for @allDownloadsPaused.
  ///
  /// In en, this message translates to:
  /// **'All downloads paused'**
  String get allDownloadsPaused;

  /// No description provided for @allDownloadsResumed.
  ///
  /// In en, this message translates to:
  /// **'All downloads resumed'**
  String get allDownloadsResumed;

  /// No description provided for @wifiOnlyDownloads.
  ///
  /// In en, this message translates to:
  /// **'WiFi Only Downloads'**
  String get wifiOnlyDownloads;

  /// No description provided for @wifiOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pause downloads when on cellular data'**
  String get wifiOnlySubtitle;

  /// No description provided for @activeQueue.
  ///
  /// In en, this message translates to:
  /// **'Active / Queue'**
  String get activeQueue;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @clearSeasonMetadata.
  ///
  /// In en, this message translates to:
  /// **'Clear Season Metadata Cache'**
  String get clearSeasonMetadata;

  /// No description provided for @clearSeasonMetadataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete cached season posters, cast, and plot info. App will re-fetch from TMDB on next visit.'**
  String get clearSeasonMetadataSubtitle;

  /// No description provided for @clearSeasonMetadataConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will delete all cached season metadata (posters, cast, plot). The app will re-fetch from TMDB next time you open each season. Your settings and watch history will NOT be affected.'**
  String get clearSeasonMetadataConfirm;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @seasonMetadataCleared.
  ///
  /// In en, this message translates to:
  /// **'Season metadata cache cleared.'**
  String get seasonMetadataCleared;

  /// No description provided for @deleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete Download'**
  String get deleteDownload;

  /// No description provided for @deleteDownloadConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\" from your device? This cannot be undone.'**
  String deleteDownloadConfirm(Object name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted successfully'**
  String get fileDeleted;

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete file: {error}'**
  String failedToDelete(Object error);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select App Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get russian;

  /// No description provided for @autoDownloadFirst.
  ///
  /// In en, this message translates to:
  /// **'Auto-download first'**
  String get autoDownloadFirst;

  /// No description provided for @noSubtitlesFound.
  ///
  /// In en, this message translates to:
  /// **'No subtitles found for auto-download.'**
  String get noSubtitlesFound;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitles;

  /// No description provided for @playbackSettings.
  ///
  /// In en, this message translates to:
  /// **'Playback Settings'**
  String get playbackSettings;

  /// No description provided for @audioSettings.
  ///
  /// In en, this message translates to:
  /// **'Audio Settings'**
  String get audioSettings;

  /// No description provided for @videoSettings.
  ///
  /// In en, this message translates to:
  /// **'Video Settings'**
  String get videoSettings;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String error(Object message);

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String saveError(Object error);

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String loadError(Object error);

  /// No description provided for @deleteError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String deleteError(Object error);

  /// No description provided for @uploadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload: {error}'**
  String uploadError(Object error);

  /// No description provided for @downloadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to download: {error}'**
  String downloadError(Object error);

  /// No description provided for @searchError.
  ///
  /// In en, this message translates to:
  /// **'Failed to search: {error}'**
  String searchError(Object error);

  /// No description provided for @updateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update: {error}'**
  String updateError(Object error);

  /// No description provided for @restoreError.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore: {error}'**
  String restoreError(Object error);

  /// No description provided for @backupError.
  ///
  /// In en, this message translates to:
  /// **'Failed to backup: {error}'**
  String backupError(Object error);

  /// No description provided for @generalError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get generalError;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get serverError;

  /// No description provided for @notFoundError.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get notFoundError;

  /// No description provided for @accessDeniedError.
  ///
  /// In en, this message translates to:
  /// **'Access denied.'**
  String get accessDeniedError;

  /// No description provided for @invalidURLError.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL.'**
  String get invalidURLError;

  /// No description provided for @timeoutError.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get timeoutError;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get unknownError;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available.'**
  String get noData;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResults;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history available.'**
  String get noHistory;

  /// No description provided for @noDownloads.
  ///
  /// In en, this message translates to:
  /// **'No downloads available.'**
  String get noDownloads;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites available.'**
  String get noFavorites;

  /// No description provided for @noSettings.
  ///
  /// In en, this message translates to:
  /// **'No settings available.'**
  String get noSettings;

  /// No description provided for @noPermissions.
  ///
  /// In en, this message translates to:
  /// **'No permissions available.'**
  String get noPermissions;

  /// No description provided for @noStorage.
  ///
  /// In en, this message translates to:
  /// **'No storage available.'**
  String get noStorage;

  /// No description provided for @noNetwork.
  ///
  /// In en, this message translates to:
  /// **'No network available.'**
  String get noNetwork;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get noInternet;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection.'**
  String get noConnection;

  /// No description provided for @noAccess.
  ///
  /// In en, this message translates to:
  /// **'No access.'**
  String get noAccess;

  /// No description provided for @noContent.
  ///
  /// In en, this message translates to:
  /// **'No content available.'**
  String get noContent;

  /// No description provided for @noEpisodes.
  ///
  /// In en, this message translates to:
  /// **'No episodes available.'**
  String get noEpisodes;

  /// No description provided for @noSeasons.
  ///
  /// In en, this message translates to:
  /// **'No seasons available.'**
  String get noSeasons;

  /// No description provided for @noSeries.
  ///
  /// In en, this message translates to:
  /// **'No series available.'**
  String get noSeries;

  /// No description provided for @noMovies.
  ///
  /// In en, this message translates to:
  /// **'No movies available.'**
  String get noMovies;

  /// No description provided for @noAnime.
  ///
  /// In en, this message translates to:
  /// **'No anime available.'**
  String get noAnime;

  /// No description provided for @noWebSeries.
  ///
  /// In en, this message translates to:
  /// **'No web series available.'**
  String get noWebSeries;

  /// No description provided for @noChannels.
  ///
  /// In en, this message translates to:
  /// **'No channels available.'**
  String get noChannels;

  /// No description provided for @noSubtitles.
  ///
  /// In en, this message translates to:
  /// **'No subtitles available.'**
  String get noSubtitles;

  /// No description provided for @noAudio.
  ///
  /// In en, this message translates to:
  /// **'No audio available.'**
  String get noAudio;

  /// No description provided for @noVideo.
  ///
  /// In en, this message translates to:
  /// **'No video available.'**
  String get noVideo;

  /// No description provided for @noImages.
  ///
  /// In en, this message translates to:
  /// **'No images available.'**
  String get noImages;

  /// No description provided for @noFiles.
  ///
  /// In en, this message translates to:
  /// **'No files available.'**
  String get noFiles;

  /// No description provided for @noDocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents available.'**
  String get noDocuments;

  /// No description provided for @noLinks.
  ///
  /// In en, this message translates to:
  /// **'No links available.'**
  String get noLinks;

  /// No description provided for @noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks available.'**
  String get noBookmarks;

  /// No description provided for @noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes available.'**
  String get noNotes;

  /// No description provided for @noTags.
  ///
  /// In en, this message translates to:
  /// **'No tags available.'**
  String get noTags;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories available.'**
  String get noCategories;

  /// No description provided for @noFilters.
  ///
  /// In en, this message translates to:
  /// **'No filters available.'**
  String get noFilters;

  /// No description provided for @noSort.
  ///
  /// In en, this message translates to:
  /// **'No sort available.'**
  String get noSort;

  /// No description provided for @noView.
  ///
  /// In en, this message translates to:
  /// **'No view available.'**
  String get noView;

  /// No description provided for @noLayout.
  ///
  /// In en, this message translates to:
  /// **'No layout available.'**
  String get noLayout;

  /// No description provided for @noTheme.
  ///
  /// In en, this message translates to:
  /// **'No theme available.'**
  String get noTheme;

  /// No description provided for @noColor.
  ///
  /// In en, this message translates to:
  /// **'No color available.'**
  String get noColor;

  /// No description provided for @noFont.
  ///
  /// In en, this message translates to:
  /// **'No font available.'**
  String get noFont;

  /// No description provided for @noSize.
  ///
  /// In en, this message translates to:
  /// **'No size available.'**
  String get noSize;

  /// No description provided for @noPosition.
  ///
  /// In en, this message translates to:
  /// **'No position available.'**
  String get noPosition;

  /// No description provided for @noDuration.
  ///
  /// In en, this message translates to:
  /// **'No duration available.'**
  String get noDuration;

  /// No description provided for @noSpeed.
  ///
  /// In en, this message translates to:
  /// **'No speed available.'**
  String get noSpeed;

  /// No description provided for @noVolume.
  ///
  /// In en, this message translates to:
  /// **'No volume available.'**
  String get noVolume;

  /// No description provided for @noBrightness.
  ///
  /// In en, this message translates to:
  /// **'No brightness available.'**
  String get noBrightness;

  /// No description provided for @noContrast.
  ///
  /// In en, this message translates to:
  /// **'No contrast available.'**
  String get noContrast;

  /// No description provided for @noSaturation.
  ///
  /// In en, this message translates to:
  /// **'No saturation available.'**
  String get noSaturation;

  /// No description provided for @noHue.
  ///
  /// In en, this message translates to:
  /// **'No hue available.'**
  String get noHue;

  /// No description provided for @noGamma.
  ///
  /// In en, this message translates to:
  /// **'No gamma available.'**
  String get noGamma;

  /// No description provided for @noSharpness.
  ///
  /// In en, this message translates to:
  /// **'No sharpness available.'**
  String get noSharpness;

  /// No description provided for @noNoise.
  ///
  /// In en, this message translates to:
  /// **'No noise available.'**
  String get noNoise;

  /// No description provided for @noBlur.
  ///
  /// In en, this message translates to:
  /// **'No blur available.'**
  String get noBlur;

  /// No description provided for @noPixel.
  ///
  /// In en, this message translates to:
  /// **'No pixel available.'**
  String get noPixel;

  /// No description provided for @noFrame.
  ///
  /// In en, this message translates to:
  /// **'No frame available.'**
  String get noFrame;

  /// No description provided for @noField.
  ///
  /// In en, this message translates to:
  /// **'No field available.'**
  String get noField;

  /// No description provided for @noValue.
  ///
  /// In en, this message translates to:
  /// **'No value available.'**
  String get noValue;

  /// No description provided for @noKey.
  ///
  /// In en, this message translates to:
  /// **'No key available.'**
  String get noKey;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available.'**
  String get noDataAvailable;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResultsFound;

  /// No description provided for @noHistoryAvailable.
  ///
  /// In en, this message translates to:
  /// **'No history available.'**
  String get noHistoryAvailable;

  /// No description provided for @noDownloadsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No downloads available.'**
  String get noDownloadsAvailable;

  /// No description provided for @noFavoritesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No favorites available.'**
  String get noFavoritesAvailable;

  /// No description provided for @noSettingsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No settings available.'**
  String get noSettingsAvailable;

  /// No description provided for @noPermissionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No permissions available.'**
  String get noPermissionsAvailable;

  /// No description provided for @noStorageAvailable.
  ///
  /// In en, this message translates to:
  /// **'No storage available.'**
  String get noStorageAvailable;

  /// No description provided for @noNetworkAvailable.
  ///
  /// In en, this message translates to:
  /// **'No network available.'**
  String get noNetworkAvailable;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get noInternetConnection;

  /// No description provided for @noConnectionAvailable.
  ///
  /// In en, this message translates to:
  /// **'No connection available.'**
  String get noConnectionAvailable;

  /// No description provided for @noAccessAvailable.
  ///
  /// In en, this message translates to:
  /// **'No access available.'**
  String get noAccessAvailable;

  /// No description provided for @noContentAvailable.
  ///
  /// In en, this message translates to:
  /// **'No content available.'**
  String get noContentAvailable;

  /// No description provided for @noEpisodesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No episodes available.'**
  String get noEpisodesAvailable;

  /// No description provided for @noSeasonsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No seasons available.'**
  String get noSeasonsAvailable;

  /// No description provided for @noSeriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No series available.'**
  String get noSeriesAvailable;

  /// No description provided for @noMoviesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No movies available.'**
  String get noMoviesAvailable;

  /// No description provided for @noAnimeAvailable.
  ///
  /// In en, this message translates to:
  /// **'No anime available.'**
  String get noAnimeAvailable;

  /// No description provided for @noWebSeriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No web series available.'**
  String get noWebSeriesAvailable;

  /// No description provided for @noChannelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No channels available.'**
  String get noChannelsAvailable;

  /// No description provided for @noSubtitlesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No subtitles available.'**
  String get noSubtitlesAvailable;

  /// No description provided for @noAudioAvailable.
  ///
  /// In en, this message translates to:
  /// **'No audio available.'**
  String get noAudioAvailable;

  /// No description provided for @noVideoAvailable.
  ///
  /// In en, this message translates to:
  /// **'No video available.'**
  String get noVideoAvailable;

  /// No description provided for @noImagesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No images available.'**
  String get noImagesAvailable;

  /// No description provided for @noFilesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No files available.'**
  String get noFilesAvailable;

  /// No description provided for @noDocumentsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No documents available.'**
  String get noDocumentsAvailable;

  /// No description provided for @noLinksAvailable.
  ///
  /// In en, this message translates to:
  /// **'No links available.'**
  String get noLinksAvailable;

  /// No description provided for @noBookmarksAvailable.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks available.'**
  String get noBookmarksAvailable;

  /// No description provided for @noNotesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No notes available.'**
  String get noNotesAvailable;

  /// No description provided for @noTagsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tags available.'**
  String get noTagsAvailable;

  /// No description provided for @noCategoriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No categories available.'**
  String get noCategoriesAvailable;

  /// No description provided for @noFiltersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No filters available.'**
  String get noFiltersAvailable;

  /// No description provided for @noSortAvailable.
  ///
  /// In en, this message translates to:
  /// **'No sort available.'**
  String get noSortAvailable;

  /// No description provided for @noViewAvailable.
  ///
  /// In en, this message translates to:
  /// **'No view available.'**
  String get noViewAvailable;

  /// No description provided for @noLayoutAvailable.
  ///
  /// In en, this message translates to:
  /// **'No layout available.'**
  String get noLayoutAvailable;

  /// No description provided for @noThemeAvailable.
  ///
  /// In en, this message translates to:
  /// **'No theme available.'**
  String get noThemeAvailable;

  /// No description provided for @noColorAvailable.
  ///
  /// In en, this message translates to:
  /// **'No color available.'**
  String get noColorAvailable;

  /// No description provided for @noFontAvailable.
  ///
  /// In en, this message translates to:
  /// **'No font available.'**
  String get noFontAvailable;

  /// No description provided for @noSizeAvailable.
  ///
  /// In en, this message translates to:
  /// **'No size available.'**
  String get noSizeAvailable;

  /// No description provided for @noPositionAvailable.
  ///
  /// In en, this message translates to:
  /// **'No position available.'**
  String get noPositionAvailable;

  /// No description provided for @noDurationAvailable.
  ///
  /// In en, this message translates to:
  /// **'No duration available.'**
  String get noDurationAvailable;

  /// No description provided for @noSpeedAvailable.
  ///
  /// In en, this message translates to:
  /// **'No speed available.'**
  String get noSpeedAvailable;

  /// No description provided for @noVolumeAvailable.
  ///
  /// In en, this message translates to:
  /// **'No volume available.'**
  String get noVolumeAvailable;

  /// No description provided for @noBrightnessAvailable.
  ///
  /// In en, this message translates to:
  /// **'No brightness available.'**
  String get noBrightnessAvailable;

  /// No description provided for @noContrastAvailable.
  ///
  /// In en, this message translates to:
  /// **'No contrast available.'**
  String get noContrastAvailable;

  /// No description provided for @noSaturationAvailable.
  ///
  /// In en, this message translates to:
  /// **'No saturation available.'**
  String get noSaturationAvailable;

  /// No description provided for @noHueAvailable.
  ///
  /// In en, this message translates to:
  /// **'No hue available.'**
  String get noHueAvailable;

  /// No description provided for @noGammaAvailable.
  ///
  /// In en, this message translates to:
  /// **'No gamma available.'**
  String get noGammaAvailable;

  /// No description provided for @noSharpnessAvailable.
  ///
  /// In en, this message translates to:
  /// **'No sharpness available.'**
  String get noSharpnessAvailable;

  /// No description provided for @noNoiseAvailable.
  ///
  /// In en, this message translates to:
  /// **'No noise available.'**
  String get noNoiseAvailable;

  /// No description provided for @noBlurAvailable.
  ///
  /// In en, this message translates to:
  /// **'No blur available.'**
  String get noBlurAvailable;

  /// No description provided for @noPixelAvailable.
  ///
  /// In en, this message translates to:
  /// **'No pixel available.'**
  String get noPixelAvailable;

  /// No description provided for @noFrameAvailable.
  ///
  /// In en, this message translates to:
  /// **'No frame available.'**
  String get noFrameAvailable;

  /// No description provided for @noFieldAvailable.
  ///
  /// In en, this message translates to:
  /// **'No field available.'**
  String get noFieldAvailable;

  /// No description provided for @noValueAvailable.
  ///
  /// In en, this message translates to:
  /// **'No value available.'**
  String get noValueAvailable;

  /// No description provided for @noKeyAvailable.
  ///
  /// In en, this message translates to:
  /// **'No key available.'**
  String get noKeyAvailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'ja',
    'pt',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
