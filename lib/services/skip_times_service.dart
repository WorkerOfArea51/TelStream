import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logger.dart';
import 'storage_service.dart';

class SkipInterval {
  final double startTime;
  final double endTime;
  final String type; // 'op' (Opening/Intro) or 'ed' (Ending/Outro)

  const SkipInterval({
    required this.startTime,
    required this.endTime,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'startTime': startTime,
        'endTime': endTime,
        'type': type,
      };

  factory SkipInterval.fromJson(Map<String, dynamic> json) => SkipInterval(
        startTime: (json['startTime'] as num).toDouble(),
        endTime: (json['endTime'] as num).toDouble(),
        type: json['type'] as String,
      );
}

final skipTimesServiceProvider = Provider<SkipTimesService>((ref) {
  return SkipTimesService(ref.watch(storageServiceProvider));
});

class SkipTimesService {
  final StorageService _storageService;
  final Map<String, List<SkipInterval>> _memoryCache = {};

  SkipTimesService(this._storageService);

  String? _extractSeason(String title) {
    // Match "Season 2", "Season 02", "S2", "S02"
    final match = RegExp(r'(?:Season\s*|S)(\d+)', caseSensitive: false).firstMatch(title);
    if (match != null) {
      final seasonNum = int.tryParse(match.group(1)!);
      if (seasonNum != null) {
        return 'Season $seasonNum';
      }
    }
    // Match "2nd Season", "1st Season", etc.
    final matchOrder = RegExp(r'(\d+)(?:st|nd|rd|th)\s*Season', caseSensitive: false).firstMatch(title);
    if (matchOrder != null) {
      final seasonNum = int.tryParse(matchOrder.group(1)!);
      if (seasonNum != null) {
        return 'Season $seasonNum';
      }
    }
    return null;
  }

  // Clean series name for MAL search
  String _cleanTitleForMal(String title) {
    var clean = title.trim();
    // Remove file extensions
    clean = clean.replaceAll(RegExp(r'\.(?:mkv|mp4|avi|webm|flv|mov|ts|m4v)$', caseSensitive: false), '');
    // Remove release groups like [SubsPlease], [Erai-raws], [HorribleSubs]
    clean = clean.replaceAll(RegExp(r'\[[a-zA-Z0-9-\s\._~]+\]'), '');
    // Remove resolution patterns like [1080p], (720p), etc.
    clean = clean.replaceAll(RegExp(r'[\[\(]\d{3,4}p[\]\)]', caseSensitive: false), '');
    // Remove audio tags
    clean = clean.replaceAll(RegExp(r'(Dual|Multi)[-\s]Audio', caseSensitive: false), '');
    // Remove encode tags
    clean = clean.replaceAll(RegExp(r'(10bit|x265|hevc|x264|h264|bdrip|web-rip|webrip)', caseSensitive: false), '');
    
    // Strip episode numbers at the end, but preserve season numbers (e.g. S2, Season 2)
    clean = clean.replaceAll(RegExp(r'(?:[-\s]+(?:Episode|Ep)\s*\d+|[-\s]+\d+)\s*$', caseSensitive: false), '');

    // Remove square brackets and parentheses content
    clean = clean.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    clean = clean.replaceAll(RegExp(r'\([^)]*\)'), '');
    // Clean multiple spaces and special characters
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  int? _extractEpisodeNumber(String title) {
    // Clean brackets and parentheses first to avoid false matching inside release tags/resolutions
    var clean = title.replaceAll(RegExp(r'\[[^\]]*\]'), '').replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    // Remove file extensions
    clean = clean.replaceAll(RegExp(r'\.(?:mkv|mp4|avi|webm|flv|mov|ts|m4v)$', caseSensitive: false), '').trim();
    
    // 1. Match typical formats: Episode 12, Ep. 12, Ep 12, E12, EP12
    final epMatch = RegExp(r'\b(?:Episode|Ep|E)\.?\s*(\d{1,3})\b', caseSensitive: false).firstMatch(clean);
    if (epMatch != null) {
      return int.tryParse(epMatch.group(1)!);
    }
    
    // 2. Match a standalone episode number at the end or after a dash, e.g. "Title - 12", "Title 03"
    final numberMatch = RegExp(r'(?:-\s*|(?:\s+))\b(\d{1,3})\b(?:\s*v\d+)?\s*$', caseSensitive: false).firstMatch(clean);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(1)!);
    }
    
    // 3. Fallback: match any standalone 2-3 digit number in the clean title
    final fallbackMatch = RegExp(r'\b(\d{2,3})\b').firstMatch(clean);
    if (fallbackMatch != null) {
      return int.tryParse(fallbackMatch.group(1)!);
    }

    return null;
  }

  Future<List<SkipInterval>> fetchSkipTimes({
    required String seriesName,
    required int episodeNumber,
    required double totalDuration,
    String? videoTitle,
  }) async {
    var finalSeriesName = seriesName;
    var finalEpisodeNumber = episodeNumber;

    if (videoTitle != null && videoTitle.isNotEmpty) {
      // 1. If seriesName is empty, clean the videoTitle and use it as the series search query
      if (finalSeriesName.isEmpty) {
        finalSeriesName = _cleanTitleForMal(videoTitle);
        Log.i('Extracted series name "$finalSeriesName" from video title: "$videoTitle"');
      }
      
      // 2. If episodeNumber is 1 (default fallback), try to parse the actual episode number from the title
      if (episodeNumber == 1) {
        final extractedEp = _extractEpisodeNumber(videoTitle);
        if (extractedEp != null) {
          finalEpisodeNumber = extractedEp;
          Log.i('Extracted episode number $finalEpisodeNumber from video title: "$videoTitle"');
        }
      }
    }

    final cacheKey = '${finalSeriesName}_$finalEpisodeNumber';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    List<SkipInterval> intervals = [];
    var searchQuery = finalSeriesName;

    // Detect and append season to MAL search query if not already present in the folder name
    if (videoTitle != null && videoTitle.isNotEmpty) {
      final season = _extractSeason(videoTitle);
      if (season != null && !searchQuery.toLowerCase().contains(season.toLowerCase())) {
        searchQuery = '$searchQuery $season';
      }
    }

    final cleanName = _cleanTitleForMal(searchQuery);
    if (cleanName.isEmpty) return _getHeuristicFallback(totalDuration);

    try {
      int? malId = _storageService.getMalIdForSeries(cleanName);
      
      // If not cached, search Jikan MAL API
      if (malId == null) {
        Log.i('Searching MAL for anime: $cleanName');
        final url = Uri.parse('https://api.jikan.moe/v4/anime?q=${Uri.encodeComponent(cleanName)}&limit=1');
        final response = await http.get(url).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['data'] as List?;
          if (results != null && results.isNotEmpty) {
            malId = results.first['mal_id'] as int?;
            if (malId != null) {
              await _storageService.setMalIdForSeries(cleanName, malId);
              Log.i('Found and cached MAL ID $malId for $cleanName');
            }
          }
        }
      }

      // If we found a MAL ID, query AniSkip
      if (malId != null) {
        Log.i('Fetching AniSkip times for MAL ID: $malId, Ep: $finalEpisodeNumber');
        final url = Uri.parse('https://api.aniskip.com/v2/skip-times/$malId/$finalEpisodeNumber?types[]=op&types[]=ed');
        final response = await http.get(url).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final found = data['found'] as bool? ?? false;
          if (found) {
            final results = data['results'] as List?;
            if (results != null) {
              for (final res in results) {
                final type = res['skip_type'] as String; // 'op' or 'ed'
                final interval = res['interval'] as Map?;
                if (interval != null) {
                  final start = (interval['start_time'] as num).toDouble();
                  final end = (interval['end_time'] as num).toDouble();
                  intervals.add(SkipInterval(startTime: start, endTime: end, type: type));
                }
              }
              Log.i('Successfully fetched ${intervals.length} skip intervals from AniSkip');
            }
          }
        }
      }
    } catch (e) {
      Log.w('Failed to fetch skip times from API for $finalSeriesName (Ep $finalEpisodeNumber): $e');
    }

    // Fallback if no skip times fetched (e.g. not an anime, API error, or no entry)
    if (intervals.isEmpty) {
      intervals = _getHeuristicFallback(totalDuration);
    }

    _memoryCache[cacheKey] = intervals;
    return intervals;
  }

  List<SkipInterval> _getHeuristicFallback(double totalDuration) {
    return [];
  }
}
