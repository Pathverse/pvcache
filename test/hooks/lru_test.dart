import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/hooks/lru.dart';

void main() {
  setUpAll(() {
    PVBridge.testMode = true;
  });

  group('LRU Hooks', () {
    test('should track access count on get', () async {
      final cache = PVCache(
        env: 'lru_test',
        hooks: createLRUHooks(max: 5),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Put a value
      await cache.put('key1', 'value1');

      // Get it multiple times
      await cache.get('key1');
      await cache.get('key1');

      // Value should still be there
      final result = await cache.get('key1');
      expect(result, 'value1');
    });

    test('should evict least recently used when max is reached', () async {
      final cache = PVCache(
        env: 'lru_test2',
        hooks: createLRUHooks(max: 3),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Add 3 entries (at max)
      await cache.put('key1', 'value1');
      await cache.put('key2', 'value2');
      await cache.put('key3', 'value3');

      // All should exist
      expect(await cache.get('key1'), 'value1');
      expect(await cache.get('key2'), 'value2');
      expect(await cache.get('key3'), 'value3');

      // Add a 4th entry - should evict key1 (oldest, not accessed)
      await cache.put('key4', 'value4');

      // key1 should be gone
      expect(await cache.get('key1'), null);
      // Others should still exist
      expect(await cache.get('key2'), 'value2');
      expect(await cache.get('key3'), 'value3');
      expect(await cache.get('key4'), 'value4');
    });

    test('should keep recently accessed entries', () async {
      final cache = PVCache(
        env: 'lru_test3',
        hooks: createLRUHooks(max: 3),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Add 3 entries
      await cache.put('key1', 'value1');
      await cache.put('key2', 'value2');
      await cache.put('key3', 'value3');

      // Access key1 (updates its count)
      await cache.get('key1');

      // Add key4 - should evict key2 (lowest count, not key1)
      await cache.put('key4', 'value4');

      // key1 should still be there (was accessed)
      expect(await cache.get('key1'), 'value1');
      // key2 should be gone (LRU)
      expect(await cache.get('key2'), null);
      // Others should exist
      expect(await cache.get('key3'), 'value3');
      expect(await cache.get('key4'), 'value4');
    });

    test('should handle sequential evictions', () async {
      final cache = PVCache(
        env: 'lru_test4',
        hooks: createLRUHooks(max: 2),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Add entries one by one
      await cache.put('key1', 'value1');
      await cache.put('key2', 'value2');
      await cache.put('key3', 'value3'); // evicts key1
      await cache.put('key4', 'value4'); // evicts key2

      // Only the last 2 should remain
      expect(await cache.get('key1'), null);
      expect(await cache.get('key2'), null);
      expect(await cache.get('key3'), 'value3');
      expect(await cache.get('key4'), 'value4');
    });

    test('should not evict if under max', () async {
      final cache = PVCache(
        env: 'lru_test5',
        hooks: createLRUHooks(max: 10),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Add 5 entries (under max)
      for (int i = 0; i < 5; i++) {
        await cache.put('key$i', 'value$i');
      }

      // All should still exist
      for (int i = 0; i < 5; i++) {
        expect(await cache.get('key$i'), 'value$i');
      }
    });

    test('should work with max=1', () async {
      final cache = PVCache(
        env: 'lru_test6',
        hooks: createLRUHooks(max: 1),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Add first entry
      await cache.put('key1', 'value1');
      expect(await cache.get('key1'), 'value1');

      // Add second entry - should evict first
      await cache.put('key2', 'value2');
      expect(await cache.get('key1'), null);
      expect(await cache.get('key2'), 'value2');
    });
  });
}
