class TdJsonUtil {
  /// Pure function that sanitizes TDLib JSON.
  /// It creates a NEW map instead of mutating the input map,
  /// preventing ConcurrentModificationException and side effects.
  static Map<String, dynamic> sanitize(Map<String, dynamic> input) {
    final out = <String, dynamic>{};

    for (final entry in input.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        out[key] = sanitize(value);
      } else if (value is List) {
        out[key] = value.map((item) {
          if (item is Map<String, dynamic>) return sanitize(item);
          return item;
        }).toList();
      } else {
        out[key] = value;
      }
    }

    // Type-specific sanitization on the new map
    final type = out['@type'];
    if (type == 'messageVideo') {
      out['has_stickers'] = out['has_stickers'] ?? false;
    } else if (type == 'messageDocument') {
      final doc = out['document'];
      if (doc is Map<String, dynamic>) {
        final docType = doc['@type'];
        if (docType == 'document') {
          doc['thumbnail'] = doc['thumbnail'] ?? null;
        }
      }
    } else if (type == 'file') {
      out['expected_size'] = out['expected_size'] ?? 0;
      final local = out['local'];
      if (local is Map<String, dynamic>) {
        local['download_offset'] = local['download_offset'] ?? 0;
        local['downloaded_size'] = local['downloaded_size'] ?? 0;
      }
    }

    return out;
  }
}
