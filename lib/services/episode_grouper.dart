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
  /// Examples:
  ///   "EP - 01 - The Magic That Started Everything.mkv" → "Episode 1 - The Magic That Started Everything"
  ///   "Show.S01E05.The.Big.Bang.mp4"                     → "Episode 5 - The Big Bang"
  ///   "Episode 3 - Punishment Posting.mkv"               → "Episode 3 - Punishment Posting"
  ///   "01.mkv"                                           → "Episode 1"
  static String _buildEpisodeTitle(td.Message msg, int epNum) {
    final fileName = TitleNormalizer.getMessageFileName(msg);
    // Remove file extension
    final baseName = fileName.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');

    // Try pattern: (ep|episode|eps)[. _-]* N [-_–] <descriptive title>
    final epTitleMatch = RegExp(
      r'(?:ep|episode|eps)\.?\s*[-—–_]*\s*\d{1,3}\s*[-—–_:]\s*(.+)',
      caseSensitive: false,
    ).firstMatch(baseName);

    if (epTitleMatch != null) {
      final desc = epTitleMatch.group(1)!
          .replaceAll('_', ' ')
          .replaceAll('.', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (desc.isNotEmpty && desc.toLowerCase() != 'episode') {
        return 'Episode $epNum - $desc';
      }
    }

    // Try S##E## pattern: Show.S01E05.The.Big.Bang → "The Big Bang"
    final sxxExxMatch = RegExp(
      r's\d{1,2}\s*e\d{1,3}\s*[-—–_.]\s*(.+)',
      caseSensitive: false,
    ).firstMatch(baseName);

    if (sxxExxMatch != null) {
      final desc = sxxExxMatch.group(1)!
          .replaceAll('_', ' ')
          .replaceAll('.', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (desc.isNotEmpty) {
        return 'Episode $epNum - $desc';
      }
    }

    // Fallback: just the number
    return 'Episode $epNum';
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

    // Process isolated episodes
    for (final msg in isolatedMessages) {
      final source = _createSource(msg);
      String rawTitle = TitleNormalizer.getMessageFileName(msg);
      final cleanTitle = rawTitle
          .replaceAll(RegExp(r'\.(mkv|mp4|avi|webm|mov|flv|wmv|ts|m4v|3gp)$', caseSensitive: false), '')
          .replaceAll('_', ' ')
          .trim();

      results.add(Episode(
        title: cleanTitle.isNotEmpty ? cleanTitle : 'Video ${msg.id}',
        sources: [source],
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
