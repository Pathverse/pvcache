# Old Memory Bank (v1)

This folder contains the original memory bank files from PVCache v1 (pvcache2), archived on November 19, 2025, before the v2 rewrite.

## Contents

These files document the **old architecture** that is being replaced:
- `activeContext.md` - v1 features and status
- `productContext.md` - v1 use cases
- `progress.md` - v1 development history
- `projectbrief.md` - v1 goals
- `systemPatterns.md` - v1 architecture patterns
- `techContext.md` - v1 technical details

## Status

The v1 implementation in `../../pvcache2/` is:
- ✅ **Fully functional** with 136 passing tests
- ✅ **Feature complete** (TTL, LRU, encryption, macro get)
- ❌ **Has race conditions** in LRU counter
- ❌ **No transaction support**
- ❌ **Haphazard DB access** in hooks

## Why Archived?

v2 rewrite addresses critical issues:
1. Race conditions (LRU concurrent updates)
2. Missing transaction support
3. Manual DB access in hooks
4. Exception-based flow control
5. No dependency management

## Usage

### For Reference
Use these files to understand:
- What worked well in v1
- Design decisions that were successful
- Features that need to be ported to v2

### For Comparison
Compare with current docs to see:
- What changed in v2
- Why changes were made
- Migration path

### For Context
When working on v2, refer to these to:
- Remember v1 behavior
- Ensure feature parity
- Understand user expectations

## New Documentation

See parent folder for current v2 documentation:
- `../projectbrief.md` - Current project status
- `../arch/` - v2 architecture details

## Date Archived

November 19, 2025
