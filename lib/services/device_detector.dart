import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Centralized device capability detection.
///
/// Used to make runtime decisions about hardware decoder selection, GPU
/// backend compatibility, and other SoC-specific quirks.
///
/// ── Why this exists ─────────────────────────────────────────────────────────
/// The MediaTek Dimensity 6080 (and many other MediaTek SoCs with Mali-G57
/// and earlier GPUs) have known issues with the media_kit rendering pipeline:
///
///   1. `c2.mtk.*.decoder` drops every frame in zero-copy mode (`hwdec=
///      mediacodec`) when mpv's audio clock drifts ahead of the video clock
///      during the first-frame warmup. MediaTek's decoder has ZERO tolerance
///      for late render timestamps, unlike Qualcomm's ~100ms tolerance.
///
///   2. `hwdec=mediacodec-copy` with `enableHardwareAcceleration=true` in
///      VideoControllerConfiguration creates an EGL SurfaceTexture for the
///      Video widget, but mpv's GPU VO renders to its own GL framebuffer —
///      the frames never reach the Video widget's SurfaceTexture → black
///      screen. The fix is `enableHardwareAcceleration=false` so the Video
///      widget uses the CPU pixel buffer path instead.
///
///   3. The GL→Vulkan texture interop (used by Flutter Impeller) is broken
///      on Mali-G57 MC2 drivers, so any SurfaceTexture-backed rendering
///      produces black under Impeller. Disabling Impeller in AndroidManifest.xml
///      forces Skia which handles SurfaceTextures correctly.
///
/// With both fixes (Impeller disabled + enableHardwareAcceleration=false for
/// mediacodec-copy), the reliable decoder path on these devices is:
///   hwdec=mediacodec-copy (hardware decode + tone-mapping) with CPU buffer
///   output to the Video widget.
///
/// This class detects MediaTek SoCs at runtime for diagnostics logging.
/// The decoder selection logic in video_player_screen.dart now uses
/// enableHardwareAcceleration=false for all non-zero-copy modes, so
/// MediaTek-specific software decoding is no longer forced.
class DeviceDetector {
  DeviceDetector._();

  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  /// Cached Android info — fetching it on every player init is expensive
  /// (involves a platform channel round-trip). Cache it after the first call.
  static AndroidDeviceInfo? _cachedAndroidInfo;

  /// True if the device's SoC vendor is MediaTek.
  ///
  /// Detection logic (in order of reliability):
  ///   1. `androidInfo.brand` contains "mediatek" (rare, but explicit).
  ///   2. `androidInfo.board` contains "mt" (e.g., "mt6877" for Dimensity 6080).
  ///   3. `androidInfo.hardware` contains "mt" (e.g., "mt6877").
  ///   4. `androidInfo.display` or `androidInfo.host` contains "mtk".
  ///   5. `androidInfo.manufacturer` is "MediaTek" (very rare).
  ///
  /// We use multiple checks because OEMs (Xiaomi, Realme, Oppo) often
  /// customize the build properties and may not expose the SoC vendor in
  /// a single canonical field.
  static Future<bool> get isMediaTekSoC async {
    if (!Platform.isAndroid) return false;
    final info = await _getAndroidInfo();
    if (info == null) return false;

    final brand = info.brand.toLowerCase();
    final board = info.board.toLowerCase();
    final hardware = info.hardware.toLowerCase();
    final manufacturer = info.manufacturer.toLowerCase();
    final display = info.display.toLowerCase();
    final host = info.host.toLowerCase();
    final model = info.model.toLowerCase();
    final device = info.device.toLowerCase();

    // Check 1: Explicit brand marking.
    if (brand.contains('mediatek') || manufacturer.contains('mediatek')) {
      return true;
    }
    // Check 2: Board name starts with "mt" (MediaTek's SoC prefix).
    // Examples: mt6877 (Dimensity 6080), mt6893 (Dimensity 1200),
    // mt6769 (Helio G80), mt6768 (Helio P65).
    if (board.startsWith('mt') && board.length >= 4) {
      return true;
    }
    // Check 3: Hardware field starts with "mt".
    if (hardware.startsWith('mt') && hardware.length >= 4) {
      return true;
    }
    // Check 4: Display or host contains "mtk" (MediaTek's abbreviation).
    if (display.contains('mtk') || host.contains('mtk')) {
      return true;
    }
    // Check 5: Model name contains a MediaTek Dimensity/Helio identifier.
    // Some OEMs put the SoC name in the model field.
    if (model.contains('dimensity') || device.contains('dimensity')) {
      return true;
    }
    if (model.contains('helio') || device.contains('helio')) {
      return true;
    }
    return false;
  }

  /// True if the device's SoC vendor is Qualcomm (Snapdragon).
  ///
  /// Used for logging and diagnostics — not currently used for any
  /// decoder selection logic, but available for future use.
  static Future<bool> get isQualcommSoC async {
    if (!Platform.isAndroid) return false;
    final info = await _getAndroidInfo();
    if (info == null) return false;

    final board = info.board.toLowerCase();
    final hardware = info.hardware.toLowerCase();
    final brand = info.brand.toLowerCase();

    if (board.contains('snapdragon') || board.contains('msm') ||
        board.contains('sdm') || board.contains('sm8')) {
      return true;
    }
    if (hardware.contains('qcom') || hardware.startsWith('msm') ||
        hardware.startsWith('sdm') || hardware.startsWith('sm')) {
      return true;
    }
    if (brand.contains('qualcomm')) {
      return true;
    }
    return false;
  }

  /// Returns a human-readable SoC identifier for diagnostics logging.
  ///
  /// Example output: "MediaTek MT6877 (Dimensity 6080)" or
  /// "Qualcomm SM6450 (Snapdragon 7s Gen 3)" or "Unknown".
  static Future<String> get socDescription async {
    if (!Platform.isAndroid) return 'Non-Android';
    final info = await _getAndroidInfo();
    if (info == null) return 'Unknown';

    final board = info.board;
    final brand = info.brand;
    final model = info.model;

    if (await isMediaTekSoC) {
      return 'MediaTek $board ($model)';
    }
    if (await isQualcommSoC) {
      return 'Qualcomm $board ($model)';
    }
    return 'Unknown $brand $board ($model)';
  }

  static Future<AndroidDeviceInfo?> _getAndroidInfo() async {
    if (_cachedAndroidInfo != null) return _cachedAndroidInfo;
    try {
      _cachedAndroidInfo = await _plugin.androidInfo;
    } catch (_) {
      return null;
    }
    return _cachedAndroidInfo;
  }
}