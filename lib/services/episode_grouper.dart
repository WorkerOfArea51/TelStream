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
  /// Builds a display title for an episode from its filename.
  /// Preserves the full title format (e.g. "EP - 01 - The Magic That Started Everything")
  /// but strips file extension, quality/codec tags, and bracketed release-group info.
  /// Leading emojis are preserved.
  static String _buildEpisodeTitle(td.Message msg, int epNum) {
    final rawTitle = TitleNormalizer.getMessageFileName(msg);
    final cleaned = TitleNormalizer.cleanDisplayTitle(rawTitle);

    if (cleaned.isEmpty) return 'Episode $epNum';

    return cleaned;
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
    final thumbnailFileId = extractThumbnailFileId(msg);

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
      thumbnailFileId: thumbnailFileId,
      tdlibDurationSeconds: tdDuration,
      metadata: initialMetadata,
    );
  }
}
