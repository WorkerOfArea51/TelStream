import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('lib/l10n/app_en.arb');
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final langs = ['ru','es','fr','de','ja','zh','hi','ar','pt','it','ko','tr','id','vi','th','bn','pl','uk','fa'];
  
  for (final l in langs) {
    final copy = Map<String, dynamic>.from(data);
    copy['@@locale'] = l;
    File('lib/l10n/app_$l.arb').writeAsStringSync(const JsonEncoder.withIndent('    ').convert(copy));
  }
}

