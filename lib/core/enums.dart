enum ActionType { put, delete, get, clear, exists, iter }

enum EventFlow {
  preProcess,
  metaRead,
  metaUpdatePriorEntry,
  storageRead,
  storageUpdate,
  metaUpdatePostEntry,
  postProcess,
}

enum StorageType { inMemory, stdSembast, secureStorage }

enum BreakReturnType { none, initial, resolved }
