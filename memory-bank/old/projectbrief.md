# Project Brief: PVCache

## Overview
PVCache is a Flutter package that provides a flexible, plugin-based caching system built on top of sembast (NoSQL database) and flutter_secure_storage. The package is designed to support extensible caching strategies through a hook-based plugin architecture.

## Core Objective
Create a caching system that allows developers to:
- Store data with multiple storage backends (in-memory, sembast, secure storage)
- Implement custom caching policies through plugins (TTL, LRU, etc.)
- Maintain metadata alongside cached entries
- Support multiple environments
- Process cache operations through a configurable pipeline of hooks

## Key Features
1. **Multi-Backend Storage**: Support for in-memory, sembast, and secure storage backends
2. **Plugin Architecture**: Hook-based system for implementing caching policies
3. **Metadata Support**: Separate metadata storage for cache management
4. **Environment-Based**: Multi-environment support for different configurations
5. **Flexible Pipeline**: Ordered hook execution through different event flows

## Intended Plugin Support
- **Lifetime/TTL**: Time-to-live expiration policies
- **LRU**: Least Recently Used eviction strategies
- **Custom Policies**: Extensible hook system for any caching policy

## Technical Foundation
- **Language**: Dart/Flutter
- **Primary Dependencies**: 
  - `sembast` (v3.8.5+1) - NoSQL database
  - `sembast_web` (v2.4.2) - Web support
  - `flutter_secure_storage` (v9.2.4) - Secure storage
  - `path_provider` (v2.1.4) - File system paths
- **SDK**: Dart 3.9.2+, Flutter 1.17.0+

## Success Criteria
- ✅ Clean, extensible API for cache operations (put, get, delete, clear, exists)
- ✅ Easy plugin creation through hook system
- ✅ Cross-platform support (mobile, web, desktop)
- ✅ Separate configurable storage for entries and metadata
- ✅ Working template plugins (TTL, LRU)
- ✅ Comprehensive test coverage
- 🔄 Complete documentation (partial)
- ❌ Published package (not yet)
