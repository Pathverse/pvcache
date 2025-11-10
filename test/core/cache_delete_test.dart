import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';

void main() {
  group('PVCache Delete Operations', () {
    late PVCache cache;

    setUp(() {
      cache = PVCache(
        env: 'test_delete',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    test('delete removes entry', () async {
      await cache.put('key10', 'to be deleted');
      await cache.delete('key10');
      final result = await cache.get('key10');
      expect(result, isNull);
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
  });
}
