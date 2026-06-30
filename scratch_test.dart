import 'dart:convert';
import 'dart:io';

int? parseEpisodeNumber(String fileName) {
  final name = fileName.toLowerCase();
  
  // 1. Try matching patterns like e06, ep06, ep.06, ep - 06, episode 06, episode - 06, ep_06
  final epMatch = RegExp(
    r'\b(?:ep|episode|e|eps)\.?\s*[-–—_]*\s*(\d+)\b',
    caseSensitive: false,
  ).firstMatch(name);
  if (epMatch != null) {
    return int.tryParse(epMatch.group(1)!);
  }
  
  // 2. Try matching standalone numbers (like "- 01 -", " - 01.mkv", "001.mkv")
  final standaloneMatch = RegExp(
    r'(?:[-–—_]\s*|^)(\d+)(?:\s*[-–—_]|\.mkv|\.mp4|\.avi|\.webm|\.mov|\.flv|\.wmv|\.3gp|\.m4v|\.ts)\b',
    caseSensitive: false,
  ).firstMatch(name);
  if (standaloneMatch != null) {
    return int.tryParse(standaloneMatch.group(1)!);
  }
  
  // 3. Fallback: match any digits in the filename
  final fallbackMatch = RegExp(r'(\d+)').firstMatch(name);
  if (fallbackMatch != null) {
    return int.tryParse(fallbackMatch.group(1)!);
  }
  
  return null;
}

void main() {
  final path = r'C:\Users\MidNight Hawk\AppData\Roaming\com.darkmatter\telstream\catalog_cache_Anime.json';
  final file = File(path);
  if (!file.existsSync()) return;
  final jsonList = json.decode(file.readAsStringSync()) as List;

  final testSeries = ['bleach', 'naruto', 'dragon ball'];

  for (final series in jsonList) {
    final sName = (series['coreName'] ?? series['name'] ?? 'Unknown').toString();
    final lowerName = sName.toLowerCase();
    
    bool match = false;
    for (final t in testSeries) {
      if (lowerName.contains(t)) match = true;
    }
    if (!match) continue;

    print('\nSeries: $sName');
    final seasons = series['seasons'] as List? ?? [];
    for (final s in seasons) {
      final sName = s['seasonName'] ?? 'Unknown';
      print('  Season: $sName');
      final eps = s['episodes'] as List? ?? [];
      
      final List<Map<String, dynamic>> epList = [];
      for (final ep in eps) {
        final doc = ep['content']?['document'];
        final vid = ep['content']?['video'];
        final fileName = (doc?['file_name'] ?? vid?['file_name'] ?? '').toString();
        epList.add({
          'fileName': fileName,
          'epNum': parseEpisodeNumber(fileName) ?? 9999
        });
      }

      // Sort numerically by parsed episode number
      epList.sort((a, b) => (a['epNum'] as int).compareTo(b['epNum'] as int));

      print('    Sorted first 5 episodes:');
      for (var i = 0; i < 5 && i < epList.length; i++) {
        print('      - ${epList[i]['fileName']} (parsed ep: ${epList[i]['epNum']})');
      }
      print('    Sorted last 5 episodes:');
      for (var i = epList.length - 5; i < epList.length; i++) {
        if (i >= 0) {
          print('      - ${epList[i]['fileName']} (parsed ep: ${epList[i]['epNum']})');
        }
      }
    }
  }
}
