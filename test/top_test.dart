import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/core/top.dart';

void main() {
  group('PVCacheTop Basic Operations', () {
    late PVCache devCache;
    late PVCache prodCache;

    setUp(() {
      // Clear any existing instances
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;

      // Create test caches
      devCache = PVCache(
        env: 'dev',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      prodCache = PVCache(
        env: 'prod',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    tearDown(() async {
      await devCache.clear();
      await prodCache.clear();
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;
    });

    test('put and get using most recent cache', () async {
      await PVCacheTop.put('key1', 'Hello World');
      final result = await PVCacheTop.get('key1');
      expect(result, equals('Hello World'));
    });

    test('put and get with explicit currentEnv', () async {
      PVCacheTop.currentEnv = 'dev';
      await PVCacheTop.put('key2', 'Dev Value');

      final result = await PVCacheTop.get('key2');
      expect(result, equals('Dev Value'));
    });

    test('exists returns true for existing key', () async {
      await PVCacheTop.put('key3', 'exists');
      final exists = await PVCacheTop.exists('key3');
      expect(exists, isTrue);
    });

    test('exists returns false for non-existent key', () async {
      final exists = await PVCacheTop.exists('nonexistent');
      expect(exists, isFalse);
    });

    test('delete removes entry', () async {
      await PVCacheTop.put('key4', 'to be deleted');
      await PVCacheTop.delete('key4');
      final result = await PVCacheTop.get('key4');
      expect(result, isNull);
    });

    test('clear removes all entries from current cache', () async {
      await PVCacheTop.put('key5', 'value5');
      await PVCacheTop.put('key6', 'value6');
      await PVCacheTop.clear();

      final result5 = await PVCacheTop.get('key5');
      final result6 = await PVCacheTop.get('key6');

      expect(result5, isNull);
      expect(result6, isNull);
    });
  });

  group('PVCacheTop env:key Format', () {
    late PVCache devCache;
    late PVCache prodCache;

    setUp(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;

      devCache = PVCache(
        env: 'dev',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      prodCache = PVCache(
        env: 'prod',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    tearDown(() async {
      await devCache.clear();
      await prodCache.clear();
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;
    });

    test('parses env:key format and routes to correct cache', () async {
      await PVCacheTop.put('dev:user', 'Dev User');
      await PVCacheTop.put('prod:user', 'Prod User');

      // Check directly in caches
      final devResult = await devCache.get('user');
      final prodResult = await prodCache.get('user');

      expect(devResult, equals('Dev User'));
      expect(prodResult, equals('Prod User'));
    });

    test('get with env:key format retrieves from specific cache', () async {
      await devCache.put('session', 'Dev Session');
      await prodCache.put('session', 'Prod Session');

      final devResult = await PVCacheTop.get('dev:session');
      final prodResult = await PVCacheTop.get('prod:session');

      expect(devResult, equals('Dev Session'));
      expect(prodResult, equals('Prod Session'));
    });

    test('delete with env:key format removes from specific cache', () async {
      await devCache.put('temp', 'Temp Value');
      await prodCache.put('temp', 'Temp Value');

      await PVCacheTop.delete('dev:temp');

      final devResult = await devCache.get('temp');
      final prodResult = await prodCache.get('temp');

      expect(devResult, isNull);
      expect(prodResult, equals('Temp Value')); // Prod should still exist
    });

    test('exists with env:key format checks specific cache', () async {
      await devCache.put('data', 'Some Data');

      final devExists = await PVCacheTop.exists('dev:data');
      final prodExists = await PVCacheTop.exists('prod:data');

      expect(devExists, isTrue);
      expect(prodExists, isFalse);
    });

    test('env:key with multiple colons in key', () async {
      await PVCacheTop.put('dev:namespace:user:123', 'User Data');
      final result = await PVCacheTop.get('dev:namespace:user:123');
      expect(result, equals('User Data'));

      // Verify it's stored with the correct key (without 'dev:')
      final directResult = await devCache.get('namespace:user:123');
      expect(directResult, equals('User Data'));
    });

    test(
      'key with colon but not matching env name uses default cache',
      () async {
        await PVCacheTop.put('unknown:key', 'Value');

        // Should go to most recent cache (prod) with full key 'unknown:key'
        final result = await prodCache.get('unknown:key');
        expect(result, equals('Value'));
      },
    );
  });

  group('PVCacheTop Environment Resolution', () {
    late PVCache testCache;

    setUp(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;

      testCache = PVCache(
        env: 'test',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    tearDown(() async {
      await testCache.clear();
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;
    });

    test('uses most recent cache when currentEnv is null', () async {
      expect(PVCacheTop.currentEnv, isNull);

      await PVCacheTop.put('key', 'value');
      final result = await testCache.get('key');

      expect(result, equals('value'));
    });

    test('uses specified currentEnv when set', () async {
      // Create another cache
      final anotherCache = PVCache(
        env: 'another',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      PVCacheTop.currentEnv = 'test';
      await PVCacheTop.put('key', 'test value');

      final testResult = await testCache.get('key');
      final anotherResult = await anotherCache.get('key');

      expect(testResult, equals('test value'));
      expect(anotherResult, isNull); // Should not exist in 'another'
    });

    test('env:key overrides currentEnv setting', () async {
      final devCache = PVCache(
        env: 'dev',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Set currentEnv to 'test'
      PVCacheTop.currentEnv = 'test';

      // But use 'dev:key' format
      await PVCacheTop.put('dev:key', 'dev value');

      final testResult = await testCache.get('key');
      final devResult = await devCache.get('key');

      expect(testResult, isNull); // Should not exist in test cache
      expect(devResult, equals('dev value')); // Should exist in dev cache
    });
  });

  group('PVCacheTop Error Handling', () {
    setUp(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;
    });

    tearDown(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;
    });

    test('throws error when no cache instances available', () async {
      expect(
        () async => await PVCacheTop.put('key', 'value'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No PVCache instances available'),
          ),
        ),
      );
    });

    test('throws error when specified env does not exist', () async {
      // Create a cache
      PVCache(
        env: 'test',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      PVCacheTop.currentEnv = 'nonexistent';

      expect(
        () async => await PVCacheTop.put('key', 'value'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No PVCache instance found for environment'),
          ),
        ),
      );
    });
  });

  group('PVCacheTop with Metadata', () {
    late PVCache cache;

    setUp(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;

      cache = PVCache(
        env: 'test',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    tearDown(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;
    });

    test('put with metadata', () async {
      await PVCacheTop.put('key1', 'value1', metadata: {'priority': 'high'});

      final result = await PVCacheTop.get('key1');
      expect(result, equals('value1'));
    });

    test('get with metadata', () async {
      await PVCacheTop.put('key2', 'value2');

      final result = await PVCacheTop.get('key2', metadata: {'tracking': true});

      expect(result, equals('value2'));
    });

    test('delete with metadata', () async {
      await PVCacheTop.put('key3', 'value3');

      await PVCacheTop.delete('key3', metadata: {'reason': 'cleanup'});

      final result = await PVCacheTop.get('key3');
      expect(result, isNull);
    });

    test('exists with metadata', () async {
      await PVCacheTop.put('key4', 'value4');

      final exists = await PVCacheTop.exists('key4', metadata: {'check': true});

      expect(exists, isTrue);
    });

    test('clear with metadata', () async {
      await PVCacheTop.put('key5', 'value5');
      await PVCacheTop.clear(metadata: {'reason': 'reset'});

      final result = await PVCacheTop.get('key5');
      expect(result, isNull);
    });
  });

  group('PVCacheTop Data Types', () {
    late PVCache cache;

    setUp(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;

      cache = PVCache(
        env: 'test',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    tearDown(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;
    });

    test('string values', () async {
      await PVCacheTop.put('str', 'Hello World');
      expect(await PVCacheTop.get('str'), equals('Hello World'));
    });

    test('integer values', () async {
      await PVCacheTop.put('int', 42);
      expect(await PVCacheTop.get('int'), equals(42));
    });

    test('double values', () async {
      await PVCacheTop.put('double', 3.14159);
      expect(await PVCacheTop.get('double'), equals(3.14159));
    });

    test('boolean values', () async {
      await PVCacheTop.put('bool', true);
      expect(await PVCacheTop.get('bool'), equals(true));
    });

    test('list values', () async {
      final list = [1, 2, 3, 'four', true];
      await PVCacheTop.put('list', list);
      expect(await PVCacheTop.get('list'), equals(list));
    });

    test('map values', () async {
      final map = {'name': 'John', 'age': 30, 'active': true};
      await PVCacheTop.put('map', map);
      expect(await PVCacheTop.get('map'), equals(map));
    });

    test('nested object values', () async {
      final nested = {
        'user': {
          'id': 123,
          'profile': {'name': 'Alice'},
        },
      };
      await PVCacheTop.put('nested', nested);
      expect(await PVCacheTop.get('nested'), equals(nested));
    });

    test('null values', () async {
      await PVCacheTop.put('null', null);
      expect(await PVCacheTop.get('null'), isNull);
    });
  });

  group('PVCacheTop Multiple Caches Isolation', () {
    late PVCache cache1;
    late PVCache cache2;
    late PVCache cache3;

    setUp(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;

      cache1 = PVCache(
        env: 'cache1',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      cache2 = PVCache(
        env: 'cache2',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      cache3 = PVCache(
        env: 'cache3',
        hooks: [],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );
    });

    tearDown(() {
      PVCache.instances.clear();
      PVCacheTop.currentEnv = null;
    });

    test('operations on different caches are isolated', () async {
      await PVCacheTop.put('cache1:data', 'Data 1');
      await PVCacheTop.put('cache2:data', 'Data 2');
      await PVCacheTop.put('cache3:data', 'Data 3');

      expect(await cache1.get('data'), equals('Data 1'));
      expect(await cache2.get('data'), equals('Data 2'));
      expect(await cache3.get('data'), equals('Data 3'));
    });

    test('delete from one cache does not affect others', () async {
      await cache1.put('key', 'Value 1');
      await cache2.put('key', 'Value 2');
      await cache3.put('key', 'Value 3');

      await PVCacheTop.delete('cache2:key');

      expect(await cache1.get('key'), equals('Value 1'));
      expect(await cache2.get('key'), isNull);
      expect(await cache3.get('key'), equals('Value 3'));
    });

    test('clear only affects current cache', () async {
      await cache1.put('key', 'Value 1');
      await cache2.put('key', 'Value 2');
      await cache3.put('key', 'Value 3');

      PVCacheTop.currentEnv = 'cache2';
      await PVCacheTop.clear();

      expect(await cache1.get('key'), equals('Value 1'));
      expect(await cache2.get('key'), isNull);
      expect(await cache3.get('key'), equals('Value 3'));
    });
  });
}
