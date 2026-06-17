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
  static const String currentVersion = '2.5.0';
  static const String changelog = '''
### 🚀 What's New in v2.5.0

This update introduces intelligent auto-skipping, visual seekbar preloading, and lag-free slider dragging for a truly premium, seamless streaming experience.

#### 🤖 Intelligent Skip Intro & Outro
* **Crowdsourced Anime Detection**: Integrated the Jikan MAL Search and AniSkip APIs to automatically retrieve precise opening and ending time intervals for anime.
* **Contextual Skip Buttons**: A beautiful, floating frosted-glass skip button ("Skip Intro" / "Skip Outro") appears dynamically when the play position enters an active range.
* **Auto-Skip Mode**: Enable the "Auto Skip" toggle to instantly jump past intros/outros automatically, accompanied by a clean OSD toast notification.
* **Smart Local Heuristic Fallback**: Falls back to logical defaults (1:30 to 3:00 for intros, last 120s to last 30s for outros) for non-anime web series.

#### 📈 Visual Seekbar Preloading
* **Download Buffer Visualization**: Both the Standard and Wavy seekbar styles now render a light, translucent secondary track showing how much of the video is preloaded in real-time.
* **Lag-Free Slider Scrubbing**: Extracted seekbar controls to an isolated stateful sub-tree, eliminating layout rebuild overhead and delivering silky-smooth, 60fps sliding.
* **Direct Player Toggles**: Toggle Auto Play, Auto Next, and Auto Skip preferences instantly via checklist checkboxes rendered below the player seekbar.
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
