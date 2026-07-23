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
  <img src="https://img.shields.io/badge/platform-Android-34d399?logo=android" alt="Android" />
  <img src="https://img.shields.io/badge/platform-Windows-0078D4?logo=windows" alt="Windows" />
  <img src="https://img.shields.io/badge/platform-Linux-FCC624?logo=linux" alt="Linux" />
  <img src="https://img.shields.io/badge/framework-Flutter-02569B?logo=flutter" alt="Built with Flutter" />
</p>

---

## 🌟 Introduction

**TelStream** is a lightweight, high-performance Flutter-based Telegram client designed specifically to stream Telegram videos seamlessly. Leveraging the official **Telegram Database Library (TDLib)** and the hardware-accelerated **MediaKit** engine, TelStream delivers instantaneous video playback without requiring full video downloads.

Available on **Android**, **Windows**, and **Linux** — stream your Telegram channels on mobile and desktop.

---

## 🚀 Key Features

*   ⚡ **Instant Video Streaming**: Stream media directly using Telegram's MTProto servers via FFI-based TDLib bindings.
*   🎬 **Advanced Video Engine**: High-performance playback engine powered by `media_kit` (MPV integration) offering hardware acceleration, custom scaling, audio track options, and playback speed controls.
*   🔑 **Secure Telegram Authentication**: Direct and secure login flow supporting Phone Number verification, Login Code, and 2-Factor Authentication (2FA) passwords.
*   💾 **Smart Cache Controller**: An in-app storage optimizer that lets you sweep and purge cached media to prevent local storage bloat.
*   ⭐ **Favorites Management**: Save channels, chats, and specific episodes/videos to your favorites list for quick access.
*   ⚙️ **Modern Slate UI**: Responsive dark theme with a clean interface tailored for video browsing and media playback.
*   📡 **Dynamic Metadata Fetching**: Automatically resolves season-specific TMDB metadata (posters, cast, plot, and recommendations) for accurate UI rendering.
*   ⚡ **Persistent Metadata Caching**: Optimized instant loading utilizing local secure caching for season metadata.
*   📚 **Batch Download**: Download entire seasons with one tap!
*   📶 **WiFi-Only Downloads**: Toggle to pause downloads on cellular data.
*   ⏸️ **Pause All / Resume All**: Bulk control all downloads from the Downloads screen.
*   💬 **Auto-Download Subtitles**: One-tap auto-download of the first subtitle match with 16 languages supported.
*   📝 **User-Added Channels**: Add your own Telegram channels/groups via More → My Channels.
*   🖥️ **Desktop Support**: Full native desktop experience on Windows and Linux with custom window management, keyboard shortcuts, and mouse-driven controls.

---

## 📦 How to Install

### Android

Download the latest precompiled, production-ready APKs directly from the **[GitHub Releases Page](https://github.com/WorkerOfArea51/TelStream/releases)**.

We offer optimized **split-ABI** builds to keep application sizes minimal:
*   **`telstream-arm64.apk`**: Recommended for all modern 64-bit Android devices (arm64-v8a).
*   **`telstream-arm32.apk`**: Recommended for older 32-bit Android devices (armeabi-v7a).

### Windows

Download the Windows executable from the **[GitHub Releases Page](https://github.com/WorkerOfArea51/TelStream/releases)**:
*   **`TelStream-windows-x64.zip`**: Extract and run `TelStream.exe`. No installer required — portable application.

### Linux

Download the Linux build from the **[GitHub Releases Page](https://github.com/WorkerOfArea51/TelStream/releases)**:
*   **`TelStream-linux-x64.tar.gz`**: Extract and run the bundled executable.

---

## 🛠️ CI/CD Pipeline

TelStream uses a fully automated **GitHub Actions** pipeline configuration:
*   **Continuous Integration**: Every push to the `main` branch automatically triggers a new workflow run.
*   **Dependency Injection**: Automatically pulls secure API credentials and bundles native shared libraries (`libtdjson.so` for Android, `tdjson.dll` for Windows) for all target architectures.
*   **Optimized Compiles**: Uses Gradle caching and limits Flutter compile targets to maximize pipeline speed.
*   **Auto-Release**: Publishes compiled APKs, Windows executables, and Linux binaries directly to GitHub Releases.

---

## 💻 Developer Setup

If you wish to build or run the project locally, follow these steps:

### 1. Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (matching version in `pubspec.yaml`)
*   Android SDK / Command Line Tools (for Android builds)
*   Visual Studio with C++ Desktop Development tools (for Windows builds)
*   GTK3 development libraries (for Linux builds)

### 2. Native Library Configuration

TDLib requires native binary files to run. The workflow download is automated on GitHub Actions, but for **local development**:

**Android:**
1. Download `jniLibs.tar.gz` from [up9cloud/android-libtdjson Releases](https://github.com/up9cloud/android-libtdjson/releases).
2. Extract the archive into: `android/app/src/main/` so the ABI folders are placed under `android/app/src/main/jniLibs/`.

**Windows:**
1. Download `tdjson.dll` and supporting libraries (OpenSSL, zlib) from [TDLib Releases](https://github.com/tdlib/td/releases) or the project's native library storage.
2. Place all `.dll` files into: `windows/runner/libs/`.

**Linux:**
1. Ensure `libtdjson.so` is available in your system library path or bundled alongside the executable.

### 3. API Secrets
Create a local file `lib/core/secrets.dart` (which is git-ignored) to specify your Telegram API credentials:
```dart
class Secrets {
  static const int apiId = YOUR_TELEGRAM_API_ID;
  static const String apiHash = 'YOUR_TELEGRAM_API_HASH';
}
```
> Get your API credentials from [my.telegram.org](https://my.telegram.org).

### 4. Build and Run
```bash
# Get pub dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run the app on a connected device/emulator
flutter run

# Build for specific platforms
flutter build apk --split-per-abi   # Android
flutter build windows               # Windows
flutter build linux                 # Linux
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an Issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## ⚖️ License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
All TDLib components are subject to the [official TDLib License](https://github.com/tdlib/td/blob/master/LICENSE).
