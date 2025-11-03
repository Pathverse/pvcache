/// PVCache - A flexible caching library for Flutter with hook-based extensibility.
///
/// Supports TTL expiration, LRU eviction, encryption, and custom hooks.
///
/// Import hook packages separately:
/// - `package:pvcache/hooks/ttl.dart`
/// - `package:pvcache/hooks/lru.dart`
/// - `package:pvcache/hooks/encryption.dart`
/// - `package:pvcache/hooks/selective_encryption.dart`
library;

// Core exports
export 'core/cache.dart'
    show PVCache, PVCtx, PVCtxStorageProxy, PVCacheHook, BreakHook;
export 'core/enums.dart'
    show ActionType, EventFlow, StorageType, BreakReturnType;
export 'core/top.dart' show PVCacheTop;
export 'core/bridge.dart' show PVBridge;
