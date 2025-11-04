import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:pvcache/core/bridge.dart';

/// Shared encryption utilities for PVCache hooks.
///
/// Provides common encryption functions to avoid code duplication.

// ignore: constant_identifier_names
const String DEFAULT_ENCRYPTION_KEY_NAME = '_pvcache_encryption_key';

/// AES-256-CTR encryption/decryption utilities.
class AESCipher {
  final Uint8List _key;
  final String seed;

  AESCipher(this.seed) : _key = _deriveKey(seed);

  /// Derive a 32-byte key from seed using SHA-256.
  static Uint8List _deriveKey(String seed) {
    final digest = SHA256Digest();
    final seedBytes = utf8.encode(seed);
    return digest.process(Uint8List.fromList(seedBytes));
  }

  /// Encrypt data using AES-256-CTR with deterministic IV.
  String encryptString(String data) {
    final plainBytes = utf8.encode(data);

    // Generate deterministic IV based on content + seed
    final iv = _generateDeterministicIV(data);

    // Handle empty string case
    if (plainBytes.isEmpty) {
      return base64.encode(iv);
    }

    // Setup AES cipher in CTR mode (handles any length, no padding needed)
    final cipher = CTRStreamCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(_key), iv);

    cipher.init(true, params); // true = encrypt

    final encryptedBytes = cipher.process(Uint8List.fromList(plainBytes));

    // Combine IV + encrypted data
    final result = Uint8List(iv.length + encryptedBytes.length);
    result.setRange(0, iv.length, iv);
    result.setRange(iv.length, result.length, encryptedBytes);

    return base64.encode(result);
  }

  /// Decrypt data using AES-256-CTR.
  String decryptString(String encryptedText) {
    final encryptedData = base64.decode(encryptedText);

    // Validate minimum length (at least IV = 16 bytes)
    if (encryptedData.length < 16) {
      throw ArgumentError('Invalid encrypted data: too short');
    }

    // Extract IV and encrypted bytes
    final iv = encryptedData.sublist(0, 16);
    final encryptedBytes = encryptedData.sublist(16);

    // Handle empty string case (no encrypted data, just IV)
    if (encryptedBytes.isEmpty) {
      return '';
    }

    // Setup AES cipher in CTR mode
    final cipher = CTRStreamCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(_key), iv);

    cipher.init(false, params); // false = decrypt

    final decryptedBytes = cipher.process(Uint8List.fromList(encryptedBytes));

    try {
      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw ArgumentError('Failed to decrypt: invalid key or corrupted data');
    }
  }

  /// Generate deterministic IV based on content + seed.
  ///
  /// Uses length-prefixed encoding to avoid collisions.
  Uint8List _generateDeterministicIV(String data) {
    final seedBytes = utf8.encode(seed);
    final dataBytes = utf8.encode(data);

    // Create length-prefixed buffer to avoid collisions
    // Format: [seed_len_high][seed_len_low][seed_bytes][data_len_high][data_len_low][data_bytes]
    final buffer = <int>[];

    // Add seed length (2 bytes, big-endian)
    buffer.add(seedBytes.length >> 8);
    buffer.add(seedBytes.length & 0xFF);
    buffer.addAll(seedBytes);

    // Add data length (2 bytes, big-endian)
    buffer.add(dataBytes.length >> 8);
    buffer.add(dataBytes.length & 0xFF);
    buffer.addAll(dataBytes);

    // Generate deterministic hash
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(buffer));

    // Take first 16 bytes as IV (AES block size)
    return Uint8List.fromList(hash.sublist(0, 16));
  }

  /// Encrypt with random nonce (for selective encryption).
  String encryptStringWithNonce(String data, String nonce) {
    final plainBytes = utf8.encode(data);

    // Generate IV from nonce
    final iv = _generateNonceIV(nonce);

    // Handle empty string case
    if (plainBytes.isEmpty) {
      return base64.encode(iv);
    }

    // Setup AES cipher in CTR mode
    final cipher = CTRStreamCipher(AESEngine());
    final params = ParametersWithIV(KeyParameter(_key), iv);

    cipher.init(true, params); // true = encrypt

    final encryptedBytes = cipher.process(Uint8List.fromList(plainBytes));

    // Combine IV + encrypted data
    final result = Uint8List(iv.length + encryptedBytes.length);
    result.setRange(0, iv.length, iv);
    result.setRange(iv.length, result.length, encryptedBytes);

    return base64.encode(result);
  }

  /// Generate IV from nonce.
  Uint8List _generateNonceIV(String nonce) {
    final nonceBytes = utf8.encode(nonce);
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(nonceBytes));
    return Uint8List.fromList(hash.sublist(0, 16));
  }
}

/// Get or generate encryption key from secure storage.
///
/// Keys stored in flutter_secure_storage.
Future<String> getOrCreateEncryptionKey(String keyName) async {
  // Try to read existing key
  final existingKey = await PVBridge.secureStorage.read(key: keyName);
  if (existingKey != null && existingKey.isNotEmpty) {
    return existingKey;
  }

  // Generate new key (32 characters for AES-256 compatibility)
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = timestamp.toString() + DateTime.now().microsecond.toString();
  final hash = sha256.convert(utf8.encode(random)).toString();
  final newKey = hash.substring(0, 32);

  // Store in secure storage
  await PVBridge.secureStorage.write(key: keyName, value: newKey);

  return newKey;
}

/// Generate random nonce for one-time use.
///
/// Used for selective encryption where each field needs unique nonce.
String generateNonce() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final micro = DateTime.now().microsecond;
  final random = '$timestamp$micro';
  return sha256.convert(utf8.encode(random)).toString().substring(0, 16);
}
