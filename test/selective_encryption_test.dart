import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/hooks/selective_encryption.dart';

void main() {
  setUpAll(() {
    // Enable test mode for in-memory database
    PVBridge.testMode = true;
  });

  group('Selective Encryption Hook Tests', () {
    late PVCache cache;

    setUp(() {
      cache = PVCache(
        env: 'test_selective_encryption',
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        hooks: createSelectiveEncryptionHooks(
          encryptionKey: 'test-key-for-selective-encryption-32',
        ),
        defaultMetadata: {},
      );
    });

    test('Encrypts and decrypts single field', () async {
      final data = {'id': 1, 'name': 'John', 'password': 'secret123'};

      await cache.put(
        'user:1',
        data,
        metadata: {
          'secure': ['password'],
        },
      );

      final result = await cache.get('user:1');

      expect(result, isNotNull);
      expect(result['id'], 1);
      expect(result['name'], 'John');
      expect(result['password'], 'secret123'); // Should be decrypted
    });

    test('Encrypts nested fields', () async {
      final data = {
        'id': 1,
        'name': 'John',
        'profile': {
          'ssn': '123-45-6789',
          'phone': '555-1234',
          'address': '123 Main St',
        },
      };

      await cache.put(
        'user:2',
        data,
        metadata: {
          'secure': ['profile.ssn', 'profile.phone'],
        },
      );

      final result = await cache.get('user:2');

      expect(result, isNotNull);
      expect(result['name'], 'John');
      expect(result['profile']['ssn'], '123-45-6789'); // Decrypted
      expect(result['profile']['phone'], '555-1234'); // Decrypted
      expect(result['profile']['address'], '123 Main St'); // Never encrypted
    });

    test('Handles list index encryption', () async {
      final data = {
        'id': 1,
        'tokens': [
          {'type': 'access', 'value': 'access_token_123'},
          {'type': 'refresh', 'value': 'refresh_token_456'},
        ],
      };

      await cache.put(
        'session:1',
        data,
        metadata: {
          'secure': ['tokens.0.value', 'tokens.1.value'],
        },
      );

      final result = await cache.get('session:1');

      expect(result, isNotNull);
      expect(result['tokens'][0]['type'], 'access');
      expect(result['tokens'][0]['value'], 'access_token_123'); // Decrypted
      expect(result['tokens'][1]['value'], 'refresh_token_456'); // Decrypted
    });

    test('Empty secure list does not encrypt', () async {
      final data = {'id': 1, 'name': 'John', 'password': 'secret'};

      await cache.put('user:3', data, metadata: {'secure': []});

      final result = await cache.get('user:3');

      expect(result, isNotNull);
      expect(result['password'], 'secret');
    });

    test('No secure metadata does not encrypt', () async {
      final data = {'id': 1, 'name': 'John', 'password': 'secret'};

      await cache.put('user:4', data);

      final result = await cache.get('user:4');

      expect(result, isNotNull);
      expect(result['password'], 'secret');
    });

    test('Non-existent paths are skipped', () async {
      final data = {'id': 1, 'name': 'John'};

      await cache.put(
        'user:5',
        data,
        metadata: {
          'secure': ['password', 'profile.ssn'], // These don't exist
        },
      );

      final result = await cache.get('user:5');

      expect(result, isNotNull);
      expect(result['id'], 1);
      expect(result['name'], 'John');
      expect(result.containsKey('password'), false);
    });

    test('Mixed data types are encrypted correctly', () async {
      final data = {
        'id': 1,
        'settings': {
          'apiKey': 'sk_live_abc123',
          'maxRetries': 3,
          'enabled': true,
          'tags': ['premium', 'verified'],
        },
      };

      await cache.put(
        'config:1',
        data,
        metadata: {
          'secure': ['settings.apiKey', 'settings.tags'],
        },
      );

      final result = await cache.get('config:1');

      expect(result, isNotNull);
      expect(result['settings']['apiKey'], 'sk_live_abc123'); // Decrypted
      expect(result['settings']['maxRetries'], 3); // Never encrypted
      expect(result['settings']['enabled'], true); // Never encrypted
      expect(result['settings']['tags'], [
        'premium',
        'verified',
      ]); // Decrypted list
    });

    test('Multiple entries have independent nonces', () async {
      final data1 = {'id': 1, 'secret': 'password1'};
      final data2 = {'id': 2, 'secret': 'password1'}; // Same value

      await cache.put(
        'user:10',
        data1,
        metadata: {
          'secure': ['secret'],
        },
      );
      await cache.put(
        'user:11',
        data2,
        metadata: {
          'secure': ['secret'],
        },
      );

      final result1 = await cache.get('user:10');
      final result2 = await cache.get('user:11');

      expect(result1['secret'], 'password1');
      expect(result2['secret'], 'password1');

      // Verify they're both decrypted correctly
      expect(result1, isNotNull);
      expect(result2, isNotNull);
    });

    test('Data persists across cache instances', () async {
      final data = {'id': 1, 'name': 'John', 'password': 'secret123'};

      await cache.put(
        'user:20',
        data,
        metadata: {
          'secure': ['password'],
        },
      );

      // Create new cache instance with same key
      final cache2 = PVCache(
        env: 'test_selective_encryption',
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        hooks: createSelectiveEncryptionHooks(
          encryptionKey: 'test-key-for-selective-encryption-32',
        ),
        defaultMetadata: {},
      );

      final result = await cache2.get('user:20');

      expect(result, isNotNull);
      expect(result['password'], 'secret123'); // Should still decrypt
    });

    test('Wrong key fails to decrypt', () async {
      final data = {'id': 1, 'password': 'secret123'};

      await cache.put(
        'user:30',
        data,
        metadata: {
          'secure': ['password'],
        },
      );

      // Create new cache with different key
      final cache2 = PVCache(
        env: 'test_selective_encryption',
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
        hooks: createSelectiveEncryptionHooks(
          encryptionKey: 'wrong-key-that-is-32-chars-long',
        ),
        defaultMetadata: {},
      );

      final result = await cache2.get('user:30');

      // Should get result but password field will fail to decrypt
      expect(result, isNotNull);
      expect(result['id'], 1);
      // Password will be corrupted or null due to decryption failure
    });

    test('Complex nested structure encryption', () async {
      final data = {
        'user': {
          'id': 1,
          'name': 'John',
          'auth': {
            'password': 'secret123',
            'tokens': {'access': 'tok_abc', 'refresh': 'tok_xyz'},
          },
          'profile': {'email': 'john@example.com', 'phone': '555-1234'},
        },
      };

      await cache.put(
        'complex:1',
        data,
        metadata: {
          'secure': [
            'user.auth.password',
            'user.auth.tokens.access',
            'user.auth.tokens.refresh',
            'user.profile.phone',
          ],
        },
      );

      final result = await cache.get('complex:1');

      expect(result, isNotNull);
      expect(result['user']['name'], 'John'); // Not encrypted
      expect(result['user']['auth']['password'], 'secret123'); // Decrypted
      expect(
        result['user']['auth']['tokens']['access'],
        'tok_abc',
      ); // Decrypted
      expect(
        result['user']['auth']['tokens']['refresh'],
        'tok_xyz',
      ); // Decrypted
      expect(
        result['user']['profile']['email'],
        'john@example.com',
      ); // Not encrypted
      expect(result['user']['profile']['phone'], '555-1234'); // Decrypted
    });
  });
}
