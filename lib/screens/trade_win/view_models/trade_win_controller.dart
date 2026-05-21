import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/trade_win/trade_win_leaderboard_entry_model.dart';
import 'package:crm_app/models/trade_win/trade_win_past_win_model.dart';
import 'package:crm_app/models/trade_win/trade_win_product_model.dart';
import 'package:crm_app/models/trade_win/trade_win_stats_model.dart';
import 'package:crm_app/services/api_service.dart';

class TradeWinController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMoreProducts = false.obs;
  final RxBool moduleEnabled = true.obs;
  final RxString errorMessage = ''.obs;
  final RxString selectedCategory = 'all'.obs;
  final RxInt mainTabIndex = 0.obs;

  final RxList<TradeWinProductModel> products = <TradeWinProductModel>[].obs;
  final Rxn<TradeWinStatsModel> stats = Rxn<TradeWinStatsModel>();
  final RxList<TradeWinPastWinModel> pastWins = <TradeWinPastWinModel>[].obs;
  final RxList<TradeWinLeaderboardEntryModel> leaderboard =
      <TradeWinLeaderboardEntryModel>[].obs;

  int productsCurrentPage = 1;
  int productsLastPage = 1;

  final RxBool isLoadingPastWins = false.obs;
  final RxBool isLoadingMorePastWins = false.obs;
  int pastWinsCurrentPage = 1;
  int pastWinsLastPage = 1;

  List<String> get categories {
    final set = <String>{'all'};
    for (final p in products) {
      if (p.category.isNotEmpty) set.add(p.category.toLowerCase());
    }
    return set.toList();
  }

  List<TradeWinProductModel> get filteredProducts {
    final cat = selectedCategory.value.toLowerCase();
    if (cat == 'all') return products.toList();
    return products.where((p) => p.category.toLowerCase() == cat).toList();
  }

  bool get productsHasMore => productsCurrentPage < productsLastPage;

  bool get pastWinsHasMore => pastWinsCurrentPage < pastWinsLastPage;

  TradeWinProductModel? productById(int id) {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
    fetchPastWins(reset: true);
  }

  Future<void> fetchProducts({
    bool showLoader = true,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      if (isLoadingMoreProducts.value || !productsHasMore) return;
      isLoadingMoreProducts.value = true;
    } else {
      if (showLoader) isLoading.value = true;
    }

    errorMessage.value = '';

    final page = loadMore ? productsCurrentPage + 1 : 1;

    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.tradeWinProducts,
        queryParameters: {
          'page': '$page',
          'category': 'all',
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (!response.success || response.data == null) {
        errorMessage.value = response.message ?? 'Failed to load products';
        return;
      }

      final root = _asMap(response.data);
      if (root == null) {
        errorMessage.value = 'Invalid response';
        return;
      }

      moduleEnabled.value = root['module_enabled'] != false;

      final data = _asMap(root['data']) ?? root;
      final parsed = _parseProductsPage(data['products']);

      productsCurrentPage = parsed.currentPage;
      productsLastPage = parsed.lastPage;

      if (loadMore) {
        products.addAll(parsed.items);
      } else {
        products.assignAll(parsed.items);
      }

      final statsRaw = data['stats'];
      stats.value =
          statsRaw is Map
              ? TradeWinStatsModel.fromJson(Map<String, dynamic>.from(statsRaw))
              : null;

      final leaderboardRaw = data['leaderboard'];
      if (leaderboardRaw is List) {
        leaderboard.assignAll(
          leaderboardRaw
              .whereType<Map>()
              .map(
                (e) => TradeWinLeaderboardEntryModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(),
        );
      } else {
        leaderboard.clear();
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      if (showLoader) isLoading.value = false;
      isLoadingMoreProducts.value = false;
    }
  }

  Future<void> loadMoreProducts() => fetchProducts(showLoader: false, loadMore: true);

  Future<void> fetchPastWins({bool reset = true, bool loadMore = false}) async {
    if (loadMore) {
      if (isLoadingMorePastWins.value || !pastWinsHasMore) return;
      isLoadingMorePastWins.value = true;
    } else if (reset) {
      isLoadingPastWins.value = true;
    }

    final page =
        loadMore ? pastWinsCurrentPage + 1 : (reset ? 1 : pastWinsCurrentPage);

    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.tradeWinPastWins,
        queryParameters: {
          'page': '$page',
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (!response.success || response.data == null) {
        return;
      }

      final root = _asMap(response.data);
      if (root == null) return;

      final pageData = _asMap(root['data']);
      if (pageData == null) return;

      pastWinsCurrentPage = _readInt(pageData['current_page'], fallback: page);
      pastWinsLastPage = _readInt(pageData['last_page'], fallback: 1);

      final listRaw = pageData['data'];
      final items =
          listRaw is List
              ? listRaw
                  .whereType<Map>()
                  .map(
                    (e) => TradeWinPastWinModel.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList()
              : <TradeWinPastWinModel>[];

      if (loadMore) {
        pastWins.addAll(items);
      } else {
        pastWins.assignAll(items);
      }
    } catch (_) {
      // Keep existing list; errors are non-fatal for this tab
    } finally {
      isLoadingPastWins.value = false;
      isLoadingMorePastWins.value = false;
    }
  }

  Future<void> loadMorePastWins() =>
      fetchPastWins(reset: false, loadMore: true);

  void selectCategory(String category) {
    selectedCategory.value = category.toLowerCase();
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  int _readInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  _ProductsPageParse _parseProductsPage(dynamic productsRaw) {
    if (productsRaw is List) {
      final items =
          productsRaw
              .whereType<Map>()
              .map(
                (e) =>
                    TradeWinProductModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
      return _ProductsPageParse(
        items: items,
        currentPage: 1,
        lastPage: 1,
      );
    }

    if (productsRaw is Map) {
      final m = Map<String, dynamic>.from(productsRaw);
      final listRaw = m['data'];
      final items =
          listRaw is List
              ? listRaw
                  .whereType<Map>()
                  .map(
                    (e) => TradeWinProductModel.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList()
              : <TradeWinProductModel>[];

      return _ProductsPageParse(
        items: items,
        currentPage: _readInt(m['current_page'], fallback: 1),
        lastPage: _readInt(m['last_page'], fallback: 1),
      );
    }

    return _ProductsPageParse(items: [], currentPage: 1, lastPage: 1);
  }
}

class _ProductsPageParse {
  final List<TradeWinProductModel> items;
  final int currentPage;
  final int lastPage;

  _ProductsPageParse({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });
}
