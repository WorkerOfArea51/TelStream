import 'package:flutter_test/flutter_test.dart';
import 'package:telstream/features/home/home_controller.dart';
import 'package:telstream/models/anime_models.dart';
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
    });

    test('season group consecutive numbering logic works correctly', () {
      final seasons = [
        AnimeSeason(
          fullTitle: 'Ranma ½',
          seasonName: 'Season 1',
          posterMessage: FakeMessage(id: 1, content: FakeMessagePhoto()),
          episodes: [],
        ),
        AnimeSeason(
          fullTitle: 'Ranma ½ Nettouhen',
          seasonName: 'Nettouhen',
          posterMessage: FakeMessage(id: 2, content: FakeMessagePhoto()),
          episodes: [],
        ),
        AnimeSeason(
          fullTitle: 'Ranma ½ (2024)',
          seasonName: 'Season 1 (2024)',
          posterMessage: FakeMessage(id: 3, content: FakeMessagePhoto()),
          episodes: [],
        ),
        AnimeSeason(
          fullTitle: 'Ranma ½ (2024) 2nd Season',
          seasonName: 'Season 2 (2024)',
          posterMessage: FakeMessage(id: 4, content: FakeMessagePhoto()),
          episodes: [],
        ),
      ];

      final storage = FakeStorageService();
      storage.setSeasonReleaseYear('Ranma ½', 1989);
      storage.setSeasonReleaseYear('Ranma ½ Nettouhen', 1989);
      storage.setSeasonReleaseYear('Ranma ½ (2024)', 2024);
      storage.setSeasonReleaseYear('Ranma ½ (2024) 2nd Season', 2024);

      // Perform run partitioning
      final List<List<int>> runs = [];
      if (seasons.isNotEmpty) {
        runs.add([0]);
        for (int i = 1; i < seasons.length; i++) {
          final prevSeason = seasons[i - 1];
          final currSeason = seasons[i];

          final prevName = prevSeason.seasonName;
          final currName = currSeason.seasonName;

          final prevYearMatch = RegExp(r'[\[\(](\d{4})[\]\)]').firstMatch(prevName);
          final currYearMatch = RegExp(r'[\[\(](\d{4})[\]\)]').firstMatch(currName);

          final prevSuffixYear = prevYearMatch?.group(1);
          final currSuffixYear = currYearMatch?.group(1);

          bool isNewRun = false;
          if (prevSuffixYear != currSuffixYear) {
            isNewRun = true;
          } else {
            final prevYear = prevSeason.getReleaseYear(storage) ?? 0;
            final currYear = currSeason.getReleaseYear(storage) ?? 0;
            if (prevYear > 0 && currYear > 0 && (currYear - prevYear).abs() > 3) {
              isNewRun = true;
            }
          }

          if (isNewRun) {
            runs.add([i]);
          } else {
            runs.last.add(i);
          }
        }
      }

      expect(runs.length, 2);
      expect(runs[0], [0, 1]);
      expect(runs[1], [2, 3]);

      // Apply renaming within each run
      for (final indices in runs) {
        int currentSeasonNum = 1;
        for (final idx in indices) {
          final season = seasons[idx];
          final name = season.seasonName;
          final match = RegExp(r'^Season\s+(\d+|[ivxIVX]+)(.*)$').firstMatch(name);
          if (match != null) {
            final suffix = match.group(2) ?? '';
            final newName = 'Season $currentSeasonNum$suffix';
            seasons[idx] = season.copyWith(seasonName: newName);
            currentSeasonNum++;
          }
        }
      }

      expect(seasons[0].seasonName, 'Season 1');
      expect(seasons[1].seasonName, 'Nettouhen');
      expect(seasons[2].seasonName, 'Season 1 (2024)');
      expect(seasons[3].seasonName, 'Season 2 (2024)');
    });
  });
}
