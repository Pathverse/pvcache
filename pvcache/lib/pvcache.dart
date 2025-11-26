/// PVCache - A hook-based extension layer for Sembast
///
/// PVCache extends Sembast with a powerful event-driven hook system,
/// enabling pre/post action hooks, encryption, multi-environment management,
/// and composable plugin behaviors like LRU and TTL.
library pvcache;

// Core API
export 'core/cache.dart' show PVCache;
export 'core/config.dart' show PVConfig, PVImmutableConfig, PVCPlugin;
export 'core/ctx/ctx.dart' show PVCtx;
export 'core/enums.dart' show StorageType, ValueType, NextStep;

// Hook System
export 'core/hooks/action_hook.dart' show PVActionHook, PVActionContext;
export 'core/ctx/runtime_ctx.dart' show PVRuntimeCtx;
export 'core/ctx/runtime_ctx_ref.dart' show PVRuntimeCtxRef;
export 'core/ctx/exception.dart' show PVCtrlException;

// Built-in Plugins
export 'hooks/lru.dart' show LRUPlugin;
export 'hooks/ttl.dart' show TTLPlugin, LRUTTLPlugin;

// Database Layer (for advanced usage)
export 'db/db.dart' show Db, Ref;
