import 'package:flutter/material.dart';
import 'secrets.dart';

class ChannelCategory {
  final String title;
  final int channelId;
  final String inviteLink;
  
  const ChannelCategory({
    required this.title,
    required this.channelId,
    required this.inviteLink,
  });
}

class Constants {
  static const String currentVersion = '2.6.1';
  static const String changelog = '''
### 🚀 What's New in v2.6.1

This update resolves video speed sync issues and simplifies UI metadata.

#### ⚡ High-Speed Playback Synchronization
* **Optimized Master Clock**: Increased audio buffer to 200ms and disabled autosync speed adjustments, establishing the audio clock as the absolute master sync reference.
* **Clean Frame Dropping**: Shifted frame dropping to the output layer (`vo`) instead of the decoder, avoiding keyframe decoding artifacts or glitches.
* **Independent Subtitle Rendering**: Disabled subtitle texture blending to prevent subtitle lag, rendering them dynamically on screen at proper timestamps regardless of video frame rate.

#### 🧹 TMDB Integration Removed
* **Anime Cleanups**: Removed all TMDB service code, metadata fetchers, and settings configs.
* **Offline-First UI Details**: Reverted to pure local metadata (TDLib details, filenames, and local Telegram posters) for a faster, offline-friendly details screen layout.
''';

  // Telegram API Credentials from secrets.dart
  static const int apiId = Secrets.apiId;
  static const String apiHash = Secrets.apiHash;

  // Categories & Channels
  static const List<ChannelCategory> categories = [
    ChannelCategory(
      title: 'Anime',
      channelId: Secrets.animeChannelId,
      inviteLink: Secrets.animeInviteLink,
    ),
    ChannelCategory(
      title: 'Movies',
      channelId: -1000000000001, // PLACEHOLDER
      inviteLink: 'https://t.me/placeholder_movies', // PLACEHOLDER
    ),
    ChannelCategory(
      title: 'Web Series',
      channelId: -1000000000002, // PLACEHOLDER
      inviteLink: 'https://t.me/placeholder_series', // PLACEHOLDER
    ),
  ];
}

class PremiumPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  PremiumPageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}
