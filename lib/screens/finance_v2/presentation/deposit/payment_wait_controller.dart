import 'dart:async';

import 'package:get/get.dart';

import '../../data/finance_v2_repository.dart';
import '../../data/models/deposit_status.dart';

enum PaymentWaitStatus {
  waiting,
  paid,
  failed,

  /// The wait ran out without a final status. Never shown as a failure.
  processing,
}

/// Polls GET /deposit/by-reference until the deposit is paid or failed, or
/// the wait runs out.
class PaymentWaitController extends GetxController {
  PaymentWaitController({
    required FinanceV2Repository repository,
    required this.reference,
    this.pollInterval = const Duration(seconds: 4),
    this.timeout = const Duration(minutes: 10),
  }) : _repository = repository;

  final FinanceV2Repository _repository;
  final String reference;
  final Duration pollInterval;
  final Duration timeout;

  final status = PaymentWaitStatus.waiting.obs;

  Timer? _timer;
  Duration _waited = Duration.zero;
  bool _isPolling = false;

  /// Set when [pollNow] was asked for while a call was still running.
  bool _isPollQueued = false;

  @override
  void onInit() {
    super.onInit();
    start();
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }

  void start() {
    stop();
    _waited = Duration.zero;
    // Without a reference there is nothing to ask for: the deposit shows up
    // in Transaction History.
    if (reference.isEmpty) {
      status.value = PaymentWaitStatus.processing;
      return;
    }
    status.value = PaymentWaitStatus.waiting;
    _timer = Timer.periodic(pollInterval, (_) {
      _waited += pollInterval;
      if (_waited >= timeout) {
        _finish(PaymentWaitStatus.processing);
        return;
      }
      // A tick that finds a call running is covered by the next tick.
      if (!_isPolling) _poll();
    });
  }

  /// Leaving the screen only stops the polling; the deposit is untouched.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isPollQueued = false;
  }

  /// Asks for the status once, outside the timer (e.g. when the payment page
  /// was closed). When a call is already running, one more is made right
  /// after it: its answer may predate the payment.
  Future<void> pollNow() async {
    if (_isPolling) {
      _isPollQueued = true;
      return;
    }
    await _poll();
  }

  bool get _canPoll =>
      !isClosed &&
      reference.isNotEmpty &&
      status.value == PaymentWaitStatus.waiting;

  /// A failed call is ignored and the polling goes on.
  Future<void> _poll() async {
    if (_isPolling || !_canPoll) return;

    _isPolling = true;
    try {
      final result = await _repository.getDepositByReference(reference);
      if (!_canPoll) return;
      switch (result.valueOrNull?.outcome ?? DepositOutcome.pending) {
        case DepositOutcome.paid:
          _finish(PaymentWaitStatus.paid);
        case DepositOutcome.failed:
          _finish(PaymentWaitStatus.failed);
        case DepositOutcome.pending:
          break;
      }
    } catch (_) {
      // A network error is not a payment result: keep polling.
    } finally {
      _isPolling = false;
    }

    if (!_isPollQueued) return;
    _isPollQueued = false;
    await _poll();
  }

  void _finish(PaymentWaitStatus result) {
    stop();
    status.value = result;
  }
}
