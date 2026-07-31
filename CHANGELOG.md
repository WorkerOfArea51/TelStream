# Changelog

## [2.13.6] - 2026-07-31

### ✨ What's New in v2.13.6+58

#### 🚀 Critical Playback Fixes
* **Android Black-Screen-With-Audio Fixed**: Videos on Android no longer play audio while showing a black screen. The root cause was `hwdec=auto-safe` resolving to `mediacodec-copy`, which decodes to CPU RAM instead of the SurfaceTexture — incompatible with `vo=gpu` set by `enableHardwareAcceleration=true`. Now uses `hwdec=mediacodec` (surface rendering) by default, which works correctly with `vo=gpu`. MPV still auto-falls-back to software decoding if a codec fails.
* **Desktop 2-Second Freeze Fixed**: Videos on desktop no longer play for 2-3 seconds then freeze on first playback. Two changes fix this:
  - **Pre-buffering before `player.open()`**: The player now waits for TDLib to download at least 2 MB at the start of the file (up to 5 seconds max) before handing the proxy URL to MPV. This ensures MPV has data ready to read immediately on connect.
  - **`cache-pause-wait` increased from 1s to 3s on desktop**: Gives MPV enough time to fill its demuxer cache before starting playback, preventing the buffer-drain-then-freeze pattern.
* **Quality Fetching Fixed for Files Without Filename Labels**: Quality badges no longer stay stuck as "..." for files whose filenames don't contain a quality token (e.g. `1080p`, `720p`). The streaming proxy's auto-shift logic now triggers a TDLib download at offset 0 when no download is active — previously it only shifted when an existing download was "out of bounds", which left metadata-extraction requests waiting forever for bytes that never arrived.

#### 🔧 Technical
* `StreamingProxyService._handleRequest`: Rewrote the auto-shift decision logic. Added `noActiveDownload` detection — when `activeOffset == 0 && baseDownloaded == 0 && prefixSize == 0`, the proxy immediately issues `td.DownloadFile` at the requested offset instead of waiting for the 20-second timeout.
* `TdlibRangeFetch.fetchPrefix`: Now reads directly from disk when `downloadedPrefixSize >= bytes` (not just when the file is fully downloaded). This skips the HTTP roundtrip entirely when TDLib has already cached the first 2 MB — common after the user has played or scrubbed the video once.
* `VideoPlayerScreen._initDownload`: Added `_waitForPrefixDownload()` helper that polls `td.GetFile` every 150 ms until `downloadedPrefixSize >= 2 MB` or 5 s elapse, called before `_startPlayback(proxyUrl)` on both the active-download and pre-emptive-fallback paths.
* `VideoPlayerScreen._initPlayerInstance`: Android `hwdec` mapping rewritten. `auto`, `auto-safe`, `auto-copy`, and `mediacodec` all map to `mediacodec` (surface rendering). `mediacodec-copy` is respected if the user explicitly chose it (for Native Blending subtitle compatibility). `no` remains `no` (software decoding).
* `VideoPlayerScreen._initPlayerInstance`: Desktop `cache-pause-wait` increased from `1` to `3` seconds.

## [2.13.5] - 2026-07-28

### ✨ What's New in v2.13.5+57

#### 🚀 Major Fixes
* **Player 0:01 Glitch Fixed**: Grouped movies on user-added channels now play correctly. The player now resolves the real Telegram file ID via the source's `chatId` directly, with a fallback to `Constants.categories` + user channels.
* **Episode Titles Preserved**: Descriptive episode names like "EP - 01 - Arrival" are no longer stripped by the release-group cleaner. The cleaner now only strips suffixes that follow a known release token (1080p, x264, WEB-DL, etc.).
* **Quality Badges Always Show**: Quality badges now display the real label (e.g. "1080p") immediately, using TDLib-provided dimensions. Badges brighten when the container is parsed for confirmation.
* **Refresh Metadata Works**: The "Refresh Metadata" button now actually refreshes. It clears the cache, re-runs extraction, and shows a snackbar with progress and result.
* **Quality Switcher Icon Appears**: The gear icon in the player header bar now appears for any episode with multiple qualities (even before container parsing completes), enabling in-player quality switching.

#### 🔧 Technical
* Catalog cache version bumped to v6 (old caches will be rebuilt on first launch).
* `VideoSource.hasMetadata` now returns true when height > 0, regardless of container type.
* Added `VideoSource.isContainerParsed` getter for confirming container-type detection.
* `VideoPlayerScreen` now accepts an optional `chatId` parameter for direct file ID resolution.
* `MetadataExtractionNotifier.extractMetadataForEpisode` now accepts `forceRefresh: bool`.
## [2.13.4] - 2026-07-28

### Fixed
- **Movie Grouping for User-Added Channels**: Multi-quality movies (720p/1080p/480p) now group into a single library card for ALL channel types, not just channels tagged with the "movie" icon. Release-token stripping (1080p, x265, HEVC, etc.) now runs unconditionally in `normalizeSeriesName`, so quality tokens no longer pollute the grouping key.
- **Full-Quality Episode Thumbnails**: Episode list thumbnails now download and display the full TDLib thumbnail (320x180+ pixels) instead of the tiny minithumbnail (~50x50). Thumbnails are crisp and match Telegram's quality. A new `thumbnailFileId` field is persisted in `VideoSource` for cache-load instant display.
- **Episode Title Format Preserved**: Episode titles now show the full cleaned format (e.g. "EP - 01 - The Magic That Started Everything") instead of just the descriptive name. The `EP - 01 -` prefix is preserved as the uploader intended. Quality/codec tags and file extensions are still stripped.
- **Quality Badge Accuracy**: Quality badges no longer show wrong labels (e.g. "720p" for a 1920x816 video). When container metadata hasn't been confirmed yet, the badge shows "..." instead of a potentially-wrong TDLib-provided label. Added "Refresh Metadata" option in episode long-press menu to force re-extraction.
- **`cleanDisplayTitle` Ordering Fix**: Release tokens are now stripped BEFORE dots are replaced with spaces, so `5.1` (with a dot) is correctly stripped instead of becoming `5 1` (which doesn't match the regex).
- **Player Quality Picker Gating**: The quality-picker gear icon in the player is now gated on `enableInPlayerQualitySwitch` (the correct setting) instead of `showQualityBadges` (the library-chip setting). Users who turned off quality badges but enabled in-player switching now see the gear icon.
- **Player Title Cleaning**: Player header title now uses `cleanDisplayTitle` for both the series name and episode title, eliminating raw-filename noise. Movie titles are no longer duplicated ("Nagabandham 2026 - Nagabandham 2026" -> just "Nagabandham 2026").
- **Cache Version Bump**: Catalog cache version bumped to 5, forcing a fresh re-parse on next launch so users see the new grouping immediately.

## [2.13.3] - 2026-07-27

### Fixed
- **Library Organization & Movie Grouping**: Overhauled the parsing engine to properly group multi-quality/multi-part movies under a single title instead of cluttering the library. Movies (videos without "S01E01" style naming) now aggregate correctly across different formats and qualities into a unified entry.
- **Aggressive Display Title Cleaning**: Substantially expanded the title cleaning logic to strip scene release tokens (e.g. 1080p, x265, HEVC, BluRay, web-dl, dual-audio, language tags) so UI displays clean, descriptive names.
- **Smart Year Detection**: Fixed a regex bug where titles containing years (e.g., "Batman 2022") were sometimes truncated incorrectly or left with stray parentheses.
- **Isolated Video Display Name**: Standalone videos now display an ultra-clean version of their filename in the UI rather than an ugly raw filename with underscores and `.mkv` extensions.
- **Episode Title Preservation**: When episode names include descriptive titles (e.g. "Episode 5 - Vegeta Attacks"), the UI now successfully extracts "Vegeta Attacks" rather than showing the fallback "Episode 5".
- **Emoji Preservation**: Emojis intentionally included at the start of filenames by uploaders (e.g., 🎬, ✨) are now fully preserved and rendered cleanly in episode lists rather than breaking alignment.

## [2.13.1] - 2026-07-27

### Fixed
- **Episode Thumbnails Restored**: Episode cards now display the video's minithumbnail (extracted from TDLib) instead of a gray placeholder. Thumbnails appear instantly on cache load — no network fetch needed.
- **Episode Titles Restored**: Grouped episodes now show descriptive titles extracted from filenames (e.g., "Episode 1 - The Magic That Started Everything" instead of just "Episode 1"). Supports `EP - XX - Title`, `S##E## - Title`, and `Episode XX - Title` patterns.
- **Duration Restored for Videos**: For messages sent as Telegram Videos (not Documents), duration is now read directly from TDLib's `video.duration` field — no container parsing needed. Appears instantly.
- **Quality Badge Restored for Videos**: For MessageVideo, width/height from TDLib are used immediately to show the quality badge (e.g., "1080p") without waiting for container parsing.
- **"Extracting..." Indicator**: While container metadata is being fetched for Document-type messages, the quality badge now shows "..." instead of "Unknown" to indicate extraction is in progress.
- **Metadata Merge Safety**: Container-parsed metadata no longer overwrites TDLib-provided duration when the parser fails to extract duration from the container.

All notable changes to this project will be documented in this file.

## [2.13.0] - 2026-07-27

### Added
- **Multi-Quality Video Support**: Episodes grouped from multiple Telegram messages now display as a single episode with selectable qualities. Quality is detected from container metadata (MP4 moov/tkhd, MKV EBML), not from filenames — works even when the developer uploads as Telegram documents without quality tags in the filename.
- **In-Player Quality Switching**: Switch quality without leaving the player. Playback position is preserved across switches via direct `player.open` + `player.seek`.
- **Quality Picker Sheet**: Modal bottom sheet with Auto / explicit quality options, file size display, Refresh (cache clear + re-extract), Play and Download actions.
- **Persistent Metadata Cache**: Quality metadata cached on disk via `flutter_secure_storage` with a 1-hour TTL for failed extractions, preventing redundant requests on messages that can't be parsed.
- **Concurrency-Limited Extraction**: `Pool(3)` from `package:pool` limits concurrent metadata extraction requests with FLOOD_WAIT exponential backoff retry.
- **Suffix Fetch for moov-at-end MP4s**: When the moov atom isn't in the first 2 MB (common for streaming-optimized MP4s), the extractor fetches the last 2 MB and scans for the moov signature.
- **Episode Grouper Denylist**: Opening/ending themes, recaps, previews, specials, OVA/ONA, NCOP/NCED, BD/DVD/Web-DL rips are excluded from episode grouping.
- **Settings**: New toggles for "Show Quality Badges in Library", "Enable In-Player Quality Switch", "Single Episode Download Quality", "Batch Download Quality (Series/Seasons)".

### Fixed
- **Round 1 Audit Fixes**: Removed forbidden `extractQuality` filename-based quality detection, replaced `json_serializable` with `fromFlatJson`/`toFlatJson`, removed `9999` sentinel, added denylist, added persistent cache, added concurrency limit.
- **Round 2 Audit Fixes**: Added Auto option to QualityPickerSheet, position-preserving quality switch in player, batch download quality setting.
- **Round 3 Audit Fixes**: Completed denylist (`ona|op|ed|tva|bd|dvd|web-dl`), removed final `9999` sentinel, stabilized episode key in `MetadataExtractionNotifier`, fixed suffix-fetch API call, debounced `VisibilityDetector` extraction, replaced fragile `VideoMetadataCache` null/unknown contract with explicit result type, shared `HttpClient` for range fetches, short-circuit on small files in suffix fetch, wait-for-ready before seek in quality switch, fixed `_downloadAllEpisodes` to use `batchDownloadQuality`, removed duplicate settings tile, added `prefetchEpisode` / `invalidate` / `invalidateAll` APIs.

## [2.12.1] - 2026-07-26

### Fixed
- **Tap to Switch Aspect Ratio**: Restored default fallback for `tap_to_switch_aspect_ratio` from `false` to `true`, fixing a regression where the gesture was disabled out of the box.
- **Source Cleanup**: Removed unused `eq_temp.txt` developer scratch file.

## [2.12.0] - 2026-07-25

### Added
- **Proxy Latency Manager**: Replaced basic proxy support with an advanced multi-proxy system featuring latency ping testing, auto-fetch from public proxy lists, and intelligent auto-reconnect to the fastest responsive proxy.
- **Proxy UI Overhaul**: Upgraded the proxy settings UI to display all saved proxies as selectable cards with live latency badges.

## [2.11.0] - 2025-07-25

### Added
- **Proxy Support for Login (Issue #9)**: Users in regions where Telegram is banned can now configure SOCKS5 or MTProto proxy before logging in. Proxy settings are accessible from both the login screen and the Settings screen. Includes auto-fetch of MTProto proxy lists from SoliSpirit/mtproto.
- **Clean Desktop Video Player**: Desktop video player now has a PotPlayer-style clean bottom bar (play/pause, stop, prev/next, time, volume, speed, settings, playlist) with no mobile UI leaking through. Mobile-only overlays (seek indicators, brightness, gestures, track selector panels) are properly gated and hidden on desktop.
- **Aspect Ratio Panel on Android**: Tapping the aspect ratio icon on Android now opens a selection panel (like subtitle/audio selector) instead of silently cycling through ratios.
- **Desktop Video Rendering Fix**: Video now renders properly on Windows desktop (no more black screen). Uses `d3d11va-copy` hardware decoder and eliminates Transform wrapper overhead on desktop.

### Changed
- **Desktop Bottom Bar Cleanup**: Removed redundant subtitle, audio track, and fullscreen buttons from desktop bottom control bar. Subtitle and audio are inside Settings panel; fullscreen is on the top bar. Bottom bar now shows only: speed toggle, settings gear, and playlist toggle.
- **Desktop Video Performance**: Removed unnecessary `Transform.scale`/`Transform.translate` compositing layers and `RepaintBoundary` wrapper on desktop, reducing rendering overhead.
- **Proxy Settings Persistence**: All proxy settings (type, server, port, credentials, MTProto secret) are saved persistently via Hive and applied before TDLib goes online.

### Fixed
- **Black Screen on Desktop**: Fixed video not rendering on Windows desktop. Root cause: mobile overlay gradient blocking video surface + missing hardware decoder configuration.
- **Android Aspect Ratio Silent Cycling**: Fixed aspect ratio button silently cycling through ratios on Android. Now shows a proper selection panel.
- **Mobile UI on Desktop**: Fixed mobile video player overlays (seek bars, brightness indicators, gesture controls) appearing on desktop player.
- **Proxy Debounced Save**: Fixed proxy settings writing to disk on every keystroke. Now debounced at 500ms to reduce I/O.
- **Dev Script Cleanup**: Removed `scripts/patch_proxy_url.py` containing hardcoded developer paths.

## [Unreleased]

### Added
- **Native Dependency Automation**: Added `scripts/download_windows_dlls.ps1` to automatically fetch required `tdjson` binaries for Windows builds.
- **Season-Specific TMDB Metadata**: The app now dynamically fetches season-specific metadata from TMDB, ensuring accurate posters, synopses, and cast for each season.
- **Dynamic Recommendations**: Added "More Like This" recommendations populated from TMDB show-level data when viewing a series.
- **Persistent Metadata Caching**: Implemented local caching in `StorageService` to instantly load previously fetched season metadata without redundant API calls.

### Changed
- **Repo Size Optimization**: Stripped massive `@playButton` metadata from `.arb` translation files and untracked binary dependencies, cutting over 100MB of repository bloat.
- **Video Controls Deconstruction**: Modularized the massive `custom_video_controls.dart` "God Widget" by extracting `AspectRatioPanel` and isolating complex view states for better maintainability.
- **Storage Safety**: Hardened `StorageService` initialization assertions to gracefully prevent production crashes on premature read/write access.
- **UI Modernization (Material 3)**: Fully upgraded the app theme to Material 3 Expressive, introducing component-level themes for Cards, Buttons, Dialogs, Sliders, Bottom Sheets, Snackbars, and Chips.
- **Settings Screen Redesign**: Modernized the settings screen layout, introduced M3 styled section headers, replaced the old dropdown with visual color swatches for the theme picker, and cleanly separated the Logout action.

### Fixed
- **UI Jank on Message Load**: Offloaded CPU-heavy message parsing in `home_controller.dart` to a background `Isolate`, eliminating main-thread stuttering when loading channels.
- **Stream Disconnections**: Modified `StreamingProxyService`'s auth token to be `static final`, preventing active video streams from breaking during Riverpod provider rebuilds.
- **Episode Count Badge Alignment**: Standardized the orange episode count badge by aligning it to the top-right on all library cards (both grid and compact views).
- **Library Grid Layout Enhancements**: 
  - Increased grid padding to 16px to prevent corner cut-offs on edge cards.
  - Increased border opacity on library cards for better visibility on dark backgrounds.
  - Removed overlapping heavy shadows on untapped cards that previously caused dark spots in grid gaps.
