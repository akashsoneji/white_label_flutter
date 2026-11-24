import 'dart:io';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/secure_storage_service.dart';

import 'finance_v2_result.dart';
import 'models/deposit_method_detail.dart';
import 'models/deposit_status.dart';
import 'models/deposit_submit_result.dart';
import 'models/finance_channel.dart';
import 'models/finance_v2_failure.dart';
import 'models/finance_v2_json.dart';
import 'models/payment_type_option.dart';
import 'models/user_withdrawal_method.dart';

/// Calls of the quote-driven deposit and withdrawal flow (TSK-0119).
///
/// Every method reads the envelope's `status`, never only the HTTP code, and
/// returns a [FinanceV2Result]. The shared [ApiClient] does not expose the
/// HTTP status, so failures are classified from `data.error_code` and the
/// field names (see [FinanceV2Failure.from]).
class FinanceV2Repository {
  static const String typeDeposit = 'deposit';
  static const String typeWithdrawal = 'withdrawal';

  final ApiClient _api;
  final Future<String?> Function() _readToken;
  final String _platform;

  FinanceV2Repository(
    this._api, {
    Future<String?> Function()? tokenProvider,
    String? platform,
  })  : _readToken = tokenProvider ?? SecureStorageService.getAuthToken,
        _platform = platform ?? (Platform.isIOS ? 'ios' : 'android');

  /// Turns a card's deposit_api (`/deposit/cregis`, `/api/user/deposit/...`
  /// or a full URL) into an endpoint relative to the API base.
  static String depositEndpoint(String depositApi) {
    var path = depositApi.trim();
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) path = uri.path;
    path = path.replaceFirst(RegExp(r'^/+'), '');
    for (final prefix in const <String>['api/', ApiConstants.ajax]) {
      if (path.startsWith(prefix)) path = path.substring(prefix.length);
    }
    return '${ApiConstants.ajax}$path';
  }

  /// GET /deposit: the deposit channels the client may use.
  Future<FinanceV2Result<List<PaymentTypeOption>>> getDepositRows() async {
    final response = await _api.get(endpoint: ApiConstants.depositList);
    if (!_isOk(response)) return FinanceV2Err(_failure(response));
    return FinanceV2Ok(_options(_rows(_data(response), _depositRowKeys)));
  }

  /// GET /withdrawal: the payout channels. Rows without method_slug are
  /// dropped.
  Future<FinanceV2Result<List<PaymentTypeOption>>> getWithdrawalRows() async {
    final response = await _api.get(endpoint: ApiConstants.withdrawalRequest);
    if (!_isOk(response)) return FinanceV2Err(_failure(response));
    final rows = _options(_rows(_data(response), _withdrawalRowKeys))
        .where((row) => row.methodSlug.isNotEmpty)
        .toList(growable: false);
    return FinanceV2Ok(rows);
  }

  /// GET /finance/payment-types?type=deposit|withdrawal.
  Future<FinanceV2Result<List<PaymentTypeOption>>> getPaymentTypes(
    String type,
  ) async {
    final response = await _api.get(
      endpoint: ApiConstants.financePaymentTypes,
      queryParameters: <String, dynamic>{'type': type},
    );
    if (!_isOk(response)) return FinanceV2Err(_failure(response));
    return FinanceV2Ok(
      _options(_rows(_data(response), const <String>['payment_types'])),
    );
  }

  /// POST /finance/channels: the priced cards, eligible ones first. Rate
  /// limited on the server: call it debounced, never per key.
  Future<FinanceV2Result<List<FinanceChannel>>> getChannels({
    required String type,
    required String paymentType,
    required String amount,
    required String amountCurrency,
  }) async {
    final response = await _api.post(
      endpoint: ApiConstants.financeChannels,
      data: <String, dynamic>{
        'type': type,
        'payment_type': paymentType,
        'amount': amount,
        'amount_currency': apiAmountCurrency(amountCurrency),
        'platform': _platform,
      },
    );
    if (!_isOk(response)) return FinanceV2Err(_failure(response));

    final channels = _rows(_data(response), const <String>['channels'])
        .map(FinanceChannel.fromJson)
        .where((channel) => channel.slug.isNotEmpty)
        .toList(growable: false);
    return FinanceV2Ok(<FinanceChannel>[
      ...channels.where((channel) => channel.eligible),
      ...channels.where((channel) => !channel.eligible),
    ]);
  }

  /// POST (multipart) to a card's deposit_api. [extraFields] are the details
  /// screen fields (utr_referce, client_note, payer_*); [proof] is sent as
  /// `proof`.
  Future<FinanceV2Result<DepositSubmitResult>> submitDeposit(
    String depositApi, {
    required String gatewayMethodId,
    required String mt5AccountId,
    required String amount,
    required String amountCurrency,
    required String quoteId,
    Map<String, dynamic> extraFields = const <String, dynamic>{},
    File? proof,
  }) async {
    final formData = <String, dynamic>{
      'gateway_method_id': gatewayMethodId,
      'mt5_account_id': mt5AccountId,
      'amount': amount,
      'amount_currency': apiAmountCurrency(amountCurrency),
      'quote_id': quoteId,
      for (final entry in extraFields.entries)
        if (jsonString(entry.value).isNotEmpty) entry.key: entry.value,
    };
    final endpoint = depositEndpoint(depositApi);
    final token = await _readToken();

    final ApiResponse response = proof == null
        ? await _api.postForm(
            endpoint: endpoint,
            formData: formData,
            token: token,
          )
        : await _api.uploadImageDepositRequest(
            endpoint: endpoint,
            file: proof,
            formData: formData,
            token: token,
          );
    if (!_isOk(response)) return FinanceV2Err(_failure(response));
    return FinanceV2Ok(
      DepositSubmitResult.fromJson(jsonMap(_data(response))),
      message: _message(response),
    );
  }

  /// GET /deposit/{slug}: everything for the details screen.
  Future<FinanceV2Result<DepositMethodDetail>> getDepositMethodDetail(
    String slug,
  ) async {
    final response = await _api.get(
      endpoint: '${ApiConstants.depositList}/$slug',
    );
    if (!_isOk(response)) return FinanceV2Err(_failure(response));

    return FinanceV2Ok(DepositMethodDetail.fromJson(jsonMap(_data(response))));
  }

  /// GET /deposit/payer-data: the keys of the payer details the server
  /// already holds for the client (id_type, id_number, id_country). The
  /// values are not returned: the id number is masked and must never be sent
  /// back.
  Future<FinanceV2Result<Set<String>>> getSavedPayerKeys() async {
    final response = await _api.get(
      endpoint: '${ApiConstants.depositList}/payer-data',
    );
    if (!_isOk(response)) return FinanceV2Err(_failure(response));
    return FinanceV2Ok(
      jsonMap(jsonMap(_data(response))['payer_data']).keys.toSet(),
    );
  }

  /// GET /deposit/by-reference?ref=. A deposit the server does not know yet
  /// (404) and any other failed call give a pending status, so the wait
  /// screen keeps polling and never shows "failed" for a call that failed.
  Future<FinanceV2Result<DepositStatus>> getDepositByReference(
    String reference,
  ) async {
    final response = await _api.get(
      endpoint: ApiConstants.depositByReference,
      queryParameters: <String, dynamic>{'ref': reference},
    );
    final data = jsonMap(_data(response));
    if (!_isOk(response) || data.isEmpty) {
      return FinanceV2Ok(DepositStatus.pending(reference));
    }
    return FinanceV2Ok(DepositStatus.fromJson(data));
  }

  /// GET /withdrawal/withdrawal-method/{slug}: the client's approved saved
  /// payout methods.
  Future<FinanceV2Result<List<UserWithdrawalMethod>>> getUserWithdrawalMethods(
    String methodSlug,
  ) async {
    final response = await _api.get(
      endpoint: '${ApiConstants.withdrawalMethods}$methodSlug',
    );
    if (!_isOk(response)) return FinanceV2Err(_failure(response));
    final methods = jsonMapList(
      jsonMap(_data(response))['userWithdrawalMethods'],
    )
        .map(UserWithdrawalMethod.fromJson)
        .where((method) => method.isApproved)
        .toList(growable: false);
    return FinanceV2Ok(methods);
  }

  /// GET /withdrawal/sendOTP. The value is data.channel (mobile | email).
  Future<FinanceV2Result<String>> sendWithdrawalOtp({
    required String mt5AccountId,
    required String amount,
  }) async {
    final response = await _api.get(
      endpoint: ApiConstants.withdrawalSendOTPRequest,
      queryParameters: <String, dynamic>{
        'mt5_account_id': mt5AccountId,
        'amount': amount,
      },
    );
    if (!_isOk(response)) return FinanceV2Err(_failure(response));
    return FinanceV2Ok(
      jsonString(jsonMap(_data(response))['channel']),
      message: _message(response),
    );
  }

  /// POST /withdrawal/withdrawalrequest (JSON). [withdrawalSlug] is the saved
  /// method's withdrawal_slug; leave it null for type local and for a pasted
  /// crypto address (the server expects 0). The value is the answer's message.
  Future<FinanceV2Result<String>> submitWithdrawal({
    required String channelSlug,
    required String paymentType,
    required String mt5AccountId,
    required String amount,
    required String amountCurrency,
    required String quoteId,
    required String otp,
    String? withdrawalSlug,
    String? cryptoAddress,
    String? cryptoNetwork,
  }) async {
    final hasSavedMethod = withdrawalSlug != null && withdrawalSlug.isNotEmpty;
    final Object savedMethod = hasSavedMethod ? withdrawalSlug : 0;
    final address = cryptoAddress?.trim() ?? '';
    final network = cryptoNetwork?.trim() ?? '';

    final response = await _api.post(
      endpoint: ApiConstants.withdrawalSubmitRequest,
      data: <String, dynamic>{
        'withdrawal_method_slug': channelSlug,
        'payment_method': paymentType,
        'withdrawal_method': paymentType,
        'withdrawal_method_id': savedMethod,
        'to_account': savedMethod,
        'mt5_account_id': mt5AccountId,
        'amount': amount,
        'amount_currency': apiAmountCurrency(amountCurrency),
        'quote_id': quoteId,
        'otp': otp,
        if (address.isNotEmpty) 'crypto_address': address,
        if (network.isNotEmpty) 'crypto_network': network,
      },
    );
    if (!_isOk(response)) {
      return FinanceV2Err(_failure(response, isWithdrawalSubmit: true));
    }
    final message = _message(response);
    return FinanceV2Ok(message, message: message);
  }

  static const List<String> _depositRowKeys = <String>[
    'depositMethods',
    'deposit_methods',
    'methods',
    'rows',
    'data',
  ];

  static const List<String> _withdrawalRowKeys = <String>[
    'withdrawalMethods',
    'withdrawal_methods',
    'methods',
    'rows',
    'data',
  ];

  /// The server takes only "usd" or "local" as amount_currency: any other
  /// code shown to the client (INR, KWD ...) is the type's local currency.
  /// "USD", "inr" or "INR" are answered with 422.
  static String apiAmountCurrency(String code) {
    return code.trim().toLowerCase() == 'usd' ? 'usd' : 'local';
  }

  bool _isOk(ApiResponse response) {
    if (!response.success) return false;
    final body = response.data;
    return body is! Map || !body.containsKey('status') || jsonBool(body['status']);
  }

  /// `data` of a successful envelope.
  dynamic _data(ApiResponse response) {
    final body = response.data;
    return body is Map ? body['data'] : null;
  }

  String _message(ApiResponse response) {
    final body = response.data;
    final fromBody = body is Map ? jsonString(body['message']) : '';
    return fromBody.isNotEmpty ? fromBody : jsonString(response.message);
  }

  /// JSON calls hand back the inner `data` of an error, the multipart upload
  /// hands back the whole envelope; both end up as the inner object here.
  FinanceV2Failure _failure(
    ApiResponse response, {
    bool isWithdrawalSubmit = false,
  }) {
    final raw = jsonMap(response.data);
    final isEnvelope = raw.containsKey('status') || raw.containsKey('success');
    final envelopeMessage = isEnvelope ? jsonString(raw['message']) : '';
    return FinanceV2Failure.from(
      message:
          envelopeMessage.isNotEmpty ? envelopeMessage : response.message,
      data: isEnvelope ? raw['data'] : raw,
      isWithdrawalSubmit: isWithdrawalSubmit,
    );
  }

  /// The row list of a list answer, whether `data` is the list itself or an
  /// object holding it under one of [keys].
  List<Map<String, dynamic>> _rows(dynamic data, List<String> keys) {
    if (data is List) return jsonMapList(data);
    final map = jsonMap(data);
    for (final key in keys) {
      if (map[key] is List) return jsonMapList(map[key]);
    }
    for (final value in map.values) {
      if (value is List && value.isNotEmpty && value.first is Map) {
        return jsonMapList(value);
      }
    }
    return const <Map<String, dynamic>>[];
  }

  List<PaymentTypeOption> _options(List<Map<String, dynamic>> rows) {
    return rows.map(PaymentTypeOption.fromJson).toList(growable: false);
  }
}
