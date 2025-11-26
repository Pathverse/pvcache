import 'package:pvcache/core/enums.dart';
import 'package:pvcache/core/hooks/action_hook.dart';

class PVConfig {
  String env;
  ValueType valueStorageType;
  ValueType metadataStorageType;
  StorageType storageType;
  final Map<String, List<PVActionHook>> actionHooks;

  PVConfig(
    this.env, {
    this.valueStorageType = ValueType.std,
    this.metadataStorageType = ValueType.std,
    this.storageType = StorageType.std,
    Map<String, List<PVActionHook>>? actionHooks,
    List<PVCPlugin>? plugins,
  }) : actionHooks = actionHooks ?? {} {
    // Integrate plugins
    if (plugins != null) {
      for (final plugin in plugins) {
        for (final hook in plugin.actionHooks) {
          for (final context in hook.contexts) {
            this.actionHooks.putIfAbsent(context.event, () => []).add(hook);
          }
        }
      }
    }
  }

  PVImmutableConfig finalize() {
    return PVImmutableConfig.fromConfig(this);
  }
}

class PVImmutableConfig {
  static final Map<String, PVImmutableConfig> _instances = {};

  final String env;
  final ValueType valueStorageType;
  final ValueType metadataStorageType;
  final StorageType storageType;
  final Map<String, List<PVActionHook>> preActionHooks;
  final Map<String, List<PVActionHook>> postActionHooks;

  const PVImmutableConfig._(
    this.env,
    this.valueStorageType,
    this.metadataStorageType,
    this.storageType,
    this.preActionHooks,
    this.postActionHooks,
  );

  factory PVImmutableConfig.fromConfig(PVConfig config) {
    if (_instances.containsKey(config.env)) {
      throw Exception(
        "PVImmutableConfig for env '${config.env}' already exists.",
      );
    }
    // sort and filter pre and post action hooks
    final preHooks = <String, List<PVActionHook>>{};
    final postHooks = <String, List<PVActionHook>>{};

    for (final entry in config.actionHooks.entries) {
      final event = entry.key;
      final hooks = entry.value;

      for (final hook in hooks) {
        for (final context in hook.contexts) {
          if (context.event == event) {
            if (context.isPost) {
              postHooks.putIfAbsent(event, () => []).add(hook);
            } else {
              preHooks.putIfAbsent(event, () => []).add(hook);
            }
          }
        }
      }
    }

    // Sort by priority
    for (final event in preHooks.keys) {
      preHooks[event]!.sort((a, b) {
        final aPriority = a.contexts
            .firstWhere((c) => c.event == event)
            .priority;
        final bPriority = b.contexts
            .firstWhere((c) => c.event == event)
            .priority;
        return bPriority.compareTo(aPriority);
      });
    }

    for (final event in postHooks.keys) {
      postHooks[event]!.sort((a, b) {
        final aPriority = a.contexts
            .firstWhere((c) => c.event == event)
            .priority;
        final bPriority = b.contexts
            .firstWhere((c) => c.event == event)
            .priority;
        return bPriority.compareTo(aPriority);
      });
    }

    //
    _instances[config.env] ??= PVImmutableConfig._(
      config.env,
      config.valueStorageType,
      config.metadataStorageType,
      config.storageType,
      Map.unmodifiable(preHooks),
      Map.unmodifiable(postHooks),
    );
    return _instances[config.env]!;
  }

  static PVImmutableConfig getInstance(String env) {
    final instance = _instances[env];
    if (instance == null) {
      throw Exception("PVImmutableConfig for env '$env' does not exist.");
    }
    return instance;
  }
}

class PVCPlugin {
  final List<PVActionHook> actionHooks;

  PVCPlugin({required this.actionHooks});
}
