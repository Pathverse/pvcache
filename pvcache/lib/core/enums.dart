
enum StorageType {
  std,
  separateFilePreferred,
  memory
}

enum ValueType {
  std,
  encrypted
}

enum NextStep {
  f_continue,
  f_break,
  f_panic,
  f_delete,
  f_pop
}

enum Encryption {
  none,
  standard,
  test
}

enum EncryptionFeatures {
  regenKeyOnFailure,
  useGlobalMetaNonce,
  usePerRecordNonce
}