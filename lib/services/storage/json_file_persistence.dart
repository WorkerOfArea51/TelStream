import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:synchronized/synchronized.dart';
import '../../core/logger.dart';
import '../../core/utils/path_helper.dart';

class JsonFilePersistence {
  File? _file;
  final Lock _lock = Lock();
  bool _isInitialized = false;

  Map<String, dynamic> data = {
    'history': <String, int>{},
    'favorites': <String>[],
    'last_watched': null,
  };

  void checkInit() {
    if (!_isInitialized) {
      Log.e('CRITICAL: JsonFilePersistence accessed before init() completed!');
      assert(_isInitialized, 'JsonFilePersistence accessed before init() completed!');
    }
  }

  Future<void> init() async {
    final directory = await getAppDirectory();
    final primaryPath = '${directory.path}/user_storage.json';
    final backupPath = '$primaryPath.bak';
    _file = File(primaryPath);
    final backupFile = File(backupPath);

    if (await _file!.exists()) {
      try {
        final content = await _file!.readAsString();
        final Map<String, dynamic> jsonData = jsonDecode(content);
        data = _mergeData(data, jsonData);
        Log.i('JsonFilePersistence loaded primary data');
      } catch (e) {
        Log.e('Failed to load primary storage JSON', e);
        if (await backupFile.exists()) {
          try {
            final content = await backupFile.readAsString();
            final Map<String, dynamic> jsonData = jsonDecode(content);
            data = _mergeData(data, jsonData);
            Log.i('JsonFilePersistence recovered from backup data');
          } catch (e2) {
            Log.e('Failed to load backup storage JSON', e2);
          }
        }
      }
    } else {
      Log.i('No existing storage file found. Starting fresh.');
    }
    _isInitialized = true;
  }

  Map<String, dynamic> _mergeData(Map<String, dynamic> defaultData, Map<String, dynamic> loadedData) {
    Map<String, dynamic> result = Map.from(defaultData);
    loadedData.forEach((key, value) {
      result[key] = value;
    });
    return result;
  }

  Future<void> save() async {
    checkInit();
    await _executeSave();
  }

  Future<void> flush() async {
    if (_isInitialized) {
      await _executeSave();
    }
  }

  Future<void> _executeSave() async {
    if (_file == null) return;
    await _lock.synchronized(() async {
      try {
        final content = jsonEncode(data);
        final tempFile = File('${_file!.path}.tmp');
        await tempFile.writeAsString(content, flush: true);
        
        final backupFile = File('${_file!.path}.bak');
        if (await _file!.exists()) {
          if (await backupFile.exists()) {
            await backupFile.delete();
          }
          await _file!.rename(backupFile.path);
        }
        
        await tempFile.rename(_file!.path);
      } catch (e) {
        Log.e('Failed to save to JSON storage file', e);
      }
    });
  }
}
