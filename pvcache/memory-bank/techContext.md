# Technical Context

## Technology Stack

### Core Dependencies
- **Flutter**: ^3.10.1 minimum SDK
- **sembast**: ^3.8.5+1 - NoSQL database for Flutter
- **sembast_web**: ^2.4.2 - Web platform support
- **sembast_sqflite**: ^2.2.0+2 - SQLite backend for mobile
- **sqflite**: ^2.4.1 - SQLite plugin for Flutter
- **flutter_secure_storage**: ^9.2.4 - Secure key-value storage
- **crypto**: ^3.0.3 - Cryptographic functions
- **pointycastle**: ^3.9.1 - Encryption algorithms
- **path_provider**: ^2.1.4 - File system paths
- **path**: ^1.9.0 - Path manipulation

### Development Dependencies
- **test**: ^1.28.0 - Unit testing framework

## Platform Support

### Mobile (iOS/Android)
- **Database**: sembast_sqflite → SQLite files
- **Location**: App documents directory
- **Files**: `pvcache.db`, `pvcache_{env}.db`

### Web
- **Database**: sembast_web → IndexedDB
- **Location**: Browser storage
- **Database name**: `pvcache`

### Conditional Imports
```dart
import 'storage_other.dart' if (dart.library.html) 'storage_web.dart';
```

When `dart.library.html` is available (web), imports `storage_web.dart`, otherwise `storage_other.dart`.

## Storage Architecture

### Sembast Concepts
- **Database**: File or IndexedDB container
- **Store**: Namespace within database (like a table)
- **Record**: Key-value pair within store
- **StoreRef**: Reference to a store (lightweight, just metadata)
- **Transaction**: Atomic operations

### Store Structure
```
Database: pvcache.db
├── Store: "__pvglobal__"
│   └── Record: {env} → {keys: [...], ...}
├── Store: "production"
│   └── Record: "user_token" → {value: ..., metadata: ...}
├── Store: "staging"
│   └── Record: "user_token" → {value: ..., metadata: ...}
```

### Global Metadata Store
- **Store name**: `__pvglobal__`
- **Keys**: Environment names
- **Values**: `{keys: [list of all keys in env], ...}`
- **Purpose**: Track all keys per environment for clear() operations

## Technical Constraints

### Database Initialization
- Must call `Db.initialize()` before first use
- Initialization is idempotent (safe to call multiple times)
- Test mode must be set BEFORE initialization
- Once initialized, cannot change test mode

### Store References
- Creating a `StoreRef` is synchronous and cheap
- Same store name on different databases = different data
- Store operations require both StoreRef AND Database instance

### Memory Management
- Global metadata cached in-memory for performance
- Cache invalidation via `_syncGlobalMetaCache()`
- Lazy loading: only load metadata when first accessed per environment

### Transactions
- All global metadata updates use transactions
- Ensures atomic updates to cache registry
- Transaction context passed to store operations

### Platform Differences
- **Web**: Single database name (no file paths)
- **Mobile**: Multiple database files possible
- **isWeb** flag resolved at compile time via conditional imports

## Development Setup

### Project Structure
```
lib/
├── pvcache.dart           # Public API exports
├── core/                  # Business logic
│   ├── cache.dart         # PVCache main class
│   ├── config.dart        # Configuration classes
│   ├── enums.dart         # Enums (StorageType, ValueType, etc.)
│   ├── ctx/               # Context classes
│   └── hooks/             # Hook system
├── db/                    # Database layer
│   ├── db.dart            # Db and Ref classes
│   ├── storage_web.dart   # Web platform
│   └── storage_other.dart # Mobile platforms
├── helper/                # Utilities
└── utils/                 # Shared utilities
```

### Testing
- Use `Db.isTestMode = true` before any database operations
- Test mode uses in-memory database (no file I/O)
- Reset state between tests by clearing `_instances` maps

## Tool Usage Patterns

### Creating a Store Reference
```dart
final store = stringMapStoreFactory.store('store_name');
```

### Database Operations
```dart
// Get value
final record = await store.record(key).get(database);

// Put value
await store.record(key).put(database, value);

// Delete value
await store.record(key).delete(database);
```

### Transactions
```dart
await database.transaction((txn) async {
  await store.record(key).put(txn, value);
  await store.record(key2).put(txn, value2);
});
```

### Database Factory
```dart
// Mobile
final db = await platformDatabaseFactory.openDatabase('file.db');

// Web
final db = await platformDatabaseFactory.openDatabase('dbname');

// Memory (testing)
final db = await databaseFactoryMemory.openDatabase('test_db');
```

## Critical Technical Details

### Why Sembast?
- **Cross-platform**: Works on mobile and web
- **NoSQL**: Flexible schema for cache data
- **Transactions**: Atomic operations
- **Lightweight**: No complex SQL, easy to use
- **Type-safe**: Strong typing with generics

### Store Ref Pattern
Store references are just pointers - they don't hold data. This allows:
- Creating multiple refs to same store (cheap)
- Storing database instance separately
- Using same store name across different databases

### Encryption Integration
- ValueType enum indicates encryption needed
- flutter_secure_storage for key storage
- crypto/pointycastle for encryption operations
- **Not yet implemented** in current db.dart

### Compaction
`await db.compact()` called after delete operations to reclaim space and optimize performance.
