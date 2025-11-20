# Architecture Documentation

This folder contains detailed architectural documentation for PVCache v2 rewrite.

## Files

### 01-architecture-overview.md
High-level system architecture covering:
- Component diagram and relationships
- Stage vs Action hooks pattern
- Execution flow examples
- Transaction strategy
- Key architectural decisions
- Migration mapping from v1 to v2

### 02-hook-system.md
Deep dive into the hook system:
- Hook hierarchy (PVCBaseHook → PVCStageHook/PVCActionHook)
- Built-in stage hooks (metadata_get, value_put, etc.)
- Action hook examples (TTL, LRU, encryption)
- Produces/consumes dependency system
- Hook registry and validation
- Best practices for hook development

### 03-context-system.md
Context (PVRuntimeCtx) structure and usage:
- Context data maps (runtime, metadata, temp)
- NextStep enum for flow control
- ReturnSpec class for return values
- Data flow examples (GET and PUT operations)
- Reserved key namespaces
- Transaction integration
- Best practices

### 04-compilation-execution.md
Compilation and execution strategy:
- Two-phase approach (compile once, execute many)
- Dependency resolution algorithm (topological sort)
- Execution plan structure
- Skip optimization
- Transaction wrapping
- Performance characteristics
- Error handling

## Reading Order

1. **Start here**: `01-architecture-overview.md` for big picture
2. **Then**: `02-hook-system.md` to understand hooks
3. **Next**: `03-context-system.md` for context details
4. **Finally**: `04-compilation-execution.md` for implementation strategy

## Usage

### For Implementers
Read all documents sequentially. They provide the blueprint for implementation.

### For Hook Developers
Focus on:
- `02-hook-system.md` - How to write hooks
- `03-context-system.md` - How to use context

### For Users
The root memory bank files provide a higher-level view:
- `../productContext.md` - Use cases and benefits
- `../systemPatterns.md` - Architecture summary

## Relationship to Other Docs

```
memory-bank/
├── projectbrief.md       ← Project goals and status
├── activeContext.md      ← Current work and next steps
├── progress.md           ← Implementation checklist
├── systemPatterns.md     ← Architecture summary
├── productContext.md     ← User perspective
├── techContext.md        ← Technical details
│
├── arch/ (THIS FOLDER)   ← Detailed architecture
│   ├── 01-architecture-overview.md
│   ├── 02-hook-system.md
│   ├── 03-context-system.md
│   └── 04-compilation-execution.md
│
└── old/                  ← Archived v1 docs (reference)
```

## Version

These documents describe **PVCache v2** architecture as of November 19, 2025.

The old v1 architecture is documented in `../old/` folder for reference.
