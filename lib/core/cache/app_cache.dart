import 'dart:async';

/// A very small in-memory cache for the current app session.
/// - Web-friendly (no file system; no external deps)
/// - Useful to show cached data instantly while Firestore streams connect
/// - TTL-based invalidation
class AppCacheEntry<T> {
  final T data;
  final DateTime storedAt;
  final Duration ttl;
  AppCacheEntry({required this.data, required this.storedAt, required this.ttl});
  bool get isExpired => DateTime.now().difference(storedAt) > ttl;
}

class AppCache {
  AppCache._internal();
  static final AppCache instance = AppCache._internal();

  final Map<String, AppCacheEntry<dynamic>> _map = {};

  T? get<T>(String key) {
    final entry = _map[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _map.remove(key);
      return null;
    }
    final data = entry.data;
    if (data is T) return data;
    return null;
  }

  void set<T>(String key, T data, {Duration ttl = const Duration(minutes: 5)}) {
    _map[key] = AppCacheEntry<T>(data: data, storedAt: DateTime.now(), ttl: ttl);
  }

  void invalidate(String key) => _map.remove(key);
  void clear() => _map.clear();

  /// Wraps a source stream so it immediately emits any cached value (if present and fresh)
  /// before forwarding live updates. Each live emission updates the cache.
  Stream<T> cacheFirstStream<T>(String key, Stream<T> source, {Duration ttl = const Duration(minutes: 5)}) {
    final cached = get<T>(key);
    final mapped = source.map((value) {
      set<T>(key, value, ttl: ttl);
      return value;
    });
    if (cached != null) {
      // Emit cached once, then follow with live stream
      return Stream<T>.multi((controller) {
        controller.add(cached);
        final sub = mapped.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: false,
        );
        controller.onCancel = () => sub.cancel();
      });
    }
    return mapped;
  }

  /// Returns cached data if available and fresh; otherwise awaits [fetch],
  /// stores it, and returns the fresh value.
  Future<T> getOrFetch<T>(String key, Future<T> Function() fetch, {Duration ttl = const Duration(minutes: 5)}) async {
    final cached = get<T>(key);
    if (cached != null) return cached;
    final fresh = await fetch();
    set<T>(key, fresh, ttl: ttl);
    return fresh;
  }
}
