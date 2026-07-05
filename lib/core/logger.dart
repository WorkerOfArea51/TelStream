import 'dart:io';
import 'package:flutter/foundation.dart';

class Log {
  static File? _logFile;
  static IOSink? _sink;

  static void init(String appDir) {
    try {
      _logFile = File('$appDir/app.log');
      if (_logFile!.existsSync()) {
        if (_logFile!.lengthSync() > 5 * 1024 * 1024) {
          _logFile!.writeAsStringSync('');
        }
      }
      _sink = _logFile!.openWrite(mode: FileMode.writeOnlyAppend);
    } catch (_) {}
  }

  static void _writeToFile(String prefix, String message) {
    if (_sink != null) {
      try {
        final now = DateTime.now().toIso8601String();
        _sink!.write('[$now][$prefix] $message\n');
      } catch (_) {}
    }
  }

  static void d(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
    _writeToFile('DEBUG', message);
  }

  static void i(String message) {
    debugPrint('[INFO] $message');
    _writeToFile('INFO', message);
  }

  static void w(String message) {
    debugPrint('[WARNING] $message');
    _writeToFile('WARNING', message);
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message');
    _writeToFile('ERROR', message);
    if (error != null) {
      debugPrint('Details: $error');
      _writeToFile('ERROR_DETAIL', error.toString());
    }
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
      _writeToFile('STACK_TRACE', stackTrace.toString());
    }
  }
}
