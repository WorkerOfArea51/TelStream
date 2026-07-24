import 'package:tdlib/td_api.dart' as td;
import '../models/anime_models.dart';
import '../core/utils/title_normalizer.dart';

class SeriesParser {
  static List<AnimeSeries> parseMessagesBackground(List<td.Message> raw, bool isMovie) {
  
  // 1. Separate poster messages and episode messages
  final List<td.Message> posterMessages = [];
  final List<td.Message> episodeMessages = [];

  for (final msg in raw) {
    if (msg.content is td.MessagePhoto) {
      final photo = msg.content as td.MessagePhoto;
      if (photo.caption.text.isNotEmpty) {
        posterMessages.add(msg);
      }
    } else if (msg.content is td.MessageVideo) {
      episodeMessages.add(msg);
    } else if (msg.content is td.MessageDocument) {
      final fileName = TitleNormalizer.getMessageFileName(msg).toLowerCase();
      final doc = msg.content as td.MessageDocument;
      if (doc.document.mimeType.startsWith('video/') ||
          fileName.endsWith('.mkv') ||
          fileName.endsWith('.mp4') ||
          fileName.endsWith('.avi') ||
          fileName.endsWith('.mov') ||
          fileName.endsWith('.webm') ||
          fileName.endsWith('.flv') ||
          fileName.endsWith('.wmv')) {
        episodeMessages.add(msg);
      }
    }
  }

  // 2. Pre-process poster details & initialize series map/list
  final List<Map<String, dynamic>> posterDetails = [];
  final Map<String, AnimeSeries> seriesMap = {};
  final List<AnimeSeries> seriesList = [];

  for (final pMsg in posterMessages) {
    final photo = pMsg.content as td.MessagePhoto;
    final captionText = photo.caption.text;
    final lines = captionText.split('\n');
    final fullTitle = lines.first.trim();
    final baseName = TitleNormalizer.normalizeSeriesName(fullTitle, isMovie: isMovie);
    
    final canonicalKey = baseName.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    String matchedKey = isMovie ? '${canonicalKey}_${pMsg.id}' : canonicalKey;

    if (!isMovie) {
      for (final existingKey in seriesMap.keys) {
        if (existingKey.length >= 7 && canonicalKey.length >= 7) {
          // Bypass prefix/substring grouping for franchise sequels/spinoffs
          bool isFranchiseBypass = false;
          const franchisePrefixes = ['dragonball', 'naruto', 'onepiece', 'bleach'];
          for (final prefix in franchisePrefixes) {
            if ((canonicalKey.startsWith(prefix) || existingKey.startsWith(prefix)) &&
                canonicalKey != existingKey) {
              isFranchiseBypass = true;
              break;
            }
          }
          if (isFranchiseBypass) continue;

          if (canonicalKey.startsWith(existingKey)) {
            matchedKey = existingKey;
            break;
          } else if (existingKey.startsWith(canonicalKey)) {
            matchedKey = existingKey;
            final existingSeries = seriesMap[existingKey]!;
            if (baseName.length < existingSeries.coreName.length) {
              seriesMap[existingKey] = AnimeSeries(
                coreName: baseName,
                seasons: existingSeries.seasons,
              );
              final idx = seriesList.indexOf(existingSeries);
              if (idx != -1) {
                seriesList[idx] = seriesMap[existingKey]!;
              }
              break;
            }
          }
        }
      }
    }

    if (!seriesMap.containsKey(matchedKey)) {
      seriesMap[matchedKey] = AnimeSeries(coreName: baseName, seasons: []);
      seriesList.add(seriesMap[matchedKey]!);
    }

    posterDetails.add({
      'message': pMsg,
      'fullTitle': fullTitle,
      'baseName': baseName,
      'matchedKey': matchedKey,
      'episodesList': <td.Message>[],
    });
    
  }

  // 3. Match each episode message to its preceding poster message (pure sequential chronological)
  for (final ep in episodeMessages) {
    Map<String, dynamic>? selectedPoster;
    int maxPrecedingId = -1;

    for (final pd in posterDetails) {
      final pMsg = pd['message'] as td.Message;
      if (pMsg.id < ep.id && pMsg.id > maxPrecedingId) {
        maxPrecedingId = pMsg.id;
        selectedPoster = pd;
      }
    }
    


    if (selectedPoster != null) {
      (selectedPoster['episodesList'] as List<td.Message>).add(ep);
    } else {
      // No poster found â€” create a standalone poster from the video itself.
      // This handles user channels where videos are posted without preceding text/photo posts.
      final epFileName = TitleNormalizer.getMessageFileName(ep);
      final epTitle = epFileName.isNotEmpty 
          ? epFileName.replaceAll(RegExp(r'\.(mkv|mp4|avi|mov|webm|flv|wmv|ts|m4v|3gp)$', caseSensitive: false), '').replaceAll('_', ' ').trim()
          : 'Video ${ep.id}';
      final epBaseName = TitleNormalizer.normalizeSeriesName(epTitle, isMovie: isMovie);
      final epKey = isMovie ? '${epBaseName}_${ep.id}' : epBaseName.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
      
      // Create a synthetic poster entry using the video message itself as the "poster"
      final standalonePoster = {
        'message': ep,
        'fullTitle': epTitle,
        'baseName': epBaseName,
        'matchedKey': epKey,
        'episodesList': <td.Message>[ep],
      };
      posterDetails.add(standalonePoster);
      
      if (!seriesMap.containsKey(epKey)) {
        seriesMap[epKey] = AnimeSeries(coreName: epBaseName, seasons: []);
        seriesList.add(seriesMap[epKey]!);
      }
    }
    // Yield to keep UI smooth (Removed fake concurrency)
  }

  // 4. Assemble seasons and populate the series list
  for (final pd in posterDetails) {
    final pMsg = pd['message'] as td.Message;
    final fullTitle = pd['fullTitle'] as String;
    final baseName = pd['baseName'] as String;
    final matchedKey = pd['matchedKey'] as String;
    final rawEps = pd['episodesList'] as List<td.Message>;

    // Sort episodes inside the season numerically by episode number parsed from filename
    final sortedEpisodes = List<td.Message>.from(rawEps)
      ..sort((a, b) {
        final epA = TitleNormalizer.parseEpisodeNumber(a);
        final epB = TitleNormalizer.parseEpisodeNumber(b);
        if (epA != epB) {
          return epA.compareTo(epB);
        }
        return a.id.compareTo(b.id);
      });

    final newSeason = AnimeSeason(
      fullTitle: fullTitle,
      seasonName: TitleNormalizer.parseSeasonName(fullTitle, baseName, isMovie: isMovie),
      posterMessage: pMsg,
      episodes: sortedEpisodes,
    );

    final series = seriesMap[matchedKey];
    if (series != null) {
      final existingIndex = series.seasons.indexWhere((s) => s.posterMessage.id == pMsg.id);
      if (existingIndex != -1) {
        series.seasons[existingIndex] = newSeason;
      } else {
        series.seasons.add(newSeason);
      }
    }
  }

  return seriesList;
}
}
