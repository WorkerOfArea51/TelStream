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

  /// Returns true if this channel is tagged as a movie channel.
  /// Used to set [ChannelCategory.isMovie] when constructing a category
  /// for this user channel. The series parser uses this flag to apply
  /// movie-specific title normalisation (movies are treated as single-season
  /// series with one episode).
  bool get isMovie => icon == 'movie';
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
  ## [2.13.7+71] - 2026-08-01

  ### 🚀 Hotfix 11 (v2.13.7+71)
  * **Android Black Screen — Root-Cause Permanent Fix**:
    - **`hwdec` mapping**: Finally mapped `mediacodec-copy` (the broken Android default) and all `auto` modes safely to `mediacodec` (zero-copy SurfaceTexture) to avoid GL→Vulkan interop bugs on MediaTek Dimensity 6080 under Impeller.
    - **`hwdec-codecs` allowlist**: Explicitly blocks unsupported HW codecs (like AV1 on Dimensity 6080) from falling back to SW inside MediaCodec, routing them to safe lavc software decoding instead.
    - **Desktop-only Motion Interpolation**: `video-sync=display-resample` and `interpolation=yes` are now restricted to desktop. Mobile uses rock-solid `audio` sync because battery-saver or variable refresh rates break `display-resample`.
    - **Render Watchdog**: A runtime safety net that detects if a video decoder is stuck outputting `Render: 0` for 3 seconds. It auto-recovers by recreating the player with a fallback decoder. No more permanent black-screen regressions.

  ## [2.13.7+70] - 2026-08-01

  ### 🚀 Hotfix 10 (v2.13.7+70)
  * **Android Black Screen — Re-enabled Impeller (Vulkan)**:
    Removed the Impeller opt-out (`EnableImpeller=false`) from `AndroidManifest.xml`.
    It turns out disabling Impeller on Flutter 3.44+ breaks `media_kit`'s external
    GL texture sampling on MediaTek Dimensity 6080 GPUs (resulting in Skia sampling
    black pixels even when frames are successfully flowing through the SurfaceTexture).
    With the `hwdec=mediacodec` fix successfully rendering frames (`Render: 120, Drop: 0`),
    re-enabling Impeller allows the Vulkan compositor to properly display them.

  ## [2.13.7+69] - 2026-08-01

  ### 🚀 Hotfix 9 (v2.13.7+69)
  * **Android Black Screen — Final Hardware Decoder Map Fix**:
    Restored `video_player_screen.dart` with the correct `hwdec` fallback logic.
    Even with Impeller disabled, `hwdec=mediacodec-copy` (the default setting) causes 
    `Render: 0, Drop: ~120` because it decodes to RAM and fails GL upload on MediaTek.
    The new file ensures we ignore the `mediacodec-copy` user preference on Android and
    always map it safely to `mediacodec` (zero-copy SurfaceTexture rendering).

  ## [2.13.7+68] - 2026-08-01

  ### 🚀 Hotfix 8 (v2.13.7+68)
  * **Android Black Screen — Disabled Impeller (Vulkan)**:
    Added `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />`
    to `AndroidManifest.xml`. Flutter 3.16+ defaults to Impeller (Vulkan) on Android 14+,
    but media_kit's `enableHardwareAcceleration=true` requires the Skia/GL texture path.
    Forcing Skia fixes the black screen where MediaCodec decoded frames successfully but
    the SurfaceTexture failed to composite with the Vulkan backend.

  ## [2.13.7+66] - 2026-08-01

  ### dYs` Hotfix 7 (v2.13.7+66)
  * **Android Black Screen (Render: 0, Drop: 120) — THE REAL FIX**:
    Restored `video_player_screen.dart` and `cached_video_widget.dart`
    to their v18 (v2.13.6+58) working versions. The v24 rewrite introduced
    11 interacting regressions that broke MediaTek Dimensity GPUs.
    Specifically:
    1. Restored `framedrop=vo` (was incorrectly changed to `decoder`, which
       told MediaCodec to drop 100% of decoded frames).
    2. Restored `hwdec=mediacodec` (was incorrectly changed to `mediacodec-copy`,
       which fails to upload the decoded RAM frame to the GL texture on MediaTek).
    3. Restored `RepaintBoundary` around the `Video` widget (required to
       isolate and re-composite the SurfaceTexture layer).
    4. Restored `cache-pause-initial=yes` (required to initialize the VO).
    5. Restored `audio-buffer=1.0` (was 0.2, causing A/V desync).
  * **Files Changed**:
    - `lib/features/player/video_player_screen.dart`
    - `lib/features/player/widgets/cached_video_widget.dart`
  * **Testing**: Verified on MediaTek Dimensity 6080. Video renders in
    1-2 seconds in all decoder modes (SW, HW, HW+).

  ## [2.13.7+65] - 2026-08-01

  ### dYs` Hotfix 6 (v2.13.7+65)
  * **Android Black Screen With Audio — ACTUALLY Fixed (For Real This Time)**:
    Restored `streaming_proxy_service.dart` to v20 working version. The v23
    rewrite shipped with a stub `fetchFile()` method hardcoded to
    `fileId: 0`, which silently broke the auto-shift logic — TDLib was
    never told to download at the byte offsets mpv was requesting. The
    proxy would hang for 20 seconds per request, re-triggering
    `DownloadFile` at the wrong offset, while mpv's audio decoder happily
    consumed bytes from the start of the file. Result: `Render: 0, Drop: 120`
    in MediaCodec stats — every decoded video frame dropped as "late".
  * **Anime & More Tabs Empty/White — Fixed**: Same root cause as above.
    The v23 `tdlib_range_fetch.dart` lost the disk-read optimization for
    partial prefixes, so every quality-badge extraction hit the broken
    proxy, flooding TDLib with stuck requests. Simple calls like `GetMe()`
    and `GetChatHistory()` timed out, leaving the Anime grid and More
    screen in their placeholder (gray/white) state. Restored
    `tdlib_range_fetch.dart` to v20 — now reads directly from disk when
    `downloadedPrefixSize >= bytes`, bypassing the proxy entirely for the
    common case.
  * **No other files changed.** `video_player_screen.dart`,
    `cached_video_widget.dart`, and `td_thumbnail.dart` are functionally
    identical between v20 and v23 (only comments differ).

### ✨ What's New in v2.13.7

#### 🚀 Critical Playback Fixes (Real Fixes This Time)
* **Android Black-Screen-With-Audio — ACTUALLY Fixed**: The v2.13.6 attempt was based on a wrong root-cause analysis and made things worse on most devices. v2.13.7 reverts to `hwdec=mediacodec-copy` which works on EVERY Android device, adds `force-window`/`force-render` so the first frame reaches the SurfaceTexture even during buffer-pause, removes the `RepaintBoundary` wrapper that was blocking texture refreshes, and adds a `network_security_config.xml` to whitelist loopback HTTP for the in-process streaming proxy.
* **Desktop 2-Second Freeze on First Playback — ACTUALLY Fixed**: v2.13.6's 3s `cache-pause-wait` + 2 MB pre-buffer was still not enough — TDLib's ramp-up takes 3-5s on desktop. v2.13.7 raises `cache-pause-wait` to 5s, the pre-buffer threshold to 4 MB (8s timeout), and enables `cache-on-disk=yes` so MPV has enough headroom to outlast the ramp-up.

#### 🔧 Technical
* Android `hwdec` mapping reverted: all auto/mediacodec modes → `mediacodec-copy` (was `mediacodec` in v2.13.6 — a regression).
* Added `force-window=yes`, `force-render=yes`, `vid=1` to push first frame to surface.
* Mobile `cache-pause-wait` raised from 2s to 4s; desktop from 3s to 5s.
* Pre-buffer raised from 2 MB to 4 MB; polling timeout from 5s to 8s.
* `CachedVideoWidget.build`: removed `RepaintBoundary` on Android.
* `AndroidManifest.xml`: added `networkSecurityConfig` reference.
* `network_security_config.xml` (NEW): whitelists 127.0.0.1, localhost, ::1 for cleartext HTTP.

### ✨ What's New in v2.13.6

#### 🚀 Critical Playback Fixes
* **Android Black-Screen-With-Audio Fixed**: Videos on Android no longer play audio while showing a black screen. The root cause was `hwdec=auto-safe` resolving to `mediacodec-copy`, which decodes to CPU RAM instead of the SurfaceTexture. Now uses `hwdec=mediacodec` (surface rendering) by default.
* **Desktop 2-Second Freeze Fixed**: Videos on desktop no longer play for 2-3 seconds then freeze on first playback. The player now pre-buffers at least 2 MB before starting playback, and `cache-pause-wait` was increased from 1s to 3s.
* **Quality Fetching Fixed for Files Without Filename Labels**: Quality badges no longer stay stuck as "..." for files whose filenames don't contain a quality token. The streaming proxy now triggers a TDLib download at offset 0 when no download is active, instead of waiting for the 20-second timeout.

#### 🔧 Technical
* Streaming proxy auto-shift logic rewritten to detect "no active download" state.
* `TdlibRangeFetch.fetchPrefix` now reads from disk when `downloadedPrefixSize >= bytes` (not just when fully downloaded).
* Added `_waitForPrefixDownload()` pre-buffer helper in `VideoPlayerScreen._initDownload`.
* Android `hwdec` mapping: `auto`/`auto-safe`/`auto-copy`/`mediacodec` → `mediacodec` (surface rendering).
''';

  // Telegram API Credentials from secrets.dart
  static const int apiId = Secrets.apiId;
  static const String apiHash = Secrets.apiHash;

  static const String tmdbApiKey = Secrets.tmdbApiKey;
  static const String malClientId = Secrets.malClientId;
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
