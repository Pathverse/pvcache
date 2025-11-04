import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/core/bridge.dart';
import 'package:sembast/sembast.dart';

/// LRU (Least Recently Used) Hook System
///
/// Implements cache eviction:
/// 1. Tracks access count per entry in metadata
/// 2. Stores global counter in reserved key
/// 3. Evicts least recently used when max size reached
///
/// Usage:
/// ```dart
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: createLRUHooks(max: 100),
///   defaultMetadata: {},
/// );
/// ```

// ignore: constant_identifier_names
const String _LRU_COUNTER_KEY = '_lru_global_counter';

/// Creates a hook that updates access count on get.
PVCacheHook createLRUTrackAccessHook({int priority = 100}) {
  return PVCacheHook(
    eventString: 'lru_track_access',
    eventFlow: EventFlow.metaRead,
    priority: priority,
    actionTypes: [ActionType.get],
    hookFunction: (ctx) async {
      // Get the global counter
      final counterData = await ctx.meta.get(_LRU_COUNTER_KEY);
      int counter = counterData?['counter'] ?? 0;

      // Increment counter
      counter++;

      // Update entry's access count
      ctx.runtimeMeta['_lru_count'] = counter;

      // Store the new global counter
      await ctx.meta.put(_LRU_COUNTER_KEY, {'counter': counter});
    },
  );
}

/// Creates a hook that updates access count on put and evicts if needed.
///
/// Runs during metaUpdatePriorEntry. Sets access count and evicts LRU entry if cache exceeds max.
PVCacheHook createLRUEvictHook({required int max, int priority = 0}) {
  return PVCacheHook(
    eventString: 'lru_evict',
    eventFlow: EventFlow.metaUpdatePriorEntry,
    priority: priority,
    actionTypes: [ActionType.put],
    hookFunction: (ctx) async {
      // Get the global counter
      final counterData = await ctx.meta.get(_LRU_COUNTER_KEY);
      int counter = counterData?['counter'] ?? 0;

      // Increment counter
      counter++;

      // Set access count for this entry
      ctx.runtimeMeta['_lru_count'] = counter;

      // Store the new global counter
      await ctx.meta.put(_LRU_COUNTER_KEY, {'counter': counter});

      // Check cache size and evict if needed
      await _evictIfNeeded(ctx, max);
    },
  );
}

/// Helper to evict least recently used entry.
Future<void> _evictIfNeeded(PVCtx ctx, int max) async {
  // Get all metadata entries to count and find LRU
  // We need to read from the store directly
  final bridge = PVBridge();
  final db = await bridge.getDatabaseForType(ctx.cache.metadataStorageType);
  final storeName = ctx.cache.metadataNameFunction!(ctx.cache.env);
  final store = bridge.getStore(storeName, ctx.cache.metadataStorageType);

  // Get all record snapshots
  final finder = Finder();
  final snapshots = await store.find(db, finder: finder);

  // Filter out reserved keys and count entries
  final userEntries = snapshots.where((s) => !s.key.startsWith('_')).toList();

  // If we're at or over the limit, evict the LRU entry
  if (userEntries.length >= max) {
    // Find the entry with the lowest _lru_count
    int? lowestCount;
    String? lruKey;

    for (final snapshot in userEntries) {
      final count = snapshot.value['_lru_count'];
      if (count != null) {
        if (lowestCount == null || count < lowestCount) {
          lowestCount = count;
          lruKey = snapshot.key;
        }
      } else {
        // Entry without LRU count, evict it first
        lruKey = snapshot.key;
        break;
      }
    }

    // Evict the LRU entry
    if (lruKey != null && lruKey != ctx.resolvedKey) {
      await ctx.entry.delete(lruKey);
      await ctx.meta.delete(lruKey);
    }
  }
}

/// Creates complete LRU hook set.
List<PVCacheHook> createLRUHooks({required int max}) {
  return [createLRUEvictHook(max: max), createLRUTrackAccessHook()];
}
