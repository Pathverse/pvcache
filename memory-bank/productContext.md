# Product Context: PVCache v2

## Problem Statement

### Original Problem (v1)
Existing Flutter caching solutions lack:
- Flexible plugin architectures for custom caching policies
- Clear separation between data and metadata
- Multi-backend storage options
- Easy extensibility for different caching strategies

### New Problems Discovered (v1 → v2)
During v1 development, we discovered critical issues:
1. **Race Conditions**: Concurrent operations (like LRU counter updates) cause incorrect state
2. **Transaction Support**: No way to ensure atomic multi-step operations
3. **Manual DB Access**: Hooks bypass abstractions, leading to fragile code
4. **Exception-Based Flow**: Using exceptions for control flow is unclear
5. **No Dependency Management**: Hooks can't declare what they need/produce

## Solution Evolution

### v1 Solution (pvcache2 - Working)
Hook-based system with:
- Direct hook execution through EventFlow stages
- Context object passing through hooks
- Separate entry and metadata storage
- Pattern-based macro get (auto-fetch)

**Result**: 136 passing tests, fully functional, but with race conditions and transaction issues.

### v2 Solution (pvcache - In Progress)
Enhanced architecture with:
- **Two-tier hooks**: Stage hooks (framework) + Action hooks (user)
- **Transaction support**: Atomic operations across multiple stages
- **Dependency system**: Hooks declare produces/consumes
- **Rich context**: Separate runtime/metadata/temp with explicit flow control
- **Compile-time optimization**: Build execution plans once, run efficiently

## How It Works (v2)

### User Perspective

#### 1. Create Cache with Factory
```dart
final factory = PVFactory.fromDefault();

// Configure sequences
factory.sequenceConfig.get = [
  'metadata_get',
  'metadata_parse',
  'value_get',
  'value_parse',
];

// Add user hooks
factory.actionHooks['metadata_parse'] = [
  createTTLCheckHook(),
  createLRUUpdateHook(),
];

// Build cache
final cache = factory.createCache();
```

#### 2. Use Cache Normally
```dart
// Put with TTL
await cache.put('user:123', userData, metadata: {'ttl': 3600});

// Get (auto-checks TTL, updates LRU, decrypts)
final user = await cache.get('user:123');

// Delete
await cache.delete('user:123');
```

#### 3. Hooks Run Automatically
Users don't see the complexity:
- TTL expiration checked automatically
- LRU counters updated atomically
- Encryption/decryption transparent
- All operations transaction-safe

### Under the Hood

#### Compilation Phase (Once)
```
Factory → Analyze sequences
       → Order hooks by dependencies
       → Build execution plan
       → Cache plan in PVCache
```

#### Execution Phase (Per Request)
```
User calls cache.get()
  ↓
Create context with key
  ↓
Execute compiled plan:
  ├─ Stage: metadata_get (read DB)
  ├─ Stage: metadata_parse (TTL check, LRU update)
  ├─ Stage: value_get (read DB)
  └─ Stage: value_parse (decrypt)
  ↓
Return value from context
```

## Use Cases

### Use Case 1: TTL Cache
**Problem**: Data should expire after a time period.

**Solution**:
```dart
// User adds TTL hook
factory.actionHooks['metadata_prepare'] = [createTTLSetHook()];
factory.actionHooks['metadata_parse'] = [createTTLCheckHook()];

// Usage
await cache.put('session', token, metadata: {'ttl': 3600});
await cache.get('session');  // Returns null after 1 hour
```

**How It Works**:
1. PUT: TTL set hook converts `ttl: 3600` to `_ttl_timestamp: <future_time>`
2. GET: TTL check hook compares current time to `_ttl_timestamp`
3. If expired: Sets `ctx.nextStep = break` and returns null

### Use Case 2: LRU Cache with Correct Counting
**Problem**: Limit cache size, evict least recently used, avoid race conditions.

**Solution**: Transaction-wrapped counter updates
```dart
factory.actionHooks['metadata_prepare'] = [
  createLRUUpdateHook(max: 100),
];

// Concurrent requests:
Request A and B both update counter
→ Both in separate transactions
→ Request A: counter 5 → 6
→ Request B: counter 6 → 7 (sees A's committed value)
→ No race condition! ✅
```

### Use Case 3: Encrypted Cache
**Problem**: Sensitive data should be encrypted at rest.

**Solution**:
```dart
factory.actionHooks['value_prepare'] = [createEncryptionHook(key)];
factory.actionHooks['value_parse'] = [createDecryptionHook(key)];

// Usage (encryption is transparent)
await cache.put('password', 'secret123');
// Stored encrypted in DB
final pwd = await cache.get('password');
// Returns 'secret123' (decrypted)
```

### Use Case 4: Selective Encryption
**Problem**: Only some fields should be encrypted.

**Solution**:
```dart
await cache.put('user', {
  'name': 'Alice',      // Plain text
  'email': 'a@x.com',   // Plain text
  'ssn': '123-45-6789', // Encrypted
}, metadata: {
  'secure': ['ssn'],    // Mark field for encryption
});
```

### Use Case 5: Complex Hook Composition
**Problem**: Need TTL + LRU + Encryption together.

**Solution**: Just add all hooks - framework handles ordering:
```dart
factory.actionHooks = {
  'metadata_prepare': [ttlSetHook, lruUpdateHook],
  'metadata_parse': [ttlCheckHook],
  'value_prepare': [encryptionHook],
  'value_parse': [decryptionHook],
};

// All hooks work together:
// 1. TTL set on put
// 2. LRU counter updated (atomic)
// 3. Value encrypted
// 4. On get: TTL checked → value decrypted → LRU updated
```

## Design Goals

### Primary Goals
1. **Correctness**: No race conditions, atomic operations
2. **Flexibility**: Support any caching policy through hooks
3. **Performance**: Compile-time optimization, efficient execution
4. **Clarity**: Clear separation of framework vs user code
5. **Safety**: Transaction support, proper error handling

### Secondary Goals
6. **Composability**: Multiple hooks work together seamlessly
7. **Extensibility**: Easy to add new hook types
8. **Testability**: Each component testable in isolation
9. **Documentation**: Self-documenting through produces/consumes

## User Benefits

### For Application Developers
- **Easy to use**: Simple API, hooks run automatically
- **Reliable**: No race conditions, transaction-safe
- **Flexible**: Add/remove hooks as needed
- **Predictable**: Clear execution order

### For Hook Developers
- **Clear contract**: Produces/consumes declarations
- **No DB knowledge**: Modify context, framework handles DB
- **Automatic ordering**: Declare dependencies, framework orders
- **Transaction access**: Multi-step operations are atomic

### For Framework Maintainers
- **Separation of concerns**: Stage hooks vs action hooks
- **Testable**: Each component isolated
- **Extensible**: Easy to add new stage types
- **Optimizable**: Compile-time analysis enables optimizations

## Migration Path (v1 → v2)

### For Users
1. Replace `PVCache(hooks: [...])` with factory pattern
2. Update hook attachments to use `hookOn: 'stage_name'`
3. Replace `throw BreakHook()` with `ctx.nextStep = break_`
4. Update context access: `ctx.entryValue` → `ctx.runtime['value']`

### For Hook Developers
1. Add `produces` and `consumes` lists
2. Change from `EventFlow` enum to stage names
3. Remove direct DB access (use stage hooks instead)
4. Update to use new context maps

## Success Metrics

### Correctness
- ✅ No race conditions (verified by concurrent tests)
- ✅ Atomic operations (transaction tests)
- ✅ Consistent state (integration tests)

### Performance
- Target: <10% slower than v1
- Compile time: <100ms for typical configs
- Execution time: Baseline from v1 + transaction overhead

### Usability
- Clear error messages
- Self-documenting through dependencies
- Minimal boilerplate

## References
- **Architecture**: `memory-bank/arch/` folder
- **Old implementation**: `../pvcache2/` folder (reference)
- **Examples**: Will be ported from v1 after core implementation
