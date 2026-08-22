class EnrollmentPreviewModel {
  final double enrollmentFee;
  final double walletBalance;
  final double walletAfter;
  final bool canEnroll;
  final bool enrollmentRequired;
  final bool tasksRequired;
  final bool termsRequired;
  final bool multipleAllowed;
  final int currentParticipations;
  final int maxParticipations;

  EnrollmentPreviewModel({
    required this.enrollmentFee,
    required this.walletBalance,
    required this.walletAfter,
    required this.canEnroll,
    required this.enrollmentRequired,
    required this.tasksRequired,
    required this.termsRequired,
    required this.multipleAllowed,
    required this.currentParticipations,
    required this.maxParticipations,
  });

  factory EnrollmentPreviewModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentPreviewModel(
      enrollmentFee: (json['enrollment_fee'] as num?)?.toDouble() ?? 0.0,
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      walletAfter: (json['wallet_after'] as num?)?.toDouble() ?? 0.0,
      canEnroll: json['can_enroll'] == true,
      enrollmentRequired: json['enrollment_required'] == true,
      tasksRequired: json['tasks_required'] == true,
      termsRequired: json['terms_required'] == true,
      multipleAllowed: json['multiple_allowed'] == true,
      currentParticipations: (json['current_participations'] as num?)?.toInt() ?? 0,
      maxParticipations: (json['max_participations'] as num?)?.toInt() ?? 1,
    );
  }
}
