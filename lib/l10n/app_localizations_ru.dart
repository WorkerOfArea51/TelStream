// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'TelStream';

  @override
  String get settings => 'Настройки';

  @override
  String get downloads => 'Загрузки';

  @override
  String get downloadsManager => 'Менеджер загрузок';

  @override
  String get history => 'История';

  @override
  String get historyPlayback => 'История / Воспроизведение';

  @override
  String get airingCalendar => 'Календарь выхода';

  @override
  String get globalSearch => 'Глобальный поиск';

  @override
  String get networkStream => 'Сетевой поток';

  @override
  String get openStream => 'Открыть поток...';

  @override
  String get more => 'Ещё';

  @override
  String get myChannels => 'Мои каналы';

  @override
  String get addChannel => 'Добавить канал';

  @override
  String get channelName => 'Название канала';

  @override
  String get telegramLink => 'Ссылка Telegram или @username';

  @override
  String get icon => 'Иконка';

  @override
  String get cancel => 'Отмена';

  @override
  String get add => 'Добавить';

  @override
  String get save => 'Сохранить';

  @override
  String get saveAll => 'Сохранить все';

  @override
  String get remove => 'Удалить';

  @override
  String get removeChannel => 'Удалить канал?';

  @override
  String removeChannelConfirm(Object name) {
    return 'Вы уверены, что хотите удалить \"$name\"?';
  }

  @override
  String get noChannelsAdded => 'Каналы еще не добавлены';

  @override
  String get noChannelsHint =>
      'Перейдите в Ещё → Мои каналы, чтобы добавить свои каналы';

  @override
  String get addYourFirstChannel => 'Добавить канал';

  @override
  String pendingResolution(Object link) {
    return 'Ожидает: $link';
  }

  @override
  String channelId(Object id) {
    return 'ID канала: $id';
  }

  @override
  String get storage => 'Хранилище';

  @override
  String get storageManagement => 'Управление хранилищем';

  @override
  String get storageManagementSubtitle =>
      'Хранилище устройства, лимиты кэша, папка загрузок';

  @override
  String get playback => 'Воспроизведение';

  @override
  String get videoPlayerPreferences => 'Настройки видеоплеера';

  @override
  String get videoPlayerSubtitle => 'Жесты, аудио, субтитры и интерфейс плеера';

  @override
  String get appearance => 'Оформление';

  @override
  String get themeMode => 'Режим темы';

  @override
  String get colorTheme => 'Цветовая тема';

  @override
  String get system => 'Система';

  @override
  String get light => 'Светлая';

  @override
  String get dark => 'Тёмная';

  @override
  String get trackersIntegrations => 'Трекеры и интеграции';

  @override
  String get trackerAccounts => 'Аккаунты трекеров';

  @override
  String get trackerAccountsSubtitle =>
      'Настройки синхронизации MyAnimeList, AniList и Trakt.tv.';

  @override
  String get diagnosticsBackups => 'Диагностика и резервные копии';

  @override
  String get troubleshooting => 'Диагностика и устранение неполадок';

  @override
  String get troubleshootingSubtitle =>
      'Диагностика аппаратного декодирования и рендеринга субтитров.';

  @override
  String get backupRestore => 'Резервное копирование и восстановление';

  @override
  String get backupRestoreSubtitle =>
      'Экспорт или импорт настроек и истории просмотра.';

  @override
  String get about => 'О приложении';

  @override
  String get whatsNew => 'Что нового / Журнал изменений';

  @override
  String get whatsNewSubtitle => 'Просмотр заметок к релизу для этой версии';

  @override
  String get logout => 'Выйти из TelStream';

  @override
  String get libraryEmpty => 'Ваша библиотека пуста';

  @override
  String get refreshLibrary => 'Обновить библиотеку';

  @override
  String get search => 'Поиск';

  @override
  String get searchQuery => 'Поисковый запрос...';

  @override
  String get searchHint => 'Поиск сегодняшних релизов...';

  @override
  String get noRecommendations => 'Нет рекомендаций';

  @override
  String downloadAll(Object count) {
    return 'Загрузить все ($count серий)';
  }

  @override
  String downloadAllConfirm(Object count) {
    return 'Это загрузит $count серий. До 3 будут загружаться одновременно, остальные будут в очереди.';
  }

  @override
  String get downloadAllButton => 'Загрузить все';

  @override
  String startedBatchDownload(Object count) {
    return 'Начата массовая загрузка $count серий';
  }

  @override
  String get noDownloadableEpisodes => 'Нет серий для загрузки.';

  @override
  String get pauseAll => 'Пауза для всех';

  @override
  String get resumeAll => 'Возобновить все';

  @override
  String get allDownloadsPaused => 'Все загрузки приостановлены';

  @override
  String get allDownloadsResumed => 'Все загрузки возобновлены';

  @override
  String get wifiOnlyDownloads => 'Загрузка только по WiFi';

  @override
  String get wifiOnlySubtitle => 'Приостанавливать загрузки при сотовой связи';

  @override
  String get activeQueue => 'Активные / Очередь';

  @override
  String get downloaded => 'Загружено';

  @override
  String get clearSeasonMetadata => 'Очистить кэш метаданных сезонов';

  @override
  String get clearSeasonMetadataSubtitle =>
      'Удалить кэшированные постеры сезонов, актеров и описания. Приложение заново загрузит их из TMDB при следующем открытии.';

  @override
  String get clearSeasonMetadataConfirm =>
      'Это удалит весь кэшированный кэш метаданных сезонов (постеры, актеры, описания). Приложение заново загрузит их из TMDB при следующем открытии каждого сезона. Ваши настройки и история просмотра НЕ будут затронуты.';

  @override
  String get clear => 'Очистить';

  @override
  String get seasonMetadataCleared => 'Кэш метаданных сезонов очищен.';

  @override
  String get deleteDownload => 'Удалить загрузку';

  @override
  String deleteDownloadConfirm(Object name) {
    return 'Вы уверены, что хотите удалить \"$name\" с устройства? Это действие нельзя отменить.';
  }

  @override
  String get delete => 'Удалить';

  @override
  String get fileDeleted => 'Файл успешно удален';

  @override
  String failedToDelete(Object error) {
    return 'Не удалось удалить файл: $error';
  }

  @override
  String get language => 'Язык';

  @override
  String get selectLanguage => 'Выбрать язык приложения';

  @override
  String get english => 'English';

  @override
  String get russian => 'Русский';

  @override
  String get autoDownloadFirst => 'Авто-загрузка первого';

  @override
  String get noSubtitlesFound => 'Субтитры не найдены для авто-загрузки.';

  @override
  String get subtitles => 'Субтитры';

  @override
  String get playbackSettings => 'Настройки воспроизведения';

  @override
  String get audioSettings => 'Настройки аудио';

  @override
  String get videoSettings => 'Настройки видео';

  @override
  String get connectionError => 'Ошибка подключения';

  @override
  String get retry => 'Повторить';

  @override
  String get loading => 'Загрузка...';

  @override
  String error(Object message) {
    return 'Ошибка: $message';
  }

  @override
  String saveError(Object error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String loadError(Object error) {
    return 'Не удалось загрузить: $error';
  }

  @override
  String deleteError(Object error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String uploadError(Object error) {
    return 'Не удалось загрузить: $error';
  }

  @override
  String downloadError(Object error) {
    return 'Не удалось скачать: $error';
  }

  @override
  String searchError(Object error) {
    return 'Не удалось найти: $error';
  }

  @override
  String updateError(Object error) {
    return 'Не удалось обновить: $error';
  }

  @override
  String restoreError(Object error) {
    return 'Не удалось восстановить: $error';
  }

  @override
  String backupError(Object error) {
    return 'Не удалось создать резервную копию: $error';
  }

  @override
  String get generalError => 'Произошла ошибка. Пожалуйста, попробуйте снова.';

  @override
  String get networkError => 'Сетевая ошибка. Проверьте подключение.';

  @override
  String get serverError => 'Ошибка сервера. Попробуйте позже.';

  @override
  String get notFoundError => 'Не найдено.';

  @override
  String get accessDeniedError => 'Доступ запрещен.';

  @override
  String get invalidURLError => 'Неверный URL.';

  @override
  String get timeoutError => 'Время запроса истекло. Попробуйте снова.';

  @override
  String get unknownError => 'Произошла неизвестная ошибка.';

  @override
  String get noData => 'Нет данных.';

  @override
  String get noResults => 'Результаты не найдены.';

  @override
  String get noHistory => 'История недоступна.';

  @override
  String get noDownloads => 'Загрузки недоступны.';

  @override
  String get noFavorites => 'Избранное недоступно.';

  @override
  String get noSettings => 'Настройки недоступны.';

  @override
  String get noPermissions => 'Разрешения недоступны.';

  @override
  String get noStorage => 'Хранилище недоступно.';

  @override
  String get noNetwork => 'Сеть недоступна.';

  @override
  String get noInternet => 'Нет интернет-соединения.';

  @override
  String get noConnection => 'Нет соединения.';

  @override
  String get noAccess => 'Нет доступа.';

  @override
  String get noContent => 'Контент недоступен.';

  @override
  String get noEpisodes => 'Серии недоступны.';

  @override
  String get noSeasons => 'Сезоны недоступны.';

  @override
  String get noSeries => 'Сериалы недоступны.';

  @override
  String get noMovies => 'Фильмы недоступны.';

  @override
  String get noAnime => 'Аниме недоступно.';

  @override
  String get noWebSeries => 'Веб-сериалы недоступны.';

  @override
  String get noChannels => 'Каналы недоступны.';

  @override
  String get noSubtitles => 'Субтитры недоступны.';

  @override
  String get noAudio => 'Аудио недоступно.';

  @override
  String get noVideo => 'Видео недоступно.';

  @override
  String get noImages => 'Изображения недоступны.';

  @override
  String get noFiles => 'Файлы недоступны.';

  @override
  String get noDocuments => 'Документы недоступны.';

  @override
  String get noLinks => 'Ссылки недоступны.';

  @override
  String get noBookmarks => 'Закладки недоступны.';

  @override
  String get noNotes => 'Заметки недоступны.';

  @override
  String get noTags => 'Теги недоступны.';

  @override
  String get noCategories => 'Категории недоступны.';

  @override
  String get noFilters => 'Фильтры недоступны.';

  @override
  String get noSort => 'Сортировка недоступна.';

  @override
  String get noView => 'Просмотр недоступен.';

  @override
  String get noLayout => 'Макет недоступен.';

  @override
  String get noTheme => 'Тема недоступна.';

  @override
  String get noColor => 'Цвет недоступен.';

  @override
  String get noFont => 'Шрифт недоступен.';

  @override
  String get noSize => 'Размер недоступен.';

  @override
  String get noPosition => 'Позиция недоступна.';

  @override
  String get noDuration => 'Длительность недоступна.';

  @override
  String get noSpeed => 'Скорость недоступна.';

  @override
  String get noVolume => 'Громкость недоступна.';

  @override
  String get noBrightness => 'Яркость недоступна.';

  @override
  String get noContrast => 'Контраст недоступен.';

  @override
  String get noSaturation => 'Насыщенность недоступна.';

  @override
  String get noHue => 'Оттенок недоступен.';

  @override
  String get noGamma => 'Гамма недоступна.';

  @override
  String get noSharpness => 'Резкость недоступна.';

  @override
  String get noNoise => 'Шум недоступен.';

  @override
  String get noBlur => 'Размытие недоступно.';

  @override
  String get noPixel => 'Пиксель недоступен.';

  @override
  String get noFrame => 'Кадр недоступен.';

  @override
  String get noField => 'Поле недоступно.';

  @override
  String get noValue => 'Значение недоступно.';

  @override
  String get noKey => 'Ключ недоступен.';

  @override
  String get noDataAvailable => 'Нет данных.';

  @override
  String get noResultsFound => 'Результаты не найдены.';

  @override
  String get noHistoryAvailable => 'История недоступна.';

  @override
  String get noDownloadsAvailable => 'Загрузки недоступны.';

  @override
  String get noFavoritesAvailable => 'Избранное недоступно.';

  @override
  String get noSettingsAvailable => 'Настройки недоступны.';

  @override
  String get noPermissionsAvailable => 'Разрешения недоступны.';

  @override
  String get noStorageAvailable => 'Хранилище недоступно.';

  @override
  String get noNetworkAvailable => 'Сеть недоступна.';

  @override
  String get noInternetConnection => 'Нет интернет-соединения.';

  @override
  String get noConnectionAvailable => 'Нет соединения.';

  @override
  String get noAccessAvailable => 'Нет доступа.';

  @override
  String get noContentAvailable => 'Контент недоступен.';

  @override
  String get noEpisodesAvailable => 'Серии недоступны.';

  @override
  String get noSeasonsAvailable => 'Сезоны недоступны.';

  @override
  String get noSeriesAvailable => 'Сериалы недоступны.';

  @override
  String get noMoviesAvailable => 'Фильмы недоступны.';

  @override
  String get noAnimeAvailable => 'Аниме недоступно.';

  @override
  String get noWebSeriesAvailable => 'Веб-сериалы недоступны.';

  @override
  String get noChannelsAvailable => 'Каналы недоступны.';

  @override
  String get noSubtitlesAvailable => 'Субтитры недоступны.';

  @override
  String get noAudioAvailable => 'Аудио недоступно.';

  @override
  String get noVideoAvailable => 'Видео недоступно.';

  @override
  String get noImagesAvailable => 'Изображения недоступны.';

  @override
  String get noFilesAvailable => 'Файлы недоступны.';

  @override
  String get noDocumentsAvailable => 'Документы недоступны.';

  @override
  String get noLinksAvailable => 'Ссылки недоступны.';

  @override
  String get noBookmarksAvailable => 'Закладки недоступны.';

  @override
  String get noNotesAvailable => 'Заметки недоступны.';

  @override
  String get noTagsAvailable => 'Теги недоступны.';

  @override
  String get noCategoriesAvailable => 'Категории недоступны.';

  @override
  String get noFiltersAvailable => 'Фильтры недоступны.';

  @override
  String get noSortAvailable => 'Сортировка недоступна.';

  @override
  String get noViewAvailable => 'Просмотр недоступен.';

  @override
  String get noLayoutAvailable => 'Макет недоступен.';

  @override
  String get noThemeAvailable => 'Тема недоступна.';

  @override
  String get noColorAvailable => 'Цвет недоступен.';

  @override
  String get noFontAvailable => 'Шрифт недоступен.';

  @override
  String get noSizeAvailable => 'Размер недоступен.';

  @override
  String get noPositionAvailable => 'Позиция недоступна.';

  @override
  String get noDurationAvailable => 'Длительность недоступна.';

  @override
  String get noSpeedAvailable => 'Скорость недоступна.';

  @override
  String get noVolumeAvailable => 'Громкость недоступна.';

  @override
  String get noBrightnessAvailable => 'Яркость недоступна.';

  @override
  String get noContrastAvailable => 'Контраст недоступен.';

  @override
  String get noSaturationAvailable => 'Насыщенность недоступна.';

  @override
  String get noHueAvailable => 'Оттенок недоступен.';

  @override
  String get noGammaAvailable => 'Гамма недоступна.';

  @override
  String get noSharpnessAvailable => 'Резкость недоступна.';

  @override
  String get noNoiseAvailable => 'Шум недоступен.';

  @override
  String get noBlurAvailable => 'Размытие недоступно.';

  @override
  String get noPixelAvailable => 'Пиксель недоступен.';

  @override
  String get noFrameAvailable => 'Кадр недоступен.';

  @override
  String get noFieldAvailable => 'Поле недоступно.';

  @override
  String get noValueAvailable => 'Значение недоступно.';

  @override
  String get noKeyAvailable => 'Ключ недоступен.';
}
