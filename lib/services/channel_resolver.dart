import 'package:tdlib/td_api.dart' as td;
import '../core/logger.dart';
import 'tdlib_service.dart';

class ChannelResolver {
  final TdlibService _tdlib;

  ChannelResolver(this._tdlib);

  /// Resolves a Telegram link/username to a channel ID.
  /// Returns a [ResolvedChannel] if successful, throws otherwise.
  Future<ResolvedChannel> resolve(String input) async {
    final cleaned = input.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('Input is empty');
    }

    int? channelId;
    String? title;

    // Case 1: Direct numeric ID (e.g., -1001234567890)
    if (cleaned.startsWith('-') && int.tryParse(cleaned) != null) {
      channelId = int.parse(cleaned);
    }

    // Case 2: Private channel link (https://t.me/c/1234567890)
    else if (cleaned.contains('t.me/c/') || cleaned.contains('telegram.me/c/')) {
      final match = RegExp(r'/c/(-?\d+)').firstMatch(cleaned);
      if (match == null) {
        throw FormatException('Invalid private channel link format');
      }
      final rawId = int.parse(match.group(1)!);
      channelId = rawId > 0 ? -1000000000000 - rawId : rawId;
    }

    // Case 3: Invite link with + (https://t.me/+AbCdEfGhIjKlMnOp)
    else if (cleaned.contains('t.me/+') || cleaned.contains('telegram.me/+')) {
      Log.i('Resolving invite link: $cleaned');
      final result = await _tdlib.sendAsync(td.CheckChatInviteLink(inviteLink: cleaned))
          .timeout(const Duration(seconds: 10));

      if (result is td.ChatInviteLinkInfo) {
        final info = result;
        if (info.chatId == 0) {
          throw Exception('You are not a member of this channel. Join it first in Telegram.');
        }
        channelId = info.chatId;
        title = info.title;
      } else if (result is td.TdError) {
        throw Exception('Telegram error: ${result.message}');
      } else {
        throw Exception('Unexpected response from CheckChatInviteLink');
      }
    }

    // Case 4: @username or https://t.me/username (public)
    else {
      String? username;
      if (cleaned.startsWith('@')) {
        username = cleaned.substring(1);
      } else if (cleaned.contains('t.me/') || cleaned.contains('telegram.me/')) {
        final uri = Uri.tryParse(cleaned);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          username = uri.pathSegments.first;
        }
      } else {
        username = cleaned;
      }

      if (username == null || username.isEmpty) {
        throw FormatException('Could not extract username from input');
      }

      Log.i('Resolving Telegram username: $username');
      final result = await _tdlib.sendAsync(td.SearchPublicChat(username: username))
          .timeout(const Duration(seconds: 10));

      if (result is td.Chat) {
        channelId = result.id;
        title = result.title;
      } else if (result is td.TdError) {
        throw Exception('Telegram error: ${result.message}');
      } else {
        throw Exception('Unexpected response from SearchPublicChat');
      }
    }

    if (channelId == 0) {
      throw Exception('Failed to resolve channel ID');
    }

    // Verify access: GetChat will throw if the user doesn't have access
    Log.i('Verifying access to channel ID: $channelId');
    final chatResult = await _tdlib.sendAsync(td.GetChat(chatId: channelId))
        .timeout(const Duration(seconds: 10));

    if (chatResult is td.TdError) {
      throw Exception('Cannot access channel: ${chatResult.message}');
    }

    if (chatResult is td.Chat) {
      title ??= chatResult.title;
      final type = chatResult.type;
      final isChannel = type is td.ChatTypeSupergroup && type.isChannel;
      final isSupergroup = type is td.ChatTypeSupergroup && !type.isChannel;

      if (!isChannel && !isSupergroup) {
        throw Exception('This is not a channel or supergroup. Only channels are supported.');
      }

      Log.i('Resolved channel: $title (ID: $channelId, isChannel: $isChannel)');
      return ResolvedChannel(
        channelId: channelId,
        title: title,
        isChannel: isChannel,
      );
    }

    throw Exception('Unexpected response from GetChat');
  }

  /// Checks if a channel has any video/media files by fetching recent history.
  Future<bool> hasMediaContent(int channelId) async {
    try {
      final result = await _tdlib.sendAsync(td.GetChatHistory(
        chatId: channelId,
        fromMessageId: 0,
        offset: 0,
        limit: 50,
        onlyLocal: false,
      )).timeout(const Duration(seconds: 15));

      if (result is td.Messages) {
        for (final msg in result.messages) {
          if (msg.content is td.MessageVideo || msg.content is td.MessageDocument) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      Log.w('Failed to check media content for channel $channelId: $e');
      return false;
    }
  }
}

class ResolvedChannel {
  final int channelId;
  final String title;
  final bool isChannel;

  const ResolvedChannel({
    required this.channelId,
    required this.title,
    required this.isChannel,
  });
}
