import 'finance_v2_json.dart';

enum DepositOutcome { paid, failed, pending }

/// `data` of GET /deposit/by-reference.
class DepositStatus {
  static const Set<String> _paidStatuses = <String>{
    'approved',
    'success',
    'completed',
  };

  static const Set<String> _failedStatuses = <String>{
    'rejected',
    'failed',
    'cancelled',
    'canceled',
    'declined',
    'expired',
  };

  final String referenceNumber;

  /// Credited amount, as the server sent it.
  final String amount;
  final String status;
  final String mt5AccountId;
  final String gatewayMethodId;
  final DateTime? createdAt;

  const DepositStatus({
    this.referenceNumber = '',
    this.amount = '',
    this.status = '',
    this.mt5AccountId = '',
    this.gatewayMethodId = '',
    this.createdAt,
  });

  /// The deposit is not known to the server yet: keep polling.
  const DepositStatus.pending(String reference)
      : this(referenceNumber: reference);

  factory DepositStatus.fromJson(Map<String, dynamic> json) {
    return DepositStatus(
      referenceNumber: jsonString(json['reference_number']),
      amount: jsonString(json['amount']),
      status: jsonString(json['status']),
      mt5AccountId: jsonString(json['mt5_account_id']),
      gatewayMethodId: jsonString(json['gateway_method_id']),
      createdAt: jsonDateTime(json['created_at']),
    );
  }

  /// Anything that is not a known final status keeps the wait screen polling;
  /// a timeout must never be shown as failed.
  static DepositOutcome outcomeFor(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    if (_paidStatuses.contains(normalized)) return DepositOutcome.paid;
    if (_failedStatuses.contains(normalized)) return DepositOutcome.failed;
    return DepositOutcome.pending;
  }

  DepositOutcome get outcome => outcomeFor(status);
}
