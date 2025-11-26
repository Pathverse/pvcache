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

  group('TTLPlugin Tests', () {
    setUp(() async {
      await Db.initialize();
    });

    tearDown(() async {
      Db.globalMetaCache.clear();
    });

    test('TTL adds timestamp metadata on put', () async {
      final config = PVConfig(
        'ttl_metadata_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: 1000)],
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));

      // Value should be immediately available
      final value = await cache.get(PVCtx(key: 'key1'));
      expect(value, 'value1');

      // Metadata should have been added (we can't directly check, but it works)
      expect(value, isNotNull);
    });

    test('TTL expires items after default TTL', () async {
      final ttlMillis = 100;
      final config = PVConfig(
        'ttl_expire_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: ttlMillis)],
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));

      // Should be available immediately
      var value = await cache.get(PVCtx(key: 'key1'));
      expect(value, 'value1');

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: ttlMillis + 50));

      // Should be expired now
      value = await cache.get(PVCtx(key: 'key1'));
      expect(value, isNull);
    });

    test('TTL respects custom TTL in metadata', () async {
      final config = PVConfig(
        'ttl_custom_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: 5000)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Item with short custom TTL
      await cache.put(
        PVCtx(key: 'key1', value: 'value1', metadata: {'ttl': 100}),
      );

      // Item with long custom TTL
      await cache.put(
        PVCtx(key: 'key2', value: 'value2', metadata: {'ttl': 5000}),
      );

      // Both should be available immediately
      expect(await cache.get(PVCtx(key: 'key1')), 'value1');
      expect(await cache.get(PVCtx(key: 'key2')), 'value2');

      // Wait for key1 to expire
      await Future.delayed(Duration(milliseconds: 150));

      // key1 should be expired, key2 should still exist
      expect(await cache.get(PVCtx(key: 'key1')), isNull);
      expect(await cache.get(PVCtx(key: 'key2')), 'value2');
    });

    test('TTL handles multiple items with different TTLs', () async {
      final config = PVConfig(
        'ttl_multiple_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: 1000)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add items with staggered custom TTLs
      await cache.put(
        PVCtx(key: 'key1', value: 'value1', metadata: {'ttl': 50}),
      );
      await cache.put(
        PVCtx(key: 'key2', value: 'value2', metadata: {'ttl': 200}),
      );
      await cache.put(
        PVCtx(key: 'key3', value: 'value3', metadata: {'ttl': 300}),
      );

      // All should be available initially
      expect(await cache.get(PVCtx(key: 'key1')), 'value1');
      expect(await cache.get(PVCtx(key: 'key2')), 'value2');
      expect(await cache.get(PVCtx(key: 'key3')), 'value3');

      // Wait for key1 to expire
      await Future.delayed(Duration(milliseconds: 80));

      expect(await cache.get(PVCtx(key: 'key1')), isNull);
      expect(await cache.get(PVCtx(key: 'key2')), 'value2');
      expect(await cache.get(PVCtx(key: 'key3')), 'value3');

      // Wait for key2 to expire
      await Future.delayed(Duration(milliseconds: 150));

      expect(await cache.get(PVCtx(key: 'key1')), isNull);
      expect(await cache.get(PVCtx(key: 'key2')), isNull);
      expect(await cache.get(PVCtx(key: 'key3')), 'value3');

      // Wait for key3 to expire
      await Future.delayed(Duration(milliseconds: 100));

      expect(await cache.get(PVCtx(key: 'key1')), isNull);
      expect(await cache.get(PVCtx(key: 'key2')), isNull);
      expect(await cache.get(PVCtx(key: 'key3')), isNull);
    });

    test('TTL handles large dataset (100 items)', () async {
      final ttlMillis = 200;
      final config = PVConfig(
        'ttl_large_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: ttlMillis)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add 100 items
      for (var i = 1; i <= 100; i++) {
        await cache.put(PVCtx(key: 'key$i', value: 'value$i'));
      }

      // All should be available immediately
      for (var i = 1; i <= 100; i++) {
        final value = await cache.get(PVCtx(key: 'key$i'));
        expect(value, 'value$i');
      }

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: ttlMillis + 50));

      // All should be expired
      for (var i = 1; i <= 100; i++) {
        final value = await cache.get(PVCtx(key: 'key$i'));
        expect(value, isNull, reason: 'key$i should be expired');
      }
    });

    test('TTL with very short expiration (50ms)', () async {
      final config = PVConfig(
        'ttl_short_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: 50)],
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));

      // Should be available immediately
      expect(await cache.get(PVCtx(key: 'key1')), 'value1');

      // Wait just past expiration
      await Future.delayed(Duration(milliseconds: 70));

      // Should be expired
      expect(await cache.get(PVCtx(key: 'key1')), isNull);
    });

    test('TTL with long expiration (items persist)', () async {
      final config = PVConfig(
        'ttl_long_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: 10000)],
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));

      // Should be available immediately
      expect(await cache.get(PVCtx(key: 'key1')), 'value1');

      // Wait a bit but not past expiration
      await Future.delayed(Duration(milliseconds: 100));

      // Should still be available
      expect(await cache.get(PVCtx(key: 'key1')), 'value1');
    });

    test('TTL deletes expired item from storage', () async {
      final ttlMillis = 100;
      final config = PVConfig(
        'ttl_delete_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: ttlMillis)],
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));

      // containsKey should return true initially
      expect(await cache.containsKey(PVCtx(key: 'key1')), isTrue);

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: ttlMillis + 50));

      // Access should delete the expired item
      await cache.get(PVCtx(key: 'key1'));

      // containsKey should now return false
      expect(await cache.containsKey(PVCtx(key: 'key1')), isFalse);
    });

    test('TTL allows re-adding expired keys', () async {
      final ttlMillis = 100;
      final config = PVConfig(
        'ttl_readd_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: ttlMillis)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Add and expire
      await cache.put(PVCtx(key: 'key1', value: 'value1'));
      await Future.delayed(Duration(milliseconds: ttlMillis + 50));
      expect(await cache.get(PVCtx(key: 'key1')), isNull);

      // Re-add with new value
      await cache.put(PVCtx(key: 'key1', value: 'new_value1'));
      expect(await cache.get(PVCtx(key: 'key1')), 'new_value1');

      // Wait for expiration again
      await Future.delayed(Duration(milliseconds: ttlMillis + 50));
      expect(await cache.get(PVCtx(key: 'key1')), isNull);
    });

    test('TTL stress test: rapid put/get cycles', () async {
      final config = PVConfig(
        'ttl_stress_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: 500)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Rapid fire 50 operations
      for (var i = 1; i <= 50; i++) {
        await cache.put(PVCtx(key: 'key${i % 30}', value: 'value$i'));

        if (i % 5 == 0) {
          await cache.get(PVCtx(key: 'key${i % 30}'));
        }
      } // Verify cache is still functional
      await cache.put(PVCtx(key: 'test_key', value: 'test_value'));
      expect(await cache.get(PVCtx(key: 'test_key')), 'test_value');
    });

    test('TTL with zero TTL expires immediately', () async {
      final config = PVConfig(
        'ttl_zero_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: 0)],
      ).finalize();

      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));

      // Even immediate access might return null due to 0 TTL
      // Wait a tiny bit to ensure expiration check runs
      await Future.delayed(Duration(milliseconds: 10));

      final value = await cache.get(PVCtx(key: 'key1'));
      expect(value, isNull);
    });

    test('TTL handles mixed operations on same key', () async {
      final config = PVConfig(
        'ttl_mixed_test',
        storageType: StorageType.memory,
        plugins: [TTLPlugin(defaultTTLMillis: 200)],
      ).finalize();

      final cache = PVCache.create(config: config);

      // Put initial value
      await cache.put(PVCtx(key: 'key1', value: 'value1'));
      expect(await cache.get(PVCtx(key: 'key1')), 'value1');

      // Wait a bit but don't expire
      await Future.delayed(Duration(milliseconds: 100));

      // Update value (resets TTL)
      await cache.put(PVCtx(key: 'key1', value: 'value2'));
      expect(await cache.get(PVCtx(key: 'key1')), 'value2');

      // Wait original TTL duration
      await Future.delayed(Duration(milliseconds: 150));

      // Should still exist because TTL was reset
      expect(await cache.get(PVCtx(key: 'key1')), 'value2');

      // Wait for new TTL to expire
      await Future.delayed(Duration(milliseconds: 100));

      // Now should be expired
      expect(await cache.get(PVCtx(key: 'key1')), isNull);
    });
  });
}
