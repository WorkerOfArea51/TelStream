import 'package:flutter_test/flutter_test.dart';
import 'package:telstream/features/settings/settings_provider.dart';

void main() {
  group('Subtitle Customization Settings Tests', () {
    test('VideoSettings default values are set correctly', () {
      const settings = VideoSettings();
      expect(settings.subtitles.subtitleFontSize, 20.0);
      expect(settings.subtitles.subtitleColor, '#FFFFFF');
      expect(settings.subtitles.subtitleDelay, 0.0);
      expect(settings.subtitles.subtitleFont, 'Roboto');
    });

    test('VideoSettings.copyWith updates specific properties', () {
      const settings = VideoSettings();
      final updated = settings.copyWith(
        subtitles: settings.subtitles.copyWith(
          subtitleFontSize: 50.0,
          subtitleColor: '#FFFF00',
          subtitleDelay: 1.5,
          subtitleFont: 'Arial',
        ),
      );

      expect(updated.subtitles.subtitleFontSize, 50.0);
      expect(updated.subtitles.subtitleColor, '#FFFF00');
      expect(updated.subtitles.subtitleDelay, 1.5);
      expect(updated.subtitles.subtitleFont, 'Arial');

      // Unchanged properties remain the same
      expect(updated.layout.seekbarStyle, settings.layout.seekbarStyle);
    });

    test('VideoSettings toFlatJson and fromFlatJson match', () {
      final original = const VideoSettings().copyWith(
        subtitles: const SubtitleSettings().copyWith(
          subtitleFontSize: 60.0,
          subtitleColor: '#FF0000',
          subtitleDelay: -2.0,
          subtitleFont: 'DejaVuSans',
        ),
      );

      final json = original.toFlatJson();
      final fromJson = VideoSettings.fromFlatJson(json, 'auto');

      expect(fromJson.subtitles.subtitleFontSize, original.subtitles.subtitleFontSize);
      expect(fromJson.subtitles.subtitleColor, original.subtitles.subtitleColor);
      expect(fromJson.subtitles.subtitleDelay, original.subtitles.subtitleDelay);
      expect(fromJson.subtitles.subtitleFont, original.subtitles.subtitleFont);
    });
  });
}
