import 'package:pvcache/core/cache.dart';

/// Global access for PVCache without explicit instance reference.
///
/// Provides singleton-like interface using the most recently created cache.
///
/// Usage:
/// ```dart
/// final cache = PVCache(env: 'myCache', hooks: [], defaultMetadata: {});
/// await PVCacheTop.put('key', 'value');
/// final value = await PVCacheTop.get('key');
/// ```
class PVCacheTop {
  /// Current environment name. If null, uses most recent cache.
  static String? currentEnv;

  /// Resolve current cache instance.
  static PVCache _resolveEnv() {
    if (currentEnv == null) {
      // get the last instance
      if (PVCache.instances.isEmpty) {
        throw Exception(
          'No PVCache instances available to resolve environment.',
        );
      }
      currentEnv = PVCache.instances.keys.last;
    }
    final cache = PVCache.instances[currentEnv!];
    if (cache == null) {
      throw Exception('No PVCache instance found for environment: $currentEnv');
    }
    return cache;
  }

  /// Store key-value pair in cache.
  static Future<void> put(
    String key,
    dynamic value, {
    Map<String, dynamic>? metadata,
  }) async {
    final cache = _resolveEnv();
    await cache.put(key, value, metadata: metadata);
  }

  /// Retrieve value from cache. Returns null if not found.
  static Future<dynamic> get(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    final cache = _resolveEnv();
    return await cache.get(key, metadata: metadata);
  }

  /// Delete key-value pair from cache.
  static Future<void> delete(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    final cache = _resolveEnv();
    await cache.delete(key, metadata: metadata);
  }

  /// Clear all cache entries.
  static Future<void> clear({Map<String, dynamic>? metadata}) async {
    final cache = _resolveEnv();
    await cache.clear(metadata: metadata);
  }

  /// Check if key exists in cache (respects TTL).
  static Future<bool> exists(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    final cache = _resolveEnv();
    return await cache.exists(key, metadata: metadata);
  }
}
