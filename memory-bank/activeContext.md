# Active Context: PVCache v2 Rewrite# Active Context: PVCache



## Current Work Focus## Current Work Focus

**Major architectural rewrite in progress**. Transitioning from the old direct-hook system to a new factory-based, dependency-aware architecture with transaction support.All major features complete. Ready for package polish and publication.



## Recent Progress (November 19, 2025)## Recent Implementations



### Architecture Design Complete ✅### Encryption Recovery System (Nov 18, 2025)

Finalized the new architecture with clear separation of concerns:Added `lib/hooks/encryption_recovery.dart` with comprehensive key rotation and recovery features:

- **Stage Hooks**: Framework-provided DB operations- **`createEncryptionRecoveryHook()`**: Detects and handles decryption failures with optional auto-clear and error throwing

- **Action Hooks**: User-provided business logic- **`rotateEncryptionKey()`**: Changes encryption key and clears incompatible data

- **Context System**: Rich state container with runtime/metadata/temp maps- **`clearEncryptedEntries()`**: Removes only encrypted entries from cache

- **Dependency System**: Produces/consumes for automatic ordering- **`validateEncryptionKey()`**: Tests if current key can decrypt data

- **Transaction Support**: Atomic operations across stages- **`createEncryptionKeyValidationHook()`**: Validates key on first access



### Documentation Created ✅Updated `lib/hooks/encryption.dart`:

Comprehensive architecture documentation in `memory-bank/arch/`:- Added optional `throwOnFailure` parameter to control error handling behavior (default: `true`)

1. `01-architecture-overview.md` - High-level system design- Passed through to `createEncryptionHooks()` and `createEncryptionDecryptHook()`

2. `02-hook-system.md` - Stage vs action hooks, dependency resolution

3. `03-context-system.md` - Context structure and data flow### Macro Get Feature (Nov 8, 2025)

4. `04-compilation-execution.md` - Plan compilation and execution strategyPattern-based auto-fetch integrated into `PVCache.get()` core method. Checks patterns after hook pipeline if returnValue is null, fetches and caches data automatically. Works with all hooks (TTL, LRU, encryption). 19 tests passing.



### Code Skeleton Established ✅Full and selective field encryption with AES-256-CTR. Shared utilities in `lib/utils/`. Security fix: removed key name from metadata. 21 tests passing (10 full + 11 selective).

Basic structure in place:

- `lib/config/hook.dart` - Hook class definitions## Core Features

- `lib/config/factory.dart` - Factory pattern

- `lib/config/config.dart` - Configuration container**Hooks**: 

- `lib/config/registry.dart` - Hook registry- TTL (8 tests)

- `lib/config/sequence_config.dart` - Operation sequences- LRU (6 tests) 

- Encryption (10 tests) with optional `throwOnFailure`

## Current State- Selective Encryption (11 tests)

- Encryption Recovery (new - no tests yet)

### Implemented ✅

- Hook class hierarchy (`PVCBaseHook`, `PVCStageHook`, `PVCActionHook`)**Macro Get**: Pattern-based auto-fetch (19 tests)

- `skippable` flag for optimization**Examples**: Full demonstration in `example/` directory

- `produces`/`consumes` fields for dependencies**Tests**: 136 passing total

- `isPostHook` flag for pre/post attachment

- Factory pattern foundation## Next Steps

- Sequence config structure

1. Write tests for encryption recovery hooks

### Not Implemented ❌2. Package polish: Update main README, export hooks in lib/pvcache.dart

- `PVRuntimeCtx` with runtime/metadata/temp maps3. Publish to pub.dev

- `NextStep` enum (continue, break, error)

- `ReturnSpec` class (return value specification)## Key Architecture Decisions

- Built-in stage hooks (metadata_get, value_put, etc.)

- Dependency resolver (topological sort)### Reserved Keys

- Execution plan compilerKeys starting with `_` are system-reserved (e.g., `_ttl_timestamp`, `_lru_count`, `_encryption_nonces`). Need validation to prevent user creation.

- Executor with transaction support

- All user-facing cache operations### Hook Ordering

Hooks sorted by EventFlow stage, then priority (int). Lower priority runs first within same stage.

## Key Decisions Made

### Macro Get Integration

### 1. Context as Control NodeIntegrated into core `PVCache.get()` instead of hook because BreakHook stops subsequent hooks. Runs after pipeline if returnValue is null. Works with all hooks without special cases.

Context carries all state and flow control:

```dart### Dual Database Architecture  

ctx.runtime = {}     // Entry dataSeparate sembast databases for persistent and in-memory storage. No redundant maps. Unified API.

ctx.metadata = {}    // Cache metadata

ctx.temp = {}        // Inter-hook communication### Metadata Mutability

ctx.nextStep         // continue, break, errorMetadata loaded before hooks run. Creates mutable copy for hooks to modify.

ctx.whatToReturn     // Return specification

```### Encryption Error Handling

Two levels of control:

### 2. Empty Checkpoint Stages1. **`encryption.dart`**: `throwOnFailure` on decrypt hook (default `true`) - controls whether decryption failures throw exceptions

Stages like `metadata_parse` do no DB work - they're extension points:2. **`encryption_recovery.dart`**: Recovery hook with `throwOnFailure`, `autoClearOnFailure`, and callback for handling corrupted data

```dart

Stage: metadata_parseTypical pattern: Set encryption `throwOnFailure: false` and add recovery hook to gracefully handle key changes.
├─ Pre-hooks: []
├─ Stage hook: No-op (checkpoint only)
└─ Post-hooks: [TTL check, LRU update]
```

### 3. Transaction Wrapping
Multiple stages share same transaction:
```dart
await db.transaction((txn) async {
  ctx.transaction = txn;
  await executeStage('metadata_get');
  await executeStage('metadata_parse');  // Uses same transaction
  await executeStage('value_get');
});
```

### 4. Produces/Consumes for Ordering
Hooks declare dependencies explicitly:
```dart
Hook A: produces: ['metadata._lru_count']
Hook B: consumes: ['metadata._lru_count']
→ Hook A must run before Hook B
```

## Problem Being Solved

### Race Conditions (LRU Example)
**Old system** (pvcache2):
```dart
// Request A and B run concurrently
Request A: Read counter = 5
Request B: Read counter = 5
Request A: Write counter = 6
Request B: Write counter = 6  ❌ Should be 7
```

**New system** (pvcache):
```dart
// Each request gets its own transaction
Request A: [Transaction] Read 5 → Write 6 → Commit
Request B: [Transaction] Read 6 → Write 7 → Commit  ✅
```

### Manual DB Access
**Old system**:
```dart
// Hooks bypass abstractions
final bridge = PVBridge();
final db = await bridge.getDatabaseForType(...);
final store = bridge.getStore(...);
final data = await store.find(db);
```

**New system**:
```dart
// Stage hooks handle DB access
// Action hooks just modify context
ctx.metadata['_lru_count'] = counter + 1;
```

## Next Steps (Priority Order)

### 1. Implement Context System
```dart
// lib/core/ctx.dart
class PVRuntimeCtx extends PVCtx {
  final Map<String, dynamic> runtime = {};
  final Map<String, dynamic> metadata = {};
  final Map<String, dynamic> temp = {};
  NextStep nextStep = NextStep.continue_;
  ReturnSpec whatToReturn = ReturnSpec.runtime('value');
  Transaction? transaction;
}
```

### 2. Implement Built-in Stage Hooks
```dart
// lib/builtin/stage_hooks.dart
PVCStageHook metadataGetHook = ...
PVCStageHook metadataParseHook = ...
PVCStageHook valueGetHook = ...
PVCStageHook valuePutHook = ...
```

### 3. Implement Dependency Resolver
```dart
// lib/core/resolver.dart
class DependencyResolver {
  List<Hook> topologicalSort(List<Hook> hooks) { ... }
}
```

### 4. Implement Compiler
```dart
// lib/core/compiler.dart
class StageCompiler {
  ExecutionPlan compile(sequence, registry, actionHooks) { ... }
}
```

### 5. Implement Executor
```dart
// lib/core/executor.dart
class Executor {
  Future<dynamic> execute(plan, ctx) { ... }
}
```

### 6. Port Existing Hooks
- TTL check hook (GET)
- TTL set hook (PUT)
- LRU update hook (GET/PUT)
- LRU evict hook (PUT)
- Encryption hooks
- Selective encryption hooks

### 7. Write Tests
- Unit tests for dependency resolution
- Integration tests for race conditions
- Performance benchmarks

## Migration Strategy

### Phase 1: Core Infrastructure
Implement new architecture without breaking old code.

### Phase 2: Side-by-Side
Both old and new systems working simultaneously.

### Phase 3: Hook Migration
Port hooks one by one, testing each.

### Phase 4: Cutover
Switch examples and tests to new system.

### Phase 5: Cleanup
Remove old code, publish v2.

## Open Questions

1. **Skip optimization**: Runtime or compile-time analysis?
2. **Parallel execution**: Worth the complexity?
3. **Transaction granularity**: Per-stage or per-sequence?
4. **Error recovery**: Rollback entire transaction or continue?
5. **Performance target**: How much slower is acceptable vs. v1?

## References
- Old working implementation: `../pvcache2/` (136 tests passing)
- Architecture documentation: `arch/` folder
- Old memory bank: `old/` folder
