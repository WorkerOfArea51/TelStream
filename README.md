# 📱 TelStream

<p align="center">
  <strong>Stream Telegram Videos Seamlessly</strong>
</p>

<p align="center">
  <img src="assets/icon.png" alt="TelStream Logo" width="128" height="128" style="border-radius: 20%;" />
</p>

<p align="center">
  <a href="https://github.com/WorkerOfArea51/TelStream/releases">
    <img src="https://img.shields.io/github/v/release/WorkerOfArea51/TelStream?include_prereleases&logo=github&color=3b82f6" alt="Latest Release" />
  </a>
  <a href="https://github.com/WorkerOfArea51/TelStream/actions">
    <img src="https://img.shields.io/github/actions/workflow/status/WorkerOfArea51/TelStream/build-release.yml?branch=main&logo=github-actions&color=10b981" alt="Build Status" />
  </a>
  <img src="https://img.shields.io/badge/platform-Android-34d399?logo=android" alt="Supported Platform: Android" />
  <img src="https://img.shields.io/badge/framework-Flutter-02569B?logo=flutter" alt="Built with Flutter" />
</p>

---

## 🌟 Introduction

**TelStream** is a lightweight, high-performance Flutter-based Telegram client designed specifically to stream Telegram videos seamlessly. Leveraging the official **Telegram Database Library (TDLib)** and the hardware-accelerated **MediaKit** engine, TelStream delivers instantaneous video playback without requiring full video downloads.

---

## 🚀 Key Features

*   ⚡ **Instant Video Streaming**: Stream media directly using Telegram's MTProto servers via FFI-based TDLib bindings.
*   🎬 **Advanced Video Engine**: High-performance playback engine powered by `media_kit` (MPV integration) offering hardware acceleration, custom scaling, audio track options, and playback speed controls.
*   🔑 **Secure Telegram Authentication**: Direct and secure login flow supporting Phone Number verification, Login Code, and 2-Factor Authentication (2FA) passwords.
*   💾 **Smart Cache Controller**: An in-app storage optimizer that lets you sweep and purge cached media to prevent local storage bloat.
*   ⭐ **Favorites Management**: Save channels, chats, and specific episodes/videos to your favorites list for quick access.
*   ⚙️ **Modern Slate UI**: Responsive dark theme with a clean interface tailored for video browsing and media playback.

---

## 📦 How to Install

You can download the latest precompiled, production-ready APKs directly from the **[GitHub Releases Page](https://github.com/WorkerOfArea51/TelStream/releases)**.

We offer optimized **split-ABI** builds to keep application sizes minimal:
*   **`telstream-arm64.apk`**: Recommended for all modern 64-bit Android devices (arm64-v8a).
*   **`telstream-arm32.apk`**: Recommended for older 32-bit Android devices (armeabi-v7a).

---

## 🛠️ CI/CD Pipeline

TelStream uses a fully automated **GitHub Actions** pipeline configuration:
*   **Continuous Integration**: Every push to the `main` branch automatically triggers a new workflow run.
*   **Dependency Injection**: Automatically pulls secure API credentials and bundles the native `libtdjson.so` shared libraries for all target architectures.
*   **Optimized Compiles**: Uses Gradle caching and limits Flutter compile targets exclusively to `android-arm` and `android-arm64` configurations to maximize pipeline speed.
*   **Auto-Release**: Publishes compiled split-ABI APKs directly to GitHub Releases.

---

## 💻 Developer Setup

If you wish to build or run the project locally, follow these steps:

### 1. Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (matching version in `pubspec.yaml`)
*   Android SDK / Command Line Tools

### 2. Native Library Configuration
TDLib requires native binary files to run. The workflow download is automated on GitHub Actions, but for **local development**:
1. Download `jniLibs.tar.gz` from [up9cloud/android-libtdjson Releases](https://github.com/up9cloud/android-libtdjson/releases).
2. Extract the archive into: `android/app/src/main/` so the ABI folders are placed under `android/app/src/main/jniLibs/`.

### 3. API Secrets
Create a local file `lib/core/secrets.dart` (which is git-ignored) to specify your Telegram API credentials:
```dart
class Secrets {
  static const int apiId = YOUR_TELEGRAM_API_ID;
  static const String apiHash = 'YOUR_TELEGRAM_API_HASH';
}
```

### 4. Build and Run
```bash
# Get pub dependencies
flutter pub get

# Run the app on a connected device
flutter run
```

---

## ⚖️ License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
All TDLib components are subject to the [official TDLib License](https://github.com/tdlib/td/blob/master/LICENSE).
