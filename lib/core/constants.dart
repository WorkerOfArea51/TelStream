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
  static const String currentVersion = '2.6.0';
  static const String changelog = '''
### 🚀 What's New in v2.6.0

This major update introduces the Google Pixel-inspired Material 3 Expressive UI, customizable gestures, advanced offline library features, real-time download speed analytics, and structured history search.

#### 🎨 Material 3 Expressive UI
* **Pixel Style Loaders**: Organic skeleton loaders replace loading spinners for screens and lists.
* **Expansion Transitions**: Hero widgets deliver fluid detail expansions across screens.
* **M3 Cards**: Rounded container styles (20px-24px corners) applied consistently.

#### 📈 Adaptive Streaming & Pre-fetching
* **Adaptive Cache Profiles**: Define Aggressive (100MB buffer), Balanced (30MB), or Mobile Saver (10MB) profiles to optimize bandwidth.
* **Next-Episode Pre-fetching**: Starts background-downloading the first 10MB of the next episode as you near the current episode's outro range for instant continuation.

#### 📥 Advanced Offline Library & Downloader
* **True Offline Library**: Access completely downloaded episodes directly via file paths, enabling full playback without any network verification checks.
* **Active Downloads Manager**: Displays real-time download speeds (MB/s), estimated time of arrival (ETA), and cancellation capabilities.

#### 📺 Gestural Mapping & Audio Night Mode
* **Custom Gestural Actions**: Bind Left/Right vertical swipe gestures to Brightness, Volume, or Playback Speed.
* **Audio Night Mode (DRC)**: Dynamic Range Compression levels sudden volume spikes (amplifying dialog, quietening explosions).
* **Software Audio Boost**: Boost volume up to +6dB software gain inside the media player.

#### 🕒 Structured Watch History
* **Accordion Grouping**: History screen now groups watches under series folders with season/episode drill-down.
* **Master Search Filter**: Search series groups or nested episodes instantly by title, season, or episode label.
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
