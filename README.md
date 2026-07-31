# TelStream v2.13.6+58 — Fixed Code for Copy-Paste

This folder contains **complete, ready-to-copy-paste fixed code files** for the three issues reported in v2.13.5+57:

1. **Quality fetching still broken** for files without filename quality labels
2. **Desktop video freeze after 2 seconds** of playback (first attempt)
3. **Android black screen with audio** when playing video

Plus version bump and changelog updates.

---

## 📋 Files to Copy-Paste

Replace these files in the repo with the versions from this folder:

| # | Source (in this folder) | Target (in repo) |
|---|------------------------|------------------|
| 1 | `lib/services/streaming_proxy_service.dart` | `lib/services/streaming_proxy_service.dart` |
| 2 | `lib/services/network/tdlib_range_fetch.dart` | `lib/services/network/tdlib_range_fetch.dart` |
| 3 | `lib/features/player/video_player_screen.dart` | `lib/features/player/video_player_screen.dart` |
| 4 | `lib/core/constants.dart` | `lib/core/constants.dart` |
| 5 | `pubspec.yaml` | `pubspec.yaml` |
| 6 | `CHANGELOG.md` | `CHANGELOG.md` |

**Just overwrite the existing files with these versions and push.** No other files need to be changed.

---

## 🔍 What Was Fixed and Why

### Fix 1: Quality Fetching for Files Without Filename Labels

**Symptom**: Quality badges stay stuck as "..." for files whose filenames don't contain a quality token like `1080p`, `720p`, etc. The badge never resolves to a real label.

**Root cause**: When metadata extraction runs (on the episode list screen, before playback), it calls `TdlibRangeFetch.fetchPrefix()` which goes through the streaming proxy. The proxy's auto-shift logic had a bug:

```dart
// v17 BUG: This condition is false when no download is active
final isOutBefore = start < activeOffset;       // 0 < 0 = false
final isOutAfter = start > activeRangeEnd + 3MB; // 0 > 0 + 3MB = false
if (!isCompleted && start >= prefixSize &&
    (isOutBefore || (isOutAfter && ...))) {
  // NEVER ENTERED — no download is triggered
}
```

When no download was active (`activeOffset=0`, `baseDownloaded=0`, `prefixSize=0`), both conditions were false, so the proxy never triggered a TDLib download. It just waited for bytes that would never arrive (until the 20-second timeout kicked in).

**Fix** (`streaming_proxy_service.dart`): Rewrote the auto-shift decision logic. Added a `noActiveDownload` check that triggers a TDLib download at the requested offset immediately when no download is active:

```dart
final noActiveDownload = activeOffset == 0 && baseDownloaded == 0 && prefixSize == 0;
final shouldShift = !isCompleted && !isWithinPrefix && !isWithinActiveRange &&
    (noActiveDownload || start < activeOffset ||
     (start > activeRangeEnd + forwardThreshold && (!hasEarlierRequest || isTailQuery)));
```

**Additional fix** (`tdlib_range_fetch.dart`): `fetchPrefix` now reads directly from disk when `downloadedPrefixSize >= bytes` (not just when the file is fully downloaded). This skips the HTTP roundtrip entirely when TDLib has already cached the first 2 MB — common after the user has played or scrubbed the video once.

---

### Fix 2: Desktop Video Freeze After 2 Seconds

**Symptom**: On desktop (Windows/Linux/macOS), video plays for 2-3 seconds on first attempt, then freezes. User must seek back to 0 to resume playback.

**Root cause**: Two issues combined:

1. `_initDownload()` sent `td.DownloadFile(synchronous: false)` and immediately called `_startPlayback(proxyUrl)`. MPV connected to the proxy, but TDLib had barely started downloading — the proxy had no bytes to serve.

2. v17 set `cache-pause-wait=1` on desktop. This tells MPV to wait only 1 second for the demuxer cache to fill before giving up. With a near-empty buffer, MPV starts playing, plays the first 2 seconds from whatever bytes arrived, then freezes when the buffer drains.

**Fix** (`video_player_screen.dart`): Two changes:

1. **Pre-buffer before `player.open()`**: Added `_waitForPrefixDownload()` helper that polls `td.GetFile` every 150 ms until `downloadedPrefixSize >= 2 MB` or 5 seconds elapse. Called before `_startPlayback(proxyUrl)` on both the active-download and pre-emptive-fallback paths.

2. **`cache-pause-wait` increased from 1s to 3s on desktop**: Gives MPV enough time to fill its demuxer cache before starting playback.

---

### Fix 3: Android Black Screen With Audio

**Symptom**: On Android, video plays audio but the video display area is completely black. Player shows it's playing (waveform visible, time advancing), but no video frames are rendered.

**Root cause**: v17 mapped all `auto*` and `mediacodec*` modes to `hwdec=auto-safe`:

```dart
// v17 BUG
if (safeMode == 'mediacodec' || safeMode == 'mediacodec-copy' ||
    safeMode == 'auto' || safeMode == 'auto-copy') {
  safeMode = 'auto-safe';  // ← This is the problem
}
```

On most Android devices, `auto-safe` resolves to `mediacodec-copy`, which decodes video frames to CPU RAM instead of directly to the SurfaceTexture. Combined with `enableHardwareAcceleration=true` (set in `VideoController`), which configures `vo=gpu` for SurfaceTexture rendering, this creates a mismatch:

- **Audio path**: works (decoded from RAM)
- **Video path**: `vo=gpu` waits for SurfaceTexture frames that never arrive → black screen

**Fix** (`video_player_screen.dart`): Use `hwdec=mediacodec` (NOT `mediacodec-copy`, NOT `auto-safe`) by default on Android:

```dart
// v2.13.6 FIX
if (hwDecMode == 'no') {
  nativePlayer.setProperty('hwdec', 'no');
} else if (hwDecMode == 'mediacodec-copy') {
  // Respect explicit user choice (subtitle compatibility mode)
  nativePlayer.setProperty('hwdec', 'mediacodec-copy');
} else {
  // 'auto', 'auto-safe', 'auto-copy', 'mediacodec' → all map to 'mediacodec'
  nativePlayer.setProperty('hwdec', 'mediacodec');
}
```

`mediacodec` (without `-copy`) makes MediaCodec output directly to the SurfaceTexture, which `vo=gpu` then renders. If a specific codec fails on a device, MPV automatically falls back to software decoding.

The only exception is when the user **explicitly** chose `mediacodec-copy` (e.g., for Native Blending subtitle compatibility) — in that case we respect their choice, but note that it may show a black screen with `vo=gpu`. This trade-off is documented in the diagnostics screen.

---

## ✅ Verification Steps After Pushing

After Gemini pushes these changes, the user should verify:

1. **Android video playback**: Open any video on Android — video should now render (not just audio). The black screen issue should be gone.

2. **Desktop first-playback freeze**: Open any video on desktop — it should play smoothly from the start without freezing after 2 seconds. There may be a brief 1-3 second delay before playback starts (this is the pre-buffering).

3. **Quality badges for files without filename labels**: Navigate to an episode list containing files without `1080p`/`720p`/etc. in their filenames. The quality badges should resolve from "..." to a real label (e.g., `1080p`, `720p`) within a few seconds, not stay stuck forever.

4. **In-app changelog**: Open Settings → About → Changelog. Should show "What's New in v2.13.6" with the three fixes listed.

5. **App version**: Should show `2.13.6+58` in Settings → About.

---

## 📝 Version & Changelog Updates

- `pubspec.yaml`: `version: 2.13.5+57` → `version: 2.13.6+58`
- `CHANGELOG.md`: Prepended `[2.13.6] - 2026-07-31` entry with full details
- `lib/core/constants.dart`: Updated `changelog` constant to show v2.13.6 (also fixes the broken UTF-8 emoji encoding `ðŸš€` → `🚀` that was in the old v2.12.2 entry)

---

## ⚠️ Notes for Gemini

- **Do NOT run `flutter pub run build_runner build`** — these changes don't touch any `@freezed` or `@jsonSerializable` annotated classes, so no code generation is needed.
- **Do NOT modify any other files** — only the 6 files listed above need to be changed.
- **The `video_player_screen.dart` file is large (1919 lines)** — just overwrite it completely with the version in this folder. Don't try to apply patches manually.
- **All braces/parens/brackets are balanced** — verified with a Python script.
- **No new imports were added** — all imports in the fixed files already exist in v17.
