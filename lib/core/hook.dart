part of 'cache.dart';

/// Defines a hook that executes during cache operations.
///
/// Hooks intercept and modify cache behavior at various lifecycle stages:
/// - TTL expiration
/// - LRU eviction
/// - Encryption/decryption
/// - Access tracking
/// - Validation
///
/// Example:
/// ```dart
/// final ttlHook = PVCacheHook(
///   eventString: 'ttl_check',
///   eventFlow: EventFlow.metaRead,
///   priority: 0,
///   actionTypes: [ActionType.get],
///   hookFunction: (ctx) async {
///     final timestamp = ctx.runtimeMeta['_ttl_timestamp'];
///     if (timestamp != null && DateTime.now().millisecondsSinceEpoch > timestamp) {
///       throw BreakHook('Entry expired');
///     }
///   },
/// );
/// ```
class PVCacheHook {
  /// Optional identifier for the hook (for debugging/logging).
  final String? eventString;

  /// Lifecycle stage where this hook executes.
  ///
  /// Sorted by [EventFlow] stage, then [priority] within each stage.
  final EventFlow eventFlow;

  /// Execution priority within the [eventFlow] stage.
  ///
  /// Lower values execute first. Default is 0.
  /// Example: -50 (early), 0 (default), 50 (late)
  final int priority;

  /// Operation types this hook responds to.
  ///
  /// Defaults to all types. Specify a subset for optimization.
  final List<ActionType> actionTypes;

  /// Function that executes when this hook is triggered.
  ///
  /// Receives [PVCtx] with entry value, metadata, and cache reference.
  /// Throw [BreakHook] to exit early and control return value.
  final Future<void> Function(PVCtx ctx) hookFunction;

  /// Creates a new cache hook.
  ///
  /// [eventFlow] and [hookFunction] are required. All other parameters are optional.
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

/// Exception to break hook execution early and control return value.
///
/// Stops remaining hooks and returns from the cache operation.
///
/// Example:
/// ```dart
/// if (isExpired) {
///   await ctx.entry.delete(ctx.resolvedKey!);
///   throw BreakHook('Entry expired', BreakReturnType.none); // Returns null
/// }
/// ```
class BreakHook implements Exception {
  /// Description of why execution was halted.
  final String message;

  /// Controls return value: none (null), initial, or resolved.
  final BreakReturnType returnType;

  BreakHook([
    this.message = 'Hook execution halted.',
    this.returnType = BreakReturnType.none,
  ]);

  @override
  String toString() => 'BreakHook: $message';
}
