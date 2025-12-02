# Project Brief: PVCache

## Overview
PVCache is a **company-internal implementation layer** for HiveHook, providing encryption and simplified configuration for direct plug-and-play use in company projects.

## What "Implementation Layer" Means
PVCache is NOT a wrapper or abstraction - it's a **convenience package** that:
1. **Re-exports HiveHook** - Everything from HiveHook is directly available
2. **Adds ONE new plugin** - `createEncryptedHook()` for AES encryption with secure key management
3. **Provides company defaults** - Pre-configured PVConfig with sensible defaults
4. **Simplifies imports** - Single import instead of multiple HiveHook imports

**Users still use HiveHook's API directly** - PVCache just adds encryption capability and bundles everything together.

## Core Architecture
- **HiveHook**: Provides ALL functionality (hooks, TTL plugin, LRU plugin, cache operations)
- **PVCache Role**: Adds `createEncryptedHook()` plugin + re-exports HiveHook for convenience
- **Storage Backend**: Hive (via HiveHook) for cross-platform persistent storage

## Key Requirements

### 1. HiveHook Integration
- PVCache is a **thin wrapper** over HiveHook's HHive class
- Re-export HiveHook's existing TTL and LRU plugins (`createTTLPlugin`, `createLRUPlugin`)
- Add only what's missing: **EncryptedHook** with secure key management
- Simplify configuration for Flutter developers (PVConfig wraps HHConfig)

### 2. Encryption System (NEW - Not in HiveHook)
**EncryptedHook** - A HiveHook plugin that provides automatic encryption/decryption:
- Uses PointyCastle for AES encryption
- Key management via Flutter Secure Storage
- Configuration options:
  - `Uint8List? providedKey` - Optional pre-generated key
  - `bool autoGenerateKey` - Auto-generate key if none exists
  - `bool autoResetKey` - Clear storage and regenerate key on launch
  - `String? secureStorageTargetKey` - Key name in secure storage (default: configurable)

**Key Management Flow**:
1. Check if key exists in secure storage (using `secureStorageTargetKey`)
2. If `providedKey` supplied, use it and optionally store it
3. If `autoGenerateKey=true` and no key found, generate new AES key
4. If `autoResetKey=true`, clear associated storage and regenerate key
5. Store key in Flutter Secure Storage for persistence

### 3. Serialization
- SerializationHook for automatic data conversion
- Support for complex Dart types
- Integration with encryption layer

### 4. Plugins
- **createTTLPlugin** (from HiveHook): Time-to-live expiration - RE-EXPORT ONLY
- **createLRUPlugin** (from HiveHook): Least Recently Used eviction - RE-EXPORT ONLY  
- **createEncryptedHook** (NEW): Encryption/decryption with secure key management - IMPLEMENT

### 5. Cross-Platform Support
- Flutter Web (IndexedDB via Hive web)
- iOS/Android (Hive native)
- Desktop (Hive desktop)

## Success Criteria
- EncryptedHook works with HiveHook's existing TTL/LRU plugins
- Encryption working with secure key storage (Flutter Secure Storage)
- Simple API: PVCache wraps HHive, PVConfig wraps HHConfig
- All plugins composable (Encrypted + TTL + LRU together)
- Clear documentation for company internal use
- Example demonstrating all features

## Constraints
- Must maintain backward compatibility with existing PVCache API where possible
- HiveHook handles the core hook system - don't duplicate functionality
- Encryption must be opt-in, not mandatory
- Key storage must be secure (Flutter Secure Storage only)

## Dependencies
- hivehook: ^1.0.0 (or latest)
- hive: via hivehook
- pointycastle: for AES encryption
- flutter_secure_storage: for key persistence
