# Changelog

All notable changes to this project will be documented in this file.

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
