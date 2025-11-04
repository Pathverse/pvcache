import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';

/// TTL (Time-To-Live) Hook System
///
/// Implements cache expiration:
/// 1. Converts 'ttl' metadata to expiration timestamp
/// 2. Checks expiration on get
/// 3. Auto-removes expired entries
///
/// Usage:
/// ```dart
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: [createTTLSetHook(), createTTLCheckHook()],
///   defaultMetadata: {},
/// );
/// await cache.put('key', 'value', metadata: {'ttl': 3600}); // 1 hour
/// ```

/// Creates a hook that converts 'ttl' seconds to '_ttl_timestamp'.
PVCacheHook createTTLSetHook({int priority = 0}) {
  return PVCacheHook(
    eventString: 'ttl_set',
    eventFlow: EventFlow.metaUpdatePriorEntry,
    priority: priority,
    actionTypes: [ActionType.put],
    hookFunction: (ctx) async {
      // Check if TTL is provided in metadata
      final ttl = ctx.initialMeta['ttl'];
      if (ttl == null) return; // No TTL specified

      // Convert TTL seconds to timestamp
      final ttlSeconds = ttl is int ? ttl : int.tryParse(ttl.toString());
      if (ttlSeconds == null || ttlSeconds <= 0) return; // Invalid TTL

      // Calculate expiration timestamp
      final expiresAt = DateTime.now()
          .add(Duration(seconds: ttlSeconds))
          .millisecondsSinceEpoch;

      // Set the timestamp in runtime metadata (this gets saved)
      ctx.runtimeMeta['_ttl_timestamp'] = expiresAt;
    },
  );
}

/// Creates a hook that checks if entry expired before returning.
///
/// Runs during metaRead stage. Deletes expired entries and returns null.
PVCacheHook createTTLCheckHook({int priority = 0}) {
  return PVCacheHook(
    eventString: 'ttl_check',
    eventFlow: EventFlow.metaRead,
    priority: priority,
    actionTypes: [ActionType.get, ActionType.exists],
    hookFunction: (ctx) async {
      // Check if TTL metadata exists
      final expiresAt = ctx.runtimeMeta['_ttl_timestamp'];
      if (expiresAt == null) return; // No TTL set, skip check

      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if expired
      if (now >= expiresAt) {
        // Delete the expired entry
        if (ctx.resolvedKey != null) {
          await ctx.entry.delete(ctx.resolvedKey!);
          await ctx.meta.delete(ctx.resolvedKey!);
        }

        // Break the hook chain and return null
        throw BreakHook('Entry expired (TTL)', BreakReturnType.none);
      }
    },
  );
}

/// Creates complete TTL hook set.
List<PVCacheHook> createTTLHooks() {
  return [createTTLSetHook(), createTTLCheckHook()];
}
