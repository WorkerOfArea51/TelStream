import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telstream/services/tdlib_service.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:tdlib/td_api.dart';

class MockTdlibService extends Mock implements TdlibService {}

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
          states.add((event as td.UpdateConnectionState).state);
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
          messages.add((event as td.UpdateNewMessage).message);
        }
      });

      final mockMessage = td.Message(
        id: 12345,
        senderId: const td.MessageSenderUser(userId: 1),
        chatId: -100123456789,
        isOutgoing: false,
        isPinned: false,
        canBeEdited: false,
        canBeForwarded: false,
        canBeSaved: false,
        canBeDeletedOnlyForSelf: false,
        canBeDeletedForAllUsers: false,
        canGetAddedReactions: false,
        canGetStatistics: false,
        canGetMessageThread: false,
        canSeeReadConfirmations: false,
        canGetViewers: false,
        canUseMediaTimestamps: false,
        hasTimestampedMedia: false,
        isChannelPost: true,
        containsUnreadMention: false,
        date: 1234567890,
        editDate: 0,
        replyInChatId: 0,
        replyToMessageId: 0,
        messageThreadId: 0,
        ttl: 0,
        ttlExpiresIn: 0.0,
        viaBotUserId: 0,
        authorSignature: '',
        mediaAlbumId: 0,
        restrictionReason: '',
        content: const td.MessageText(text: td.FormattedText(text: 'Hello', entities: [])),
      );

      updatesController.add(td.UpdateNewMessage(message: mockMessage));

      await Future.delayed(Duration.zero);

      expect(messages.length, 1);
      expect(messages.first.id, 12345);
    });
  });
}

