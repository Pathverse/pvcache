import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';

void main() {
  group('PVCache Exists Operations', () {
    late PVCache cache;

    setUp(() {
      cache = PVCache(
        env: 'test_exists',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
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
  });
}
