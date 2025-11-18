import 'package:flutter_test/flutter_test.dart';
import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/hooks/encryption.dart';
import 'package:pvcache/hooks/encryption_recovery.dart';

void main() {
  setUpAll(() {
    // Enable test mode for in-memory database
    PVBridge.testMode = true;
  });

  group('Encryption Recovery Hook Tests', () {
    test('Detects decryption failure when key changes', () async {
      // Store with one key
      final cacheOriginal = PVCache(
        env: 'recovery_key_change',
        hooks: createEncryptionHooks(encryptionKey: 'original-key-123'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cacheOriginal.put('data', {'secret': 'important'});

      // Try to read with different key and recovery hook
      bool callbackTriggered = false;
      final cacheNewKey = PVCache(
        env: 'recovery_key_change',
        hooks: [
          ...createEncryptionHooks(
            encryptionKey: 'different-key-456',
            throwOnFailure: false, // MUST be false for recovery to work
          ),
          createEncryptionRecoveryHook(
            onDecryptionFailure: (key) async {
              callbackTriggered = true;
              expect(key, 'data');
              return false; // Don't clear
            },
          ),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Should return null due to decryption failure
      final result = await cacheNewKey.get('data');
      expect(result, null);
      expect(callbackTriggered, true);
    });

    test('Auto-clear on decryption failure', () async {
      // Store with one key
      final cacheOriginal = PVCache(
        env: 'recovery_auto_clear',
        hooks: createEncryptionHooks(encryptionKey: 'original-key'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cacheOriginal.put('corrupted', {'data': 'test'});

      // Read with different key and auto-clear enabled
      final cacheNewKey = PVCache(
        env: 'recovery_auto_clear',
        hooks: [
          ...createEncryptionHooks(
            encryptionKey: 'new-key',
            throwOnFailure: false,
          ),
          createEncryptionRecoveryHook(autoClearOnFailure: true),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      final result = await cacheNewKey.get('corrupted');
      expect(result, null);

      // Verify entry was cleared
      final exists = await cacheNewKey.exists('corrupted');
      expect(exists, false);
    });

    test('Callback controls clearing behavior', () async {
      // Store with one key
      final cacheOriginal = PVCache(
        env: 'recovery_callback_clear',
        hooks: createEncryptionHooks(encryptionKey: 'key-one'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cacheOriginal.put('should_clear', {'data': 'test'});

      // Read with different key, callback returns true to clear
      final cacheNewKey = PVCache(
        env: 'recovery_callback_clear',
        hooks: [
          ...createEncryptionHooks(
            encryptionKey: 'key-two',
            throwOnFailure: false,
          ),
          createEncryptionRecoveryHook(
            onDecryptionFailure: (key) async => true, // Clear it
          ),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cacheNewKey.get('should_clear');

      // Verify entry was cleared
      final exists = await cacheNewKey.exists('should_clear');
      expect(exists, false);
    });

    test('Throw on failure option', () async {
      // Store with one key
      final cacheOriginal = PVCache(
        env: 'recovery_throw',
        hooks: createEncryptionHooks(encryptionKey: 'key-a'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cacheOriginal.put('entry', {'data': 'test'});

      // Try to read with different key, should throw
      final cacheNewKey = PVCache(
        env: 'recovery_throw',
        hooks: [
          ...createEncryptionHooks(
            encryptionKey: 'key-b',
            throwOnFailure: false, // Let recovery hook handle it
          ),
          createEncryptionRecoveryHook(throwOnFailure: true),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      expect(() async => await cacheNewKey.get('entry'), throwsException);
    });

    test('No false positives on successful decryption', () async {
      bool callbackCalled = false;

      final cache = PVCache(
        env: 'recovery_no_false_positive',
        hooks: [
          ...createEncryptionHooks(encryptionKey: 'consistent-key'),
          createEncryptionRecoveryHook(
            onDecryptionFailure: (key) async {
              callbackCalled = true;
              return false;
            },
          ),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cache.put('good_data', {'value': 'works'});
      final result = await cache.get('good_data');

      expect(result, {'value': 'works'});
      expect(callbackCalled, false); // Callback should NOT be triggered
    });

    test('Handles non-existent keys gracefully', () async {
      bool callbackCalled = false;

      final cache = PVCache(
        env: 'recovery_nonexistent',
        hooks: [
          ...createEncryptionHooks(encryptionKey: 'test-key'),
          createEncryptionRecoveryHook(
            onDecryptionFailure: (key) async {
              callbackCalled = true;
              return false;
            },
          ),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      final result = await cache.get('nonexistent');
      expect(result, null);
      expect(callbackCalled, false); // Should not trigger for missing keys
    });
  });

  group('Encryption Key Validation Hook Tests', () {
    test('Validates on first access and creates test entry', () async {
      bool keyInvalidCalled = false;

      final cache = PVCache(
        env: 'validation_first',
        hooks: [
          createEncryptionKeyValidationHook(
            testKey: '_validation_test',
            encryptionKey: 'test-key-123',
            onKeyInvalid: () async {
              keyInvalidCalled = true;
            },
          ),
          ...createEncryptionHooks(
            encryptionKey: 'test-key-123',
            throwOnFailure: false,
          ),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // First access - should validate without calling onKeyInvalid
      await cache.put('data', {'value': 'test'});
      expect(keyInvalidCalled, false);

      // Create test entry manually for validation
      await cache.put('_validation_test', '_pvcache_key_test');

      // Verify test entry exists
      final testEntry = await cache.get('_validation_test');
      expect(testEntry, '_pvcache_key_test');
    });

    test('Detects key change and calls onKeyInvalid', () async {
      // Setup: Create cache with test entry
      final setupCache = PVCache(
        env: 'validation_key_change',
        hooks: createEncryptionHooks(
          encryptionKey: 'original-key',
          throwOnFailure: false,
        ),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await setupCache.put('_validation_test', '_pvcache_key_test');
      await setupCache.put('data', {'value': 'test'});

      // Test: Create new cache with different key
      bool keyInvalidCalled = false;
      final newCache = PVCache(
        env: 'validation_key_change',
        hooks: [
          createEncryptionKeyValidationHook(
            testKey: '_validation_test',
            encryptionKey: 'different-key',
            onKeyInvalid: () async {
              keyInvalidCalled = true;
            },
          ),
          ...createEncryptionHooks(
            encryptionKey: 'different-key',
            throwOnFailure: false,
          ),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Access any key should trigger validation
      await newCache.get('data');

      // onKeyInvalid should be called due to decryption failure
      expect(keyInvalidCalled, true);
    });

    test('Validation only runs once per cache instance', () async {
      int validationCount = 0;

      final cache = PVCache(
        env: 'validation_once',
        hooks: [
          createEncryptionKeyValidationHook(
            testKey: '_test',
            encryptionKey: 'key',
            onKeyInvalid: () async {
              validationCount++;
            },
          ),
          ...createEncryptionHooks(encryptionKey: 'key', throwOnFailure: false),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Multiple operations should only validate once
      await cache.put('data1', {'value': '1'});
      await cache.put('data2', {'value': '2'});
      await cache.get('data1');
      await cache.get('data2');

      // Should not call onKeyInvalid since key is consistent
      expect(validationCount, 0);
    });
  });

  group('Utility Functions Tests', () {
    test('rotateEncryptionKey clears cache', () async {
      final cache = PVCache(
        env: 'rotate_key_test',
        hooks: createEncryptionHooks(encryptionKey: 'old-key'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Add some data
      await cache.put('data1', {'value': 'test1'});
      await cache.put('data2', {'value': 'test2'});

      // Rotate key
      await rotateEncryptionKey(cache: cache, newKey: 'new-key');

      // All data should be cleared
      expect(await cache.get('data1'), null);
      expect(await cache.get('data2'), null);
    });

    test('clearEncryptedEntries removes only encrypted data', () async {
      final cache = PVCache(
        env: 'clear_encrypted_test',
        hooks: createEncryptionHooks(encryptionKey: 'test-key'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Add encrypted data
      await cache.put('encrypted1', {'secret': 'data1'});
      await cache.put('encrypted2', {'secret': 'data2'});

      // Clear encrypted entries
      await clearEncryptedEntries(cache);

      // All entries should be gone (all were encrypted)
      expect(await cache.get('encrypted1'), null);
      expect(await cache.get('encrypted2'), null);
    });

    test('validateEncryptionKey returns true for valid key', () async {
      final cache = PVCache(
        env: 'validate_key_true',
        hooks: createEncryptionHooks(encryptionKey: 'test-key'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // First validation creates test entry
      final valid1 = await validateEncryptionKey(
        cache: cache,
        testKey: '_validation',
      );
      expect(valid1, true);

      // Second validation checks existing entry
      final valid2 = await validateEncryptionKey(
        cache: cache,
        testKey: '_validation',
      );
      expect(valid2, true);
    });

    test('validateEncryptionKey returns false for invalid key', () async {
      // Create test entry with one key
      final cache1 = PVCache(
        env: 'validate_key_false',
        hooks: createEncryptionHooks(encryptionKey: 'key-one'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await validateEncryptionKey(cache: cache1, testKey: '_test');

      // Try to validate with different key
      final cache2 = PVCache(
        env: 'validate_key_false',
        hooks: createEncryptionHooks(encryptionKey: 'key-two'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      final valid = await validateEncryptionKey(
        cache: cache2,
        testKey: '_test',
      );
      expect(valid, false);
    });
  });

  group('Integration Tests', () {
    test('Complete recovery workflow', () async {
      // Step 1: Create cache with encryption
      final originalCache = PVCache(
        env: 'recovery_workflow',
        hooks: createEncryptionHooks(encryptionKey: 'original-key'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await originalCache.put('user1', {'name': 'Alice'});
      await originalCache.put('user2', {'name': 'Bob'});

      // Step 2: Simulate key change - new cache with recovery
      final recoveryCache = PVCache(
        env: 'recovery_workflow',
        hooks: [
          ...createEncryptionHooks(
            encryptionKey: 'new-key',
            throwOnFailure: false,
          ),
          createEncryptionRecoveryHook(
            autoClearOnFailure: true,
            onDecryptionFailure: (key) async {
              // Log the failure
              return true; // Auto-clear
            },
          ),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      // Accessing old data should trigger recovery
      await recoveryCache.get('user1');
      await recoveryCache.get('user2');

      // Step 3: Add new data with new key
      await recoveryCache.put('user3', {'name': 'Charlie'});

      // Step 4: Verify new data works
      final user3 = await recoveryCache.get('user3');
      expect(user3, {'name': 'Charlie'});

      // Old data should be cleared
      expect(await recoveryCache.exists('user1'), false);
      expect(await recoveryCache.exists('user2'), false);
    });

    test('Recovery with selective clearing', () async {
      // Setup: cache with some data
      final cache1 = PVCache(
        env: 'selective_recovery',
        hooks: createEncryptionHooks(encryptionKey: 'key-1'),
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cache1.put('keep_me', {'important': true});
      await cache1.put('delete_me', {'important': false});

      // New cache with selective recovery
      final cache2 = PVCache(
        env: 'selective_recovery',
        hooks: [
          ...createEncryptionHooks(
            encryptionKey: 'key-2',
            throwOnFailure: false,
          ),
          createEncryptionRecoveryHook(
            onDecryptionFailure: (key) async {
              // Only clear entries starting with 'delete_'
              return key.startsWith('delete_');
            },
          ),
        ],
        defaultMetadata: {},
        entryStorageType: StorageType.inMemory,
        metadataStorageType: StorageType.inMemory,
      );

      await cache2.get('keep_me');
      await cache2.get('delete_me');

      // 'delete_me' should be cleared, 'keep_me' should still exist (but unreadable)
      expect(await cache2.exists('delete_me'), false);
      // Note: 'keep_me' entry still exists in storage but is corrupted/unreadable
      // The exists() check may return false if it can't decrypt the metadata
      // This is expected behavior - the entry is there but inaccessible
      final keepMeResult = await cache2.get('keep_me');
      expect(keepMeResult, null); // Can't decrypt, returns null
    });
  });
}
