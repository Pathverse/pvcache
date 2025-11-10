import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/core/bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Enable test mode for in-memory database
  PVBridge.testMode = true;

  group('PVCache Sembast Operations', () {
    late PVCache cache;

    setUp(() async {
      cache = PVCache(
        env: 'test_sembast',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.stdSembast,
        metadataStorageType: StorageType.stdSembast,
      );
    });

    tearDown(() async {
      // Clean up database after each test
      await PVBridge().close();
    });

    test('put and get string value with sembast', () async {
      await cache.put('key1', 'Hello Sembast');
      final result = await cache.get('key1');
      expect(result, equals('Hello Sembast'));
    });

    test('put and get integer value with sembast', () async {
      await cache.put('key2', 42);
      final result = await cache.get('key2');
      expect(result, equals(42));
    });

    test('put and get double value with sembast', () async {
      await cache.put('key3', 3.14159);
      final result = await cache.get('key3');
      expect(result, equals(3.14159));
    });

    test('put and get boolean value with sembast', () async {
      await cache.put('key4', true);
      final result = await cache.get('key4');
      expect(result, equals(true));
    });

    test('put and get list value with sembast', () async {
      final list = [1, 2, 3, 'four', true];
      await cache.put('key5', list);
      final result = await cache.get('key5');
      expect(result, equals(list));
    });

    test('put and get map value with sembast', () async {
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

    test('put and get nested object with sembast', () async {
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

    test('get non-existent key returns null with sembast', () async {
      final result = await cache.get('nonexistent');
      expect(result, isNull);
    });

    test('exists returns true for existing key with sembast', () async {
      await cache.put('key9', 'exists');
      final exists = await cache.exists('key9');
      expect(exists, isTrue);
    });

    test('exists returns false for non-existent key with sembast', () async {
      final exists = await cache.exists('nonexistent');
      expect(exists, isFalse);
    });

    test('delete removes entry with sembast', () async {
      await cache.put('key10', 'to be deleted');
      await cache.delete('key10');
      final result = await cache.get('key10');
      expect(result, isNull);
    });

    test('overwrite existing value with sembast', () async {
      await cache.put('key11', 'original');
      await cache.put('key11', 'updated');
      final result = await cache.get('key11');
      expect(result, equals('updated'));
    });

    test('persistence - data survives cache recreation', () async {
      await cache.put('persist_key', 'persistent_value');

      // Create new cache instance with same env
      final cache2 = PVCache(
        env: 'test_sembast',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.stdSembast,
        metadataStorageType: StorageType.stdSembast,
      );

      final result = await cache2.get('persist_key');
      expect(result, equals('persistent_value'));
    });
  });

  group('PVCache Sembast Edge Cases', () {
    late PVCache cache;

    setUp(() async {
      cache = PVCache(
        env: 'test_sembast_edge',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.stdSembast,
        metadataStorageType: StorageType.stdSembast,
      );
    });

    tearDown(() async {
      await PVBridge().close();
    });

    test('empty string with sembast', () async {
      await cache.put('empty', '');
      final result = await cache.get('empty');
      expect(result, equals(''));
    });

    test('empty list with sembast', () async {
      await cache.put('empty_list', []);
      final result = await cache.get('empty_list');
      expect(result, equals([]));
    });

    test('empty map with sembast', () async {
      await cache.put('empty_map', {});
      final result = await cache.get('empty_map');
      expect(result, equals({}));
    });

    test('zero value with sembast', () async {
      await cache.put('zero', 0);
      final result = await cache.get('zero');
      expect(result, equals(0));
    });

    test('negative number with sembast', () async {
      await cache.put('negative', -100);
      final result = await cache.get('negative');
      expect(result, equals(-100));
    });

    test('special characters in string with sembast', () async {
      await cache.put('special', 'Hello\nWorld\t🚀');
      final result = await cache.get('special');
      expect(result, equals('Hello\nWorld\t🚀'));
    });

    test('unicode characters with sembast', () async {
      await cache.put('unicode', '你好世界 مرحبا العالم');
      final result = await cache.get('unicode');
      expect(result, equals('你好世界 مرحبا العالم'));
    });
  });

  group('PVCache Sembast Multiple Entries', () {
    late PVCache cache;

    setUp(() async {
      cache = PVCache(
        env: 'test_sembast_multi',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.stdSembast,
        metadataStorageType: StorageType.stdSembast,
      );
    });

    tearDown(() async {
      await PVBridge().close();
    });

    test('store and retrieve multiple entries with sembast', () async {
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

    test('delete one entry does not affect others with sembast', () async {
      await cache.put('key1', 'value1');
      await cache.put('key2', 'value2');
      await cache.put('key3', 'value3');

      await cache.delete('key2');

      expect(await cache.get('key1'), equals('value1'));
      expect(await cache.get('key2'), isNull);
      expect(await cache.get('key3'), equals('value3'));
    });
  });

  group('PVCache Mixed Storage Types', () {
    late PVCache cache;

    setUp(() async {
      cache = PVCache(
        env: 'test_mixed',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.stdSembast,
        metadataStorageType: StorageType.inMemory,
      );
    });

    tearDown(() async {
      await PVBridge().close();
    });

    test('entries in sembast, metadata in memory', () async {
      await cache.put('mixed_key', 'mixed_value', metadata: {'priority': 1});
      final result = await cache.get('mixed_key');
      expect(result, equals('mixed_value'));
    });
  });
}
