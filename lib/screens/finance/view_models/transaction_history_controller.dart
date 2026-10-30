import 'dart:convert';
import 'dart:developer' as dev;
import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// Transaction Model
class Transaction {
  String? message;
  bool? success;
  List<Data>? data;
  Pagination? pagination;

  Transaction({this.message, this.success, this.data, this.pagination});

  /// Admin toggle "Show the Proof column in client Transaction History";
  /// top-level `show_proof_column` on the list response, OFF by default.
  bool showProofColumn = false;

  Transaction.fromJson(Map<String, dynamic> json) {
    showProofColumn = json['show_proof_column'] == true;
    message = json['message'];
    success = json['success'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(new Data.fromJson(v));
      });
    }
    pagination =
        json['pagination'] != null
            ? new Pagination.fromJson(json['pagination'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['message'] = this.message;
    data['success'] = this.success;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (this.pagination != null) {
      data['pagination'] = this.pagination!.toJson();
    }
    return data;
  }
}

class Data {
  String? id;
  int? userId;
  String? mt5AccountId;
  String? referenceNumber;
  String? amount;
  String? currencyAccount;
  String? transactionId;
  String? status;
  String? paymentMethod;
  String? proof;
  String? proofUrl;
  String? paymentDetails;
  String? createdAt;
  String? transactionType;
  String? type;
  String? accountType;
  String? accountLabel;
  String? fromAccount;
  String? toAccount;
  String? walletId;
  String? rejectReason;
  String? commentForClient;

  Data({
    this.id,
    this.userId,
    this.mt5AccountId,
    this.referenceNumber,
    this.amount,
    this.currencyAccount,
    this.transactionId,
    this.status,
    this.paymentMethod,
    this.proof,
    this.proofUrl,
    this.paymentDetails,
    this.createdAt,
    this.transactionType,
    this.type,
    this.accountType,
    this.accountLabel,
    this.fromAccount,
    this.toAccount,
    this.walletId,
    this.rejectReason,
    this.commentForClient,
  });

  bool get isInternalTransfer =>
      (transactionType ?? '').toLowerCase().contains('transfer');

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    userId =
        json['user_id'] is int
            ? json['user_id']
            : int.tryParse(json['user_id']?.toString() ?? '');
    mt5AccountId = json['mt5_account_id']?.toString();
    referenceNumber = json['reference_number']?.toString();
    currencyAccount = json['currency_account']?.toString();
    amount = _normalizeAmount(json['amount']?.toString(), currencyAccount);
    transactionId = json['transaction_id']?.toString();
    status = json['status']?.toString();
    paymentMethod = json['paymentMethod']?.toString();
    proof = json['proof']?.toString();
    proofUrl = json['proof_url']?.toString();
    paymentDetails = json['payment_details']?.toString();
    createdAt = json['created_at_iso']?.toString() ?? json['created_at']?.toString();
    transactionType = json['transaction_type']?.toString();
    type = json['type']?.toString();
    accountType = json['account_type']?.toString();
    accountLabel = json['account_label']?.toString();
    fromAccount = json['from_account']?.toString();
    toAccount = json['to_account']?.toString();
    walletId = json['wallet_id']?.toString();
    rejectReason = json['reject_reason']?.toString();
    commentForClient = json['comment_for_client']?.toString();
  }

  // USC (US Cent) accounts report `amount` in cents (as a display string like
  // "$10,000.00"). Divide by 100 so the UI shows the real USD value.
  static String? _normalizeAmount(String? raw, String? currencyAccount) {
    if (raw == null || raw.isEmpty) return raw;
    if (currencyAccount?.toUpperCase() != 'USC') return raw;
    final match = RegExp(r'-?[\d,]*\.?\d+').firstMatch(raw);
    if (match == null) return raw;
    final numeric = double.tryParse(match.group(0)!.replaceAll(',', ''));
    if (numeric == null) return raw;
    final converted = numeric / 100;
    final whole = converted.truncate();
    final formattedWhole = whole
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final formatted = '$formattedWhole.${(converted - whole).abs().toStringAsFixed(2).substring(2)}';
    return raw.replaceRange(match.start, match.end, formatted);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['user_id'] = this.userId;
    data['mt5_account_id'] = this.mt5AccountId;
    data['reference_number'] = this.referenceNumber;
    data['amount'] = this.amount;
    data['currency_account'] = this.currencyAccount;
    data['transaction_id'] = this.transactionId;
    data['status'] = this.status;
    data['paymentMethod'] = this.paymentMethod;
    data['proof'] = this.proof;
    data['proof_url'] = this.proofUrl;
    data['payment_details'] = this.paymentDetails;
    data['created_at'] = this.createdAt;
    data['transaction_type'] = this.transactionType;
    data['type'] = this.type;
    return data;
  }
}

class Pagination {
  int? currentPage;
  int? lastPage;
  int? perPage;
  int? total;
  String? nextPageUrl;
  String? prevPageUrl;

  Pagination({
    this.currentPage,
    this.lastPage,
    this.perPage,
    this.total,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  Pagination.fromJson(Map<String, dynamic> json) {
    currentPage = json['current_page'];
    lastPage = json['last_page'];
    perPage = json['per_page'];
    total = json['total'];
    nextPageUrl = json['next_page_url'];
    prevPageUrl = json['prev_page_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['current_page'] = this.currentPage;
    data['last_page'] = this.lastPage;
    data['per_page'] = this.perPage;
    data['total'] = this.total;
    data['next_page_url'] = this.nextPageUrl;
    data['prev_page_url'] = this.prevPageUrl;
    return data;
  }
}

class TransactionHistoryController extends GetxController {
  final FinanceRepository _repo = Get.find<FinanceRepository>();
  // Observable states
  final _isLoading = false.obs;
  final _errorMessage = ''.obs;
  final _successMessage = ''.obs;

  // Getters
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;
  String get successMessage => _successMessage.value;

  // Transactions list
  var accounts = <MT5Account>[].obs;
  // Filters
  final selectedAccount = Rxn<String>();
  final selectedDate = Rxn<DateTime>();
  final selectedTransactionType = Rxn<String>();
  final selectedTransactionIndex = (-1).obs;

  // For pagination
  var currentPage = 1;
  var lastPage = 1;

  // Transactions list from /api/user/transactions
  var userTransactions = <Data>[].obs;

  final showProofColumn = false.obs;

  bool get isLoadingMore => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    print('🔵 TransactionHistoryController.onInit() called');
    // fetchTransactionHistory(); // call API on screen load
    // fetchUserTransactions(page: 1);
  }

  /// Fetch transaction history
  Future<void> fetchTransactionHistory() async {
    print(
      '\n⚠️⚠️⚠️ TRANSACTION HISTORY CONTROLLER: fetchTransactionHistory() CALLED ⚠️⚠️⚠️\n',
    );
    try {
      _setLoading(true);
      _clearError();

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.getMt5Accounts(token: token ?? '');

      if (response.success) {
        final data = response.data;
        print(
          '⚠️⚠️⚠️ TRANSACTION HISTORY CONTROLLER - MT5 Accounts Response: $data',
        );

        if (data['status'] == true && data['data'] != null) {
          final accountsData = data['data'] as List;
          print(': Found ${accountsData.length} accounts in response');

          if (accountsData.isNotEmpty) {
            // User has MT5 accounts
            final parsedAccounts =
                accountsData
                    .map((account) => MT5Account.fromJson(account))
                    .toList();
            accounts.assignAll(parsedAccounts);
            print(
              ': Updated mt5Accounts observable with ${accounts.length} accounts',
            );
          } else {
            // User has no MT5 accounts - redirect to account opening
            print('User has no MT5 accounts - redirecting to account opening');
          }
        } else {
          // API returned error or no data
          print('MT5 accounts API error: ${data['message']}');
          // CustomToastService.showError(
          //   message: data['message'] ?? "Something went wrong",
          // );
        }
      } else {
        // API call failed
        print('Failed to fetch MT5 accounts: ${response.message}');
        // CustomToastService.showError(
        //   message: response.message ?? "Something went wrong",
        // );
      }
    } catch (e) {
      // _errorMessage.value = "Error while fetching transactions: $e";
      // CustomToastService.showError(message: _errorMessage.value);
    } finally {
      _setLoading(false);
    }
  }

  /// Apply filters
  void updateAccount(String account) {
    selectedAccount.value = account;
    // you can re-filter transactions here or trigger API again
  }

  Future<void> fetchUserTransactions({int page = 1}) async {
    try {
      _setLoading(true);
      if (page == 1) userTransactions.clear();

      final token = await SecureStorageService.getAuthToken();

      // Log request - Always log with both dev.log and print
      dev.log(
        '═══════════════════════════════════════════════════════════',
        name: 'TRANSACTION_HISTORY',
      );
      dev.log(
        '📤 TRANSACTION HISTORY API REQUEST',
        name: 'TRANSACTION_HISTORY',
      );
      dev.log(
        'Endpoint: ${ApiConstants.getFinanceActivity}',
        name: 'TRANSACTION_HISTORY',
      );
      dev.log('Page: $page', name: 'TRANSACTION_HISTORY');
      dev.log(
        'Token exists: ${token != null && token.isNotEmpty}',
        name: 'TRANSACTION_HISTORY',
      );
      dev.log(
        '═══════════════════════════════════════════════════════════',
        name: 'TRANSACTION_HISTORY',
      );

      print('\n');
      print('═══════════════════════════════════════════════════════════');
      print('📤 TRANSACTION HISTORY API REQUEST');
      print('═══════════════════════════════════════════════════════════');
      print('🔗 Endpoint: ${ApiConstants.getFinanceActivity}');
      print('📄 Page: $page');
      print('🔑 Token exists: ${token != null && token.isNotEmpty}');
      print('═══════════════════════════════════════════════════════════');

      final response = await _repo.getTransactions(
        token: token ?? '',
        page: page,
      );

      // Log full response - Always log with both dev.log and print
      dev.log(
        '═══════════════════════════════════════════════════════════',
        name: 'TRANSACTION_HISTORY',
      );
      dev.log(
        '📥 TRANSACTION HISTORY API RESPONSE',
        name: 'TRANSACTION_HISTORY',
      );
      dev.log('Success: ${response.success}', name: 'TRANSACTION_HISTORY');
      dev.log('Message: ${response.message}', name: 'TRANSACTION_HISTORY');
      dev.log(
        'Has Data: ${response.data != null}',
        name: 'TRANSACTION_HISTORY',
      );

      print('\n');
      print('═══════════════════════════════════════════════════════════');
      print('📥 TRANSACTION HISTORY API RESPONSE');
      print('═══════════════════════════════════════════════════════════');
      print('✅ Success: ${response.success}');
      print('📝 Message: ${response.message}');
      print('📦 Has Data: ${response.data != null}');
      print('═══════════════════════════════════════════════════════════');

      if (response.data != null) {
        dev.log(
          'Response Data Type: ${response.data.runtimeType}',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log('Response Data:', name: 'TRANSACTION_HISTORY');
        print('\n📊 RESPONSE DATA DETAILS:');
        print('Type: ${response.data.runtimeType}');
        print('═══════════════════════════════════════════════════════════');
        try {
          final formatted = JsonEncoder.withIndent('  ').convert(response.data);
          dev.log(formatted, name: 'TRANSACTION_HISTORY');
          print('Full Response JSON:');
          print(formatted);
        } catch (e) {
          dev.log('Raw Data: ${response.data}', name: 'TRANSACTION_HISTORY');
          dev.log('Format Error: $e', name: 'TRANSACTION_HISTORY');
          print('⚠️ Could not format JSON, showing raw data:');
          print('Raw Data: ${response.data}');
          print('Format Error: $e');
        }
        print('═══════════════════════════════════════════════════════════\n');
      } else {
        dev.log('Response Data: null', name: 'TRANSACTION_HISTORY');
        print('\n⚠️ Response Data: null\n');
      }
      dev.log(
        '═══════════════════════════════════════════════════════════',
        name: 'TRANSACTION_HISTORY',
      );
      print('═══════════════════════════════════════════════════════════');

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Log data structure - Always log with both dev.log and print
        dev.log(
          '═══════════════════════════════════════════════════════════',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log('📊 PARSING TRANSACTION DATA', name: 'TRANSACTION_HISTORY');
        dev.log(
          'Data keys: ${data.keys.toList()}',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log(
          'Has "data" key: ${data.containsKey("data")}',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log(
          'Has "pagination" key: ${data.containsKey("pagination")}',
          name: 'TRANSACTION_HISTORY',
        );

        print('═══════════════════════════════════════════════════════════');
        print('📊 PARSING TRANSACTION DATA');
        print('Data keys: ${data.keys.toList()}');
        print('Has "data" key: ${data.containsKey("data")}');
        print('Has "pagination" key: ${data.containsKey("pagination")}');

        if (data.containsKey('data')) {
          final dataValue = data['data'];
          dev.log(
            'Data value type: ${dataValue.runtimeType}',
            name: 'TRANSACTION_HISTORY',
          );
          print('Data value type: ${dataValue.runtimeType}');
          if (dataValue is List) {
            dev.log(
              'Data is List with ${dataValue.length} items',
              name: 'TRANSACTION_HISTORY',
            );
            print('Data is List with ${dataValue.length} items');
            if (dataValue.isNotEmpty) {
              dev.log(
                'First item: ${dataValue[0]}',
                name: 'TRANSACTION_HISTORY',
              );
              print('First item: ${dataValue[0]}');
            }
          } else if (dataValue is Map) {
            dev.log(
              'Data is Map with keys: ${dataValue.keys.toList()}',
              name: 'TRANSACTION_HISTORY',
            );
            print('Data is Map with keys: ${dataValue.keys.toList()}');
          }
        }
        dev.log(
          '═══════════════════════════════════════════════════════════',
          name: 'TRANSACTION_HISTORY',
        );
        print('═══════════════════════════════════════════════════════════');

        // parse response using Transaction model
        Transaction? transactionResponse;
        try {
          transactionResponse = Transaction.fromJson(data);
          dev.log(
            '✅ Successfully parsed Transaction model',
            name: 'TRANSACTION_HISTORY',
          );
          print('✅ Successfully parsed Transaction model');
        } catch (parseError, stackTrace) {
          dev.log(
            '❌ ERROR PARSING TRANSACTION MODEL',
            name: 'TRANSACTION_HISTORY',
          );
          dev.log('Parse Error: $parseError', name: 'TRANSACTION_HISTORY');
          dev.log('Stack Trace: $stackTrace', name: 'TRANSACTION_HISTORY');
          print('❌ ERROR PARSING TRANSACTION MODEL');
          print('Parse Error: $parseError');
          print('Stack Trace: $stackTrace');
          _errorMessage.value = "Error parsing transaction data: $parseError";
          CustomToastService.showError(message: _errorMessage.value);
          return;
        }

        // update pagination info
        currentPage = transactionResponse.pagination?.currentPage ?? 1;
        lastPage = transactionResponse.pagination?.lastPage ?? 1;
        showProofColumn.value = transactionResponse.showProofColumn;

        dev.log(
          '═══════════════════════════════════════════════════════════',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log('📊 PARSED TRANSACTION DATA', name: 'TRANSACTION_HISTORY');
        dev.log(
          'Transaction Response Success: ${transactionResponse.success}',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log(
          'Transaction Response Message: ${transactionResponse.message}',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log(
          'Transactions Count: ${transactionResponse.data?.length ?? 0}',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log('Pagination:', name: 'TRANSACTION_HISTORY');
        dev.log(
          '  Current Page: ${transactionResponse.pagination?.currentPage ?? 'N/A'}',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log(
          '  Last Page: ${transactionResponse.pagination?.lastPage ?? 'N/A'}',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log(
          '  Per Page: ${transactionResponse.pagination?.perPage ?? 'N/A'}',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log(
          '  Total: ${transactionResponse.pagination?.total ?? 'N/A'}',
          name: 'TRANSACTION_HISTORY',
        );

        print('═══════════════════════════════════════════════════════════');
        print('📊 PARSED TRANSACTION DATA');
        print('Transaction Response Success: ${transactionResponse.success}');
        print('Transaction Response Message: ${transactionResponse.message}');
        print('Transactions Count: ${transactionResponse.data?.length ?? 0}');
        print('Pagination:');
        print(
          '  Current Page: ${transactionResponse.pagination?.currentPage ?? 'N/A'}',
        );
        print(
          '  Last Page: ${transactionResponse.pagination?.lastPage ?? 'N/A'}',
        );
        print(
          '  Per Page: ${transactionResponse.pagination?.perPage ?? 'N/A'}',
        );
        print('  Total: ${transactionResponse.pagination?.total ?? 'N/A'}');

        if (transactionResponse.data != null &&
            transactionResponse.data!.isNotEmpty) {
          dev.log(
            'Transaction Details (first 3):',
            name: 'TRANSACTION_HISTORY',
          );
          print('Transaction Details (first 3):');
          for (int i = 0; i < transactionResponse.data!.length && i < 3; i++) {
            final tx = transactionResponse.data![i];
            dev.log('  Transaction ${i + 1}:', name: 'TRANSACTION_HISTORY');
            dev.log('    ID: ${tx.id}', name: 'TRANSACTION_HISTORY');
            dev.log(
              '    Type: ${tx.transactionType ?? tx.type}',
              name: 'TRANSACTION_HISTORY',
            );
            dev.log('    Amount: ${tx.amount}', name: 'TRANSACTION_HISTORY');
            dev.log('    Status: ${tx.status}', name: 'TRANSACTION_HISTORY');
            dev.log(
              '    Account: ${tx.mt5AccountId}',
              name: 'TRANSACTION_HISTORY',
            );
            dev.log(
              '    Created: ${tx.createdAt}',
              name: 'TRANSACTION_HISTORY',
            );
            dev.log(
              '    Reference: ${tx.referenceNumber}',
              name: 'TRANSACTION_HISTORY',
            );
            print('  Transaction ${i + 1}:');
            print('    ID: ${tx.id}');
            print('    Type: ${tx.transactionType ?? tx.type}');
            print('    Amount: ${tx.amount}');
            print('    Status: ${tx.status}');
            print('    Account: ${tx.mt5AccountId}');
            print('    Created: ${tx.createdAt}');
            print('    Reference: ${tx.referenceNumber}');
          }
        } else {
          dev.log(
            '⚠️ WARNING: transactionResponse.data is null or empty!',
            name: 'TRANSACTION_HISTORY',
          );
          dev.log(
            '  transactionResponse.data == null: ${transactionResponse.data == null}',
            name: 'TRANSACTION_HISTORY',
          );
          print('⚠️ WARNING: transactionResponse.data is null or empty!');
          print(
            '  transactionResponse.data == null: ${transactionResponse.data == null}',
          );
          if (transactionResponse.data != null) {
            dev.log(
              '  transactionResponse.data.length: ${transactionResponse.data!.length}',
              name: 'TRANSACTION_HISTORY',
            );
            print(
              '  transactionResponse.data.length: ${transactionResponse.data!.length}',
            );
          }
        }
        dev.log(
          '═══════════════════════════════════════════════════════════',
          name: 'TRANSACTION_HISTORY',
        );
        print('═══════════════════════════════════════════════════════════');

        // update transactions list
        if (transactionResponse.data != null) {
          final beforeCount = userTransactions.length;
          if (page == 1) {
            userTransactions.assignAll(transactionResponse.data!);
          } else {
            userTransactions.addAll(transactionResponse.data!);
          }
          final afterCount = userTransactions.length;
          dev.log(
            '✅ Updated userTransactions list',
            name: 'TRANSACTION_HISTORY',
          );
          dev.log(
            '  Before: $beforeCount transactions',
            name: 'TRANSACTION_HISTORY',
          );
          dev.log(
            '  After: $afterCount transactions',
            name: 'TRANSACTION_HISTORY',
          );
          dev.log(
            '  Added: ${afterCount - beforeCount} transactions',
            name: 'TRANSACTION_HISTORY',
          );
          print('\n✅ TRANSACTION LIST UPDATED:');
          print('═══════════════════════════════════════════════════════════');
          print('📊 Before: $beforeCount transactions');
          print('📊 After: $afterCount transactions');
          print('📊 Added: ${afterCount - beforeCount} transactions');
          print('📊 Total Transactions in List: ${userTransactions.length}');
          if (transactionResponse.data!.isNotEmpty) {
            print('\n📋 Sample Transaction (First one):');
            final first = transactionResponse.data!.first;
            print('   ID: ${first.id}');
            print('   Type: ${first.transactionType ?? first.type ?? "N/A"}');
            print('   Amount: ${first.amount}');
            print('   Status: ${first.status ?? "N/A"}');
            print('   Account: ${first.mt5AccountId ?? "N/A"}');
            print('   Created: ${first.createdAt ?? "N/A"}');
            print('   Reference: ${first.referenceNumber ?? "N/A"}');
          }
          print(
            '═══════════════════════════════════════════════════════════\n',
          );
        } else {
          dev.log(
            '❌ ERROR: transactionResponse.data is null, cannot update list',
            name: 'TRANSACTION_HISTORY',
          );
          print(
            '❌ ERROR: transactionResponse.data is null, cannot update list',
          );
        }
        // _successMessage.value = transactionResponse.message ?? "Transactions fetched successfully";
      } else {
        dev.log(
          '❌ Transaction History API failed',
          name: 'TRANSACTION_HISTORY',
        );
        dev.log('  Success: ${response.success}', name: 'TRANSACTION_HISTORY');
        dev.log('  Message: ${response.message}', name: 'TRANSACTION_HISTORY');
        dev.log('  Data: ${response.data}', name: 'TRANSACTION_HISTORY');
        print('\n❌ TRANSACTION HISTORY API FAILED');
        print('═══════════════════════════════════════════════════════════');
        print('❌ Success: ${response.success}');
        print('📝 Message: ${response.message}');
        print('📦 Data: ${response.data}');
        print('═══════════════════════════════════════════════════════════\n');
        _errorMessage.value = response.message ??
            TranslationUtils.tr(
              'transaction_history_controller_failed_to_fetch_user_transactions',
            );
        CustomToastService.showError(message: _errorMessage.value);
      }
    } catch (e, t) {
      dev.log(
        '═══════════════════════════════════════════════════════════',
        name: 'TRANSACTION_HISTORY',
      );
      dev.log('❌ TRANSACTION HISTORY API ERROR', name: 'TRANSACTION_HISTORY');
      dev.log('Error: $e', name: 'TRANSACTION_HISTORY');
      dev.log('Stack Trace: $t', name: 'TRANSACTION_HISTORY');
      dev.log(
        '═══════════════════════════════════════════════════════════',
        name: 'TRANSACTION_HISTORY',
      );
      print('\n❌ TRANSACTION HISTORY API ERROR');
      print('═══════════════════════════════════════════════════════════');
      print('💥 Error: $e');
      print('📚 Stack Trace: $t');
      print('═══════════════════════════════════════════════════════════\n');
      _errorMessage.value = "Error while fetching user transactions: $e";
      CustomToastService.showError(message: _errorMessage.value);
    } finally {
      _setLoading(false);
      dev.log(
        '✅ fetchUserTransactions completed. Loading: false',
        name: 'TRANSACTION_HISTORY',
      );
      print('\n✅ TRANSACTION HISTORY API CALL COMPLETED');
      print('📊 Final Transaction Count: ${userTransactions.length}');
      print('🔄 Loading State: false');
      print('═══════════════════════════════════════════════════════════\n');
    }
  }

  Future<void> loadNextPage() async {
    if (currentPage < lastPage && !isLoadingMore) {
      await fetchUserTransactions(page: currentPage + 1);
    }
  }

  /// Lightweight poll helper for the Cregis waiting screens: fetches the first
  /// page of transactions and returns the newest `created_at` (as a UTC
  /// DateTime), without touching [userTransactions] or emitting the verbose
  /// debug logs of [fetchUserTransactions]. Returns null on error / no rows.
  Future<DateTime?> fetchLatestTransactionTime() async {
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.getTransactions(token: token ?? '');
      if (!response.success || response.data == null) return null;

      final parsed = Transaction.fromJson(response.data as Map<String, dynamic>);
      final rows = parsed.data;
      if (rows == null || rows.isEmpty) return null;

      DateTime? newest;
      for (final row in rows) {
        final ts = DateTime.tryParse(row.createdAt ?? '');
        if (ts == null) continue;
        if (newest == null || ts.isAfter(newest)) newest = ts;
      }
      return newest;
    } catch (_) {
      return null;
    }
  }

  /// Cregis poll helper: returns the FIRST row whose `referenceNumber` matches
  /// the Cregis `ref` param. Used by the waiting screens to detect a confirmed
  /// deposit without caring about tap-time / clock skew.
  ///
  /// `statusFilter` (optional) restricts the match to rows whose status is
  /// one of `approved`, `success`, `completed` (case-insensitive) — only
  /// terminal-positive states. Pass `null` to match any status.
  ///
  /// Returns null on error / no match. Logging is intentionally verbose so
  /// the Cregis screen can show a debug badge of the latest API response.
  Future<({Data? row, int totalRows, String rawStatus})>
      fetchLatestTransactionForRef(String ref, {bool statusFilter = true}) async {
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.getTransactions(token: token ?? '');
      if (!response.success || response.data == null) {
        return (row: null, totalRows: 0, rawStatus: 'http_error');
      }

      final parsed =
          Transaction.fromJson(response.data as Map<String, dynamic>);
      final rows = parsed.data ?? <Data>[];

      for (final row in rows) {
        if ((row.referenceNumber ?? '').trim() != ref.trim()) continue;
        if (statusFilter) {
          final s = (row.status ?? '').toLowerCase().trim();
          const allowed = {'approved', 'success', 'completed'};
          if (!allowed.contains(s)) continue;
        }
        return (row: row, totalRows: rows.length, rawStatus: 'match');
      }
      return (row: null, totalRows: rows.length, rawStatus: 'no_match');
    } catch (e) {
      return (row: null, totalRows: 0, rawStatus: 'exception:$e');
    }
  }

  void updateDate(DateTime date) {
    selectedDate.value = date;
  }

  void updateTransactionType(String type) {
    selectedTransactionType.value = type;
  }

  void selectTransaction(int index) {
    selectedTransactionIndex.value = index;
  }

  // Debug method to check current state
  void debugPrintState() {
    dev.log(
      '═══════════════════════════════════════════════════════════',
      name: 'TRANSACTION_HISTORY_DEBUG',
    );
    dev.log(
      '🔍 TRANSACTION HISTORY STATE DEBUG',
      name: 'TRANSACTION_HISTORY_DEBUG',
    );
    dev.log('Is Loading: $isLoading', name: 'TRANSACTION_HISTORY_DEBUG');
    dev.log(
      'User Transactions Count: ${userTransactions.length}',
      name: 'TRANSACTION_HISTORY_DEBUG',
    );
    dev.log('Current Page: $currentPage', name: 'TRANSACTION_HISTORY_DEBUG');
    dev.log('Last Page: $lastPage', name: 'TRANSACTION_HISTORY_DEBUG');
    dev.log('Error Message: $errorMessage', name: 'TRANSACTION_HISTORY_DEBUG');
    dev.log(
      'Success Message: $successMessage',
      name: 'TRANSACTION_HISTORY_DEBUG',
    );
    if (userTransactions.isNotEmpty) {
      dev.log('First Transaction:', name: 'TRANSACTION_HISTORY_DEBUG');
      final first = userTransactions.first;
      dev.log('  ID: ${first.id}', name: 'TRANSACTION_HISTORY_DEBUG');
      dev.log(
        '  Type: ${first.transactionType}',
        name: 'TRANSACTION_HISTORY_DEBUG',
      );
      dev.log('  Amount: ${first.amount}', name: 'TRANSACTION_HISTORY_DEBUG');
      dev.log('  Status: ${first.status}', name: 'TRANSACTION_HISTORY_DEBUG');
    }
    dev.log(
      '═══════════════════════════════════════════════════════════',
      name: 'TRANSACTION_HISTORY_DEBUG',
    );
  }

  void goBack() {
    selectedTransactionIndex.value = -1;
  }

  Future<void> viewReceipt(String id) async {
    if (id.isEmpty) return;

    // We reuse the name 'viewReceipt' as it's called from UI, but it now downloads.
    final url = ApiConstants.baseUrl + ApiConstants.depositProofProxy + id;

    try {
      _setLoading(true);
      CustomToastService.showSuccess(
        message: TranslationUtils.tr(
          'transaction_history_controller_downloading_receipt',
        ),
      );

      final token = await SecureStorageService.getAuthToken();
      final headers = token != null 
          ? <String, String>{'Authorization': 'Bearer $token'} 
          : <String, String>{};
      
      // Log request
      final timestamp = DateTime.now().toIso8601String();
      dev.log('═══════════════════════════════════════════════════════════');
      dev.log('📤 DIRECT HTTP REQUEST [$timestamp]');
      dev.log('═══════════════════════════════════════════════════════════');
      dev.log('Method: GET');
      dev.log('URL: $url');
      dev.log('Headers: $headers');
      dev.log('═══════════════════════════════════════════════════════════');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      // Log response
      final statusEmoji = response.statusCode >= 200 && response.statusCode < 300 
          ? '✅' 
          : response.statusCode >= 400 
              ? '❌' 
              : '⚠️';
      dev.log('═══════════════════════════════════════════════════════════');
      dev.log('$statusEmoji DIRECT HTTP RESPONSE [$timestamp]');
      dev.log('═══════════════════════════════════════════════════════════');
      dev.log('URL: $url');
      dev.log('Status Code: ${response.statusCode}');
      dev.log('Content-Type: ${response.headers['content-type'] ?? 'N/A'}');
      dev.log('Content-Length: ${response.bodyBytes.length} bytes');
      dev.log('═══════════════════════════════════════════════════════════');

      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();

        // Try to infer extension from content-type or default to jpg
        String extension = 'jpg';
        final contentType = response.headers['content-type'];
        if (contentType != null) {
          if (contentType.contains('pdf'))
            extension = 'pdf';
          else if (contentType.contains('png'))
            extension = 'png';
          else if (contentType.contains('jpeg'))
            extension = 'jpg';
        }

        final file = File('${dir.path}/receipt_$id.$extension');
        await file.writeAsBytes(response.bodyBytes);

        CustomToastService.showSuccess(
          message: TranslationUtils.tr(
            'transaction_history_controller_receipt_downloaded_successfully',
          ),
        );

        // Open the file
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          CustomToastService.showError(
            message: "Could not open file: ${result.message}",
          );
        }
      } else if (response.statusCode == 404) {
        CustomToastService.showError(
          message: TranslationUtils.tr(
            'transaction_history_controller_proof_not_available',
          ),
        );
      } else {
        CustomToastService.showError(
          message: "Failed to download receipt: ${response.statusCode}",
        );
      }
    } catch (e) {
      CustomToastService.showError(message: "Download error: $e");
      print('Download Error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Helpers
  void _setLoading(bool loading) {
    _isLoading.value = loading;
  }

  void _clearError() {
    _errorMessage.value = '';
  }

  void clearMessages() {
    _errorMessage.value = '';
    _successMessage.value = '';
  }
}
