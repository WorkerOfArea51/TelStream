import 'package:flutter_test/flutter_test.dart';
import 'package:telstream/features/home/home_controller.dart';
import 'package:telstream/services/storage_service.dart';
import 'package:telstream/core/constants.dart';
import 'package:telstream/models/anime_models.dart';
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
  final td.FormattedText caption;

  FakeMessagePhoto(String text)
      : caption = td.FormattedText(text: text, entities: const []);

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

class TestHomeController extends HomeController {
  @override
  ChannelCategory get category => const ChannelCategory(
        title: 'Anime',
        channelId: 1,
        inviteLink: '',
      );

  List<AnimeSeries> testParse(List<td.Message> raw) {
    return parseMessagesForTesting(raw);
  }
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
      expect(HomeController.parseSeasonName('Re:ZERO -Starting Life in Another World- Memory Snow', 'Re:ZERO -Starting Life in Another World'), 'Memory Snow');
      expect(HomeController.parseSeasonName('Re:ZERO -Starting Life in Another World- Frozen Bond', 'Re:ZERO -Starting Life in Another World'), 'Frozen Bond');
    });

    test('normalizeSeriesName normalizes series names correctly', () {
      expect(HomeController.normalizeSeriesName('Ranma ½'), 'Ranma ½');
      expect(HomeController.normalizeSeriesName('Ranma ½ (2024)'), 'Ranma ½');
      expect(HomeController.normalizeSeriesName('Re:ZERO -Starting Life in Another World-'), 'Re:ZERO -Starting Life in Another World');
      expect(HomeController.normalizeSeriesName('👑 Re:ZERO -Starting Life in Another World- Season 1'), '👑 Re:ZERO -Starting Life in Another World');
      expect(HomeController.normalizeSeriesName('👑 Re:ZERO'), '👑 Re:ZERO');
      expect(HomeController.normalizeSeriesName('Re:Creators'), 'Re:Creators');
      expect(HomeController.normalizeSeriesName('Re: Creators'), 'Re: Creators');
      expect(HomeController.normalizeSeriesName('Re:ZERO -Starting Life in Another World- Memory Snow'), 'Re:ZERO -Starting Life in Another World');
      expect(HomeController.normalizeSeriesName('Re:ZERO -Starting Life in Another World- Frozen Bond'), 'Re:ZERO -Starting Life in Another World');
    });

    test('franchise grouping bypass separates Dragon Ball, Z, and Daima', () {
      final controller = TestHomeController();

      // We will parse messages in the correct sequence.
      // E.g. we post Dragon Ball Daima, Dragon Ball Z, then Dragon Ball.
      final messages = [
        FakeMessage(
          id: 3,
          content: FakeMessagePhoto('Dragon Ball Daima : Episode 1'),
        ),
        FakeMessage(
          id: 2,
          content: FakeMessagePhoto('Dragon Ball Z : 1.Saiyan Saga'),
        ),
        FakeMessage(
          id: 1,
          content: FakeMessagePhoto('Dragon Ball : 1.Emperor Pilaf Saga'),
        ),
      ];

      final seriesList = controller.testParse(messages);

      // They should NOT be merged. We should get 3 separate series.
      expect(seriesList.length, 3);
      expect(seriesList[0].coreName, 'Dragon Ball Daima');
      expect(seriesList[1].coreName, 'Dragon Ball Z');
      expect(seriesList[2].coreName, 'Dragon Ball');
    });

    test('Naruto seasons sort numerically even when message IDs are uploaded out-of-order', () {
      final controller = TestHomeController();
      final mockStorage = FakeStorageService();
      controller.testStorage = mockStorage;

      // We parse messages for Naruto. S4 is uploaded after S9 (higher message ID).
      final messages = [
        FakeMessage(
          id: 4, // Uploaded last
          content: FakeMessagePhoto('Naruto : Season 4'),
        ),
        FakeMessage(
          id: 3, // Uploaded third
          content: FakeMessagePhoto('Naruto : Season 9'),
        ),
        FakeMessage(
          id: 2, // Uploaded second
          content: FakeMessagePhoto('Naruto : Season 8'),
        ),
        FakeMessage(
          id: 1, // Uploaded first
          content: FakeMessagePhoto('Naruto : Season 7'),
        ),
      ];

      // Parse the messages to build the series structures
      final seriesList = controller.testParse(messages);
      expect(seriesList.length, 1);
      expect(seriesList[0].coreName, 'Naruto');

      // Now apply the search and sort (which runs the numeric season sorting exception for Naruto)
      final sortedSeries = controller.applySearchAndSortForTesting(seriesList);
      final seasons = sortedSeries[0].seasons;

      expect(seasons.length, 4);
      // The seasons should be ordered strictly by season number ascending: Season 4, Season 7, Season 8, Season 9
      expect(seasons[0].seasonName, 'Season 4');
      expect(seasons[1].seasonName, 'Season 7');
      expect(seasons[2].seasonName, 'Season 8');
      expect(seasons[3].seasonName, 'Season 9');
    });
  });
}
