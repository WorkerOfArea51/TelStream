import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'secrets.dart';

class ChannelCategory {
  final String title;
  final int channelId;
  final String inviteLink;
  final bool isMovie;
  
  const ChannelCategory({
    required this.title,
    required this.channelId,
    required this.inviteLink,
    this.isMovie = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelCategory &&
          channelId == other.channelId;

  @override
  int get hashCode => channelId.hashCode;
}

class UserChannel {
  final String id;          // unique ID (use timestamp or UUID)
  final String title;       // user-defined name (e.g., "My Anime Channel")
  final int channelId;      // Telegram channel ID (e.g., -1001234567890)
  final String? inviteLink; // optional Telegram invite link
  final String icon;        // icon name (e.g., 'movie', 'tv', 'anime', 'custom')
  final DateTime addedAt;   // when the channel was added
  
  const UserChannel({
    required this.id,
    required this.title,
    required this.channelId,
    this.inviteLink,
    required this.icon,
    required this.addedAt,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channelId': channelId,
    'inviteLink': inviteLink,
    'icon': icon,
    'addedAt': addedAt.toIso8601String(),
  };
  
  factory UserChannel.fromJson(Map<String, dynamic> json) => UserChannel(
    id: json['id'] as String,
    title: json['title'] as String,
    channelId: json['channelId'] as int,
    inviteLink: json['inviteLink'] as String?,
    icon: json['icon'] as String? ?? 'custom',
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class Constants {
  static Locale getLocale(String langCode) {
    switch (langCode) {
      case 'ru':
        return const Locale('ru');
      default:
        return const Locale('en');
    }
  }
  static String _currentVersion = '0.0.0+0';
  static String get currentVersion => _currentVersion;

  static Future<void> initVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}
  }

  static const String changelog = '''
### ✨ What's New in v2.10.4

#### 🎉 New Features
* **User-Added Channels**: Add your own Telegram channels/groups! Go to More → My Channels to add public or private channels. Supports @username, t.me/+invite, and t.me/c/ID links.
* **Batch Download**: Download entire seasons with one tap! "Download All" button appears below season chips.
* **WiFi-Only Downloads**: Toggle in Downloads screen to pause downloads on cellular data.
* **Pause All / Resume All**: Bulk control all downloads from the Downloads screen AppBar.
* **Season-Specific Metadata**: Web series now show different posters, plots, and cast per season (TMDB integration).
* **Auto-Download Subtitles**: One-tap auto-download of the first subtitle match.
* **16 Subtitle Languages**: Added Japanese, Chinese, Korean, Hindi, Italian, Portuguese, Russian, Turkish, Thai, Vietnamese.

#### 🎨 UI/UX Improvements
* **Material 3 Theme**: Upgraded cards, buttons, dialogs, sliders, and typography to full M3 Expressive design.
* **Settings Redesign**: Visual color theme picker with swatches, M3 section headers, cleaner layout.
* **Seekbar Polish**: Themed seekbar with dynamic colors (adapts to your theme).
* **Library Card Polish**: Fixed border visibility, shadow overlap, and badge positioning.
* **Movie Labels**: Movies now show "Movie (1 EP)" instead of "Season 1 (1 EP)".
* **Duration Format**: Fixed duration display to include hours (e.g., "1:24:56" instead of "24:56").
* **Default Subtitle Size**: Changed from 45 to 20 (more reasonable default).

#### 🔧 Bug Fixes
* Fixed video player crashes (ANR) on Android and PC
* Fixed update popup not appearing without VPN (multi-mirror support)
* Fixed infinite proxy auto-shift loop causing ANR
* Fixed double-dispose of Player on back-press
* Fixed PC provider error on episode change
* Fixed seek-during-buffer thrash leaving player paused
* Fixed re-buffering when reopening cached videos
* Fixed subtitle size not migrating from old default
* Fixed mediacodec-copy decoder on PC
* Fixed download "Resume All" not starting downloads
* Added download retry on failure (3 attempts with backoff)
* Added network change detection (auto-pause/resume on WiFi drop)
* Fixed real-time deletion sync for all channels
* Fixed movie duration format (now shows hours)
* Fixed episode title cleaning (all video extensions)
* Fixed range error on empty seasons
* Fixed loadMore infinite loop on short lists
* Fixed screen-time tracker running while backgrounded
* Fixed search debounce on calendar screen
* Fixed history play null-assertion crash
''';

  // Telegram API Credentials from secrets.dart
  static const int apiId = Secrets.apiId;
  static const String apiHash = Secrets.apiHash;

  static const String tmdbApiKey = Secrets.tmdbApiKey;
  static const int adminUserId = Secrets.adminUserId;

  // Categories & Channels
  static const List<ChannelCategory> categories = [
    ChannelCategory(
      title: 'Anime',
      channelId: Secrets.animeChannelId,
      inviteLink: Secrets.animeInviteLink,
      isMovie: false,
    ),
    ChannelCategory(
      title: 'Movies',
      channelId: Secrets.movieChannelId,
      inviteLink: Secrets.movieInviteLink,
      isMovie: true,
    ),
    ChannelCategory(
      title: 'Web Series',
      channelId: Secrets.webSeriesChannelId,
      inviteLink: Secrets.webSeriesInviteLink,
      isMovie: false,
    ),
  ];
}

class PremiumPageRoute<T> extends MaterialPageRoute<T> {
  final Widget child;

  PremiumPageRoute({
    required this.child,
    super.settings,
    super.fullscreenDialog,
  }) : super(
         builder: (context) => child,
       );

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // On iOS, defer to parent for native swipe-from-edge pop.
    // On Android, defer to parent for predictive-back support.
    if (Platform.isIOS || Platform.isAndroid) {
      return super.buildTransitions(context, animation, secondaryAnimation, child);
    }
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOutCubic;
    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    return SlideTransition(
      position: animation.drive(tween),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
