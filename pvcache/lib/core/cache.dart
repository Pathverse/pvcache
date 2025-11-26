import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/ctx/ctx.dart';
import 'package:pvcache/core/ctx/runtime_ctx.dart';
import 'package:pvcache/db/db.dart';

class PVCache {
  static final Map<String, PVCache> _instances = {};

  final PVImmutableConfig config;

  PVCache._(this.config);

  /// Get an existing cache instance by environment name
  static PVCache? getInstance(String env) => _instances[env];

  /// Create or get a cache instance
  factory PVCache.create({String? env, PVImmutableConfig? config}) {
    if (config == null) {
      if (env == null) {
        throw Exception("Either 'env' or 'config' must be provided.");
      }
      if (_instances.containsKey(env)) {
        return _instances[env]!;
      }

      config = PVImmutableConfig.getInstance(env);
    }

    if (_instances.containsKey(config.env)) {
      return _instances[config.env]!;
    }

    _instances[config.env] ??= PVCache._(config);
    return _instances[config.env]!;
  }

  Future<Map<String, dynamic>?> _getRecord(PVRuntimeCtx ctx) async {
    await ctx.emit("parseMetadata");
    return await ctx.emit(
      "getRecord",
      func: (ctx) async {
        final storeRef = await ctx.getStoreRef();
        final record = await storeRef.getRecord(ctx.overrideCtx.key!);

        final retrievedMetadata = await ctx.emit(
          "getMetadata",
          func: (ctx) async {
            return Map<String, dynamic>.from(record?['metadata'] ?? {});
          },
          setOutput: false,
        );
        ctx.retrievedMetadata.addAll(retrievedMetadata);
        return record;
      },
      handlesBreak: true,
      setOutput: false,
    );
  }

  /// Get a cached value
  Future<dynamic> get(PVCtx ctx) async {
    final rctx = PVRuntimeCtx(config, ctx);
    await _getRecord(rctx);
    await rctx.emit(
      "getValue",
      func: (ctx) async {
        // Re-fetch record in case hooks modified it
        final storeRef = await ctx.getStoreRef();
        final record = await storeRef.getRecord(ctx.overrideCtx.key!);
        final value = record?['value'];
        ctx.normalReturn(value);
      },
      handlesBreak: true,
      setOutput: false,
    );
    return rctx.returnValue;
  }

  /// Store a value in the cache
  Future<void> put(PVCtx ctx) async {
    final rctx = PVRuntimeCtx(config, ctx);
    await _getRecord(rctx);
    await rctx.emit(
      "put",
      func: (ctx) async {
        final storeRef = await ctx.getStoreRef();
        await storeRef.put(
          ctx.overrideCtx.key!,
          ctx.overrideCtx.value,
          ctx.overrideCtx.metadata,
        );
      },
      handlesBreak: true,
    );
  }

  /// Delete a value from the cache
  Future<void> delete(PVCtx ctx) async {
    final rctx = PVRuntimeCtx(config, ctx);
    await _getRecord(rctx);
    await rctx.emit(
      "delete",
      func: (ctx) async {
        final storeRef = await ctx.getStoreRef();
        await storeRef.delete(ctx.overrideCtx.key!);
      },
      handlesBreak: true,
    );
  }

  /// Clear all values from the cache
  Future<void> clear(PVCtx ctx) async {
    final rctx = PVRuntimeCtx(config, ctx);
    await _getRecord(rctx);
    await rctx.emit(
      "clear",
      func: (ctx) async {
        final storeRef = await ctx.getStoreRef();
        await storeRef.clear();
      },
      handlesBreak: true,
    );
  }

  /// Check if a key exists in the cache
  Future<bool> containsKey(PVCtx ctx) async {
    final rctx = PVRuntimeCtx(config, ctx);
    final record = await _getRecord(rctx);
    await rctx.emit(
      "containsKey",
      func: (ctx) async {
        ctx.normalReturn(record != null);
      },
      handlesBreak: true,
      setOutput: false,
    );
    return rctx.returnValue;
  }

  /// Iterate over all keys in the cache
  Future<Iterable<String>> iterateKey(PVCtx ctx) async {
    final rctx = PVRuntimeCtx(config, ctx);
    await _getRecord(rctx);
    await rctx.emit(
      "iterateKey",
      func: (ctx) async {
        final keys = await Ref.getGlobalMetaValue(
          config,
          "keys",
          defaultValue: <String>[],
        );
        ctx.normalReturn(keys);
      },
      handlesBreak: true,
      setOutput: false,
    );
    return rctx.returnValue;
  }

  /// Iterate over all values in the cache
  Future<Iterable<dynamic>> iterateValue(PVCtx ctx) async {
    final rctx = PVRuntimeCtx(config, ctx);
    await _getRecord(rctx);
    await rctx.emit(
      "iterateValue",
      func: (ctx) async {
        final storeRef = await ctx.getStoreRef();
        final keys = await Ref.getGlobalMetaValue(
          config,
          "keys",
          defaultValue: <String>[],
        );
        final values = <dynamic>[];
        for (final key in keys) {
          final value = await storeRef.getValue(key);
          values.add(value);
        }
        ctx.normalReturn(values);
      },
      handlesBreak: true,
      setOutput: false,
    );
    return rctx.returnValue;
  }

  /// Iterate over all entries (key-value pairs) in the cache
  Future<Iterable<MapEntry<String, dynamic>>> iterateEntry(PVCtx ctx) async {
    final rctx = PVRuntimeCtx(config, ctx);
    await _getRecord(rctx);
    await rctx.emit(
      "iterateEntry",
      func: (ctx) async {
        final storeRef = await ctx.getStoreRef();
        final keys = await Ref.getGlobalMetaValue(
          config,
          "keys",
          defaultValue: <String>[],
        );
        final entries = <MapEntry<String, dynamic>>[];
        for (final key in keys) {
          final value = await storeRef.getValue(key);
          entries.add(MapEntry(key, value));
        }
        ctx.normalReturn(entries);
      },
      handlesBreak: true,
      setOutput: false,
    );
    return rctx.returnValue;
  }

  /// Dispose of this cache instance
  Future<void> dispose() async {
    _instances.remove(config.env);
  }

  /// Execute computeFunction if value is not cached, then cache the result
  Future<dynamic> ifNotCached(
    PVCtx ctx,
    Future<dynamic> Function() computeFunction,
  ) async {
    var cachedValue = await get(ctx);
    if (cachedValue != null) {
      return cachedValue;
    }

    var computedValue = await computeFunction();
    await put(ctx.copyWith(value: computedValue));
    return computedValue;
  }
}
