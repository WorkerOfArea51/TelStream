import 'package:tdlib/td_api.dart' as td;
import '../models/episode.dart';
import '../models/video_source.dart';
import '../core/utils/title_normalizer.dart';

class EpisodeGrouper {
  static List<Episode> groupEpisodes(List<td.Message> messages) {
    // 1. Group messages by episode number
    final Map<int, List<td.Message>> epMap = {};
    for (final msg in messages) {
      final epNum = TitleNormalizer.parseEpisodeNumber(msg);
      epMap.putIfAbsent(epNum, () => []).add(msg);
    }

    // 2. Sort the groups by episode number
    final sortedEpNums = epMap.keys.toList()..sort();
    
    // 3. For each group, create an Episode with multiple VideoSources
    final List<Episode> results = [];
    for (final epNum in sortedEpNums) {
      final msgs = epMap[epNum]!;
      final sources = msgs.map((m) {
        return VideoSource(
          message: m,
          qualityLabel: TitleNormalizer.extractQuality(m),
          width: 0, // Will be updated by metadata extractor later
          height: 0,
        );
      }).toList();
      
      // Try to determine a title for the episode
      final bestMsg = msgs.first;
      String rawTitle = TitleNormalizer.getMessageFileName(bestMsg);
      final cleanTitle = rawTitle.replaceAll(RegExp(r'\.(mkv|mp4|avi|webm|mov|flv|wmv|ts|m4v|3gp)$', caseSensitive: false), '').replaceAll('_', ' ').trim();
      
      final title = epNum != 9999 ? 'Episode $epNum' : (cleanTitle.isNotEmpty ? cleanTitle : 'Video ${bestMsg.id}');

      results.add(Episode(
        title: title,
        sources: sources,
        isMetadataExtracted: false,
      ));
    }
    
    return results;
  }
}
