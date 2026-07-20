import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('lib/l10n/app_en.arb');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  // Tracker strings
  json['trackerInstructions'] = 'Login to MyAnimeList, AniList, or Trakt.tv to automatically sync watch progress in the background once you reach 80% watched of an episode.';
  json['pasteAnilistToken'] = 'Paste AniList Access Token';
  json['anilistInstructions'] = '1. Visit AniList Developer Settings.\n2. Create a Client or use an existing Developer Token.\n3. Paste the generated Access Token here.';
  json['pasteMalToken'] = 'Paste MyAnimeList Access Token';
  json['malInstructions'] = '1. Open MyAnimeList API Settings.\n2. Authorize an application to fetch your Developer Token.\n3. Paste your OAuth2 access token here.';
  json['pasteTraktToken'] = 'Paste Trakt.tv Access Token';
  json['traktInstructions'] = '1. Create a new App in Trakt API Developer dashboard.\n2. Obtain/generate a personal Access Token.\n3. Paste your Trakt access token here.';

  // Backup strings
  json['backupManagerTitle'] = 'Backup & Restore';
  json['exportBackup'] = 'Export Backup';
  json['exportBackupSubtitle'] = 'Save configuration and history to an encrypted file';
  json['restoreBackup'] = 'Restore Backup';
  json['restoreBackupSubtitle'] = 'Load settings and history from a backup file';
  json['cloudProgressSync'] = 'Cloud Progress Sync';
  json['syncProgressNow'] = 'Sync Progress Now';
  json['syncProgressNowSubtitle'] = 'Immediately upload local progress to Telegram';
  json['cancel'] = 'Cancel';
  json['ok'] = 'OK';
  json['disabled'] = 'Disabled';
  json['pinnedMessage'] = 'Pinned Message (Clean)';
  json['sequentialLogs'] = 'Sequential Logs';

  file.writeAsStringSync(const JsonEncoder.withIndent('    ').convert(json));
}

