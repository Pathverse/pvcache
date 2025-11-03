import 'package:pvcache/core/cache.dart';

class PVCacheTop {
  static String? currentEnv;

  static PVCache _resolveEnv() {
    if (currentEnv == null) {
      // get the last instance
      if (PVCache.instances.isEmpty) {
        throw Exception('No PVCache instances available to resolve environment.');
      }
      currentEnv = PVCache.instances.keys.last;
    }
    final cache = PVCache.instances[currentEnv!];
    if (cache == null) {
      throw Exception('No PVCache instance found for environment: $currentEnv');
    }
    return cache;
  }

  static Future<void> put(
    String key, 
    dynamic value, {
      Map<String, dynamic>? metadata,
    }
  ) async {
    final cache = _resolveEnv();
    await cache.put(key, value, metadata: metadata);
  }

  static Future<dynamic> get(
    String key, {
      Map<String, dynamic>? metadata,
    }
  ) async {
    final cache = _resolveEnv();
    return await cache.get(key, metadata: metadata);
  }

  static Future<void> delete(
    String key, {
      Map<String, dynamic>? metadata,
    }
  ) async {
    final cache = _resolveEnv();
    await cache.delete(key, metadata: metadata);
  }

  static Future<void> clear({
      Map<String, dynamic>? metadata,
    }
  ) async {
    final cache = _resolveEnv();
    await cache.clear(metadata: metadata);
  }

  static Future<bool> exists(
    String key, {
      Map<String, dynamic>? metadata,
    }
  ) async {
    final cache = _resolveEnv();
    return await cache.exists(key, metadata: metadata);
  }
}
