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
  static const String currentVersion = '2.9.2';
  static const String changelog = '''
### 🚀 What's New in v2.9.2

* **Draggable Subtitle Position Overlay (Phone & PC)**:
  - Drag the custom subtitle overlay anywhere on the screen (supports finger drag on phones and mouse drag on PC).
  - The app automatically remembers and saves your custom position.
* **Telegram-style Startup Jet Animation**:
  - Replaced the initial loading screen with a smooth Telegram-style logo fly-in animation (flying jet effect inside a blue gradient circle) on app launch.
* **Continue Watching Screen Redirection & Glow Highlights**:
  - Tapping a Continue Watching item now navigates to the series detail screen, selects the correct season, scrolls to the last watched episode, and highlights it with a 5-second glowing outline.
* **Telegram Document Video Thumbnail Support**:
  - Video files uploaded as Document attachments (.mkv, .mp4, etc.) will now parse and render their original video thumbnails instead of showing generic grey icons.
* **Persistent Layout View Preferences**:
  - Saved layout preferences (`Grid`, `Compact`, `List`) separately so they never reset during app updates, logouts, or cloud merges.
* **Playback Stability & Double Subtitle Fixes**:
  - Mapped default Windows hardware decoding to Direct3D 11 (`d3d11va`) to resolve grey video macroblock glitching.
  - Dynamically toggle sub-visibility to completely prevent double-rendering subtitle layers on PC.
  - Solved loopback proxy header timeouts that caused video playback to freeze at `0:00` on startup.
* **Removed Swipe Gestures**:
  - Removed swiping gesture shortcuts in the episode list to prevent accidental downloads or watch status edits during scrolling.
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
