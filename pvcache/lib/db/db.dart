import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/enums.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sembast/sembast_memory.dart';

// Conditional imports for platform-specific database factory
// ignore: unused_import
import 'storage_other.dart' if (dart.library.html) 'storage_web.dart';

class Ref {
  final StoreRef<String, Map<String, dynamic>> store;
  final PVImmutableConfig config;
  final Database db;
  Ref(this.store, this.config, this.db);

  // global
  static Future<void> _syncGlobalMetaCache(PVImmutableConfig config) async {
    await Db.mainDb.transaction((txn) async {
      final store = stringMapStoreFactory.store('__pvglobal__');
      final record = await store.record(config.env).get(txn) ?? {};
      Db.globalMetaCache[config.env] = record;
    });
  }

  static Future<Map<String, dynamic>> getGlobalMeta(
    PVImmutableConfig config,
  ) async {
    if (!Db.globalMetaCache.containsKey(config.env)) {
      await _syncGlobalMetaCache(config);
    }
    return Db.globalMetaCache[config.env]!;
  }

  static Future<dynamic> getGlobalMetaValue(
    PVImmutableConfig config,
    String key, {
    dynamic defaultValue = null,
  }) async {
    final globalMeta = await getGlobalMeta(config);
    return globalMeta[key] ?? defaultValue;
  }

  static Future<void> putGlobalMeta(
    PVImmutableConfig config,
    Map<String, dynamic> value,
  ) async {
    // check difference
    if (Db.globalMetaCache[config.env] == value) {
      return;
    }

    Db.globalMetaCache[config.env] = value;
    await Db.mainDb.transaction((txn) async {
      final store = stringMapStoreFactory.store('__pvglobal__');
      await store.record(config.env).put(txn, value);
    });
  }

  static Future<void> updateGlobalMeta(
    PVImmutableConfig config,
    Map<String, dynamic> valueUpdate,
  ) async {
    final current = await getGlobalMeta(config);
    current.addAll(valueUpdate);
    await putGlobalMeta(config, current);
  }

  // record
  Future<Map<String, dynamic>?> getRecord(String key) async {
    return await store.record(key).get(db);
  }

  Future<dynamic> getValue(String key) async {
    final record = await store.record(key).get(db);
    return record != null ? record['value'] : null;
  }

  Future<Map<String, dynamic>> getMetadata(String key) async {
    final record = await store.record(key).get(db);
    return record != null ? record['metadata'] ?? {} : {};
  }

  Future<void> put(
    String key,
    dynamic value,
    Map<String, dynamic> metadata,
  ) async {
    await store.record(key).put(db, {'value': value, 'metadata': metadata});
    final keys = await Ref.getGlobalMetaValue(
      config,
      "keys",
      defaultValue: <String>[],
    );
    if (!keys.contains(key)) {
      keys.add(key);
    }
    await Ref.updateGlobalMeta(config, {"keys": keys});
  }

  Future<void> delete(String key) async {
    await store.record(key).delete(db);
    final keys = await Ref.getGlobalMetaValue(
      config,
      "keys",
      defaultValue: <String>[],
    );
    keys.remove(key);
    await Ref.updateGlobalMeta(config, {"keys": keys});
    await db.compact();
  }

  Future<void> clear() async {
    final keys = await Ref.getGlobalMetaValue(config, "keys", defaultValue: []);
    for (final key in keys) {
      await store.record(key).delete(db);
    }
    await Ref.updateGlobalMeta(config, {"keys": []});
    await db.compact();
  }

  Future<bool> containsKey(String key) async {
    final record = await store.record(key).get(db);
    return record != null;
  }
}

class Db {
  static final Map<String, Database> _dbs = {};
  static late final Database _mainDb;
  static Database get mainDb {
    if (!_isDbInitialized) {
      throw Exception("Database not initialized. Call Db.initialize() first.");
    }
    if (_isTestMode) {
      return memoryDb;
    }
    return _mainDb;
  }

  static late final Database memoryDb;
  static bool _isMemoryDbInitialized = false;
  static bool _isDbInitialized = false;
  static bool _isTestMode = false;
  static const encryptedStore = FlutterSecureStorage();
  static final Map<String, Map<String, dynamic>> globalMetaCache = {};

  static set isTestMode(bool value) {
    if (_isDbInitialized || _isMemoryDbInitialized) {
      throw Exception("Cannot change test mode after DB initialization.");
    }
    _isTestMode = value;
  }

  static Future<void> initialize() async {
    if (_isDbInitialized || (_isTestMode && _isMemoryDbInitialized)) {
      return;
    }

    if (_isTestMode) {
      memoryDb = await databaseFactoryMemory.openDatabase('main_db');
      _isMemoryDbInitialized = true;
      _isDbInitialized = true;
      return;
    }
    // if is web
    if (isWeb) {
      _mainDb = await platformDatabaseFactory.openDatabase("pvcache");
    } else {
      _mainDb = await platformDatabaseFactory.openDatabase('pvcache.db');
    }

    _isDbInitialized = true;
  }

  static Future<Database> getOrCreateDb(PVImmutableConfig config) async {
    if (config.storageType == StorageType.memory) {
      if (!_isMemoryDbInitialized) {
        memoryDb = await databaseFactoryMemory.openDatabase('main_db');
        _isMemoryDbInitialized = true;
      }
      return memoryDb;
    }

    if (_dbs.containsKey(config.env)) {
      return _dbs[config.env]!;
    }
    if (config.storageType == StorageType.separateFilePreferred && !isWeb) {
      final db = await platformDatabaseFactory.openDatabase(
        'pvcache_${config.env}.db',
      );
      _dbs[config.env] = db;
      return db;
    } else {
      return mainDb;
    }
  }

  static Future<Ref> resolve(PVImmutableConfig config) async {
    await initialize();
    final db = await getOrCreateDb(config);
    final store = stringMapStoreFactory.store(config.env);
    return Ref(store, config, db);
  }
}
