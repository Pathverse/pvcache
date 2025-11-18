import 'dart:convert';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/utils/encrypt.dart';
import 'package:sembast/sembast.dart';

/// Encryption Recovery Hook System
///
/// Handles encryption key changes and recovery scenarios.
///
/// Features:
/// - Detect decryption failures
/// - Clear corrupted encrypted data
/// - Rotate encryption keys
/// - Recovery callbacks
///
/// Usage:
/// ```dart
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: [
///     ...createEncryptionHooks(),
///     createEncryptionRecoveryHook(
///       onDecryptionFailure: (key) async {
///         print('Failed to decrypt: $key');
///         // Return true to clear the corrupted entry
///         return true;
///       },
///     ),
///   ],
///   defaultMetadata: {},
/// );
/// ```

/// Callback type for handling decryption failures.
///
/// Return `true` to clear the corrupted entry, `false` to keep it.
typedef DecryptionFailureCallback = Future<bool> Function(String key);

/// Creates a hook that handles decryption failures.
///
/// This hook should run AFTER the encryption decrypt hook to catch failures.
/// IMPORTANT: When using this hook, you must set `throwOnFailure: false` in
/// the encryption decrypt hook, otherwise exceptions will be thrown before
/// this hook can handle them.
PVCacheHook createEncryptionRecoveryHook({
  DecryptionFailureCallback? onDecryptionFailure,
  bool autoClearOnFailure = false,
  bool throwOnFailure = false,
  int priority = 10,
}) {
  return PVCacheHook(
    eventString: 'encryption_recovery',
    eventFlow: EventFlow.postProcess,
    priority: priority,
    actionTypes: [ActionType.get, ActionType.exists],
    hookFunction: (ctx) async {
      // Check if decryption failed (value is null but _encrypted flag exists)
      final wasEncrypted = ctx.runtimeMeta['_encrypted'] == true;
      final decryptionFailed = wasEncrypted && ctx.entryValue == null;

      if (!decryptionFailed) return;

      // Call user callback if provided
      bool shouldClear = autoClearOnFailure;
      if (onDecryptionFailure != null && ctx.resolvedKey != null) {
        shouldClear = await onDecryptionFailure(ctx.resolvedKey!);
      }

      // Clear the corrupted entry if requested
      if (shouldClear && ctx.resolvedKey != null) {
        await ctx.cache.delete(ctx.resolvedKey!);
        // Mark in runtime data that entry was cleared
        ctx.runtimeData['_recovery_cleared'] = true;
      }

      // Throw error if requested
      if (throwOnFailure && ctx.resolvedKey != null) {
        throw Exception(
          'Decryption failed for key: ${ctx.resolvedKey}. The encryption key may have changed or the data is corrupted.',
        );
      }
    },
  );
}

/// Creates a hook that validates encryption key on first access.
///
/// Attempts to decrypt a test entry to verify key is valid.
/// If test fails, calls onKeyInvalid callback.
///
/// NOTE: This hook accesses storage directly to avoid infinite recursion.
/// The test entry must be created separately before using this hook.
PVCacheHook createEncryptionKeyValidationHook({
  required String testKey,
  String testValue = '_pvcache_key_test',
  String? encryptionKey,
  String keyName = '_pvcache_encryption_key',
  Future<void> Function()? onKeyInvalid,
  int priority = -100,
}) {
  bool validated = false;

  return PVCacheHook(
    eventString: 'encryption_key_validation',
    eventFlow: EventFlow.preProcess,
    priority: priority,
    actionTypes: [ActionType.get, ActionType.put],
    hookFunction: (ctx) async {
      // Only validate once per cache instance
      if (validated) return;

      // Skip validation for the test key itself to avoid recursion
      if (ctx.resolvedKey == testKey) {
        validated = true;
        return;
      }

      // Access storage directly to avoid recursion
      final bridge = PVBridge();
      final entryDb = await bridge.getDatabaseForType(
        ctx.cache.entryStorageType,
        heavy: ctx.cache.heavy,
        env: ctx.cache.env,
      );
      final entryStore = bridge.getStore(
        ctx.cache.env,
        ctx.cache.entryStorageType,
      );

      // Read test entry directly from storage
      final encryptedTestValue = await entryStore.record(testKey).get(entryDb);

      if (encryptedTestValue == null) {
        // Test entry doesn't exist, this is first run - mark as validated
        // The test entry will be created by normal cache operations later
        validated = true;
        return;
      }

      // Read metadata to check if it's encrypted
      final metaDb = await bridge.getDatabaseForType(
        ctx.cache.metadataStorageType,
        heavy: ctx.cache.heavy,
        env: ctx.cache.env,
      );
      final metaStoreName = ctx.cache.metadataNameFunction!(ctx.cache.env);
      final metaStore = bridge.getStore(
        metaStoreName,
        ctx.cache.metadataStorageType,
      );
      final metadata = await metaStore.record(testKey).get(metaDb);

      // If test entry exists and is encrypted, try to decrypt it
      if (metadata?['_encrypted'] == true) {
        try {
          final key = encryptionKey ?? await getOrCreateEncryptionKey(keyName);
          final cipher = AESCipher(key);
          final decrypted = cipher.decryptString(encryptedTestValue as String);
          final value = jsonDecode(decrypted);

          if (value == testValue) {
            // Key is valid
            validated = true;
            return;
          }

          // Value doesn't match - key changed
          if (onKeyInvalid != null) {
            await onKeyInvalid();
          }
        } catch (e) {
          // Decryption failed - key changed
          if (onKeyInvalid != null) {
            await onKeyInvalid();
          }
        }
      }

      validated = true;
    },
  );
}

/// Rotates encryption key and clears all encrypted data.
///
/// Use this when you need to change the encryption key.
/// WARNING: This will clear all encrypted cache entries.
Future<void> rotateEncryptionKey({
  required PVCache cache,
  String keyName = '_pvcache_encryption_key',
  String? newKey,
}) async {
  // Clear all cache data (encrypted data becomes unreadable)
  await cache.clear();

  // Skip secure storage operations in test mode
  if (!PVBridge.testMode) {
    // Delete old key from secure storage
    await PVBridge.secureStorage.delete(key: keyName);

    // Store new key if provided, otherwise will be auto-generated on next use
    if (newKey != null) {
      await PVBridge.secureStorage.write(key: keyName, value: newKey);
    }
  }
}

/// Clears all encrypted entries from cache.
///
/// This iterates through all entries and removes those with _encrypted flag.
/// Useful for recovery when key is lost.
Future<void> clearEncryptedEntries(PVCache cache) async {
  // Get all keys
  final allKeys = await cache.iterKeys();

  // Check each entry for encryption flag
  for (final key in allKeys) {
    // Read metadata directly from storage to check encryption flag
    final bridge = PVBridge();
    final db = await bridge.getDatabaseForType(
      cache.metadataStorageType,
      heavy: cache.heavy,
      env: cache.env,
    );
    final storeName = cache.metadataNameFunction!(cache.env);
    final store = bridge.getStore(storeName, cache.metadataStorageType);
    final metadata = await store.record(key).get(db);

    if (metadata?['_encrypted'] == true) {
      await cache.delete(key);
    }
  }
}

/// Validates that encryption key can decrypt existing data.
///
/// Returns true if key is valid, false if key mismatch detected.
/// Note: This function requires the cache to have throwOnFailure: false
/// in its encryption hooks to properly detect key mismatches.
Future<bool> validateEncryptionKey({
  required PVCache cache,
  required String testKey,
  String testValue = '_pvcache_key_test',
}) async {
  try {
    // Try to read test entry
    final result = await cache.get(testKey);

    // If test entry doesn't exist, create it
    if (result == null) {
      await cache.put(testKey, testValue, metadata: {});
      return true;
    }

    // Check if value matches
    return result == testValue;
  } catch (e) {
    // Decryption failed - key is invalid
    return false;
  }
}
