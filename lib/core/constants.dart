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
  static const String currentVersion = '2.2.0';
  static const String changelog = '''
### 🚀 What's New in v2.2.0

We have optimized seeking, player buffering, and cold-boot resume reliability!

#### 📺 Player & Buffering Optimizations
* **Instant Dynamic Seeking**: Integrated TDLib dynamic download offsets to pivot download priority instantly to the seek target.
* **Smart Demuxer Cache Tuning**: Implemented dynamic player cache constraints (8MB / 5s ahead during streaming to prevent decoding zero-filled sparse disk pages, boosting to 100MB buffer upon completion).
* **Cold Boot Watch Progress Resume**: Automatically starts download from the last watch byte offset on cold boot, resolving resume-play reliability from history and Continue Watching.

#### 🎛️ Gestures & Persistence Memory
* **Screen Brightness Memory**: Added automatic persistence for video player brightness adjustments across app restarts.
* **Volume Synchronization Fix**: Prevented volume HUD gesture feedback loop jitter on external volume updates.

---

### 🚀 What's New in v2.1.0

We have rolled out a major streaming optimization and quality-of-life update!

#### 📺 Premium Player Controls & Gestures
* Added hardware **Volume & Brightness control gestures** to the built-in media player.
* Swipe up/down on the left side of the screen to adjust screen brightness; swipe on the right to adjust system volume.
* Display premium on-screen overlay indicators for volume and brightness status.
* Added an **Auto Play Next Episode** countdown overlay 15 seconds before the current episode completes.

#### 🎬 Continue Watching Shelf
* Added a new, horizontal **Continue Watching** shelf at the top of the Library screen.
* Resume partially watched movies or series episodes instantly at the correct timestamp.
* Continue Watching items are automatically partitioned by category (Anime, Movies, Web Series).

#### 📈 Watch Progress Indicators
* Added visual **watch progress bars** at the bottom of each episode tile.
* Episodes that are more than 90% watched will display a green completion checkmark (`✓`) in the episode list.

#### 🛡️ Stability & Cache Enhancements
* Implemented **Atomic Storage Safes**: Watch history and settings are written staged, validated, and backed up (`.bak`) to prevent JSON corruption.
* Optimized directory cache size calculations using a background isolate to keep settings scrolling butter-smooth.
* Added background **Cache Pruning** on startup to clear old buffers while preserving permanently downloaded files.
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
