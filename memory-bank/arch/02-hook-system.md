# Hook System Architecture

## Hook Hierarchy

```dart
PVCBaseHook (abstract)
├── produces: List<String>        // What data this hook creates
├── consumes: List<String>        // What data this hook requires
├── skippable: bool              // Can be skipped if output unused
└── hookFunction: Future<void> Function(PVRuntimeCtx)

    ├─── PVCStageHook (framework-provided)
    │    └── Built-in DB operations
    │        Examples: metadata_get, value_put, etc.
    │
    └─── PVCActionHook (user-provided)
         ├── hookOn: String       // Which stage to attach to
         ├── isPostHook: bool     // Before or after stage
         └── User business logic
             Examples: TTL check, LRU update, encryption
```

## Stage Hooks (Framework-Provided)

### Purpose
Perform actual database I/O operations. These are built into the framework.

### Characteristics
- **Immutable**: Defined by framework, not user-modifiable
- **Transaction-aware**: Can require transaction wrapping
- **Consistent API**: All stage hooks follow same patterns
- **Optimized**: Direct DB access, no abstraction overhead

### Standard Stage Hooks

#### For GET Operations:
```dart
// 1. Read metadata from database
PVCStageHook(
  name: 'metadata_get',
  produces: ['metadata.*'],
  consumes: ['runtime.key'],
  hookFunction: (ctx) async {
    final key = ctx.runtime['key'];
    final metaData = await _readMetadataFromDB(key);
    ctx.metadata.addAll(metaData ?? {});
  },
)

// 2. Empty checkpoint for metadata inspection
PVCStageHook(
  name: 'metadata_parse',
  produces: [],
  consumes: ['metadata.*'],
  hookFunction: (ctx) async {
    // No-op - just a checkpoint for action hooks
  },
)

// 3. Read entry value from database
PVCStageHook(
  name: 'value_get',
  produces: ['runtime.value'],
  consumes: ['runtime.key'],
  hookFunction: (ctx) async {
    final key = ctx.runtime['key'];
    final entryData = await _readEntryFromDB(key);
    if (entryData != null) {
      ctx.runtime['value'] = entryData['value'];
    }
  },
)

// 4. Empty checkpoint for value transformation
PVCStageHook(
  name: 'value_parse',
  produces: [],
  consumes: ['runtime.value'],
  hookFunction: (ctx) async {
    // No-op - checkpoint for decryption, transformation, etc.
  },
)
```

#### For PUT Operations:
```dart
// 1. Read existing metadata (for updates)
PVCStageHook(
  name: 'metadata_get',
  produces: ['metadata.*'],
  consumes: ['runtime.key'],
  hookFunction: (ctx) async {
    final key = ctx.runtime['key'];
    final metaData = await _readMetadataFromDB(key);
    ctx.metadata.addAll(metaData ?? {});
  },
)

// 2. Checkpoint for metadata preparation (TTL set, LRU increment)
PVCStageHook(
  name: 'metadata_prepare',
  produces: [],
  consumes: ['metadata.*'],
  hookFunction: (ctx) async {
    // No-op - checkpoint for metadata modification
  },
)

// 3. Checkpoint for value preparation (encryption)
PVCStageHook(
  name: 'value_prepare',
  produces: [],
  consumes: ['runtime.value'],
  hookFunction: (ctx) async {
    // No-op - checkpoint for encryption, validation
  },
)

// 4. Write value to database
PVCStageHook(
  name: 'value_put',
  produces: [],
  consumes: ['runtime.key', 'runtime.value'],
  hookFunction: (ctx) async {
    final key = ctx.runtime['key'];
    final value = ctx.runtime['value'];
    await _writeEntryToDB(key, {'value': value});
  },
)

// 5. Write metadata to database
PVCStageHook(
  name: 'metadata_put',
  produces: [],
  consumes: ['runtime.key', 'metadata.*'],
  hookFunction: (ctx) async {
    final key = ctx.runtime['key'];
    await _writeMetadataToDB(key, ctx.metadata);
  },
)
```

#### For DELETE Operations:
```dart
PVCStageHook(
  name: 'value_delete',
  produces: [],
  consumes: ['runtime.key'],
  hookFunction: (ctx) async {
    final key = ctx.runtime['key'];
    await _deleteEntryFromDB(key);
  },
)

PVCStageHook(
  name: 'metadata_delete',
  produces: [],
  consumes: ['runtime.key'],
  hookFunction: (ctx) async {
    final key = ctx.runtime['key'];
    await _deleteMetadataFromDB(key);
  },
)
```

## Action Hooks (User-Provided)

### Purpose
Implement business logic and data transformations between stage operations.

### Characteristics
- **User-defined**: Created by cache users
- **Composable**: Multiple action hooks can attach to same stage
- **Ordered**: Via produces/consumes dependency analysis
- **Transparent**: Framework handles ordering and skipping

### Hook Attachment

```dart
PVCActionHook(
  hookOn: 'metadata_parse',  // Attach to this stage
  isPostHook: true,          // After stage hook runs
  produces: [],
  consumes: ['metadata._ttl_timestamp'],
  hookFunction: (ctx) async {
    // Your logic here
  },
)
```

### isPostHook Behavior

#### `isPostHook: false` (Pre-Hook)
Runs **before** the stage hook executes:
```
User Hook → Stage Hook → User Hook
  (pre)                    (post)
```

**Use Cases**:
- Validation before DB operation
- Prepare data for stage hook
- Early exit before DB access

#### `isPostHook: true` (Post-Hook)
Runs **after** the stage hook executes:
```
Stage Hook → User Hook
             (post)
```

**Use Cases**:
- Transform data from DB (decryption)
- Validate data from DB
- Update derived metadata

### Example Action Hooks

#### TTL Check Hook
```dart
PVCActionHook(
  hookOn: 'metadata_parse',
  isPostHook: true,
  produces: [],
  consumes: ['metadata._ttl_timestamp'],
  skippable: false,  // Always check TTL
  hookFunction: (ctx) async {
    final expiresAt = ctx.metadata['_ttl_timestamp'];
    if (expiresAt == null) return;  // No TTL set
    
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= expiresAt) {
      // Entry expired
      ctx.nextStep = NextStep.break_;
      ctx.whatToReturn = ReturnSpec.null_();
      
      // Clean up expired entry
      await _deleteExpiredEntry(ctx);
    }
  },
)
```

#### TTL Set Hook
```dart
PVCActionHook(
  hookOn: 'metadata_prepare',
  isPostHook: true,
  produces: ['metadata._ttl_timestamp'],
  consumes: ['metadata.ttl'],
  skippable: true,  // Skip if no TTL provided
  hookFunction: (ctx) async {
    final ttl = ctx.metadata['ttl'];
    if (ttl == null) return;  // No TTL requested
    
    final ttlSeconds = ttl is int ? ttl : int.tryParse(ttl.toString());
    if (ttlSeconds == null || ttlSeconds <= 0) return;
    
    final expiresAt = DateTime.now()
        .add(Duration(seconds: ttlSeconds))
        .millisecondsSinceEpoch;
    
    ctx.metadata['_ttl_timestamp'] = expiresAt;
  },
)
```

#### LRU Update Hook
```dart
PVCActionHook(
  hookOn: 'metadata_prepare',
  isPostHook: true,
  produces: ['metadata._lru_count'],
  consumes: ['metadata._lru_global_counter'],
  skippable: false,
  hookFunction: (ctx) async {
    // Read global counter (in same transaction!)
    final counterData = await _readMetadataFromDB('_lru_global_counter');
    int counter = counterData?['counter'] ?? 0;
    
    // Increment
    counter++;
    
    // Update entry's access count
    ctx.metadata['_lru_count'] = counter;
    
    // Store new global counter
    await _writeMetadataToDB('_lru_global_counter', {'counter': counter});
    
    // Evict if needed
    await _evictLRUIfNeeded(ctx, maxEntries: 100);
  },
)
```

#### Encryption Hook
```dart
PVCActionHook(
  hookOn: 'value_prepare',
  isPostHook: true,
  produces: ['runtime.value', 'metadata._encrypted'],
  consumes: ['runtime.value'],
  skippable: false,
  hookFunction: (ctx) async {
    final value = ctx.runtime['value'];
    if (value == null) return;
    
    // Encrypt the value
    final encrypted = await encryptValue(value, encryptionKey);
    ctx.runtime['value'] = encrypted;
    
    // Mark as encrypted
    ctx.metadata['_encrypted'] = true;
  },
)
```

#### Decryption Hook
```dart
PVCActionHook(
  hookOn: 'value_parse',
  isPostHook: true,
  produces: ['runtime.value'],
  consumes: ['runtime.value', 'metadata._encrypted'],
  skippable: false,
  hookFunction: (ctx) async {
    if (ctx.metadata['_encrypted'] != true) return;
    
    final encrypted = ctx.runtime['value'];
    if (encrypted == null) return;
    
    // Decrypt the value
    try {
      final decrypted = await decryptValue(encrypted, encryptionKey);
      ctx.runtime['value'] = decrypted;
    } catch (e) {
      // Decryption failed
      ctx.runtime['value'] = null;
      ctx.metadata['_decrypt_failed'] = true;
    }
  },
)
```

## Produces/Consumes System

### Notation
- `metadata.*` - All metadata keys
- `metadata._ttl_timestamp` - Specific metadata key
- `runtime.value` - Specific runtime key
- `runtime.key` - Entry key
- `temp.validation_result` - Temporary data

### Dependency Resolution

#### Example Hooks:
```dart
Hook A: produces: ['metadata._lru_count']
        consumes: []

Hook B: produces: ['metadata._ttl_timestamp']
        consumes: ['metadata.ttl']

Hook C: produces: []
        consumes: ['metadata._lru_count', 'metadata._ttl_timestamp']
```

#### Dependency Graph:
```
Hook B (needs metadata.ttl)
  ↓
Hook A (no dependencies)
  ↓
Hook C (needs _lru_count + _ttl_timestamp)
```

#### Execution Order:
1. Hook B (if metadata.ttl exists)
2. Hook A (always)
3. Hook C (if both dependencies available)

### Skip Optimization

If Hook C is skippable and nothing downstream needs its output:
```dart
Hook C(
  skippable: true,
  produces: ['temp.stats'],
  consumes: ['metadata._lru_count'],
)
```

Compiler checks: "Does anything consume `temp.stats`?"
- If NO → Skip Hook C entirely
- If YES → Execute Hook C

## Hook Registry

### Structure
```dart
class PVCHookRegistry {
  final Map<String, PVCStageHook> _stageHooks = {};
  
  void registerStageHook(String name, PVCStageHook hook) {
    _stageHooks[name] = hook;
  }
  
  PVCStageHook? getStageHook(String name) => _stageHooks[name];
  
  List<String> get registeredStageHooks => _stageHooks.keys.toList();
}
```

### Registration (Framework)
```dart
final registry = PVCHookRegistry();
registry.registerStageHook('metadata_get', metadataGetHook);
registry.registerStageHook('metadata_parse', metadataParseHook);
registry.registerStageHook('value_get', valueGetHook);
// ... etc
```

### Validation (Factory)
```dart
bool _validateActionHooks(Map<String, List<PVCActionHook>> actionHooks) {
  for (var hooks in actionHooks.values) {
    for (var hook in hooks) {
      if (!registry.registeredStageHooks.contains(hook.hookOn)) {
        throw Exception('Action hook references unknown stage: ${hook.hookOn}');
      }
    }
  }
  return true;
}
```

## Best Practices

### 1. Minimize Produces
Only list what you actually create:
```dart
// ❌ Bad
produces: ['metadata.*']  // Too broad

// ✅ Good
produces: ['metadata._ttl_timestamp']  // Specific
```

### 2. Be Specific with Consumes
```dart
// ❌ Bad
consumes: ['metadata.*']  // Can't detect missing data

// ✅ Good
consumes: ['metadata._ttl_timestamp', 'metadata._lru_count']
```

### 3. Use Skippable for Optional Logic
```dart
// ✅ Good for logging, stats, etc.
PVCActionHook(
  skippable: true,
  produces: ['temp.access_log'],
  consumes: ['runtime.key'],
  hookFunction: (ctx) async {
    // Log access
  },
)
```

### 4. Pre-Hooks for Validation
```dart
PVCActionHook(
  hookOn: 'value_put',
  isPostHook: false,  // Before DB write
  produces: [],
  consumes: ['runtime.value'],
  hookFunction: (ctx) async {
    if (ctx.runtime['value'] == null) {
      ctx.nextStep = NextStep.error;
      throw Exception('Cannot put null value');
    }
  },
)
```

### 5. Post-Hooks for Transformation
```dart
PVCActionHook(
  hookOn: 'value_get',
  isPostHook: true,  // After DB read
  produces: ['runtime.value'],
  consumes: ['runtime.value'],
  hookFunction: (ctx) async {
    // Transform data
    ctx.runtime['value'] = await transform(ctx.runtime['value']);
  },
)
```
