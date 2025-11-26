import 'package:test/test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/ctx/ctx.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/db/db.dart';
import 'package:pvcache/hooks/lru.dart';

void main() {
  setUpAll(() {
    Db.isTestMode = true;
  });

  group('LRUPlugin Tests', () {
    setUp(() async {
      await Db.initialize();
    });

    tearDown(() async {
      Db.globalMetaCache.clear();
    });

    test('LRU tracks access order for small set', () async {
      final config = PVConfig(
        'lru_small_test',
        storageType: StorageType.memory,
        plugins: [LRUPlugin(maxSize: 5)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add items
      for (var i = 1; i <= 5; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      final accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );

      expect(accessOrder.length, 5);
      expect(accessOrder, ['key1', 'key2', 'key3', 'key4', 'key5']);
    });

    test('LRU updates access order on get', () async {
      final config = PVConfig(
        'lru_get_test',
        storageType: StorageType.memory,
        plugins: [LRUPlugin(maxSize: 5)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add items
      for (var i = 1; i <= 5; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      // Access key2 - should move to end
      await cache.get(PVCtx(key: 'key2'));

      var accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );
      expect(accessOrder, ['key1', 'key3', 'key4', 'key5', 'key2']);

      // Access key1 - should move to end
      await cache.get(PVCtx(key: 'key1'));

      accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );
      expect(accessOrder, ['key3', 'key4', 'key5', 'key2', 'key1']);
    });

    test(
      'LRU evicts least recently used item when exceeding maxSize',
      () async {
        final maxSize = 10;
        final config = PVConfig(
          'lru_evict_test',
          storageType: StorageType.memory,
          plugins: [LRUPlugin(maxSize: maxSize)],
        ).finalize();

        final cache = PVCache.create(config: config);

        // Fill cache to max
        for (var i = 1; i <= maxSize; i++) {
          await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
        }

        var accessOrder = await Ref.getGlobalMetaValue(
          config,
          'lru_access_order',
          defaultValue: <String>[],
        );
        expect(accessOrder.length, maxSize);

        // Add one more - should evict key1
        await cache.put(
          PVCtx(key: 'key${maxSize + 1}', value: 'value${maxSize + 1}'),
        );

        accessOrder = await Ref.getGlobalMetaValue(
          config,
          'lru_access_order',
          defaultValue: <String>[],
        );
        expect(accessOrder.length, maxSize);
        expect(accessOrder.contains('key1'), isFalse);
        expect(accessOrder.contains('key${maxSize + 1}'), isTrue);

        // Verify key1 was deleted
        final value1 = await cache.get(PVCtx(key: 'key1'));
        expect(value1, isNull);

        // Verify key2 still exists
        final value2 = await cache.get(PVCtx(key: 'key2'));
        expect(value2, 'value2');
      },
    );

    test('LRU handles large dataset (100 items, maxSize 50)', () async {
      final maxSize = 50;
      final totalItems = 100;
      final config = PVConfig(
        'lru_large_test',
        storageType: StorageType.memory,
        plugins: [LRUPlugin(maxSize: maxSize)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add 100 items - should keep only last 50
      for (var i = 1; i <= totalItems; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      final accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );

      // Should have exactly maxSize items
      expect(accessOrder.length, maxSize);

      // First 50 items should be evicted
      for (var i = 1; i <= totalItems - maxSize; i++) {
        final value = await cache.get(PVCtx(key: 'key$i'));
        expect(value, isNull, reason: 'key$i should be evicted');
      }

      // Last 50 items should exist
      for (var i = totalItems - maxSize + 1; i <= totalItems; i++) {
        final value = await cache.get(PVCtx(key: 'key$i'));
        expect(value, 'value$i', reason: 'key$i should exist');
      }
    });

    test(
      'LRU preserves most recently accessed items during eviction',
      () async {
        final maxSize = 10;
        final config = PVConfig(
          'lru_preserve_test',
          storageType: StorageType.memory,
          plugins: [LRUPlugin(maxSize: maxSize)],
        ).finalize();

        final cache = PVCache.create(config: config);

        // Add 10 items
        for (var i = 1; i <= maxSize; i++) {
          await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
        }

        // Access key1 and key2 to make them recently used
        await cache.get(PVCtx(key: 'key1'));
        await cache.get(PVCtx(key: 'key2'));

        var accessOrder = await Ref.getGlobalMetaValue(
          config,
          'lru_access_order',
          defaultValue: <String>[],
        );
        // Now order should be: key3...key10, key1, key2
        expect(accessOrder.last, 'key2');
        expect(accessOrder[accessOrder.length - 2], 'key1');

        // Add new items - key3 and key4 should be evicted first
        await cache.put(PVCtx(key: 'key11', value: 'value11'));
        await cache.put(PVCtx(key: 'key12', value: 'value12'));

        // key1 and key2 should still exist
        expect(await cache.get(PVCtx(key: 'key1')), 'value1');
        expect(await cache.get(PVCtx(key: 'key2')), 'value2');

        // key3 and key4 should be evicted
        expect(await cache.get(PVCtx(key: 'key3')), isNull);
        expect(await cache.get(PVCtx(key: 'key4')), isNull);
      },
    );

    test('LRU handles sequential access patterns', () async {
      final maxSize = 20;
      final config = PVConfig(
        'lru_sequential_test',
        storageType: StorageType.memory,
        plugins: [LRUPlugin(maxSize: maxSize)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add items and access them in sequence
      for (var i = 1; i <= maxSize; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      // Access first half multiple times
      for (var i = 1; i <= maxSize ~/ 2; i++) {
        await cache.get(PVCtx(key: 'key$i'));
      }

      // Add new items - second half should be evicted first
      for (var i = maxSize + 1; i <= maxSize + 10; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      // First half should still exist (recently accessed)
      for (var i = 1; i <= maxSize ~/ 2; i++) {
        final value = await cache.get(PVCtx(key: 'key$i'));
        expect(value, 'value$i', reason: 'key$i should exist');
      }

      // Items from second half should be evicted
      for (var i = maxSize ~/ 2 + 1; i <= maxSize ~/ 2 + 10; i++) {
        final value = await cache.get(PVCtx(key: 'key$i'));
        expect(value, isNull, reason: 'key$i should be evicted');
      }
    });

    test('LRU handles random access patterns', () async {
      final maxSize = 30;
      final config = PVConfig(
        'lru_random_test',
        storageType: StorageType.memory,
        plugins: [LRUPlugin(maxSize: maxSize)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add items
      for (var i = 1; i <= maxSize; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      // Random access pattern: access every 3rd item
      final accessedKeys = <String>[];
      for (var i = 3; i <= maxSize; i += 3) {
        await cache.get(PVCtx(key: 'key$i'));
        accessedKeys.add('key$i');
      }

      // Add new items equal to number of accessed items
      for (var i = maxSize + 1; i <= maxSize + accessedKeys.length; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      // Accessed keys should still exist
      for (final key in accessedKeys) {
        final value = await cache.get(PVCtx(key: key));
        expect(value, isNotNull, reason: '$key should exist');
      }
    });

    test('LRU handles updates to existing keys', () async {
      final maxSize = 5;
      final config = PVConfig(
        'lru_update_test',
        storageType: StorageType.memory,
        plugins: [LRUPlugin(maxSize: maxSize)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add initial items
      for (var i = 1; i <= maxSize; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      var accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );
      expect(accessOrder, ['key1', 'key2', 'key3', 'key4', 'key5']);

      // Update key1 - should move to end
      await cache.put(PVCtx(key: 'key1', value: 'updated_value1'));

      accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );
      expect(accessOrder, ['key2', 'key3', 'key4', 'key5', 'key1']);
      expect(await cache.get(PVCtx(key: 'key1')), 'updated_value1');

      // Add new item - key2 should be evicted
      await cache.put(PVCtx(key: 'key6', value: 'value6'));

      expect(await cache.get(PVCtx(key: 'key2')), isNull);
      expect(await cache.get(PVCtx(key: 'key1')), 'updated_value1');
    });

    test('LRU stress test: 50 operations', () async {
      final maxSize = 20;
      final config = PVConfig(
        'lru_stress_test',
        storageType: StorageType.memory,
        plugins: [LRUPlugin(maxSize: maxSize)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Perform 50 mixed operations
      for (var i = 1; i <= 50; i++) {
        if (i % 3 == 0) {
          // Read operation
          await cache.get(PVCtx(key: 'key\${i % 30}'));
        } else {
          // Write operation
          await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
        }
      }

      final accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );

      // Should never exceed maxSize
      expect(accessOrder.length, lessThanOrEqualTo(maxSize));

      // Verify cache is still functional
      await cache.put(PVCtx(key: 'test_key', value: 'test_value'));
      expect(await cache.get(PVCtx(key: 'test_key')), 'test_value');
    });

    test('LRU with maxSize=1 behaves like single-item cache', () async {
      final config = PVConfig(
        'lru_single_test',
        storageType: StorageType.memory,
        plugins: [LRUPlugin(maxSize: 1)],
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));
      expect(await cache.get(PVCtx(key: 'key1')), 'value1');

      await cache.put(PVCtx(key: 'key2', value: 'value2'));
      // key1 should be evicted after key2 is added (list becomes > 1)
      expect(await cache.get(PVCtx(key: 'key2')), 'value2');
      expect(await cache.get(PVCtx(key: 'key1')), isNull);

      await cache.put(PVCtx(key: 'key3', value: 'value3'));
      expect(await cache.get(PVCtx(key: 'key2')), isNull);
      expect(await cache.get(PVCtx(key: 'key3')), 'value3');
    });
  });
}
