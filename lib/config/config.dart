import 'hook.dart';
import 'registry.dart';
import 'sequence_config.dart';

class PVConfig {
  static Map<String, PVConfig> _instances = {};
  static PVConfig? getInstance(String env) => _instances[env];
  static PVConfig ensureInstance(String env) => _instances[env]!;

  final String env;

  final bool createSeparateFileForNonWeb;

  final ImmutablePVSeqConfig sequenceConfig;
  final ImmutablePVCHookRegistry hookRegistry;
  final Map<String, List<PVCActionHook>> actionHooks;

  PVConfig({
    required this.env,
    required this.sequenceConfig,
    required this.hookRegistry,
    required Map<String, List<PVCActionHook>>? actionHooks,
    this.createSeparateFileForNonWeb = false,
  }) : actionHooks = Map.unmodifiable(actionHooks ?? {}) {
    if (_instances.containsKey(env)) {
      throw Exception('PVConfig for environment "$env" already exists.');
    }
    _instances[env] = this;
  }

  factory PVConfig.fromFactory(
    Map<String, dynamic> envConfig,
    ImmutablePVCHookRegistry hookRegistry,
    ImmutablePVSeqConfig sequenceConfig,
    Map<String, List<PVCActionHook>>? actionHooks,
  ) {
    return PVConfig(
      env: envConfig['env'] as String,
      createSeparateFileForNonWeb:
          envConfig['createSeparateFileForNonWeb'] as bool? ?? false,
      hookRegistry: hookRegistry,
      sequenceConfig: sequenceConfig,
      actionHooks: actionHooks,
    );
  }
}
