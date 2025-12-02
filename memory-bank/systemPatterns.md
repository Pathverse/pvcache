# System Patterns: PVCache Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────┐
│         PVCache (package)               │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Re-exports (from HiveHook):     │  │
│  │  - HHive, HHConfig               │  │
│  │  - createTTLPlugin               │  │
│  │  - createLRUPlugin               │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  New Addition:                   │  │
│  │  - createEncryptedHook()         │  │
│  │  - EncryptionKeyManager          │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Optional Convenience:           │  │
│  │  - PVCache (delegates to HHive)  │  │
│  │  - PVConfig (builds HHConfig)    │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
                    │
                    │ Users call HHive methods directly
                    ▼
┌─────────────────────────────────────────┐
│        HiveHook (HHive)                 │
│  - Hook System (pre/post actions)       │
│  - Cache Operations (get/put/delete)    │
│  - Plugin System                        │
│  - createTTLPlugin, createLRUPlugin     │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Hive (BoxCollection)            │
│  - Cross-platform persistence           │
│  - Fast key-value storage               │
│  - Web/Mobile/Desktop support           │
└─────────────────────────────────────────┘
```

**Key Point**: PVCache doesn't wrap or hide HiveHook. It's an additive package that bundles HiveHook + encryption plugin.

## Core Components

### 1. PVCache (Optional Convenience Class)
**Responsibility**: Simplify HHive usage for common patterns
- **Optional** - users can use HHive directly instead
- Provides simplified factory method
- Delegates ALL methods directly to HHive instance
- No additional logic or abstraction

**Implementation**:
```dart
class PVCache {
  final HHive _hive;
  
  PVCache._(this._hive);
  
  static Future<PVCache> create({
    required String name,
    bool encrypted = false,
    int? ttlSeconds,
    int? maxSize,
  }) async {
    final plugins = <HHPlugin>[];
    if (encrypted) plugins.add(createEncryptedHook(autoGenerateKey: true));
    if (ttlSeconds != null) plugins.add(createTTLPlugin(defaultTTLSeconds: ttlSeconds));
    if (maxSize != null) plugins.add(createLRUPlugin(maxSize: maxSize));
    
    final hive = await HHive.createInstance(HHConfig(name, usesMeta: true, plugins: plugins));
    return PVCache._(hive);
  }
  
  // All methods delegate to _hive
  Future<T?> get<T>(String key) => _hive.get<T>(key);
  Future<void> put<T>(String key, T value) => _hive.put(key, value);
  // ... etc
}
```

**Users can skip PVCache entirely and use HHive directly.**

### 2. PVConfig (Optional Helper)
**Responsibility**: Build HHConfig with company defaults
- **Optional** - users can construct HHConfig directly
- Provides simplified builder pattern
- Returns HHConfig for use with HHive
- No state management or runtime behavior

**Implementation**:
```dart
class PVConfig {
  static HHConfig build({
    required String name,
    bool encrypted = false,
    int? ttlSeconds,
    int? maxSize,
  }) {
    final plugins = <HHPlugin>[];
    if (encrypted) plugins.add(createEncryptedHook(autoGenerateKey: true));
    if (ttlSeconds != null) plugins.add(createTTLPlugin(defaultTTLSeconds: ttlSeconds));
    if (maxSize != null) plugins.add(createLRUPlugin(maxSize: maxSize));
    
    return HHConfig(name, usesMeta: plugins.isNotEmpty, plugins: plugins);
  }
}
```

**Users can skip this and construct HHConfig directly.**

### 3. No Custom Context
**PVCache doesn't create its own context types**
- Users work directly with HiveHook's API
- No PVCtx - operations use simple key/value parameters
- Metadata handled by HiveHook internally when plugins need it

### 4. EncryptedHook (Plugin)
**Responsibility**: Encryption/decryption with key management

**Architecture**:
```
┌─────────────────────────────────────────┐
│         EncryptedHook                   │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  Key Management                   │ │
│  │  - Load from secure storage       │ │
│  │  - Generate if missing            │ │
│  │  - Reset with storage clear       │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  Pre-Put Hook                     │ │
│  │  - Serialize value                │ │
│  │  - Encrypt with AES               │ │
│  │  - Store encrypted bytes          │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  Post-Get Hook                    │ │
│  │  - Decrypt bytes                  │ │
│  │  - Deserialize value              │ │
│  │  - Return original data           │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Hook Points**:
- `pre:put` - Encrypt before storing
- `post:get` - Decrypt after retrieving
- `pre:initialize` - Load/generate key

**Key Management Flow**:
```
Start
  │
  ├─ autoResetKey? ──Yes──> Clear storage, Generate new key
  │                          Store in secure storage
  │                          ↓
  ├─ providedKey exists? ──Yes──> Use providedKey
  │                                Optionally store it
  │                                ↓
  ├─ Key in secure storage? ──Yes──> Load key
  │                                   ↓
  └─ autoGenerateKey? ──Yes──> Generate new AES-256 key
                                Store in secure storage
                                ↓
                             Use key for encryption
```

### 5. TTL Plugin (Time-to-Live)
**Responsibility**: Automatic expiration
- Stores expiration timestamp in metadata
- Checks on get/iterate operations
- Deletes expired items
- Inherits from HiveHook plugin system

### 6. LRU Plugin (Least Recently Used)
**Responsibility**: Size-based eviction
- Tracks access order
- Evicts oldest when size exceeded
- Updates access time on get
- Works with HiveHook's hook system

## Key Design Patterns

### 1. Adapter Pattern
PVCache adapts HiveHook's API to provide cache-specific functionality:
```
PVCache.get() → HiveHook hooks → Hive storage
PVCtx → HiveCtx mapping
PVConfig → HiveHook config
```

### 2. Plugin/Hook Pattern
All plugins implement HiveHook's plugin interface:
- Pre-action hooks (before operation)
- Post-action hooks (after operation)
- Composable via configuration

### 3. Key Management Pattern
**EncryptedHook Key Lifecycle**:
1. **Initialization**: Check secure storage
2. **Generation**: Create if missing (when autoGenerateKey=true)
3. **Reset**: Clear and regenerate (when autoResetKey=true)
4. **Caching**: Keep key in memory during app lifetime
5. **Persistence**: Always store in Flutter Secure Storage

### 4. Context Flow Pattern
Every operation flows through context:
```
User calls cache.get(PVCtx(key: 'user'))
  ↓
PVCache wraps in HiveCtx
  ↓
HiveHook executes pre-hooks (decrypt if EncryptedHook present)
  ↓
Hive retrieves data
  ↓
HiveHook executes post-hooks
  ↓
Return decrypted value to user
```

## Critical Implementation Paths

### Path 1: Encrypted Put Operation
```
1. User: cache.put(PVCtx(key: 'data', value: obj))
2. PVCache: Convert to HiveCtx
3. EncryptedHook (pre:put):
   - Serialize obj to bytes
   - Encrypt bytes with AES key
   - Replace value with encrypted bytes
4. HiveHook: Execute put operation
5. Hive: Store encrypted bytes
6. Return success
```

### Path 2: Encrypted Get Operation
```
1. User: cache.get(PVCtx(key: 'data'))
2. PVCache: Convert to HiveCtx
3. HiveHook: Execute get operation
4. Hive: Return encrypted bytes
5. EncryptedHook (post:get):
   - Decrypt bytes with AES key
   - Deserialize to original type
   - Replace value with decrypted obj
6. Return decrypted obj to user
```

### Path 3: Key Reset Flow
```
1. User creates config with autoResetKey=true
2. EncryptedHook initialization:
   - Get box reference from HiveHook
   - Clear all data in box
   - Generate new AES-256 key
   - Store key in secure storage (secureStorageTargetKey)
   - Cache key in memory
3. Ready for encrypted operations with new key
```

## Technology Stack Integration

### Encryption Stack
- **PointyCastle**: AES-256-CBC encryption
- **Flutter Secure Storage**: Key persistence
- **dart:typed_data**: Uint8List for key/data

### Storage Stack
- **HiveHook**: Hook system and context management
- **Hive**: Underlying storage engine
- **Hive Web**: IndexedDB adapter
- **Hive Mobile**: SQLite adapter

### Platform Support
- Web: Hive web (IndexedDB)
- iOS/Android: Hive mobile
- Desktop: Hive desktop
- All via unified HiveHook interface
