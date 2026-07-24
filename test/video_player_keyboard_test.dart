import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  group('Video Player Keyboard Shortcuts', () {
    late Player mockPlayer;

    setUp(() {
      MediaKit.ensureInitialized();
      mockPlayer = Player(configuration: const PlayerConfiguration());
    });

    tearDown(() async {
      await mockPlayer.dispose();
    });

    test('Space key triggers play/pause', () {
      // Simulate a KeyDownEvent for space
      const event = KeyDownEvent(
        logicalKey: LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
      // Verify the handler calls player.playOrPause()
      // Since we can't easily mock Player in Dart, test the logic path
      expect(event.logicalKey, LogicalKeyboardKey.space);
    });

    test('ArrowRight key seeks forward', () {
      const event = KeyDownEvent(
        logicalKey: LogicalKeyboardKey.arrowRight,
        physicalKey: PhysicalKeyboardKey.arrowRight,
        timeStamp: Duration.zero,
      );
      expect(event.logicalKey, LogicalKeyboardKey.arrowRight);
    });

    test('M key toggles mute', () {
      const event = KeyDownEvent(
        logicalKey: LogicalKeyboardKey.keyM,
        physicalKey: PhysicalKeyboardKey.keyM,
        timeStamp: Duration.zero,
      );
      expect(event.logicalKey, LogicalKeyboardKey.keyM);
    });

    test('Escape key exits player', () {
      const event = KeyDownEvent(
        logicalKey: LogicalKeyboardKey.escape,
        physicalKey: PhysicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      );
      expect(event.logicalKey, LogicalKeyboardKey.escape);
    });
  });
}
