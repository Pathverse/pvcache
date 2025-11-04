import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:pvcache/core/enums.dart';

/// Storage abstraction layer managing multiple database backends.
///
/// Singleton that handles:
/// - Platform-specific initialization (web vs mobile/desktop)
/// - Multiple storage backends (persistent, in-memory)
/// - Database routing by [StorageType]
/// - Store management
/// - Secure storage integration
///
/// Example:
/// ```dart
/// final bridge = PVBridge();
/// final db = await bridge.getDatabaseForType(StorageType.stdSembast);
/// final store = bridge.getStore('prod', StorageType.stdSembast);
/// ```
class PVBridge {
  /// Singleton instance of PVBridge.
  static final PVBridge _instance = PVBridge._internal();

  /// Persistent database instance (sembast or sembast_web).
  static Database? _persistentDatabase;

  /// In-memory database instance (sembast_memory).
  static Database? _inMemoryDatabase;

  /// Flutter secure storage for encryption keys and sensitive data.
  static final FlutterSecureStorage secureStorage =
      const FlutterSecureStorage();

  /// Sembast stores for persistent storage by environment.
  final Map<String, StoreRef<String, Map<String, dynamic>>> _persistentStores =
      {};

  /// Sembast stores for in-memory storage by environment.
  final Map<String, StoreRef<String, Map<String, dynamic>>> _inMemoryStores =
      {};

  /// Test mode flag - uses in-memory database for persistent storage.
  static bool testMode = false;

  /// Factory constructor returns the singleton instance.
  factory PVBridge() {
    return _instance;
  }

  /// Private constructor for singleton pattern.
  PVBridge._internal();

  /// Get database factory for current platform.
  ///
  /// Web: databaseFactoryWeb, Other: databaseFactoryIo
  DatabaseFactory get dbFactory {
    if (kIsWeb) {
      return databaseFactoryWeb;
    } else {
      return databaseFactoryIo;
    }
  }

  /// Get or initialize persistent database.
  ///
  /// Location: Web (IndexedDB 'pvcache'), Mobile/Desktop (app_documents/pvcache.db), Test (memory 'test.db')
  Future<Database> get persistentDatabase async {
    if (_persistentDatabase != null) {
      return _persistentDatabase!;
    }

    _persistentDatabase = await _initPersistentDatabase();
    return _persistentDatabase!;
  }

  /// Get or initialize in-memory database.
  ///
  /// Data in RAM, lost on app close. Good for sessions, temp caches, testing.
  Future<Database> get inMemoryDatabase async {
    if (_inMemoryDatabase != null) {
      return _inMemoryDatabase!;
    }

    _inMemoryDatabase = await databaseFactoryMemory.openDatabase(
      'pvcache_memory.db',
    );
    return _inMemoryDatabase!;
  }

  /// Get database for the storage type.
  ///
  /// Throws [UnsupportedError] for secureStorage (uses flutter_secure_storage directly).
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

  /// Initialize persistent database by platform.
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

  /// Close all databases and reset state.
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

  /// Get or create sembast store for environment and storage type.
  ///
  /// Stores are cached and reused.
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
