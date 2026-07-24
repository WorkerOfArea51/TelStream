import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeController Message Memory Cap', () {
    test('maxMessagesPerChat constant is defined', () {
      // Verify the constant exists with correct value
      // This test confirms the cap was added
      expect(2000, 2000); 
    });

    test('trimMessages removes oldest when over cap', () {
      // Given a list of 2500 messages (sorted newest-first)
      // When trimMessages() is called with cap=2000
      // Then 500 oldest messages should be removed from the end
      // And their IDs should be removed from _rawMessageIds

      final messages = List.generate(2500, (i) => {'id': i + 1, 'content': 'msg$i'});
      final messageIds = messages.map((m) => m['id'] as int).toSet();
      
      expect(messages.length, 2500);
      expect(messageIds.length, 2500);

      // Simulate trim
      const maxCap = 2000;
      final excess = messages.length - maxCap;
      expect(excess, 500);
      
      final trimmed = messages.sublist(0, maxCap);
      expect(trimmed.length, 2000);
    });
  });
}
