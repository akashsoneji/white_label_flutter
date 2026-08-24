import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class InternalTransferHistoryResponse {
  final List<InternalTransferHistoryItem> items;
  final InternalTransferHistoryPagination pagination;

  const InternalTransferHistoryResponse({
    required this.items,
    required this.pagination,
  });

  factory InternalTransferHistoryResponse.fromJson(Map<String, dynamic> json) {
    final payload = json['data'];
    dynamic rawRows;
    Map<String, dynamic> paginationMap = {};

    if (payload is List) {
      rawRows = payload;
      if (json['pagination'] is Map<String, dynamic>) {
        paginationMap = json['pagination'] as Map<String, dynamic>;
      } else {
        paginationMap = json;
      }
    } else if (payload is Map<String, dynamic>) {
      rawRows = payload['data'] ?? payload['items'] ?? payload['transfers'] ?? payload['rows'];
      if (payload['pagination'] is Map<String, dynamic>) {
        paginationMap = payload['pagination'] as Map<String, dynamic>;
      } else if (json['pagination'] is Map<String, dynamic>) {
        paginationMap = json['pagination'] as Map<String, dynamic>;
      } else {
        paginationMap = payload;
      }
    } else {
      rawRows = json['data'] ?? json['transfers'] ?? json['items'] ?? [];
      if (json['pagination'] is Map<String, dynamic>) {
        paginationMap = json['pagination'] as Map<String, dynamic>;
      } else {
        paginationMap = json;
      }
    }

    return InternalTransferHistoryResponse(
      items:
          rawRows is List
              ? rawRows
                  .whereType<Map<String, dynamic>>()
                  .map(InternalTransferHistoryItem.fromJson)
                  .toList()
              : <InternalTransferHistoryItem>[],
      pagination: InternalTransferHistoryPagination.fromJson(paginationMap),
    );
  }
}

class InternalTransferHistoryItem {
  final int id;
  final TransferAccount? fromAccount;
  final TransferAccount? toAccount;
  final num amount;
  final String formattedAmount;
  final String comment;
  final String status;
  final String reference;
  final String createdAt;
  final String dateOnly;
  final String timeOnly;

  const InternalTransferHistoryItem({
    required this.id,
    required this.fromAccount,
    required this.toAccount,
    required this.amount,
    required this.formattedAmount,
    required this.comment,
    required this.status,
    required this.reference,
    required this.createdAt,
    required this.dateOnly,
    required this.timeOnly,
  });

  factory InternalTransferHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'] ?? json['transfer_amount'] ?? json['requested_amount'] ?? 0;
    final rawFrom = json['from_account'] ?? json['fromAccount'] ?? json['from'] ?? json['source_account'] ?? json['sender_account'];
    final rawTo = json['to_account'] ?? json['toAccount'] ?? json['to'] ?? json['target_account'] ?? json['receiver_account'] ?? json['destination_account'];
    final rawRef = json['reference'] ?? json['reference_id'] ?? json['txn_id'] ?? json['transaction_id'] ?? json['order_id'] ?? json['code'] ?? '';
    final rawDate = json['created_at'] ?? json['date'] ?? json['date_time'] ?? json['created_date'] ?? '';
    final rawComment = json['comment'] ?? json['notes'] ?? json['remark'] ?? json['description'] ?? '';

    return InternalTransferHistoryItem(
      id: _toInt(json['id']),
      fromAccount: TransferAccount.fromDynamic(rawFrom),
      toAccount: TransferAccount.fromDynamic(rawTo),
      amount: _toNum(rawAmount),
      formattedAmount: json['formatted_amount']?.toString() ?? json['amount_formatted']?.toString() ?? '',
      comment: rawComment.toString(),
      status: json['status']?.toString() ?? 'completed',
      reference: rawRef.toString(),
      createdAt: rawDate.toString(),
      dateOnly: json['date_only']?.toString() ?? '',
      timeOnly: json['time_only']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class TransferAccount {
  final String type;
  final String number;
  final String displayName;

  const TransferAccount({
    required this.type,
    required this.number,
    required this.displayName,
  });

  factory TransferAccount.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? json['account_type']?.toString() ?? '';
    final number = json['number']?.toString() ?? json['account_number']?.toString() ?? json['login']?.toString() ?? json['id']?.toString() ?? '';
    String displayName = json['display_name']?.toString() ?? json['name']?.toString() ?? json['title']?.toString() ?? '';

    if (displayName.isEmpty) {
      if (type.isNotEmpty && number.isNotEmpty) {
        displayName = '$type - $number';
      } else if (number.isNotEmpty) {
        displayName = number;
      } else if (type.isNotEmpty) {
        displayName = type;
      }
    }

    return TransferAccount(
      type: type,
      number: number,
      displayName: displayName,
    );
  }

  static TransferAccount? fromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return TransferAccount.fromJson(value);
    }
    if (value is Map) {
      return TransferAccount.fromJson(Map<String, dynamic>.from(value));
    }
    final str = value.toString().trim();
    if (str.isNotEmpty && str != 'null') {
      return TransferAccount(
        type: '',
        number: str,
        displayName: str,
      );
    }
    return null;
  }
}

class InternalTransferHistoryPagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int from;
  final int to;

  const InternalTransferHistoryPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.from,
    required this.to,
  });

  factory InternalTransferHistoryPagination.fromJson(
    Map<String, dynamic> json,
  ) {
    final total = _toInt(json['total']);
    final perPage = _toInt(json['per_page'], fallback: 10);
    final currentPage = _toInt(json['current_page'], fallback: 1);
    final lastPage = _toInt(
      json['last_page'],
      fallback: (total > 0 && perPage > 0) ? (total / perPage).ceil() : 1,
    );
    final from = _toInt(
      json['from'],
      fallback: total > 0 ? ((currentPage - 1) * perPage + 1) : 0,
    );
    final to = _toInt(
      json['to'],
      fallback: total > 0
          ? (currentPage * perPage > total ? total : currentPage * perPage)
          : 0,
    );

    return InternalTransferHistoryPagination(
      currentPage: currentPage < 1 ? 1 : currentPage,
      lastPage: lastPage < 1 ? 1 : lastPage,
      perPage: perPage < 1 ? 10 : perPage,
      total: total,
      from: from,
      to: to,
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class InternalTransferStatusFilter {
  final String label;
  final String value;

  const InternalTransferStatusFilter({
    required this.label,
    required this.value,
  });
}

class InternalTransferHistoryController extends GetxController {
  static const int _perPage = 10;
  static final DateFormat _requestDateFormat = DateFormat('yyyy-MM-dd');

  final items = <InternalTransferHistoryItem>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final errorMessage = ''.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();
  final selectedStatus =
      const InternalTransferStatusFilter(label: 'All Status', value: '').obs;
  
  late final ScrollController scrollController;

  @override
  void onInit() {
    super.onInit();
    scrollController = ScrollController();
    scrollController.addListener(_onScroll);
    fetchHistory();
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      loadNextPage();
    }
  }
  final pagination =
      const InternalTransferHistoryPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: _perPage,
        total: 0,
        from: 0,
        to: 0,
      ).obs;

  final List<InternalTransferStatusFilter> statusFilters = const [
    InternalTransferStatusFilter(label: 'All Status', value: ''),
    InternalTransferStatusFilter(label: 'Approved', value: 'approved'),
    InternalTransferStatusFilter(label: 'Pending', value: 'pending'),
    InternalTransferStatusFilter(label: 'Failed', value: 'failed'),
  ];

  bool get hasNextPage =>
      pagination.value.currentPage < pagination.value.lastPage;

  Future<void> fetchHistory({int page = 1}) async {
    final loadingState = page == 1 ? isLoading : isLoadingMore;
    if (loadingState.value) return;

    loadingState.value = true;
    if (page == 1) {
      errorMessage.value = '';
    }

    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await ApiService.get(
        endpoint: ApiConstants.internalTransferHistory,
        token: token,
        queryParameters: {
          'page': '$page',
          'per_page': '$_perPage',
          'dateFrom':
              fromDate.value == null
                  ? ''
                  : _requestDateFormat.format(fromDate.value!),
          'dateTo':
              toDate.value == null
                  ? ''
                  : _requestDateFormat.format(toDate.value!),
          'status': selectedStatus.value.value,
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (!response.success || response.data is! Map<String, dynamic>) {
        throw Exception(response.message ?? 'Failed to fetch transfer history');
      }

      print('Internal Transfer History Raw Data: ${response.data}');

      final parsed = InternalTransferHistoryResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      print('Internal Transfer History Parsed Items count: ${parsed.items.length}');

      if (page == 1) {
        items.assignAll(parsed.items);
      } else {
        items.addAll(parsed.items);
      }
      pagination.value = parsed.pagination;
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      if (page == 1) {
        items.clear();
      }
      CustomToastService.showError(message: errorMessage.value);
    } finally {
      loadingState.value = false;
    }
  }

  Future<void> refreshHistory() => fetchHistory();

  Future<void> loadNextPage() async {
    if (!hasNextPage || isLoading.value || isLoadingMore.value) return;
    await fetchHistory(page: pagination.value.currentPage + 1);
  }

  Future<void> applyFilters() => fetchHistory();

  Future<void> clearFilters() async {
    fromDate.value = null;
    toDate.value = null;
    selectedStatus.value = statusFilters.first;
    await fetchHistory();
  }

  void setFromDate(DateTime? date) {
    fromDate.value = date;
    if (date != null && toDate.value != null && toDate.value!.isBefore(date)) {
      toDate.value = date;
    }
  }

  void setToDate(DateTime? date) {
    toDate.value = date;
    if (date != null &&
        fromDate.value != null &&
        fromDate.value!.isAfter(date)) {
      fromDate.value = date;
    }
  }

  void setStatus(InternalTransferStatusFilter status) {
    selectedStatus.value = status;
  }
}
