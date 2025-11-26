import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/hooks/action_hook.dart';
import 'package:pvcache/core/ctx/runtime_ctx.dart';
import 'package:pvcache/db/db.dart';

/// LRU (Least Recently Used) cache plugin
///
/// Tracks access order in global metadata and evicts least recently used items
/// when the cache exceeds maxSize.
class LRUPlugin extends PVCPlugin {
  final int maxSize;

  LRUPlugin({required this.maxSize})
    : super(
        actionHooks: [_createTrackAccessHook(), _createEvictLRUHook(maxSize)],
      );

  /// Tracks access order for both put and get operations
  static PVActionHook _createTrackAccessHook() {
    return PVActionHook(
      (ctxRef) async {
        final ctx = ctxRef as PVRuntimeCtx;
        final key = ctx.overrideCtx.key;

        if (key != null) {
          final config = ctx.config;

          // Get current access order from global metadata
          final accessOrder = List<String>.from(
            await Ref.getGlobalMetaValue(
              config,
              'lru_access_order',
              defaultValue: <String>[],
            ),
          );

          // Update access order
          accessOrder.remove(key);
          accessOrder.add(key);

          // Persist to global metadata
          await Ref.updateGlobalMeta(config, {'lru_access_order': accessOrder});
        }
      },
      [
        PVActionContext('put', priority: 10, isPost: true),
        PVActionContext('getRecord', priority: 10, isPost: true),
      ],
    );
  }

  /// Evicts least recently used items when cache exceeds maxSize
  static PVActionHook _createEvictLRUHook(int maxSize) {
    return PVActionHook((ctxRef) async {
      final ctx = ctxRef as PVRuntimeCtx;
      final key = ctx.overrideCtx.key;

      if (key != null) {
        final config = ctx.config;

        // Get current access order from global metadata
        final accessOrder = List<String>.from(
          await Ref.getGlobalMetaValue(
            config,
            'lru_access_order',
            defaultValue: <String>[],
          ),
        );

        // If over limit, evict least recently used
        if (accessOrder.length > maxSize) {
          final lruKey = accessOrder.first;
          accessOrder.removeAt(0);

          // Delete the evicted item
          final storeRef = await Db.resolve(config);
          await storeRef.delete(lruKey);

          // Update global metadata
          await Ref.updateGlobalMeta(config, {'lru_access_order': accessOrder});
        }
      }
    }, [PVActionContext('put', priority: 5, isPost: true)]);
  }
}
