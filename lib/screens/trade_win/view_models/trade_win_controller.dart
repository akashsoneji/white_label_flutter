import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/trade_win/trade_win_leaderboard_entry_model.dart';
import 'package:crm_app/models/trade_win/trade_win_past_win_model.dart';
import 'package:crm_app/models/trade_win/trade_win_product_model.dart';
import 'package:crm_app/models/trade_win/trade_win_stats_model.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';

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

  final RxString selectedAvailability = 'all'.obs;
  final RxString selectedAudience = 'client'.obs;
  final RxBool isProductsFiltering = false.obs;
  final RxSet<String> allKnownCategories = <String>{'all'}.obs;

  /// Reward categories returned by the API (slug -> display name).
  /// Drives the filter chips so categories with no product on the current
  /// page (e.g. Electronics, Travel) still appear, matching the web UI.
  final RxList<TradeWinRewardCategory> rewardCategories =
      <TradeWinRewardCategory>[].obs;

  List<String> get categories {
    final list = <String>['all'];
    if (rewardCategories.isNotEmpty) {
      list.addAll(rewardCategories.map((c) => c.slug));
      return list;
    }
    // Fallback: derive from loaded products if the API omitted the list.
    final set = <String>{};
    set.addAll(allKnownCategories.where((c) => c != 'all'));
    for (final p in products) {
      if (p.category.isNotEmpty) set.add(p.category.toLowerCase());
    }
    list.addAll(set);
    return list;
  }

  /// Display label for a category slug, preferring the API-provided name.
  String categoryDisplayName(String slug) {
    for (final c in rewardCategories) {
      if (c.slug.toLowerCase() == slug.toLowerCase()) return c.name;
    }
    return slug;
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
    fetchProducts(audience: 'client');
    fetchPastWins(reset: true);
  }

  Future<void> fetchProducts({
    bool showLoader = true,
    bool loadMore = false,
    String? category,
    String? audience,
    String? availability,
  }) async {
    if (category != null) selectedCategory.value = category.toLowerCase();
    if (availability != null) {
      selectedAvailability.value = availability.toLowerCase();
    }
    if (audience != null) selectedAudience.value = audience.toLowerCase();

    if (loadMore) {
      if (isLoadingMoreProducts.value || !productsHasMore) return;
      isLoadingMoreProducts.value = true;
    } else {
      if (showLoader) isLoading.value = true;
      isProductsFiltering.value = true;
    }

    errorMessage.value = '';

    final page = loadMore ? productsCurrentPage + 1 : 1;

    try {
      final queryParams = <String, dynamic>{
        'page': '$page',
        'category': selectedCategory.value,
        'audience': selectedAudience.value,
        'availability': selectedAvailability.value,
        '_t': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      final response = await ApiService.get(
        endpoint: ApiConstants.tradeWinProducts,
        queryParameters: queryParams,
      );

      if (!response.success || response.data == null) {
        errorMessage.value =
            response.message ?? TranslationUtils.tr('tw_load_products_failed');
        return;
      }

      final root = _asMap(response.data);
      if (root == null) {
        errorMessage.value = TranslationUtils.tr('tw_invalid_response');
        return;
      }

      moduleEnabled.value = root['module_enabled'] != false;

      final data = _asMap(root['data']) ?? root;
      final parsed = _parseProductsPage(data['products']);

      productsCurrentPage = parsed.currentPage;
      productsLastPage = parsed.lastPage;

      for (final p in parsed.items) {
        if (p.category.isNotEmpty) {
          allKnownCategories.add(p.category.toLowerCase());
        }
      }

      if (loadMore) {
        products.addAll(parsed.items);
      } else {
        products.assignAll(parsed.items);
      }

      final statsRaw = data['stats'];
      if (statsRaw is Map) {
        stats.value = TradeWinStatsModel.fromJson(
          Map<String, dynamic>.from(statsRaw),
        );
      }

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

      final rewardCategoriesRaw = data['reward_categories'];
      if (rewardCategoriesRaw is List) {
        rewardCategories.assignAll(
          rewardCategoriesRaw
              .whereType<Map>()
              .map(
                (e) => TradeWinRewardCategory.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((c) => c.slug.isNotEmpty)
              .toList(),
        );
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      if (showLoader) isLoading.value = false;
      isProductsFiltering.value = false;
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
    final normalized = category.toLowerCase();
    if (selectedCategory.value == normalized && !isProductsFiltering.value) {
      return;
    }
    // Server-side filter: re-fetch page 1 for the selected category so
    // products that aren't on the current page (e.g. Travel) also load.
    fetchProducts(category: normalized, audience: selectedAudience.value);
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

class TradeWinRewardCategory {
  final String slug;
  final String name;

  const TradeWinRewardCategory({required this.slug, required this.name});

  factory TradeWinRewardCategory.fromJson(Map<String, dynamic> json) {
    final slug = (json['slug'] ?? '').toString();
    final name = (json['name'] ?? '').toString();
    return TradeWinRewardCategory(
      slug: slug,
      name: name.isNotEmpty ? name : slug,
    );
  }
}
