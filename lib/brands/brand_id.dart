/// Brand identifiers are string-based so new brands can be added via JSON
/// without needing code changes.
class BrandId {
  final String value;

  const BrandId._(this.value);

  static const BrandId tenax = BrandId._('tenax');

  static BrandId fromString(String raw) {
    final normalized = raw.trim().toLowerCase();
    return BrandId._(normalized.isEmpty ? BrandId.tenax.value : normalized);
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BrandId && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

