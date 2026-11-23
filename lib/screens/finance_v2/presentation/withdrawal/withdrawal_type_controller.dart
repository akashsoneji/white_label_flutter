import 'package:get/get.dart';

import 'package:crm_app/screens/finance_v2/data/finance_v2_grouping.dart';
import 'package:crm_app/screens/finance_v2/data/finance_v2_repository.dart';
import 'package:crm_app/screens/finance_v2/data/finance_v2_result.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_v2_failure.dart';
import 'package:crm_app/screens/finance_v2/data/models/payment_type_option.dart';

/// What the withdrawal type screen shows.
enum WithdrawalTypeState {
  loading,
  data,
  empty,
  error,

  /// FINANCE_DISABLED: the server message only, no tiles and no retry.
  disabled,
}

/// Loads GET /withdrawal and the withdrawal payment types and turns them into
/// the type tiles of the first withdrawal screen.
class WithdrawalTypeController extends GetxController {
  final FinanceV2Repository _repository;

  WithdrawalTypeController({FinanceV2Repository? repository})
      : _repository = repository ?? Get.find<FinanceV2Repository>();

  final Rx<WithdrawalTypeState> state = WithdrawalTypeState.loading.obs;
  final RxList<PaymentTypeGroup> groups = <PaymentTypeGroup>[].obs;

  /// Server message of the error or disabled state.
  final RxString message = ''.obs;

  /// True when the list could not load because verification is missing.
  final RxBool needsKyc = false.obs;

  List<PaymentTypeOption> _paymentTypes = const <PaymentTypeOption>[];
  bool _disposed = false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _disposed = true;
    super.onClose();
  }

  Future<void> load() async {
    state.value = WithdrawalTypeState.loading;
    message.value = '';
    needsKyc.value = false;

    final results = await Future.wait(<Future<
        FinanceV2Result<List<PaymentTypeOption>>>>[
      _repository.getWithdrawalRows(),
      _repository.getPaymentTypes(FinanceV2Repository.typeWithdrawal),
    ]);
    if (_disposed) return;

    final rowsResult = results[0];
    final typesResult = results[1];

    final rowsFailure = rowsResult.failureOrNull;
    if (rowsFailure != null) {
      _showFailure(rowsFailure);
      return;
    }
    final typesFailure = typesResult.failureOrNull;
    if (typesFailure?.kind == FinanceV2FailureKind.financeDisabled) {
      _showFailure(typesFailure!);
      return;
    }

    // The payment types only add labels and currencies, so the tiles still
    // show when that call fails.
    _paymentTypes = typesResult.valueOrNull ?? const <PaymentTypeOption>[];
    final grouped = groupWithdrawalRows(
      rowsResult.valueOrNull ?? const <PaymentTypeOption>[],
      _paymentTypes,
    );
    groups.assignAll(grouped);
    state.value = grouped.isEmpty
        ? WithdrawalTypeState.empty
        : WithdrawalTypeState.data;
  }

  /// The payment-types entry of [group], which carries the crypto address
  /// settings when the server sends them there.
  PaymentTypeOption? typeInfoOf(PaymentTypeGroup group) {
    return _paymentTypes.firstWhereOrNull(
      (type) => type.paymentType.trim().toLowerCase() == group.type,
    );
  }

  void _showFailure(FinanceV2Failure failure) {
    groups.clear();
    message.value = failure.message;
    needsKyc.value = failure.kind == FinanceV2FailureKind.kycRequired;
    state.value = failure.kind == FinanceV2FailureKind.financeDisabled
        ? WithdrawalTypeState.disabled
        : WithdrawalTypeState.error;
  }
}
