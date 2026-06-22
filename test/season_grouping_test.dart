import 'package:flutter_test/flutter_test.dart';
import 'package:telstream/features/home/home_controller.dart';
import 'package:telstream/services/storage_service.dart';
import 'package:tdlib/td_api.dart' as td;

class FakeStorageService implements StorageService {
  final Map<String, int> _years = {};

  @override
  int? getSeasonReleaseYear(String fullTitle) => _years[fullTitle];

  @override
  Future<void> setSeasonReleaseYear(String fullTitle, int year) async {
    _years[fullTitle] = year;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMessagePhoto implements td.MessagePhoto {
  @override
  final td.FormattedText caption = const td.FormattedText(text: '', entities: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMessage implements td.Message {
  @override
  final int id;
  @override
  final td.MessageContent content;

  FakeMessage({required this.id, required this.content});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Season Parsing & Grouping Tests', () {
    test('parseSeasonName parses standard season names correctly', () {
      expect(HomeController.parseSeasonName('Ranma ½', 'Ranma ½'), 'Season 1');
      expect(HomeController.parseSeasonName('Ranma ½ Nettouhen', 'Ranma ½'), 'Nettouhen');
      expect(HomeController.parseSeasonName('Ranma ½ (2024)', 'Ranma ½'), 'Season 1 (2024)');
      expect(HomeController.parseSeasonName('Ranma ½ (2024) 2nd Season', 'Ranma ½'), 'Season 2 (2024)');
      expect(HomeController.parseSeasonName('Ranma ½ (2024) Season 2', 'Ranma ½'), 'Season 2 (2024)');
      expect(HomeController.parseSeasonName('Ranma ½ - 2nd Season', 'Ranma ½'), 'Season 2');
    });

    test('normalizeSeriesName normalizes series names correctly', () {
      expect(HomeController.normalizeSeriesName('Ranma ½'), 'Ranma ½');
      expect(HomeController.normalizeSeriesName('Ranma ½ (2024)'), 'Ranma ½');
      expect(HomeController.normalizeSeriesName('Re:ZERO -Starting Life in Another World-'), 'Re:ZERO -Starting Life in Another World');
      expect(HomeController.normalizeSeriesName('👑 Re:ZERO -Starting Life in Another World- Season 1'), '👑 Re:ZERO -Starting Life in Another World');
      expect(HomeController.normalizeSeriesName('👑 Re:ZERO'), '👑 Re:ZERO');
      expect(HomeController.normalizeSeriesName('Re:Creators'), 'Re:Creators');
      expect(HomeController.normalizeSeriesName('Re: Creators'), 'Re: Creators');
    });


  });
}
