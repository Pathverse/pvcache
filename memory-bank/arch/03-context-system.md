# Context System Architecture

## Context Structure

### PVRuntimeCtx Class

```dart
class PVRuntimeCtx extends PVCtx {
  /// Entry data - values being cached
  /// Examples:
  ///   runtime['key'] = 'user:123'
  ///   runtime['value'] = {'name': 'Alice', 'age': 30}
  ///   runtime['original_value'] = <backup before encryption>
  final Map<String, dynamic> runtime = {};
  
  /// Cache metadata - TTL, LRU, encryption flags, etc.
  /// Examples:
  ///   metadata['_ttl_timestamp'] = 1732012345000
  ///   metadata['_lru_count'] = 42
  ///   metadata['_encrypted'] = true
  ///   metadata['ttl'] = 3600 (user-provided, converted to _ttl_timestamp)
  final Map<String, dynamic> metadata = {};
  
  /// Temporary inter-hook communication
  /// Not persisted to database
  /// Examples:
  ///   temp['validation_passed'] = true
  ///   temp['access_log'] = [...]
  ///   temp['computed_stats'] = {...}
  final Map<String, dynamic> temp = {};
  
  /// Control flow instruction
  /// Determines whether to continue execution or exit early
  NextStep nextStep = NextStep.continue_;
  
  /// Return value specification
  /// Tells the framework what to return to the user
  ReturnSpec whatToReturn = ReturnSpec.runtime('value');
  
  /// Optional: Transaction object for DB operations
  /// Set by framework when executing within transaction
  Transaction? transaction;
}
```

## NextStep Enum

Controls execution flow through hook pipeline:

```dart
enum NextStep {
  /// Continue executing remaining stages/hooks
  continue_,
  
  /// Stop execution immediately, return value based on whatToReturn
  break_,
  
  /// Stop execution with error, throw exception
  error,
}
```

### Usage Examples

#### Continue (Default)
```dart
hookFunction: (ctx) async {
  // Do work
  ctx.metadata['_lru_count'] = 42;
  
  // Implicitly continue (don't change nextStep)
  // Next hook will execute
}
```

#### Break (Early Exit)
```dart
hookFunction: (ctx) async {
  final expiresAt = ctx.metadata['_ttl_timestamp'];
  if (expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt) {
    // Entry expired - stop execution
    ctx.nextStep = NextStep.break_;
    ctx.whatToReturn = ReturnSpec.null_();  // Return null
  }
}
```

#### Error (Exception)
```dart
hookFunction: (ctx) async {
  if (ctx.runtime['value'] == null) {
    ctx.nextStep = NextStep.error;
    throw Exception('Value cannot be null');
  }
}
```

## ReturnSpec Class

Specifies what value to return to the user:

```dart
class ReturnSpec {
  /// Where to read the value from
  final String source;  // 'RUNTIME', 'METADATA', 'TEMP', 'NULL', 'LITERAL'
  
  /// Key to read from source map (if applicable)
  final String? key;
  
  /// Direct value (if source is 'LITERAL')
  final dynamic value;
  
  // Constructors
  ReturnSpec.null_() 
    : source = 'NULL', key = null, value = null;
  
  ReturnSpec.runtime(String key) 
    : source = 'RUNTIME', key = key, value = null;
  
  ReturnSpec.metadata(String key) 
    : source = 'METADATA', key = key, value = null;
  
  ReturnSpec.temp(String key) 
    : source = 'TEMP', key = key, value = null;
  
  ReturnSpec.literal(dynamic value) 
    : source = 'LITERAL', key = null, value = value;
}
```

### Usage Examples

#### Return null (expired entry)
```dart
ctx.whatToReturn = ReturnSpec.null_();
```

#### Return cached value (default for GET)
```dart
ctx.whatToReturn = ReturnSpec.runtime('value');
```

#### Return metadata field
```dart
ctx.whatToReturn = ReturnSpec.metadata('_ttl_timestamp');
```

#### Return computed result
```dart
ctx.temp['computed'] = calculateSomething();
ctx.whatToReturn = ReturnSpec.temp('computed');
```

#### Return literal value
```dart
ctx.whatToReturn = ReturnSpec.literal(true);  // For exists() operation
```

## Context Data Flow

### GET Operation Example

```
1. Initialize Context
   ┌─────────────────────────────────────┐
   │ ctx.runtime = {                     │
   │   'key': 'user:123'                 │
   │ }                                   │
   │ ctx.metadata = {}                   │
   │ ctx.temp = {}                       │
   │ ctx.nextStep = continue_            │
   │ ctx.whatToReturn = runtime('value') │
   └─────────────────────────────────────┘

2. Stage: metadata_get
   ┌─────────────────────────────────────┐
   │ Read from DB:                       │
   │   _ttl_timestamp: 1732015000000     │
   │   _lru_count: 5                     │
   │   _encrypted: true                  │
   │                                     │
   │ ctx.metadata = {                    │
   │   '_ttl_timestamp': 1732015000000,  │
   │   '_lru_count': 5,                  │
   │   '_encrypted': true                │
   │ }                                   │
   └─────────────────────────────────────┘

3. Stage: metadata_parse + TTL check hook
   ┌─────────────────────────────────────┐
   │ Check expiration:                   │
   │   now = 1732010000000               │
   │   expires = 1732015000000           │
   │   → Not expired, continue           │
   │                                     │
   │ ctx.nextStep = continue_            │
   └─────────────────────────────────────┘

4. Stage: value_get
   ┌─────────────────────────────────────┐
   │ Read from DB:                       │
   │   value: <encrypted data>           │
   │                                     │
   │ ctx.runtime = {                     │
   │   'key': 'user:123',                │
   │   'value': <encrypted data>         │
   │ }                                   │
   └─────────────────────────────────────┘

5. Stage: value_parse + Decryption hook
   ┌─────────────────────────────────────┐
   │ Decrypt value:                      │
   │   encrypted = ctx.runtime['value']  │
   │   decrypted = decrypt(encrypted)    │
   │                                     │
   │ ctx.runtime = {                     │
   │   'key': 'user:123',                │
   │   'value': {'name': 'Alice'}        │
   │ }                                   │
   └─────────────────────────────────────┘

6. Return to User
   ┌─────────────────────────────────────┐
   │ Resolve return value:               │
   │   source = 'RUNTIME'                │
   │   key = 'value'                     │
   │   → return ctx.runtime['value']     │
   │   → {'name': 'Alice'}               │
   └─────────────────────────────────────┘
```

### PUT Operation Example

```
1. Initialize Context
   ┌─────────────────────────────────────┐
   │ ctx.runtime = {                     │
   │   'key': 'user:123',                │
   │   'value': {'name': 'Alice'}        │
   │ }                                   │
   │ ctx.metadata = {                    │
   │   'ttl': 3600  // user-provided     │
   │ }                                   │
   │ ctx.nextStep = continue_            │
   │ ctx.whatToReturn = null_()          │
   └─────────────────────────────────────┘

2. Stage: metadata_get
   ┌─────────────────────────────────────┐
   │ Read existing metadata (if any):    │
   │   _lru_count: 5                     │
   │                                     │
   │ ctx.metadata = {                    │
   │   'ttl': 3600,                      │
   │   '_lru_count': 5                   │
   │ }                                   │
   └─────────────────────────────────────┘

3. Stage: metadata_prepare + TTL set hook
   ┌─────────────────────────────────────┐
   │ Convert TTL to timestamp:           │
   │   ttl = 3600                        │
   │   expiresAt = now + 3600s           │
   │                                     │
   │ ctx.metadata = {                    │
   │   'ttl': 3600,                      │
   │   '_ttl_timestamp': 1732013600000,  │
   │   '_lru_count': 5                   │
   │ }                                   │
   └─────────────────────────────────────┘

4. Stage: value_prepare + Encryption hook
   ┌─────────────────────────────────────┐
   │ Encrypt value:                      │
   │   plaintext = ctx.runtime['value']  │
   │   encrypted = encrypt(plaintext)    │
   │                                     │
   │ ctx.runtime = {                     │
   │   'key': 'user:123',                │
   │   'value': <encrypted data>         │
   │ }                                   │
   │                                     │
   │ ctx.metadata = {                    │
   │   ...,                              │
   │   '_encrypted': true                │
   │ }                                   │
   └─────────────────────────────────────┘

5. Stage: value_put
   ┌─────────────────────────────────────┐
   │ Write to DB:                        │
   │   key = 'user:123'                  │
   │   value = <encrypted data>          │
   │                                     │
   │ DB['user:123'] = {                  │
   │   'value': <encrypted data>         │
   │ }                                   │
   └─────────────────────────────────────┘

6. Stage: metadata_put
   ┌─────────────────────────────────────┐
   │ Write to DB:                        │
   │   key = 'user:123'                  │
   │   metadata = ctx.metadata           │
   │                                     │
   │ MetadataDB['user:123'] = {          │
   │   '_ttl_timestamp': 1732013600000,  │
   │   '_lru_count': 5,                  │
   │   '_encrypted': true                │
   │ }                                   │
   └─────────────────────────────────────┘

7. Return to User
   ┌─────────────────────────────────────┐
   │ Resolve return value:               │
   │   source = 'NULL'                   │
   │   → return null                     │
   │   (PUT operations return void)      │
   └─────────────────────────────────────┘
```

## Reserved Keys

### Runtime Keys (Framework)
- `runtime['key']` - Entry key (always set)
- `runtime['value']` - Entry value (main data)
- `runtime['original_value']` - Backup before transformation

### Metadata Keys (User-Provided)
- `metadata['ttl']` - TTL in seconds (user input)
- `metadata['secure']` - Fields to encrypt (selective encryption)
- Any custom keys users want to store

### Metadata Keys (System-Reserved)
All keys starting with `_` are reserved for framework and hooks:
- `metadata['_ttl_timestamp']` - Expiration timestamp (ms)
- `metadata['_lru_count']` - Access counter for LRU
- `metadata['_encrypted']` - Encryption flag
- `metadata['_encryption_nonces']` - Nonce map for selective encryption
- `metadata['_decrypt_failed']` - Decryption failure flag

### Temp Keys (No Restrictions)
Any keys, used for inter-hook communication:
- `temp['validation_result']`
- `temp['access_log']`
- `temp['computed_hash']`

## Context Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│ 1. Creation (by PVCache)                                │
│    ctx = PVRuntimeCtx()                                 │
│    ctx.runtime['key'] = userKey                         │
│    ctx.runtime['value'] = userValue                     │
│    ctx.metadata = userMetadata                          │
└────────────────────┬────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Stage Execution                                      │
│    for stage in compiledStages:                         │
│      - Execute pre-hooks (modify ctx)                   │
│      - Execute stage hook (DB I/O)                      │
│      - Execute post-hooks (modify ctx)                  │
│      - Check ctx.nextStep                               │
│        if break or error: exit                          │
└────────────────────┬────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Return Resolution                                    │
│    switch (ctx.whatToReturn.source):                    │
│      'RUNTIME': return ctx.runtime[key]                 │
│      'METADATA': return ctx.metadata[key]               │
│      'TEMP': return ctx.temp[key]                       │
│      'NULL': return null                                │
│      'LITERAL': return value                            │
└────────────────────┬────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Cleanup                                              │
│    ctx is garbage collected                             │
│    (No persistent references to ctx)                    │
└─────────────────────────────────────────────────────────┘
```

## Transaction Integration

```dart
class PVRuntimeCtx extends PVCtx {
  /// Transaction object (set by framework)
  Transaction? transaction;
  
  /// Helper: Get DB or transaction
  Database getDB() {
    if (transaction != null) {
      return transaction!.database;
    }
    return PVBridge().persistentDatabase;
  }
}
```

### Usage in Stage Hooks

```dart
PVCStageHook(
  name: 'metadata_get',
  hookFunction: (ctx) async {
    final store = PVBridge().getStore(env, storageType);
    final key = ctx.runtime['key'];
    
    // Use transaction if available
    final data = await store.record(key).get(
      ctx.transaction ?? await PVBridge().persistentDatabase
    );
    
    if (data != null) {
      ctx.metadata.addAll(data);
    }
  },
)
```

## Best Practices

### 1. Don't Store Large Data in temp
```dart
// ❌ Bad
ctx.temp['entire_user_list'] = await loadAllUsers();

// ✅ Good
ctx.temp['user_count'] = await countUsers();
```

### 2. Use Descriptive Keys
```dart
// ❌ Bad
ctx.temp['flag'] = true;
ctx.temp['data'] = result;

// ✅ Good
ctx.temp['validation_passed'] = true;
ctx.temp['decryption_result'] = result;
```

### 3. Clean Up temp Between Stages
```dart
hookFunction: (ctx) async {
  // Use temp data
  final validated = ctx.temp['validation_result'];
  
  // Clean up if no longer needed
  ctx.temp.remove('validation_result');
}
```

### 4. Check nextStep After Critical Operations
```dart
hookFunction: (ctx) async {
  if (ctx.nextStep != NextStep.continue_) return;
  
  // Only do expensive work if still continuing
  await expensiveOperation();
}
```

### 5. Set whatToReturn Explicitly for Non-Standard Returns
```dart
hookFunction: (ctx) async {
  // For exists() operation
  final exists = ctx.runtime['value'] != null;
  ctx.whatToReturn = ReturnSpec.literal(exists);
}
```

## Migration from Old Context

| Old (pvcache2) | New (pvcache) | Notes |
|----------------|---------------|-------|
| `ctx.entryValue` | `ctx.runtime['value']` | More flexible |
| `ctx.runtimeMeta` | `ctx.metadata` | Clearer naming |
| `ctx.runtimeData` | `ctx.temp` | Explicit purpose |
| `ctx.returnValue` | `ctx.whatToReturn` | Explicit specification |
| `throw BreakHook()` | `ctx.nextStep = break_` | No exceptions |
| N/A | `ctx.transaction` | New: transaction support |
