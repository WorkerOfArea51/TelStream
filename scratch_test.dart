import 'dart:io';

void main() {
  // Let's check Windows application support directory
  // In Dart / Flutter on Windows it's usually:
  // C:\Users\<user>\AppData\Roaming\com.darkmatter\TelStream
  final userProfile = Platform.environment['USERPROFILE'] ?? '';
  final appDir = Directory('$userProfile/AppData/Roaming/com.darkmatter/TelStream');
  if (appDir.existsSync()) {
    print('Root App directory exists: ${appDir.path}');
    _printDirectory(appDir, '');
  } else {
    print('App directory not found at default Windows location.');
  }
}

void _printDirectory(Directory dir, String indent) {
  try {
    for (final entity in dir.listSync()) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        print('$indent[DIR] $name');
        _printDirectory(entity, '$indent  ');
      } else if (entity is File) {
        final name = entity.path.split(Platform.pathSeparator).last;
        final size = entity.lengthSync();
        print('$indent[FILE] $name (${(size / 1024 / 1024).toStringAsFixed(2)} MB)');
      }
    }
  } catch (e) {
    print('$indent Error listing directory: $e');
  }
}
