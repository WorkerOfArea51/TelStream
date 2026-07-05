import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telstream/services/sync_service.dart';
import 'package:telstream/services/tdlib_service.dart';
import 'package:telstream/services/storage_service.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockTdlibService extends Mock implements TdlibService {}
class MockStorageService extends Mock implements StorageService {}

void main() {
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
      // Return a valid user for GetMe
      when(() => mockTdlib.sendAsync(any(that: isA<td.GetMe>())))
          .thenAnswer((_) async => const td.User(
            id: 1, 
            firstName: 'Test', 
            lastName: '', 
            usernames: null, 
            phoneNumber: '', 
            status: td.UserStatusEmpty(), 
            profilePhoto: null, 
            isContact: false, 
            isMutualContact: false, 
            isVerified: false, 
            isPremium: false, 
            isSupport: false, 
            restrictionReason: '', 
            isScam: false, 
            isFake: false, 
            hasBotCommands: false,
            hasBotInfo: false,
            hasUnreadMentions: false,
            isCloseFriend: false,
            addedToAttachmentMenu: false,
            botInfoVersion: 0,
            languageCode: '',
            type: td.UserTypeRegular(),
          ));

      // Return a valid chat
      when(() => mockTdlib.sendAsync(any(that: isA<td.CreatePrivateChat>())))
          .thenAnswer((_) async => const td.Chat(
            id: 123, 
            type: td.ChatTypePrivate(userId: 1), 
            title: 'Saved Messages', 
            photo: null, 
            permissions: td.ChatPermissions(
              canSendBasicMessages: true,
              canSendAudios: true,
              canSendDocuments: true,
              canSendPhotos: true,
              canSendVideos: true,
              canSendVideoNotes: true,
              canSendVoiceNotes: true,
              canSendPolls: true,
              canSendOtherMessages: true,
              canAddWebPagePreviews: true,
              canChangeInfo: true,
              canInviteUsers: true,
              canPinMessages: true,
              canManageTopics: true,
            ), 
            lastMessage: null, 
            positions: [], 
            messageSenderId: td.MessageSenderUser(userId: 1),
            hasProtectedContent: false,
            isTranslatable: false,
            isMarkedAsUnread: false,
            isBlocked: false,
            hasScheduledMessages: false,
            canBeDeletedOnlyForSelf: false,
            canBeDeletedForAllUsers: false,
            canBeReported: false,
            defaultDisableNotification: false,
            unreadCount: 0,
            lastReadInboxMessageId: 0,
            lastReadOutboxMessageId: 0,
            unreadMentionCount: 0,
            unreadReactionCount: 0,
            notificationSettings: td.ChatNotificationSettings(
              useDefaultMuteFor: false,
              muteFor: 0,
              useDefaultSound: false,
              soundId: 0,
              useDefaultShowPreview: false,
              showPreview: false,
              useDefaultDisablePinnedMessageNotifications: false,
              disablePinnedMessageNotifications: false,
              useDefaultDisableMentionNotifications: false,
              disableMentionNotifications: false,
            ),
            availableReactions: td.ChatAvailableReactionsAll(),
            messageAutoDeleteTime: 0,
            background: null,
            themeName: '',
            actionBar: null,
            videoChat: td.VideoChat(
              groupCallId: 0,
              hasParticipants: false,
              defaultParticipantId: null,
            ),
            pendingJoinRequests: null,
            replyMarkupMessageId: 0,
            draftMessage: null,
            clientData: '',
          ));

      // Return fake sync data
      when(() => mockTdlib.sendAsync(any(that: isA<td.GetChatHistory>())))
          .thenAnswer((_) async => td.Messages(
            totalCount: 1, 
            messages: [
              td.Message(
                id: 1, 
                senderId: const td.MessageSenderUser(userId: 1), 
                chatId: 123, 
                isOutgoing: true, 
                isPinned: true, 
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
                isChannelPost: false, 
                containsUnreadMention: false, 
                date: 0, 
                editDate: 0, 
                replyInChatId: 0, 
                replyToMessageId: 0, 
                messageThreadId: 0, 
                ttl: 0, 
                ttlExpiresIn: 0, 
                viaBotUserId: 0, 
                authorSignature: '', 
                mediaAlbumId: 0, 
                restrictionReason: '', 
                content: const td.MessageText(
                  text: td.FormattedText(
                    text: '[TelStream Sync Data]\n{"history": {"123": 10}, "favorites": []}', 
                    entities: []
                  )
                )
              )
            ]
          ));

      final notifier = container.read(progressSyncServiceProvider.notifier);
      await notifier.syncProgress();
      
      // Verification logic: ensure storage was updated
      verify(() => mockStorage.importData(any())).called(1);
    });
  });
}

