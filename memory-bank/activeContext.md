# Active Context: PVCache

## Current Work Focus
All major features complete. Ready for package polish and publication.

## Recent Implementations

### Macro Get Feature (Nov 8, 2025)
Pattern-based auto-fetch integrated into `PVCache.get()` core method. Checks patterns after hook pipeline if returnValue is null, fetches and caches data automatically. Works with all hooks (TTL, LRU, encryption). 19 tests passing.

Full and selective field encryption with AES-256-CTR. Shared utilities in `lib/utils/`. Security fix: removed key name from metadata. 21 tests passing (10 full + 11 selective).

## Core Features

**Hooks**: TTL (8 tests), LRU (6 tests), Encryption (10 tests), Selective Encryption (11 tests)
**Macro Get**: Pattern-based auto-fetch (19 tests)
**Examples**: Full demonstration in `example/` directory
**Tests**: 136 passing total

## Next Steps

1. Package polish: Update main README, export hooks in lib/pvcache.dart
2. Publish to pub.dev

## Key Architecture Decisions

### Reserved Keys
Keys starting with `_` are system-reserved (e.g., `_ttl_timestamp`, `_lru_count`, `_encryption_nonces`). Need validation to prevent user creation.

### Hook Ordering
Hooks sorted by EventFlow stage, then priority (int). Lower priority runs first within same stage.

### Macro Get Integration
Integrated into core `PVCache.get()` instead of hook because BreakHook stops subsequent hooks. Runs after pipeline if returnValue is null. Works with all hooks without special cases.

### Dual Database Architecture  
Separate sembast databases for persistent and in-memory storage. No redundant maps. Unified API.

### Metadata Mutability
Metadata loaded before hooks run. Creates mutable copy for hooks to modify.