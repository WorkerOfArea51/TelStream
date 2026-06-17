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
  static const String currentVersion = '2.3.5';
  static const String changelog = '''
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

---

### 🚀 What's New in v2.3.3

This update brings critical bug fixes for player seeking, back navigation, and Android subtitles!

#### 📺 Gestures & Seeking
* **Double-Tap Seek Debouncer**: Implemented a 500ms debounce on double-tap seeking. The UI increments immediately, but we wait for you to finish double-tapping before sending the seek command to TDLib/player, eliminating playback freezes and buffering stalls.

#### 🧭 Orientation & Navigation
* **Back-Navigation Orientation Reset**: Exiting playback via the back button or system back gesture now immediately restores the app's portrait mode orientation, while orientation is correctly kept in landscape when transitioning between episodes.

#### 💬 Android Subtitles Reliability
* **Native Font Fallback Engine**: Updated native player configuration and directory mappings to ensure external/embedded subtitle tracks render correctly on Android.
* **Smart Auto-Select Track**: Automatically selects the first English/available subtitle track when no preference is saved.

---

### 🚀 What's New in v2.3.2

We have fixed major player issues and improved the seekbar style!

#### 💬 Subtitle Fixes (Android)
* **Local Font Fallback Extractor**: Added automatic font extraction to local storage, mapping it directly into `libass` and `libmpv`. Subtitles will now render correctly on Android devices even for custom embedded streams.

#### 📺 Visuals & Navigation
* **Premium Wavy Seekbar**: Stretched out seekbar waves for a smoother, cleaner, and less cluttered timeline.
* **Orientation Continuity**: Playback orientation now persists seamlessly in landscape during next-episode and auto-next transitions.

---

### 🚀 What's New in v2.3.1

We have fixed a critical player resume issue!

#### 🩹 Cold-Boot Resume Fix
* **Resolves Stale videoFileId Freezes**: Playback no longer freezes on "Buffering..." when launched from the **Continue Watching shelf** or **History tab** after an app restart. The player now dynamically queries the channel to obtain a fresh file ID before starting the stream.

---

### 🚀 What's New in v2.3.0

We have implemented advanced subtitle rendering, smart next-episode preloading, and active playback speed-boost optimizations!

#### 💬 Subtitles & Multi-Track Memory
* **Auto-apply Preferred Tracks**: Added track preferences persistence. Subtitle and audio tracks chosen during playback are automatically remembered and applied to subsequent videos.
* **libass Subtitle Engine**: Activated advanced SSA/ASS/SRT subtitle rendering with a bundled high-quality font asset (`Roboto-Regular`), ensuring embedded subtitle tracks display beautifully.

#### ⏭️ Smart Preloading & Network Throttling
* **Next-Episode Preloading**: Automatically schedules low-priority preloading of the next episode's first 15 MB in the background when the current video crosses 80% progress, achieving near-instant play transitions.
* **Auto-Throttling Throws**: Pauses background offline downloads and channel history synchronization during active streaming, dedicating 100% of your network connection bandwidth to the player. Background tasks automatically resume once playback stops.
* **Ultra-Low Buffer Times**: Increased cache memory limits to 64 MB and pre-fetch limits to 60 seconds. Plays instantly without artificial start latency.

---

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
