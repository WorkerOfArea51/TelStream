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

We've rolled out a minor update to restore our classic look and fix build stability!

#### 🎨 Reverted to Classic Theme
* **Orange-Black Theme**: Main tabs are back to pure solid black backgrounds (`Colors.black`) with vibrant orange accent colors.
* **Fixed Library Tabs**: The **All** tab is now fully visible beside the **Favorites** tab (no white-on-white text issues).
* **More Screen Restored**: Menu list items now feature classic bright orange icons, and the TelStream play logo is reverted to its original cyan-glow design.
* **Bluish-Black Settings**: Deep bluish-black styling (`#0A1128`) is restored across Settings, Video Preferences, and the Episode List view.

#### 📥 Stable Background Downloads
* **Background Sync**: Active background downloads continue seamlessly in the system drawer even if the app is closed or minimized.
* **Recents Dismiss Cleanup**: Swiping away the app from your recents menu automatically halts downloads and purges the TDLib cache to save storage.
* **Exit Playback Safety**: Exiting the video player no longer deletes or cancels your started background downloads.
* **Autoplay Pausing**: Video playback now automatically pauses when you minimize the app.

#### ⚙️ Bug Fixes & Improvements
* Fixed Flutter compile errors related to constant constraints in the navigation menus.
* Added a dynamic Markdown parser for cleaner and rich presentation of in-app update notes.
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
