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

  // Clean series name for MAL search
  String _cleanTitleForMal(String title) {
    var clean = title.trim();
    // Remove release groups like [SubsPlease], [Erai-raws], [HorribleSubs]
    clean = clean.replaceAll(RegExp(r'\[[a-zA-Z0-9-\s\._~]+\]'), '');
    // Remove resolution patterns like [1080p], (720p), etc.
    clean = clean.replaceAll(RegExp(r'[\[\(]\d{3,4}p[\]\)]', caseSensitive: false), '');
    // Remove audio tags
    clean = clean.replaceAll(RegExp(r'(Dual|Multi)[-\s]Audio', caseSensitive: false), '');
    // Remove encode tags
    clean = clean.replaceAll(RegExp(r'(10bit|x265|hevc|x264|h264|bdrip|web-rip|webrip)', caseSensitive: false), '');
    // Remove season terms like Season 1, S1, S2, etc.
    clean = clean.replaceAll(RegExp(r'(Season\s+\d+|S\d+)', caseSensitive: false), '');
    // Remove square brackets and parentheses content
    clean = clean.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    clean = clean.replaceAll(RegExp(r'\([^)]*\)'), '');
    // Clean multiple spaces and special characters
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  Future<List<SkipInterval>> fetchSkipTimes({
    required String seriesName,
    required int episodeNumber,
    required double totalDuration,
  }) async {
    final cacheKey = '${seriesName}_$episodeNumber';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    List<SkipInterval> intervals = [];
    final cleanName = _cleanTitleForMal(seriesName);
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
        Log.i('Fetching AniSkip times for MAL ID: $malId, Ep: $episodeNumber');
        final url = Uri.parse('https://api.aniskip.com/v2/skip-times/$malId/$episodeNumber?types[]=op&types[]=ed');
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
      Log.w('Failed to fetch skip times from API for $seriesName (Ep $episodeNumber): $e');
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
