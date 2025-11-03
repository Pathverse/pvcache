# Active Context: PVCache

## Current Work Focus
**Status**: Selective encryption implementation complete
**Date**: November 3, 2025

## Recent Changes

### Selective Encryption Feature (Just Completed)

**1. Utility Infrastructure**
- Created `lib/utils/nested.dart` for dot notation path handling
  - `getNestedValue(data, 'user.name')` - Navigate nested structures
  - `setNestedValue(data, 'user.age', 30)` - Set nested values
  - `hasNestedPath(data, 'path')` - Check path existence
  - `deleteNestedValue(data, 'path')` - Delete at path
  - Supports maps, lists, array indices (`'tokens.0.value'`)

- Created `lib/utils/encrypt.dart` for shared encryption utilities
  - `AESCipher` class - Extracted from encryption.dart
  - `getOrCreateEncryptionKey(keyName)` - Key management
  - `generateNonce()` - Random nonce generation
  - `encryptStringWithNonce(data, nonce)` - Nonce-based encryption
  - Shared by both full and selective encryption hooks

**2. Selective Encryption Hook**
- Created `lib/hooks/selective_encryption.dart`
  - Encrypts only specified fields via `metadata: {'secure': ['password', 'profile.ssn']}`
  - Uses dot notation for nested paths
  - Each field gets unique nonce stored in metadata
  - Non-encrypted fields remain readable
  - 11 tests passing

**3. Security Fix**
- Removed `_encryption_key_name` from metadata storage
  - Was potential hijacking vulnerability
  - Key name now fixed by hook instance only
  - No way to manipulate which key is used via metadata

**4. Example Integration**
- Updated `example/cache_manager.dart` with three cache types:
  - `_cache` - Regular (TTL only)
  - `_secureCache` - Full encryption (TTL + encryption)
  - `_selectiveCache` - Selective encryption (TTL + selective encryption)
- Added methods: `setSelective()`, `getSelective()`, `existsSelective()`, etc.
- Added Examples 12-16 to `example/main.dart`
- Updated `example/README.md` with selective encryption documentation

**5. Refactored encryption.dart**
- Now imports from `lib/utils/encrypt.dart`
- Uses shared `AESCipher` class instead of private `_AesEncryptor`
- Uses shared `getOrCreateEncryptionKey()` function
- Cleaner, DRY code

## Test Status

**Total: 84 tests passing** ✅
- 49 original tests (in-memory + sembast)
- 8 TTL tests
- 6 LRU tests
- 10 encryption tests (full encryption)
- 11 selective encryption tests

Expected warnings on "wrong key" tests (security working correctly).
1. **Dual Database Architecture**: Refactored PVBridge to support separate persistent and in-memory sembast databases
   - Removed redundant `_inMemoryEntries` and `_inMemoryMetadata` maps from PVCache
   - Now uses sembast's native `databaseFactoryMemory` for in-memory storage
   - Both storage types now benefit from sembast's indexing and query capabilities

2. **EventFlow Fix**: Corrected metadata loading order
   - Metadata now loads BEFORE hooks run in `metaRead` stage
   - Fixed immutable map issue by creating mutable copy: `Map<String, dynamic>.from(metaData)`
   - This resolved the "read only" error when hooks tried to modify `ctx.runtimeMeta`

3. **Hook Queue Implementation**: Complete EventFlow pipeline working
   - All 7 stages execute in correct order with automatic operations
   - Storage operations injected at appropriate stages
   - BreakHook exception handling implemented

### Template Hooks Created
1. **TTL Hook (`lib/hooks/ttl.dart`)** ✅
   - `createTTLSetHook()`: Reads `metadata: {'ttl': seconds}` and stores `_ttl_timestamp`
   - `createTTLCheckHook()`: Checks expiration in `metaRead` stage, throws BreakHook if expired
   - Auto-deletes expired entries
   - 8 tests passing

2. **LRU Hook (`lib/hooks/lru.dart`)** ✅
   - `createLRUEvictHook(max)`: Sets `_lru_count` and evicts oldest entry when max reached
   - `createLRUTrackAccessHook()`: Updates access count on get operations
   - Uses global counter stored in `_lru_global_counter` reserved key
   - 6 tests passing

3. **Encryption Hook (`lib/hooks/encryption.dart`)** ✅
   - `createEncryptionEncryptHook()`: Encrypts entire value before storage
   - `createEncryptionDecryptHook()`: Decrypts value after retrieval
   - Uses AES-256-CTR with deterministic IV
   - Auto-generates encryption key, stores in flutter_secure_storage
   - 10 tests passing

4. **Selective Encryption Hook (`lib/hooks/selective_encryption.dart`)** ✅
   - `createSelectiveEncryptionEncryptHook()`: Encrypts only specified fields
   - `createSelectiveEncryptionDecryptHook()`: Decrypts encrypted fields
   - Uses `metadata: {'secure': ['field1', 'nested.field2']}`
   - Each field gets unique nonce (stored in metadata)
   - Dot notation for nested paths: `'profile.ssn'`, `'tokens.0.value'`
   - 11 tests passing

### Example Created
Multi-file example in `example/` directory demonstrating all features:
- `main.dart`: 16 examples (6 TTL, 5 full encryption, 5 selective encryption)
- `cache_manager.dart`: Three cache types (regular, secure, selective)
- `models/user.dart`: Example model
- `services/user_service.dart`: Service layer with caching
- `README.md`: Complete documentation with all three cache types

**Verified Output:**
- All 16 examples run successfully
- Regular cache: TTL working correctly
- Secure cache: Full encryption/decryption working
- Selective cache: Field-level encryption working with dot notation paths

## Core Architecture (Finalized)

### EventFlow Execution Order
```
1. preProcess         → Run hooks
2. metaRead           → READ metadata → Run hooks (TTL check here)
3. metaUpdatePriorEntry → Run hooks (TTL set, LRU evict here)
4a. storageRead       → Run hooks → READ entry (GET/EXISTS)
4b. storageUpdate     → Run hooks → WRITE entry (PUT)
4c. storageUpdate     → Run hooks → DELETE entry (DELETE)
5. metaUpdatePostEntry → Run hooks → WRITE metadata
6. postProcess        → Run hooks
```

### Key Classes

**PVCache**
- No longer has `_inMemoryEntries` or `_inMemoryMetadata` maps
- No longer has `inMemoryCacheSize` parameter
- Hook ordering by EventFlow index, then priority

**PVBridge**
- `_persistentDatabase` and `_inMemoryDatabase` fields
- `getDatabaseForType(StorageType)` routes to correct database
- `getStore(String env, StorageType type)` maintains separate store caches
- Test mode uses `databaseFactoryMemory` for both databases

**PVCtx**
- `runtimeMeta` is mutable copy from sembast (fixes immutable map issue)
- `queue()` executes all EventFlow stages with automatic operations
- BreakHook exception for early exit

**PVCtxStorageProxy**
- Routes to correct database based on StorageType
- Both inMemory and stdSembast use sembast (no more plain maps)

## Important Patterns

### Reserved Keys Pattern
Keys starting with `_` are reserved for system use:
- `_ttl_timestamp`: Expiration timestamp (milliseconds since epoch)
- `_lru_global_counter`: Global access counter for LRU
- `_lru_count`: Per-entry access count
- `_encrypted`: Boolean flag indicating full encryption
- `_selective_encrypted`: Boolean flag indicating selective encryption
- `_encryption_nonces`: Map of field paths to nonces (for selective encryption)
- Future: User should not be able to create entries with `_` prefix

### Hook Creation Pattern
```dart
PVCacheHook createMyHook({int priority = 0}) {
  return PVCacheHook(
    eventString: 'my_hook',
    eventFlow: EventFlow.metaRead,  // Choose appropriate stage
    priority: priority,
    actionTypes: [ActionType.get],
    hookFunction: (ctx) async {
      // Modify ctx.runtimeMeta (it's mutable)
      ctx.runtimeMeta['my_field'] = value;
      
      // Break early if needed
      if (shouldBreak) {
        throw BreakHook('Reason', BreakReturnType.none);
      }
    },
  );
}
```

### Metadata Usage Pattern
```dart
// Set metadata on put
await cache.put('key', 'value', metadata: {'ttl': 3600, 'custom': 'data'});

// Metadata is automatically read in metaRead stage
// Hooks can access via ctx.runtimeMeta
// Metadata is automatically written in metaUpdatePostEntry stage
```

## Test Status

**Total: 63 tests passing** ✅
- 49 original tests (in-memory + sembast)
- 8 TTL tests
- 6 LRU tests

All tests use `PVBridge.testMode = true` for in-memory testing.

## Next Steps

### Immediate
1. ~~Add validation to prevent users from creating keys starting with `_`~~
2. ~~Implement encryption hooks~~ ✅ Done
3. ~~Implement selective encryption~~ ✅ Done

### Future Enhancements
4. More template hooks:
   - Cache warming hook
   - Compression hook
   - Statistics/monitoring hook
   - Size limit hook

5. Package polish:
   - Update main README with encryption examples
   - Export all hooks in `lib/pvcache.dart`
   - API documentation
   - Publish to pub.dev

## Key Decisions Made

### 1. Sembast for Everything
- Decision: Use sembast for both in-memory and persistent storage
- Rationale: Eliminates redundancy, unified API, better query capabilities
- Impact: Simpler architecture, no manual cache management

### 2. Metadata Loads First
- Decision: Load metadata before running metaRead hooks
- Rationale: Hooks need access to metadata (TTL, LRU counts, etc.)
- Impact: Fixed "late initialization" and "read only" errors

### 3. Mutable Runtime Metadata
- Decision: Create mutable copy of metadata from sembast
- Rationale: Hooks need to modify metadata
- Impact: `Map<String, dynamic>.from(metaData)` in queue()

### 4. Reserved Key Convention
- Decision: Keys starting with `_` are system-reserved
- Rationale: Avoid collisions between user data and system metadata
- Impact: Need to add validation, document convention

### 5. Priority-Based Hook Ordering
- Decision: Simple int priority within each EventFlow stage
- Rationale: Simpler than string-based dependencies, more flexible
- Impact: Easy to reason about execution order

## Notes and Learnings

### Encryption Implementation
- AES-256-CTR chosen for no padding requirement (handles any length)
- Deterministic IV for full encryption (content-based hashing)
- Random nonce per field for selective encryption
- Keys stored in flutter_secure_storage (Keychain/Keystore)
- Base64 encoding for safe storage
- Decrypt hook runs in `postProcess` stage (after metadata loads)

### Selective Encryption Insights
- Dot notation enables flexible path specification
- Nonce-based IV prevents IV collision across fields
- Metadata stores nonces, not key names (security)
- Works seamlessly with nested maps and arrays
- Non-encrypted fields remain queryable/debuggable

### Security Patterns
- Never store key name in entry metadata (hijacking risk)
- Key name fixed by hook configuration only
- Unique nonce per field per entry
- Failed decryption logs warning but doesn't crash
- Wrong key produces corrupted data (expected behavior)

### Sembast Behavior
- Returns immutable maps for data integrity
- Must create mutable copies to modify
- `find()` with `Finder()` gets all records as snapshots
- Reserved keys don't conflict with user keys (different namespace)

### Hook System Insights
- Hooks at same EventFlow/priority execute in registration order
- BreakHook stops execution and returns immediately
- Hooks can read/write to any storage via ctx.entry/ctx.meta
- Negative priority runs earlier in the stage

### Testing Strategies
- `PVBridge.testMode = true` enables memory-only databases
- `TestWidgetsFlutterBinding.ensureInitialized()` needed for Flutter tests
- `Future.delayed()` useful for testing TTL expiration

### Current Terminal State
- Last command: `flutter test`
- Exit code: 0 (all 63 tests passing)
- All compilation errors resolved
