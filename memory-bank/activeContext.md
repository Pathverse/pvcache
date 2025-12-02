# Active Context: Current Work Focus

## Current Sprint: HiveHook-Based Implementation

### Active Focus
1. **Simplified Architecture**: PVCache is all-in-one helper, not wrapper
2. **HHPlugin System**: Encryption uses HHPlugin with dynamic IDs
3. **Example Implementation**: Creating proper flutter create example

### Recent Changes (Dec 1, 2025)
1. **Architecture Simplification**: Removed unnecessary wrappers (PVConfig deleted)
2. **PVCache as Helper**: registerConfig, getCache, setDefaultPlugins, setDefaultTHooks
3. **HHPlugin Integration**: Encryption hook uses HHPlugin system with dynamic IDs
4. **Example Creation**: About to implement with flutter create

### Immediate Next Steps
1. **Complete TerminalSerializationHook Migration**
   - Update PVCache.create() to accept TerminalSerializationHook
   - Fix all type references from SerializationHook to TerminalSerializationHook
   - Update documentation
   
2. **Recreate Example with flutter create**
   - Delete manual example directory
   - Run `flutter create example` 
   - Copy proper main.dart with initialization pattern
   - Test all three rotation strategies in Chrome

## Active Decisions

### Decision 1: PVCache as All-in-One Helper
**Status**: DECIDED - Helper, not wrapper
**Rationale**: 
- Don't wrap HHive methods
- Provide helpers: registerConfig, getCache, setDefaultPlugins
- Users use HHConfig directly, not custom wrappers
- Minimal API surface

### Decision 2: HHPlugin System for Encryption
**Status**: DECIDED - Use HHPlugin with dynamic IDs
**Rationale**:
- Follows HiveHook's plugin pattern
- Dynamic ID generation: `pvcache_encryption_0`, `pvcache_encryption_1`
- No need for instance sharing registry
- Clean integration with HiveHook

### Decision 3: Key Rotation Strategies
**Status**: DECIDED - Three strategy pattern
**Strategies**:
- **Passive**: Manual rotation via EncryptionHookController
- **Active**: Auto-rotate on decryption failure
- **Reactive**: Callback decides whether to rotate

**Rationale**: Covers all use cases from manual control to fully automatic

## Critical Patterns Learned

### Pattern 1: PVCache Helper Usage
```dart
// Set default encryption for all configs
final plugin = await createEncryptedHook();
PVCache.setDefaultPlugins([plugin]);

// Register configs
PVCache.registerConfig(env: 'mybox');

// Initialize HiveHook
await HHiveCore.initialize();

// Get cache
final cache = PVCache.getCache('mybox');
```

### Pattern 2: HHPlugin System for Encryption
```dart
Future<HHPlugin> createEncryptedHook() async {
  final keyManager = EncryptionKeyManager(storageKey: 'key');
  await keyManager.initialize();
  
  final hook = _EncryptionTerminalHook(
    keyManager: keyManager,
    id: 'pvcache_encryption_${_counter++}',  // Dynamic ID
  );
  
  return HHPlugin(terminalSerializationHooks: [hook]);
}
```

### Pattern 3: TerminalSerializationHook for Encryption
```dart
class _EncryptionTerminalHook extends TerminalSerializationHook {
  @override
  Future<String> serialize(String value, HHCtxI ctx) async {
    // Encrypt JSON string → base64
  }
  
  @override
  Future<String> deserialize(String value, HHCtxI ctx) async {
    // Decrypt base64 → JSON string
  }
}
    if (autoResetKey) {
      await _clearStorageAndRegenerateKey();
      return _cachedKey!;
    }
    
    // Check providedKey
    if (providedKey != null) {
      _cachedKey = providedKey;
      await _storeKey();
      return _cachedKey!;
    }
    
    // Load from secure storage
    final stored = await _loadKey();
    if (stored != null) {
      _cachedKey = stored;
      return _cachedKey!;
    }
    
    // Auto-generate if enabled
    if (autoGenerateKey) {
      _cachedKey = _generateKey();
      await _storeKey();
      return _cachedKey!;
    }
    
    throw Exception('No encryption key available');
  }
}
```

### Pattern 3: Context Mapping
```dart
// PVCache → HiveHook
HiveCtx _toHiveCtx(PVCtx pvCtx) {
  return HiveCtx(
    key: pvCtx.key,
    value: pvCtx.value,
    metadata: pvCtx.metadata,
  );
}
```

## Current Blockers
None currently - planning phase

## Questions to Resolve
1. How does HiveHook handle async hooks? (Need to study source)
2. Can we access box reference in plugin initialization? (For autoResetKey)
3. What's the best serialization format? (JSON, MessagePack, custom?)
4. Should we support multiple encryption algorithms or just AES-256?

## Learnings and Insights

### Insight 1: What "Implementation Layer" Actually Means
**NOT a wrapper**: PVCache doesn't wrap or abstract HiveHook

**IS a convenience package**:
```dart
// pvcache/lib/pvcache.dart
export 'package:hivehook/hivehook.dart';  // Re-export everything
export 'hooks/encrypted_hook.dart';       // Add encryption plugin
export 'core/pvcache.dart';                // Optional convenience class
export 'core/pvconfig.dart';               // Optional config helper
```

**Users have 3 options**:
1. **Direct HiveHook** (most control):
```dart
import 'package:pvcache/pvcache.dart';
final cache = await HHive.createInstance(HHConfig(...));
await cache.put('key', value);
```

2. **PVConfig helper** (build HHConfig easily):
```dart
import 'package:pvcache/pvcache.dart';
final config = PVConfig.build(encrypted: true, ttlSeconds: 60);
final cache = await HHive.createInstance(config);
```

3. **PVCache convenience** (simplest):
```dart
import 'package:pvcache/pvcache.dart';
final cache = await PVCache.create(name: 'cache', encrypted: true);
```

**All three do the exact same thing** - option 3 just saves typing

### Insight 2: Encryption Complexity
Key management is the hard part, not encryption itself:
- Where to store keys securely
- When to regenerate
- How to handle key rotation
- What to do with existing data

**Solution**: Make it configurable but opinionated

### Insight 3: Hook System Benefits
HiveHook's event-driven architecture allows:
- Clean separation of concerns
- Composable plugins
- Easy testing
- User extensibility

**Key**: Don't fight the hook system, embrace it
