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
  static String _currentVersion = '0.0.0+0';
  static String get currentVersion => _currentVersion;

  static Future<void> initVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}
  }

  static const String changelog = '''
### ✨ What's New in v2.10.3

* **🚀 Audit Remediation**: Massively improved stability, eliminated stream subscription leaks, optimized storage disk I/O, fixed various race conditions and memory leaks.
* **🛡️ Updater Improvements**: Enforced strict SHA-256 installer integrity checks for auto-updates.
* **🔧 Background Polish**: Refactored TDLib JSON handlers, implemented robust error boundaries, and fixed AMOLED theme presets.
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
