### 🚀 What's New in v2.10.2+43

This release is a massive stability and security update, fixing over 200 issues identified in a comprehensive source code audit! 🛡️

#### 🔒 Security & Data Integrity
* **RCE Prevention**: Implemented strict SHA-256 hash verification before executing any downloaded `.exe` or `.apk` app updates.
* **Database Encryption**: Secured the local TDLib database with a generated 32-byte secure key using `flutter_secure_storage`.
* **Corrupted Schema Protection**: Added strict JSON type checking when parsing storage configurations to prevent the app from crashing on boot if data is corrupted.
* **Atomic File Saving**: Downloads now write to a `.part` extension and rename on completion to prevent corrupted half-downloads.

#### ⚡ Concurrency & Sync Fixes
* **Concurrent Downloads Limiter**: The Download Manager now strictly limits concurrent active downloads to a maximum of 3, drastically reducing CPU spikes and network congestion.
* **History Deduplication**: The Cloud Sync Service now correctly deduplicates standalone movies in the "Continue Watching" log by unique Telegram message IDs.
* **GraphQL Error Parsing**: The AniList Tracker integration now correctly detects and processes API errors instead of blindly trusting HTTP 200 OK responses.

#### 📱 Platform Fixes
* **Android Background Crashes**: Fixed a foreground service `stopSelf()` race condition and safely handled null-intent deliveries to prevent crashes on Android 8+.
* **iOS Audio Freezes**: Added `UIBackgroundModes: audio` to prevent background streaming from pausing unexpectedly.
* **macOS Networking**: Added the required `com.apple.security.network.client` entitlement for production macOS builds.
* **Wakelock Plus**: Added `wakelock_plus` to stop your screen from falling asleep during long movies.

#### 🎨 Performance Improvements
* **Search Debouncing**: Added a 300ms `Timer` debounce to the Library and Global search bars, eliminating UI stuttering while typing.
* **Storage Writes Throttling**: Reduced the Video Player's auto-save frequency from 10s to 30s and suspended writes while paused to reduce battery and disk usage.
* **Startup Stability**: The root `runApp` has been safely moved outside the `try` block to guarantee a visible error screen on fatal init failure.

---

### 🛠️ Build Information
- **Version:** `v2.10.2+43`
- **Build Number:** `43`
- **Branch:** `main`
- **Commit SHA:** `pending`

### 📲 Downloads
- **ARM64 APK:** Optimized for modern 64-bit ARM devices (arm64-v8a).
- **ARM32 APK:** Optimized for older 32-bit ARM devices (armeabi-v7a).
