import 'package:flutter/foundation.dart';

class Log {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  static void i(String message) {
    debugPrint('[INFO] $message');
  }

  static void w(String message) {
    debugPrint('[WARNING] $message');
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message');
    if (error != null) {
      debugPrint('Details: $error');
    }
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
