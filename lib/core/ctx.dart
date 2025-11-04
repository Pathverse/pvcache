part of 'cache.dart';

/// Execution context for a cache operation, passed through all hooks.
///
/// Contains operation state: initial values, runtime state, storage proxies, and return values.
///
/// Hooks can read/modify keys, values, metadata, and break execution with [BreakHook].
///
/// EventFlow lifecycle:
/// 1. **preProcess**: Validation
/// 2. **metaRead**: Metadata loaded
/// 3. **metaUpdatePriorEntry**: Pre-entry updates
/// 4. **storageRead/storageUpdate**: Entry I/O
/// 5. **metaUpdatePostEntry**: Post-entry updates
/// 6. **postProcess**: Finalization
///
/// Example:
/// ```dart
/// Future<void> myHook(PVCtx ctx) async {
///   ctx.runtimeMeta['timestamp'] = DateTime.now().toIso8601String();
///   if (shouldBreak) throw BreakHook(returnType: BreakReturnType.resolved);
/// }
/// ```
class PVCtx {
  /// The cache instance this operation belongs to.
  final PVCache cache;

  /// The type of operation being performed (put, get, delete, clear, exists).
  final ActionType actionType;

  /// Initial key provided to the operation (null for clear).
  final String? initialKey;

  /// Initial value for put operations (null for others).
  final dynamic initialEntryValue;

  /// Initial metadata merged with [PVCache.defaultMetadata].
  final Map<String, dynamic> initialMeta;

  /// Resolved key for the entry (modifiable by hooks).
  late String? resolvedKey;

  /// Resolved metadata key (modifiable by hooks).
  late String? resolvedMetaKey;

  /// Current value being operated on (modifiable by hooks).
  late dynamic entryValue;

  /// Runtime metadata loaded from storage and modified by hooks.
  Map<String, dynamic> runtimeMeta = {};

  /// Value returned from the operation.
  late dynamic returnValue;

  /// Temporary inter-hook communication storage (not persisted).
  final Map<String, dynamic> runtimeData = {};

  /// Create a new context for a cache operation.
  ///
  /// Typically created by [PVCache] methods, not by user code.
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

  /// Execute all hooks through the EventFlow lifecycle.
  ///
  /// Groups hooks by stage, executes in order, handles storage I/O,
  /// and catches [BreakHook] exceptions.
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

  /// Execute hooks in a specific stage.
  Future<void> _runHooks(List<PVCacheHook>? hooks) async {
    if (hooks == null) return;
    for (final hook in hooks) {
      await hook.hookFunction(this);
    }
  }

  /// Storage proxy for cache entries.
  ///
  /// Routes to configured [StorageType] for entry operations.
  PVCtxStorageProxy get entry => PVCtxStorageProxy(
    ctx: this,
    storageType: cache.entryStorageType,
    isMetadata: false,
  );

  /// Storage proxy for metadata.
  ///
  /// Routes to configured [StorageType] for metadata operations.
  PVCtxStorageProxy get meta => PVCtxStorageProxy(
    ctx: this,
    storageType: cache.metadataStorageType,
    isMetadata: true,
  );
}

/// Storage abstraction for entries and metadata.
///
/// Routes operations to backends: stdSembast (persistent), inMemory (session), secureStorage (keychain).
///
/// Used internally via [PVCtx.entry] and [PVCtx.meta].
class PVCtxStorageProxy {
  /// The context this proxy belongs to.
  final PVCtx ctx;

  /// Storage backend type (stdSembast, inMemory, or secureStorage).
  final StorageType storageType;

  /// Whether this proxy is for metadata (true) or entries (false).
  final bool isMetadata;

  /// Create a storage proxy.
  ///
  /// Typically created by [PVCtx.entry] and [PVCtx.meta], not directly.
  PVCtxStorageProxy({
    required this.ctx,
    required this.storageType,
    required this.isMetadata,
  });

  /// Retrieve a value from storage.
  ///
  /// Returns map from backend, or null if not found.
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

  /// Store a value in storage.
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

  /// Delete a value from storage.
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
