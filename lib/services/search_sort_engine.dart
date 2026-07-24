import '../models/anime_models.dart';
import '../features/home/home_controller.dart' show SortOrder;
import 'storage_service.dart';

int levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  List<int> v0 = List.generate(b.length + 1, (i) => i);
  List<int> v1 = List.filled(b.length + 1, 0);
  for (int i = 0; i < a.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < b.length; j++) {
      int cost = (a[i] == b[j]) ? 0 : 1;
      v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((min, val) => val < min ? val : min);
    }
    for (int j = 0; j <= b.length; j++) {
      v0[j] = v1[j];
    }
  }
  return v1[b.length];
}

class SeasonSortKey implements Comparable<SeasonSortKey> {
  final int seasonNum;
  final double partNum;
  final int messageId;
  final String original;
  final int releaseYear;
  final bool isExplicit;

  SeasonSortKey({
    required this.seasonNum,
    required this.partNum,
    required this.messageId,
    required this.original,
    required this.releaseYear,
    required this.isExplicit,
  });

  static int _parseRomanNumeral(String r) {
    switch (r.toLowerCase()) {
      case 'i': return 1;
      case 'ii': return 2;
      case 'iii': return 3;
      case 'iv': return 4;
      case 'v': return 5;
      case 'vi': return 6;
      case 'vii': return 7;
      case 'viii': return 8;
      case 'ix': return 9;
      case 'x': return 10;
      default: return 1;
    }
  }

  static SeasonSortKey fromSeason(AnimeSeason season, StorageService storage) {
    final name = season.seasonName;
    final lower = name.toLowerCase();
    final fullTitleLower = season.fullTitle.toLowerCase();
    int sNum = 1; // Default to 1 (base Season 1) if no numbers detected, so it sorts before Season 2+
    double pNum = 0.0;
    int year = 0;
    bool explicit = false;

    // Check if season fullTitle or name contains "arc" or "saga"
    if (fullTitleLower.contains('arc') || fullTitleLower.contains('saga') ||
        lower.contains('arc') || lower.contains('saga')) {
      year = 0; // Bypasses release year lookup
    } else {
      year = season.getReleaseYear(storage) ?? 0;
    }

    // Clean the name of part/volume indicators first to avoid matching their digits as season number.
    final lowerForSeason = lower
        .replaceAll(RegExp(r'\bpart\s*(\d+|[ivxIVX]+)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bvol(?:ume)?\s*(\d+|[ivxIVX]+)\b', caseSensitive: false), '')
        .trim();

    // Check for special keywords first
    if (lowerForSeason.contains('final season') || lowerForSeason.contains('final_season')) {
      sNum = 99;
      explicit = true;
    } else if (lowerForSeason.contains('ova') || lowerForSeason.contains('special') || lowerForSeason.contains('movie')) {
      sNum = 100;
      explicit = false;
    } else if (lowerForSeason.trim() == 'season s' || lowerForSeason.trim() == 's') {
      sNum = 2; // S suffix usually represents second season / sequel
      explicit = true;
    } else if (RegExp(r'^(?:âˆš\s*a|root\s*a|root\s*alpha)$', caseSensitive: false).hasMatch(lowerForSeason)) {
      sNum = 2; // Root A / âˆšA is the second season of Tokyo Ghoul
      explicit = true;
    } else {
      // 1. Look for Roman numerals first
      final romanMatch = RegExp(r'\b(i|ii|iii|iv|v|vi|vii|viii|ix|x)\b', caseSensitive: false).firstMatch(lowerForSeason);
      if (romanMatch != null) {
        sNum = _parseRomanNumeral(romanMatch.group(1)!);
        explicit = true;
      } else {
        // 2. Look for "season X" or "sX"
        final match = RegExp(r'(?:season|s)\s*(\d+)').firstMatch(lowerForSeason);
        if (match != null) {
          sNum = int.tryParse(match.group(1)!) ?? 1;
          explicit = true;
        } else if (fullTitleLower.contains('arc') || fullTitleLower.contains('saga') ||
                   lowerForSeason.contains('arc') || lowerForSeason.contains('saga')) {
          // Default to season 1 for all arcs/sagas unless they have an explicit season X tag
          sNum = 1;
          explicit = false;
        } else {
          // Look for a number at the start of the string (e.g. "1.Agent..." or "14.Lost...")
          final matchStart = RegExp(r'^\s*(\d+)').firstMatch(lowerForSeason);
          if (matchStart != null) {
            sNum = int.tryParse(matchStart.group(1)!) ?? 1;
            explicit = true;
          } else {
            // Look for any other isolated number in the season name
            final matchAny = RegExp(r'\b(\d+)\b').firstMatch(lowerForSeason);
            if (matchAny != null) {
              sNum = int.tryParse(matchAny.group(1)!) ?? 1;
              explicit = true;
            }
          }
        }
      }
    }

    // Look for "part X"
    final partMatch = RegExp(r'part\s*(\d+)').firstMatch(lower);
    if (partMatch != null) {
      pNum = double.tryParse(partMatch.group(1)!) ?? 0.0;
    } else if (lower.contains('final chapters') || lower.contains('final chapter')) {
      pNum = 9.0;
    }

    return SeasonSortKey(
      seasonNum: sNum,
      partNum: pNum,
      messageId: season.posterMessage.id,
      original: name,
      releaseYear: year,
      isExplicit: explicit,
    );
  }

  @override
  int compareTo(SeasonSortKey other) {
    return messageId.compareTo(other.messageId);
  }
}

class SearchPayload {
  final List<AnimeSeries> list;
  final String currentQuery;
  final SortOrder sortOrder;
  final Set<String> favorites;
  final bool showFavoritesOnly;
  final Map<String, int> releaseYears;

  SearchPayload({
    required this.list,
    required this.currentQuery,
    required this.sortOrder,
    required this.favorites,
    required this.showFavoritesOnly,
    required this.releaseYears,
  });
}

class SearchSortEngine {
  static List<AnimeSeries> computeSearchAndSort(SearchPayload payload) {
  List<AnimeSeries> favoritesFiltered = payload.list;
  if (payload.showFavoritesOnly) {
    favoritesFiltered = payload.list.where((s) => payload.favorites.contains(s.coreName)).toList();
  }

  List<AnimeSeries> filtered = favoritesFiltered;
  if (payload.currentQuery.isNotEmpty) {
    final queryWords = payload.currentQuery.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    
    filtered = favoritesFiltered.where((series) {
      final seriesName = series.coreName.toLowerCase();
      final seasonNames = series.seasons.map((s) => s.fullTitle.toLowerCase()).join(' ');
      final releaseYears = series.seasons
          .map((s) => payload.releaseYears[s.fullTitle])
          .where((y) => y != null && y > 0)
          .join(' ');
      final fullText = '$seriesName $seasonNames $releaseYears';
      
      final textWords = fullText.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
      
      bool allWordsMatch = true;
      for (var qw in queryWords) {
        bool wordFound = false;
        for (var tw in textWords) {
          if (tw.startsWith(qw) || tw.contains(qw)) {
            wordFound = true;
            break;
          }
          if (qw.length > 4 && tw.length > 4) {
            if (levenshtein(qw, tw) <= 2) {
              wordFound = true;
              break;
            }
          }
        }
        if (!wordFound) {
          allWordsMatch = false;
          break;
        }
      }
      return allWordsMatch;
    }).toList();
  }

  List<AnimeSeries> sorted = List.from(filtered);

  switch (payload.sortOrder) {
    case SortOrder.aToZ:
      sorted.sort((a, b) => a.coreName.compareTo(b.coreName));
      break;
    case SortOrder.zToA:
      sorted.sort((a, b) => b.coreName.compareTo(a.coreName));
      break;
    case SortOrder.newest:
      sorted.sort((a, b) {
        final idA = a.seasons.isNotEmpty ? a.seasons.last.posterMessage.id : 0;
        final idB = b.seasons.isNotEmpty ? b.seasons.last.posterMessage.id : 0;
        return idB.compareTo(idA);
      });
      break;
    case SortOrder.oldest:
      sorted.sort((a, b) {
        final idA = a.seasons.isNotEmpty ? a.seasons.first.posterMessage.id : 0;
        final idB = b.seasons.isNotEmpty ? b.seasons.first.posterMessage.id : 0;
        return idA.compareTo(idB);
      });
      break;
  }

  for (var series in sorted) {
    final key = series.coreName.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    if (key == 'naruto') {
      series.seasons.sort((a, b) {
        // Can't use storage in isolate, so use basic parsing
        final matchA = RegExp(r'season\s*(\d+)', caseSensitive: false).firstMatch(a.seasonName);
        final matchB = RegExp(r'season\s*(\d+)', caseSensitive: false).firstMatch(b.seasonName);
        final sA = matchA != null ? (int.tryParse(matchA.group(1)!) ?? 0) : 0;
        final sB = matchB != null ? (int.tryParse(matchB.group(1)!) ?? 0) : 0;
        int cmp = sA.compareTo(sB);
        if (cmp != 0) return cmp;
        return a.posterMessage.id.compareTo(b.posterMessage.id);
      });
    } else {
      series.seasons.sort((a, b) => a.posterMessage.id.compareTo(b.posterMessage.id));
    }
  }

  return sorted;
}
}
