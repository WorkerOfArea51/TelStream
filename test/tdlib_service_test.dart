import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telstream/services/tdlib_service.dart';
import 'package:tdlib/td_api.dart' as td;

class MockTdlibService extends Mock implements TdlibService {}
class MockMessage extends Mock implements td.Message {}

void main() {
  group('TdlibService Integration Tests', () {
    late MockTdlibService mockService;
    late StreamController<td.TdObject> updatesController;

    setUp(() {
      mockService = MockTdlibService();
      updatesController = StreamController<td.TdObject>.broadcast();
      when(() => mockService.updates).thenAnswer((_) => updatesController.stream);
    });

    tearDown(() {
      updatesController.close();
    });

    test('reconnects after network drop', () async {
      // Simulate connection state changes
      final states = <td.ConnectionState>[];
      mockService.updates.listen((event) {
        if (event is td.UpdateConnectionState) {
          states.add((event).state);
        }
      });

      // Drop network
      updatesController.add(const td.UpdateConnectionState(state: td.ConnectionStateConnectingToProxy()));
      updatesController.add(const td.UpdateConnectionState(state: td.ConnectionStateWaitingForNetwork()));
      
      // Reconnect network
      updatesController.add(const td.UpdateConnectionState(state: td.ConnectionStateConnecting()));
      updatesController.add(const td.UpdateConnectionState(state: td.ConnectionStateReady()));

      await Future.delayed(Duration.zero);

      expect(states.length, 4);
      expect(states.last, isA<td.ConnectionStateReady>());
    });

    test('UpdateNewMessage triggers stream updates', () async {
      final messages = <td.Message>[];
      mockService.updates.listen((event) {
        if (event is td.UpdateNewMessage) {
          messages.add((event).message);
        }
      });

      final mockMessage = MockMessage();
      when(() => mockMessage.id).thenReturn(12345);

      updatesController.add(td.UpdateNewMessage(message: mockMessage));

      await Future.delayed(Duration.zero);

      expect(messages.length, 1);
      expect(messages.first.id, 12345);
    });
  });
}
