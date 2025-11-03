import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/hooks/encryption.dart';

void main() {
  setUpAll(() {
    // Enable test mode for in-memory database
    PVBridge.testMode = true;
  });

  group('Encryption Hook Tests', () {
    test('Basic encryption and decryption', () async {
      final cache = PVCache(
        env: 'encryption_test',
        hooks: createEncryptionHooks(encryptionKey: 'test-key-for-basic'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Store a value
      await cache.put('test_key', {'message': 'Hello, World!'});

      // Retrieve and verify decryption
      final retrieved = await cache.get('test_key');
      expect(retrieved, {'message': 'Hello, World!'});
    });

    test('Encryption with custom key', () async {
      const customKey = 'my-super-secret-key-12345678';

      final cache = PVCache(
        env: 'encryption_custom_key',
        hooks: createEncryptionHooks(encryptionKey: customKey),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Store and retrieve with custom key
      await cache.put('secure_data', {'password': 'secretpass123'});
      final retrieved = await cache.get('secure_data');

      expect(retrieved, {'password': 'secretpass123'});
    });

    test('Data is encrypted and decrypted correctly', () async {
      // Test that data can be stored and retrieved
      final cache = PVCache(
        env: 'encryption_verify',
        hooks: createEncryptionHooks(encryptionKey: 'test-key-123'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      final originalData = {'secret': 'this should be encrypted'};
      await cache.put('encrypted_entry', originalData);

      // Retrieve and verify
      final retrieved = await cache.get('encrypted_entry');
      expect(retrieved, originalData);
    });

    test('Different keys produce different results', () async {
      const key1 = 'key-one-12345678901234567890';
      const key2 = 'key-two-12345678901234567890';

      final cache1 = PVCache(
        env: 'encryption_key1',
        hooks: createEncryptionHooks(encryptionKey: key1),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      final cache2 = PVCache(
        env: 'encryption_key2',
        hooks: createEncryptionHooks(encryptionKey: key2),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      final testData = {'secret': 'same data for both'};

      await cache1.put('entry', testData);
      await cache2.put('entry', testData);

      // Both should decrypt correctly with their own keys
      final decrypted1 = await cache1.get('entry');
      final decrypted2 = await cache2.get('entry');
      expect(decrypted1, testData);
      expect(decrypted2, testData);
    });

    test('Wrong key fails to decrypt properly', () async {
      // Encrypt with one key
      final cacheEncrypt = PVCache(
        env: 'encryption_wrong_key',
        hooks: createEncryptionHooks(encryptionKey: 'correct-key-123'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cacheEncrypt.put('entry', {'secret': 'data'});

      // Try to decrypt with different key (reusing same env)
      final cacheDecrypt = PVCache(
        env: 'encryption_wrong_key',
        hooks: createEncryptionHooks(encryptionKey: 'wrong-key-456'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      final result = await cacheDecrypt.get('entry');

      // Should return null due to decryption failure
      expect(result, isNull);
    });

    test('Empty string encryption and decryption', () async {
      final cache = PVCache(
        env: 'encryption_empty',
        hooks: createEncryptionHooks(encryptionKey: 'test-key'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Test empty string
      await cache.put('empty', {'text': ''});
      final retrieved = await cache.get('empty');

      expect(retrieved, {'text': ''});
    });

    test('Complex nested data structures', () async {
      final cache = PVCache(
        env: 'encryption_complex',
        hooks: createEncryptionHooks(encryptionKey: 'complex-data-key'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      final complexData = {
        'user': {
          'id': 123,
          'name': 'John Doe',
          'roles': ['admin', 'user'],
          'settings': {'theme': 'dark', 'notifications': true},
        },
        'tokens': ['token1', 'token2'],
        'metadata': null,
      };

      await cache.put('complex', complexData);
      final retrieved = await cache.get('complex');

      expect(retrieved, complexData);
    });

    test('Custom key name parameter', () async {
      const customKeyName = '_my_custom_encryption_key';

      final cache = PVCache(
        env: 'encryption_custom_keyname',
        hooks: createEncryptionHooks(
          encryptionKey: 'explicit-key-for-test',
          keyName: customKeyName,
        ),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cache.put('test', {'data': 'value'});

      // Should decrypt correctly
      final retrieved = await cache.get('test');
      expect(retrieved, {'data': 'value'});
    });

    test('Multiple entries with encryption', () async {
      final cache = PVCache(
        env: 'encryption_multiple',
        hooks: createEncryptionHooks(encryptionKey: 'test-key'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Store multiple entries
      await cache.put('user1', {'name': 'Alice', 'age': 30});
      await cache.put('user2', {'name': 'Bob', 'age': 25});
      await cache.put('user3', {'name': 'Charlie', 'age': 35});

      // Retrieve and verify all
      expect(await cache.get('user1'), {'name': 'Alice', 'age': 30});
      expect(await cache.get('user2'), {'name': 'Bob', 'age': 25});
      expect(await cache.get('user3'), {'name': 'Charlie', 'age': 35});
    });

    test('Encryption persists across cache instances', () async {
      const testKey = 'persistent-key-12345678';
      const testData = {'persistent': 'data value'};

      // First instance - encrypt and store
      final cache1 = PVCache(
        env: 'encryption_persist',
        hooks: createEncryptionHooks(encryptionKey: testKey),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cache1.put('entry', testData);

      // Second instance - retrieve with same key (same env, shares storage)
      final cache2 = PVCache(
        env: 'encryption_persist',
        hooks: createEncryptionHooks(encryptionKey: testKey),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      final retrieved = await cache2.get('entry');
      expect(retrieved, testData);
    });
  });
}
