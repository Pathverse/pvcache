import 'package:test/test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/ctx/ctx.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/db/db.dart';
import 'package:pvcache/hooks/ttl.dart';

void main() {
  setUpAll(() {
    Db.isTestMode = true;
  });

  group('LRUTTLPlugin Tests', () {
    setUp(() async {
      await Db.initialize();
    });

    tearDown(() async {
      Db.globalMetaCache.clear();
    });

    test('Combined plugin tracks LRU and enforces TTL', () async {
      final config = PVConfig(
        'combined_basic_test',
        storageType: StorageType.memory,
        plugins: [LRUTTLPlugin(maxSize: 5, defaultTTLMillis: 1000)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add items
      for (var i = 1; i <= 5; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      // Verify LRU tracking
      final accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );
      expect(accessOrder, ['key1', 'key2', 'key3', 'key4', 'key5']);

      // All should be available
      for (var i = 1; i <= 5; i++) {
        expect(await cache.get(PVCtx(key: 'key$i')), 'value$i');
      }
    });

    test('Expired items removed from LRU tracking', () async {
      final ttlMillis = 100;
      final config = PVConfig(
        'combined_expire_test',
        storageType: StorageType.memory,
        plugins: [LRUTTLPlugin(maxSize: 10, defaultTTLMillis: ttlMillis)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add items with different TTLs
      await cache.put(
        PVCtx(key: 'key1', value: 'value1', metadata: {'ttl': ttlMillis}),
      );
      await cache.put(
        PVCtx(key: 'key2', value: 'value2', metadata: {'ttl': 5000}),
      ); // Long TTL
      await cache.put(
        PVCtx(key: 'key3', value: 'value3', metadata: {'ttl': ttlMillis}),
      );

      var accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );
      expect(accessOrder, ['key1', 'key2', 'key3']);

      // Wait for key1 and key3 to expire
      await Future.delayed(Duration(milliseconds: ttlMillis + 50));

      // Access expired items - should be removed from tracking
      await cache.get(PVCtx(key: 'key1'));
      await cache.get(PVCtx(key: 'key3'));

      accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );

      expect(accessOrder.contains('key1'), isFalse);
      expect(accessOrder.contains('key2'), isTrue);
      expect(accessOrder.contains('key3'), isFalse);
    });

    test('LRU eviction respects TTL expiration', () async {
      final maxSize = 5;
      final ttlMillis = 100;
      final config = PVConfig(
        'combined_evict_test',
        storageType: StorageType.memory,
        plugins: [LRUTTLPlugin(maxSize: maxSize, defaultTTLMillis: ttlMillis)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Fill cache
      for (var i = 1; i <= maxSize; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      // Wait for items to expire
      await Future.delayed(Duration(milliseconds: ttlMillis + 50));

      // Add new items - expired items should be handled gracefully
      await cache.put(PVCtx(key: 'key6', value: 'value6'));

      // Only key6 should be available
      expect(await cache.get(PVCtx(key: 'key6')), 'value6');

      // Old keys should trigger cleanup when accessed
      for (var i = 1; i <= maxSize; i++) {
        expect(await cache.get(PVCtx(key: 'key$i')), isNull);
      }
    });

    test(
      'Combined plugin with large dataset (100 items, maxSize 50)',
      () async {
        final maxSize = 50;
        final config = PVConfig(
          'combined_large_test',
          storageType: StorageType.memory,
          plugins: [LRUTTLPlugin(maxSize: maxSize, defaultTTLMillis: 10000)],
        ).finalize();

        final cache = PVCache.create(config: config);

        // Add 100 items
        for (var i = 1; i <= 100; i++) {
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
        for (var i = 1; i <= 50; i++) {
          expect(await cache.get(PVCtx(key: 'key$i')), isNull);
        }

        // Last 50 items should exist
        for (var i = 51; i <= 100; i++) {
          expect(await cache.get(PVCtx(key: 'key$i')), 'value$i');
        }
      },
    );

    test('Combined plugin handles rapid expiration and eviction', () async {
      final maxSize = 10;
      final ttlMillis = 50;
      final config = PVConfig(
        'combined_rapid_test',
        storageType: StorageType.memory,
        plugins: [LRUTTLPlugin(maxSize: maxSize, defaultTTLMillis: ttlMillis)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add items that will expire quickly
      for (var i = 1; i <= 20; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));

        if (i == 10) {
          // Wait for first batch to start expiring
          await Future.delayed(Duration(milliseconds: ttlMillis + 20));
        }
      }

      // Items 11-20 should exist (recently added)
      for (var i = 11; i <= 20; i++) {
        final value = await cache.get(PVCtx(key: 'key$i'));
        expect(value, isNotNull, reason: 'key$i should exist');
      }

      // Items 1-10 should be expired
      for (var i = 1; i <= 10; i++) {
        expect(await cache.get(PVCtx(key: 'key$i')), isNull);
      }
    });

    test('Combined plugin with custom TTLs per item', () async {
      final maxSize = 10;
      final config = PVConfig(
        'combined_custom_ttl_test',
        storageType: StorageType.memory,
        plugins: [LRUTTLPlugin(maxSize: maxSize, defaultTTLMillis: 1000)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add items with varying TTLs
      await cache.put(
        PVCtx(key: 'short1', value: 'value1', metadata: {'ttl': 100}),
      );
      await cache.put(
        PVCtx(key: 'medium1', value: 'value2', metadata: {'ttl': 500}),
      );
      await cache.put(
        PVCtx(key: 'long1', value: 'value3', metadata: {'ttl': 5000}),
      );
      await cache.put(
        PVCtx(key: 'short2', value: 'value4', metadata: {'ttl': 100}),
      );

      // Wait for short TTL items to expire
      await Future.delayed(Duration(milliseconds: 150));

      expect(await cache.get(PVCtx(key: 'short1')), isNull);
      expect(await cache.get(PVCtx(key: 'short2')), isNull);
      expect(await cache.get(PVCtx(key: 'medium1')), 'value2');
      expect(await cache.get(PVCtx(key: 'long1')), 'value3');

      var accessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );

      // Expired items should be removed from tracking
      expect(accessOrder.contains('short1'), isFalse);
      expect(accessOrder.contains('short2'), isFalse);
    });

    test(
      'Combined plugin preserves recently accessed items despite TTL',
      () async {
        final maxSize = 5;
        final config = PVConfig(
          'combined_preserve_test',
          storageType: StorageType.memory,
          plugins: [LRUTTLPlugin(maxSize: maxSize, defaultTTLMillis: 10000)],
        ).finalize();

        final cache = PVCache.create(config: config);

        // Fill cache
        for (var i = 1; i <= maxSize; i++) {
          await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
        }

        // Access first two items
        await cache.get(PVCtx(key: 'key1'));
        await cache.get(PVCtx(key: 'key2'));

        // Add new items - should evict key3 and key4 (LRU)
        await cache.put(PVCtx(key: 'key6', value: 'value6'));
        await cache.put(PVCtx(key: 'key7', value: 'value7'));

        // key1 and key2 should still exist (recently accessed)
        expect(await cache.get(PVCtx(key: 'key1')), 'value1');
        expect(await cache.get(PVCtx(key: 'key2')), 'value2');

        // key3 and key4 should be evicted
        expect(await cache.get(PVCtx(key: 'key3')), isNull);
        expect(await cache.get(PVCtx(key: 'key4')), isNull);
      },
    );

    test('Combined plugin stress test: 150 mixed operations', () async {
      final maxSize = 30;
      final config = PVConfig(
        'combined_stress_test',
        storageType: StorageType.memory,
        plugins: [LRUTTLPlugin(maxSize: maxSize, defaultTTLMillis: 500)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Mixed operations: puts, gets, various TTLs
      for (var i = 1; i <= 150; i++) {
        if (i % 4 == 0) {
          // Read operation
          await cache.get(PVCtx(key: 'key\${i % 30}'));
        } else if (i % 4 == 1) {
          // Write with short TTL
          await cache.put(
            PVCtx(key: 'key$i', value: 'value$i', metadata: {'ttl': 100}),
          );
        } else if (i % 4 == 2) {
          // Write with medium TTL
          await cache.put(
            PVCtx(key: 'key$i', value: 'value$i', metadata: {'ttl': 500}),
          );
        } else {
          // Write with long TTL
          await cache.put(
            PVCtx(key: 'key$i', value: 'value$i', metadata: {'ttl': 5000}),
          );
        }

        // Periodic cleanup check
        if (i % 20 == 0) {
          final accessOrder = await Ref.getGlobalMetaValue(
            config,
            'lru_access_order',
            defaultValue: <String>[],
          );
          expect(
            accessOrder.length,
            lessThanOrEqualTo(maxSize),
            reason: 'LRU should not exceed maxSize at operation $i',
          );
        }
      }

      // Verify cache is still functional
      await cache.put(PVCtx(key: 'final_test', value: 'final_value'));
      expect(await cache.get(PVCtx(key: 'final_test')), 'final_value');

      final finalAccessOrder = await Ref.getGlobalMetaValue(
        config,
        'lru_access_order',
        defaultValue: <String>[],
      );
      expect(finalAccessOrder.length, lessThanOrEqualTo(maxSize));
    });

    test(
      'Combined plugin handles edge case: expired item eviction race',
      () async {
        final maxSize = 3;
        final ttlMillis = 100;
        final config = PVConfig(
          'combined_race_test',
          storageType: StorageType.memory,
          plugins: [
            LRUTTLPlugin(maxSize: maxSize, defaultTTLMillis: ttlMillis),
          ],
        ).finalize();

        final cache = PVCache.create(config: config);

        // Fill cache with short TTL items
        await cache.put(PVCtx(key: 'key1', value: 'value1'));
        await cache.put(PVCtx(key: 'key2', value: 'value2'));
        await cache.put(PVCtx(key: 'key3', value: 'value3'));

        // Wait for all to expire
        await Future.delayed(Duration(milliseconds: ttlMillis + 50));

        // Add new items
        await cache.put(PVCtx(key: 'key4', value: 'value4'));
        await cache.put(PVCtx(key: 'key5', value: 'value5'));

        // New items should exist
        expect(await cache.get(PVCtx(key: 'key4')), 'value4');
        expect(await cache.get(PVCtx(key: 'key5')), 'value5');

        // Old items should be expired
        expect(await cache.get(PVCtx(key: 'key1')), isNull);
        expect(await cache.get(PVCtx(key: 'key2')), isNull);
        expect(await cache.get(PVCtx(key: 'key3')), isNull);

        // New items still accessible
        expect(await cache.get(PVCtx(key: 'key4')), 'value4');
        expect(await cache.get(PVCtx(key: 'key5')), 'value5');
      },
    );

    test('Combined plugin with maxSize=1 and short TTL', () async {
      final ttlMillis = 100;
      final config = PVConfig(
        'combined_single_test',
        storageType: StorageType.memory,
        plugins: [LRUTTLPlugin(maxSize: 1, defaultTTLMillis: ttlMillis)],
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));
      expect(await cache.get(PVCtx(key: 'key1')), 'value1');

      // Add another - should evict key1
      await cache.put(PVCtx(key: 'key2', value: 'value2'));
      expect(await cache.get(PVCtx(key: 'key1')), isNull);
      expect(await cache.get(PVCtx(key: 'key2')), 'value2');

      // Wait for key2 to expire
      await Future.delayed(Duration(milliseconds: ttlMillis + 50));
      expect(await cache.get(PVCtx(key: 'key2')), isNull);

      // Add key3 to empty cache
      await cache.put(PVCtx(key: 'key3', value: 'value3'));
      expect(await cache.get(PVCtx(key: 'key3')), 'value3');
    });
  });
}
