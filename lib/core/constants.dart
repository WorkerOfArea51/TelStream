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
  static const String currentVersion = '2.7.3';
  static const String changelog = '''
### 🚀 What's New in v2.7.3

* **Restored Season Tabs**: Restored the segmented season ChoiceChip/tab navigation inside the episode list screen to keep franchise episodes cleanly divided by season, while keeping the main catalog card simplified with total episode count.
* **Franchise Grouping and Sorting Fixes**: Resolved Re:ZERO movie and OVA naming/grouping issues (Memory Snow, Frozen Bond) to ensure they are named correctly, sorted chronologically, and prevent shifted season numbers.
* **Cached Database Pruning**: Invalidated legacy structured catalog cache to rebuild library from scratch with correct grouping.

### 🚀 What's New in v2.7.1

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
