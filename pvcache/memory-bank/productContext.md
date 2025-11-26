# Product Context

## Why PVCache Exists
PVCache extends Sembast (a NoSQL embedded database for Dart/Flutter) with advanced hook-based capabilities. While Sembast provides reliable storage, PVCache adds:
- **Hook system**: Pre/post action hooks for validation, transformation, logging, and auditing
- **Multi-environment management**: Isolated cache instances with configurable storage
- **Encryption layer**: Value and metadata encryption on top of Sembast
- **Plugin architecture**: Composable behaviors like LRU eviction and TTL expiration
- **Context-based operations**: Rich execution context for complex workflows

**Core Philosophy**: Sembast handles storage reliably; PVCache adds the event-driven capabilities you need around it.

## Problems It Solves

### 1. Environment Isolation
Applications often need separate caches for different environments or features without data bleeding between them.

**Solution**: Environment-based cache instances with configurable storage isolation (shared DB or separate files).

### 2. Platform-Specific Storage
Different platforms have different storage mechanisms (SQLite on mobile, IndexedDB on web).

**Solution**: Conditional imports route to platform-specific database factories transparently.

### 3. Sensitive Data
Cached data may contain tokens, user info, or other sensitive information.

**Solution**: Configurable encryption at value and/or metadata level using ValueType enum.

### 4. Cache Operation Hooks
Need to validate, transform, log, or audit cache operations.

**Solution**: Priority-based pre/post action hooks that can intercept any cache operation.

### 5. Testing
Need to test cache logic without persisting data.

**Solution**: Test mode with in-memory databases that can be enabled before initialization.

## How It Should Work

### Basic Usage
```dart
// Create/get cache instance for environment
final cache = PVCache.create(env: 'production');

// Store value with metadata
await cache.put(PVCtx('user_token', 'abc123', {'expires': 1234567890}));

// Retrieve value
final token = await cache.get(PVCtx('user_token', null, null));
```

### Advanced Configuration
```dart
final config = PVConfig(
  'production',
  valueStorageType: ValueType.encrypted,
  storageType: StorageType.separateFilePreferred,
  actionHooks: {
    'getValue': [
      PVActionHook(
        (ctx) async => print('Retrieved: ${ctx.key}'),
        [PVActionContext('getValue', priority: 10, isPost: true)]
      )
    ]
  }
).finalize();

final cache = PVCache.create(config: config);
```

## User Experience Goals

### Developer Experience
- **Simple by default**: Basic caching works with minimal configuration
- **Powerful when needed**: Hooks and encryption available for advanced use cases
- **Type-safe**: Strong typing with Dart's type system
- **Discoverable**: Clear API with self-documenting method names

### Runtime Behavior
- **Fast**: In-memory caching of global metadata, transaction-based writes
- **Reliable**: Proper error handling, atomic operations
- **Predictable**: Hooks execute in priority order, clear execution flow
- **Debuggable**: Context objects track operation lifecycle
