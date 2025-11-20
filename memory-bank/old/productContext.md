# Product Context: PVCache

## Problem Statement
Existing Flutter caching solutions often lack:
- Flexible plugin architectures for custom caching policies
- Clear separation between data and metadata
- Multi-backend storage options
- Easy extensibility for different caching strategies (TTL, LRU, etc.)

## Solution
PVCache provides a hook-based caching system where caching behavior is controlled through plugins that intercept cache operations at specific points in the execution pipeline.

## How It Works

### User Perspective
1. **Initialize Cache**: Create a `PVCache` instance with configuration (environment, storage types, metadata)
2. **Perform Operations**: Use standard cache methods (`put`, `get`, `delete`, `clear`, `exists`)
3. **Add Plugins**: Register hooks that implement caching policies (TTL, LRU, custom logic)
4. **Automatic Processing**: Hooks execute automatically in the correct order during operations

### Key Concepts

#### Storage Backends
- **In-Memory**: Fast, ephemeral storage for frequently accessed data
- **Sembast**: Persistent NoSQL storage for mobile/desktop/web
- **Secure Storage**: Encrypted storage for sensitive data

#### Hook System
Hooks intercept operations at different **event flows**:
1. `preProcess` - Before any processing
2. `metaRead` - Read metadata
3. `metaUpdatePriorEntry` - Update metadata before storage operation
4. `storageRead` - Read from storage
5. `storageUpdate` - Update storage
6. `metaUpdatePostEntry` - Update metadata after storage operation
7. `postProcess` - After all processing

#### Context Object (`PVCtx`)
Carries operation state through the hook pipeline:
- Original request data (key, value, metadata)
- Resolved runtime data
- Shared state between hooks
- Action type information

## Use Cases

### Example 1: TTL Plugin
Hook checks metadata timestamps during `get` operations to determine if entry has expired.

### Example 2: LRU Plugin
Hook updates access timestamps in metadata and evicts least recently used entries when cache size limit is reached.

### Example 3: Macro Get (Pattern-Based Auto-Fetch)
Configure patterns that automatically fetch and cache data on cache miss:
```dart
final cache = PVCache(
  env: 'prod',
  hooks: [createTTLHook()],
  macroGetHandlers: {
    RegExp(r'^user:\d+$'): (key) async {
      final userId = key.split(':')[1];
      return await api.fetchUser(userId);
    },
  },
  macroGetDefaultMetadata: {'ttl': 3600},
);

// Automatically fetches from API if not cached
final user = await cache.get('user:123');
```

Works seamlessly with:
- TTL: Auto-refetches after expiration
- LRU: Auto-refetches after eviction  
- Encryption: Fetched data can be encrypted
- Any hook combination

### Example 4: Cache Warming
Hook pre-loads frequently accessed data during `preProcess` events.

## Design Goals
- **Flexibility**: Support any caching policy through hooks
- **Performance**: In-memory layer for fast access
- **Persistence**: Sembast for reliable storage
- **Security**: Secure storage option for sensitive data
- **Composability**: Multiple hooks work together
- **Clarity**: Clear execution order and event flow
