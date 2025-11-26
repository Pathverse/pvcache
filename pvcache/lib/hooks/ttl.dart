import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/hooks/action_hook.dart';
import 'package:pvcache/core/ctx/runtime_ctx.dart';
import 'package:pvcache/db/db.dart';

/// TTL (Time To Live) cache plugin
///
/// Adds timestamp metadata on put and checks for expiration on get.
/// Expired items are automatically deleted and return null.
class TTLPlugin extends PVCPlugin {
  final int defaultTTLMillis;

  TTLPlugin({required this.defaultTTLMillis})
    : super(
        actionHooks: [
          _createStoreTTLHook(defaultTTLMillis),
          _createCheckTTLHook(),
        ],
      );

  /// Adds created_at timestamp and ttl to metadata on put
  static PVActionHook _createStoreTTLHook(int defaultTTLMillis) {
    return PVActionHook((ctxRef) async {
      final ctx = ctxRef as PVRuntimeCtx;
      final newMetadata = Map<String, dynamic>.from(ctx.overrideCtx.metadata);

      newMetadata['created_at'] = DateTime.now().millisecondsSinceEpoch;
      // Use metadata TTL if provided, otherwise use default
      newMetadata['ttl'] = newMetadata['ttl'] ?? defaultTTLMillis;

      ctx.overrideCtx = ctx.overrideCtx.copyWith(metadata: newMetadata);
    }, [PVActionContext('put', priority: 5, isPost: false)]);
  }

  /// Checks if item is expired after retrieving metadata
  static PVActionHook _createCheckTTLHook() {
    return PVActionHook((ctxRef) async {
      final ctx = ctxRef as PVRuntimeCtx;
      final metadata = ctx.retrievedMetadata;

      if (metadata.containsKey('created_at') && metadata.containsKey('ttl')) {
        final createdAt = metadata['created_at'] as int;
        final ttl = metadata['ttl'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - createdAt > ttl) {
          // Expired - delete and return null
          final config = ctx.config;
          final storeRef = await Db.resolve(config);
          await storeRef.delete(ctx.overrideCtx.key!);

          ctx.normalReturn(null);
          ctx.earlyBreak(null);
        }
      }
    }, [PVActionContext('getRecord', priority: 10, isPost: true)]);
  }
}

/// Combined LRU + TTL plugin
///
/// Combines LRU eviction with TTL expiration, ensuring expired items
/// are removed from LRU tracking in global metadata.
class LRUTTLPlugin extends PVCPlugin {
  final int maxSize;
  final int defaultTTLMillis;

  LRUTTLPlugin({required this.maxSize, required this.defaultTTLMillis})
    : super(
        actionHooks: [
          _createStoreTTLHook(defaultTTLMillis),
          _createTrackLRUHook(),
          _createEvictLRUHook(maxSize),
          _createCheckTTLHook(),
        ],
      );

  /// Adds timestamp to metadata on put
  static PVActionHook _createStoreTTLHook(int defaultTTLMillis) {
    return PVActionHook((ctxRef) async {
      final ctx = ctxRef as PVRuntimeCtx;
      final newMetadata = Map<String, dynamic>.from(ctx.overrideCtx.metadata);

      newMetadata['created_at'] = DateTime.now().millisecondsSinceEpoch;
      newMetadata['ttl'] = newMetadata['ttl'] ?? defaultTTLMillis;

      ctx.overrideCtx = ctx.overrideCtx.copyWith(metadata: newMetadata);
    }, [PVActionContext('put', priority: 5, isPost: false)]);
  }

  /// Tracks LRU access order in global metadata
  static PVActionHook _createTrackLRUHook() {
    return PVActionHook(
      (ctxRef) async {
        final ctx = ctxRef as PVRuntimeCtx;
        final key = ctx.overrideCtx.key;

        if (key != null) {
          final config = ctx.config;
          final accessOrder = List<String>.from(
            await Ref.getGlobalMetaValue(
              config,
              'lru_access_order',
              defaultValue: <String>[],
            ),
          );

          accessOrder.remove(key);
          accessOrder.add(key);

          await Ref.updateGlobalMeta(config, {'lru_access_order': accessOrder});
        }
      },
      [
        PVActionContext('put', priority: 10, isPost: true),
        PVActionContext('getRecord', priority: 10, isPost: true),
      ],
    );
  }

  /// Evicts LRU items when over maxSize
  static PVActionHook _createEvictLRUHook(int maxSize) {
    return PVActionHook((ctxRef) async {
      final ctx = ctxRef as PVRuntimeCtx;
      final key = ctx.overrideCtx.key;

      if (key != null) {
        final config = ctx.config;
        final accessOrder = List<String>.from(
          await Ref.getGlobalMetaValue(
            config,
            'lru_access_order',
            defaultValue: <String>[],
          ),
        );

        if (accessOrder.length > maxSize) {
          final lruKey = accessOrder.first;
          accessOrder.removeAt(0);

          final storeRef = await Db.resolve(config);
          await storeRef.delete(lruKey);

          await Ref.updateGlobalMeta(config, {'lru_access_order': accessOrder});
        }
      }
    }, [PVActionContext('put', priority: 5, isPost: true)]);
  }

  /// Checks expiration and removes from LRU tracking
  static PVActionHook _createCheckTTLHook() {
    return PVActionHook((ctxRef) async {
      final ctx = ctxRef as PVRuntimeCtx;
      final metadata = ctx.retrievedMetadata;

      if (metadata.containsKey('created_at') && metadata.containsKey('ttl')) {
        final createdAt = metadata['created_at'] as int;
        final ttl = metadata['ttl'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - createdAt > ttl) {
          final config = ctx.config;

          // Remove from LRU tracking in global metadata
          final accessOrder = List<String>.from(
            await Ref.getGlobalMetaValue(
              config,
              'lru_access_order',
              defaultValue: <String>[],
            ),
          );

          accessOrder.remove(ctx.overrideCtx.key);

          await Ref.updateGlobalMeta(config, {'lru_access_order': accessOrder});

          // Delete expired item
          final storeRef = await Db.resolve(config);
          await storeRef.delete(ctx.overrideCtx.key!);

          ctx.normalReturn(null);
          ctx.earlyBreak(null);
        }
      }
    }, [PVActionContext('getRecord', priority: 10, isPost: true)]);
  }
}
