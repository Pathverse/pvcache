# System Patterns: PVCache

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    PVCache                          │
│  - Configuration (env, storage types, etc.)         │
│  - Hook management (_orderedPutHooks, etc.)         │
│  - Public API (put, get, delete, clear, exists)     │
└──────────────────┬──────────────────────────────────┘
                   │ creates
                   ▼
┌─────────────────────────────────────────────────────┐
│                     PVCtx                            │
│  - Action type (put, get, delete, etc.)             │
│  - Initial data (key, value, metadata)              │
│  - Resolved runtime data                            │
│  - Shared state (runtimeData map)                   │
└──────────────────┬──────────────────────────────────┘
                   │ queues through
                   ▼
┌─────────────────────────────────────────────────────┐
│              PVCacheHook (List)                      │
│  - Event flow stage                                 │
│  - Action type filters                              │
│  - Before/after ordering                            │
│  - Hook function (processes ctx)                    │
└──────────────────┬──────────────────────────────────┘
                   │ accesses
                   ▼
┌─────────────────────────────────────────────────────┐
│                   PVBridge                           │
│  - Singleton database manager                       │
│  - Platform detection (web vs native)               │
│  - Sembast database initialization                  │
│  - FlutterSecureStorage instance                    │
└─────────────────────────────────────────────────────┘
```

## Key Technical Decisions

### 1. Hook-Based Plugin Architecture
**Decision**: Use a hook system with ordered execution rather than inheritance or direct plugin interfaces.

**Rationale**: 
- Maximum flexibility for plugin composition
- Clear execution order through event flows
- Plugins can focus on specific stages
- Easy to add/remove/reorder behaviors

**Implementation**:
- Hooks define which `EventFlow` stage they operate in
- Hooks specify priority (int, default 0) for ordering within same EventFlow
- Multiple hooks can process same stage
- Context object passed through entire pipeline

### 2. Separate Entry and Metadata Storage
**Decision**: Store cache entries and metadata separately with independent storage type configuration.

**Rationale**:
- Metadata may require different storage (e.g., secure for sensitive tracking)
- Allows metadata-only operations without loading entries
- Supports `noMetadataStoreIfEmpty` optimization
- Clear separation of concerns

### 3. Context Object Pattern
**Decision**: Use a mutable `PVCtx` object that travels through hooks.

**Rationale**:
- Shared state between hooks
- Allows hooks to modify data for subsequent hooks
- Tracks both initial and resolved values
- Provides `runtimeData` for temporary hook communication

### 4. Singleton Bridge Pattern
**Decision**: `PVBridge` singleton manages database connections.

**Rationale**:
- Single database connection shared across cache instances
- Platform-specific initialization (web vs native)
- Clean separation of storage concerns
- Easy to mock for testing

### 5. In-Memory Cache Layer
**Decision**: Optional in-memory cache with configurable size (`inMemoryCacheSize`).

**Rationale**:
- Fast access for hot data
- Reduces database calls
- Size limit prevents memory issues
- Can be disabled (size = 0) if not needed

## Component Relationships

### PVCache
- Main entry point
- Holds configuration
- Manages hooks
- Orchestrates operations through `PVCtx`

### PVCtx (Context)
- Created per operation
- Carries operation state
- Modified by hooks
- Returns final result

### PVCacheHook
- Defines intervention point (`EventFlow`)
- Filters by `ActionType`
- Orders by priority (int, default 0, lower runs first)
- Executes function with context

### PVBridge
- Singleton storage manager
- Provides database access
- Handles platform differences
- Manages secure storage

## Critical Implementation Paths

### Macro Get (Pattern-Based Auto-Fetch)
**Location**: `PVCache.get()` method (post-hook-pipeline)

**Flow**:
1. Execute full hook pipeline
2. Check if returnValue is null
3. If null, iterate through macroGetHandlers
4. For each pattern, check if key matches using `_matchesPattern()`
5. On match, call fetch function with key
6. If fetch succeeds (not null), cache data with merged metadata
7. Return fetched data

**Pattern Matching**:
- String patterns: exact match OR prefix match (`key == pattern || key.startsWith(pattern)`)
- RegExp patterns: `pattern.hasMatch(key)`
- First matching handler wins

**Integration Points**:
- Works with TTL: auto-refetches after expiration
- Works with LRU: auto-refetches after eviction
- Works with encryption: fetched data can be encrypted
- Works with any hook: runs after ALL hooks complete

**Design Rationale**:
- Initially attempted as hook but BreakHook prevented execution
- Core integration ensures it runs regardless of hook behavior
- Scales to all future hooks without special cases

### Cache Put Flow
1. Create `PVCtx` with key, value, metadata
2. Queue through `_orderedPutHooks`
3. Hooks process in order:
   - preProcess
   - metaRead (read existing metadata)
   - metaUpdatePriorEntry (e.g., update write time)
   - storageUpdate (write to storage)
   - metaUpdatePostEntry (e.g., update size tracking)
   - postProcess
4. Return from operation

### Cache Get Flow
1. Create `PVCtx` with key
2. Queue through `_orderedGetHooks`
3. Hooks process:
   - preProcess
   - metaRead (check TTL, access patterns)
   - storageRead (retrieve from storage/memory)
   - metaUpdatePostEntry (update access time for LRU)
   - postProcess
4. **Macro Get Check** (post-pipeline):
   - If returnValue is null (miss, expiration, eviction)
   - Check if key matches any macroGetHandlers pattern
   - If match found, fetch data via handler function
   - Cache fetched data with macroGetDefaultMetadata
   - Return fetched data
5. Return `ctx.entryValue` or fetched data

### Hook Ordering
- Hooks are ordered by `EventFlow` first (enum order)
- Within same flow, ordered by `priority` (lower numbers run first)
- `_orderedPutHooks`, `_orderedGetHooks`, etc. are pre-sorted lists

## Event Flow Stages

1. **preProcess**: Setup, validation, early exits
2. **metaRead**: Load metadata from storage
3. **metaUpdatePriorEntry**: Modify metadata before touching entry (e.g., check TTL)
4. **storageRead**: Load entry from storage
5. **storageUpdate**: Write entry to storage
6. **metaUpdatePostEntry**: Update metadata based on operation results
7. **postProcess**: Cleanup, logging, callbacks

## Storage Type Enum
- `inMemory`: Fast, ephemeral
- `sembast`: Persistent NoSQL
- `secureStorage`: Encrypted storage

## Action Type Enum
Defines operation types:
- `put`: Write entry
- `get`: Read entry
- `delete`: Remove entry
- `clear`: Remove all entries
- `exists`: Check if entry exists
- `iter`: (Future) Iterate entries

## Encryption Recovery Pattern

### Problem
Encryption keys can change or become invalid, making existing encrypted data unreadable. This causes:
- Silent data loss (decryption returns null)
- No distinction between cache miss and decryption failure
- No recovery mechanism

### Solution
Two-layer approach in separate files:

**`lib/hooks/encryption.dart`** (Core Encryption):
- `throwOnFailure` parameter (default `true`) on decrypt hook
- Controls whether decryption failures throw exceptions
- When `false`, silently returns `null` on failure

**`lib/hooks/encryption_recovery.dart`** (Recovery System):
- **Detection Hook**: `createEncryptionRecoveryHook()` runs AFTER decrypt (priority 10)
  - Detects failures (encrypted flag but null value)
  - Optional callback to handle failures
  - Optional auto-clear of corrupted entries
  - Optional error throwing
- **Validation Hook**: `createEncryptionKeyValidationHook()` runs BEFORE operations (priority -100)
  - Tests key validity on first access
  - Creates test entry for future validation
  - Triggers callback if key changed
- **Utility Functions**:
  - `rotateEncryptionKey()`: Change key and clear all data
  - `clearEncryptedEntries()`: Remove only encrypted entries
  - `validateEncryptionKey()`: Test if key works

### Usage Pattern
```dart
final cache = PVCache(
  env: 'myCache',
  hooks: [
    ...createEncryptionHooks(throwOnFailure: false),
    createEncryptionRecoveryHook(
      autoClearOnFailure: true,
      onDecryptionFailure: (key) async {
        print('Failed: $key');
        return true; // clear it
      },
    ),
  ],
);
```

### Design Rationale
- Separation of concerns: core encryption vs recovery logic
- Flexible error handling: throw immediately vs handle gracefully
- Progressive enhancement: recovery hooks are optional
- Clear entry points for key rotation scenarios
