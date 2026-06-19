### 🚀 What's New in v2.6.2

This update brings UI enhancements, improved video player controls, and optimized high-speed video synchronization.

#### ⚡ Playback Sync & Controls
* **Perfect 2x Speed Sync**: Configured the master audio clock and aggressive decoder/rendering framedrops to ensure audio, video, and subtitles remain perfectly synchronized.
* **On-the-fly Buffer Flushing**: Automatically performs seek resyncs on speed adjustments to rebuild player buffers instantly.
* **HW/SW Decoder Switcher**: Switch hardware acceleration modes (`HW`, `HW+`, `SW`) on-the-fly directly from the player's control bar.
* **Subtitle Renderer Settings**: Switch between Flutter and Native subtitle renderers right inside the player's subtitle customizer.

#### 🎨 Cleaner Episode List UI
* **Aligned Episode Cards**: Episode list cards now have their content vertically centered for a clean look.
* **Removed Descriptions**: Removed the generic "No description available" text from local episodes.
* **Zero-Lag Folder Loading**: Removed dynamic theme color extraction from the poster image to ensure instant navigation.

---

### 🛠️ Build Information
- **Version:** `v2.0.0`
- **Build Number:** `#0`
- **Branch:** `main`
- **Commit SHA:** `unknown`

### 📲 Downloads
- **ARM64 APK:** Optimized for modern 64-bit ARM devices (arm64-v8a).
- **ARM32 APK:** Optimized for older 32-bit ARM devices (armeabi-v7a).
