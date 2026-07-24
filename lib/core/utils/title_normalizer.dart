import 'package:tdlib/td_api.dart' as td;

class TitleNormalizer {
  static final _bracketSuffixRegex = RegExp(r'\s*[\[\(].*?[\]\)]\s*$');
  static final _seasonSuffixRegex = RegExp(r'(?:\s*[-—–|]\s*)?\b(?:(?:season|part)\s*(?:\d+|[ivxIVX]+)|s\s*\d+|s\s+[ivxIVX]+)\b', caseSensitive: false);
  static final _finalSeasonRegex = RegExp(r'(?:\s*[-—–|]\s*)?\b(?:the\s+)?final\s+(?:season|chapters?|act|arcs?|part)?\b', caseSensitive: false);
  static final _movieOvaRegex = RegExp(r'(?:\s*[-—–|]\s*)?\b(?:the\s+)?(?:movie|ova|oad|specials?|prequels?|sequels?)\b', caseSensitive: false);
  static final _romanNumeralRegex = RegExp(r'\s*\b[ivxIVX]+\b$', caseSensitive: false);
  static final _singleDigitRegex = RegExp(r'(?<!\bno)(?<!\bno\.)(?<!\bvol)(?<!\bvol\.)\s+\b\d\b$', caseSensitive: false);
  static final _singleLetterSRegex = RegExp(r'\s+\b[sS]\b$');
  static final _customSubtitlesRegex = RegExp(r'(?:\s*[-—–|]\s*)?\b(?:Memory\s+Snow|Frozen\s+Bond|Hyouketsu\s+no\s+Kizuna)\b', caseSensitive: false);
  static final _rootARegex = RegExp(r'(?:\s*[-—–|]\s*)?(?:root\s*a|root\s*alpha|√\s*a)\b', caseSensitive: false);
  static final _rePrefixRegex = RegExp(r'\b[rR][eE]\b$');
  static final _trailingPunctuationRegex = RegExp(r'\s*[-—–|]+\s*$');

  static String normalizeSeriesName(String name, {bool isMovie = false}) {
    var normalized = name.trim();

    // 1. Remove bracketed text at the end, e.g. [1080p], (Movie), etc.
    normalized = normalized.replaceAll(_bracketSuffixRegex, '');

    if (!isMovie) {
      // 2. Remove trailing season / part / movie indicators.
      normalized = normalized.replaceAll(_seasonSuffixRegex, '');
      normalized = normalized.replaceAll(_finalSeasonRegex, '');
      normalized = normalized.replaceAll(_movieOvaRegex, '');
      normalized = normalized.replaceAll(_romanNumeralRegex, '');
      normalized = normalized.replaceAll(_singleDigitRegex, '');
      normalized = normalized.replaceAll(_singleLetterSRegex, '');
      normalized = normalized.replaceAll(_customSubtitlesRegex, '');
      normalized = normalized.replaceAll(_rootARegex, '');

      // 3. Remove common trailing subtitles after a colon if the prefix has length > 3 and doesn't end with "Re"
      if (normalized.contains(':')) {
        final parts = normalized.split(':');
        final prefix = parts[0].trim();
        final isRePrefix = _rePrefixRegex.hasMatch(prefix);
        if (prefix.length > 3 && !isRePrefix) {
          normalized = prefix;
        }
      }
    }

    // 4. Remove bracketed text at the end again
    normalized = normalized.replaceAll(_bracketSuffixRegex, '');

    // Also clean up any trailing dashes, colons, or punctuation
    normalized = normalized.replaceAll(_trailingPunctuationRegex, '');

    return normalized.trim();
  }

  static String parseSeasonName(String fullTitle, String baseName, {bool isMovie = false}) {
    final ft = fullTitle.trim();
    final bn = baseName.trim();
    
    // Extract year suffix (like (2024) or [2024]) from the full title to preserve and append it.
    final yearMatch = RegExp(r'[\[\(](\d{4})[\]\)]').firstMatch(ft);
    if (yearMatch != null) {
      final year = yearMatch.group(1)!;
      final cleanFullTitle = ft.replaceAll(RegExp(r'\s*[\[\(]\d{4}[\]\)]\s*'), ' ').trim();
      final cleanSeason = parseSeasonName(cleanFullTitle, bn, isMovie: isMovie);
      if (cleanSeason.contains(year)) {
        return cleanSeason;
      }
      return '$cleanSeason ($year)';
    }

    if (ft.toLowerCase() == bn.toLowerCase()) {
      return isMovie ? 'Movie' : 'Season 1';
    }
    
    if (ft.length <= bn.length) {
      return isMovie ? 'Movie' : 'Season 1';
    }

    var diff = ft.substring(bn.length).trim();
    // Remove leading dashes, colons, spaces, punctuation
    diff = diff.replaceAll(RegExp(r'^[-—–:|,\s]+'), '').trim();
    
    if (diff.isEmpty) {
      return isMovie ? 'Movie' : 'Season 1';
    }

    // Check if diff is Root A or √A
    if (RegExp(r'^(?:√\s*a|root\s*a|root\s*alpha)$', caseSensitive: false).hasMatch(diff)) {
      return '√A';
    }
    
    // Check if diff is a Roman numeral (e.g. "II", "III")
    if (RegExp(r'^[ivxIVX]+$').hasMatch(diff)) {
      return 'Season $diff';
    }
    
    // Check if diff is just a single digit (e.g. "2", "3")
    if (RegExp(r'^\d+$').hasMatch(diff)) {
      return 'Season $diff';
    }
    
    return diff;
  }

  static String getMessageFileName(td.Message msg) {
    String fileName = '';
    String caption = '';

    if (msg.content is td.MessageVideo) {
      final video = msg.content as td.MessageVideo;
      fileName = video.video.fileName;
      caption = video.caption.text;
    } else if (msg.content is td.MessageDocument) {
      final doc = msg.content as td.MessageDocument;
      fileName = doc.document.fileName;
      caption = doc.caption.text;
    }

    if (caption.isNotEmpty) {
      final firstLine = caption.split('\n').first.trim();
      final lowerFirst = firstLine.toLowerCase();
      // If the first line of the caption is the full filename (ends with a known video extension)
      if (lowerFirst.endsWith('.mkv') || lowerFirst.endsWith('.mp4') || lowerFirst.endsWith('.avi') || lowerFirst.endsWith('.webm')) {
        return firstLine;
      }
      
      // Alternatively, if the original fileName was truncated by Telegram
      if (fileName.length >= 50) {
        final baseName = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        final prefix = baseName.length > 20 ? baseName.substring(0, 20) : baseName;
        
        final cleanPrefix = prefix.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
        final cleanFirstLine = firstLine.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
        
        if (firstLine.length > fileName.length && cleanFirstLine.startsWith(cleanPrefix)) {
          return firstLine;
        }
      }
    }

    return fileName;
  }

  static int parseEpisodeNumber(td.Message ep) {
    String fileName = getMessageFileName(ep);
    
    final name = fileName.toLowerCase();
    
    // 1. Match patterns like e06, ep06, ep.06, ep - 06, episode 06, episode - 06, ep_06
    final epMatch = RegExp(
      r'\b(?:ep|episode|e|eps)\.?\s*[-—–_]*\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(name);
    if (epMatch != null) {
      return int.tryParse(epMatch.group(1)!) ?? 9999;
    }
    
    // 2. Match standalone numbers followed by common extensions or separators
    final standaloneMatch = RegExp(
      r'(?:[-—–_]\s*|^)(\d+)(?:\s*[-—–_]|\.mkv|\.mp4|\.avi|\.webm|\.mov|\.flv|\.wmv|\.3gp|\.m4v|\.ts)\b',
      caseSensitive: false,
    ).firstMatch(name);
    if (standaloneMatch != null) {
      return int.tryParse(standaloneMatch.group(1)!) ?? 9999;
    }
    
    // 3. Fallback: match any digits in the filename
    final fallbackMatch = RegExp(r'(\d+)').firstMatch(name);
    if (fallbackMatch != null) {
      return int.tryParse(fallbackMatch.group(1)!) ?? 9999;
    }
    
    return 9999;
  }
}
