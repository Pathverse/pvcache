import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/core/bridge.dart';
import 'package:sembast/sembast.dart';

/// LRU (Least Recently Used) Hook System
///
/// This system implements cache eviction by:
/// 1. Tracking access count for each entry in metadata
/// 2. Storing a global access counter in a reserved key
/// 3. Evicting the least recently used entry when max size is reached
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

/// Creates a hook that updates access count on get operations
///
/// This hook runs during the `metaRead` stage to update the last access
/// count for entries that are being read.
///
/// [priority] - Hook priority (default: 100, runs after other metaRead hooks)
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

/// Creates a hook that updates access count on put operations and evicts if needed
///
/// This hook runs during the `metaUpdatePriorEntry` stage to:
/// 1. Set the access count for new entries
/// 2. Check if cache size exceeds max
/// 3. Evict the least recently used entry if needed
///
/// [max] - Maximum number of entries in the cache
/// [priority] - Hook priority (default: 0)
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

/// Helper function to evict the least recently used entry
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

/// Creates a complete LRU hook set with all necessary hooks
///
/// This is a convenience function that creates all LRU hooks at once.
///
/// [max] - Maximum number of entries in the cache
List<PVCacheHook> createLRUHooks({required int max}) {
  return [createLRUEvictHook(max: max), createLRUTrackAccessHook()];
}
