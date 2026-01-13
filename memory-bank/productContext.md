# Product Context: PVCache on HiveHook

## Why This Project Exists

### The Problem
Flutter developers need a robust caching solution that:
- Works consistently across all platforms (web, mobile, desktop)
- Provides encryption without complexity
- Supports TTL and LRU eviction policies
- Allows extensibility through hooks
- Doesn't require managing multiple storage backends

### The Solution
PVCache builds on HiveHook to provide a production-ready caching layer:
- **HiveHook** handles the hook system and storage abstraction
- **PVCache** adds encryption, serialization, and practical plugins
- **Single API** for all platforms with consistent behavior

### Core Philosophy
HiveHook provides the foundation; PVCache adds the production features you need. Instead of reinventing hooks and storage, we leverage HiveHook's proven architecture and focus on encryption, key management, and specialized cache behaviors.

## Target Users
- Flutter developers building web/mobile/desktop apps
- Teams requiring encrypted local storage
- Apps with caching requirements (TTL, LRU, size limits)
- Developers who need extensible storage through hooks

## How It Works

### User Flow: Basic Cache Usage
```dart
import 'package:pvcache/pvcache.dart';  // Re-exports HiveHook + adds encryption

// Users work directly with HiveHook's HHive class
final cache = await HHive.createInstance(
  HHConfig(
    'user_cache',
    usesMeta: true,  // Required for plugins
    plugins: [
      createEncryptedHook(  // Only new addition from PVCache
        autoGenerateKey: true,
        secureStorageTargetKey: 'my_app_cache_key',
      ),
      createTTLPlugin(defaultTTLSeconds: 60),  // From HiveHook
    ],
  ),
);

// Use HiveHook's API directly
await cache.put('user', userData);
final data = await cache.get('user');
```

**Alternative: PVCache convenience wrapper**
```dart
// PVCache provides optional simplified config
final cache = await PVCache.create(
  name: 'user_cache',
  encrypted: true,  // Automatically adds createEncryptedHook
  ttlSeconds: 60,   // Automatically adds createTTLPlugin
);

await cache.put('user', userData);  // Delegates to HHive
```

### User Flow: Encryption Key Reset
```dart
// Reset all encrypted data with new key
final config = PVConfig(
  'secure_cache',
  plugins: [
    EncryptedHook(
      autoResetKey: true, // Clears storage and generates new key
      autoGenerateKey: true,
    ),
  ],
).finalize();
```

### User Flow: Provided Key
```dart
// Use your own encryption key
final myKey = Uint8List(32); // Your 256-bit AES key
final config = PVConfig(
  'custom_cache',
  plugins: [
    EncryptedHook(
      providedKey: myKey,
    ),
  ],
).finalize();
```

## Key Features

### 1. Automatic Encryption
- Transparent encrypt/decrypt via EncryptedHook
- AES encryption using PointyCastle
- Secure key storage in Flutter Secure Storage
- Optional key rotation with automatic storage clear

### 2. Flexible Key Management
- Auto-generate keys when needed
- Provide custom keys
- Auto-reset with storage clear
- Persistent storage across app launches

### 3. Production-Ready Plugins
- **TTLPlugin**: Items expire after timeout
- **LRUPlugin**: Evict least recently used
- **EncryptedHook**: Transparent encryption
- Easy to combine plugins

### 4. HiveHook Foundation
- Reliable hook system from HiveHook
- Cross-platform Hive storage
- Event-driven architecture
- Composable plugins

## User Experience Goals

### Simplicity
- Single API across all platforms
- Encryption is opt-in with simple config
- Sensible defaults for key management
- Clear error messages

### Security
- Keys never in plain text
- Stored only in Flutter Secure Storage
- Option to reset and clear all data
- AES-256 encryption standard

### Performance
- Hive's fast storage backend
- Minimal overhead from hooks
- Efficient key caching
- Lazy encryption (only when configured)

### Reliability
- Built on proven HiveHook foundation
- Consistent behavior across platforms
- Comprehensive error handling
- Well-tested encryption implementation
