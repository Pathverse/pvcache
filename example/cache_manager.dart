import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/hooks/ttl.dart';
import 'package:pvcache/hooks/encryption.dart';
import 'package:pvcache/hooks/selective_encryption.dart';

/// A simple cache manager that uses TTL (Time-To-Live) for expiration
/// and encryption for secure data storage
class CacheManager {
  late final PVCache _cache;
  late final PVCache _secureCache;
  late final PVCache _selectiveCache;

  CacheManager() {
    // Regular cache with TTL only
    _cache = PVCache(
      env: 'user_cache',
      hooks: createTTLHooks(),
      defaultMetadata: {},
      entryStorageType: StorageType.stdSembast,
      metadataStorageType: StorageType.stdSembast,
    );

    // Secure cache with TTL + Encryption (auto-generated key)
    _secureCache = PVCache(
      env: 'secure_cache',
      hooks: [
        ...createTTLHooks(),
        ...createEncryptionHooks(), // Auto-generates and stores encryption key
      ],
      defaultMetadata: {},
      entryStorageType: StorageType.stdSembast,
      metadataStorageType: StorageType.stdSembast,
    );

    // Selective cache with TTL + Selective Encryption
    _selectiveCache = PVCache(
      env: 'selective_cache',
      hooks: [
        ...createTTLHooks(),
        ...createSelectiveEncryptionHooks(), // Encrypts only specified fields
      ],
      defaultMetadata: {},
      entryStorageType: StorageType.stdSembast,
      metadataStorageType: StorageType.stdSembast,
    );
  }

  /// Store data with a custom TTL in seconds
  Future<void> set(String key, dynamic value, {int? ttlSeconds}) async {
    final metadata = ttlSeconds != null ? {'ttl': ttlSeconds} : null;
    await _cache.put(key, value, metadata: metadata);
  }

  /// Retrieve data (returns null if expired)
  Future<dynamic> get(String key) async {
    return await _cache.get(key);
  }

  /// Check if a key exists and is not expired
  Future<bool> exists(String key) async {
    return await _cache.exists(key);
  }

  /// Delete a specific key
  Future<void> delete(String key) async {
    await _cache.delete(key);
  }

  /// Clear all cache
  Future<void> clear() async {
    await _cache.clear();
  }

  // ===== Secure Cache Methods (with encryption) =====

  /// Store sensitive data with encryption and optional TTL
  Future<void> setSecure(String key, dynamic value, {int? ttlSeconds}) async {
    final metadata = ttlSeconds != null ? {'ttl': ttlSeconds} : null;
    await _secureCache.put(key, value, metadata: metadata);
  }

  /// Retrieve encrypted data (automatically decrypted)
  Future<dynamic> getSecure(String key) async {
    return await _secureCache.get(key);
  }

  /// Check if a secure key exists and is not expired
  Future<bool> existsSecure(String key) async {
    return await _secureCache.exists(key);
  }

  /// Delete a specific secure key
  Future<void> deleteSecure(String key) async {
    await _secureCache.delete(key);
  }

  /// Clear all secure cache
  Future<void> clearSecure() async {
    await _secureCache.clear();
  }

  // ===== Selective Cache Methods (encrypts only specified fields) =====

  /// Store data with selective field encryption
  ///
  /// [key] - Cache key
  /// [value] - Data to cache (must be a Map or contain nested structures)
  /// [secureFields] - List of field paths to encrypt (e.g., ['password', 'profile.ssn'])
  /// [ttlSeconds] - Optional TTL in seconds
  Future<void> setSelective(
    String key,
    dynamic value, {
    List<String>? secureFields,
    int? ttlSeconds,
  }) async {
    final metadata = <String, dynamic>{};

    if (ttlSeconds != null) {
      metadata['ttl'] = ttlSeconds;
    }

    if (secureFields != null && secureFields.isNotEmpty) {
      metadata['secure'] = secureFields;
    }

    await _selectiveCache.put(
      key,
      value,
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }

  /// Retrieve selectively encrypted data (encrypted fields are automatically decrypted)
  Future<dynamic> getSelective(String key) async {
    return await _selectiveCache.get(key);
  }

  /// Check if a selective cache key exists and is not expired
  Future<bool> existsSelective(String key) async {
    return await _selectiveCache.exists(key);
  }

  /// Delete a specific selective cache key
  Future<void> deleteSelective(String key) async {
    await _selectiveCache.delete(key);
  }

  /// Clear all selective cache
  Future<void> clearSelective() async {
    await _selectiveCache.clear();
  }

  /// Close the cache and cleanup resources
  Future<void> close() async {
    await PVBridge().close();
  }
}
