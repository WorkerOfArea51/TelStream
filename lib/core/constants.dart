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
  static const String currentVersion = '2.3.6';
  static const String changelog = '''
### 🚀 What's New in v2.3.6

This update resolves video orientation issues when switching episodes and implements a dual-mode subtitle renderer on Android!

#### 📺 Orientation Continuity
* **Seamless Episode Transitions**: Verified active player state during page replacement to prevent orientation resets. The player now remains in landscape mode seamlessly when transitioning between episodes, only restoring portrait mode when you exit playback.

#### 💬 Subtitle Compatibility
* **Dual Subtitle Renderer**: Added a Subtitle Renderer setting in Player Preferences. You can choose between a highly-compatible Flutter-based overlay rendering engine (which renders widgets on top of the player) and Native libass.
* **Hardware Acceleration Toggle**: Added a toggle under Subtitles section to enable/disable GPU-accelerated video decoding. Disabling this fallback to software decoding, which resolves issues where subtitles are hidden by Android direct-to-surface GPU overlays.
* **Native Font Family Resolution**: Fixed font loading in Native libass mode on Android by properly mapping family names to the custom fonts directory instead of using file paths.
* **Outline Customization Styling**: Custom font size, color, delay, and font preferences are fully applied to the Flutter renderer with premium black stroke outlines for optimal readability.

---

### 🚀 What's New in v2.3.5

This update brings dynamic storage stats, UI overlap fixes, and advanced subtitle rendering improvements!

#### 📊 Dynamic Storage Stats
* **Real-time Disk Gauges**: Replaced hardcoded values in Settings. The app now dynamically calculates cache, downloads, and actual total/free device storage using platform APIs (StatFs on Android, PowerShell on Windows) to match your device's file manager.

#### 📺 Episode List Layout & Navigation
* **Bottom Scroll Spacer**: Added a 120px bottom scroll margin to the episode list. This allows you to scroll all cards completely above the floating favorite icon, ensuring download buttons are never blocked.

#### 💬 Subtitle Compatibility Enhancements
* **Hardware Accelerated Blending**: Configured decoder blending and timing fixes (`blend-subtitles` and `sub-fix-timing`) to display PGS/VobSub graphics, ASS, and SRT subtitle tracks seamlessly on Android.
* **Asynchronous Selection Verification**: Added a 300ms verification retry loop during track changes to ensure manual selections are properly synchronized and persist through track list updates.

---

### 🚀 What's New in v2.3.4

This update brings a critical fix for Android subtitle rendering and introduces customizable system font integration!

#### 💬 Subtitle Display & System Fonts
* **System Fonts Integration**: Enabled mpv system font provider fallback on Android to resolve missing/invisible subtitles in custom/foreign language media.
* **Asset Path Initialization**: Fixed native font loader initializer exception by strictly using validated asset paths.
* **On-the-Fly Toggle & Settings**: Added a "Use System Fonts" toggle inside both the in-video Subtitle Customizer dialog and Player Preferences settings.
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
