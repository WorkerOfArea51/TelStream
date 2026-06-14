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
  static const String currentVersion = '2.0.2';
  static const String changelog = '''
### 🚀 What's New in v2.0.2

We've rolled out a major feature update for Appearance and Theming customization!

#### 🎨 Custom Appearance & Theme Modes
* **Theme Modes Supported**: Choose between **Light Mode**, **Dark Mode**, **Dark AMOLED Mode** (pure `#000000` black background for screen and settings to save battery), or **System Mode** (follows system settings).
* **Color Themes Selector**: Personalize the app's accent and background colors:
  * **TelStream Classic**: The default signature hybrid theme with solid black main pages and deep bluish-black settings.
  * **Sunset Cyberpunk**: Neon magenta accent lines with dark purple-violet layouts.
  * **Aurora Abyss**: Vibrant cyan accent highlights with dark teal backgrounds.
  * **Midnight Slate**: Indigo accents with clean slate-grey configurations.

#### ⚙️ Standard Settings Layout
* Added a dedicated **Appearance** section inside settings for live theme preview and selection.
* Completely dynamic accents and background resolution across the whole application.
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
