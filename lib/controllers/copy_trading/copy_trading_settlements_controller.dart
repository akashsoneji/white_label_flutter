import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:get/get.dart';

/// One commission payout credited to the Master's wallet.
class MasterSettlementItem {
  final int id;
  final num amount;
  final String description;
  final String sourceRef;
  final String creditedAt;
  final String creditedAtDate;

  const MasterSettlementItem({
    required this.id,
    required this.amount,
    required this.description,
    required this.sourceRef,
    required this.creditedAt,
    required this.creditedAtDate,
  });

  factory MasterSettlementItem.fromJson(Map<String, dynamic> json) {
    return MasterSettlementItem(
      id: int.tryParse('${json['id']}') ?? 0,
      amount: num.tryParse('${json['amount']}') ?? 0,
      description: (json['description'] ?? '').toString(),
      sourceRef: (json['source_ref'] ?? '').toString(),
      creditedAt: (json['credited_at'] ?? '').toString(),
      creditedAtDate: (json['credited_at_date'] ?? '').toString(),
    );
  }
}

class CopyTradingSettlementsController extends GetxController {
  static const int perPage = 20;

  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<MasterSettlementItem> settlements = <MasterSettlementItem>[].obs;
  final Rx<num> totalCredited = Rx<num>(0);
  final RxInt entryCount = 0.obs;
  final RxInt currentPage = 1.obs;
  final RxInt lastPage = 1.obs;

  bool get hasMore => currentPage.value < lastPage.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final body = await _fetchPage(1);
      if (body == null) return;
      settlements.assignAll(_parseRows(body));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore.value || isLoading.value) return;
    isLoadingMore.value = true;
    try {
      final body = await _fetchPage(currentPage.value + 1);
      if (body != null) settlements.addAll(_parseRows(body));
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Fetches one page and updates pagination + summary. Returns null (and
  /// sets [errorMessage] on the first page) when the call fails.
  Future<Map?> _fetchPage(int page) async {
    try {
      final res = await ApiService.get(
        endpoint: ApiConstants.copyTradingMasterSettlements,
        queryParameters: {
          'page': '$page',
          'per_page': '$perPage',
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final body = res.data?['data'];
      if (!res.success || body is! Map) {
        if (page == 1) {
          settlements.clear();
          errorMessage.value = res.message ??
              TranslationUtils.tr('copy_trading_invalid_response_format');
        }
        return null;
      }

      final pagination = body['pagination'];
      if (pagination is Map) {
        currentPage.value = int.tryParse('${pagination['current_page']}') ?? page;
        lastPage.value = int.tryParse('${pagination['last_page']}') ?? page;
      }
      final summary = body['summary'];
      if (summary is Map) {
        totalCredited.value = num.tryParse('${summary['total_credited']}') ?? 0;
        entryCount.value = int.tryParse('${summary['entry_count']}') ?? 0;
      }
      return body;
    } catch (e) {
      if (page == 1) {
        settlements.clear();
        errorMessage.value =
            '${TranslationUtils.tr('copy_trading_load_error')}: $e';
      }
      return null;
    }
  }

  List<MasterSettlementItem> _parseRows(Map body) {
    final rows = body['data'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((e) => MasterSettlementItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
