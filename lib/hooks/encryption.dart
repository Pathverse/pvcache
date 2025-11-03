import 'dart:convert';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/utils/encrypt.dart';

/// Encryption Hook System
///
/// This system implements automatic encryption/decryption using AES-256-CTR.
/// Based on production-ready encryption from pvcache_hive package.
///
/// Features:
/// - AES-256-CTR encryption (no padding required, handles any length)
/// - Automatic key generation and secure storage
/// - Deterministic IV generation for consistent caching
/// - Cross-platform compatibility
/// - Base64 encoding for safe storage
///
/// Usage:
/// ```dart
/// // Auto-generate and store key
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: createEncryptionHooks(),
///   defaultMetadata: {},
/// );
///
/// // Use custom key
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: createEncryptionHooks(encryptionKey: 'my-secret-key'),
///   defaultMetadata: {},
/// );
///
/// // Use custom key name in secure storage
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: createEncryptionHooks(keyName: '_my_custom_key'),
///   defaultMetadata: {},
/// );
/// ```

/// Creates a hook that encrypts entry values before storage
///
/// This hook runs during the `storageUpdate` stage (before write) to encrypt
/// the entry value using AES-256-CTR encryption.
///
/// [encryptionKey] - Optional custom encryption key
/// [keyName] - Key name in secure storage (default: _pvcache_encryption_key)
/// [priority] - Hook priority (default: -50, runs before storage write)
PVCacheHook createEncryptionEncryptHook({
  String? encryptionKey,
  String keyName = DEFAULT_ENCRYPTION_KEY_NAME,
  int priority = -50,
}) {
  return PVCacheHook(
    eventString: 'encryption_encrypt',
    eventFlow: EventFlow.storageUpdate,
    priority: priority,
    actionTypes: [ActionType.put],
    hookFunction: (ctx) async {
      // Skip if no value
      if (ctx.entryValue == null) return;

      // Get or create encryption key
      final key = encryptionKey ?? await getOrCreateEncryptionKey(keyName);
      final cipher = AESCipher(key);

      // Convert value to JSON string
      final jsonString = jsonEncode(ctx.entryValue);

      // Encrypt
      final encrypted = cipher.encryptString(jsonString);

      // Replace entry value with encrypted version
      ctx.entryValue = encrypted;

      // Mark in metadata that this entry is encrypted
      ctx.runtimeMeta['_encrypted'] = true;
    },
  );
}

/// Creates a hook that decrypts entry values after retrieval
///
/// This hook runs during the `postProcess` stage (after storage and metadata reads)
/// to decrypt the entry value using AES-256-CTR encryption.
///
/// [encryptionKey] - Optional custom encryption key (must match encrypt hook)
/// [keyName] - Key name in secure storage (must match encrypt hook)
/// [priority] - Hook priority (default: 0)
PVCacheHook createEncryptionDecryptHook({
  String? encryptionKey,
  String keyName = DEFAULT_ENCRYPTION_KEY_NAME,
  int priority = 0,
}) {
  return PVCacheHook(
    eventString: 'encryption_decrypt',
    eventFlow: EventFlow.postProcess,
    priority: priority,
    actionTypes: [ActionType.get, ActionType.exists],
    hookFunction: (ctx) async {
      // Skip if no value or not encrypted
      if (ctx.entryValue == null) return;
      if (ctx.runtimeMeta['_encrypted'] != true) return;

      // Get encryption key
      final key = encryptionKey ?? await getOrCreateEncryptionKey(keyName);
      final cipher = AESCipher(key);

      try {
        // Decrypt
        final decrypted = cipher.decryptString(ctx.entryValue as String);

        // Parse JSON back to original value
        ctx.entryValue = jsonDecode(decrypted);
      } catch (e) {
        // If decryption fails, leave as null
        ctx.entryValue = null;
        print('Warning: Failed to decrypt entry: $e');
      }
    },
  );
}

/// Creates a complete encryption hook set
///
/// This is a convenience function that creates both encrypt and decrypt hooks.
///
/// [encryptionKey] - Optional custom encryption key
/// [keyName] - Key name in secure storage (default: _pvcache_encryption_key)
///
/// If no key is provided, a key will be automatically generated and stored
/// in secure storage under the specified keyName.
List<PVCacheHook> createEncryptionHooks({
  String? encryptionKey,
  String keyName = DEFAULT_ENCRYPTION_KEY_NAME,
}) {
  return [
    createEncryptionEncryptHook(encryptionKey: encryptionKey, keyName: keyName),
    createEncryptionDecryptHook(encryptionKey: encryptionKey, keyName: keyName),
  ];
}
