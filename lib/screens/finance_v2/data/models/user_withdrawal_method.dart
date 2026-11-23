import 'finance_v2_json.dart';

/// A saved payout method from
/// GET /withdrawal/withdrawal-method/{slug} (data.userWithdrawalMethods).
class UserWithdrawalMethod {
  /// Sent as withdrawal_method_id / to_account. The numeric [id] is not.
  final String withdrawalSlug;
  final String id;

  /// bank | upi | crypto | card.
  final String withdrawalMethod;
  final String upiAddress;
  final String bankAccountNo;
  final String bankName;
  final String cryptoAddress;
  final String cardBrand;
  final String cardLast4;
  final String status;

  const UserWithdrawalMethod({
    required this.withdrawalSlug,
    this.id = '',
    this.withdrawalMethod = '',
    this.upiAddress = '',
    this.bankAccountNo = '',
    this.bankName = '',
    this.cryptoAddress = '',
    this.cardBrand = '',
    this.cardLast4 = '',
    this.status = '',
  });

  factory UserWithdrawalMethod.fromJson(Map<String, dynamic> json) {
    return UserWithdrawalMethod(
      withdrawalSlug: jsonString(json['withdrawal_slug']),
      id: jsonString(json['id']),
      withdrawalMethod: jsonString(json['withdrawal_method']),
      upiAddress: jsonString(json['upi_address']),
      bankAccountNo: jsonString(json['bank_account_no']),
      bankName: jsonString(json['bank_name']),
      cryptoAddress: jsonString(json['crypto_address']),
      cardBrand: jsonString(json['card_brand']),
      cardLast4: jsonString(json['card_last4']),
      status: jsonString(json['status']),
    );
  }

  /// The endpoint sends approved methods only, so a row without a status
  /// counts as approved.
  bool get isApproved {
    final normalized = status.toLowerCase();
    return normalized.isEmpty || normalized == 'approved' || normalized == '1';
  }

  /// The line to show under "Pay to".
  String get primaryLabel {
    if (upiAddress.isNotEmpty) return upiAddress;
    if (bankAccountNo.isNotEmpty) return bankAccountNo;
    if (cryptoAddress.isNotEmpty) return cryptoAddress;
    if (cardLast4.isNotEmpty) return '•••• $cardLast4';
    return withdrawalSlug;
  }

  /// Bank name or card brand, when there is one.
  String get secondaryLabel => bankName.isNotEmpty ? bankName : cardBrand;
}
