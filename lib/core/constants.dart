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
  static const String currentVersion = '2.6.2';
  static const String changelog = '''
### 🚀 What's New in v2.6.2

This update brings UI enhancements, improved video player controls, and optimized high-speed video synchronization.

#### ⚡ Playback Sync & Controls
* **Perfect 2x Speed Sync**: Configured the master audio clock and aggressive decoder/rendering framedrops to ensure audio, video, and subtitles remain perfectly synchronized.
* **On-the-fly Buffer Flushing**: Automatically performs seek resyncs on speed adjustments to rebuild player buffers instantly.
* **HW/SW Decoder Switcher**: Switch hardware acceleration modes (`HW`, `HW+`, `SW`) on-the-fly directly from the player's control bar.
* **Subtitle Renderer Settings**: Switch between Flutter and Native subtitle renderers right inside the player's subtitle customizer.

#### 🎨 Cleaner Episode List UI
* **Aligned Episode Cards**: Episode list cards now have their content vertically centered for a clean look.
* **Removed Descriptions**: Removed the generic "No description available" text from local episodes.
* **Zero-Lag Folder Loading**: Removed dynamic theme color extraction from the poster image to ensure instant navigation.
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
