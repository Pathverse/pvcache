import 'package:pvcache/core/cache.dart';

/// Global access point for PVCache operations without explicit instance reference.
///
/// [PVCacheTop] provides a convenient singleton-like interface for cache operations
/// when you don't want to pass around cache instances. It automatically resolves
/// to the most recently created cache instance.
///
/// Usage:
/// ```dart
/// // Create a cache instance
/// final cache = PVCache(env: 'myCache', hooks: [], defaultMetadata: {});
///
/// // Use global access
/// await PVCacheTop.put('key', 'value');
/// final value = await PVCacheTop.get('key');
/// ```
///
/// Note: You can explicitly set which cache instance to use:
/// ```dart
/// PVCacheTop.currentEnv = 'myCache';
/// await PVCacheTop.put('key', 'value'); // Uses 'myCache' instance
/// ```
class PVCacheTop {
  /// The current environment name to use for operations.
  ///
  /// If null, will automatically resolve to the last created cache instance.
  /// Set this to explicitly control which cache instance is used.
  static String? currentEnv;

  /// Resolves the current cache instance based on [currentEnv].
  ///
  /// If [currentEnv] is null, uses the most recently created cache instance.
  /// Throws an [Exception] if no cache instances are available or if the
  /// specified environment doesn't exist.
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

  /// Stores a key-value pair in the cache.
  ///
  /// [key] - The cache key
  /// [value] - The value to cache (must be JSON-serializable)
  /// [metadata] - Optional metadata for hooks (e.g., TTL, secure fields)
  ///
  /// Example:
  /// ```dart
  /// await PVCacheTop.put('user:123', userData, metadata: {'ttl': 3600});
  /// ```
  static Future<void> put(
    String key,
    dynamic value, {
    Map<String, dynamic>? metadata,
  }) async {
    final cache = _resolveEnv();
    await cache.put(key, value, metadata: metadata);
  }

  /// Retrieves a value from the cache.
  ///
  /// [key] - The cache key
  /// [metadata] - Optional metadata for hooks
  ///
  /// Returns the cached value, or `null` if not found or expired.
  ///
  /// Example:
  /// ```dart
  /// final user = await PVCacheTop.get('user:123');
  /// ```
  static Future<dynamic> get(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    final cache = _resolveEnv();
    return await cache.get(key, metadata: metadata);
  }

  /// Deletes a key-value pair from the cache.
  ///
  /// [key] - The cache key to delete
  /// [metadata] - Optional metadata for hooks
  ///
  /// Example:
  /// ```dart
  /// await PVCacheTop.delete('user:123');
  /// ```
  static Future<void> delete(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    final cache = _resolveEnv();
    await cache.delete(key, metadata: metadata);
  }

  /// Clears all entries from the cache.
  ///
  /// [metadata] - Optional metadata for hooks
  ///
  /// Warning: This removes all cached data. Use with caution.
  ///
  /// Example:
  /// ```dart
  /// await PVCacheTop.clear();
  /// ```
  static Future<void> clear({Map<String, dynamic>? metadata}) async {
    final cache = _resolveEnv();
    await cache.clear(metadata: metadata);
  }

  /// Checks if a key exists in the cache.
  ///
  /// [key] - The cache key to check
  /// [metadata] - Optional metadata for hooks
  ///
  /// Returns `true` if the key exists and is not expired, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (await PVCacheTop.exists('user:123')) {
  ///   print('User is cached');
  /// }
  /// ```
  static Future<bool> exists(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    final cache = _resolveEnv();
    return await cache.exists(key, metadata: metadata);
  }
}
