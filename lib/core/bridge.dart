import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:pvcache/core/enums.dart';

/// Storage abstraction layer for PVCache that manages multiple database backends.
///
/// PVBridge is a singleton that handles:
/// - Platform-specific database initialization (web vs mobile/desktop)
/// - Multiple storage backends (persistent, in-memory)
/// - Database routing based on [StorageType]
/// - Store management for different environments
/// - Secure storage integration
///
/// It automatically detects the platform and uses the appropriate database:
/// - Web: sembast_web (IndexedDB)
/// - Mobile/Desktop: sembast_io (file-based)
/// - Testing: sembast_memory (in-memory)
///
/// Example:
/// ```dart
/// // Get bridge instance
/// final bridge = PVBridge();
///
/// // Get database for storage type
/// final db = await bridge.getDatabaseForType(StorageType.stdSembast);
///
/// // Get store for environment
/// final store = bridge.getStore('prod', StorageType.stdSembast);
/// ```
class PVBridge {
  /// Singleton instance of PVBridge.
  static final PVBridge _instance = PVBridge._internal();

  /// Persistent database instance (sembast or sembast_web).
  ///
  /// Stored at:
  /// - Web: IndexedDB (name: 'pvcache')
  /// - Mobile/Desktop: Application documents directory ('pvcache.db')
  /// - Test mode: In-memory ('test.db')
  static Database? _persistentDatabase;

  /// In-memory database instance (always sembast_memory).
  ///
  /// Data is lost when app closes. Good for:
  /// - Session data
  /// - Temporary caches
  /// - Testing
  static Database? _inMemoryDatabase;

  /// Flutter secure storage instance for encryption keys and sensitive data.
  ///
  /// Used by encryption hooks to store encryption keys securely
  /// in the platform keychain/keystore.
  static final FlutterSecureStorage secureStorage =
      const FlutterSecureStorage();

  /// Sembast stores for persistent storage, keyed by environment name.
  final Map<String, StoreRef<String, Map<String, dynamic>>> _persistentStores =
      {};

  /// Sembast stores for in-memory storage, keyed by environment name.
  final Map<String, StoreRef<String, Map<String, dynamic>>> _inMemoryStores =
      {};

  /// Test mode flag - when true, uses in-memory database for persistent storage.
  ///
  /// Enable this in your test setup:
  /// ```dart
  /// setUp(() {
  ///   PVBridge.testMode = true;
  /// });
  /// ```
  static bool testMode = false;

  /// Factory constructor returns the singleton instance.
  factory PVBridge() {
    return _instance;
  }

  /// Private constructor for singleton pattern.
  PVBridge._internal();

  /// Get the appropriate database factory for the current platform.
  ///
  /// Returns:
  /// - Web: [databaseFactoryWeb] (IndexedDB backend)
  /// - Other: [databaseFactoryIo] (file-based backend)
  DatabaseFactory get dbFactory {
    if (kIsWeb) {
      return databaseFactoryWeb;
    } else {
      return databaseFactoryIo;
    }
  }

  /// Get or initialize the persistent database.
  ///
  /// Database location depends on platform and mode:
  /// - Web: IndexedDB with name 'pvcache'
  /// - Mobile/Desktop: `<app_documents>/pvcache.db`
  /// - Test mode: In-memory 'test.db'
  ///
  /// The database is lazily initialized on first access and reused thereafter.
  ///
  /// Returns: Initialized sembast [Database] instance.
  ///
  /// Example:
  /// ```dart
  /// final db = await bridge.persistentDatabase;
  /// final store = stringMapStoreFactory.store('myStore');
  /// await store.record('key').put(db, {'value': 'data'});
  /// ```
  Future<Database> get persistentDatabase async {
    if (_persistentDatabase != null) {
      return _persistentDatabase!;
    }

    _persistentDatabase = await _initPersistentDatabase();
    return _persistentDatabase!;
  }

  /// Get or initialize the in-memory database.
  ///
  /// Uses sembast_memory regardless of platform. Data is stored in RAM
  /// and lost when the app closes.
  ///
  /// Good for:
  /// - Session-scoped data (auth tokens, user state)
  /// - Temporary caches that don't need persistence
  /// - Performance-critical caches
  /// - Testing
  ///
  /// Returns: Initialized in-memory [Database] instance.
  ///
  /// Example:
  /// ```dart
  /// final db = await bridge.inMemoryDatabase;
  /// // Data here is lost on app restart
  /// ```
  Future<Database> get inMemoryDatabase async {
    if (_inMemoryDatabase != null) {
      return _inMemoryDatabase!;
    }

    _inMemoryDatabase = await databaseFactoryMemory.openDatabase(
      'pvcache_memory.db',
    );
    return _inMemoryDatabase!;
  }

  /// Get the appropriate database for the given storage type.
  ///
  /// Routes to the correct database backend:
  /// - [StorageType.inMemory]: In-memory database
  /// - [StorageType.stdSembast]: Persistent database
  /// - [StorageType.secureStorage]: Throws [UnsupportedError] (uses flutter_secure_storage directly)
  ///
  /// Parameters:
  /// - [type]: The storage type to get the database for.
  ///
  /// Returns: Initialized [Database] for the storage type.
  ///
  /// Throws: [UnsupportedError] if called with [StorageType.secureStorage].
  ///
  /// Example:
  /// ```dart
  /// // Get persistent database
  /// final db = await bridge.getDatabaseForType(StorageType.stdSembast);
  ///
  /// // Get in-memory database
  /// final memDb = await bridge.getDatabaseForType(StorageType.inMemory);
  /// ```
  Future<Database> getDatabaseForType(StorageType type) async {
    switch (type) {
      case StorageType.inMemory:
        return await inMemoryDatabase;
      case StorageType.stdSembast:
        return await persistentDatabase;
      case StorageType.secureStorage:
        throw UnsupportedError('Secure storage does not use sembast database');
    }
  }

  /// Initialize the persistent database based on platform and mode.
  ///
  /// Platform-specific initialization:
  /// - Test mode: In-memory database ('test.db')
  /// - Web: IndexedDB ('pvcache')
  /// - Mobile/Desktop: File-based (`<app_documents>/pvcache.db`)
  ///
  /// Returns: Initialized [Database] instance.
  Future<Database> _initPersistentDatabase() async {
    if (testMode) {
      // Use in-memory database for testing
      return await databaseFactoryMemory.openDatabase('test.db');
    } else if (kIsWeb) {
      // For web, just pass the database name (stored in IndexedDB)
      return await dbFactory.openDatabase('pvcache');
    } else {
      // For mobile/desktop, use the full path
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = join(appDocDir.path, 'pvcache.db');
      return await dbFactory.openDatabase(dbPath);
    }
  }

  /// Close all open databases and reset state.
  ///
  /// Cleanly closes both persistent and in-memory databases.
  /// Should be called when shutting down the app or in test tearDown.
  ///
  /// Example:
  /// ```dart
  /// // In test tearDown
  /// tearDown(() async {
  ///   await PVBridge().close();
  /// });
  /// ```
  Future<void> close() async {
    if (_persistentDatabase != null) {
      await _persistentDatabase!.close();
      _persistentDatabase = null;
    }
    if (_inMemoryDatabase != null) {
      await _inMemoryDatabase!.close();
      _inMemoryDatabase = null;
    }
  }

  /// Get or create a sembast store for the given environment and storage type.
  ///
  /// Stores are sembast's equivalent to tables. Each environment gets its own
  /// store to keep data isolated. Stores are cached and reused.
  ///
  /// Parameters:
  /// - [env]: Environment name (e.g., 'dev', 'prod', 'test').
  /// - [type]: Storage type ([StorageType.inMemory] or [StorageType.stdSembast]).
  ///
  /// Returns: [StoreRef] for accessing the store's records.
  ///
  /// Example:
  /// ```dart
  /// // Get store for 'prod' environment with persistent storage
  /// final store = bridge.getStore('prod', StorageType.stdSembast);
  ///
  /// // Use the store
  /// final db = await bridge.persistentDatabase;
  /// await store.record('user:123').put(db, {'name': 'Alice'});
  /// ```
  StoreRef<String, Map<String, dynamic>> getStore(
    String env,
    StorageType type,
  ) {
    final stores = type == StorageType.inMemory
        ? _inMemoryStores
        : _persistentStores;
    return stores.putIfAbsent(env, () => stringMapStoreFactory.store(env));
  }
}
