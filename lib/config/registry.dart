
import 'hook.dart';

class PVCHookRegistry {
  final Map<String, PVCStageHook> _stageHooks = {};

  List<String> get registeredStageHooks => _stageHooks.keys.toList();

  ImmutablePVCHookRegistry toImmutable() {
    return ImmutablePVCHookRegistry(stageHooks: Map.unmodifiable(_stageHooks));
  }
  
}

class ImmutablePVCHookRegistry {
  final Map<String, PVCStageHook> stageHooks;

  ImmutablePVCHookRegistry({required this.stageHooks});
}