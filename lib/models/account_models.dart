class AccountModel {
  final String id;
  final String type; // 'REAL' or 'DEMO'
  final double balance;
  final String currency;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  AccountModel({
    required this.id,
    required this.type,
    required this.balance,
    this.currency = 'USD',
    this.isActive = false,
    required this.createdAt,
    this.metadata,
  });

  AccountModel copyWith({
    String? id,
    String? type,
    double? balance,
    String? currency,
    bool? isActive,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return AccountModel(
      id: id ?? this.id,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'balance': balance,
      'currency': currency,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'],
      type: json['type'],
      balance: json['balance']?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      isActive: json['isActive'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      metadata: json['metadata'],
    );
  }

  @override
  String toString() {
    return 'AccountModel(id: $id, type: $type, balance: $balance, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountModel &&
        other.id == id &&
        other.type == type &&
        other.balance == balance &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        type.hashCode ^
        balance.hashCode ^
        isActive.hashCode;
  }
} 