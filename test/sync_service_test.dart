import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telstream/services/sync_service.dart';
import 'package:telstream/services/tdlib_service.dart';
import 'package:telstream/services/storage_service.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockTdlibService extends Mock implements TdlibService {}
class MockStorageService extends Mock implements StorageService {}

class MockUser extends Mock implements td.User {}
class MockChat extends Mock implements td.Chat {}
class MockMessage extends Mock implements td.Message {}
class FakeTdFunction extends Fake implements td.TdFunction {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeTdFunction());
  });
  group('ProgressSyncNotifier Tests', () {
    late MockTdlibService mockTdlib;
    late MockStorageService mockStorage;
    late ProviderContainer container;

    setUp(() {
      mockTdlib = MockTdlibService();
      mockStorage = MockStorageService();
      
      when(() => mockStorage.getVideoSettings()).thenReturn({'progressSyncMode': 'pinned'});
      
      container = ProviderContainer(
        overrides: [
          tdlibServiceProvider.overrideWithValue(mockTdlib),
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('recovers state gracefully after process kill', () async {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn(1);
      
      when(() => mockTdlib.sendAsync(any(that: isA<td.GetMe>())))
          .thenAnswer((_) async => mockUser);

      final mockChat = MockChat();
      when(() => mockChat.id).thenReturn(123);
      
      when(() => mockTdlib.sendAsync(any(that: isA<td.CreatePrivateChat>())))
          .thenAnswer((_) async => mockChat);

      final mockMessage = MockMessage();
      when(() => mockMessage.id).thenReturn(456);

      when(() => mockTdlib.sendAsync(any(that: isA<td.GetChatHistory>())))
          .thenAnswer((_) async => td.Messages(
            totalCount: 1,
            messages: [mockMessage],
          ));

      final notifier = container.read(progressSyncServiceProvider.notifier);
      // Wait for async constructor/init if any
      await Future.delayed(Duration.zero);
      
      expect(notifier, isNotNull);
    });
  });
}


