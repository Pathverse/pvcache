# PVCache

**Encrypted caching for Flutter** - Built on HiveHook with AES-256 encryption and smart key rotation.

## Features

- 🔐 **AES-256 Encryption** - Automatic encrypt/decrypt with secure key storage
- 🔄 **Smart Key Rotation** - Three strategies: manual, automatic, or callback-based
- ⚡ **Fast & Lightweight** - Built on HiveHook's high-performance cache
- 🌐 **Cross-Platform** - Works on Web, iOS, Android, Desktop
- 🎯 **Simple API** - Minimal setup, maximum security

## Installation

```yaml
dependencies:
  pvcache: ^1.0.0
  hivehook: ^0.1.3
```

## Quick Start

```dart
import 'package:pvcache/pvcache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup encrypted cache
  final plugin = await createEncryptedHook(
    rotationStrategy: KeyRotationStrategy.active,
  );
  
  PVCache.registerConfig(env: 'myapp', plugins: [plugin]);
  await HHiveCore.initialize();
  
  runApp(MyApp());
}

// Use anywhere in your app
final cache = PVCache.getCache('myapp');
await cache.put('token', 'secret_jwt_token_here');
final token = await cache.get('token'); // Automatically decrypted
```

That's it! Your data is now encrypted at rest with AES-256.

## Key Rotation

PVCache handles corrupted or invalid encryption keys gracefully:

**Automatic (Recommended)**
```dart
createEncryptedHook(rotationStrategy: KeyRotationStrategy.active)
// Auto-rotates on decryption failure
```

**Manual Control**
```dart
final controller = EncryptionHookController(keyManager);
await controller.rotateKey(); // Rotate when you decide
```

**Custom Logic**
```dart
createEncryptedHook(
  rotationStrategy: KeyRotationStrategy.reactive,
  rotationCallback: (error, key) async {
    logToAnalytics(error);
    return shouldRotate; // You decide
  },
)
```

## Advanced Usage

**Bring Your Own Key**
```dart
final myKey = Uint8List(32); // Your 256-bit key
createEncryptedHook(providedKey: myKey);
```

**Multiple Encrypted Caches**
```dart
PVCache.setDefaultPlugins([await createEncryptedHook()]);

PVCache.registerConfig(env: 'user_data');
PVCache.registerConfig(env: 'settings');
await HHiveCore.initialize();

// Both are encrypted
PVCache.getCache('user_data');
PVCache.getCache('settings');
```

**Ephemeral Cache** (new key each launch)
```dart
createEncryptedHook(autoResetKey: true);
```

## How It Works

PVCache extends [HiveHook](https://pub.dev/packages/hivehook) with encryption:
- Data is encrypted with AES-256-CBC before storage
- Keys are stored securely via Flutter Secure Storage
- Decryption happens automatically on read
- Invalid keys trigger your chosen rotation strategy

## Try the Demo

```bash
cd example
flutter run -d chrome
```

The demo app lets you test all three rotation strategies and see encryption in action.

## License

MIT

