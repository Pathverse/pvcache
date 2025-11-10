import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';

void main() {
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
}
