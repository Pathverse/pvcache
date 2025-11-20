class ImmutablePVSeqConfig {
  final List<String> get;
  final List<String> put;
  final List<String> delete;
  final List<String> iterateKey;
  final List<String> iterateValue;
  final List<String> iterateEntry;
  final List<String> clear;

  const ImmutablePVSeqConfig({
    required this.get,
    required this.put,
    required this.delete,
    required this.iterateKey,
    required this.iterateValue,
    required this.iterateEntry,
    required this.clear,
  });
}

class PVSeqConfig {
  final List<String> get = [];
  final List<String> put = [];
  final List<String> delete = [];
  final List<String> iterateKey = [];
  final List<String> iterateValue = [];
  final List<String> iterateEntry = [];
  final List<String> clear = [];

  ImmutablePVSeqConfig toImmutable() {
    return ImmutablePVSeqConfig(
      get: List.unmodifiable(get),
      put: List.unmodifiable(put),
      delete: List.unmodifiable(delete),
      iterateKey: List.unmodifiable(iterateKey),
      iterateValue: List.unmodifiable(iterateValue),
      iterateEntry: List.unmodifiable(iterateEntry),
      clear: List.unmodifiable(clear),
    );
  }
}
