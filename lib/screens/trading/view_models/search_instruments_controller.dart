import 'dart:convert';
import 'dart:developer' as developer;

import 'package:get/get.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/models/search_instruments_model.dart';
import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/services/symbol_details_cache_service.dart';

class SearchInstrumentsController extends GetxController {
  final AccountController _accountController = Get.find<AccountController>();

  var isLoading = false.obs;
  var allSymbols = <SearchSymbol>[].obs;
  var filteredSymbols = <SearchSymbol>[].obs;
  var availableCategories = <String>[].obs;
  var searchQuery = ''.obs;
  /// Chips order: All, Currency, Metals, Crypto, Indices, Energy, Commodities.
  /// Default tab is Currency (Forex/Currency API names via aliases).
  var currentCategory = 'All'.obs;

  static const List<String> _categoryChipOrder = [
    'All',
    'Currency',
    'Metals',
    'Crypto',
    'Indices',
    'Energy',
    'Commodities',
  ];

  @override
  void onInit() {
    super.onInit();
    // Categories are populated dynamically after API response via _updateAvailableCategories().
    fetchInstruments();
  }

  Future<void> fetchInstruments() async {
    final activeAccount = _accountController.activeMT5Account;
    final rawNumber = activeAccount?.metaAccountNumber;
    final tradingAccount =
        (rawNumber != null && rawNumber.trim().isNotEmpty) ? rawNumber : '0';

    final endpoint = ApiConstants.getInstrumentsByAccount(tradingAccount);

    // ---- DEBUG: REQUEST ----
    developer.log(
      '🔎 [SearchInstruments] REQUEST → endpoint: $endpoint | '
      'baseUrl: ${ApiConstants.baseUrl} | '
      'tradingAccount: $tradingAccount | '
      'activeMT5: ${activeAccount?.metaAccountNumber}',
      name: 'SearchInstrumentsController',
    );
    print('🔎 [SearchInstruments] REQUEST URL: ${ApiConstants.baseUrl}$endpoint');

    try {
      isLoading.value = true;
      final response = await ApiService.get(endpoint: endpoint);

      // ---- DEBUG: RAW RESPONSE ----
      print('🔎 [SearchInstruments] success: ${response.success}');
      print('🔎 [SearchInstruments] message: ${response.message}');
      try {
        final encoded = jsonEncode(response.data);
        final preview = encoded.length > 4000
            ? '${encoded.substring(0, 4000)}...(truncated ${encoded.length - 4000} chars)'
            : encoded;
        print('🔎 [SearchInstruments] RAW DATA: $preview');
      } catch (_) {
        print('🔎 [SearchInstruments] RAW DATA (non-json): ${response.data}');
      }

      if (response.success && response.data != null) {
        final searchResponse =
            SearchInstrumentsResponse.fromJson(response.data);

        print(
          '🔎 [SearchInstruments] PARSED → status: ${searchResponse.status} | '
          'data != null: ${searchResponse.data != null} | '
          'symbols count: ${searchResponse.data?.symbols.length ?? 0}',
        );

        if (searchResponse.data != null) {
          allSymbols.assignAll(searchResponse.data!.symbols);
          for (final s in searchResponse.data!.symbols) {
            if (s.datafeedSymbol.isNotEmpty) {
              SymbolDetailsCacheService.registerDatafeedSymbol(s.displaySymbol, s.datafeedSymbol);
            }
          }
          _updateAvailableCategories();

          currentCategory.value = 'All';

          _applyFilter();

          print(
            '🔎 [SearchInstruments] AFTER FILTER → allSymbols: ${allSymbols.length} | '
            'filteredSymbols: ${filteredSymbols.length} | '
            'availableCategories: $availableCategories',
          );
          if (allSymbols.isNotEmpty) {
            final first = allSymbols.first;
            print(
              '🔎 [SearchInstruments] FIRST SYMBOL → display: ${first.displaySymbol} | '
              'category: ${first.categoryName} | digits: ${first.digits}',
            );
          }
        } else {
          print('⚠️ [SearchInstruments] searchResponse.data is NULL');
        }
      } else {
        print(
          '⚠️ [SearchInstruments] Bad response → success=${response.success}, '
          'data=${response.data}',
        );
      }
    } catch (e, st) {
      print('❌ [SearchInstruments] Error fetching search instruments: $e');
      print('❌ [SearchInstruments] StackTrace: $st');
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
    // Only show categories that have at least one symbol in the API response.
    // 'All' is always shown first (if there are any symbols at all).
    final presentChips = <String>[];

    if (allSymbols.isNotEmpty) {
      presentChips.add('All');
    }

    for (final chip in _categoryChipOrder) {
      if (chip == 'All') continue; // already handled above
      final hasMatch = allSymbols.any(
        (s) => symbolMatchesCategoryChip(s.categoryName, chip),
      );
      if (hasMatch) {
        presentChips.add(chip);
      }
    }

    availableCategories.assignAll(presentChips);
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
