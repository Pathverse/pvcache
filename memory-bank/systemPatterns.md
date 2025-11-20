# System Patterns: PVCache v2

## Architecture Overview

See detailed documentation in `memory-bank/arch/01-architecture-overview.md`.

### High-Level Flow

```
User Request (cache.get('key'))
    ↓
PVCache (public API)
    ↓
Creates PVRuntimeCtx (state container)
    ↓
Executes Compiled Plan (pre-built at init)
    ↓
Stages Execute in Sequence:
  ├─ Stage 1: metadata_get
  │   ├─ Pre-hooks: []
  │   ├─ Stage hook: Read DB → ctx.metadata
  │   └─ Post-hooks: []
  │
  ├─ Stage 2: metadata_parse (checkpoint)
  │   ├─ Pre-hooks: []
  │   ├─ Stage hook: No-op
  │   └─ Post-hooks: [TTL check, LRU update]
  │
  ├─ Stage 3: value_get
  │   ├─ Pre-hooks: []
  │   ├─ Stage hook: Read DB → ctx.runtime['value']
  │   └─ Post-hooks: [Decryption]
  │
  └─ Stage 4: value_parse (checkpoint)
      ├─ Pre-hooks: []
      ├─ Stage hook: No-op
      └─ Post-hooks: [Transformation]
    ↓
Resolve Return Value (ctx.whatToReturn)
    ↓
Return to User
```

## Key Design Patterns

### 1. Stage vs Action Hooks Pattern

**Stage Hooks** (Framework-Provided):
- Handle database I/O
- Consistent, tested implementations
- Transaction-aware
- Examples: `metadata_get`, `value_put`

**Action Hooks** (User-Provided):
- Business logic and transformations
- No direct DB access
- Modify context data only
- Examples: TTL check, encryption

### 2. Empty Checkpoint Pattern

Some stages do no work - they're extension points:
```dart
PVCStageHook(
  name: 'metadata_parse',
  hookFunction: (ctx) async {
    // Empty - just a checkpoint for action hooks
  },
)
```

Action hooks attach here:
```dart
PVCActionHook(
  hookOn: 'metadata_parse',
  isPostHook: true,
  hookFunction: (ctx) async {
    // TTL check logic
  },
)
```

### 3. Context as State Container Pattern

All data flows through context:
```dart
ctx.runtime['key']      // Entry key
ctx.runtime['value']    // Entry value
ctx.metadata['_ttl']    // System metadata
ctx.temp['stats']       // Temporary data
ctx.nextStep            // Flow control
ctx.whatToReturn        // Return spec
```

### 4. Produces/Consumes Dependency Pattern

Hooks declare what they need and create:
```dart
Hook A: produces: ['metadata._counter']
        consumes: []

Hook B: produces: ['temp.validated']
        consumes: ['metadata._counter']
        
→ Hook A must run before Hook B
```

Compiler builds dependency graph and orders hooks automatically.

### 5. Transaction Wrapping Pattern

Multiple stages share same transaction:
```dart
await db.transaction((txn) async {
  ctx.transaction = txn;
  await executeStage('metadata_get', ctx);
  await executeStage('metadata_parse', ctx);
  await executeStage('value_get', ctx);
  // All stages use same transaction
});
```

### 6. Compile Once, Execute Many Pattern

```
Cache Initialization:
  ├─ Parse sequences
  ├─ Analyze dependencies
  ├─ Order hooks (topological sort)
  ├─ Build execution plan
  └─ Cache plan in memory
  
Cache Operation:
  ├─ Get pre-compiled plan
  ├─ Create context
  ├─ Execute plan
  └─ Return result
```

### 7. Skip Optimization Pattern

If a hook produces data nobody consumes, skip it:
```dart
Hook X: produces: ['temp.log']
        skippable: true

// At runtime:
if (hook.skippable && !isDataNeeded(hook.produces)) {
  continue;  // Skip hook
}
```

## Component Relationships

### PVFactory → PVConfig → PVCache

```dart
// Factory builds config
PVFactory factory = PVFactory.fromDefault();
factory.sequenceConfig.get = ['metadata_get', 'value_get'];
factory.actionHooks['metadata_parse'] = [ttlHook];
PVConfig config = factory.generateConfig();

// Config used to create cache
PVCache cache = PVCache.create(config);
```

### Registry Pattern

Framework stage hooks registered centrally:
```dart
class PVCHookRegistry {
  Map<String, PVCStageHook> stageHooks = {
    'metadata_get': metadataGetHook,
    'value_put': valuePutHook,
    // ...
  };
}
```

Action hooks attached per-stage:
```dart
Map<String, List<PVCActionHook>> actionHooks = {
  'metadata_parse': [ttlCheckHook, lruUpdateHook],
  'value_parse': [decryptionHook],
};
```

## Critical Paths

### GET Operation

1. **Initialize**: Create context with key
2. **Metadata Get**: Read metadata from DB → ctx.metadata
3. **Metadata Parse**: Run TTL check, LRU update (action hooks)
4. **Value Get**: Read value from DB → ctx.runtime['value']
5. **Value Parse**: Run decryption (action hook)
6. **Return**: Resolve ctx.whatToReturn

### PUT Operation

1. **Initialize**: Create context with key, value
2. **Metadata Get**: Read existing metadata
3. **Metadata Prepare**: Run TTL set, LRU increment (action hooks)
4. **Value Prepare**: Run encryption (action hook)
5. **Value Put**: Write value to DB from ctx.runtime['value']
6. **Metadata Put**: Write metadata to DB from ctx.metadata
7. **Return**: Return void

### Transaction Boundaries

Entire operation wrapped in transaction:
```
Transaction Start
  ├─ All stages execute
  ├─ All hooks execute
  └─ All DB operations
Transaction Commit (or Rollback on error)
```

## Data Flow

### Entry Data
```
User Input
  ↓
ctx.runtime['key'] = 'user:123'
ctx.runtime['value'] = {'name': 'Alice'}
  ↓
Encryption Hook
  ↓
ctx.runtime['value'] = <encrypted>
ctx.metadata['_encrypted'] = true
  ↓
Stage Hook (value_put)
  ↓
Database
```

### Metadata Flow
```
User Metadata
ctx.metadata['ttl'] = 3600
  ↓
TTL Set Hook
  ↓
ctx.metadata['_ttl_timestamp'] = <timestamp>
  ↓
LRU Update Hook
  ↓
ctx.metadata['_lru_count'] = 42
  ↓
Stage Hook (metadata_put)
  ↓
Database
```

## Reserved Namespaces

### Runtime Keys
- `runtime['key']` - Entry key (required)
- `runtime['value']` - Entry value (required for put/get)
- `runtime['original_value']` - Backup before transformation

### Metadata Keys
**User-provided** (no prefix):
- `metadata['ttl']` - User input
- `metadata['secure']` - User input

**System-reserved** (prefix with `_`):
- `metadata['_ttl_timestamp']` - TTL hook
- `metadata['_lru_count']` - LRU hook
- `metadata['_encrypted']` - Encryption hook
- `metadata['_encryption_nonces']` - Selective encryption hook

### Temp Keys
No restrictions - any key allowed for inter-hook communication.

## Migration from Old System

| Old Concept | New Concept |
|-------------|-------------|
| `PVCacheHook` | `PVCActionHook` |
| `EventFlow` enum | Stage names (strings) |
| `throw BreakHook()` | `ctx.nextStep = break_` |
| `ctx.entryValue` | `ctx.runtime['value']` |
| `ctx.runtimeMeta` | `ctx.metadata` |
| `ctx.runtimeData` | `ctx.temp` |
| Direct DB access | Stage hooks only |
| No transactions | Transaction-wrapped |

## References

See detailed architecture documentation:
- `arch/01-architecture-overview.md` - System design
- `arch/02-hook-system.md` - Hook types and dependencies
- `arch/03-context-system.md` - Context structure
- `arch/04-compilation-execution.md` - Compilation and execution
