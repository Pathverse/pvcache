

import '../core/cache.dart';
import 'config.dart';
import 'hook.dart';
import 'registry.dart';
import 'sequence_config.dart';

class PVFactory {
  final PVCHookRegistry hookRegistry;
  final PVSeqConfig sequenceConfig;
  final Map<String, List<PVCActionHook>> _actionHooks = {};
  final Map<String, dynamic> additionalSettings = {};

  PVFactory({
    required this.hookRegistry,
    required this.sequenceConfig,
  });

  factory PVFactory.fromDefault() {
    return PVFactory(
      hookRegistry: PVCHookRegistry(),
      sequenceConfig: PVSeqConfig(),
    );
  }

  /// function to check if the action hook hookon exists as a stage hook
  bool _validateActionHooks() {
    for (var hooks in _actionHooks.values) {
      for (var hook in hooks) {
        if (!hookRegistry.registeredStageHooks
            .any((stageHook) => stageHook == hook.hookOn)) {
          return false;
        }
      }
    }
    return true;
  }

  PVConfig generateConfig() {
    if (!_validateActionHooks()) {
      throw Exception(
          'One or more action hooks reference unregistered stage hooks.');
    }

    return PVConfig.fromFactory(
      
      additionalSettings,
      hookRegistry.toImmutable(),
      sequenceConfig.toImmutable(),
      _actionHooks,
    );
  }

  PVCache createCache() {
    final config = generateConfig();
    return PVCache.create(config);
  }
}