class RuleViolationModel {
  final String rule;
  final String message;
  final int? tradeId;
  final DateTime? occurredAt;

  RuleViolationModel({
    required this.rule,
    required this.message,
    this.tradeId,
    this.occurredAt,
  });

  factory RuleViolationModel.fromJson(Map<String, dynamic> json) {
    return RuleViolationModel(
      rule: json['rule']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      tradeId: (json['trade_id'] as num?)?.toInt(),
      occurredAt: json['occurred_at'] != null ? DateTime.tryParse(json['occurred_at'].toString()) : null,
    );
  }
}
