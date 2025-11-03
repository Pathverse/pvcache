import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/core/enums.dart';
import 'package:sembast/sembast.dart';

part 'ctx.dart';
part 'hook.dart';

/// A configurable cache instance with hook-based extensibility.
///
/// PVCache is the main class for creating isolated cache instances. Each cache:
/// - Has its own environment namespace (e.g., 'dev', 'prod')
/// - Can configure storage types for entries and metadata independently
/// - Supports custom hooks for extending behavior (TTL, encryption, etc.)
/// - Executes hooks in priority order through the EventFlow lifecycle
///
/// Key concepts:
/// - **Hooks**: Functions that intercept cache operations to add behavior
/// - **EventFlow**: 7-stage lifecycle (preProcess → metaRead → metaUpdatePriorEntry → storageRead/Update → metaUpdatePostEntry → postProcess)
/// - **Storage Types**: stdSembast (persistent), inMemory (session), secureStorage (platform keychain)
/// - **Metadata**: Additional data per entry (TTL, encryption info, custom flags)
///
/// Example - Basic cache:
/// ```dart
/// final cache = PVCache(
///   env: 'dev',
///   hooks: [],
///   defaultMetadata: {},
/// );
///
/// await cache.put('user:123', {'name': 'Alice'});
/// final user = await cache.get('user:123');
/// ```
///
/// Example - Cache with TTL:
/// ```dart
/// final cache = PVCache(
///   env: 'prod',
///   hooks: [
///     createTTLHook(),
///   ],
///   defaultMetadata: {},
/// );
///
/// // Expires in 1 hour
/// await cache.put('session', token, metadata: {'ttl_seconds': 3600});
/// ```
///
/// Example - Encrypted cache:
/// ```dart
/// final cache = PVCache(
///   env: 'secure',
///   hooks: [
///     ...createEncryptionHooks(encryptionKey: 'my-secure-key-123'),
///   ],
///   defaultMetadata: {},
/// );
///
/// // Automatically encrypted/decrypted
/// await cache.put('password', 'secret123');
/// ```
class PVCache {
  /// Map of all cache instances by environment name.
  ///
  /// Used internally to track created caches. Can be useful for debugging
  /// or accessing caches globally.
  ///
  /// Example:
  /// ```dart
  /// final devCache = PVCache.instances['dev'];
  /// ```
  static final Map<String, PVCache> instances = {};

  /// Environment name for this cache instance.
  ///
  /// Used as the sembast store name to isolate data between environments.
  final String env;

  /// Default metadata applied to all operations if not overridden.
  ///
  /// Example:
  /// ```dart
  /// final cache = PVCache(
  ///   env: 'dev',
  ///   hooks: [],
  ///   defaultMetadata: {'ttl_seconds': 3600}, // 1 hour TTL by default
  /// );
  /// ```
  final Map<String, dynamic> defaultMetadata;

  /// Storage backend for cache entries (the actual data).
  ///
  /// Options:
  /// - [StorageType.stdSembast]: Persistent storage (default)
  /// - [StorageType.inMemory]: Session-only storage
  /// - [StorageType.secureStorage]: Platform keychain (limited use)
  final StorageType entryStorageType;

  /// Storage backend for metadata (TTL, encryption info, etc.).
  ///
  /// Can differ from [entryStorageType]. For example:
  /// - Entries in persistent storage
  /// - Metadata in memory (if metadata is regenerated on each session)
  final StorageType metadataStorageType;

  /// If true, don't create metadata entry when metadata map is empty.
  ///
  /// Useful to avoid storing unnecessary metadata records when hooks
  /// don't add any metadata.
  final bool noMetadataStoreIfEmpty;

  /// Function to generate metadata store name from environment name.
  ///
  /// Defaults to `(env) => '${env}_metadata'`.
  ///
  /// Example custom naming:
  /// ```dart
  /// final cache = PVCache(
  ///   env: 'prod',
  ///   hooks: [],
  ///   defaultMetadata: {},
  ///   metadataNameFunction: (env) => 'meta_$env',
  /// );
  /// // Metadata stored in 'meta_prod' instead of 'prod_metadata'
  /// ```
  final String Function(String)? metadataNameFunction;

  /// Create a new cache instance with the given configuration.
  ///
  /// Parameters:
  /// - [env]: Environment name (used as store name).
  /// - [hooks]: List of hooks to execute during cache operations.
  /// - [defaultMetadata]: Metadata applied to all operations by default.
  /// - [entryStorageType]: Storage backend for entries (default: stdSembast).
  /// - [metadataStorageType]: Storage backend for metadata (default: stdSembast).
  /// - [noMetadataStoreIfEmpty]: Skip storing empty metadata (default: false).
  /// - [metadataNameFunction]: Custom metadata store naming (default: '${env}_metadata').
  ///
  /// The constructor automatically:
  /// 1. Registers the instance in [PVCache.instances]
  /// 2. Sorts hooks by [EventFlow] stage and priority
  /// 3. Creates separate hook lists for each [ActionType]
  ///
  /// Example:
  /// ```dart
  /// final cache = PVCache(
  ///   env: 'prod',
  ///   hooks: [
  ///     createTTLHook(),
  ///     createLRUHook(maxEntries: 100),
  ///   ],
  ///   defaultMetadata: {},
  ///   entryStorageType: StorageType.stdSembast,
  ///   metadataStorageType: StorageType.inMemory,
  /// );
  /// ```
  PVCache({
    required this.env,
    required List<PVCacheHook> hooks,
    required this.defaultMetadata,
    this.entryStorageType = StorageType.stdSembast,
    this.metadataStorageType = StorageType.stdSembast,
    this.noMetadataStoreIfEmpty = false,
    String Function(String)? metadataNameFunction,
  }) : metadataNameFunction =
           metadataNameFunction ?? ((env) => '${env}_metadata') {
    PVCache.instances[env] = this;

    _hooks = hooks;
    _orderedPutHooks =
        _hooks
            .where((hook) => hook.actionTypes.contains(ActionType.put))
            .toList()
          ..sort((a, b) {
            final flowComparison = a.eventFlow.index.compareTo(
              b.eventFlow.index,
            );
            if (flowComparison != 0) return flowComparison;
            return a.priority.compareTo(b.priority);
          });

    _orderedGetHooks =
        _hooks
            .where((hook) => hook.actionTypes.contains(ActionType.get))
            .toList()
          ..sort((a, b) {
            final flowComparison = a.eventFlow.index.compareTo(
              b.eventFlow.index,
            );
            if (flowComparison != 0) return flowComparison;
            return a.priority.compareTo(b.priority);
          });

    _orderedDeleteHooks =
        _hooks
            .where((hook) => hook.actionTypes.contains(ActionType.delete))
            .toList()
          ..sort((a, b) {
            final flowComparison = a.eventFlow.index.compareTo(
              b.eventFlow.index,
            );
            if (flowComparison != 0) return flowComparison;
            return a.priority.compareTo(b.priority);
          });

    _orderedClearHooks =
        _hooks
            .where((hook) => hook.actionTypes.contains(ActionType.clear))
            .toList()
          ..sort((a, b) {
            final flowComparison = a.eventFlow.index.compareTo(
              b.eventFlow.index,
            );
            if (flowComparison != 0) return flowComparison;
            return a.priority.compareTo(b.priority);
          });

    _orderedExistsHooks =
        _hooks
            .where((hook) => hook.actionTypes.contains(ActionType.exists))
            .toList()
          ..sort((a, b) {
            final flowComparison = a.eventFlow.index.compareTo(
              b.eventFlow.index,
            );
            if (flowComparison != 0) return flowComparison;
            return a.priority.compareTo(b.priority);
          });
  }

  /// All registered hooks for this cache instance.
  late final List<PVCacheHook> _hooks;

  /// Hooks that execute during [ActionType.put] operations, sorted by flow and priority.
  late final List<PVCacheHook> _orderedPutHooks;

  /// Hooks that execute during [ActionType.get] operations, sorted by flow and priority.
  late final List<PVCacheHook> _orderedGetHooks;

  /// Hooks that execute during [ActionType.delete] operations, sorted by flow and priority.
  late final List<PVCacheHook> _orderedDeleteHooks;

  /// Hooks that execute during [ActionType.clear] operations, sorted by flow and priority.
  late final List<PVCacheHook> _orderedClearHooks;

  /// Hooks that execute during [ActionType.exists] operations, sorted by flow and priority.
  late final List<PVCacheHook> _orderedExistsHooks;

  /// Store a value in the cache.
  ///
  /// Executes all registered [ActionType.put] hooks through the EventFlow lifecycle:
  /// 1. **preProcess**: Validate inputs, transform data
  /// 2. **metaRead**: Load existing metadata
  /// 3. **metaUpdatePriorEntry**: Update metadata before storage (set TTL, etc.)
  /// 4. **storageUpdate**: Write to storage (encryption happens here)
  /// 5. **metaUpdatePostEntry**: Update metadata after storage
  /// 6. **postProcess**: Cleanup, logging
  ///
  /// Parameters:
  /// - [key]: Cache key (unique identifier).
  /// - [value]: Data to store (will be JSON-serialized).
  /// - [metadata]: Additional metadata for this entry (merged with [defaultMetadata]).
  ///
  /// Metadata can control hook behavior:
  /// ```dart
  /// // TTL example
  /// await cache.put('session', token, metadata: {'ttl_seconds': 3600});
  ///
  /// // Selective encryption example
  /// await cache.put('user', userData, metadata: {
  ///   'secure': ['password', 'ssn'],
  /// });
  /// ```
  ///
  /// Example:
  /// ```dart
  /// await cache.put('user:123', {'name': 'Alice', 'age': 30});
  /// await cache.put('config', settings, metadata: {'priority': 'high'});
  /// ```
  Future<void> put(
    String key,
    dynamic value, {
    Map<String, dynamic>? metadata,
  }) async {
    final ctx = PVCtx(
      cache: this,
      actionType: ActionType.put,
      initialKey: key,
      initialEntryValue: value,
      initialMeta: metadata ?? {},
    );
    await ctx.queue(_orderedPutHooks);
  }

  /// Retrieve a value from the cache.
  ///
  /// Executes all registered [ActionType.get] hooks through the EventFlow lifecycle:
  /// 1. **preProcess**: Validate key, prepare request
  /// 2. **metaRead**: Load metadata (check TTL, etc.)
  /// 3. **storageRead**: Read from storage
  /// 4. **postProcess**: Transform data (decryption happens here)
  ///
  /// Hooks can:
  /// - Return early with [BreakHook] if entry expired or doesn't exist
  /// - Transform the value (decrypt, decompress, deserialize)
  /// - Update metadata (access timestamps, hit counts)
  ///
  /// Parameters:
  /// - [key]: Cache key to retrieve.
  /// - [metadata]: Optional metadata to pass to hooks.
  ///
  /// Returns: The cached value, or `null` if not found or expired.
  ///
  /// Example:
  /// ```dart
  /// final user = await cache.get('user:123');
  /// if (user != null) {
  ///   print('Found: $user');
  /// } else {
  ///   print('Not in cache');
  /// }
  /// ```
  Future<dynamic> get(String key, {Map<String, dynamic>? metadata}) async {
    final ctx = PVCtx(
      cache: this,
      actionType: ActionType.get,
      initialKey: key,
      initialMeta: metadata ?? {},
    );
    await ctx.queue(_orderedGetHooks);
    return ctx.returnValue;
  }

  /// Delete a value from the cache.
  ///
  /// Executes all registered [ActionType.delete] hooks through the EventFlow lifecycle:
  /// 1. **preProcess**: Validate key, check permissions
  /// 2. **metaRead**: Load metadata
  /// 3. **storageUpdate**: Remove from storage
  /// 4. **metaUpdatePostEntry**: Clean up metadata
  /// 5. **postProcess**: Cleanup, logging
  ///
  /// Parameters:
  /// - [key]: Cache key to delete.
  /// - [metadata]: Optional metadata to pass to hooks.
  ///
  /// Example:
  /// ```dart
  /// await cache.delete('user:123');
  /// ```
  Future<void> delete(String key, {Map<String, dynamic>? metadata}) async {
    final ctx = PVCtx(
      cache: this,
      actionType: ActionType.delete,
      initialKey: key,
      initialMeta: metadata ?? {},
    );
    await ctx.queue(_orderedDeleteHooks);
  }

  /// Clear all entries from the cache.
  ///
  /// Executes all registered [ActionType.clear] hooks through the EventFlow lifecycle:
  /// 1. **preProcess**: Validate permissions, prepare
  /// 2. **storageUpdate**: Remove all entries and metadata
  /// 3. **postProcess**: Cleanup, logging
  ///
  /// This is a destructive operation that removes all data in the cache's environment.
  ///
  /// Parameters:
  /// - [metadata]: Optional metadata to pass to hooks.
  ///
  /// Example:
  /// ```dart
  /// // Clear all cached data
  /// await cache.clear();
  ///
  /// // Clear with logging
  /// await cache.clear(metadata: {'reason': 'user_logout'});
  /// ```
  Future<void> clear({Map<String, dynamic>? metadata}) async {
    final ctx = PVCtx(
      cache: this,
      actionType: ActionType.clear,
      initialMeta: metadata ?? {},
    );
    await ctx.queue(_orderedClearHooks);
  }

  /// Check if a key exists in the cache.
  ///
  /// Executes all registered [ActionType.exists] hooks through the EventFlow lifecycle:
  /// 1. **preProcess**: Validate key
  /// 2. **metaRead**: Load metadata (check TTL if applicable)
  /// 3. **storageRead**: Check storage for key
  /// 4. **postProcess**: Finalize result
  ///
  /// Respects hook logic - if a TTL hook marks an entry as expired,
  /// this will return `false` even if the key exists in storage.
  ///
  /// Parameters:
  /// - [key]: Cache key to check.
  /// - [metadata]: Optional metadata to pass to hooks.
  ///
  /// Returns: `true` if the key exists and is valid, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (await cache.exists('user:123')) {
  ///   print('User is cached');
  /// } else {
  ///   print('Need to fetch user');
  /// }
  /// ```
  Future<bool> exists(String key, {Map<String, dynamic>? metadata}) async {
    final ctx = PVCtx(
      cache: this,
      actionType: ActionType.exists,
      initialKey: key,
      initialMeta: metadata ?? {},
    );
    await ctx.queue(_orderedExistsHooks);
    return ctx.returnValue != null;
  }
}
