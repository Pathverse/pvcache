class PVCtx {
  final String? key;
  final dynamic value;
  final Map<String, dynamic> metadata;

  PVCtx({this.key, this.value, Map<String, dynamic>? metadata})
    : metadata = Map.unmodifiable(metadata ?? {});

  /// Create a copy of this context with optional field overrides
  PVCtx copyWith({String? key, dynamic value, Map<String, dynamic>? metadata}) {
    return PVCtx(
      key: key ?? this.key,
      value: value ?? this.value,
      metadata: metadata ?? this.metadata,
    );
  }
}
