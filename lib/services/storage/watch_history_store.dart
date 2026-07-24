import 'json_file_persistence.dart';

class WatchHistoryStore {
  final JsonFilePersistence _persistence;

  WatchHistoryStore(this._persistence);

  bool get _isIncognitoMode => _persistence.data['incognito'] == true;

  Future<void> saveWatchPosition(int messageId, int positionInSeconds) async {
    if (_isIncognitoMode) return;
    
    final history = _persistence.data['history'];
    if (history is Map) {
      history[messageId.toString()] = positionInSeconds;
      await _persistence.save();
    }
  }

  int getWatchPosition(int messageId) {
    if (_isIncognitoMode) return 0;
    
    final history = _persistence.data['history'];
    if (history is Map) {
      return history[messageId.toString()] as int? ?? 0;
    }
    return 0;
  }

  Future<void> setLastWatched(String seriesName, int messageId, int episodeIndex) async {
    if (_isIncognitoMode) return;
    
    _persistence.data['last_watched'] = {
      'seriesName': seriesName,
      'messageId': messageId,
      'episodeIndex': episodeIndex,
    };
    await _persistence.save();
  }

  Map<String, dynamic>? getLastWatched() {
    final lw = _persistence.data['last_watched'];
    if (lw is Map) {
      return Map<String, dynamic>.from(lw);
    }
    return null;
  }

  Future<void> addToHistoryLog({
    required String seriesName,
    required int messageId,
    required int episodeIndex,
    required String episodeTitle,
    required int positionInSeconds,
    required int videoFileId,
  }) async {
    if (_isIncognitoMode) return;

    final logsData = _persistence.data['history_log'];
    final List<dynamic> logs = logsData is List ? List.from(logsData) : [];
    
    // Remove if exists
    logs.removeWhere((item) => item is Map && item['messageId'] == messageId);
    
    // Add to top
    logs.insert(0, {
      'seriesName': seriesName,
      'messageId': messageId,
      'episodeIndex': episodeIndex,
      'episodeTitle': episodeTitle,
      'positionInSeconds': positionInSeconds,
      'videoFileId': videoFileId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (logs.length > 200) {
      logs.removeRange(200, logs.length);
    }
    
    _persistence.data['history_log'] = logs;
    await _persistence.save();
  }

  List<Map<String, dynamic>> getHistoryLog() {
    final logs = _persistence.data['history_log'];
    if (logs is! List) return [];
    return logs.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> removeFromHistoryLog(int messageId) async {
    final logsData = _persistence.data['history_log'];
    if (logsData is! List) return;
    final List<dynamic> logs = List.from(logsData);
    logs.removeWhere((item) => item is Map && item['messageId'] == messageId);
    _persistence.data['history_log'] = logs;
    await _persistence.save();
  }

  Future<void> clearHistoryLog() async {
    _persistence.data['history_log'] = [];
    _persistence.data['history'] = <String, int>{};
    _persistence.data['last_watched'] = null;
    await _persistence.save();
  }

  Future<void> saveVideoDuration(int messageId, int durationInSeconds) async {
    if (_isIncognitoMode) return;
    
    final durations = _persistence.data['durations'];
    if (durations is Map) {
      durations[messageId.toString()] = durationInSeconds;
    } else {
      _persistence.data['durations'] = {messageId.toString(): durationInSeconds};
    }
    await _persistence.save();
  }

  int getVideoDuration(int messageId) {
    final durations = _persistence.data['durations'];
    if (durations is Map) {
      return durations[messageId.toString()] as int? ?? 0;
    }
    return 0;
  }
}
