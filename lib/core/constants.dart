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
  static const String currentVersion = '2.10.2+40';
  static const String changelog = '''
### 🚀 What's New in v2.10.2+40

This release is a massive stability and security update, fixing over 200 issues identified in a comprehensive source code audit! 🛡️

* **🔒 Security**: Implemented strict SHA-256 hash verification for app updates, secured the TDLib database with a 32-byte encrypted key, added strict JSON type-checking to prevent storage crashes, and enabled atomic file saving to stop corrupted downloads.
* **⚡ Concurrency & Sync**: The Download Manager now strictly limits concurrent active downloads to a maximum of 3 to eliminate CPU/Network bottlenecks. The Cloud Sync Service now correctly deduplicates standalone movies in the "Continue Watching" log by unique Telegram message IDs.
* **📱 Platform Fixes**: Fixed a foreground service background crash and null-intent deliveries on Android 8+. Added UIBackgroundModes for continuous background audio on iOS. Added network entitlements for macOS. Included Wakelock Plus to stop your screen from falling asleep during long movies.
* **🎨 Performance Improvements**: Added a 300ms debounce to all Search bars to eliminate UI stuttering while typing. Reduced the Video Player's auto-save frequency to reduce battery and disk usage. The root runApp has been safely moved outside the try block to guarantee a visible error screen on fatal init failure.
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
