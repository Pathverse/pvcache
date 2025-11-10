import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';

void main() {
  group('PVCache Multiple Entries', () {
    late PVCache cache;

    setUp(() {
      cache = PVCache(
        env: 'test_multiple',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    tearDown(() async {
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
  });
}
