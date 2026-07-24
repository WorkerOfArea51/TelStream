import 'json_file_persistence.dart';

class DownloadStore {
  final JsonFilePersistence _persistence;

  DownloadStore(this._persistence);

  Map<int, String> getDownloadedFiles() {
    final df = _persistence.data['downloaded_files'];
    if (df is! Map) return {};
    final result = <int, String>{};
    for (final entry in df.entries) {
      final parsedKey = int.tryParse(entry.key.toString());
      if (parsedKey != null && entry.value is String) {
        result[parsedKey] = entry.value as String;
      }
    }
    return result;
  }

  Future<void> addDownloadedFile(int fileId, String filePath) async {
    _persistence.data['downloaded_files'] ??= <String, dynamic>{};
    _persistence.data['downloaded_files'][fileId.toString()] = filePath;
    await _persistence.save();
  }

  Future<void> removeDownloadedFile(int fileId) async {
    if (_persistence.data['downloaded_files'] != null) {
      (_persistence.data['downloaded_files'] as Map).remove(fileId.toString());
      await _persistence.save();
    }
  }

  Map<int, String> getActiveDownloads() {
    final ad = _persistence.data['active_downloads'];
    if (ad is! Map) return {};
    final result = <int, String>{};
    for (final entry in ad.entries) {
      final parsedKey = int.tryParse(entry.key.toString());
      if (parsedKey != null && entry.value is String) {
        result[parsedKey] = entry.value as String;
      }
    }
    return result;
  }

  List<int> getActiveDownloadsOrder() {
    final order = _persistence.data['active_downloads_order'];
    if (order is! List) return [];
    return order.map((e) => int.tryParse(e.toString())).whereType<int>().toList();
  }

  Future<void> setActiveDownloadsOrder(List<int> order) async {
    _persistence.data['active_downloads_order'] = order.map((e) => e.toString()).toList();
    await _persistence.save();
  }

  Future<void> addActiveDownload(int fileId, String title) async {
    _persistence.data['active_downloads'] ??= <String, dynamic>{};
    _persistence.data['active_downloads'][fileId.toString()] = title;
    
    final order = getActiveDownloadsOrder();
    if (!order.contains(fileId)) {
      order.add(fileId);
      _persistence.data['active_downloads_order'] = order.map((e) => e.toString()).toList();
    }
    await _persistence.save();
  }

  Future<void> removeActiveDownload(int fileId) async {
    bool changed = false;
    if (_persistence.data['active_downloads'] != null) {
      final removed = (_persistence.data['active_downloads'] as Map).remove(fileId.toString());
      if (removed != null) changed = true;
    }
    final order = getActiveDownloadsOrder();
    if (order.contains(fileId)) {
      order.remove(fileId);
      _persistence.data['active_downloads_order'] = order.map((e) => e.toString()).toList();
      changed = true;
    }
    
    if (changed) {
      await _persistence.save();
    }
  }

  String? getCustomDownloadDirectory() {
    return _persistence.data['custom_download_directory'] as String?;
  }

  Future<void> setCustomDownloadDirectory(String? path) async {
    if (path == null) {
      _persistence.data.remove('custom_download_directory');
    } else {
      _persistence.data['custom_download_directory'] = path;
    }
    await _persistence.save();
  }
}
