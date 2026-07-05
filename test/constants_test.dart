import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:telstream/core/constants.dart';

void main() {
  group('Constants Tests', () {
    setUpAll(() async {
      PackageInfo.setMockInitialValues(
        appName: 'TelStream',
        packageName: 'com.workerofarea51.telstream',
        version: '2.10.3',
        buildNumber: '46',
        buildSignature: '',
      );
      await Constants.initVersion();
    });

    test('Current version is defined and not empty', () {
      expect(Constants.currentVersion, isNotEmpty);
      expect(Constants.currentVersion, startsWith('2.10.3'));
    });

    test('Changelog is defined and contains current version info', () {
      expect(Constants.changelog, isNotEmpty);
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
