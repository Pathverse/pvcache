import 'package:pvcache/core/ctx/runtime_ctx_ref.dart';

class PVActionContext {
  final String event;
  final int priority;
  final bool isPost;

  PVActionContext(
    this.event, {
    this.priority = 0,
    this.isPost = false,
  });
}

class PVActionHook {
  final Future<void> Function(PVRuntimeCtxRef ctx) action;
  final List<PVActionContext> contexts;

  PVActionHook(this.action, this.contexts);
}
