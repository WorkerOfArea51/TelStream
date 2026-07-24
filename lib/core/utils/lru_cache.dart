import 'dart:collection';

class LruCache<K, V> {
  final int maxSize;
  final Duration? ttl;
  final LinkedHashMap<K, _CacheEntry<V>> _cache = LinkedHashMap<K, _CacheEntry<V>>();

  LruCache({this.maxSize = 100, this.ttl});

  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (ttl != null && DateTime.now().difference(entry.timestamp) > ttl!) {
      _cache.remove(key);
      return null;
    }

    // Refresh LRU position by re-inserting
    _cache.remove(key);
    _cache[key] = entry;
    return entry.value;
  }

  void set(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    }
    _cache[key] = _CacheEntry(value);

    if (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }
  
  bool containsKey(K key) {
    return get(key) != null;
  }

  void clear() {
    _cache.clear();
  }
}

class _CacheEntry<V> {
  final V value;
  final DateTime timestamp;

  _CacheEntry(this.value) : timestamp = DateTime.now();
}
