import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/hooks/ttl.dart';

void main() {
  setUpAll(() {
    PVBridge.testMode = true;
  });

  group('TTL Hooks', () {
    test('should set _ttl_timestamp when ttl is provided', () async {
      final cache = PVCache(
        env: 'ttl_test',
        hooks: createTTLHooks(),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Put with TTL of 3600 seconds (1 hour)
      await cache.put('key1', 'value1', metadata: {'ttl': 3600});

      // Get the value back
      final result = await cache.get('key1');
      expect(result, 'value1');
    });

    test('should return value before expiration', () async {
      final cache = PVCache(
        env: 'ttl_test2',
        hooks: createTTLHooks(),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Put with TTL of 10 seconds
      await cache.put('key1', 'value1', metadata: {'ttl': 10});

      // Immediately get should work
      final result = await cache.get('key1');
      expect(result, 'value1');
    });

    test('should return null after expiration', () async {
      final cache = PVCache(
        env: 'ttl_test3',
        hooks: createTTLHooks(),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Put with TTL of 1 second
      await cache.put('key1', 'value1', metadata: {'ttl': 1});

      // Wait for expiration
      await Future.delayed(Duration(seconds: 2));

      // Should return null (expired)
      final result = await cache.get('key1');
      expect(result, null);
    });

    test('should work without TTL (no expiration)', () async {
      final cache = PVCache(
        env: 'ttl_test4',
        hooks: createTTLHooks(),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Put without TTL
      await cache.put('key1', 'value1');

      // Should still work
      final result = await cache.get('key1');
      expect(result, 'value1');
    });

    test('should handle invalid TTL values', () async {
      final cache = PVCache(
        env: 'ttl_test5',
        hooks: createTTLHooks(),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Put with invalid TTL (negative)
      await cache.put('key1', 'value1', metadata: {'ttl': -1});

      // Should still work (TTL ignored)
      final result = await cache.get('key1');
      expect(result, 'value1');

      // Put with invalid TTL (zero)
      await cache.put('key2', 'value2', metadata: {'ttl': 0});

      // Should still work (TTL ignored)
      final result2 = await cache.get('key2');
      expect(result2, 'value2');
    });

    test('should delete expired entry from storage', () async {
      final cache = PVCache(
        env: 'ttl_test6',
        hooks: createTTLHooks(),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Put with short TTL
      await cache.put('key1', 'value1', metadata: {'ttl': 1});

      // Wait for expiration
      await Future.delayed(Duration(seconds: 2));

      // First get returns null and deletes
      final result1 = await cache.get('key1');
      expect(result1, null);

      // Second get should also return null (entry was deleted)
      final result2 = await cache.get('key1');
      expect(result2, null);
    });

    test('should handle ttl as string', () async {
      final cache = PVCache(
        env: 'ttl_test7',
        hooks: createTTLHooks(),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Put with TTL as string
      await cache.put('key1', 'value1', metadata: {'ttl': '3600'});

      // Should work
      final result = await cache.get('key1');
      expect(result, 'value1');
    });

    test('should work with exists() operation', () async {
      final cache = PVCache(
        env: 'ttl_test8',
        hooks: createTTLHooks(),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Put with short TTL
      await cache.put('key1', 'value1', metadata: {'ttl': 1});

      // Should exist before expiration
      final exists1 = await cache.exists('key1');
      expect(exists1, true);

      // Wait for expiration
      await Future.delayed(Duration(seconds: 2));

      // Should not exist after expiration
      final exists2 = await cache.exists('key1');
      expect(exists2, false);
    });
  });
}
