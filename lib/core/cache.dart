import 'package:pvcache/core/bridge.dart';
import 'package:pvcache/core/enums.dart';
import 'package:sembast/sembast.dart';

part 'ctx.dart';
part 'hook.dart';

class PVCache {
  static final Map<String, PVCache> instances = {};

  final String env;
  final Map<String, dynamic> defaultMetadata;
  final StorageType entryStorageType;
  final StorageType metadataStorageType;
  final bool noMetadataStoreIfEmpty;
  final String Function(String)? metadataNameFunction;
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

  // parsing
  late final List<PVCacheHook> _hooks;
  late final List<PVCacheHook> _orderedPutHooks;
  late final List<PVCacheHook> _orderedGetHooks;
  late final List<PVCacheHook> _orderedDeleteHooks;
  late final List<PVCacheHook> _orderedClearHooks;
  late final List<PVCacheHook> _orderedExistsHooks;

  // !methods
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

  Future<void> delete(String key, {Map<String, dynamic>? metadata}) async {
    final ctx = PVCtx(
      cache: this,
      actionType: ActionType.delete,
      initialKey: key,
      initialMeta: metadata ?? {},
    );
    await ctx.queue(_orderedDeleteHooks);
  }

  Future<void> clear({Map<String, dynamic>? metadata}) async {
    final ctx = PVCtx(
      cache: this,
      actionType: ActionType.clear,
      initialMeta: metadata ?? {},
    );
    await ctx.queue(_orderedClearHooks);
  }

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
