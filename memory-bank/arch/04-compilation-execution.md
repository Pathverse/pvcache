# Compilation and Execution Strategy

## Overview

The new architecture uses a two-phase approach:
1. **Compilation**: Build execution plans at cache creation (one-time cost)
2. **Execution**: Run compiled plans for each operation (optimized)

## Compilation Phase

### Input
```dart
// Sequence configuration
PVSeqConfig(
  get: ['metadata_get', 'metadata_parse', 'value_get', 'value_parse'],
  put: ['metadata_get', 'metadata_prepare', 'value_prepare', 'value_put', 'metadata_put'],
)

// Hook registry (stage hooks)
PVCHookRegistry(
  stageHooks: {
    'metadata_get': metadataGetHook,
    'metadata_parse': metadataParseHook,
    'value_get': valueGetHook,
    // ...
  }
)

// Action hooks (user-defined)
Map<String, List<PVCActionHook>> actionHooks = {
  'metadata_parse': [ttlCheckHook, lruUpdateHook],
  'value_parse': [decryptionHook],
  'metadata_prepare': [ttlSetHook],
  'value_prepare': [encryptionHook],
}
```

### Output
```dart
class ExecutionPlan {
  final List<ExecutionStage> stages;
  final bool requiresTransaction;
}

class ExecutionStage {
  final String name;
  final PVCStageHook? stageHook;
  final List<PVCActionHook> preHooks;   // isPostHook = false
  final List<PVCActionHook> postHooks;  // isPostHook = true
  final bool canSkip;
}
```

### Compilation Algorithm

```dart
class StageCompiler {
  ExecutionPlan compile(
    List<String> sequenceNames,
    PVCHookRegistry registry,
    Map<String, List<PVCActionHook>> actionHooks,
  ) {
    final stages = <ExecutionStage>[];
    
    for (final stageName in sequenceNames) {
      // Get stage hook from registry
      final stageHook = registry.stageHooks[stageName];
      
      // Get action hooks for this stage
      final stageActionHooks = actionHooks[stageName] ?? [];
      
      // Separate pre and post hooks
      final preHooks = stageActionHooks
          .where((h) => !h.isPostHook)
          .toList();
      final postHooks = stageActionHooks
          .where((h) => h.isPostHook)
          .toList();
      
      // Order hooks by dependencies
      final orderedPreHooks = _orderByDependencies(preHooks);
      final orderedPostHooks = _orderByDependencies(postHooks);
      
      // Determine if stage can be skipped
      final canSkip = _canSkipStage(stageHook, orderedPreHooks, orderedPostHooks);
      
      stages.add(ExecutionStage(
        name: stageName,
        stageHook: stageHook,
        preHooks: orderedPreHooks,
        postHooks: orderedPostHooks,
        canSkip: canSkip,
      ));
    }
    
    return ExecutionPlan(
      stages: stages,
      requiresTransaction: _needsTransaction(stages),
    );
  }
  
  /// Order hooks using topological sort based on produces/consumes
  List<PVCActionHook> _orderByDependencies(List<PVCActionHook> hooks) {
    // Build dependency graph
    final graph = <PVCActionHook, List<PVCActionHook>>{};
    final inDegree = <PVCActionHook, int>{};
    
    for (final hook in hooks) {
      graph[hook] = [];
      inDegree[hook] = 0;
    }
    
    // For each hook, find which hooks depend on it
    for (final hook in hooks) {
      for (final otherHook in hooks) {
        if (hook == otherHook) continue;
        
        // Does otherHook consume what hook produces?
        final consumes = otherHook.consumes.toSet();
        final produces = hook.produces.toSet();
        
        if (consumes.intersection(produces).isNotEmpty) {
          // otherHook depends on hook
          graph[hook]!.add(otherHook);
          inDegree[otherHook] = inDegree[otherHook]! + 1;
        }
      }
    }
    
    // Topological sort (Kahn's algorithm)
    final queue = <PVCActionHook>[];
    final result = <PVCActionHook>[];
    
    // Start with hooks that have no dependencies
    for (final hook in hooks) {
      if (inDegree[hook] == 0) {
        queue.add(hook);
      }
    }
    
    while (queue.isNotEmpty) {
      final hook = queue.removeAt(0);
      result.add(hook);
      
      // Process hooks that depend on this one
      for (final dependent in graph[hook]!) {
        inDegree[dependent] = inDegree[dependent]! - 1;
        if (inDegree[dependent] == 0) {
          queue.add(dependent);
        }
      }
    }
    
    // Check for circular dependencies
    if (result.length != hooks.length) {
      throw Exception('Circular dependency detected in hooks');
    }
    
    return result;
  }
  
  /// Determine if stage can be skipped
  bool _canSkipStage(
    PVCStageHook? stageHook,
    List<PVCActionHook> preHooks,
    List<PVCActionHook> postHooks,
  ) {
    // Stage can be skipped if:
    // 1. Stage hook is null (empty checkpoint)
    // 2. All action hooks are skippable
    // 3. Nothing downstream consumes what this stage produces
    
    if (stageHook != null && !stageHook.skippable) {
      return false;  // Stage hook is required
    }
    
    // Check if any action hook is required
    for (final hook in [...preHooks, ...postHooks]) {
      if (!hook.skippable) {
        return false;
      }
    }
    
    return true;  // Can potentially skip
  }
  
  /// Determine if plan needs transaction wrapping
  bool _needsTransaction(List<ExecutionStage> stages) {
    // Simple heuristic: if any stage does DB writes, use transaction
    for (final stage in stages) {
      if (stage.stageHook?.requiresTransaction ?? false) {
        return true;
      }
    }
    return false;
  }
}
```

### Dependency Analysis Example

#### Input Hooks:
```dart
Hook A: produces: ['metadata._lru_count']
        consumes: []

Hook B: produces: ['metadata._ttl_timestamp']
        consumes: ['metadata.ttl']

Hook C: produces: ['temp.validated']
        consumes: ['metadata._ttl_timestamp']

Hook D: produces: []
        consumes: ['temp.validated', 'metadata._lru_count']
```

#### Dependency Graph:
```
Hook A → Hook D (D consumes _lru_count)
Hook B → Hook C (C consumes _ttl_timestamp)
Hook C → Hook D (D consumes validated)
```

#### Topological Sort:
```
Start: [A, B] (no dependencies)
Process A → Add D to queue (after all deps satisfied)
Process B → Add C to queue
Process C → D already queued
Process D
Result: [A, B, C, D] or [B, A, C, D] (both valid)
```

### Skip Optimization Example

```dart
// Stage with skippable hooks
ExecutionStage(
  name: 'metadata_parse',
  stageHook: null,  // Empty checkpoint
  postHooks: [
    Hook(skippable: true, produces: ['temp.log']),
    Hook(skippable: false, produces: ['metadata._ttl_checked']),
  ],
  canSkip: false,  // Has required hook
)

// Stage that CAN be skipped
ExecutionStage(
  name: 'value_parse',
  stageHook: null,
  postHooks: [
    Hook(skippable: true, produces: ['temp.stats']),
  ],
  canSkip: true,  // All hooks skippable
)
```

Runtime check:
```dart
if (stage.canSkip && !_isDataNeeded(stage)) {
  continue;  // Skip entire stage
}
```

## Execution Phase

### Executor Implementation

```dart
class Executor {
  Future<dynamic> execute(
    ExecutionPlan plan,
    PVRuntimeCtx ctx,
  ) async {
    if (plan.requiresTransaction) {
      return await _executeWithTransaction(plan, ctx);
    } else {
      return await _executeWithoutTransaction(plan, ctx);
    }
  }
  
  Future<dynamic> _executeWithTransaction(
    ExecutionPlan plan,
    PVRuntimeCtx ctx,
  ) async {
    final bridge = PVBridge();
    final db = await bridge.getDatabaseForType(storageType);
    
    return await db.transaction((txn) async {
      ctx.transaction = txn;
      try {
        return await _executeStages(plan.stages, ctx);
      } finally {
        ctx.transaction = null;
      }
    });
  }
  
  Future<dynamic> _executeWithoutTransaction(
    ExecutionPlan plan,
    PVRuntimeCtx ctx,
  ) async {
    return await _executeStages(plan.stages, ctx);
  }
  
  Future<dynamic> _executeStages(
    List<ExecutionStage> stages,
    PVRuntimeCtx ctx,
  ) async {
    for (final stage in stages) {
      // Check if can skip
      if (stage.canSkip && !_isStageNeeded(stage, ctx)) {
        continue;
      }
      
      // Execute pre-hooks
      for (final hook in stage.preHooks) {
        await hook.hookFunction(ctx);
        if (ctx.nextStep != NextStep.continue_) {
          return _resolveReturn(ctx);
        }
      }
      
      // Execute stage hook
      if (stage.stageHook != null) {
        await stage.stageHook!.hookFunction(ctx);
        if (ctx.nextStep != NextStep.continue_) {
          return _resolveReturn(ctx);
        }
      }
      
      // Execute post-hooks
      for (final hook in stage.postHooks) {
        await hook.hookFunction(ctx);
        if (ctx.nextStep != NextStep.continue_) {
          return _resolveReturn(ctx);
        }
      }
    }
    
    return _resolveReturn(ctx);
  }
  
  bool _isStageNeeded(ExecutionStage stage, PVRuntimeCtx ctx) {
    // Check if anything downstream needs what this stage produces
    // This requires tracking what data is consumed later in the plan
    // For now, always execute (optimization TODO)
    return true;
  }
  
  dynamic _resolveReturn(PVRuntimeCtx ctx) {
    switch (ctx.whatToReturn.source) {
      case 'NULL':
        return null;
      case 'RUNTIME':
        return ctx.runtime[ctx.whatToReturn.key];
      case 'METADATA':
        return ctx.metadata[ctx.whatToReturn.key];
      case 'TEMP':
        return ctx.temp[ctx.whatToReturn.key];
      case 'LITERAL':
        return ctx.whatToReturn.value;
      default:
        return null;
    }
  }
}
```

## Performance Characteristics

### Compilation (One-Time)
- **Time**: O(H log H) where H = number of hooks
  - Topological sort: O(H + E) where E = edges in dependency graph
  - In practice: milliseconds for hundreds of hooks
- **Space**: O(H) for execution plans
- **When**: Cache initialization only

### Execution (Per Request)
- **Time**: O(S * H) where S = stages, H = hooks per stage
  - Skip optimization: O(S) in best case
  - Transaction overhead: minimal (sembast is optimized)
- **Space**: O(1) - context reused, no allocations in hot path
- **When**: Every cache operation

### Optimization Opportunities

#### 1. Skip Analysis at Compile Time
```dart
// Build consumption map during compilation
Map<String, Set<String>> consumptionMap = {};
for (final stage in stages) {
  for (final hook in [...stage.preHooks, ...stage.postHooks]) {
    for (final consumes in hook.consumes) {
      consumptionMap.putIfAbsent(stage.name, () => {}).add(consumes);
    }
  }
}

// Mark stages as truly skippable
stage.canSkip = stage.allHooksSkippable && 
                !consumptionMap.values.any((s) => s.contains(stage.produces));
```

#### 2. Parallel Execution (Future)
```dart
// Identify stages with no dependencies
List<ExecutionStage> parallelStages = stages
    .where((s) => s.consumes.isEmpty)
    .toList();

// Execute in parallel
await Future.wait(
  parallelStages.map((s) => _executeStage(s, ctx))
);
```

#### 3. Memoization
```dart
// Cache compiled plans per operation type
Map<String, ExecutionPlan> _planCache = {
  'get': compiledGetPlan,
  'put': compiledPutPlan,
  // ...
};
```

## Transaction Isolation Levels

### Sembast Transaction Characteristics
- **Isolation**: Snapshot isolation (reads see consistent snapshot)
- **Atomicity**: All-or-nothing (rollback on error)
- **Duration**: Transaction held for entire stage sequence

### Example: LRU Race Condition Solved

#### Without Transaction (OLD - Race Condition):
```
Request A: Read counter = 5
Request B: Read counter = 5
Request A: Write counter = 6
Request B: Write counter = 6  ❌ Should be 7
```

#### With Transaction (NEW - Correct):
```
Request A: Start transaction
Request A: Read counter = 5
Request A: Write counter = 6
Request A: Commit
Request B: Start transaction (sees committed state)
Request B: Read counter = 6  ✅
Request B: Write counter = 7
Request B: Commit
```

## Error Handling

### Compilation Errors
```dart
try {
  final plan = compiler.compile(sequence, registry, actionHooks);
} on CircularDependencyException catch (e) {
  throw Exception('Hook dependency cycle: ${e.cycle}');
} on UnknownStageException catch (e) {
  throw Exception('Action hook references unknown stage: ${e.stageName}');
}
```

### Execution Errors
```dart
try {
  return await executor.execute(plan, ctx);
} on Exception catch (e) {
  if (ctx.nextStep == NextStep.error) {
    // Hook set error state
    throw CacheException('Hook error: $e');
  } else {
    // Unexpected error
    throw CacheException('Execution error: $e');
  }
}
```

### Transaction Rollback
```dart
await db.transaction((txn) async {
  try {
    await _executeStages(stages, ctx);
  } catch (e) {
    // Transaction automatically rolls back on exception
    rethrow;
  }
});
```

## Testing Strategy

### Unit Tests
- Test dependency resolution with known graphs
- Test skip detection
- Test circular dependency detection
- Test transaction wrapping

### Integration Tests
- Test GET with TTL + encryption
- Test PUT with LRU + TTL
- Test concurrent operations (race conditions)
- Test transaction rollback on error

### Performance Tests
- Benchmark compilation time (thousands of hooks)
- Benchmark execution time (hot path)
- Compare with old architecture (baseline)
