# Active Context

## Current Focus
Core implementation complete! All cache operations, hook system, and test suite are fully implemented and passing.

## Recent Changes (Latest Session)

### PVCtx API Enhancement (`lib/core/ctx/ctx.dart`) - COMPLETED
- **Changed constructor to named parameters**: `PVCtx(key: 'key', value: 'value', metadata: {})` instead of positional
- **Improved API ergonomics**: Optional parameters allow cleaner usage like `PVCtx(key: 'key')` or `PVCtx(key: 'key', value: 'value')`
- **Updated copyWith**: Now uses named parameters consistently `copyWith(key: key, value: value, metadata: metadata)`

### LRU and TTL Plugins (`lib/hooks/lru.dart`, `lib/hooks/ttl.dart`) - COMPLETED
- **LRUPlugin**: Tracks access order in global metadata, evicts least recently used items when exceeding maxSize
- **TTLPlugin**: Adds timestamp metadata on put, checks expiration on getRecord, auto-deletes expired items
- **LRUTTLPlugin**: Combined LRU + TTL functionality with proper cleanup of expired items from LRU tracking
- **Plugin integration**: Uses `PVCPlugin` base class, added via `plugins` parameter in PVConfig

### Comprehensive Plugin Tests - COMPLETED
- **lru_plugin_test.dart**: 11 tests for LRU eviction (tracking, updates, eviction, large datasets, stress tests)
- **ttl_plugin_test.dart**: 11 tests for TTL expiration (metadata, custom TTL, multiple items, re-adding)
- **lru_ttl_plugin_test.dart**: 10 tests for combined LRU+TTL (expiration with tracking, edge cases)
- **Total**: 32 new plugin tests, all passing
- **Test refactoring**: Updated all 198 PVCtx constructor calls across 5 test files to use named parameters

### Test Suite Refactoring - COMPLETED
- **Updated all test files**: cache_test.dart (44 calls), hooks_test.dart (9 calls), lru_plugin_test.dart (46 calls), ttl_plugin_test.dart (42 calls), lru_ttl_plugin_test.dart (57 calls)
- **Pattern applied**: Simplified calls by omitting optional parameters where appropriate
- **Result**: 66/66 tests passing (34 original + 32 new plugin tests) ✅

### Test Suite - CREATED & ALL PASSING
- **db_test.dart**: 10 tests covering database layer (initialization, storage types, CRUD operations, metadata)
- **cache_test.dart**: 15 tests covering PVCache API (all operations, metadata, iteration, edge cases)
- **hooks_test.dart**: 9 tests covering hook system (pre/post, priority, context access, metadata modification)
- **Fixed multiple test issues**:
  - Unique environment names to avoid PVImmutableConfig singleton conflicts
  - Database initialization flag in test mode
  - Type casting in metadata retrieval
  - Hook test logic for proper execution order verification
- **Result**: 34/34 tests passing ✅

### Key Fixes Applied
1. **Db.initialize()**: Now sets `_isDbInitialized = true` in test mode
2. **Type safety**: Explicit `Map<String, dynamic>.from()` for metadata
3. **Test environment names**: All unique to avoid singleton conflicts
4. **Assertion fix**: Test expectation updated to match unique environment name

## Next Steps

### High Priority
1. **Encryption support**
   - Integrate flutter_secure_storage
   - Implement crypto/pointycastle encryption
   - Honor ValueType.encrypted in config

### Medium Priority
2. **Public API exports** in `lib/pvcache.dart`
3. **Documentation**: API docs, usage examples, migration guide

## Active Decisions

### Database Centralization
**Decision**: Global metadata stored in mainDb only, not in separate environment databases.

**Rationale**: 
- Need to query across all environments
- Simplifies management
- Performance: single source of truth

**Impact**: Ref global metadata methods always use `Db.mainDb`

### Store Reference Pattern
**Decision**: Bundle StoreRef + Database + Config in Ref class.

**Rationale**:
- StoreRef alone doesn't know which database
- Operations need all three pieces
- Clean encapsulation

**Alternative considered**: Pass database to each operation (too verbose)

### Test Mode Design
**Decision**: Global static flag set before initialization.

**Rationale**:
- Prevents accidental file I/O during tests
- Clear initialization contract
- All-or-nothing (can't mix test/prod databases)

**Tradeoff**: Requires careful test setup/teardown

## Important Patterns and Preferences

### Error Handling
- Use `PVCtrlException` for cache-specific errors
- Throw on invalid state (e.g., uninitialized DB)
- Validate inputs early

### Async Patterns
- Always await Futures before passing to other methods
- Use transactions for atomic operations
- Prefer `async/await` over `.then()`

### Type Safety
- Explicit type annotations for public APIs
- Use generics where appropriate
- Avoid dynamic where possible

### Code Organization
- Separate concerns: storage, business logic, hooks
- Keep classes focused (single responsibility)
- Use factory patterns for singletons

## Learnings and Project Insights

### Sembast Store Behavior
Stores are just namespaces - creating a StoreRef doesn't create data structures. The database holds all data, stores just partition it.

### Async Pitfalls
Easy to accidentally pass a Future to a method expecting a value. Always await at the correct point in the call chain.

### Configuration Immutability
Making config immutable after creation prevents runtime bugs from state changes. The sorting/processing of hooks happens once at config finalization.

### Global State Management
Using static singletons for Db and PVImmutableConfig is appropriate here because:
- Database connections are inherently global
- Config should not change after initialization
- Simplifies API (no need to pass DB around everywhere)

### Test Mode Pattern
Setting test mode as a static flag before initialization is cleaner than:
- Dependency injection (would complicate API)
- Environment variables (platform-specific)
- Factory parameters (would leak into all method signatures)
