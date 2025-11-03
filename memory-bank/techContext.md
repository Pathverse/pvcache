# Technical Context: PVCache

## Technology Stack

### Core Framework
- **Flutter**: Cross-platform UI framework
- **Dart**: 3.9.2+
- **Flutter SDK**: 1.17.0+

### Primary Dependencies

#### Storage
- **sembast** (3.8.5+1)
  - NoSQL database for mobile/desktop
  - Document-based storage
  - Supports transactions and queries
  
- **sembast_web** (2.4.2)
  - Web implementation using IndexedDB
  - Same API as sembast for consistency

- **flutter_secure_storage** (9.2.4)
  - Encrypted storage for sensitive data
  - Platform-specific secure storage (Keychain on iOS, KeyStore on Android)
  - Not available on all platforms (web has limitations)

#### File System
- **path_provider** (2.1.4)
  - Locates appropriate directories for database files
  - Platform-specific paths (Documents, Application Support, etc.)

- **path** (1.9.0)
  - Path manipulation utilities
  - Cross-platform path operations

### Development Dependencies
- **flutter_test**: Testing framework
- **flutter_lints** (5.0.0): Code quality rules

## Project Structure

```
lib/
├── pvcache.dart           # Package exports (currently empty)
├── core/
│   ├── cache.dart         # PVCache main class
│   ├── ctx.dart           # PVCtx context object
│   ├── hook.dart          # PVCacheHook definition
│   ├── enums.dart         # ActionType, EventFlow, StorageType
│   ├── bridge.dart        # PVBridge storage manager
│   └── top.dart           # PVTop global state (currentEnv)
└── templates/             # (Empty - future plugin templates)

example/                   # (Empty - future usage examples)
test/                      # (Future test files)
```

## Platform Support

### Web
- Uses `sembast_web` with IndexedDB
- Database stored in browser storage
- Secure storage has limitations (uses local storage fallback)

### Mobile (iOS/Android)
- Uses `sembast` with file system storage
- Database in app documents directory
- Full secure storage support (Keychain/KeyStore)

### Desktop (macOS/Windows/Linux)
- Uses `sembast` with file system storage
- Database in app documents directory
- Secure storage support varies by platform

## Development Setup

### Prerequisites
- Flutter SDK (1.17.0+)
- Dart SDK (3.9.2+)

### Installation
```bash
flutter pub get
```

### Running Example
```bash
flutter run -d <device> example/main.dart
```

### Testing
```bash
flutter test
```

## Technical Constraints

### Platform Detection
- Use `kIsWeb` from `package:flutter/foundation.dart`
- Determines whether to use sembast or sembast_web
- Affects database path resolution

### Database Initialization
- **Web**: Database name only (stored in IndexedDB)
- **Native**: Full file path required
- Singleton pattern prevents multiple connections

### Secure Storage Limitations
- Not all platforms support secure storage
- Web uses local storage (not truly secure)
- Consider fallback strategies

### Memory Management
- `inMemoryCacheSize` limits in-memory storage
- Balance between performance and memory usage
- Default: 1000 entries

## Hook Implementation Considerations

### Async Operations
- All hook functions are `Future<void>`
- Hooks execute sequentially (no parallel execution within same operation)
- Context mutations are immediately visible to subsequent hooks

### Error Handling
- Currently no error handling in `queue()` method
- Hooks should handle their own errors or allow propagation
- Failed hooks may leave context in inconsistent state

### Performance
- Hook ordering is pre-computed (not done per operation)
- Context object is mutable (no copies between hooks)
- In-memory cache reduces database calls

## Build Configuration
- Package name: `pvcache`
- Version: 0.0.1
- Homepage: https://github.com/Pathverse/pvcache
- Analysis options: Standard configuration
- License: Defined in LICENSE file
