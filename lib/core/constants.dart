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
  static const String currentVersion = '2.7.9';
  static const String changelog = '''
### 🚀 What's New in v2.7.9

* **High-Performance Adaptive Streaming & Resilient Network Handovers**:
  - Optimized streaming chunk size to 128 KB (down from 1 MB) to ensure smooth, incremental data delivery to the video player under variable bandwidth networks (e.g. 2.4 GHz WiFi, unstable mobile data, and congested ISPs).
  - Implemented a resilient download wait loop: Every 1.5 seconds, if the player is waiting for bytes, the proxy checks the connection and re-triggers the TDLib download task. This auto-recovers and continues streaming seamlessly during network switches (cellular to WiFi, 2.4GHz to 5GHz/6GHz handovers).
  - Increased MPV's forward cache size to 100 MB and the readahead time limit to 60 seconds. This allows the player to aggressively buffer content when the connection is fast, preventing playback stutters when entering weak connection zones.
  - Configured a 5-second buffer recovery hold (`cache-pause-wait`) before resuming playback after exhaustion to avoid continuous start-stop stutter cycles.

### 🚀 What's New in v2.7.8

* **Player Interface & Subtitle Compatibility Enhancements**:
  - Redesigned player bottom control layout dynamically for portrait and landscape orientations to prevent button and text overlaps.
  - Fixed native subtitle rendering by always enabling subtitle blending when native rendering mode is selected, ensuring subtitle tracks render correctly on all decoders.

### 🚀 What's New in v2.7.7

* **Subtitle Rendering & Decoder Compatibility Optimizations**:
  - Implemented dynamic hardware decoder switching: Automatically redirects direct hardware decoding (`mediacodec`) to copy-back decoding (`mediacodec-copy`) when the native subtitle renderer (`libass`) is selected. This ensures native subtitles always overlay and display correctly without screen overlays blocking them.
  - Added subtitle parsing pre-roll and fallback optimizations: Embedded subtitles are parsed and cached further ahead (10s) to prevent delays on seek, non-Unicode subtitle encodings fall back to UTF-8, and ASS margins are utilized effectively.

### 🚀 What's New in v2.7.6

* **Naruto Season Sorting Fix**: Resolved an issue where Naruto seasons sorted out of order (e.g. Season 4 showing after Season 9) due to accidental out-of-order Telegram uploads. Naruto seasons are now sorted strictly by season number ascending rather than by Telegram upload order.

### 🚀 What's New in v2.7.5

* **Franchise Grouping Separation**: Fixed an issue where separate series in the same franchise (e.g. Dragon Ball, Dragon Ball Z, and Dragon Ball Daima) were incorrectly merged under the base series card in the library. They now display as separate, independent titles.

### 🚀 What's New in v2.7.4

* **Strict Chronological Franchise Sorting**: Changed season sorting within a franchise to be sorted strictly by Telegram upload/message ID order (ascending). This resolves sorting issues for Dragon Ball, Log Horizon, Mushoku Tensei, Dr. Stone, Re:ZERO, Sword Art Online, etc., aligning them exactly with the order they were posted on the channel.
* **Restored Season Tabs**: Restored the segmented season ChoiceChip/tab navigation inside the episode list screen to keep franchise episodes cleanly divided by season.

### 🚀 What's New in v2.7.3

* **Airing Calendar Release Schedules**: Integrated a tabbed weekday release calendar fetching anime schedules from the public Jikan API with memory-caching protection.
* **Downloads Queue Reordering**: Replaced active downloads queue with a drag-and-drop `ReorderableListView` to prioritize active TDLib download streams.
* **Cache Watched Pruning**: Added a smart pruning action in Advanced Cache settings to clean local files and TDLib buffers for episodes watched >90%.
* **Modular Player Control Sheets**: Extracted dialog components (Equalizer, Speed Selector, Tracks Panel, Downloader) to decrease player overhead.
* **REST Subtitle Downloader**: Integrated OpenSubtitles v2 and SubDL REST API search with zip extraction and credential configurations.
* **Layout Views & Custom Aesthetics**: Added persistent layout options to switch the catalog library view between Grid, Compact Grid, and List View.
* **Release Year Search Indexing**: Optimized search engine functionality to match catalog items by release years.
* **Audio Equalizer Enhancements**: Implemented an audio equalizer with Flat, Bass Boost, Vocal, Rock, Pop presets and a 5-band manual fine-tuning control.
* **Tuned Player Speeds & Gestures**: Added custom fine-tuning playback speed selectors, adjustable gesture sensitivity configuration, and support for user-defined long press playback speed.
* **Local & External Subtitles Picker**: Integrated a file picker for external subtitles with secure sandbox copying and improved error propagation.
* **Manual Tracker Matcher UI**: Added direct AniList, MyAnimeList, and Trakt.tv search integration and progress sync indicator toasts within the player interface.
* **Subtitle Streaming Fixes**: Resolved HTTP loopback range and Matroska content-type headers matching inside the proxy service to load embedded subtitles seamlessly.
* **Seamless & Robust Streaming**: Optimized HTTP loopback proxy chunk handling (1MB buffers), lookbehind grace offsets (1MB), and enabled mpv startup prebuffering (`cache-pause-initial`) to prevent stutters/glitches on mobile data, 2.4GHz, and 5GHz WiFi.
* **In-Player Renderer Overrides**: Switch subtitle renderers on-the-fly directly in the subtitle track selector panel.
* **Subtitle Delay Sync Slider**: Adjust subtitle sync offsets from -5.0s to +5.0s in 0.1s increments with a one-click Reset button.
* **Enhanced Subtitle Visibility**: Render Flutter text overlay subtitles with extra bold thickness, 8-way letter outline, and heavy drop shadow.
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
