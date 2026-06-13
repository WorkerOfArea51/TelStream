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
  static const String currentVersion = '2.0.0';
  static const String changelog = '''
### 🚀 What's New in v2.0.0

We've rolled out a major stable release with background capabilities and premium styling updates!

#### 📥 Native Background Downloads
* **Active Background Services**: Downloads now continue running seamlessly even if you minimize or close the app.
* **Notification Center Progress**: Real-time download progress bar and indicators in your Android notification tray.
* **Recents Dismiss Cleanup**: Closing the app from the Recents menu automatically halts active downloads and wipes temporary cache to save your device space.
* **Video Player Exit Fix**: Disposing the player no longer cancels/deletes background downloads that are explicitly started by you.

#### 🎨 Custom Gradient Themes
* **Vibrant Gradient Palettes**: Personalize the look with 4 gorgeous, premium options:
  * **Sunset Cyberpunk** (Neon Pink/Amber accents)
  * **Aurora Abyss** (Soothing Teal/Cyan glows)
  * **Solaris Flare** (Solar Gold/Crimson highlights)
  * **Classic Navy** (Elegant Royal Blue gradients)
* **Solid Surfaces**: Clean, robust cards and tiles with no glassmorphism for enhanced readability.

#### ⚙️ Other Optimizations
* Memory efficiency and TDLib disk cache auto-cleanup on startup.
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
