import 'dart:convert';
import 'dart:io';
import 'package:translator/translator.dart';

void main() async {
  final translator = GoogleTranslator();
  final dir = Directory('lib/l10n');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.arb') && !f.path.endsWith('app_en.arb')).toList();

  for (final file in files) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final lang = fileName.replaceAll('app_', '').replaceAll('.arb', '');
    print('Translating $fileName to $lang...');
    
    final content = await file.readAsString();
    final Map<String, dynamic> json = jsonDecode(content);
    
    final Map<String, dynamic> newJson = {};
    for (final key in json.keys) {
      if (key.startsWith('@@')) {
        newJson[key] = json[key];
        continue;
      }
      
      try {
        final translation = await translator.translate(json[key].toString(), from: 'en', to: lang);
        newJson[key] = translation.text;
      } catch (e) {
        print('Error translating $key for $lang: $e');
        newJson[key] = json[key]; // Fallback to original
      }
      // Small delay to prevent rate limit
      await Future.delayed(Duration(milliseconds: 50));
    }
    
    await file.writeAsString(JsonEncoder.withIndent('    ').convert(newJson));
    print('Finished $fileName\n');
  }
}
