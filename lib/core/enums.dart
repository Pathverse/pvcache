/// Types of cache operations that can be performed.
///
/// Used by hooks to filter which operations they should respond to.
enum ActionType {
  /// Store or update a key-value pair
  put,

  /// Remove a key-value pair
  delete,

  /// Retrieve a value by key
  get,

  /// Remove all entries from the cache
  clear,

  /// Check if a key exists
  exists,

  /// Iterate over cache entries (not yet fully implemented)
  iter,
}

/// Stages in the cache operation lifecycle where hooks can execute.
///
/// Each operation flows through these stages in order:
/// 1. [preProcess] - Initial processing before any operations
/// 2. [metaRead] - Read metadata from storage
/// 3. [metaUpdatePriorEntry] - Update metadata before entry operation
/// 4. [storageRead] - Read entry from storage (GET/EXISTS only)
/// 5. [storageUpdate] - Write/delete entry in storage (PUT/DELETE only)
/// 6. [metaUpdatePostEntry] - Update metadata after entry operation
/// 7. [postProcess] - Final processing after all operations
enum EventFlow {
  /// First stage - runs before any storage operations.
  ///
  /// Use for: Initial validation, preprocessing, early exits.
  preProcess,

  /// Metadata is automatically loaded, then hooks run.
  ///
  /// Use for: TTL checks, access tracking, conditional logic based on metadata.
  metaRead,

  /// Runs before entry storage operation.
  ///
  /// Use for: TTL timestamp setting, LRU eviction, pre-storage modifications.
  metaUpdatePriorEntry,

  /// Entry is automatically read from storage (GET/EXISTS only).
  ///
  /// Use for: Custom storage logic, entry transformation.
  storageRead,

  /// Entry is automatically written/deleted (PUT/DELETE only).
  ///
  /// Use for: Encryption before write, compression, validation.
  storageUpdate,

  /// Metadata is automatically written after entry operation.
  ///
  /// Use for: Post-operation metadata updates, statistics.
  metaUpdatePostEntry,

  /// Final stage - runs after all operations complete.
  ///
  /// Use for: Decryption after read, post-processing, cleanup.
  postProcess,
}

/// Storage backend types supported by PVCache.
enum StorageType {
  /// In-memory storage using sembast memory database.
  ///
  /// Fast but data is lost when app restarts.
  /// Good for: Session cache, temporary data, testing.
  inMemory,

  /// Persistent storage using sembast with file system.
  ///
  /// Data survives app restarts.
  /// Good for: User preferences, offline data, persistent cache.
  stdSembast,

  /// Secure storage using flutter_secure_storage.
  ///
  /// Encrypted platform-specific storage (Keychain/Keystore).
  /// Good for: Tokens, credentials, sensitive keys.
  secureStorage,
}

/// Return types for [BreakHook] exception to control early exit behavior.
enum BreakReturnType {
  /// Return null from the operation
  none,

  /// Return the initial value passed to the operation
  initial,

  /// Return the current resolved value from the context
  resolved,
}
