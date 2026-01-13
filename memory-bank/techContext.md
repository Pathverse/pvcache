# Technical Context: PVCache Implementation

## Technology Stack

### Core Dependencies
- **hivehook: ^1.0.0** - Foundation hook system and storage abstraction
- **hive: (via hivehook)** - Cross-platform key-value storage
- **pointycastle: ^3.9.1** - Dart encryption library (AES)
- **flutter_secure_storage: ^9.2.4** - Secure key storage

### Development Dependencies
- **flutter: SDK ^3.10.1**
- **test: any** - Unit testing
- **build_runner: any** - Code generation (if needed)

## Development Setup

### Prerequisites
```bash
flutter pub get
```

### Project Structure
```
pvcache/
├── lib/
│   ├── pvcache.dart              # Main export file (re-exports HiveHook + adds EncryptedHook)
│   ├── core/
│   │   ├── cache.dart            # PVCache thin wrapper over HHive
│   │   └── config.dart           # PVConfig wrapper over HHConfig
│   ├── hooks/
│   │   └── encrypted_hook.dart   # EncryptedHook plugin (AES + key management)
│   └── helper/
│       ├── encryption_key_manager.dart  # Secure key storage
│       └── error_resolve.dart    # Error handling
├── test/
│   ├── cache_test.dart
│   ├── encryption_test.dart
│   └── integration_test.dart
└── example/                      # Demo app
```

**Note**: TTL and LRU plugins already exist in HiveHook (`createTTLPlugin`, `createLRUPlugin`) - PVCache just re-exports them.

## Technical Constraints

### 1. HiveHook Integration
- Must use HiveHook's hook system (don't reimplement)
- PVCtx must map cleanly to HiveCtx
- Plugin interface must match HiveHook's expectations
- Cannot modify HiveHook source - only extend it

### 2. Encryption Requirements
- AES-256 only (32-byte keys)
- Keys must be Uint8List
- Never store keys in plain text
- Flutter Secure Storage is mandatory for key persistence
- Support key rotation with data clear

### 3. Cross-Platform Support
- Web: Must work with Hive web (IndexedDB)
- Mobile: Must work with Hive mobile
- Desktop: Must work with Hive desktop
- No platform-specific code in core logic

### 4. Performance
- Encryption overhead must be minimal
- Key caching required (don't reload from secure storage on every operation)
- Hive's performance characteristics must be preserved

## Key Technical Decisions

### 1. Why HiveHook?
**Chosen**: HiveHook provides proven hook system
**Alternative considered**: Continue with Sembast
**Reasoning**: 
- HiveHook already implements hooks correctly
- Hive is faster than Sembast
- Better web support
- Don't reinvent the wheel

### 2. Encryption Library
**Chosen**: PointyCastle
**Alternative considered**: crypto package
**Reasoning**:
- PointyCastle has full AES implementation
- Works on all platforms
- Mature and well-tested
- No native dependencies

### 3. Key Storage
**Chosen**: Flutter Secure Storage
**Alternative considered**: Shared Preferences, Hive itself
**Reasoning**:
- Secure Storage uses Keychain/Keystore
- Keys never in plain text
- Industry standard for key storage
- Cross-platform

### 4. Serialization Approach
**Chosen**: Hook-based serialization in EncryptedHook
**Alternative considered**: Separate SerializationHook
**Reasoning**:
- Encryption requires serialization anyway
- Simpler for users (one plugin)
- Less overhead
- Can split later if needed

## API Mapping: Sembast → Hive

### Storage Concepts
| Sembast | Hive | Notes |
|---------|------|-------|
| Database | Box | Single namespace |
| Store | Box | One-to-one mapping |
| Record | Entry | Key-value pair |
| Transaction | Batch | Atomic operations |

### Operations
| Sembast | Hive | Implementation |
|---------|------|----------------|
| store.record(key).get() | box.get(key) | Direct mapping |
| store.record(key).put() | box.put(key, value) | Direct mapping |
| store.record(key).delete() | box.delete(key) | Direct mapping |
| store.delete() | box.clear() | Clear all |
| store.find() | box.keys | Iteration |

## Testing Strategy

### Unit Tests
- **Encryption tests**: Key generation, encrypt/decrypt round-trip
- **Key management tests**: Auto-generate, auto-reset, provided key
- **Plugin tests**: TTL expiration, LRU eviction
- **Integration tests**: EncryptedHook + TTL, EncryptedHook + LRU

### Platform Tests
- Web: Run in Chrome (IndexedDB)
- Mobile: iOS Simulator / Android Emulator
- Desktop: macOS/Windows/Linux

### Security Tests
- Verify keys stored in secure storage only
- Verify encrypted data unreadable without key
- Test key rotation clears old data
- Verify no keys in logs/memory dumps

## Migration Path (Sembast → HiveHook)

### Phase 1: Core Migration
1. Replace Db/Ref classes with HiveHook equivalents
2. Update PVCache to use HiveHook context
3. Modify config to use HiveHook config
4. Update tests to use Hive

### Phase 2: Plugin Migration
1. Rewrite TTL plugin for HiveHook
2. Rewrite LRU plugin for HiveHook
3. Create EncryptedHook (new)
4. Test plugin composition

### Phase 3: API Compatibility
1. Ensure PVCache API unchanged
2. Update examples
3. Migration guide for users
4. Deprecation notices if needed

## Environment Variables / Configuration

### Development
```yaml
# pubspec.yaml
dependencies:
  hivehook: ^1.0.0
  hive: ^2.2.3
  pointycastle: ^3.9.1
  flutter_secure_storage: ^9.2.4
```

### Example Usage
```dart
// Initialize Hive (via HiveHook)
await HiveHook.initialize();

// Create encrypted cache
final cache = PVCache.create(
  config: PVConfig(
    'my_cache',
    plugins: [
      EncryptedHook(
        autoGenerateKey: true,
        secureStorageTargetKey: 'cache_key_v1',
      ),
    ],
  ).finalize(),
);
```

## Known Issues / Workarounds

### Issue 1: Hive Web Type Safety
**Problem**: Hive web may return dynamic types
**Workaround**: EncryptedHook handles type conversion

### Issue 2: Flutter Secure Storage on Web
**Problem**: Secure Storage uses local storage on web (not truly secure)
**Workaround**: Document limitation, recommend encryption key from backend for web

### Issue 3: Key Rotation with Active Data
**Problem**: autoResetKey clears ALL data
**Workaround**: Users must backup data before reset, or implement manual migration

## Performance Characteristics

### Encryption Overhead
- AES encryption: ~1-2ms per KB
- Key loading: One-time cost (<10ms)
- Negligible for typical cache sizes (<1MB values)

### Storage Performance
- Hive: Faster than Sembast (~2-5x)
- Web: IndexedDB has async overhead
- Mobile: Very fast (native)

### Memory Usage
- Key cached in memory (32 bytes)
- Hive lazy-loads data
- Minimal overhead from hooks
