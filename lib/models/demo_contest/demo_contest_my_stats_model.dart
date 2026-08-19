class DemoContestParticipant {
  final int id;
  final int contestId;
  final int userId;
  final String demoAccountNumber;
  final double startingBalance;
  final double currentEquity;
  final double returnPercent;
  final double profit;
  final double lotsTraded;
  final int openTradesCount;
  final bool isDisqualified;
  final String? disqualificationReason;
  final bool convertedToReal;
  final String? realAccountNumber;
  final double realFtdAmount;
  final int? salesAgentId;
  final String enrollmentDate;
  final String enrollmentStatus;
  final int enrollmentFeePaid;
  final int? walletTransactionId;
  final int? approvedBy;
  final String? approvedAt;
  final String? rejectionReason;
  final bool tasksCompleted;
  final bool termsAccepted;
  final String? termsAcceptedAt;
  final String createdAt;
  final String updatedAt;
  final String? claim;

  const DemoContestParticipant({
    required this.id,
    required this.contestId,
    required this.userId,
    required this.demoAccountNumber,
    required this.startingBalance,
    required this.currentEquity,
    required this.returnPercent,
    required this.profit,
    required this.lotsTraded,
    required this.openTradesCount,
    required this.isDisqualified,
    this.disqualificationReason,
    required this.convertedToReal,
    this.realAccountNumber,
    required this.realFtdAmount,
    this.salesAgentId,
    required this.enrollmentDate,
    required this.enrollmentStatus,
    required this.enrollmentFeePaid,
    this.walletTransactionId,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.tasksCompleted,
    required this.termsAccepted,
    this.termsAcceptedAt,
    required this.createdAt,
    required this.updatedAt,
    this.claim,
  });

  factory DemoContestParticipant.fromJson(Map<String, dynamic> json) {
    return DemoContestParticipant(
      id: json['id'] ?? 0,
      contestId: json['contest_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      demoAccountNumber: json['demo_account_number']?.toString() ?? '-',
      startingBalance: _toDouble(json['starting_balance']),
      currentEquity: _toDouble(json['current_equity']),
      returnPercent: _toDouble(json['return_percent']),
      profit: _toDouble(json['profit']),
      lotsTraded: _toDouble(json['lots_traded']),
      openTradesCount: json['open_trades_count'] ?? 0,
      isDisqualified: json['is_disqualified'] ?? false,
      disqualificationReason: json['disqualification_reason'] as String?,
      convertedToReal: json['converted_to_real'] ?? false,
      realAccountNumber: json['real_account_number'] as String?,
      realFtdAmount: _toDouble(json['real_ftd_amount']),
      salesAgentId: json['sales_agent_id'] as int?,
      enrollmentDate: json['enrollment_date']?.toString() ?? '',
      enrollmentStatus: json['enrollment_status']?.toString() ?? '',
      enrollmentFeePaid: json['enrollment_fee_paid'] ?? 0,
      walletTransactionId: json['wallet_transaction_id'] as int?,
      approvedBy: json['approved_by'] as int?,
      approvedAt: json['approved_at'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      tasksCompleted: json['tasks_completed'] ?? false,
      termsAccepted: json['terms_accepted'] ?? false,
      termsAcceptedAt: json['terms_accepted_at'] as String?,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      claim: json['claim'] as String?,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String get profitDisplay {
    final sign = profit >= 0 ? '+' : '';
    return '$sign\$${profit.toStringAsFixed(2)}';
  }

  String get returnDisplay {
    final sign = returnPercent >= 0 ? '+' : '';
    return '$sign${returnPercent.toStringAsFixed(2)}%';
  }

  bool get isLive => enrollmentStatus.toLowerCase() == 'approved' || enrollmentStatus.toLowerCase() == 'active';
  bool get isPending => enrollmentStatus.toLowerCase() == 'pending';
  bool get isRejected => enrollmentStatus.toLowerCase() == 'rejected';
}

class DemoContestMyStats {
  final bool status;
  final DemoContestParticipant participant;
  final int daysLeft;
  final String rank;

  const DemoContestMyStats({
    required this.status,
    required this.participant,
    required this.daysLeft,
    required this.rank,
  });

  factory DemoContestMyStats.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return DemoContestMyStats(
      status: json['status'] ?? false,
      participant: data != null && data['participant'] != null
          ? DemoContestParticipant.fromJson(data['participant'])
          : DemoContestParticipant(
              id: 0,
              contestId: 0,
              userId: 0,
              demoAccountNumber: '-',
              startingBalance: 0,
              currentEquity: 0,
              returnPercent: 0,
              profit: 0,
              lotsTraded: 0,
              openTradesCount: 0,
              isDisqualified: false,
              convertedToReal: false,
              realFtdAmount: 0,
              enrollmentDate: '',
              enrollmentStatus: '',
              enrollmentFeePaid: 0,
              tasksCompleted: false,
              termsAccepted: false,
              createdAt: '',
              updatedAt: '',
            ),
      daysLeft: data != null ? (data['days_left'] ?? 0) : 0,
      rank: data != null ? (data['rank']?.toString() ?? '-') : '-',
    );
  }
}
