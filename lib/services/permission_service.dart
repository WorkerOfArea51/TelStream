import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class PermissionService {
  static const _channel = MethodChannel('com.darkmatter.telstream/updater');

  /// Resolves the current Android SDK version dynamically using native APIs.
  Future<int> getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;
    try {
      final int? sdk = await _channel.invokeMethod<int>('getAndroidSdkVersion');
      if (sdk != null) return sdk;
    } catch (_) {}
    
    // Fallback: Parse string if native channel method fails
    try {
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'(?:API|SDK)\s*(\d+)').firstMatch(versionStr);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// Silently checks and requests all required runtime permissions on app launch/login.
  /// - SDK 33 and above: Request Notification permission.
  Future<void> requestAllImportantPermissions() async {
    if (!Platform.isAndroid) return;

    final sdk = await getAndroidSdkVersion();

    // Notification Permission (required on Android 13+ / SDK 33+)
    if (sdk >= 33) {
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted && !notificationStatus.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    }
  }

  /// Explicitly requests storage permission (relevant for Android < 10).
  /// Returns true if granted, or if permissions are not required (Android 10+ / iOS).
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    
    final sdk = await getAndroidSdkVersion();
    if (sdk >= 29) {
      // Android 10+ uses Storage Access Framework (SAF) folder picker which doesn't require legacy permission
      return true;
    }

    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Explicitly requests notification permission (relevant for Android 13+).
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Checks or requests permission to install packages (relevant for Updater flow).
  Future<bool> requestInstallPackagesPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }
}
