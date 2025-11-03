part of 'cache.dart';

/// Defines a hook that executes during cache operations.
///
/// Hooks allow you to intercept and modify cache behavior at various stages
/// of the operation lifecycle. They can be used to implement features like:
/// - TTL (Time-To-Live) expiration
/// - LRU (Least Recently Used) eviction
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

  /// The lifecycle stage where this hook executes.
  ///
  /// Hooks are executed in order of [EventFlow] stages, then by [priority]
  /// within each stage.
  final EventFlow eventFlow;

  /// Execution priority within the [eventFlow] stage.
  ///
  /// Lower priority values execute first. Default is 0.
  /// Negative priorities run before default, positive after.
  ///
  /// Example:
  /// - Priority -50: Runs early (e.g., encryption before storage)
  /// - Priority 0: Default order
  /// - Priority 50: Runs late (e.g., logging after operation)
  final int priority;

  /// Types of operations this hook should respond to.
  ///
  /// By default, hooks respond to all operation types. Specify a subset
  /// to optimize performance and control when the hook executes.
  ///
  /// Example:
  /// ```dart
  /// actionTypes: [ActionType.get, ActionType.exists] // Only on reads
  /// ```
  final List<ActionType> actionTypes;

  /// The function that executes when this hook is triggered.
  ///
  /// Receives a [PVCtx] context object containing:
  /// - `ctx.entryValue` - The current entry value
  /// - `ctx.runtimeMeta` - Metadata for this entry
  /// - `ctx.initialMeta` - Original metadata passed to operation
  /// - `ctx.cache` - Reference to the PVCache instance
  ///
  /// The hook can modify the context to affect the operation.
  /// Throw [BreakHook] to exit early and control the return value.
  ///
  /// Example:
  /// ```dart
  /// hookFunction: (ctx) async {
  ///   ctx.runtimeMeta['_accessed'] = DateTime.now();
  ///   ctx.entryValue = transform(ctx.entryValue);
  /// }
  /// ```
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

/// Exception thrown by hooks to break execution early and control return value.
///
/// When thrown from a hook, stops execution of remaining hooks and
/// immediately returns from the cache operation with a controlled result.
///
/// Example usage:
/// ```dart
/// // In a TTL check hook
/// if (isExpired) {
///   await ctx.entry.delete(ctx.resolvedKey!);
///   throw BreakHook('Entry expired', BreakReturnType.none); // Returns null
/// }
///
/// // In a validation hook
/// if (!isValid) {
///   throw BreakHook('Invalid data', BreakReturnType.initial); // Returns original value
/// }
/// ```
class BreakHook implements Exception {
  /// Description of why the hook execution was halted.
  final String message;

  /// Controls what value is returned from the cache operation.
  ///
  /// - [BreakReturnType.none]: Returns null
  /// - [BreakReturnType.initial]: Returns the initial value passed to the operation
  /// - [BreakReturnType.resolved]: Returns the current resolved value from context
  final BreakReturnType returnType;

  /// Creates a new BreakHook exception.
  ///
  /// [message] - Optional description (default: 'Hook execution halted.')
  /// [returnType] - Controls return value (default: [BreakReturnType.none])
  BreakHook([
    this.message = 'Hook execution halted.',
    this.returnType = BreakReturnType.none,
  ]);

  @override
  String toString() => 'BreakHook: $message';
}
