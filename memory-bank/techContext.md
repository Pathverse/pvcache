# Technical Context: PVCache v2

## Technology Stack

### Core Framework
- **Flutter**: Cross-platform UI framework
- **Dart**: 3.9.2+
- **Flutter SDK**: 1.17.0+

### Primary Dependencies

#### Storage (Unchanged)
- **sembast** (3.8.5+1)
  - NoSQL database for mobile/desktop
  - **Transaction support** (critical for v2)
  - Document-based storage
  - Supports queries and atomic operations
  
- **sembast_web** (2.4.2)
  - Web implementation using IndexedDB
  - Same API as sembast for consistency
  - Transaction support on web

- **flutter_secure_storage** (9.2.4)
  - Encrypted storage for sensitive data
  - Platform-specific secure storage

#### File System (Unchanged)
- **path_provider** (2.1.4)
- **path** (1.9.0)

### Development Dependencies
- **flutter_test**: Testing framework
- **flutter_lints** (5.0.0): Code quality rules

## Project Structure (v2)

```
lib/
├── pvcache.dart           # Package exports (to be updated)
├── core/
│   ├── cache.dart         # PVCache main class (stub)
│   ├── ctx.dart           # PVRuntimeCtx (stub - needs implementation)
│   ├── bridge.dart        # PVBridge storage manager (existing)
│   ├── enums.dart         # NextStep, ReturnSpec (to be added)
│   ├── compiler.dart      # Stage compiler (to be added)
│   ├── executor.dart      # Plan executor (to be added)
│   └── resolver.dart      # Dependency resolver (to be added)
├── config/
│   ├── config.dart        # PVConfig (partial)
│   ├── factory.dart       # PVFactory (partial)
│   ├── hook.dart          # Hook classes (implemented)
│   ├── registry.dart      # Hook registry (partial)
│   └── sequence_config.dart # Sequence config (implemented)
├── builtin/
│   └── stage_hooks.dart   # Built-in stage hooks (to be added)
└── hooks/                 # User action hooks (to be ported)

memory-bank/
├── projectbrief.md        # Project overview
├── activeContext.md       # Current work
├── progress.md            # Status tracking
├── systemPatterns.md      # Architecture summary
├── productContext.md      # Use cases
├── techContext.md         # This file
├── arch/                  # Detailed architecture docs
│   ├── 01-architecture-overview.md
│   ├── 02-hook-system.md
│   ├── 03-context-system.md
│   └── 04-compilation-execution.md
└── old/                   # Archived v1 docs
```

## Platform Support (Unchanged)

### Web
- Uses `sembast_web` with IndexedDB
- Transaction support available
- Database stored in browser storage

### Mobile (iOS/Android)
- Uses `sembast` with file system storage
- Full transaction support
- Database in app documents directory

### Desktop (macOS/Windows/Linux)
- Uses `sembast` with file system storage
- Full transaction support
- Database in app documents directory

## Key Technical Changes (v1 → v2)

### 1. Transaction Support (NEW)
```dart
// Old (v1): No transactions
await store.record(key).put(db, value1);
await store.record(key2).put(db, value2);
// Not atomic - can fail between operations

// New (v2): Transaction-wrapped
await db.transaction((txn) async {
  await store.record(key).put(txn, value1);
  await store.record(key2).put(txn, value2);
  // Atomic - all or nothing
});
```

### 2. Context Structure (NEW)
```dart
// Old (v1): Flat context
class PVCtx {
  dynamic entryValue;
  Map<String, dynamic> runtimeMeta;
  Map<String, dynamic> runtimeData;
}

// New (v2): Structured context
class PVRuntimeCtx {
  Map<String, dynamic> runtime;    // Entry data
  Map<String, dynamic> metadata;   // Cache metadata
  Map<String, dynamic> temp;       // Inter-hook data
  NextStep nextStep;               // Flow control
  ReturnSpec whatToReturn;         // Return specification
  Transaction? transaction;        // DB transaction
}
```

### 3. Hook System (NEW)
```dart
// Old (v1): Single hook type
class PVCacheHook {
  EventFlow eventFlow;  // Enum
  int priority;
  List<ActionType> actionTypes;
  Future<void> Function(PVCtx) hookFunction;
}

// New (v2): Two-tier hooks
class PVCStageHook {
  List<String> produces;
  List<String> consumes;
  bool skippable;
  Future<void> Function(PVRuntimeCtx) hookFunction;
}

class PVCActionHook extends PVCBaseHook {
  String hookOn;        // Stage name (string)
  bool isPostHook;      // Pre or post attachment
}
```

### 4. Compilation (NEW)
```dart
// Old (v1): Hooks sorted at cache creation
_orderedPutHooks = hooks
    .where((h) => h.actionTypes.contains(ActionType.put))
    .toList()
  ..sort((a, b) => a.eventFlow.index.compareTo(b.eventFlow.index));

// New (v2): Full execution plan compiled
class ExecutionPlan {
  List<ExecutionStage> stages;
  bool requiresTransaction;
}

class ExecutionStage {
  String name;
  PVCStageHook? stageHook;
  List<PVCActionHook> preHooks;   // Ordered by dependencies
  List<PVCActionHook> postHooks;  // Ordered by dependencies
  bool canSkip;
}
```

## Development Setup (Unchanged)

### Prerequisites
- Flutter SDK (1.17.0+)
- Dart SDK (3.9.2+)

### Installation
```bash
flutter pub get
```

### Running Tests
```bash
flutter test
```

## Technical Constraints (v2)

### Transaction Isolation
- **Level**: Snapshot isolation (sembast default)
- **Scope**: Per-operation or per-stage sequence
- **Duration**: Short-lived (milliseconds typically)
- **Concurrency**: Multiple transactions can run, but serialize on conflicts

### Dependency Resolution
- **Algorithm**: Topological sort (Kahn's algorithm)
- **Complexity**: O(H + E) where H=hooks, E=edges
- **Constraints**: No circular dependencies allowed
- **Validation**: At compile-time (cache creation)

### Memory Management
- **Context**: One per operation, short-lived
- **Execution plans**: Cached per cache instance
- **Hook instances**: Reused across operations
- **Transactions**: Cleaned up automatically

### Performance Targets
- **Compilation**: <100ms for typical configurations
- **Execution overhead**: <10% vs. v1
- **Transaction overhead**: Minimal (sembast optimized)
- **Memory overhead**: <1MB per cache instance

## Build Configuration

- **Package name**: `pvcache`
- **Version**: 0.0.1 (will be 2.0.0 at release)
- **Homepage**: https://github.com/Pathverse/pvcache
- **Branch**: `dev1` (development branch)
- **Analysis options**: Standard configuration
- **License**: Defined in LICENSE file

## Testing Strategy (v2)

### Unit Tests
- Dependency resolver (topological sort)
- Hook ordering
- Context state transitions
- Return value resolution

### Integration Tests
- Transaction atomicity
- Race condition prevention (LRU counter)
- Hook composition (TTL + LRU + encryption)
- Error handling and rollback

### Performance Tests
- Compilation time benchmarks
- Execution time vs. v1 baseline
- Transaction overhead measurement
- Memory usage profiling

## Migration Technical Details

### Database Schema (No Changes)
- Same sembast structure
- Same store names
- Same key formats
- **Compatible**: v2 can read v1 data

### Breaking API Changes
1. Cache creation: Constructor → Factory
2. Hook definition: Add produces/consumes
3. Context access: `ctx.entryValue` → `ctx.runtime['value']`
4. Flow control: `throw BreakHook()` → `ctx.nextStep = break_`
5. Hook attachment: `EventFlow` → `hookOn: 'stage_name'`

### Compatibility Layer (Future)
Could add v1 compatibility wrapper:
```dart
// Wrapper translates v1 hooks to v2 format
PVCActionHook wrapV1Hook(PVCacheHookV1 oldHook) {
  return PVCActionHook(
    hookOn: _eventFlowToStageName(oldHook.eventFlow),
    produces: _inferProduces(oldHook),
    consumes: _inferConsumes(oldHook),
    hookFunction: (ctx) async {
      final oldCtx = _wrapContext(ctx);
      await oldHook.hookFunction(oldCtx);
      _unwrapContext(oldCtx, ctx);
    },
  );
}
```

## References

### v1 Implementation (pvcache2)
- Location: `../pvcache2/` directory
- Status: Fully functional, 136 tests passing
- Use as: Reference and baseline

### v2 Architecture
- Documentation: `memory-bank/arch/` directory
- Status: Design complete, implementation pending
- Use as: Implementation guide

### External Dependencies
- **sembast docs**: https://pub.dev/packages/sembast
- **Flutter docs**: https://flutter.dev
- **Dart docs**: https://dart.dev
