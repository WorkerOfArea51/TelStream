import 'package:tdlib/td_api.dart' as td;
import '../models/episode.dart';
import '../models/video_source.dart';
import '../core/utils/title_normalizer.dart';
import '../core/utils/td_message_helpers.dart';
import '../core/video_metadata/video_metadata.dart';

class EpisodeGrouper {
  static final _denylist = RegExp(
    r'\b(recap|preview|special|ova|ona|pv|ncop|nced|op|ed|tva|bd|dvd|web[._-]?dl)\b',
    caseSensitive: false,
  );

  /// Extracts a descriptive episode title from the filename.
  /// Tries to return just the text AFTER the episode-number marker
  /// (e.g. for "Series - EP 05 - Vegeta Attacks", returns "Vegeta Attacks").
  /// Preserves leading emojis (🎬📥✨ etc.) as part of the title.
  static String _buildEpisodeTitle(td.Message msg, int epNum) {
    final rawTitle = TitleNormalizer.getMessageFileName(msg);
    var title = TitleNormalizer.cleanDisplayTitle(rawTitle);

    if (title.isEmpty) return 'Episode $epNum';

    // Preserve leading emojis before extraction (they're part of the user's
    // intended naming style — see the separate emoji-preservation fix).
    // ignore: valid_regexps
    final leadingEmojiMatch = RegExp(r'^(\p{Extended_Pictographic}(?:\p{Extended_Pictographic}|\s)*)', unicode: true).firstMatch(title);
    final leadingEmoji = leadingEmojiMatch?.group(1) ?? '';
    var workingTitle = leadingEmoji.isEmpty ? title : title.substring(leadingEmoji.length).trim();

    // Try to extract the descriptive name that appears AFTER an episode-number marker.
    final epMarkerRegex = RegExp(
      r'(?:s\d{1,2}\s*[ex]\s*\d{1,3}|ep(?:isode)?\.?\s*\d{1,3}|e\d{1,3}|\b\d{1,3}\b)'
      r'[\s\-—–_:|.]*'
      r'(.+)$',
      caseSensitive: false,
    );
    final epMarkerMatch = epMarkerRegex.firstMatch(workingTitle);
    if (epMarkerMatch != null) {
      final descriptive = epMarkerMatch.group(1)!.trim();
      if (descriptive.isNotEmpty) {
        return '$leadingEmoji$descriptive'.trim();
      }
    }

    // No episode-number marker found, or descriptive part is empty.
    // Return the cleaned full title with the leading emoji prepended.
    return '$leadingEmoji$workingTitle'.trim().isNotEmpty
        ? '$leadingEmoji$workingTitle'.trim()
        : 'Episode $epNum';
  }

  static List<Episode> groupEpisodes(List<td.Message> messages) {
    final Map<int, List<td.Message>> epMap = {};
    final List<td.Message> isolatedMessages = [];

    for (final msg in messages) {
      final fileName = TitleNormalizer.getMessageFileName(msg);
      final epNum = TitleNormalizer.parseEpisodeNumber(msg);

      if (epNum == null || _denylist.hasMatch(fileName)) {
        isolatedMessages.add(msg);
      } else {
        epMap.putIfAbsent(epNum, () => []).add(msg);
      }
    }

    final sortedEpNums = epMap.keys.toList()..sort();
    final List<Episode> results = [];

    // Process grouped episodes
    for (final epNum in sortedEpNums) {
      final msgs = epMap[epNum]!;
      final sources = msgs.map(_createSource).toList();

      // Use the first message's filename to build a descriptive title.
      final title = _buildEpisodeTitle(msgs.first, epNum);

      results.add(Episode(
        title: title,
        sources: sources,
        isMetadataExtracted: false,
        episodeNumber: epNum,
      ));
    }

    // Group isolated messages by their clean title
    final isolatedGroups = <String, List<td.Message>>{};
    for (final msg in isolatedMessages) {
      String rawTitle = TitleNormalizer.getMessageFileName(msg);
      final cleanTitle = TitleNormalizer.normalizeSeriesName(rawTitle, isMovie: true).toLowerCase();
      isolatedGroups.putIfAbsent(cleanTitle, () => []).add(msg);
    }

    // Process isolated groups
    for (final entry in isolatedGroups.entries) {
      final msgs = entry.value;
      final sources = msgs.map(_createSource).toList();
      
      // Clean the title aggressively — strip all release-name noise.
      final rawTitle = TitleNormalizer.getMessageFileName(msgs.first);
      final cleanTitle = TitleNormalizer.cleanDisplayTitle(rawTitle);

      results.add(Episode(
        title: cleanTitle.isNotEmpty ? cleanTitle : 'Video ${msgs.first.id}',
        sources: sources,
        isMetadataExtracted: false,
        episodeNumber: null,
      ));
    }

    // Sort all results. Grouped episodes first (by number), then isolated ones (by message ID)
    results.sort((a, b) {
      final numA = a.episodeNumber;
      final numB = b.episodeNumber;
      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      } else if (numA != null && numB == null) {
        return -1;
      } else if (numA == null && numB != null) {
        return 1;
      }
      final msgA = a.messageId ?? 0;
      final msgB = b.messageId ?? 0;
      return msgA.compareTo(msgB);
    });

    return results;
  }

  static VideoSource _createSource(td.Message msg) {
    // Extract TDLib-provided metadata (instant, no network needed).
    final tdWidth = extractTdlibWidth(msg);
    final tdHeight = extractTdlibHeight(msg);
    final tdDuration = extractTdlibDurationSeconds(msg);
    final minithumbnail = extractMinithumbnailData(msg);

    // For MessageVideo, TDLib gives us width/height/duration directly.
    // Pre-populate the metadata so the UI can display quality + duration
    // immediately without waiting for container parsing.
    VideoMetadata? initialMetadata;
    if (tdWidth != null && tdHeight != null && tdWidth > 0 && tdHeight > 0) {
      initialMetadata = VideoMetadata(
        width: tdWidth,
        height: tdHeight,
        durationMillis: (tdDuration ?? 0) * 1000,
        // Container is unknown until we parse the file header.
        // The MetadataExtractionNotifier will fill this in later.
        container: VideoContainer.unknown,
      );
    }

    return VideoSource(
      messageId: msg.id,
      chatId: msg.chatId,
      fileSizeBytes: extractFileSize(msg),
      fileName: extractFileName(msg),
      mimeType: extractMimeType(msg),
      receivedAt: DateTime.fromMillisecondsSinceEpoch(msg.date * 1000),
      minithumbnailData: minithumbnail,
      tdlibDurationSeconds: tdDuration,
      metadata: initialMetadata,
    );
  }
}
