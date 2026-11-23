import 'package:get/get.dart';

import '../../data/finance_v2_grouping.dart';
import '../../data/finance_v2_repository.dart';
import '../../data/finance_v2_result.dart';
import '../../data/models/finance_v2_failure.dart';
import '../../data/models/payment_type_option.dart';

/// Loads the deposit type tiles (GET /deposit + GET /finance/payment-types).
class DepositTypeController extends GetxController {
  DepositTypeController({required FinanceV2Repository repository})
      : _repository = repository;

  final FinanceV2Repository _repository;

  final RxBool isLoading = true.obs;
  final RxList<PaymentTypeGroup> groups = <PaymentTypeGroup>[].obs;
  final RxnString errorMessage = RxnString();

  /// FINANCE_DISABLED: show [errorMessage] alone, without Retry.
  final RxBool isFinanceDisabled = false.obs;

  /// KYC_REQUIRED on the list itself: the screen offers verification.
  final RxBool needsKyc = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    isFinanceDisabled.value = false;
    needsKyc.value = false;

    final rowsFuture = _repository.getDepositRows();
    final typesFuture = _repository.getPaymentTypes(
      FinanceV2Repository.typeDeposit,
    );
    final rows = await rowsFuture;
    final types = await typesFuture;
    if (isClosed) return;

    final failure = rows.failureOrNull ?? _blockingFailure(types);
    if (failure != null) {
      groups.clear();
      errorMessage.value = failure.message;
      isFinanceDisabled.value =
          failure.kind == FinanceV2FailureKind.financeDisabled;
      needsKyc.value = failure.kind == FinanceV2FailureKind.kycRequired;
      isLoading.value = false;
      return;
    }

    // Payment types only add labels and currencies: the tiles still work
    // without them, so an ordinary failure of that call is not shown.
    groups.assignAll(
      groupDepositRows(
        rows.valueOrNull ?? const <PaymentTypeOption>[],
        types.valueOrNull ?? const <PaymentTypeOption>[],
      ),
    );
    isLoading.value = false;
  }

  FinanceV2Failure? _blockingFailure(
    FinanceV2Result<List<PaymentTypeOption>> types,
  ) {
    final failure = types.failureOrNull;
    if (failure == null) return null;
    final blocks = failure.kind == FinanceV2FailureKind.financeDisabled ||
        failure.kind == FinanceV2FailureKind.kycRequired;
    return blocks ? failure : null;
  }
}
