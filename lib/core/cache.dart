import '../config/config.dart';

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
}
