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
  static const String currentVersion = '2.0.1';
  static const String changelog = '''
### 🚀 What's New in v2.0.1

We've rolled out a major performance and quality-of-life update!

#### ⚡ Low-Bandwidth Streaming Fixes
* **Optimized Playback Buffering**: Advanced libmpv caching parameters are now automatically tuned for 100MB max buffer, 50MB back-buffer, and 120-second readahead.
* **Dynamic Playback Threshold**: The app now dynamically scales the initial buffer before starting video playback (`(fileSize * 5%).clamp(4MB, 15MB)`) to completely eliminate stuttering and glitching on slow 1-2 Mbps connections.
* **Buffering Indicator**: A loading indicator now displays in real time on the video player when network buffering occurs.

#### 🔄 Orientation & Playback Controls
* **Default Landscape Mode**: Streaming videos now launch automatically in landscape mode.
* **Seamless Screen Rotation**: Rotating your device between landscape and portrait no longer pauses or restarts the video playback.

#### 🛡️ Permission Cleanup
* **Sandbox Security**: Stripped all legacy and media image/video permissions from startup. TelStream runs in a secure sandboxed directory and requires zero local storage permissions on Android 10+.
* **Notification Permission**: On Android 13+, only the notification permission is requested on startup.
* **On-Demand Storage**: Legacy storage permission is requested dynamically only on Android 9 or below when selecting a custom download folder.

#### 📥 Real-Time Syncing & Performance
* **Minimization Handler**: Pressing the back button on the main screen now minimizes the app instead of closing it, keeping background downloads active and preventing TDLib database locks.
* **Throttled Notifications**: Throttled native notification progress updates to 800ms intervals to fix foreground service lags and queue delays.
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
