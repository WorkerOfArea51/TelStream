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
  static const String currentVersion = '2.7.0';
  static const String changelog = '''
### 🚀 What's New in v2.7.0

* **Layout Views & Custom Aesthetics**: Added persistent layout options to switch the catalog library view between Grid (2-column), Compact Grid (3-column visual layout), and List View (detailed poster + vertical rows).
* **Release Year Search Indexing**: Optimized search engine functionality to match catalog items by release years of the active seasons.
* **Audio Equalizer Enhancements**: Implemented an audio equalizer with Flat, Bass Boost, Vocal Booster, Treble Booster, Classical, Rock, and Pop presets and a 5-band manual fine-tuning control.
* **Tuned Player Speeds & Gestures**: Added custom fine-tuning playback speed selectors, adjustable gesture sensitivity configuration (Low, Normal, High), and support for user-defined long press playback speed (defaulting to 1.5x to prevent sync lag).
* **Local & External Subtitles Picker**: Integrated a file picker for external subtitles (`.srt`, `.vtt`, `.ass`, `.ssa`, `.sub`) with secure sandbox copying and improved error propagation for subtitle downloading.
* **Manual Tracker Matcher UI**: Added direct AniList, MyAnimeList, and Trakt.tv search integration and progress sync indicator toasts within the media player interface.
* **Subtitle Streaming Fixes**: Resolved HTTP loopback range and Matroska content-type headers matching inside the proxy service to load embedded subtitles seamlessly.

### 🚀 What's New in v2.6.4

* **Forced Subtitles & Selection Retention**: Prevented automatic track stream updates from overriding manual audio and subtitle track selections during playback.
* **PGS & ASS/SSA Subtitles Blending**: Auto-detects and blends PGS/image-based and advanced ASS/SSA subtitle tracks directly onto the video stream to guarantee 100% correct typography, styling, and positioning.
* **Android Decoder Warning**: Displays a compatible decoder notice when choosing PGS/ASS subtitles under zero-copy mediacodec hardware acceleration.
* **Expressive Material 3 Controls**: Realigned play control icons (Prev, circular Play/Pause, Next) horizontally and perfectly centered them.
* **Collapsible Quick Actions Row**: Quick control actions (Mute, Rotate, Chapters, A-B Repeat, Sleep Timer) collapse under an animated Chevron toggle button.
* **Intro Skip Helper**: Replaced automatic intro/outro triggers with a manual skip button (`90s+`) located next to the Next button.
* **Autoplay Next Slide-in Card**: Animate episode autoplay countdown card to slide in smoothly after a 2-second delay.
* **Dynamic Screenshot Saving**: Screenshots are saved under custom download paths if configured, otherwise falling back cleanly to picture and download directories.

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
