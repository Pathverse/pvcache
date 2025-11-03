part of 'cache.dart';

/// Execution context for a cache operation, passed through all hooks.
///
/// PVCtx contains all state for a single cache operation (put, get, delete, etc.):
/// - Initial values (key, value, metadata)
/// - Runtime state (resolved keys, metadata)
/// - Storage proxies (entry and meta)
/// - Return values
///
/// Hooks receive a PVCtx instance and can:
/// - Read/modify the key, value, or metadata
/// - Access storage through [entry] and [meta] proxies
/// - Store temporary data in [runtimeData]
/// - Break execution with [BreakHook] exception
///
/// The context flows through the EventFlow lifecycle:
/// 1. **preProcess**: Initial values set, validation occurs
/// 2. **metaRead**: Metadata loaded from storage into [runtimeMeta]
/// 3. **metaUpdatePriorEntry**: Hooks can modify [runtimeMeta]
/// 4. **storageRead/storageUpdate**: Entry read/written
/// 5. **metaUpdatePostEntry**: Final metadata updates
/// 6. **postProcess**: [returnValue] finalized
///
/// Example hook using context:
/// ```dart
/// Future<void> myHook(PVCtx ctx) async {
///   // Access operation details
///   print('Action: ${ctx.actionType}, Key: ${ctx.resolvedKey}');
///
///   // Modify value
///   if (ctx.actionType == ActionType.put) {
///     ctx.entryValue = transform(ctx.entryValue);
///   }
///
///   // Update metadata
///   ctx.runtimeMeta['timestamp'] = DateTime.now().toIso8601String();
///
///   // Store temporary data
///   ctx.runtimeData['processed'] = true;
///
///   // Early return if needed
///   if (shouldBreak) {
///     throw BreakHook(returnType: BreakReturnType.resolved);
///   }
/// }
/// ```
class PVCtx {
  /// The cache instance this operation belongs to.
  final PVCache cache;

  /// The type of operation being performed (put, get, delete, clear, exists).
  final ActionType actionType;

  /// Initial key provided to the cache operation.
  ///
  /// May be `null` for operations like [ActionType.clear].
  final String? initialKey;

  /// Initial value provided for put operations.
  ///
  /// Only set for [ActionType.put], `null` for other operations.
  final dynamic initialEntryValue;

  /// Initial metadata provided to the operation, merged with [PVCache.defaultMetadata].
  final Map<String, dynamic> initialMeta;

  /// Resolved key for the entry, hooks can modify this.
  ///
  /// Starts as [initialKey] but hooks can transform it (e.g., add prefixes).
  late String? resolvedKey;

  /// Resolved key for metadata storage, hooks can modify this.
  ///
  /// Defaults to `initialMeta['key']` or empty string.
  late String? resolvedMetaKey;

  /// Current value being operated on, hooks can modify this.
  ///
  /// - **put**: Starts as [initialEntryValue], hooks can transform before storage
  /// - **get**: Loaded from storage, hooks can transform after retrieval
  /// - **delete/clear/exists**: Not typically used
  late dynamic entryValue;

  /// Runtime metadata for the current entry.
  ///
  /// Loaded from storage during [EventFlow.metaRead] and updated by hooks.
  /// Automatically saved during [EventFlow.metaUpdatePostEntry].
  ///
  /// Hooks use this to store:
  /// - TTL information (`ttl_seconds`, `_ttl_expiry`)
  /// - Encryption nonces (`_encryption_nonces`)
  /// - Access tracking (`last_accessed`, `hit_count`)
  /// - Custom data
  Map<String, dynamic> runtimeMeta = {};

  /// Value returned from the operation.
  ///
  /// Set automatically for get/exists operations, or by [BreakHook].
  late dynamic returnValue;

  /// Temporary storage for inter-hook communication.
  ///
  /// Hooks can store data here to share with other hooks in the same operation.
  /// Not persisted to storage.
  ///
  /// Example:
  /// ```dart
  /// // Hook 1 stores data
  /// ctx.runtimeData['validated'] = true;
  ///
  /// // Hook 2 reads it
  /// if (ctx.runtimeData['validated'] == true) {
  ///   // proceed
  /// }
  /// ```
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

  /// Execute all hooks for this operation through the EventFlow lifecycle.
  ///
  /// This is the core hook execution engine. It:
  /// 1. Groups hooks by [EventFlow] stage
  /// 2. Executes stages in order
  /// 3. Automatically handles storage reads/writes between stages
  /// 4. Catches [BreakHook] exceptions to exit early
  ///
  /// Flow:
  /// 1. **preProcess**: Run hooks
  /// 2. **metaRead**: Load metadata → run hooks
  /// 3. **metaUpdatePriorEntry**: Run hooks
  /// 4. **storageRead**: Run hooks → load entry (get/exists)
  /// 5. **storageUpdate**: Run hooks → save entry (put) or delete entry (delete)
  /// 6. **metaUpdatePostEntry**: Run hooks → save metadata
  /// 7. **postProcess**: Run hooks → set [returnValue]
  ///
  /// Parameters:
  /// - [hooks]: List of hooks to execute, already sorted by priority.
  ///
  /// Throws: [BreakHook] exceptions are caught and handled internally.
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
  ///
  /// Runs each hook's [PVCacheHook.hookFunction] in order.
  /// If a hook throws [BreakHook], it propagates up to [queue].
  Future<void> _runHooks(List<PVCacheHook>? hooks) async {
    if (hooks == null) return;
    for (final hook in hooks) {
      await hook.hookFunction(this);
    }
  }

  /// Storage proxy for cache entries (the actual data).
  ///
  /// Provides [get], [put], and [delete] methods that route to the
  /// configured [StorageType] for entries.
  ///
  /// Example:
  /// ```dart
  /// // In a storageUpdate hook
  /// await ctx.entry.put(ctx.resolvedKey!, {'value': encryptedData});
  ///
  /// // In a storageRead hook
  /// final data = await ctx.entry.get(ctx.resolvedKey!);
  /// ```
  PVCtxStorageProxy get entry => PVCtxStorageProxy(
    ctx: this,
    storageType: cache.entryStorageType,
    isMetadata: false,
  );

  /// Storage proxy for metadata.
  ///
  /// Provides [get], [put], and [delete] methods that route to the
  /// configured [StorageType] for metadata.
  ///
  /// Metadata is typically stored separately from entries to allow:
  /// - Different storage backends (e.g., entries persistent, metadata in-memory)
  /// - Independent lifecycle (e.g., clear metadata without clearing entries)
  ///
  /// Example:
  /// ```dart
  /// // In a metaRead hook
  /// final metadata = await ctx.meta.get(ctx.resolvedKey!);
  ///
  /// // In a metaUpdatePostEntry hook
  /// await ctx.meta.put(ctx.resolvedKey!, ctx.runtimeMeta);
  /// ```
  PVCtxStorageProxy get meta => PVCtxStorageProxy(
    ctx: this,
    storageType: cache.metadataStorageType,
    isMetadata: true,
  );
}

/// Storage abstraction for accessing entries and metadata.
///
/// PVCtxStorageProxy routes storage operations to the appropriate backend
/// based on [StorageType]:
/// - [StorageType.stdSembast]: Persistent file-based database
/// - [StorageType.inMemory]: Session-only in-memory database
/// - [StorageType.secureStorage]: Platform keychain (for keys/sensitive data)
///
/// The proxy automatically handles:
/// - Store name resolution (environment + metadata suffix)
/// - Database instance retrieval
/// - Platform-specific storage APIs
///
/// Used internally by hooks through [PVCtx.entry] and [PVCtx.meta].
///
/// Example:
/// ```dart
/// // Get entry
/// final data = await ctx.entry.get('user:123');
///
/// // Put metadata
/// await ctx.meta.put('user:123', {'ttl': 3600});
///
/// // Delete entry
/// await ctx.entry.delete('user:123');
/// ```
class PVCtxStorageProxy {
  /// The context this proxy belongs to.
  final PVCtx ctx;

  /// Storage backend to use (stdSembast, inMemory, or secureStorage).
  final StorageType storageType;

  /// Whether this proxy is for metadata (true) or entries (false).
  ///
  /// Affects store name resolution:
  /// - Entries: Use environment name directly (e.g., 'prod')
  /// - Metadata: Use metadata name function (e.g., 'prod_metadata')
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
  /// Routes to appropriate backend:
  /// - **stdSembast/inMemory**: Returns map from sembast record
  /// - **secureStorage**: Returns `{'value': <string>}` from platform keychain
  ///
  /// Parameters:
  /// - [key]: Storage key to retrieve.
  ///
  /// Returns: Map containing the value, or `null` if not found.
  ///
  /// Example:
  /// ```dart
  /// final data = await ctx.entry.get('user:123');
  /// if (data != null) {
  ///   final value = data['value'];
  /// }
  /// ```
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
  ///
  /// Routes to appropriate backend:
  /// - **stdSembast/inMemory**: Stores map in sembast record
  /// - **secureStorage**: Stores `value['value']` as string in platform keychain
  ///
  /// Parameters:
  /// - [key]: Storage key to store under.
  /// - [value]: Map containing the data to store.
  ///
  /// Example:
  /// ```dart
  /// await ctx.entry.put('user:123', {'value': userData});
  /// ```
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
  ///
  /// Routes to appropriate backend to remove the entry.
  ///
  /// Parameters:
  /// - [key]: Storage key to delete.
  ///
  /// Example:
  /// ```dart
  /// await ctx.entry.delete('user:123');
  /// await ctx.meta.delete('user:123');
  /// ```
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
