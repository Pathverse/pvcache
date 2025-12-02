import 'package:hivehook/hivehook.dart';

/// All-in-one helper for managing HiveHook configurations and caches.
///
/// Example:
/// ```dart
/// // Register config
/// PVCache.registerConfig(env: 'mybox');
///
/// // Get cache instance
/// final cache = PVCache.getCache('mybox');
/// ```
class PVCache {
  static final Map<String, HHPlugin> _defaultPlugins = {};
  static final List<TerminalSerializationHook> _defaultTerminalHooks = [];

  /// Register a configuration for an environment.
  ///
  /// Must be called before HHiveCore.initialize().
  static void registerConfig({
    required String env,
    bool usesMeta = false,
    List<HHPlugin>? plugins,
  }) {
    final config = HHConfig(env: env, usesMeta: usesMeta);

    // Install default plugins
    for (final plugin in _defaultPlugins.values) {
      config.installPlugin(plugin);
    }

    // Install custom plugins
    if (plugins != null) {
      for (final plugin in plugins) {
        config.installPlugin(plugin);
      }
    }

    config.finalize();
  }

  /// Get a cache instance for the given environment.
  ///
  /// The environment must be registered first with registerConfig().
  static HHive getCache(String env) {
    return HHive(env: env);
  }

  /// Set default plugins to be applied to all registered configs.
  ///
  /// Must be called before registerConfig().
  static void setDefaultPlugins(List<HHPlugin> plugins) {
    _defaultPlugins.clear();
    for (final plugin in plugins) {
      _defaultPlugins[plugin.uid] = plugin;
    }
  }

  /// Set default terminal hooks to be applied to all registered configs.
  ///
  /// Must be called before registerConfig().
  static void setDefaultTHooks(List<TerminalSerializationHook> hooks) {
    _defaultTerminalHooks.clear();
    _defaultTerminalHooks.addAll(hooks);
  }
}
