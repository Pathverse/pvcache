import 'dart:convert';
import 'dart:typed_data';
import 'package:hivehook/hivehook.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

int _encryptionHookIdCounter = 0;

enum KeyRotationStrategy { passive, active, reactive }

/// Creates an encryption plugin using AES-256-CBC.
///
/// Example:
/// ```dart
/// final plugin = await createEncryptedHook(
///   rotationStrategy: KeyRotationStrategy.passive,
/// );
/// PVCache.setDefaultPlugins([plugin]);
/// ```
Future<HHPlugin> createEncryptedHook({
  KeyRotationStrategy rotationStrategy = KeyRotationStrategy.passive,
  String secureStorageKey = 'pvcache_encryption_key',
  Uint8List? providedKey,
  bool autoResetKey = false,
  EncryptionHookController? controller,
  Future<bool> Function(Object error, String key)? rotationCallback,
}) async {
  final keyManager = EncryptionKeyManager(
    storageKey: secureStorageKey,
    providedKey: providedKey,
    autoResetKey: autoResetKey,
  );

  await keyManager.initialize();

  final hook = _EncryptionTerminalHook(
    keyManager: keyManager,
    rotationStrategy: rotationStrategy,
    controller: controller,
    rotationCallback: rotationCallback,
    id: 'pvcache_encryption_${_encryptionHookIdCounter++}',
  );

  return HHPlugin(terminalSerializationHooks: [hook]);
}

/// Controller for manual key rotation (passive mode).
class EncryptionHookController {
  final EncryptionKeyManager keyManager;

  EncryptionHookController(this.keyManager);

  Future<void> rotateKey() async {
    await keyManager.rotateKey();
  }
}

/// Manages encryption keys with secure storage.
class EncryptionKeyManager {
  final String storageKey;
  final Uint8List? providedKey;
  final bool autoResetKey;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Uint8List? _cachedKey;

  EncryptionKeyManager({
    required this.storageKey,
    this.providedKey,
    this.autoResetKey = false,
  });

  Future<void> initialize() async {
    if (autoResetKey) {
      await rotateKey();
      return;
    }

    if (providedKey != null) {
      _cachedKey = providedKey;
      await _storeKey(_cachedKey!);
      return;
    }

    final stored = await _loadKey();
    if (stored != null) {
      _cachedKey = stored;
      return;
    }

    // Auto-generate if no key exists
    await rotateKey();
  }

  Future<Uint8List> getKey() async {
    if (_cachedKey == null) {
      await initialize();
    }
    return _cachedKey!;
  }

  Future<void> rotateKey() async {
    _cachedKey = _generateKey();
    await _storeKey(_cachedKey!);
  }

  Uint8List _generateKey() {
    final random = FortunaRandom();
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = DateTime.now().microsecondsSinceEpoch % 256;
    }
    random.seed(KeyParameter(seed));
    return random.nextBytes(32);
  }

  Future<void> _storeKey(Uint8List key) async {
    await _storage.write(key: storageKey, value: base64Encode(key));
  }

  Future<Uint8List?> _loadKey() async {
    final stored = await _storage.read(key: storageKey);
    if (stored == null) return null;
    return base64Decode(stored);
  }
}

class _EncryptionTerminalHook extends TerminalSerializationHook {
  final EncryptionKeyManager keyManager;
  final KeyRotationStrategy rotationStrategy;
  final EncryptionHookController? controller;
  final Future<bool> Function(Object error, String key)? rotationCallback;
  final String id;

  _EncryptionTerminalHook({
    required this.keyManager,
    required this.rotationStrategy,
    required this.controller,
    required this.rotationCallback,
    required this.id,
  });

  @override
  Future<String> serialize(String value, HHCtxI ctx) async {
    final key = await keyManager.getKey();
    final encrypted = _encrypt(value, key);
    return base64Encode(encrypted);
  }

  @override
  Future<String> deserialize(String value, HHCtxI ctx) async {
    try {
      final key = await keyManager.getKey();
      final encrypted = base64Decode(value);
      return _decrypt(encrypted, key);
    } catch (e) {
      // Decryption failed - handle based on rotation strategy
      switch (rotationStrategy) {
        case KeyRotationStrategy.passive:
          rethrow;

        case KeyRotationStrategy.active:
          await keyManager.rotateKey();
          return ''; // Return empty on failure

        case KeyRotationStrategy.reactive:
          final shouldRotate = rotationCallback != null
              ? await rotationCallback!(e, ctx.payload.key ?? '')
              : false;
          if (shouldRotate) {
            await keyManager.rotateKey();
          }
          return '';
      }
    }
  }

  Uint8List _encrypt(String plaintext, Uint8List key) {
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      iv[i] = DateTime.now().microsecondsSinceEpoch % 256;
    }

    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(key), iv),
      null,
    );
    cipher.init(true, params);

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final encrypted = cipher.process(input);

    // Prepend IV to encrypted data
    final result = Uint8List(iv.length + encrypted.length);
    result.setRange(0, iv.length, iv);
    result.setRange(iv.length, result.length, encrypted);
    return result;
  }

  String _decrypt(Uint8List ciphertext, Uint8List key) {
    // Extract IV from first 16 bytes
    final iv = ciphertext.sublist(0, 16);
    final encrypted = ciphertext.sublist(16);

    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(key), iv),
      null,
    );
    cipher.init(false, params);

    final decrypted = cipher.process(encrypted);
    return utf8.decode(decrypted);
  }
}
