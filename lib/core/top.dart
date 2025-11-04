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

  /// Resolve current cache instance and parse key.
  ///
  /// Returns tuple of (cache, parsedKey).
  /// If key contains 'env:key' format, uses specified env and returns the key part.
  /// If key is null, returns (cache, null) - useful for operations like clear.
  /// Otherwise uses currentEnv or most recent cache.
  static (PVCache, String?) _resolveEnv(String? key) {
    String? targetEnv = currentEnv;
    String? parsedKey = key;

    // Check if key contains env:key format
    if (key != null && key.contains(':')) {
      final parts = key.split(':');
      if (parts.length >= 2 && PVCache.instances.containsKey(parts[0])) {
        targetEnv = parts[0];
        parsedKey = parts
            .sublist(1)
            .join(':'); // Handle keys with multiple colons
      }
    }

    // If no env specified, use most recent
    if (targetEnv == null) {
      if (PVCache.instances.isEmpty) {
        throw Exception(
          'No PVCache instances available to resolve environment.',
        );
      }
      targetEnv = PVCache.instances.keys.last;
    }

    final cache = PVCache.instances[targetEnv];
    if (cache == null) {
      throw Exception('No PVCache instance found for environment: $targetEnv');
    }

    return (cache, parsedKey);
  }

  /// Store key-value pair in cache.
  static Future<void> put(
    String key,
    dynamic value, {
    Map<String, dynamic>? metadata,
  }) async {
    final (cache, parsedKey) = _resolveEnv(key);
    await cache.put(parsedKey!, value, metadata: metadata);
  }

  /// Retrieve value from cache. Returns null if not found.
  static Future<dynamic> get(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    final (cache, parsedKey) = _resolveEnv(key);
    return await cache.get(parsedKey!, metadata: metadata);
  }

  /// Delete key-value pair from cache.
  static Future<void> delete(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    final (cache, parsedKey) = _resolveEnv(key);
    await cache.delete(parsedKey!, metadata: metadata);
  }

  /// Clear all cache entries.
  static Future<void> clear({Map<String, dynamic>? metadata}) async {
    final (cache, _) = _resolveEnv(null);
    await cache.clear(metadata: metadata);
  }

  /// Check if key exists in cache (respects TTL).
  static Future<bool> exists(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    final (cache, parsedKey) = _resolveEnv(key);
    return await cache.exists(parsedKey!, metadata: metadata);
  }
}
