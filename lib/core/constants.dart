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
  static const String currentVersion = '2.9.0';
  static const String changelog = '''
### 🚀 What's New in v2.9.0

* **PC / Windows Platform Support**:
  - Configured project CMake build targets and optimized dependencies to compile natively on Windows.
* **Material 3 Expressive Animated UI**:
  - Integrated interactive list tiles with custom micro-animations (spinning settings gear, counter-rotating history clock, and elastic pulsing shapes).
* **Subtitle Compatibility Alerts**:
  - Embedded warning banners for PGS/VobSub formats with quick actions to switch between Native/Flutter rendering or toggle HW+ decoders.
* **Streaming Proxy Range fixes**:
  - Corrected seek range boundaries (`end + 1`) to conform with strict HTTP Content-Length expectations.

### 🚀 What's New in v2.8.0

* **Stats for Nerds & Real-time Media Analytics**:
  - Added a "Show Stats for Nerds" overlay during video playback displaying real-time video resolution, framerate, video/audio codec, active hardware decoder, active download byte offsets, buffering rate, and network prefetch cache parameters.
* **Database Maintenance & Defragmentation**:
  - Integrated a manual "Defragment & Compact Database" action in the Advanced Cache screen to optimize SQLite databases and TDLib storage, reclaiming disk space safely without clearing history or active login sessions.
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
      channelId: Secrets.movieChannelId,
      inviteLink: Secrets.movieInviteLink,
    ),
    ChannelCategory(
      title: 'Web Series',
      channelId: Secrets.webSeriesChannelId,
      inviteLink: Secrets.webSeriesInviteLink,
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
