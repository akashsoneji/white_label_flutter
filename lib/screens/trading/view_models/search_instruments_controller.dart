import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/search_instruments_model.dart';
import 'package:crm_app/models/socket_response.dart';

class SearchInstrumentsController extends GetxController {
  final AccountController _accountController = Get.find<AccountController>();

  var isLoading = false.obs;
  var allSymbols = <SearchSymbol>[].obs;
  var filteredSymbols = <SearchSymbol>[].obs;
  var availableCategories = <String>[].obs;
  var searchQuery = ''.obs;
  /// Chips order: All, Currency, Metals, Crypto, Indices, Energy, Commodities.
  /// Default tab is Currency (Forex/Currency API names via aliases).
  var currentCategory = 'Currency'.obs;

  // Preferred display order — API categories that don't appear here are
  // appended alphabetically at the end.
  static const List<String> _preferredOrder = [
    'All',
    'Currency',
    'Forex',
    'Metals',
    'Crypto',
    'Indices',
    'Energy',
    'Commodities',
  ];

  @override
  void onInit() {
    super.onInit();
    availableCategories.assignAll(['All']); // will be expanded after fetch
    fetchInstruments();
  }

  Future<void> fetchInstruments() async {
    final activeAccount = _accountController.activeMT5Account;
    final rawNumber = activeAccount?.metaAccountNumber;
    final tradingAccount =
        (rawNumber != null && rawNumber.trim().isNotEmpty) ? rawNumber : '0';

    try {
      isLoading.value = true;
      final response = await ApiService.get(
        endpoint: ApiConstants.getInstrumentsByAccount(tradingAccount),
      );

      if (response.success && response.data != null) {
        final searchResponse = SearchInstrumentsResponse.fromJson(response.data);
        if (searchResponse.data != null) {
          allSymbols.assignAll(searchResponse.data!.symbols);
          _updateAvailableCategories();

          if (!availableCategories.contains(currentCategory.value)) {
            currentCategory.value = 'Currency';
          }

          _applyFilter();
        }
      }
    } catch (e) {
      print('Error fetching search instruments: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void searchInstruments(String query) {
    searchQuery.value = query;
    _applyFilter();
  }

  void filterByCategory(String category) {
    currentCategory.value = category;
    _applyFilter();
  }

  void _updateAvailableCategories() {
    // Build category list dynamically from API data.
    // Preserve preferred order; append unknown categories alphabetically.
    final fromApi =
        allSymbols.map((s) => s.categoryName.trim()).where((c) => c.isNotEmpty).toSet();

    final ordered = <String>['All'];
    for (final preferred in _preferredOrder) {
      if (preferred == 'All') continue;
      // Match case-insensitively against API values
      String? match;
      for (final c in fromApi) {
        if (c.toLowerCase() == preferred.toLowerCase()) {
          match = c;
          break;
        }
      }
      if (match != null) ordered.add(match);
    }
    // Append any API categories not in the preferred list
    final remaining =
        fromApi.where((c) => !ordered.any((o) => o.toLowerCase() == c.toLowerCase())).toList()
          ..sort();
    ordered.addAll(remaining);

    availableCategories.assignAll(ordered);
  }

  /// Maps a symbol's API [categoryName] to the chip bucket [selectedChip], or false if no match.
  static bool symbolMatchesCategoryChip(String categoryName, String selectedChip) {
    if (selectedChip == 'All') return true;
    final name = categoryName.trim();
    if (name.isEmpty) return false;
    switch (selectedChip) {
      case 'Currency':
        return _equalsAnyInsensitive(name, ['Currency', 'Forex']);
      case 'Metals':
        return _equalsAnyInsensitive(name, ['Metals', 'Metal']);
      case 'Crypto':
        return _equalsAnyInsensitive(name, ['Crypto']);
      case 'Indices':
        return _equalsAnyInsensitive(name, ['Indices']);
      case 'Energy':
        return _equalsAnyInsensitive(name, ['Energy', 'Energies']);
      case 'Commodities':
        return _equalsAnyInsensitive(name, ['Commodities']);
      default:
        return name.toLowerCase() == selectedChip.toLowerCase();
    }
  }

  static bool _equalsAnyInsensitive(String value, List<String> options) {
    final v = value.toLowerCase();
    for (final o in options) {
      if (v == o.toLowerCase()) return true;
    }
    return false;
  }

  void _applyFilter() {
    var results = allSymbols.toList();

    // Apply category filter
    if (currentCategory.value != 'All') {
      results = results
          .where(
            (s) => symbolMatchesCategoryChip(
                  s.categoryName,
                  currentCategory.value,
                ),
          )
          .toList();
    }

    // Apply search query filter
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      results = results.where((symbol) {
        return symbol.displaySymbol.toLowerCase().contains(query) ||
               symbol.categoryName.toLowerCase().contains(query);
      }).toList();
    }

    filteredSymbols.assignAll(results);
  }

  // Convert SearchSymbol to ListElement for UI compatibility if needed
  ListElement mapToListElement(SearchSymbol symbol) {
    return ListElement(
      symbol: symbol.displaySymbol,
      digits: symbol.digits,
      bid: 0.0, // Static data from API doesn't have bid/ask
      ask: 0.0,
      last: 0,
      volume: 0,
      volumeReal: 0,
      logo: '', // Default empty logo
      spreadDiff: symbol.spreadConfig.spreadDiff,
      category: symbol.categoryName,
    );
  }
}
