class ContestParticipantModel {
  final int id;
  final String demoAccountNumber;
  final String startingBalance;
  final String currentEquity;
  final String returnPercent;
  final String profit;
  final String lotsTraded;
  final String enrollmentStatus;
  final bool isDisqualified;
  final dynamic claim;

  ContestParticipantModel({
    required this.id,
    required this.demoAccountNumber,
    required this.startingBalance,
    required this.currentEquity,
    required this.returnPercent,
    required this.profit,
    required this.lotsTraded,
    required this.enrollmentStatus,
    required this.isDisqualified,
    this.claim,
  });

  factory ContestParticipantModel.fromJson(Map<String, dynamic> json) {
    return ContestParticipantModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      demoAccountNumber: json['demo_account_number']?.toString() ?? '',
      startingBalance: json['starting_balance']?.toString() ?? '0.00',
      currentEquity: json['current_equity']?.toString() ?? '0.00',
      returnPercent: json['return_percent']?.toString() ?? '0.00',
      profit: json['profit']?.toString() ?? '0.00',
      lotsTraded: json['lots_traded']?.toString() ?? '0.00',
      enrollmentStatus: json['enrollment_status']?.toString() ?? '',
      isDisqualified: json['is_disqualified'] == true || json['is_disqualified'] == 1 || json['is_disqualified'] == '1',
      claim: json['claim'],
    );
  }
}
