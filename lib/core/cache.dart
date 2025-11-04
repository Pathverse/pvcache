import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/core/enums.dart';
import 'package:sembast/sembast.dart';

part 'ctx.dart';
part 'hook.dart';

/// A configurable cache instance with hook-based extensibility.
///
/// Each cache has its own environment namespace and supports custom hooks
/// for TTL, encryption, LRU, and other behaviors.
///
/// Example - Basic cache:
/// ```dart
/// final cache = PVCache(
///   env: 'dev',
///   hooks: [],
///   defaultMetadata: {},
/// );
/// await cache.put('user:123', {'name': 'Alice'});
/// ```
///
/// Example - Cache with TTL:
/// ```dart
/// final cache = PVCache(
///   env: 'prod',
///   hooks: [createTTLHook()],
///   defaultMetadata: {},
/// );
/// await cache.put('session', token, metadata: {'ttl_seconds': 3600});
/// ```
class PVCache {
  /// Map of all cache instances by environment name.
  static final Map<String, PVCache> instances = {};

  /// Environment name for this cache instance.
  final String env;

  /// Default metadata applied to all operations if not overridden.
  final Map<String, dynamic> defaultMetadata;

  /// Storage backend for cache entries.
  ///
  /// Options: stdSembast (persistent), inMemory (session), secureStorage (keychain)
  final StorageType entryStorageType;

  /// Storage backend for metadata. Can differ from [entryStorageType].
  final StorageType metadataStorageType;

  /// If true, don't create metadata entry when metadata map is empty.
  final bool noMetadataStoreIfEmpty;

  /// Function to generate metadata store name. Defaults to '${env}_metadata'.
  final String Function(String)? metadataNameFunction;

  /// Create a new cache instance.
  ///
  /// Hooks are sorted by EventFlow stage and priority automatically.
  ///
  /// Example:
  /// ```dart
  /// final cache = PVCache(
  ///   env: 'prod',
  ///   hooks: [createTTLHook(), createLRUHook(maxEntries: 100)],
  ///   defaultMetadata: {},
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
  /// Executes hooks in EventFlow order. Metadata controls hook behavior (TTL, encryption, etc).
  ///
  /// Example:
  /// ```dart
  /// await cache.put('user:123', {'name': 'Alice'});
  /// await cache.put('session', token, metadata: {'ttl_seconds': 3600});
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
  /// Returns `null` if not found or expired (based on hooks like TTL).
  ///
  /// Example:
  /// ```dart
  /// final user = await cache.get('user:123');
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
  /// Removes all data in this cache's environment.
  ///
  /// Example:
  /// ```dart
  /// await cache.clear();
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
  /// Respects TTL and other hook logic. Returns `false` if entry is expired.
  ///
  /// Example:
  /// ```dart
  /// if (await cache.exists('user:123')) {
  ///   print('User is cached');
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

  /// Get cached value or compute and cache if missing.
  ///
  /// If key exists in cache, returns cached value.
  /// If key doesn't exist, calls [compute], caches the result, and returns it.
  ///
  /// Example:
  /// ```dart
  /// final user = await cache.ifNotCached(
  ///   'user:123',
  ///   () => api.fetchUser(123),
  ///   metadata: {'ttl_seconds': 3600},
  /// );
  /// ```
  Future<T?> ifNotCached<T>(
    String key,
    Future<T?> Function() compute, {
    Map<String, dynamic>? metadata,
  }) async {
    final cached = await get(key, metadata: metadata);
    if (cached != null) {
      return cached as T;
    }

    final computed = await compute();
    if (computed != null) {
      await put(key, computed, metadata: metadata);
    }

    return computed;
  }
}
