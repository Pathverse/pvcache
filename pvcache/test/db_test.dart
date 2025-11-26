import 'package:test/test.dart';
import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/db/db.dart';

void main() {
  // Set test mode once before all tests
  setUpAll(() {
    Db.isTestMode = true;
  });

  group('Database Layer Tests', () {
    setUp(() async {
      await Db.initialize();
    });

    tearDown(() async {
      // Clean up: Clear all caches and reset state
      Db.globalMetaCache.clear();
    });

    test('Database initialization in test mode', () async {
      await Db.initialize();
      expect(Db.memoryDb, isNotNull);
    });

    test('Resolve database for memory storage type', () async {
      final config = PVConfig(
        'test_env_resolve',
        storageType: StorageType.memory,
      ).finalize();
      final ref = await Db.resolve(config);

      expect(ref.config.env, equals('test_env_resolve'));
      expect(ref.db, isNotNull);
    });

    test('Put and get record', () async {
      final config = PVConfig(
        'test_env_put_get',
        storageType: StorageType.memory,
      ).finalize();
      final ref = await Db.resolve(config);

      // Put a value
      await ref.put('test_key', 'test_value', {'timestamp': 123456});

      // Get the value
      final value = await ref.getValue('test_key');
      expect(value, equals('test_value'));

      // Get metadata
      final metadata = await ref.getMetadata('test_key');
      expect(metadata['timestamp'], equals(123456));
    });

    test('Delete record', () async {
      final config = PVConfig(
        'test_env_delete',
        storageType: StorageType.memory,
      ).finalize();
      final ref = await Db.resolve(config);

      // Put and then delete
      await ref.put('delete_key', 'delete_value', {});
      expect(await ref.containsKey('delete_key'), isTrue);

      await ref.delete('delete_key');
      expect(await ref.containsKey('delete_key'), isFalse);
    });

    test('Clear all records', () async {
      final config = PVConfig(
        'test_env_clear',
        storageType: StorageType.memory,
      ).finalize();
      final ref = await Db.resolve(config);

      // Put multiple values
      await ref.put('key1', 'value1', {});
      await ref.put('key2', 'value2', {});
      await ref.put('key3', 'value3', {});

      // Clear all
      await ref.clear();

      expect(await ref.containsKey('key1'), isFalse);
      expect(await ref.containsKey('key2'), isFalse);
      expect(await ref.containsKey('key3'), isFalse);
    });

    test('ContainsKey returns correct boolean', () async {
      final config = PVConfig(
        'test_env_contains',
        storageType: StorageType.memory,
      ).finalize();
      final ref = await Db.resolve(config);

      expect(await ref.containsKey('nonexistent'), isFalse);

      await ref.put('exists', 'value', {});
      expect(await ref.containsKey('exists'), isTrue);
    });

    test('Global metadata tracking', () async {
      final config = PVConfig(
        'test_env_global_meta',
        storageType: StorageType.memory,
      ).finalize();
      final ref = await Db.resolve(config);

      await ref.put('key1', 'value1', {});
      await ref.put('key2', 'value2', {});

      final keys = await Ref.getGlobalMetaValue(
        config,
        'keys',
        defaultValue: [],
      );
      expect(keys, contains('key1'));
      expect(keys, contains('key2'));
    });

    test('Multiple environments isolated', () async {
      final config1 = PVConfig(
        'env1',
        storageType: StorageType.memory,
      ).finalize();
      final config2 = PVConfig(
        'env2',
        storageType: StorageType.memory,
      ).finalize();

      final ref1 = await Db.resolve(config1);
      final ref2 = await Db.resolve(config2);

      await ref1.put('shared_key', 'env1_value', {});
      await ref2.put('shared_key', 'env2_value', {});

      final value1 = await ref1.getValue('shared_key');
      final value2 = await ref2.getValue('shared_key');

      expect(value1, equals('env1_value'));
      expect(value2, equals('env2_value'));
    });

    test('Update existing value', () async {
      final config = PVConfig(
        'test_env_update',
        storageType: StorageType.memory,
      ).finalize();
      final ref = await Db.resolve(config);

      await ref.put('key', 'original', {'version': 1});
      await ref.put('key', 'updated', {'version': 2});

      final value = await ref.getValue('key');
      final metadata = await ref.getMetadata('key');

      expect(value, equals('updated'));
      expect(metadata['version'], equals(2));
    });

    test('Get non-existent key returns null', () async {
      final config = PVConfig(
        'test_env_nonexist',
        storageType: StorageType.memory,
      ).finalize();
      final ref = await Db.resolve(config);

      final value = await ref.getValue('nonexistent');
      expect(value, isNull);
    });
  });
}
