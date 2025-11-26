import 'package:pvcache/core/ctx/ctx.dart';

/// Reference wrapper for PVRuntimeCtx used in hooks
/// Provides access to runtime context without allowing direct modification
abstract class PVRuntimeCtxRef {
  /// Get the current return value
  dynamic get returnValue;

  /// Get the initial context
  PVCtx get initialCtx;

  /// Get the runtime data map
  Map<String, dynamic> get runtime;
}
