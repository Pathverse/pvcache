/// Cache operation types.
///
/// Used by hooks to filter which operations they respond to.
enum ActionType {
  /// Store or update a key-value pair
  put,

  /// Remove a key-value pair
  delete,

  /// Retrieve a value by key
  get,

  /// Remove all entries
  clear,

  /// Check if key exists
  exists,

  /// Iterate over entries (not fully implemented)
  iter,
}

/// Operation lifecycle stages where hooks execute.
///
/// Flow: preProcess → metaRead → metaUpdatePriorEntry → storageRead/storageUpdate → metaUpdatePostEntry → postProcess
enum EventFlow {
  /// First stage - before storage operations.
  preProcess,

  /// Metadata loaded, then hooks run.
  metaRead,

  /// Before entry storage operation.
  metaUpdatePriorEntry,

  /// Entry read from storage (GET/EXISTS).
  storageRead,

  /// Entry written/deleted (PUT/DELETE).
  storageUpdate,

  /// Metadata written after entry operation.
  metaUpdatePostEntry,

  /// Final stage - after all operations.
  postProcess,
}

/// Storage backend types.
enum StorageType {
  /// In-memory (session-only, fast).
  inMemory,

  /// Persistent file-based storage.
  stdSembast,

  /// Encrypted platform keychain/keystore.
  secureStorage,
}

/// Return types for [BreakHook] to control early exit.
enum BreakReturnType {
  /// Return null
  none,

  /// Return initial value
  initial,

  /// Return current resolved value
  resolved,
}
