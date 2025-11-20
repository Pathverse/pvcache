# Architecture Overview: PVCache v2

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          PVFactory                              │
│  - Builds cache configurations                                  │
│  - Validates hook dependencies                                  │
│  - Compiles execution plans                                     │
└────────────────┬────────────────────────────────────────────────┘
                 │ creates
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                          PVConfig                               │
│  - Environment settings                                         │
│  - Hook registry (stage hooks)                                  │
│  - Sequence config (operation flows)                            │
│  - Action hooks (user logic)                                    │
└────────────────┬────────────────────────────────────────────────┘
                 │ used by
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                          PVCache                                │
│  - Public API (put, get, delete, clear, exists)                │
│  - Compiled execution plans per operation                       │
│  - Storage configuration                                        │
└────────────────┬────────────────────────────────────────────────┘
                 │ executes with
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                        PVRuntimeCtx                             │
│  - runtime: {}     (entry data)                                 │
│  - metadata: {}    (cache metadata)                             │
│  - temp: {}        (inter-hook communication)                   │
│  - nextStep        (continue, break, error)                     │
│  - whatToReturn    (return specification)                       │
└────────────────┬────────────────────────────────────────────────┘
                 │ passed through
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Execution Stages                            │
│                                                                 │
│  Stage: metadata_get (PVCStageHook)                            │
│  ├─ Pre-Hooks: [validation, preparation]                       │
│  ├─ Stage Hook: Read metadata from DB → ctx.metadata          │
│  └─ Post-Hooks: [logging, auditing]                           │
│                                                                 │
│  Stage: metadata_parse (Empty Checkpoint)                      │
│  ├─ Pre-Hooks: []                                              │
│  ├─ Stage Hook: No-op (checkpoint only)                       │
│  └─ Post-Hooks: [TTL check, LRU update]                       │
│                                                                 │
│  Stage: value_get (PVCStageHook)                               │
│  ├─ Pre-Hooks: []                                              │
│  ├─ Stage Hook: Read value from DB → ctx.runtime['value']     │
│  └─ Post-Hooks: [decryption, transformation]                  │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. **PVFactory**
- **Purpose**: Builds and validates cache configurations
- **Responsibilities**:
  - Validate hook dependencies (produces/consumes)
  - Compile execution plans from sequences
  - Create PVConfig instances
  - Create PVCache instances

### 2. **PVConfig**
- **Purpose**: Immutable configuration container
- **Contains**:
  - Environment name
  - Hook registry (framework stage hooks)
  - Sequence config (operation flows)
  - Action hooks (user business logic)
  - Additional settings

### 3. **PVCache**
- **Purpose**: Public API and execution orchestrator
- **Responsibilities**:
  - Expose cache operations (put, get, delete, etc.)
  - Hold compiled execution plans
  - Create and manage contexts
  - Execute stages with transaction support

### 4. **PVRuntimeCtx**
- **Purpose**: Operation state container
- **Contains**:
  - `runtime`: Entry data (values being cached)
  - `metadata`: Cache metadata (_ttl_timestamp, _lru_count, etc.)
  - `temp`: Temporary inter-hook data
  - `nextStep`: Control flow (continue, break, error)
  - `whatToReturn`: Return value specification

### 5. **Stage Hooks (PVCStageHook)**
- **Purpose**: Framework-provided database operations
- **Examples**:
  - `metadata_get`: Read metadata from DB
  - `metadata_put`: Write metadata to DB
  - `value_get`: Read entry value from DB
  - `value_put`: Write entry value to DB
  - `metadata_parse`: Empty checkpoint for action hooks

### 6. **Action Hooks (PVCActionHook)**
- **Purpose**: User-defined business logic
- **Examples**:
  - TTL check during `metadata_parse`
  - LRU counter update during `metadata_parse`
  - Encryption during `value_prepare`
  - Decryption during `value_get` post-hook

## Key Architectural Decisions

### Decision 1: Stage Hooks vs Action Hooks
**Rationale**: Clean separation between framework code (DB operations) and user code (business logic)

**Benefits**:
- Framework maintains transaction boundaries
- Users don't need to know DB internals
- Stage hooks provide consistent, tested DB operations
- Action hooks focus on data transformation

### Decision 2: Context as Control Node
**Rationale**: Single mutable object carries all state and flow control

**Benefits**:
- No need for exceptions (BreakHook pattern removed)
- Clean control flow via `nextStep` enum
- Clear data flow through named maps
- Easy to trace execution

### Decision 3: Produces/Consumes Dependency System
**Rationale**: Enable compile-time dependency analysis and optimization

**Benefits**:
- Detect missing dependencies before runtime
- Order hooks automatically via topological sort
- Skip hooks that produce unused data
- Validate hook compatibility

### Decision 4: Empty Checkpoint Stages
**Rationale**: Provide explicit extension points without DB operations

**Benefits**:
- Clear where action hooks should attach
- No DB overhead for pure logic stages
- Self-documenting execution flow
- Flexible for future additions

### Decision 5: Transaction-Wrapped Stage Sequences
**Rationale**: Solve race conditions and ensure atomicity

**Benefits**:
- Multiple hooks share same transaction
- Prevents race conditions (LRU counter)
- Atomic entry + metadata updates
- Clean transaction boundaries

## Execution Flow (GET Example)

```
1. User calls: cache.get('user:123')

2. PVCache creates PVRuntimeCtx:
   ctx.runtime = {'key': 'user:123'}
   ctx.nextStep = NextStep.continue_
   ctx.whatToReturn = ReturnSpec.runtime('value')

3. Execute compiled GET plan:
   ┌─────────────────────────────────────────┐
   │ Stage: metadata_get                     │
   │  ├─ Pre: []                             │
   │  ├─ Stage: Read DB → ctx.metadata       │
   │  └─ Post: []                            │
   └─────────────────────────────────────────┘
   
   ┌─────────────────────────────────────────┐
   │ Stage: metadata_parse (checkpoint)      │
   │  ├─ Pre: []                             │
   │  ├─ Stage: No-op                        │
   │  └─ Post: [TTL check hook]              │
   │       → Checks ctx.metadata['_ttl_timestamp'] │
   │       → If expired: ctx.nextStep = break │
   │       → If expired: ctx.whatToReturn = null │
   └─────────────────────────────────────────┘
   
   If nextStep == break, exit early ✋
   
   ┌─────────────────────────────────────────┐
   │ Stage: value_get                        │
   │  ├─ Pre: []                             │
   │  ├─ Stage: Read DB → ctx.runtime['value'] │
   │  └─ Post: [Decryption hook]             │
   │       → Checks ctx.metadata['_encrypted'] │
   │       → Decrypts ctx.runtime['value']    │
   └─────────────────────────────────────────┘

4. Resolve return value:
   return _resolveReturn(ctx)
   → Returns ctx.runtime['value']
```

## Transaction Strategy

### Single-Stage Transaction
```dart
await db.transaction((txn) async {
  ctx.transaction = txn;
  await executeStage('metadata_get', ctx);
  ctx.transaction = null;
});
```

### Multi-Stage Transaction
```dart
await db.transaction((txn) async {
  ctx.transaction = txn;
  await executeStage('metadata_get', ctx);
  await executeStage('metadata_parse', ctx);  // Action hooks use same txn
  await executeStage('value_get', ctx);
  ctx.transaction = null;
});
```

### Transaction Boundaries
Defined in stage hooks or sequence config:
```dart
PVCStageHook(
  name: 'metadata_get',
  requiresTransaction: true,  // Wrap this stage in transaction
  hookFunction: (ctx) async {
    // Use ctx.transaction if available
  },
);
```

## Migration from Old Architecture

### Old → New Mapping

| Old Concept | New Concept | Notes |
|-------------|-------------|-------|
| `PVCacheHook` | `PVCActionHook` | User-defined hooks |
| `EventFlow` enum | Stage names (strings) | More flexible |
| `BreakHook` exception | `ctx.nextStep = break` | No exceptions |
| Direct DB access in hooks | Stage hooks handle DB | Cleaner separation |
| `ctx.entryValue` | `ctx.runtime['value']` | More flexible storage |
| `ctx.runtimeMeta` | `ctx.metadata` | Clearer naming |
| `ctx.runtimeData` | `ctx.temp` | Clearer purpose |
| Return value inference | `ctx.whatToReturn` | Explicit control |

### Key Improvements
1. ✅ **Transaction support** - Solves race conditions
2. ✅ **Dependency analysis** - Compile-time validation
3. ✅ **Skip optimization** - Only run needed hooks
4. ✅ **Clean control flow** - No exceptions for flow control
5. ✅ **Clear separation** - Stage vs action hooks
6. ✅ **Explicit returns** - whatToReturn specification
7. ✅ **Checkpoint stages** - Empty stages for extension points
