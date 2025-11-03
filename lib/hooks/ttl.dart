import 'package:pvcache/core/cache.dart';
import 'package:pvcache/core/enums.dart';

/// TTL (Time-To-Live) Hook System
///
/// This system implements cache expiration by:
/// 1. Reading 'ttl' from metadata when putting entries and converting to expiration timestamp
/// 2. Checking expiration before returning entries (get operation)
/// 3. Automatically removing expired entries
///
/// Usage:
/// ```dart
/// final cache = PVCache(
///   env: 'myCache',
///   hooks: [
///     createTTLSetHook(),
///     createTTLCheckHook(),
///   ],
///   defaultMetadata: {},
/// );
///
/// // Use with custom TTL (in seconds)
/// await cache.put('key', 'value', metadata: {'ttl': 3600}); // 1 hour
/// ```

/// Creates a hook that converts 'ttl' seconds to '_ttl_timestamp'
///
/// This hook runs during the `metaUpdatePriorEntry` stage to read the 'ttl'
/// value from initialMeta and convert it to an absolute '_ttl_timestamp'.
///
/// [priority] - Hook priority (default: 0)
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

/// Creates a hook that checks if an entry has expired before returning it
///
/// This hook runs during the `metaRead` stage (after metadata is loaded)
/// and throws a BreakHook exception if the entry has expired.
///
/// When expired:
/// - Throws BreakHook to stop execution
/// - Automatically deletes the expired entry
/// - Returns null to the caller
///
/// [priority] - Hook priority (default: 0)
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

/// Creates a complete TTL hook set with both set and check hooks
///
/// This is a convenience function that creates all necessary TTL hooks.
List<PVCacheHook> createTTLHooks() {
  return [createTTLSetHook(), createTTLCheckHook()];
}
