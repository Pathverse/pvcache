part of 'cache.dart';

class PVCacheHook {
  final String? eventString;
  final EventFlow eventFlow;
  final int priority;
  final List<ActionType> actionTypes;
  final Future<void> Function(PVCtx ctx) hookFunction;

  PVCacheHook({
    this.eventString,
    required this.eventFlow,
    this.priority = 0,
    this.actionTypes = const [
      ActionType.put,
      ActionType.get,
      ActionType.delete,
      ActionType.clear,
      ActionType.exists,
    ],
    required this.hookFunction,
  });
}

class BreakHook implements Exception {
  final String message;
  final BreakReturnType returnType;
  BreakHook([
    this.message = 'Hook execution halted.',
    this.returnType = BreakReturnType.none,
  ]);

  @override
  String toString() => 'BreakHook: $message';
}
