import 'dart:convert';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/utils/encrypt.dart';

/// Encryption Hook System
///
/// Automatic encryption/decryption using AES-256-CTR.
///
/// Features:
/// - AES-256-CTR (no padding, handles any length)
/// - Auto key generation and secure storage
/// - Deterministic IV for consistent caching
/// - Cross-platform
/// - Base64 encoding
///
/// Usage:
/// ```dart
/// // Auto-generate key
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: createEncryptionHooks(),
///   defaultMetadata: {},
/// );
///
/// // Custom key
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: createEncryptionHooks(encryptionKey: 'my-secret-key'),
///   defaultMetadata: {},
/// );
/// ```

/// Creates a hook that encrypts entry values before storage.
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

/// Creates a hook that decrypts entry values after retrieval.
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

/// Creates complete encryption hook set.
///
/// Auto-generates and stores key if not provided.
List<PVCacheHook> createEncryptionHooks({
  String? encryptionKey,
  String keyName = DEFAULT_ENCRYPTION_KEY_NAME,
}) {
  return [
    createEncryptionEncryptHook(encryptionKey: encryptionKey, keyName: keyName),
    createEncryptionDecryptHook(encryptionKey: encryptionKey, keyName: keyName),
  ];
}
