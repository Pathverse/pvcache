import 'package:pvcache/core/config.dart';
import 'package:pvcache/core/ctx/ctx.dart';
import 'package:pvcache/core/ctx/exception.dart';
import 'package:pvcache/core/ctx/runtime_ctx_ref.dart';
import 'package:pvcache/core/enums.dart';
import 'package:pvcache/db/db.dart';

class PVRuntimeCtx extends PVRuntimeCtxRef {
  final PVImmutableConfig config;
  @override
  final PVCtx initialCtx;

  PVCtx overrideCtx;

  @override
  final Map<String, dynamic> runtime = {};
  final Map<String, dynamic> retrievedMetadata = {};

  NextStep nextStep = NextStep.f_continue;
  dynamic output;
  @override
  dynamic returnValue;
  String? invokedEvent;

  PVRuntimeCtx(this.config, this.initialCtx) : overrideCtx = initialCtx;

  Future<dynamic> emit(
    String name, {
    Future<dynamic> Function(PVRuntimeCtx ctx)? func,
    bool handlesBreak = false,
    bool setOutput = true,
  }) async {
    try {
      invokedEvent = name;
      if (config.preActionHooks.containsKey(name)) {
        for (final hook in config.preActionHooks[name]!) {
          await invoke(hook.action, handlesBreak: handlesBreak);
        }
      }
      dynamic res;
      if (func != null) {
        res = await invoke(func, handlesBreak: handlesBreak);
        if (setOutput) {
          output = res;
          runtime[name] = output;
        }
      }

      if (config.postActionHooks.containsKey(name)) {
        for (final hook in config.postActionHooks[name]!) {
          await invoke(hook.action, handlesBreak: handlesBreak);
        }
      }
      invokedEvent = null;
      return res;
    } finally {
      invokedEvent = null;
    }
  }

  void earlyBreak([dynamic value]) {
    nextStep = NextStep.f_break;
    returnValue = value;
    throw PVCtrlException();
  }

  void normalReturn([dynamic value]) {
    nextStep = NextStep.f_continue;
    returnValue = value;
  }

  Future<dynamic> invoke(
    Future<dynamic> Function(PVRuntimeCtx ctx) func, {
    bool handlesBreak = false,
  }) async {
    try {
      final result = await func(this);
      return result;
    } on PVCtrlException catch (_) {
      if (nextStep == NextStep.f_continue) {
      } else if (nextStep == NextStep.f_break) {
        if (handlesBreak) {
          return returnValue;
        } else {
          rethrow;
        }
      }
    }
  }

  Future<Ref> getStoreRef() async {
    final db = await Db.resolve(config);
    return db;
  }
}
