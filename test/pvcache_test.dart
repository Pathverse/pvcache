import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';

void main() {
  group('PVCache Basic Operations', () {
    late PVCache cache;

    setUp(() {
      cache = PVCache(
        env: 'test',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    test('put and get string value', () async {
      await cache.put('key1', 'Hello World');
      final result = await cache.get('key1');
      expect(result, equals('Hello World'));
    });

    test('put and get integer value', () async {
      await cache.put('key2', 42);
      final result = await cache.get('key2');
      expect(result, equals(42));
    });

    test('put and get double value', () async {
      await cache.put('key3', 3.14159);
      final result = await cache.get('key3');
      expect(result, equals(3.14159));
    });

    test('put and get boolean value', () async {
      await cache.put('key4', true);
      final result = await cache.get('key4');
      expect(result, equals(true));
    });

    test('put and get list value', () async {
      final list = [1, 2, 3, 'four', true];
      await cache.put('key5', list);
      final result = await cache.get('key5');
      expect(result, equals(list));
    });

    test('put and get map value', () async {
      final map = {
        'name': 'John',
        'age': 30,
        'active': true,
        'scores': [95, 87, 92],
      };
      await cache.put('key6', map);
      final result = await cache.get('key6');
      expect(result, equals(map));
    });

    test('put and get nested object', () async {
      final nested = {
        'user': {
          'id': 123,
          'profile': {'name': 'Alice', 'email': 'alice@example.com'},
          'tags': ['admin', 'verified'],
        },
        'timestamp': 1699000000,
      };
      await cache.put('key7', nested);
      final result = await cache.get('key7');
      expect(result, equals(nested));
    });

    test('put and get null value', () async {
      await cache.put('key8', null);
      final result = await cache.get('key8');
      expect(result, isNull);
    });

    test('get non-existent key returns null', () async {
      final result = await cache.get('nonexistent');
      expect(result, isNull);
    });

    test('exists returns true for existing key', () async {
      await cache.put('key9', 'exists');
      final exists = await cache.exists('key9');
      expect(exists, isTrue);
    });

    test('exists returns false for non-existent key', () async {
      final exists = await cache.exists('nonexistent');
      expect(exists, isFalse);
    });

    test('delete removes entry', () async {
      await cache.put('key10', 'to be deleted');
      await cache.delete('key10');
      final result = await cache.get('key10');
      expect(result, isNull);
    });

    test('overwrite existing value', () async {
      await cache.put('key11', 'original');
      await cache.put('key11', 'updated');
      final result = await cache.get('key11');
      expect(result, equals('updated'));
    });
  });

  group('PVCache with Metadata', () {
    late PVCache cache;

    setUp(() {
      cache = PVCache(
        env: 'test_meta',
        hooks: [],
        defaultMetadata: {'version': 1},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    test('put with custom metadata', () async {
      await cache.put(
        'meta_key1',
        'value',
        metadata: {'priority': 'high', 'ttl': 3600},
      );
      final result = await cache.get('meta_key1');
      expect(result, equals('value'));
    });

    test('get with metadata parameter', () async {
      await cache.put('meta_key2', 'value');
      final result = await cache.get('meta_key2', metadata: {'tracking': true});
      expect(result, equals('value'));
    });
  });

  group('PVCache Data Types Edge Cases', () {
    late PVCache cache;

    setUp(() {
      cache = PVCache(
        env: 'test_edge',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    test('empty string', () async {
      await cache.put('empty', '');
      final result = await cache.get('empty');
      expect(result, equals(''));
    });

    test('empty list', () async {
      await cache.put('empty_list', []);
      final result = await cache.get('empty_list');
      expect(result, equals([]));
    });

    test('empty map', () async {
      await cache.put('empty_map', {});
      final result = await cache.get('empty_map');
      expect(result, equals({}));
    });

    test('zero value', () async {
      await cache.put('zero', 0);
      final result = await cache.get('zero');
      expect(result, equals(0));
    });

    test('negative number', () async {
      await cache.put('negative', -100);
      final result = await cache.get('negative');
      expect(result, equals(-100));
    });

    test('large number', () async {
      await cache.put('large', 999999999999);
      final result = await cache.get('large');
      expect(result, equals(999999999999));
    });

    test('special characters in string', () async {
      await cache.put('special', 'Hello\nWorld\t🚀');
      final result = await cache.get('special');
      expect(result, equals('Hello\nWorld\t🚀'));
    });

    test('unicode characters', () async {
      await cache.put('unicode', '你好世界 مرحبا العالم');
      final result = await cache.get('unicode');
      expect(result, equals('你好世界 مرحبا العالم'));
    });

    test('mixed type list', () async {
      final mixed = [
        1,
        'two',
        3.0,
        true,
        null,
        {'nested': 'map'},
        [1, 2, 3],
      ];
      await cache.put('mixed', mixed);
      final result = await cache.get('mixed');
      expect(result, equals(mixed));
    });
  });

  group('PVCache Multiple Entries', () {
    late PVCache cache;

    setUp(() {
      cache = PVCache(
        env: 'test_multi',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    tearDown(() async {
      // Clean up cache after each test
      await cache.clear();
    });

    test('store and retrieve multiple entries', () async {
      await cache.put('user1', {'name': 'Alice', 'age': 25});
      await cache.put('user2', {'name': 'Bob', 'age': 30});
      await cache.put('user3', {'name': 'Charlie', 'age': 35});

      final user1 = await cache.get('user1');
      final user2 = await cache.get('user2');
      final user3 = await cache.get('user3');

      expect(user1, equals({'name': 'Alice', 'age': 25}));
      expect(user2, equals({'name': 'Bob', 'age': 30}));
      expect(user3, equals({'name': 'Charlie', 'age': 35}));
    });

    test('delete one entry does not affect others', () async {
      await cache.put('key1', 'value1');
      await cache.put('key2', 'value2');
      await cache.put('key3', 'value3');

      await cache.delete('key2');

      expect(await cache.get('key1'), equals('value1'));
      expect(await cache.get('key2'), isNull);
      expect(await cache.get('key3'), equals('value3'));
    });

    test('iterKeys returns all stored keys', () async {
      await cache.put('user1', {'name': 'Alice'});
      await cache.put('user2', {'name': 'Bob'});
      await cache.put('user3', {'name': 'Charlie'});

      final keys = await cache.iterKeys();

      expect(keys, hasLength(3));
      expect(keys, containsAll(['user1', 'user2', 'user3']));
    });

    test('iterKeys returns empty list when cache is empty', () async {
      final keys = await cache.iterKeys();
      expect(keys, isEmpty);
    });

    test('iterKeys reflects deletions', () async {
      await cache.put('key1', 'value1');
      await cache.put('key2', 'value2');
      await cache.put('key3', 'value3');

      await cache.delete('key2');

      final keys = await cache.iterKeys();
      expect(keys, hasLength(2));
      expect(keys, containsAll(['key1', 'key3']));
      expect(keys, isNot(contains('key2')));
    });
  });
}
