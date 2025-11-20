# Project Brief: PVCache v2 (Rewrite)

## Overview
PVCache is a Flutter package that provides a flexible, plugin-based caching system built on top of sembast (NoSQL database) and flutter_secure_storage. The package is undergoing a major architectural rewrite to address transaction handling, dependency management, and hook composition.

## Core Objective
Create a caching system that allows developers to:
- Store data with multiple storage backends (in-memory, sembast, secure storage)
- Implement custom caching policies through plugins (TTL, LRU, etc.)
- Maintain metadata alongside cached entries
- Support multiple environments
- Process cache operations through a configurable, dependency-aware pipeline
- **NEW**: Ensure atomic operations with proper transaction support
- **NEW**: Optimize execution through compile-time dependency analysis

## Key Features
1. **Multi-Backend Storage**: Support for in-memory, sembast, and secure storage backends
2. **Two-Tier Hook Architecture**: Stage hooks (framework) + Action hooks (user)
3. **Metadata Support**: Separate metadata storage for cache management
4. **Environment-Based**: Multi-environment support through factory pattern
5. **Dependency-Aware Pipeline**: Hooks declare produces/consumes for automatic ordering
6. **Transaction Support**: Atomic operations across multiple stages
7. **Compile-Time Optimization**: Build execution plans once, execute efficiently

## Architectural Changes (v1 → v2)

### Old Architecture (pvcache2)
- Direct hook system with EventFlow enum
- No transaction support (race conditions)
- Manual DB access in hooks
- Exception-based flow control (BreakHook)
- Simple context object

### New Architecture (pvcache - in progress)
- Stage hooks (framework) vs Action hooks (user)
- Transaction-wrapped stage sequences
- Produces/consumes dependency system
- State-based flow control (nextStep enum)
- Rich context with explicit return specification
- Factory-based configuration
- Compile-time execution plan building

## Intended Plugin Support
- **Lifetime/TTL**: Time-to-live expiration policies
- **LRU**: Least Recently Used eviction strategies (with proper transaction handling)
- **Encryption**: Full and selective encryption
- **Custom Policies**: Extensible hook system for any caching policy

## Technical Foundation
- **Language**: Dart/Flutter
- **Primary Dependencies**: 
  - `sembast` (v3.8.5+1) - NoSQL database with transaction support
  - `sembast_web` (v2.4.2) - Web support
  - `flutter_secure_storage` (v9.2.4) - Secure storage
  - `path_provider` (v2.1.4) - File system paths
- **SDK**: Dart 3.9.2+, Flutter 1.17.0+

## Current Status (November 19, 2025)
- ❌ **Architecture defined** - Documented in `/arch` folder
- ❌ **Core implementation** - Not yet started
- ❌ **Hook system** - Skeleton only (`lib/config/hook.dart`)
- ❌ **Context system** - Stub only (`lib/core/ctx.dart`)
- ❌ **Factory pattern** - Partial (`lib/config/`)
- ❌ **Tests** - Not yet written
- ❌ **Migration from v1** - Pending

## Success Criteria (v2)
- ❌ Clean, extensible API for cache operations (put, get, delete, clear, exists)
- ❌ Transaction-safe hook execution
- ❌ Dependency-based hook ordering
- ❌ Skip optimization for unused hooks
- ❌ Cross-platform support (mobile, web, desktop)
- ❌ Separate configurable storage for entries and metadata
- ❌ Working template plugins (TTL, LRU, encryption)
- ❌ Comprehensive test coverage
- ❌ Complete documentation
- ❌ Published package

## Next Steps
1. Implement `PVRuntimeCtx` with runtime/metadata/temp maps
2. Implement stage hook registry and built-in stage hooks
3. Implement dependency resolver and topological sort
4. Implement execution plan compiler
5. Implement executor with transaction support
6. Port TTL hooks to new architecture
7. Port LRU hooks to new architecture (test race condition fix)
8. Write comprehensive tests
9. Migrate examples from v1

## References
- **Old implementation**: `pvcache2/` folder (136 passing tests)
- **Architecture docs**: `memory-bank/arch/` folder
- **Old memory bank**: `memory-bank/old/` folder
