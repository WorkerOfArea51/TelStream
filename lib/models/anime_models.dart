import 'package:tdlib/td_api.dart' as td;
import '../services/storage_service.dart';

class AnimeSeries {
  final String coreName;
  final List<AnimeSeason> seasons;

  AnimeSeries({required this.coreName, required this.seasons});
}

class AnimeSeason {
  final String fullTitle;
  final String seasonName;
  final td.Message posterMessage; // The Photo message
  final List<td.Message> episodes; // The Video/Document messages

  AnimeSeason({
    required this.fullTitle,
    required this.seasonName,
    required this.posterMessage,
    required this.episodes,
  });

  int? getReleaseYear(StorageService storage) {
    final cached = storage.getSeasonReleaseYear(fullTitle);
    if (cached != null && cached > 0) return cached;

    // Try parsing from fullTitle
    final match = RegExp(r'(?<!\d)(19\d\d|20\d\d)(?!\d)').firstMatch(fullTitle);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    // Try parsing from episodes filenames
    for (final ep in episodes) {
      String? fileName;
      if (ep.content is td.MessageVideo) {
        fileName = (ep.content as td.MessageVideo).video.fileName;
      } else if (ep.content is td.MessageDocument) {
        fileName = (ep.content as td.MessageDocument).document.fileName;
      }
      if (fileName != null && fileName.isNotEmpty) {
        final epMatch = RegExp(r'(?<!\d)(19\d\d|20\d\d)(?!\d)').firstMatch(fileName);
        if (epMatch != null) {
          return int.tryParse(epMatch.group(1)!);
        }
      }
    }
    return null;
  }
}

