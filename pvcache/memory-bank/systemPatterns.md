# System Patterns

## Architecture Overview

**PVCache = Hook System + Context Management + Sembast Storage**

```
┌─────────────────────────────────────────┐
│           PVCache Layer                 │
│  (Hook-based event system & context)    │
├─────────────────┬───────────────────────┤
│   PVCache API   │  (User-facing)        │
└────────┬────────┘                        │
         │                                 │
         ├─── PVCtx (Input context)        │
         ├─── PVRuntimeCtx (Execution)     │
         │                                 │
         ▼                                 │
┌─────────────────┐                        │
│   Hook System   │  (Core Value-Add)     │
│  Pre/Post hooks │                        │
└────────┬────────┘                        │
         │                                 │
         ▼                                 │
┌─────────────────┐                        │
│  Database (Db)  │  (Wrapper layer)      │
└────────┬────────┘                        │
         │                                 │
         ├─── Ref (Store reference)        │
         │                                 │
└─────────┼─────────────────────────────────┘
          ▼
┌─────────────────────────────────────────┐
│         Sembast (Storage Engine)        │
│  (Handles actual data persistence)      │
└─────────────────────────────────────────┘
```

**Key Insight**: PVCache doesn't reinvent storage—it adds a sophisticated hook system on top of Sembast's proven database capabilities.

## Key Components

### 1. PVCache (Entry Point)
- **Singleton per environment**: Uses factory pattern with internal registry
- **Lazy initialization**: Creates instances on first access
- **Config-based or env-based**: Accepts either string env or full config object

**Pattern**:
```dart
static final Map<String, PVCache> _instances = {};
factory PVCache.create({String? env, PVImmutableConfig? config})
```

### 2. Configuration System

#### PVConfig (Mutable)
- Builder pattern for configuration
- Mutable until finalized
- Converts to PVImmutableConfig

#### PVImmutableConfig (Immutable)
- Singleton per environment
- Processes and sorts action hooks by priority
- Thread-safe after creation
- Throws if duplicate env registered

**Key Pattern**: Mutable → Immutable → Registered

### 3. Database Layer (Db)

#### Static Database Management
- `_mainDb`: Primary database (file or web)
- `memoryDb`: Test mode database
- `_dbs`: Map of separate environment databases
- `globalMetaCache`: In-memory cache of metadata

#### Database Resolution Strategy
```
StorageType.memory → memoryDb
StorageType.separateFilePreferred + !isWeb → pvcache_{env}.db
Otherwise → mainDb
```

**Critical**: Global metadata ALWAYS stored in mainDb, regardless of storage type

#### Ref Class (Store Wrapper)
Bundles together:
- `StoreRef`: Sembast store reference (namespace)
- `Database`: Specific database instance
- `PVImmutableConfig`: Configuration

**Why**: Associates a store namespace with its specific database and config

### 4. Context System

#### PVCtx (Input Context)
- Immutable user input
- Contains: key, value, metadata
- Created by user for each operation

#### PVRuntimeCtx (Execution Context)
- Mutable runtime state
- Manages hook execution
- Tracks metadata changes
- Controls flow (break, continue, panic, etc.)

**Pattern**: User creates PVCtx → PVCache wraps in PVRuntimeCtx → Hooks receive PVRuntimeCtxRef

### 5. Hook System

#### Hook Registration
- Registered in PVConfig.actionHooks
- Keyed by event name
- Each hook has multiple contexts (event + priority + pre/post)

#### Hook Processing (in PVImmutableConfig)
1. Separate into preActionHooks and postActionHooks maps
2. Sort by priority (descending)
3. Make immutable
4. Cache in singleton

#### Hook Execution (in PVRuntimeCtx)
- Pre hooks: Before operation
- Operation: Core cache logic
- Post hooks: After operation
- Flow control via NextStep enum

## Design Decisions

### Why Static Databases?
- **Single source of truth**: One database instance per file
- **Connection pooling**: Avoids multiple file handles
- **Global metadata**: Centralized across all environments
- **Test isolation**: Test mode setter prevents mixed state

### Why Separate Global Metadata?
- **Cross-environment queries**: Can list all environments
- **Centralized management**: Single location for cache registry
- **Performance**: In-memory cache of frequently accessed data

### Why Immutable Config?
- **Thread safety**: No race conditions
- **Hook ordering**: Sorted once at creation
- **Validation**: Errors at config time, not runtime
- **Cache-friendly**: Can safely share references

### Why Context Pattern?
- **Separation of concerns**: Input vs execution state
- **Hook safety**: Hooks can't corrupt user input
- **Execution control**: Runtime can manage flow
- **Debugging**: Clear execution trail

## Critical Implementation Paths

### Cache Get Operation
```
1. PVCache.get(PVCtx) called
2. Create PVRuntimeCtx wrapper
3. Call _getRecord(rctx)
   a. Emit "getRecord" event (pre hooks)
   b. Get store ref via ctx.getStoreRef()
   c. Call storeRef.getRecord(key)
   d. Emit "getMetadata" event (hooks)
   e. Post "getRecord" hooks
4. Emit "getValue" event (pre hooks)
5. Extract value from record
6. Call ctx.normalReturn(value)
7. Post "getValue" hooks
8. Return rctx.returnValue
```

### Database Resolution
```
1. PVCache.create() or operation
2. Db.initialize() ensures mainDb exists
3. Db.getOrCreateDb(config) resolves database
   - Check storage type
   - Return existing or create new
   - Cache in _dbs map
4. Create StoreRef with env as namespace
5. Return Ref(store, config, db)
```

## Component Relationships

- **PVCache** depends on **PVRuntimeCtx** for execution
- **PVRuntimeCtx** depends on **Ref** for storage
- **Ref** depends on **Db** for database instances
- **PVImmutableConfig** is shared across all layers
- **Hooks** are isolated from storage layer
