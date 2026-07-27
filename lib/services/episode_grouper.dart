import 'package:tdlib/td_api.dart' as td;
import '../models/episode.dart';
import '../models/video_source.dart';
import '../core/utils/title_normalizer.dart';
import '../core/utils/td_message_helpers.dart';

class EpisodeGrouper {
  static final _denylist = RegExp(r'\b(recap|pv|special|ova|ncop|nced)\b', caseSensitive: false);

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

      results.add(Episode(
        title: 'Episode $epNum',
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
        episodeNumber: TitleNormalizer.parseEpisodeNumber(msg),
      ));
    }

    // Sort all results. Grouped episodes first (by number), then isolated ones (by message ID)
    results.sort((a, b) {
      final numA = a.episodeNumber ?? 9999;
      final numB = b.episodeNumber ?? 9999;
      if (numA != numB) return numA.compareTo(numB);
      
      final msgA = a.messageId ?? 0;
      final msgB = b.messageId ?? 0;
      return msgA.compareTo(msgB);
    });

    return results;
  }

  static VideoSource _createSource(td.Message msg) {
    return VideoSource(
      messageId: msg.id,
      chatId: msg.chatId,
      fileSizeBytes: extractFileSize(msg),
      fileName: extractFileName(msg),
      mimeType: extractMimeType(msg),
      receivedAt: DateTime.fromMillisecondsSinceEpoch(msg.date * 1000),
    );
  }
}
