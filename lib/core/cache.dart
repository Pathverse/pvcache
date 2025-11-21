import '../config/config.dart';
import 'ctx.dart';

class PVCache {
  static final Map<String, PVCache> _instances = {};
  static PVCache? getInstance(String env) => _instances[env];

  final PVConfig _config;

  PVCache._(this._config) {
    _instances[_config.env] = this;
  }

  factory PVCache.create(PVConfig config) {
    if (_instances.containsKey(config.env)){
      return _instances[config.env]!;
    }

    return PVCache._(config);
  }

  // cache functions
  Future<dynamic> get(PVCtx ctx) async {
    final runtime = PVRuntimeCtx.fromConfig(_config, ctx);
    await runtime.invokeStage(_config.sequenceConfig.get);
    return runtime.getResult();
  }

  Future<void> put(PVCtx ctx) async {
    final runtime = PVRuntimeCtx.fromConfig(_config, ctx);
    await runtime.invokeStage(_config.sequenceConfig.put);
  }

  Future<void> delete(PVCtx ctx) async {
    final runtime = PVRuntimeCtx.fromConfig(_config, ctx);
    await runtime.invokeStage(_config.sequenceConfig.delete);
  }

  Future<void> clear(PVCtx ctx) async {
    final runtime = PVRuntimeCtx.fromConfig(_config, ctx);
    await runtime.invokeStage(_config.sequenceConfig.clear);
  }

  Future<Iterable<dynamic>> iterateKey(PVCtx ctx) async {
    final runtime = PVRuntimeCtx.fromConfig(_config, ctx);
    await runtime.invokeStage(_config.sequenceConfig.iterateKey);
    return runtime.getResult();
  }

  Future<Iterable<dynamic>> iterateValue(PVCtx ctx) async {
    final runtime = PVRuntimeCtx.fromConfig(_config, ctx);
    await runtime.invokeStage(_config.sequenceConfig.iterateValue);
    return runtime.getResult();
  }

  Future<Iterable<MapEntry<dynamic, dynamic>>> iterateEntry(PVCtx ctx) async {
    final runtime = PVRuntimeCtx.fromConfig(_config, ctx);
    await runtime.invokeStage(_config.sequenceConfig.iterateEntry);
    return runtime.getResult();
  }

  Future<void> dispose() async {
    _instances.remove(_config.env);
  }

  // helpers
  /// ifNotCached
  Future<dynamic> ifNotCached(
      PVCtx ctx,
      Future<dynamic> Function() computeFunction,
      ) async {
    var cachedValue = await get(ctx);
    if (cachedValue != null) {
      return cachedValue;
    }

    var computedValue = await computeFunction();
    await put(ctx);
    return computedValue;
  }

}
