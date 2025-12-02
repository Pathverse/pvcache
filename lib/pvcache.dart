/// PVCache - A Flutter cache package with encryption support via HiveHook
///
/// This package provides:
/// - Re-exports of HiveHook core (HHive, HHConfig, HHiveCore, etc.)
/// - Encryption support via createEncryptedHook()
/// - PVCache helper (registerConfig, getCache, setDefaultPlugins, setDefaultTHooks)
library pvcache;

// Re-export HiveHook core
export 'package:hivehook/hivehook.dart';

// Export PVCache helper
export 'core/pvcache.dart';

// Export encryption hook
export 'hooks/encrypted_hook.dart';
