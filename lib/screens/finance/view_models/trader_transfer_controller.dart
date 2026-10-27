import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Recipient returned by `POST user/trader-transfer/verify-recipient`.
class TraderTransferRecipient {
  final String token;
  final String name;
  final String email;
  final DateTime expiresAt;

  const TraderTransferRecipient({
    required this.token,
    required this.name,
    required this.email,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory TraderTransferRecipient.fromJson(Map<String, dynamic> json) {
    final expiresIn = int.tryParse('${json['expires_in'] ?? ''}') ?? 600;
    return TraderTransferRecipient(
      token: json['recipient_token']?.toString() ?? '',
      name: json['recipient_name']?.toString() ?? '',
      email: json['recipient_email']?.toString() ?? '',
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }
}

/// One row of `GET user/trader-transfer/history` (also the `submit` response).
class TraderTransferItem {
  final int id;
  final String reference;
  final String direction;
  final num amount;
  final String status;
  final String counterpartyEmail;
  final String counterpartyName;
  final String note;
  final String adminRemarks;
  final String createdAt;

  const TraderTransferItem({
    required this.id,
    required this.reference,
    required this.direction,
    required this.amount,
    required this.status,
    required this.counterpartyEmail,
    required this.counterpartyName,
    required this.note,
    required this.adminRemarks,
    required this.createdAt,
  });

  bool get isSent => direction.toLowerCase() == 'sent';

  factory TraderTransferItem.fromJson(Map<String, dynamic> json) {
    return TraderTransferItem(
      id: int.tryParse('${json['id'] ?? ''}') ?? 0,
      reference: json['reference']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      amount: num.tryParse('${json['amount'] ?? ''}') ?? 0,
      status: json['status']?.toString() ?? '',
      counterpartyEmail: json['counterparty_email']?.toString() ?? '',
      counterpartyName: json['counterparty_name']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      adminRemarks: json['admin_remarks']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class TraderTransferController extends GetxController {
  static const int _otpCooldownSeconds = 60;
  static final DateFormat _requestDateFormat = DateFormat('yyyy-MM-dd');

  final emailController = TextEditingController();
  final amountController = TextEditingController();
  final otpController = TextEditingController();
  final noteController = TextEditingController();
  late final ScrollController historyScrollController;

  // Config
  final isConfigLoading = true.obs;
  final isEnabled = false.obs;
  final configMessage = ''.obs;
  final configError = ''.obs;

  // Send flow
  final recipient = Rxn<TraderTransferRecipient>();
  final isVerifying = false.obs;
  final isSendingOtp = false.obs;
  final isSubmitting = false.obs;
  final otpSent = false.obs;
  final otpChannel = ''.obs;
  final resendSeconds = 0.obs;
  Timer? _resendTimer;
  String _otpAmount = '';

  // History
  final items = <TraderTransferItem>[].obs;
  final isHistoryLoading = false.obs;
  final isLoadingMore = false.obs;
  final historyError = ''.obs;
  final direction = ''.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();
  int _currentPage = 1;
  int _lastPage = 1;

  bool get hasNextPage => _currentPage < _lastPage;

  @override
  void onInit() {
    super.onInit();
    historyScrollController = ScrollController()..addListener(_onHistoryScroll);
    amountController.addListener(_onAmountChanged);
    loadConfig();
  }

  @override
  void onClose() {
    _resendTimer?.cancel();
    historyScrollController
      ..removeListener(_onHistoryScroll)
      ..dispose();
    amountController.removeListener(_onAmountChanged);
    emailController.dispose();
    amountController.dispose();
    otpController.dispose();
    noteController.dispose();
    super.onClose();
  }

  /// Body of a response, or null when the HTTP call or the API itself failed.
  /// Some endpoints answer 200 with `success: false`, so both are checked.
  Map<String, dynamic>? _body(ApiResponse response) {
    if (!response.success || response.data is! Map<String, dynamic>) {
      return null;
    }
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == false || body['status'] == false) return null;
    return body;
  }

  String _errorOf(ApiResponse response) {
    final data = response.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    final message = response.message ?? '';
    return message.isNotEmpty
        ? message
        : TranslationUtils.tr('trader_transfer_something_went_wrong');
  }

  Future<void> loadConfig() async {
    isConfigLoading.value = true;
    configError.value = '';
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await ApiService.get(
        endpoint: ApiConstants.traderTransferConfig,
        token: token,
      );
      final data = response.data;
      if (!response.success || data is! Map<String, dynamic>) {
        configError.value = _errorOf(response);
        return;
      }
      final payload = data['data'];
      isEnabled.value = payload is Map && payload['enabled'] == true;
      configMessage.value = data['message']?.toString() ?? '';
      if (isEnabled.value) {
        unawaited(fetchHistory());
      }
    } catch (error) {
      configError.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isConfigLoading.value = false;
    }
  }

  Future<void> verifyRecipient() async {
    final email = emailController.text.trim();
    if (!GetUtils.isEmail(email)) {
      CustomToastService.showError(
        message: TranslationUtils.tr('trader_transfer_invalid_email'),
      );
      return;
    }
    if (isVerifying.value) return;

    isVerifying.value = true;
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await ApiService.post(
        endpoint: ApiConstants.traderTransferVerifyRecipient,
        token: token,
        data: {'email': email},
      );
      final body = _body(response);
      final payload = body?['data'];
      if (payload is! Map<String, dynamic>) {
        CustomToastService.showError(message: _errorOf(response));
        return;
      }
      final verified = TraderTransferRecipient.fromJson(payload);
      if (verified.token.isEmpty) {
        CustomToastService.showError(message: _errorOf(response));
        return;
      }
      recipient.value = verified;
      _resetOtp();
    } catch (error) {
      CustomToastService.showError(
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      isVerifying.value = false;
    }
  }

  void changeRecipient() {
    recipient.value = null;
    _resetOtp();
  }

  /// Validates the amount and the recipient token; returns the amount or null.
  num? _validatedAmount() {
    final current = recipient.value;
    if (current == null || current.isExpired) {
      recipient.value = null;
      _resetOtp();
      CustomToastService.showError(
        message: TranslationUtils.tr('trader_transfer_verify_expired'),
      );
      return null;
    }
    final amount = num.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      CustomToastService.showError(
        message: TranslationUtils.tr('trader_transfer_invalid_amount'),
      );
      return null;
    }
    return amount;
  }

  Future<void> sendOtp() async {
    if (isSendingOtp.value || resendSeconds.value > 0) return;
    final amount = _validatedAmount();
    if (amount == null) return;

    isSendingOtp.value = true;
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await ApiService.post(
        endpoint: ApiConstants.traderTransferSendOtp,
        token: token,
        data: {'recipient_token': recipient.value!.token, 'amount': amount},
      );
      final body = _body(response);
      if (body == null) {
        CustomToastService.showError(message: _errorOf(response));
        return;
      }
      final payload = body['data'];
      otpChannel.value =
          payload is Map ? payload['channel']?.toString() ?? '' : '';
      otpSent.value = true;
      _otpAmount = amountController.text.trim();
      _startResendCooldown();
      CustomToastService.showSuccess(
        message: body['message']?.toString() ??
            TranslationUtils.tr('trader_transfer_otp_sent'),
      );
    } catch (error) {
      CustomToastService.showError(
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      isSendingOtp.value = false;
    }
  }

  /// Returns true when the transfer was accepted by the server.
  Future<bool> submit() async {
    if (isSubmitting.value) return false;
    final amount = _validatedAmount();
    if (amount == null) return false;
    final otp = otpController.text.trim();
    if (otp.isEmpty) {
      CustomToastService.showError(
        message: TranslationUtils.tr('trader_transfer_enter_otp'),
      );
      return false;
    }

    isSubmitting.value = true;
    try {
      final token = await SecureStorageService.getAuthToken();
      final note = noteController.text.trim();
      final response = await ApiService.post(
        endpoint: ApiConstants.traderTransferSubmit,
        token: token,
        data: {
          'recipient_token': recipient.value!.token,
          'amount': amount,
          'otp': otp,
          if (note.isNotEmpty) 'note': note,
        },
      );
      final body = _body(response);
      if (body == null) {
        CustomToastService.showError(message: _errorOf(response));
        return false;
      }
      CustomToastService.showSuccess(
        message: body['message']?.toString() ??
            TranslationUtils.tr('trader_transfer_submitted'),
      );
      _resetForm();
      unawaited(fetchHistory());
      return true;
    } catch (error) {
      CustomToastService.showError(
        message: error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> fetchHistory({int page = 1}) async {
    final loadingState = page == 1 ? isHistoryLoading : isLoadingMore;
    if (loadingState.value) return;

    loadingState.value = true;
    if (page == 1) historyError.value = '';
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await ApiService.get(
        endpoint: ApiConstants.traderTransferHistory,
        token: token,
        queryParameters: {
          'page': '$page',
          if (direction.value.isNotEmpty) 'direction': direction.value,
          if (fromDate.value != null)
            'date_from': _requestDateFormat.format(fromDate.value!),
          if (toDate.value != null)
            'date_to': _requestDateFormat.format(toDate.value!),
        },
      );
      final body = _body(response);
      final payload = body?['data'];
      if (payload is! Map<String, dynamic>) {
        throw Exception(_errorOf(response));
      }
      final rows = payload['data'];
      final parsed = rows is List
          ? rows
              .whereType<Map<String, dynamic>>()
              .map(TraderTransferItem.fromJson)
              .toList()
          : <TraderTransferItem>[];
      if (page == 1) {
        items.assignAll(parsed);
      } else {
        items.addAll(parsed);
      }
      _currentPage = int.tryParse('${payload['current_page'] ?? ''}') ?? page;
      _lastPage = int.tryParse('${payload['last_page'] ?? ''}') ?? _currentPage;
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (page == 1) {
        historyError.value = message;
      } else {
        CustomToastService.showError(message: message);
      }
    } finally {
      loadingState.value = false;
    }
  }

  Future<void> refreshHistory() => fetchHistory();

  void setDirection(String value) {
    if (direction.value == value) return;
    direction.value = value;
    fetchHistory();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    fromDate.value = from;
    toDate.value = to;
    fetchHistory();
  }

  void _onHistoryScroll() {
    if (!historyScrollController.hasClients) return;
    final position = historyScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200 &&
        hasNextPage &&
        !isLoadingMore.value &&
        !isHistoryLoading.value) {
      fetchHistory(page: _currentPage + 1);
    }
  }

  /// An OTP is issued for one amount; editing the amount needs a new OTP.
  void _onAmountChanged() {
    if (otpSent.value && amountController.text.trim() != _otpAmount) {
      otpSent.value = false;
      otpController.clear();
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    resendSeconds.value = _otpCooldownSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSeconds.value <= 1) {
        resendSeconds.value = 0;
        timer.cancel();
      } else {
        resendSeconds.value--;
      }
    });
  }

  void _resetOtp() {
    otpSent.value = false;
    otpChannel.value = '';
    otpController.clear();
    _otpAmount = '';
  }

  void _resetForm() {
    recipient.value = null;
    _resetOtp();
    emailController.clear();
    amountController.clear();
    noteController.clear();
  }
}
