part of 'cache.dart';

class PVCtx {
  final PVCache cache;
  final ActionType actionType;
  // initial
  final String? initialKey;
  final dynamic initialEntryValue;
  final Map<String, dynamic> initialMeta;

  // runtime
  late String? resolvedKey;
  late String? resolvedMetaKey;
  late dynamic entryValue;
  Map<String, dynamic> runtimeMeta = {};

  late dynamic returnValue;

  final Map<String, dynamic> runtimeData = {};

  PVCtx({
    required this.cache,
    required this.actionType,
    this.initialKey,
    this.initialEntryValue,
    required this.initialMeta,
  }) {
    resolvedKey = initialKey;
    resolvedMetaKey = initialMeta['key'] ?? '';
    entryValue = initialEntryValue;
    runtimeMeta = {};
  }

  Future<void> queue(List<PVCacheHook> hooks) async {
    try {
      // Group hooks by EventFlow
      final hooksByFlow = <EventFlow, List<PVCacheHook>>{};
      for (final hook in hooks) {
        hooksByFlow.putIfAbsent(hook.eventFlow, () => []).add(hook);
      }

      // preProcess
      await _runHooks(hooksByFlow[EventFlow.preProcess]);

      // metaRead - automatically read metadata FIRST, then run hooks
      if (resolvedKey != null) {
        final metaData = await meta.get(resolvedKey!);
        if (metaData != null) {
          // Create a mutable copy of the metadata
          runtimeMeta = Map<String, dynamic>.from(metaData);
        }
      }
      await _runHooks(hooksByFlow[EventFlow.metaRead]);

      // metaUpdatePriorEntry - update metadata before entry operation
      await _runHooks(hooksByFlow[EventFlow.metaUpdatePriorEntry]);

      // storageRead - automatically read entry (for get operations)
      if (actionType == ActionType.get || actionType == ActionType.exists) {
        await _runHooks(hooksByFlow[EventFlow.storageRead]);
        if (resolvedKey != null) {
          final entryData = await entry.get(resolvedKey!);
          if (entryData != null) {
            entryValue = entryData['value'];
          }
        }
      }

      // storageUpdate - automatically write entry (for put operations)
      if (actionType == ActionType.put) {
        await _runHooks(hooksByFlow[EventFlow.storageUpdate]);
        if (resolvedKey != null && entryValue != null) {
          await entry.put(resolvedKey!, {'value': entryValue});
        }
      }

      // delete operation
      if (actionType == ActionType.delete) {
        await _runHooks(hooksByFlow[EventFlow.storageUpdate]);
        if (resolvedKey != null) {
          await entry.delete(resolvedKey!);
          await meta.delete(resolvedKey!);
        }
      }

      // metaUpdatePostEntry - update metadata after entry operation
      await _runHooks(hooksByFlow[EventFlow.metaUpdatePostEntry]);
      if (resolvedKey != null && runtimeMeta.isNotEmpty) {
        await meta.put(resolvedKey!, runtimeMeta);
      }

      // postProcess
      await _runHooks(hooksByFlow[EventFlow.postProcess]);
    } on BreakHook catch (e) {
      if (e.returnType == BreakReturnType.initial) {
        returnValue = initialEntryValue;
      } else if (e.returnType == BreakReturnType.resolved) {
        returnValue = entryValue;
      } else {
        returnValue = null;
      }
      return;
    }
    returnValue = entryValue;
  }

  Future<void> _runHooks(List<PVCacheHook>? hooks) async {
    if (hooks == null) return;
    for (final hook in hooks) {
      await hook.hookFunction(this);
    }
  }

  PVCtxStorageProxy get entry => PVCtxStorageProxy(
    ctx: this,
    storageType: cache.entryStorageType,
    isMetadata: false,
  );

  PVCtxStorageProxy get meta => PVCtxStorageProxy(
    ctx: this,
    storageType: cache.metadataStorageType,
    isMetadata: true,
  );
}

class PVCtxStorageProxy {
  final PVCtx ctx;
  final StorageType storageType;
  final bool isMetadata;

  PVCtxStorageProxy({
    required this.ctx,
    required this.storageType,
    required this.isMetadata,
  });

  Future<Map<String, dynamic>?> get(String key) async {
    switch (storageType) {
      case StorageType.inMemory:
        final bridge = PVBridge();
        final db = await bridge.getDatabaseForType(storageType);
        final storeName = isMetadata
            ? ctx.cache.metadataNameFunction!(ctx.cache.env)
            : ctx.cache.env;
        final store = bridge.getStore(storeName, storageType);
        return await store.record(key).get(db);

      case StorageType.stdSembast:
        final bridge = PVBridge();
        final db = await bridge.getDatabaseForType(storageType);
        final storeName = isMetadata
            ? ctx.cache.metadataNameFunction!(ctx.cache.env)
            : ctx.cache.env;
        final store = bridge.getStore(storeName, storageType);
        return await store.record(key).get(db);

      case StorageType.secureStorage:
        final value = await PVBridge.secureStorage.read(key: key);
        if (value == null) return null;
        // Parse JSON from secure storage
        return {'value': value};
    }
  }

  Future<void> put(String key, Map<String, dynamic> value) async {
    switch (storageType) {
      case StorageType.inMemory:
        final bridge = PVBridge();
        final db = await bridge.getDatabaseForType(storageType);
        final storeName = isMetadata
            ? ctx.cache.metadataNameFunction!(ctx.cache.env)
            : ctx.cache.env;
        final store = bridge.getStore(storeName, storageType);
        await store.record(key).put(db, value);
        break;

      case StorageType.stdSembast:
        final bridge = PVBridge();
        final db = await bridge.getDatabaseForType(storageType);
        final storeName = isMetadata
            ? ctx.cache.metadataNameFunction!(ctx.cache.env)
            : ctx.cache.env;
        final store = bridge.getStore(storeName, storageType);
        await store.record(key).put(db, value);
        break;

      case StorageType.secureStorage:
        // Convert to JSON string for secure storage
        await PVBridge.secureStorage.write(
          key: key,
          value: value['value'].toString(),
        );
        break;
    }
  }

  Future<void> delete(String key) async {
    switch (storageType) {
      case StorageType.inMemory:
        final bridge = PVBridge();
        final db = await bridge.getDatabaseForType(storageType);
        final storeName = isMetadata
            ? ctx.cache.metadataNameFunction!(ctx.cache.env)
            : ctx.cache.env;
        final store = bridge.getStore(storeName, storageType);
        await store.record(key).delete(db);
        break;

      case StorageType.stdSembast:
        final bridge = PVBridge();
        final db = await bridge.getDatabaseForType(storageType);
        final storeName = isMetadata
            ? ctx.cache.metadataNameFunction!(ctx.cache.env)
            : ctx.cache.env;
        final store = bridge.getStore(storeName, storageType);
        await store.record(key).delete(db);
        break;

      case StorageType.secureStorage:
        await PVBridge.secureStorage.delete(key: key);
        break;
    }
  }
}
