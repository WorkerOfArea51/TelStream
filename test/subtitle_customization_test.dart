import 'package:flutter_test/flutter_test.dart';
import 'package:telstream/features/settings/settings_provider.dart';

void main() {
  group('Subtitle Customization Settings Tests', () {
    test('VideoSettings default values are set correctly', () {
      const settings = VideoSettings();
      expect(settings.subtitleFontSize, 20.0);
      expect(settings.subtitleColor, '#FFFFFF');
      expect(settings.subtitleDelay, 0.0);
      expect(settings.subtitleFont, 'Roboto');
    });

    test('VideoSettings.copyWith updates specific properties', () {
      const settings = VideoSettings();
      final updated = settings.copyWith(
        subtitleFontSize: 50.0,
        subtitleColor: '#FFFF00',
        subtitleDelay: 1.5,
        subtitleFont: 'Arial',
      );

      expect(updated.subtitleFontSize, 50.0);
      expect(updated.subtitleColor, '#FFFF00');
      expect(updated.subtitleDelay, 1.5);
      expect(updated.subtitleFont, 'Arial');

      // Unchanged properties remain the same
      expect(updated.seekbarStyle, settings.seekbarStyle);
    });

    test('VideoSettings toJson and fromJson match', () {
      final original = const VideoSettings().copyWith(
        subtitleFontSize: 60.0,
        subtitleColor: '#FF0000',
        subtitleDelay: -2.0,
        subtitleFont: 'DejaVuSans',
      );

      final json = original.toJson();
      final fromJson = VideoSettings.fromJson(json);

      expect(fromJson.subtitleFontSize, original.subtitleFontSize);
      expect(fromJson.subtitleColor, original.subtitleColor);
      expect(fromJson.subtitleDelay, original.subtitleDelay);
      expect(fromJson.subtitleFont, original.subtitleFont);
    });
  });
}
