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
  static const String currentVersion = '2.6.3';
  static const String changelog = '''
### 🚀 What's New in v2.6.3

This update brings Unified Native subtitle rendering, PGS/HDMV compatibility improvements, instant streaming startup, and high-speed video synchronization enhancements.

#### ⚡ Subtitles & Playback Sync
* **Unified Native Subtitles**: Migrated completely to the native `libass` rendering engine, removing the Flutter-compatible renderer for superior typography and format compatibility.
* **PGS/HDMV Protection**: Automatically detects graphic subtitles (PGS/HDMV) in the Customizer sheet, displaying a warning and locking text styling parameters while keeping Delay Sync editable.
* **Perfect 2x Speed Sync**: Audio-clock master synchronization coupled with aggressive multi-stage framedrop keeps audio, video, and subtitles in perfect alignment at 2x speed.
* **HW/SW Decoder Switcher**: Cycles decoder modes (`HW`, `HW+`, `SW`) on-the-fly from the control bar.

#### 🌐 Instant Startup & Performance
* **Instant Streaming Startup**: Automatically detects out-of-buffer HTTP range requests (like end-of-file metadata reads) in the proxy layer, immediately shifting TDLib download offsets to bypass startup delay.
* **Zero-Lag Episode Cards**: Removed poster theme color extraction and centered episode card content to resolve folder loading lags.
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
