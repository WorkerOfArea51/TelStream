import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Returns the directory for app-private data (not user-visible).
/// - Android: app-internal storage (returned by getApplicationSupportDirectory)
/// - iOS/macOS: ~/Library/Application Support/<bundle-id>
/// - Windows: %APPDATA%/<vendor>/<app>
/// - Linux: ${XDG_DATA_HOME}/<app> or ~/.local/share/<app>
Future<Directory> getAppDirectory() async {
  return await getApplicationSupportDirectory();
}
