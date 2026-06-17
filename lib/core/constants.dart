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
  static const String currentVersion = '2.4.0';
  static const String changelog = '''
### 🚀 What's New in v2.4.0

This major update brings premium playback optimizations, granular subtitle presets, real-time seek scrubbing, watched progress overlays, and an Advanced Cache Manager!

#### ⚡ Buttery Smooth Playback & Seeking
* **Instant Seeks**: Seeks within the already-downloaded part of a streaming video are now instantaneous and buffer-free.
* **Low-Latency Buffering**: Reduced target buffer sizes during network seeks from 2.5MB to 1MB, ensuring super-fast play resume.
* **Real-Time Seek Scrubbing**: Dragging the seekbar slider now updates video frames in real-time for downloaded regions.
* **Wi-Fi Back Buffer Boost**: Dynamically increased the player back-buffer allocation to 64MB on Wi-Fi, keeping recently played scenes cached in RAM.
* **Snappier Gestures**: Double-tap to seek gesture delay reduced from 500ms to 300ms for extra responsiveness.

#### 💬 Subtitle Presets
* **One-Tap Styles**: Added subtitle preset chips at the top of the Subtitle Customizer (Default White, Classic Yellow, Soft Cyan, Large & Bold, Compact Minimal). Select your style instantly!

#### 📺 Watched Progress Overlays
* **Premium Thumbnail Progress**: Episodes you've started watching now display a clean, subtle progress bar at the bottom edge of their thumbnail preview, keeping the episode list neat and modern.

#### 🧹 Advanced Cache Manager
* **Granular Storage View**: Added a detailed storage gauge in Settings showing videos, documents, poster images, and temporary cache sizes.
* **Per-Series Cache Purge**: Exposes cached size per series, allowing you to delete cache files on a per-show basis to save space!
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
