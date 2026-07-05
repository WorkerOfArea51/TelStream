import 'dart:io';
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

abstract class Logger {
  void d(String message);
  void i(String message);
  void w(String message);
  void e(String message, [dynamic error, StackTrace? stackTrace]);
}

class FileLogger implements Logger {
  File? _logFile;
  IOSink? _sink;
  final LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  static const int _maxBytes = 5 * 1024 * 1024;
  static const int _keepBytes = 1 * 1024 * 1024; // keep last 1MB on rotate

  void init(String appDir) {
    try {
      _logFile = File('${appDir.replaceAll('\\', '/')}/app.log');
      _rotateIfNeeded();
      _sink = _logFile!.openWrite(mode: FileMode.writeOnlyAppend);
    } catch (e, st) {
      stderr.writeln('Logger init failed: $e');
    }
  }

  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  void _rotateIfNeeded() {
    if (_logFile == null || !_logFile!.existsSync()) return;
    try {
      if (_logFile!.lengthSync() <= _maxBytes) return;
      final bytes = _logFile!.readAsBytesSync();
      final tail = bytes.length > _keepBytes
          ? bytes.sublist(bytes.length - _keepBytes)
          : bytes;
      _logFile!.writeAsBytesSync(tail, flush: true);
    } catch (_) {}
  }

  void _writeToFile(String prefix, String message) {
    if (_sink == null) return;
    try {
      final now = DateTime.now().toIso8601String();
      _sink!.writeln('[$now][$prefix] $message');
      if (prefix == 'ERROR' || prefix == 'ERROR_DETAIL' || prefix == 'STACK_TRACE') _sink!.flush();
    } catch (_) {}
  }

  @override
  void d(String message) {
    if (_minLevel.index > LogLevel.debug.index) return;
    if (kDebugMode) debugPrint('[DEBUG] $message');
    _writeToFile('DEBUG', message);
  }

  @override
  void i(String message) {
    if (_minLevel.index > LogLevel.info.index) return;
    debugPrint('[INFO] $message');
    _writeToFile('INFO', message);
  }

  @override
  void w(String message) {
    if (_minLevel.index > LogLevel.warning.index) return;
    debugPrint('[WARNING] $message');
    _writeToFile('WARNING', message);
  }

  @override
  void e(String message, [dynamic error, StackTrace? stackTrace]) {
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

class MockLogger implements Logger {
  @override
  void d(String message) => debugPrint('[MOCK DEBUG] $message');
  @override
  void i(String message) => debugPrint('[MOCK INFO] $message');
  @override
  void w(String message) => debugPrint('[MOCK WARN] $message');
  @override
  void e(String message, [dynamic error, StackTrace? stackTrace]) => debugPrint('[MOCK ERROR] $message $error');
}

class Log {
  static Logger _instance = FileLogger();
  static set instance(Logger logger) => _instance = logger;

  static void init(String appDir) {
    if (_instance is FileLogger) {
      (_instance as FileLogger).init(appDir);
    }
  }

  static Future<void> dispose() async {
    if (_instance is FileLogger) {
      await (_instance as FileLogger).dispose();
    }
  }

  static void d(String message) => _instance.d(message);
  static void i(String message) => _instance.i(message);
  static void w(String message) => _instance.w(message);
  static void e(String message, [dynamic error, StackTrace? stackTrace]) => _instance.e(message, error, stackTrace);
}
