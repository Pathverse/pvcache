import 'package:test/test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/ctx/ctx.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/db/db.dart';

void main() {
  // Set test mode once before all tests
  setUpAll(() {
    Db.isTestMode = true;
  });

  group('PVCache Tests', () {
    setUp(() async {
      await Db.initialize();
    });

    tearDown(() async {
      // Clean up
      Db.globalMetaCache.clear();
    });

    test('Create cache instance with env string', () async {
      final config = PVConfig(
        'test_cache_create',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      expect(cache, isNotNull);
      expect(cache.config.env, equals('test_cache_create'));
    });

    test('Get returns null for non-existent key', () async {
      final config = PVConfig(
        'test_cache_get_null',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      final ctx = PVCtx(key: 'nonexistent_key');
      final value = await cache.get(ctx);

      expect(value, isNull);
    });

    test('Put and get value', () async {
      final config = PVConfig(
        'test_cache_put_get',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      final putCtx = PVCtx(
        key: 'user_id',
        value: 12345,
        metadata: {'source': 'api'},
      );
      await cache.put(putCtx);

      final getCtx = PVCtx(key: 'user_id');
      final value = await cache.get(getCtx);

      expect(value, equals(12345));
    });

    test('Put and get with metadata', () async {
      final config = PVConfig(
        'test_cache_metadata',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      final metadata = {'timestamp': 1234567890, 'version': '1.0'};
      final putCtx = PVCtx(
        key: 'data_key',
        value: 'some_data',
        metadata: metadata,
      );
      await cache.put(putCtx);

      // Verify value
      final getCtx = PVCtx(key: 'data_key');
      final value = await cache.get(getCtx);
      expect(value, equals('some_data'));

      // Verify metadata through store ref
      final ref = await Db.resolve(config);
      final retrievedMetadata = await ref.getMetadata('data_key');
      expect(retrievedMetadata['timestamp'], equals(1234567890));
      expect(retrievedMetadata['version'], equals('1.0'));
    });

    test('Update existing value', () async {
      final config = PVConfig(
        'test_cache_update',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'counter', value: 1));
      await cache.put(PVCtx(key: 'counter', value: 2));
      await cache.put(PVCtx(key: 'counter', value: 3));

      final value = await cache.get(PVCtx(key: 'counter'));
      expect(value, equals(3));
    });

    test('Delete removes value', () async {
      final config = PVConfig(
        'test_cache_delete',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'temp_key', value: 'temp_value'));

      final beforeDelete = await cache.get(PVCtx(key: 'temp_key'));
      expect(beforeDelete, equals('temp_value'));

      await cache.delete(PVCtx(key: 'temp_key'));

      final afterDelete = await cache.get(PVCtx(key: 'temp_key'));
      expect(afterDelete, isNull);
    });

    test('Clear removes all values', () async {
      final config = PVConfig(
        'test_cache_clear',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));
      await cache.put(PVCtx(key: 'key2', value: 'value2'));
      await cache.put(PVCtx(key: 'key3', value: 'value3'));

      await cache.clear(PVCtx(key: ''));

      expect(await cache.get(PVCtx(key: 'key1')), isNull);
      expect(await cache.get(PVCtx(key: 'key2')), isNull);
      expect(await cache.get(PVCtx(key: 'key3')), isNull);
    });

    test('ContainsKey returns correct boolean', () async {
      final config = PVConfig(
        'test_cache_contains',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      expect(await cache.containsKey(PVCtx(key: 'missing')), isFalse);

      await cache.put(PVCtx(key: 'exists', value: 'value'));
      expect(await cache.containsKey(PVCtx(key: 'exists')), isTrue);
    });

    test('IterateKey returns all keys', () async {
      final config = PVConfig(
        'test_cache_iter_key',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));
      await cache.put(PVCtx(key: 'key2', value: 'value2'));
      await cache.put(PVCtx(key: 'key3', value: 'value3'));

      final keys = await cache.iterateKey(PVCtx(key: ''));

      expect(keys, contains('key1'));
      expect(keys, contains('key2'));
      expect(keys, contains('key3'));
      expect(keys.length, equals(3));
    });

    test('IterateValue returns all values', () async {
      final config = PVConfig(
        'test_cache_iter_val',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));
      await cache.put(PVCtx(key: 'key2', value: 'value2'));
      await cache.put(PVCtx(key: 'key3', value: 'value3'));

      final values = await cache.iterateValue(PVCtx(key: ''));

      expect(values, contains('value1'));
      expect(values, contains('value2'));
      expect(values, contains('value3'));
      expect(values.length, equals(3));
    });

    test('IterateEntry returns all key-value pairs', () async {
      final config = PVConfig(
        'test_cache_iter_entry',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      await cache.put(PVCtx(key: 'key1', value: 'value1'));
      await cache.put(PVCtx(key: 'key2', value: 'value2'));

      final entries = await cache.iterateEntry(PVCtx(key: ''));
      final entriesList = entries.toList();

      expect(entriesList.length, equals(2));
      expect(
        entriesList.any((e) => e.key == 'key1' && e.value == 'value1'),
        isTrue,
      );
      expect(
        entriesList.any((e) => e.key == 'key2' && e.value == 'value2'),
        isTrue,
      );
    });

    test('Multiple cache instances for different environments', () async {
      final config1 = PVConfig(
        'env1',
        storageType: StorageType.memory,
      ).finalize();
      final config2 = PVConfig(
        'env2',
        storageType: StorageType.memory,
      ).finalize();

      final cache1 = PVCache.create(config: config1);
      final cache2 = PVCache.create(config: config2);

      await cache1.put(PVCtx(key: 'shared_key', value: 'env1_value'));
      await cache2.put(PVCtx(key: 'shared_key', value: 'env2_value'));

      final value1 = await cache1.get(PVCtx(key: 'shared_key'));
      final value2 = await cache2.get(PVCtx(key: 'shared_key'));

      expect(value1, equals('env1_value'));
      expect(value2, equals('env2_value'));
    });

    test('Singleton pattern - same env returns same instance', () async {
      final config = PVConfig(
        'singleton_test',
        storageType: StorageType.memory,
      ).finalize();

      final cache1 = PVCache.create(config: config);
      final cache2 = PVCache.create(env: 'singleton_test');

      expect(identical(cache1, cache2), isTrue);
    });

    test('ifNotCached computes value when not cached', () async {
      final config = PVConfig(
        'test_cache_if_not',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      var computeCount = 0;
      Future<int> computeExpensive() async {
        computeCount++;
        return 42;
      }

      final ctx = PVCtx(key: 'expensive_key');
      final result = await cache.ifNotCached(ctx, computeExpensive);

      expect(result, equals(42));
      expect(computeCount, equals(1));

      // Call again - should not compute
      final result2 = await cache.ifNotCached(ctx, computeExpensive);
      expect(result2, equals(42));
      expect(computeCount, equals(1)); // Still 1, not recomputed
    });

    test('copyWith creates new context with modified fields', () {
      final original = PVCtx(
        key: 'key1',
        value: 'value1',
        metadata: {'meta': 'data'},
      );

      final withNewValue = original.copyWith(value: 'value2');
      expect(withNewValue.key, equals('key1'));
      expect(withNewValue.value, equals('value2'));

      final withNewKey = original.copyWith(key: 'key2');
      expect(withNewKey.key, equals('key2'));
      expect(withNewKey.value, equals('value1'));
    });

    test('Store different data types', () async {
      final config = PVConfig(
        'test_cache_types',
        storageType: StorageType.memory,
      ).finalize();
      final cache = PVCache.create(config: config);

      // String
      await cache.put(PVCtx(key: 'string_key', value: 'hello'));
      expect(await cache.get(PVCtx(key: 'string_key')), equals('hello'));

      // Number
      await cache.put(PVCtx(key: 'int_key', value: 123));
      expect(await cache.get(PVCtx(key: 'int_key')), equals(123));

      // Double
      await cache.put(PVCtx(key: 'double_key', value: 3.14));
      expect(await cache.get(PVCtx(key: 'double_key')), equals(3.14));

      // Boolean
      await cache.put(PVCtx(key: 'bool_key', value: true));
      expect(await cache.get(PVCtx(key: 'bool_key')), equals(true));

      // List
      await cache.put(PVCtx(key: 'list_key', value: [1, 2, 3]));
      expect(await cache.get(PVCtx(key: 'list_key')), equals([1, 2, 3]));

      // Map
      await cache.put(PVCtx(key: 'map_key', value: {'nested': 'value'}));
      expect(
        await cache.get(PVCtx(key: 'map_key')),
        equals({'nested': 'value'}),
      );
    });
  });
}
