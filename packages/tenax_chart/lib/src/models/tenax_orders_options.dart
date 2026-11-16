/// The `orders` block of the chart config (integration.md §5). Null fields
/// are left out so the chart keeps its own default.
class TenaxOrdersOptions {
  const TenaxOrdersOptions({
    this.allowDrag,
    this.allowClose,
    this.contractSize,
    this.tickSize,
    this.stopLevelPoints,
    this.confirmTimeoutMs,
    this.maxVisibleLabels,
    this.colors,
  });

  final bool? allowDrag;
  final bool? allowClose;

  /// Units per lot; only used when the server sends no `profit`.
  final double? contractSize;

  /// Drag snaps to this, so an unplaceable price is never reported.
  final double? tickSize;

  /// Broker's minimum distance from the market, in points.
  final int? stopLevelPoints;
  final int? confirmTimeoutMs;
  final int? maxVisibleLabels;
  final Map<String, String>? colors;

  /// [other]'s non-null values win.
  TenaxOrdersOptions merge(TenaxOrdersOptions? other) {
    if (other == null) return this;
    return TenaxOrdersOptions(
      allowDrag: other.allowDrag ?? allowDrag,
      allowClose: other.allowClose ?? allowClose,
      contractSize: other.contractSize ?? contractSize,
      tickSize: other.tickSize ?? tickSize,
      stopLevelPoints: other.stopLevelPoints ?? stopLevelPoints,
      confirmTimeoutMs: other.confirmTimeoutMs ?? confirmTimeoutMs,
      maxVisibleLabels: other.maxVisibleLabels ?? maxVisibleLabels,
      colors: other.colors ?? colors,
    );
  }

  Map<String, dynamic> toJson() => {
        if (allowDrag != null) 'allowDrag': allowDrag,
        if (allowClose != null) 'allowClose': allowClose,
        if (contractSize != null) 'contractSize': contractSize,
        if (tickSize != null) 'tickSize': tickSize,
        if (stopLevelPoints != null) 'stopLevelPoints': stopLevelPoints,
        if (confirmTimeoutMs != null) 'confirmTimeoutMs': confirmTimeoutMs,
        if (maxVisibleLabels != null) 'maxVisibleLabels': maxVisibleLabels,
        if (colors != null) 'colors': colors,
      };
}
