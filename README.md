# PVCache

A flexible caching library for Flutter with hook-based extensibility. Add TTL expiration, LRU eviction, encryption, and custom behaviors through a simple plugin system.

## Features

- **Hook System**: Extend cache behavior with reusable plugins
- **Built-in Hooks**: TTL expiration, LRU eviction, full encryption, selective field encryption
- **Multiple Storage**: Persistent (sembast), in-memory, or secure storage (platform keychain)
- **Environment Isolation**: Separate cache namespaces (dev, prod, test)
- **Comprehensive API**: Fully documented with examples

## Installation

```yaml
dependencies:
  pvcache: ^0.0.1
```

## Quick Start

### Basic Cache

```dart
import 'package:pvcache/pvcache.dart';

// Create a simple cache
final cache = PVCache(
  env: 'dev',
  hooks: [],
  defaultMetadata: {},
);

// Store and retrieve
await cache.put('user:123', {'name': 'Alice', 'age': 30});
final user = await cache.get('user:123');
print(user); // {name: Alice, age: 30}
```

### Cache with TTL

```dart
import 'package:pvcache/hooks/ttl.dart';

final cache = PVCache(
  env: 'prod',
  hooks: createTTLHooks(),
  defaultMetadata: {},
);

// Expires in 1 hour
await cache.put('session', token, metadata: {'ttl_seconds': 3600});

// After expiry, returns null
await Future.delayed(Duration(hours: 1));
final expired = await cache.get('session'); // null
```

### Encrypted Cache

```dart
import 'package:pvcache/hooks/encryption.dart';

final cache = PVCache(
  env: 'secure',
  hooks: [
    ...createEncryptionHooks(
      encryptionKey: 'my-secure-key-123',
    ),
  ],
  defaultMetadata: {},
);

// Automatically encrypted on write, decrypted on read
await cache.put('password', 'secret123');
final password = await cache.get('password'); // 'secret123'
```

### Selective Field Encryption

```dart
import 'package:pvcache/hooks/selective_encryption.dart';

final cache = PVCache(
  env: 'mixed',
  hooks: [
    ...createSelectiveEncryptionHooks(
      encryptionKey: 'my-key-456',
    ),
  ],
  defaultMetadata: {},
);

// Encrypt only specific fields
await cache.put('user', {
  'username': 'alice',        // plaintext
  'email': 'alice@example.com', // plaintext
  'password': 'secret123',    // encrypted
  'ssn': '123-45-6789',       // encrypted
}, metadata: {
  'secure': ['password', 'ssn'],
});
```

### Global Access

```dart
import 'package:pvcache/pvcache.dart';

// Use PVCacheTop for global access
await PVCacheTop.put('key', 'value');
final value = await PVCacheTop.get('key');
await PVCacheTop.delete('key');
```

## Available Hooks

| Hook | Purpose | Import |
|------|---------|--------|
| TTL | Auto-expire entries | `package:pvcache/hooks/ttl.dart` |
| LRU | Limit cache size | `package:pvcache/hooks/lru.dart` |
| Encryption | Encrypt entire entries | `package:pvcache/hooks/encryption.dart` |
| Selective Encryption | Encrypt specific fields | `package:pvcache/hooks/selective_encryption.dart` |

## Storage Types

- **stdSembast**: Persistent storage (survives app restarts)
- **inMemory**: Session storage (fast, lost on restart)
- **secureStorage**: Platform keychain (for encryption keys)

## API Documentation

All classes and methods are fully documented. View documentation in your IDE or generate with:

```bash
dart doc
```

Key classes:
- `PVCache` - Main cache instance
- `PVCacheHook` - Hook definition
- `PVCtx` - Operation context passed to hooks
- `PVCacheTop` - Global access point

## Examples

See the [example](example/) directory for complete working examples including:
- TTL with different expiration times
- Encrypted cache with auto-generated keys
- Selective encryption for mixed sensitivity data
- Custom hook creation

## License

See LICENSE file.
