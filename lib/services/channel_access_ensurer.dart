import 'package:tdlib/td_api.dart' as td;
import '../core/logger.dart';
import 'tdlib_service.dart';

/// Result of ensuring access to a channel.
class ChannelAccessResult {
  final bool success;
  final String? resolvedTitle;
  final String? errorMessage;
  final bool isMember;

  const ChannelAccessResult({
    required this.success,
    this.resolvedTitle,
    this.errorMessage,
    this.isMember = false,
  });

  const ChannelAccessResult.success({String? title, this.isMember = false})
      : success = true,
        resolvedTitle = title,
        errorMessage = null;

  const ChannelAccessResult.failure(String message)
      : success = false,
        resolvedTitle = null,
        errorMessage = message,
        isMember = false;
}

/// Ensures TelStream can read a channel's message history by:
/// 1. Opening the chat in TDLib (so updates are received).
/// 2. Joining the channel if the user is not already a member (reliable history access).
/// 3. Verifying that GetChat succeeds and the chat type is a channel/supergroup.
///
/// This service exists because [HomeController] previously relied on
/// [td.OpenChat] alone, which does NOT join the user to the channel.
/// For public channels the user has not joined, [td.GetChatHistory]
/// can return empty or partial results depending on TDLib's cache state.
class ChannelAccessEnsurer {
  final TdlibService _tdlib;

  ChannelAccessEnsurer(this._tdlib);

  Future<td.TdObject> _send(td.TdFunction request,
      {Duration timeout = const Duration(seconds: 10)}) {
    return _tdlib.sendAsync(request).timeout(
      timeout,
      onTimeout: () => td.TdError(code: 408, message: 'Request Timeout'),
    );
  }

  /// Ensures access to the channel identified by [chatId].
  ///
  /// [inviteLink] is the raw user input stored in [UserChannel.inviteLink]
  /// (may be "@username", "t.me/username", "t.me/+xxx", or a numeric ID string).
  ///
  /// Returns a [ChannelAccessResult] indicating success or failure.
  /// On success, [ChannelAccessResult.isMember] indicates whether the user
  /// is currently a member of the channel.
  Future<ChannelAccessResult> ensureAccess({
    required int chatId,
    String? inviteLink,
  }) async {
    Log.i('[ChannelAccessEnsurer] Ensuring access to chatId=$chatId, '
        'inviteLink=$inviteLink');

    // Step 1: OpenChat — registers the chat in TDLib's active chat list
    // so that updates are received. This is idempotent and safe to call
    // on an already-open chat.
    try {
      await _send(td.OpenChat(chatId: chatId), timeout: const Duration(seconds: 5));
      Log.i('[ChannelAccessEnsurer] OpenChat succeeded for $chatId');
    } catch (e) {
      // OpenChat may fail if the chat is not yet in TDLib's database.
      // We'll try to load it via LoadChats / SearchPublicChat below.
      Log.w('[ChannelAccessEnsurer] OpenChat failed for $chatId: $e — '
          'will attempt to load chat via fallbacks');
    }

    // Step 2: GetChat — verify the chat exists and the user can access it.
    td.TdObject chatRes;
    try {
      chatRes = await _send(td.GetChat(chatId: chatId));
    } catch (e) {
      chatRes = td.TdError(code: -1, message: e.toString());
    }

    // Step 2a: If GetChat failed, try to load the chat into TDLib's database.
    if (chatRes is td.TdError) {
      Log.w('[ChannelAccessEnsurer] GetChat failed (${chatRes.message}). '
          'Attempting fallbacks.');

      // Fallback A: If inviteLink is a t.me/+xxx link, use CheckChatInviteLink
      // which loads the chat info without joining.
      if (_isInviteLink(inviteLink)) {
        try {
          final checkRes = await _send(
            td.CheckChatInviteLink(inviteLink: inviteLink!),
          );
          if (checkRes is td.ChatInviteLinkInfo && checkRes.chatId != 0) {
            // The chat is now in TDLib's database; retry GetChat.
            chatRes = await _send(td.GetChat(chatId: chatId));
          }
        } catch (e) {
          Log.w('[ChannelAccessEnsurer] CheckChatInviteLink failed: $e');
        }
      }

      // Fallback B: If inviteLink is a @username or t.me/username link,
      // use SearchPublicChat to load the chat into TDLib's database.
      if (chatRes is td.TdError && _isUsernameLink(inviteLink)) {
        final username = _extractUsername(inviteLink);
        if (username != null) {
          try {
            final searchRes = await _send(
              td.SearchPublicChat(username: username),
            );
            if (searchRes is td.Chat) {
              chatRes = await _send(td.GetChat(chatId: chatId));
            }
          } catch (e) {
            Log.w('[ChannelAccessEnsurer] SearchPublicChat failed: $e');
          }
        }
      }

      // Fallback C: Load main chat list (helps if user is a member but
      // TDLib hasn't synced the chat list yet).
      if (chatRes is td.TdError) {
        try {
          await _send(
            const td.LoadChats(chatList: td.ChatListMain(), limit: 100),
            timeout: const Duration(seconds: 5),
          );
          chatRes = await _send(td.GetChat(chatId: chatId));
        } catch (e) {
          Log.w('[ChannelAccessEnsurer] LoadChats failed: $e');
        }
      }

      // Fallback D: Poll GetChat for up to 30 seconds (cold TDLib cache
      // can take time to sync a newly-accessed channel from the network).
      int retries = 0;
      while (chatRes is td.TdError && retries < 30) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          chatRes = await _send(td.GetChat(chatId: chatId));
        } catch (_) {}
        retries++;
      }

      if (chatRes is td.TdError) {
        return ChannelAccessResult.failure(
          'Cannot access channel after 30s: ${chatRes.message} '
          '(Code: ${chatRes.code}). The channel may not exist, or you may '
          'have been removed.',
        );
      }
    }

    if (chatRes is! td.Chat) {
      return ChannelAccessResult.failure(
        'Unexpected response from GetChat: ${chatRes.runtimeType}',
      );
    }

    final chat = chatRes;
    final type = chat.type;
    final isChannel = type is td.ChatTypeSupergroup && type.isChannel;
    final isSupergroup = type is td.ChatTypeSupergroup && !type.isChannel;

    if (!isChannel && !isSupergroup) {
      return ChannelAccessResult.failure(
        'This chat is not a channel or supergroup. '
        'Only channels and supergroups are supported.',
      );
    }

    // Step 3: Check membership status. For channels, chat.memberCount > 0
    // and the user's own status tells us if they are a member.
    bool isMember = false;
    final supergroupType = type as td.ChatTypeSupergroup;
    try {
      final supergroupRes = await _send(td.GetSupergroup(supergroupId: supergroupType.supergroupId));
      if (supergroupRes is td.Supergroup) {
        final status = supergroupRes.status;
        isMember = status is! td.ChatMemberStatusLeft &&
            status is! td.ChatMemberStatusBanned;
      }
    } catch (e) {
      Log.w('[ChannelAccessEnsurer] GetSupergroup failed: $e');
    }

    Log.i('[ChannelAccessEnsurer] Access verified for "${chat.title}" '
        '(isMember=$isMember, isChannel=$isChannel)');

    // Step 4: If the user is not a member, JOIN the channel.
    // Joining guarantees reliable GetChatHistory access for both public
    // and private channels. For private channels, the user should already
    // be a member (ChannelResolver enforces this at add time), but if they
    // left later, we rejoin here.
    if (!isMember) {
      Log.i('[ChannelAccessEnsurer] User is not a member of "${chat.title}". '
          'Joining channel for reliable history access.');
      try {
        final joinRes = await _send(td.JoinChat(chatId: chatId));
        if (joinRes is td.Chat) {
          Log.i('[ChannelAccessEnsurer] Successfully joined "${chat.title}"');
          return ChannelAccessResult.success(
            title: joinRes.title,
            isMember: true,
          );
        } else if (joinRes is td.TdError) {
          // Some channels restrict joining (e.g., removed by admin).
          // We can still try to read history as a non-member — proceed
          // with success=false but provide a descriptive error.
          Log.w('[ChannelAccessEnsurer] JoinChat failed for "${chat.title}": '
              '${joinRes.message}. Attempting read as non-member.');
          // Even if join failed, try reading history — some public
          // channels allow non-member reads.
          return ChannelAccessResult.success(
            title: chat.title,
            isMember: false,
          );
        }
      } catch (e) {
        Log.w('[ChannelAccessEnsurer] JoinChat threw: $e. '
            'Attempting read as non-member.');
        return ChannelAccessResult.success(
          title: chat.title,
          isMember: false,
        );
      }
    }

    return ChannelAccessResult.success(
      title: chat.title,
      isMember: isMember,
    );
  }

  /// Returns true if [link] is a `t.me/+xxx` or `telegram.me/+xxx` invite link.
  bool _isInviteLink(String? link) {
    if (link == null || link.isEmpty) return false;
    return link.contains('t.me/+') || link.contains('telegram.me/+');
  }

  /// Returns true if [link] is a `@username` or `t.me/username` public link.
  bool _isUsernameLink(String? link) {
    if (link == null || link.isEmpty) return false;
    if (link.startsWith('@')) return true;
    if (link.contains('t.me/') || link.contains('telegram.me/')) {
      // Exclude invite links (handled by _isInviteLink)
      if (link.contains('t.me/+') || link.contains('telegram.me/+')) {
        return false;
      }
      if (link.contains('t.me/c/') || link.contains('telegram.me/c/')) {
        return false; // Private channel link — not a username
      }
      return true;
    }
    return false;
  }

  /// Extracts the username from a `@username` or `t.me/username` link.
  String? _extractUsername(String? link) {
    if (link == null || link.isEmpty) return null;
    if (link.startsWith('@')) {
      return link.substring(1);
    }
    final uri = Uri.tryParse(link);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return null;
  }
}
