import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';

void main() {
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
}
