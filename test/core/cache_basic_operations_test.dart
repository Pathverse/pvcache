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

    test('overwrite existing value', () async {
      await cache.put('key11', 'original');
      await cache.put('key11', 'updated');
      final result = await cache.get('key11');
      expect(result, equals('updated'));
    });
  });
}
