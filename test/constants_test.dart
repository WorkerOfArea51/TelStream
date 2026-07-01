import 'package:flutter_test/flutter_test.dart';
import 'package:telstream/core/constants.dart';

void main() {
  group('Constants Tests', () {
    test('Current version is defined and not empty', () {
      expect(Constants.currentVersion, isNotEmpty);
      expect(Constants.currentVersion, '2.9.9');
    });

    test('Changelog is defined and contains current version info', () {
      expect(Constants.changelog, isNotEmpty);
      expect(Constants.changelog, contains('v${Constants.currentVersion}'));
    });

    test('Categories list contains all required categories', () {
      expect(Constants.categories, isNotEmpty);
      expect(Constants.categories.length, equals(3));
      
      final titles = Constants.categories.map((c) => c.title).toList();
      expect(titles, contains('Anime'));
      expect(titles, contains('Movies'));
      expect(titles, contains('Web Series'));
    });
  });
}
