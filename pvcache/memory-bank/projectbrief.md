# PVCache - Project Brief

## Overview
PVCache is a Flutter package that extends Sembast with a powerful hook-based event system. It adds pre/post action hooks, encryption support, and multi-environment management on top of Sembast's reliable storage foundation.

**Core Purpose**: Add advanced capabilities to Sembast through an event-driven architecture, not replace it.

## Core Requirements

### Storage System
- **Multi-backend support**: Sembast (SQLite, Web, Memory)
- **Storage types**: Standard (shared DB), Separate Files (per environment), Memory
- **Platform support**: Flutter (iOS, Android, Web)
- **Database isolation**: Separate databases per environment when requested
- **Global metadata**: Centralized in main database across all environments

### Security
- **Encryption support**: Value and metadata encryption via ValueType enum
- **Secure storage**: Flutter Secure Storage integration for sensitive data
- **Configurable**: Per-environment encryption settings

### Architecture
- **Environment-based**: Multiple isolated cache environments
- **Hook system**: Pre/post action hooks with priority ordering
- **Context pattern**: Runtime context (PVRuntimeCtx) manages execution flow
- **Immutable config**: Thread-safe configuration management

### API Design
- **Simple interface**: PVCache.create(env: 'name')
- **Context-based operations**: All operations use PVCtx context objects
- **Async by default**: Future-based API for all I/O operations
- **Metadata support**: Every cached value has associated metadata

## Current Status
**Phase**: Database layer adaptation complete, implementing cache interface

## Goals
- Maintain backward compatibility with previous pvcache implementation
- Add robust error handling via PVCtrlException
- Support test mode with in-memory databases
- Provide clean separation between storage, business logic, and hooks