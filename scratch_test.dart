import 'dart:convert';
import 'dart:io';

void main() {
  final path = r'C:\Users\MidNight Hawk\AppData\Roaming\com.darkmatter\telstream\catalog_cache_Anime.json';
  final file = File(path);
  if (!file.existsSync()) return;
  final jsonList = json.decode(file.readAsStringSync()) as List;

  for (final series in jsonList) {
    final sName = (series['coreName'] ?? series['name'] ?? 'Unknown').toString();
    if (sName.toLowerCase().contains('naruto')) {
      print('Series: $sName');
      final seasons = series['seasons'] as List? ?? [];
      for (final s in seasons) {
        print('  Season title: ${s['fullTitle']}');
      }
    }
  }
}
