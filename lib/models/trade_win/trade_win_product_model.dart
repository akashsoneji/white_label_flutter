class TradeWinProductModel {
  final int id;
  final String name;
  final String category;
  final String description;
  final String imagePath;
  final double requiredLots;
  final double requiredPoints;
  final double prizeValue;
  final int stock;
  final String status;
  final int claimsCount;
  final double eligibleLots;
  final double availableLots;
  final double calculatedPoints;
  final String? allowedGroups;
  final String? allowedSymbols;

  const TradeWinProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.imagePath,
    required this.requiredLots,
    required this.requiredPoints,
    required this.prizeValue,
    required this.stock,
    required this.status,
    required this.claimsCount,
    required this.eligibleLots,
    required this.availableLots,
    required this.calculatedPoints,
    this.allowedGroups,
    this.allowedSymbols,
  });

  String get displayAllowedGroups => _nonEmptyOrAll(allowedGroups);

  String get displayAllowedSymbols => _nonEmptyOrAll(allowedSymbols);

  static String _nonEmptyOrAll(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? 'All' : trimmed;
  }

  factory TradeWinProductModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v, [double fallback = 0]) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    return TradeWinProductModel(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imagePath: json['image_path']?.toString() ?? '',
      requiredLots: toDouble(json['required_lots'], 1),
      requiredPoints: toDouble(json['required_points'], 1),
      prizeValue: toDouble(json['prize_value']),
      stock: json['stock'] as int? ?? 0,
      status: json['status']?.toString() ?? 'active',
      claimsCount: json['claims_count'] as int? ?? 0,
      eligibleLots: toDouble(json['eligible_lots']),
      availableLots: toDouble(json['available_lots']),
      calculatedPoints: toDouble(json['calculated_points']),
      allowedGroups: _formatAllowed(json['allowed_groups']),
      allowedSymbols: _formatAllowed(json['allowed_symbols']),
    );
  }

  static String? _formatAllowed(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List) {
      if (value.isEmpty) return null;
      final items =
          value
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
      return items.isEmpty ? null : items.join(', ');
    }
    if (value is Map) {
      if (value.isEmpty) return null;
      final items =
          value.entries
              .map((e) => e.value?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
      return items.isEmpty ? null : items.join(', ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  bool get isActive => status.toLowerCase() == 'active';

  double pointsNeededFor(int quantity) => requiredPoints * quantity;

  double lotsNeededFor(int quantity) => requiredLots * quantity;

  bool canRedeemQuantity(int quantity) {
    if (!isActive || quantity < 1 || stock < quantity) return false;
    return availableLots >= lotsNeededFor(quantity) &&
        calculatedPoints >= pointsNeededFor(quantity);
  }

  bool get canRedeem => canRedeemQuantity(1);

  int pointsShortfallFor(int quantity) {
    final needed = pointsNeededFor(quantity);
    final diff = needed - calculatedPoints;
    if (diff <= 0) return 0;
    return diff.ceil();
  }

  double lotsShortfallFor(int quantity) {
    final needed = lotsNeededFor(quantity);
    final diff = needed - availableLots;
    return diff > 0 ? diff : 0;
  }

  double get progressFraction {
    if (requiredLots <= 0) return 0;
    return (availableLots / requiredLots).clamp(0.0, 1.0);
  }
}
