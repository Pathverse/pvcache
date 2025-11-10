import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';

void main() {
  group('PVCache Iter Keys Operations', () {
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
