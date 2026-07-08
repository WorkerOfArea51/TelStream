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

  Future<void> init(String appDir) async {
    try {
      _logFile = File('${appDir.replaceAll('\\', '/')}/app.log');
      await _rotateIfNeeded();
      _sink = _logFile!.openWrite(mode: FileMode.writeOnlyAppend);
    } catch (e) {
      stderr.writeln('Logger init failed: $e');
    }
  }

  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  Future<void> _rotateIfNeeded() async {
    if (_logFile == null || !_logFile!.existsSync()) return;
    try {
      final len = await _logFile!.length();
      if (len <= _maxBytes) return;
      final raf = await _logFile!.open(mode: FileMode.read);
      try {
        await raf.setPosition(len - _keepBytes);
        final tail = await raf.read(_keepBytes);
        await _logFile!.writeAsBytes(tail, flush: true, mode: FileMode.write);
      } finally {
        await raf.close();
      }
    } catch (e, st) {
      stderr.writeln('Logger rotate failed: $e\n$st');
    }
  }

  void _writeToFile(String prefix, String message) {
    if (_sink == null) return;
    try {
      final now = DateTime.now().toIso8601String();
      _sink!.writeln('[$now][$prefix] $message');
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

  static Future<void> init(String appDir) async {
    if (_instance is FileLogger) {
      await (_instance as FileLogger).init(appDir);
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

