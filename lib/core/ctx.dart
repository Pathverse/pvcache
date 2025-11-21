import '../config/config.dart';
import '../config/registry.dart';
import 'enums.dart';

class PVCtx {
  final String key;
  final dynamic value;
  final Map<String, dynamic> metadata;
  final ImmutablePVCHookRegistry? hookRegistry;

  PVCtx({
    required this.key,
    this.value,
    Map<String, dynamic>? metadata,
    this.hookRegistry,
  }) : metadata = Map.unmodifiable(metadata ?? {});
}

class PVRuntimeCtx {
  final PVCtx initialCtx;
  final PVConfig config;

  final Map<String, dynamic> runtimeMap = {};
  final Map<String, dynamic> metadataMap = {};
  final Map<String, dynamic> tempMap = {};

  // flow control var
  ReturnSpec returnSpec = ReturnSpec.runtimeKey;
  String returnKey = 'result';
  NextStep nextStep = NextStep.f_continue;

  PVRuntimeCtx._({required this.initialCtx, required this.config});

  factory PVRuntimeCtx.fromConfig(PVConfig config, PVCtx initialCtx) {
    return PVRuntimeCtx._(initialCtx: initialCtx, config: config);
  }

  Future<void> invokeStage(List<String> stages) async {
    final stageHooks = stages
        .where((stage) => config.hookRegistry.stageHooks.containsKey(stage))
        .map((stage) => config.hookRegistry.stageHooks[stage]!)
        .toList();

    for (var hook in stageHooks) {
      await hook.hookFunction(this);
    }
  }

  dynamic getResult() {
    switch (returnSpec) {
      case ReturnSpec.none:
        return null;
      case ReturnSpec.runtimeKey:
        return runtimeMap[returnKey];
      case ReturnSpec.tempKey:
        return tempMap[returnKey];
      case ReturnSpec.metadataKey:
        return metadataMap[returnKey];
    }
  }
}
