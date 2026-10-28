/// Models for the user Demo Contest enrollment / activity APIs
/// (`enroll-preview`, `steps`, `terms`, `trading-history`, `rule-violations`).

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

int _toInt(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

bool _toBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

/// `POST demo-contest/{id}/enroll-preview` → `data`.
class DemoContestEnrollPreview {
  final double enrollmentFee;
  final double walletBalance;
  final double walletAfter;
  final bool canEnroll;
  final bool tasksRequired;
  final bool termsRequired;
  final int currentParticipations;
  final int maxParticipations;

  const DemoContestEnrollPreview({
    required this.enrollmentFee,
    required this.walletBalance,
    required this.walletAfter,
    required this.canEnroll,
    required this.tasksRequired,
    required this.termsRequired,
    required this.currentParticipations,
    required this.maxParticipations,
  });

  factory DemoContestEnrollPreview.fromJson(Map<String, dynamic> json) {
    return DemoContestEnrollPreview(
      enrollmentFee: _toDouble(json['enrollment_fee']),
      walletBalance: _toDouble(json['wallet_balance']),
      walletAfter: _toDouble(json['wallet_after']),
      canEnroll: _toBool(json['can_enroll']),
      tasksRequired: _toBool(json['tasks_required']),
      termsRequired: _toBool(json['terms_required']),
      currentParticipations: _toInt(json['current_participations']),
      maxParticipations: _toInt(json['max_participations']),
    );
  }
}

/// One enrollment task from `GET demo-contest/{id}/steps`.
class DemoContestStep {
  final String id;
  final String title;
  final String description;
  final String url;
  final bool isCompleted;

  const DemoContestStep({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.isCompleted,
  });

  DemoContestStep copyWith({bool? isCompleted}) => DemoContestStep(
        id: id,
        title: title,
        description: description,
        url: url,
        isCompleted: isCompleted ?? this.isCompleted,
      );

  factory DemoContestStep.fromJson(Map<String, dynamic> json) {
    return DemoContestStep(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? json['name'] ?? json['step_title'] ?? '')
          .toString(),
      description: (json['description'] ?? '').toString(),
      url: (json['url'] ?? json['link'] ?? json['action_url'] ?? '').toString(),
      isCompleted: _toBool(json['is_completed'] ?? json['completed']),
    );
  }
}

/// `GET demo-contest/{id}/terms`.
class DemoContestTerms {
  final bool enabled;
  final String content;
  const DemoContestTerms({required this.enabled, required this.content});
}

/// One row of `GET demo-contest/{id}/trading-history` → `data[]`.
class DemoContestTrade {
  final String id;
  final String symbol;
  final String type;
  final double lots;
  final String openPrice;
  final String closePrice;
  final String openTime;
  final String closeTime;
  final double profit;
  final String status;

  const DemoContestTrade({
    required this.id,
    required this.symbol,
    required this.type,
    required this.lots,
    required this.openPrice,
    required this.closePrice,
    required this.openTime,
    required this.closeTime,
    required this.profit,
    required this.status,
  });

  bool get isOpen => closeTime.isEmpty;

  factory DemoContestTrade.fromJson(Map<String, dynamic> json) {
    return DemoContestTrade(
      id: json['id']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      lots: _toDouble(json['lots']),
      openPrice: json['open_price']?.toString() ?? '',
      closePrice: json['close_price']?.toString() ?? '',
      openTime: json['open_time']?.toString() ?? '',
      closeTime: json['close_time']?.toString() ?? '',
      profit: _toDouble(json['profit']),
      status: json['status']?.toString() ?? '',
    );
  }
}

/// A trade that broke one or more contest rules.
class DemoContestViolationTrade {
  final String tradeId;
  final String symbol;
  final String openTime;
  final double profit;
  final List<String> messages;

  const DemoContestViolationTrade({
    required this.tradeId,
    required this.symbol,
    required this.openTime,
    required this.profit,
    required this.messages,
  });

  factory DemoContestViolationTrade.fromJson(Map<String, dynamic> json) {
    final rules = json['violations'] is List ? json['violations'] as List : [];
    return DemoContestViolationTrade(
      tradeId: json['trade_id']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      openTime: json['open_time']?.toString() ?? '',
      profit: _toDouble(json['profit']),
      messages: rules
          .whereType<Map>()
          .map((r) => r['message']?.toString() ?? '')
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList(),
    );
  }
}

/// `GET demo-contest/{id}/rule-violations` → `data`.
class DemoContestRuleViolations {
  final int totalTrades;
  final int violationCount;
  final int compliantTrades;
  final double complianceRate;
  final List<DemoContestViolationTrade> violations;

  const DemoContestRuleViolations({
    required this.totalTrades,
    required this.violationCount,
    required this.compliantTrades,
    required this.complianceRate,
    required this.violations,
  });

  factory DemoContestRuleViolations.fromJson(Map<String, dynamic> json) {
    final list = json['violations'] is List ? json['violations'] as List : [];
    return DemoContestRuleViolations(
      totalTrades: _toInt(json['total_trades']),
      violationCount: _toInt(json['violation_count']),
      compliantTrades: _toInt(json['compliant_trades']),
      complianceRate: _toDouble(json['compliance_rate']),
      violations: list
          .whereType<Map>()
          .map((e) =>
              DemoContestViolationTrade.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
