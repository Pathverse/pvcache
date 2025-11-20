import '../core/ctx.dart';

class PVCBaseHook {
  final List<String> produces;
  final List<String> consumes;
  final bool skippable;
  final Future<void> Function(PVRuntimeCtx ctx) hookFunction;

  PVCBaseHook({
    this.skippable = false,
    required this.produces,
    required this.consumes,
    required this.hookFunction,
  });
}

class PVCStageHook extends PVCBaseHook {
  PVCStageHook({
    required super.produces,
    required super.consumes,
    required super.hookFunction,
    super.skippable,
  });
}

class PVCActionHook extends PVCBaseHook {
  final String hookOn;
  final bool isPostHook;
  

  PVCActionHook({
    required this.hookOn,
    required super.produces,
    required super.consumes,
    required super.hookFunction,
    super.skippable,
    this.isPostHook = true,
  });
}
