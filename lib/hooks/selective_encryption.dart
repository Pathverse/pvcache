import 'dart:convert';
import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/utils/encrypt.dart';
import 'package:pvcache/utils/nested.dart';

/// Selective Encryption Hook System
///
/// Encrypts specific fields rather than entire value.
/// Each field gets unique nonce stored in metadata.
///
/// Usage:
/// ```dart
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: createSelectiveEncryptionHooks(),
///   defaultMetadata: {},
/// );
///
/// await cache.put(
///   'user:123',
///   {'name': 'John', 'password': 'secret', 'profile': {'ssn': '123-45-6789'}},
///   metadata: {'secure': ['password', 'profile.ssn']}
/// );
/// ```
///
/// Features:
/// - Dot notation paths
/// - Unique nonce per field
/// - Non-sensitive fields remain readable
/// - Works with nested structures

/// Creates a hook that selectively encrypts specified fields.
PVCacheHook createSelectiveEncryptionEncryptHook({
  String? encryptionKey,
  String keyName = DEFAULT_ENCRYPTION_KEY_NAME,
  int priority = -50,
}) {
  return PVCacheHook(
    eventString: 'selective_encryption_encrypt',
    eventFlow: EventFlow.storageUpdate,
    priority: priority,
    actionTypes: [ActionType.put],
    hookFunction: (ctx) async {
      // Skip if no value
      if (ctx.entryValue == null) return;

      // Check if selective encryption is requested via initialMeta
      final securePaths = ctx.initialMeta['secure'];
      if (securePaths == null || securePaths is! List || securePaths.isEmpty) {
        return;
      }

      // Get or create encryption key
      final key = encryptionKey ?? await getOrCreateEncryptionKey(keyName);
      final cipher = AESCipher(key);

      // Store nonces for each encrypted field
      final nonces = <String, String>{};

      // Make a deep copy of the value to modify
      final valueJson = jsonEncode(ctx.entryValue);
      final modifiedValue = jsonDecode(valueJson);

      // Encrypt each specified field
      for (final path in securePaths) {
        if (path is! String) continue;

        // Get the value at this path
        final fieldValue = getNestedValue(modifiedValue, path);
        if (fieldValue == null) continue;

        // Generate unique nonce for this field
        final nonce = generateNonce();
        nonces[path] = nonce;

        // Convert field value to JSON string
        final fieldJson = jsonEncode(fieldValue);

        // Encrypt with nonce
        final encrypted = cipher.encryptStringWithNonce(fieldJson, nonce);

        // Replace field value with encrypted version
        setNestedValue(modifiedValue, path, encrypted);
      }

      // Update entry value with modified data
      ctx.entryValue = modifiedValue;

      // Store nonces and encryption flag in runtime metadata
      // This will be persisted by the cache system automatically
      ctx.runtimeMeta['_selective_encrypted'] = true;
      ctx.runtimeMeta['_encryption_nonces'] = nonces;
    },
  );
}

/// Creates a hook that decrypts selectively encrypted fields.
PVCacheHook createSelectiveEncryptionDecryptHook({
  String? encryptionKey,
  String keyName = DEFAULT_ENCRYPTION_KEY_NAME,
  int priority = 0,
}) {
  return PVCacheHook(
    eventString: 'selective_encryption_decrypt',
    eventFlow: EventFlow.postProcess,
    priority: priority,
    actionTypes: [ActionType.get, ActionType.exists],
    hookFunction: (ctx) async {
      // Skip if no value
      if (ctx.entryValue == null) return;

      // Check if this entry has selective encryption
      final nonces = ctx.runtimeMeta['_encryption_nonces'] as Map?;
      if (nonces == null || nonces.isEmpty) return;

      // Get encryption key
      final key = encryptionKey ?? await getOrCreateEncryptionKey(keyName);
      final cipher = AESCipher(key);

      // Make a deep copy of the value to modify
      final valueJson = jsonEncode(ctx.entryValue);
      final modifiedValue = jsonDecode(valueJson);

      // Decrypt each field
      for (final entry in nonces.entries) {
        final path = entry.key as String;
        // Note: nonce is stored in metadata but not needed for decryption
        // The IV generated from the nonce is embedded in the encrypted data

        // Get the encrypted value at this path
        final encryptedValue = getNestedValue(modifiedValue, path);
        if (encryptedValue == null || encryptedValue is! String) continue;

        try {
          // Decrypt (IV is extracted from encrypted data)
          final decrypted = cipher.decryptString(encryptedValue);

          // Parse JSON back to original value
          final fieldValue = jsonDecode(decrypted);

          // Restore decrypted value
          setNestedValue(modifiedValue, path, fieldValue);
        } catch (e) {
          // If decryption fails for this field, leave it as is
          print('Warning: Failed to decrypt field "$path": $e');
        }
      }

      // Update entry value with decrypted data
      ctx.entryValue = modifiedValue;
    },
  );
}

/// Creates complete selective encryption hook set.
///
/// Auto-generates and stores key if not provided.
List<PVCacheHook> createSelectiveEncryptionHooks({
  String? encryptionKey,
  String keyName = DEFAULT_ENCRYPTION_KEY_NAME,
}) {
  return [
    createSelectiveEncryptionEncryptHook(
      encryptionKey: encryptionKey,
      keyName: keyName,
    ),
    createSelectiveEncryptionDecryptHook(
      encryptionKey: encryptionKey,
      keyName: keyName,
    ),
  ];
}
