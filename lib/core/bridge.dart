import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:pvcache/core/enums.dart';

class PVBridge {
  static final PVBridge _instance = PVBridge._internal();

  // Multiple database instances for different storage types
  static Database? _persistentDatabase;
  static Database? _inMemoryDatabase;

  static final FlutterSecureStorage secureStorage =
      const FlutterSecureStorage();

  // Store caches per database
  final Map<String, StoreRef<String, Map<String, dynamic>>> _persistentStores =
      {};
  final Map<String, StoreRef<String, Map<String, dynamic>>> _inMemoryStores =
      {};

  // Test mode flag - set to true to use in-memory database for testing
  static bool testMode = false;

  factory PVBridge() {
    return _instance;
  }

  PVBridge._internal();

  DatabaseFactory get dbFactory {
    if (kIsWeb) {
      return databaseFactoryWeb;
    } else {
      return databaseFactoryIo;
    }
  }

  /// Get persistent database (sembast or sembast_web)
  Future<Database> get persistentDatabase async {
    if (_persistentDatabase != null) {
      return _persistentDatabase!;
    }

    _persistentDatabase = await _initPersistentDatabase();
    return _persistentDatabase!;
  }

  /// Get in-memory database (always uses sembast memory)
  Future<Database> get inMemoryDatabase async {
    if (_inMemoryDatabase != null) {
      return _inMemoryDatabase!;
    }

    _inMemoryDatabase = await databaseFactoryMemory.openDatabase(
      'pvcache_memory.db',
    );
    return _inMemoryDatabase!;
  }

  /// Get database based on storage type
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

  /// Get the store for a specific environment and storage type
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
