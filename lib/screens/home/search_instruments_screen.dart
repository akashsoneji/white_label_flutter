import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/search_instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/models/search_instruments_model.dart';
import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/services/symbol_selection_service.dart';
import 'package:crm_app/screens/home/chart_screen.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class SearchInstrumentsScreen extends StatefulWidget {
  final Function(String)? onNavigateToChart;

  /// When true (chart screen use-case):
  ///  - Shows the same live instruments data as the Quote (Instruments) tab
  ///  - Only favourited instruments are shown (with live bid/ask prices)
  ///  - Category/segment chips are hidden
  ///  - Add/remove favourite button is hidden
  final bool favoritesOnly;

  const SearchInstrumentsScreen({
    super.key,
    this.onNavigateToChart,
    this.favoritesOnly = false,
  });

  @override
  State<SearchInstrumentsScreen> createState() =>
      _SearchInstrumentsScreenState();
}

class _SearchInstrumentsScreenState extends State<SearchInstrumentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final LanguageService languageService = Get.find<LanguageService>();
  final SymbolSelectionService _symbolSelectionService =
      Get.find<SymbolSelectionService>();

  // Used in normal (non-favoritesOnly) mode
  late final SearchInstrumentsController _searchController2;

  // Used in favoritesOnly mode — same source as Quote tab
  late final InstrumentsController _instrumentsController;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);

    if (widget.favoritesOnly) {
      _instrumentsController = Get.find<InstrumentsController>();
    } else {
      // If the controller already exists from a previous open, Get.put returns
      // the existing instance and onInit() does NOT run again. We must
      // explicitly refetch so data reflects the current active MT5 account.
      final alreadyRegistered =
          Get.isRegistered<SearchInstrumentsController>();
      _searchController2 = Get.put(SearchInstrumentsController());
      _searchController2.filterByCategory('All');
      if (alreadyRegistered) {
        _searchController2.fetchInstruments();
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            // Category chips — only in normal mode
            if (!widget.favoritesOnly) _buildCategoryFilters(),

            Expanded(
              child: widget.favoritesOnly
                  ? _buildFavoritesLiveList()
                  : _buildNormalList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Favourites-only: live data from InstrumentsController ───────────────

  Widget _buildFavoritesLiveList() {
    return Obx(() {
      final allInstruments = _instrumentsController.instruments;
      final query = _searchController.text.toLowerCase();

      final filtered = <ListElement>[];
      final seen = <String>{};
      for (final inst in allInstruments) {
        final stripped = _removeSymbolSuffix(inst.symbol);
        if (query.isNotEmpty && !stripped.toLowerCase().contains(query)) {
          continue;
        }
        if (!seen.contains(stripped.toUpperCase())) {
          seen.add(stripped.toUpperCase());
          filtered.add(inst);
        }
      }

      if (_instrumentsController.isLoadingFavorites.value &&
          allInstruments.isEmpty) {
        return Center(child: CircularProgressIndicator());
      }

      if (filtered.isEmpty) {
        return _buildNoFavoritesData();
      }

      return ListView.builder(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildLiveInstrumentItem(filtered[index]);
        },
      );
    });
  }

  /// Row: flag icon + symbol name only. No live prices.
  Widget _buildLiveInstrumentItem(ListElement instrument) {
    return GestureDetector(
      onTap: () => _navigateToChartWithSymbol(instrument.symbol),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildFlagIcon(instrument.symbol),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                _removeSymbolSuffix(instrument.symbol),
                style: AppTextStyles.input.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Normal mode: all instruments from API ────────────────────────────────

  Widget _buildNormalList() {
    return Obx(() {
      if (_searchController2.isLoading.value) {
        return Center(child: CircularProgressIndicator());
      }
      if (_searchController2.filteredSymbols.isEmpty) {
        return _buildNoData();
      }
      return _buildInstrumentsList(_searchController2.filteredSymbols);
    });
  }

  // ─── Shared UI ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          margin: EdgeInsets.only(top: 12.h),
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: AppColors.textGrey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              AppSvgBackButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Get.back(closeOverlays: true);
                },
                iconWidth: 30.w,
                iconHeight: 30.h,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textDirection: RTLHelper.textDirection,
                  textAlign: RTLHelper.isRTL ? TextAlign.right : TextAlign.left,
                  decoration: InputDecoration(
                    hintText: languageService.tr("instruments_search"),
                    hintStyle: AppTextStyles.input.copyWith(
                      color: AppColors.textGrey,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters() {
    return Obx(() {
      if (_searchController2.availableCategories.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        height: 50.h,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: _searchController2.availableCategories.length,
          itemBuilder: (context, index) {
            final category = _searchController2.availableCategories[index];
            return Obx(() {
              final isSelected =
                  category == _searchController2.currentCategory.value;
              return Padding(
                padding: EdgeInsetsDirectional.only(end: 8.w),
                child: GestureDetector(
                  onTap: () => _searchController2.filterByCategory(category),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.selectedChipBackground
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: AppTextStyles.input.copyWith(
                          fontSize: 12.sp,
                          color: isSelected
                              ? AppColors.selectedChipForeground
                              : AppColors.primary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            });
          },
        ),
      );
    });
  }

  Widget _buildInstrumentsList(List<SearchSymbol> symbols) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        return _buildSearchSymbolItem(symbols[index]);
      },
    );
  }

  Widget _buildSearchSymbolItem(SearchSymbol symbol) {
    return GestureDetector(
      onTap: () => _navigateToChartWithSymbol(symbol.displaySymbol),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 45.w,
              alignment: AlignmentDirectional.centerStart,
              child: _buildFlagIcon(symbol.displaySymbol),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _removeSymbolSuffix(symbol.displaySymbol),
                    style: AppTextStyles.input.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    symbol.categoryName,
                    style: AppTextStyles.subheading.copyWith(
                      fontSize: 10.sp,
                      color: AppColors.textGrey,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            // Add/remove favourite icon
            Obx(() {
              final ic = Get.find<InstrumentsController>();
              final isFavorite = ic.isFavorite(symbol.displaySymbol);
              return GestureDetector(
                onTap: () async {
                  await ic.toggleFavorite(
                    symbol.displaySymbol,
                    searchSymbol: symbol,
                    hydrateAfterChange: false,
                  );
                  await ic.syncMarketWatchV2AfterFavoriteChange(
                    symbol.displaySymbol,
                    isFavoriteNow: ic.isFavorite(symbol.displaySymbol),
                  );
                },
                child: Padding(
                  padding: EdgeInsetsDirectional.only(start: 8.w),
                  child: Icon(
                    isFavorite
                        ? Icons.check_circle
                        : Icons.add_circle_outline,
                    size: 24.h,
                    color: isFavorite
                        ? AppColors.primary
                        : AppColors.textGrey.withValues(alpha: 0.5),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Navigation ──────────────────────────────────────────────────────────

  void _navigateToChartWithSymbol(String symbol) {
    FocusManager.instance.primaryFocus?.unfocus();
    _symbolSelectionService.setSymbol(symbol);
    ChartScreen.setSelectedSymbol(symbol);
    if (widget.onNavigateToChart != null) {
      widget.onNavigateToChart!(symbol);
    }
    Get.back();
  }

  // ─── Empty states ─────────────────────────────────────────────────────────

  Widget _buildNoData() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64.h, color: AppColors.textGrey),
          SizedBox(height: 16.h),
          Text(
            languageService.tr("common_no_data"),
            style: AppTextStyles.heading.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFavoritesData() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border_rounded,
              size: 64.h, color: AppColors.textGrey),
          SizedBox(height: 16.h),
          Text(
            languageService.tr('search_instruments_screen_no_favourites_added'),
            style: AppTextStyles.heading.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            languageService.tr(
              'search_instruments_screen_add_symbols_from_the_quote_tab',
            ),
            style: AppTextStyles.subheading.copyWith(
              color: AppColors.textGrey,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _removeSymbolSuffix(String symbol) {
    if (symbol.contains('.')) {
      return symbol.substring(0, symbol.lastIndexOf('.'));
    }
    return symbol;
  }

  Widget _buildFlagIcon(String symbol) {
    final cleanSymbol = symbol.contains('.')
        ? symbol.substring(0, symbol.lastIndexOf('.'))
        : symbol;
    final flagPath = 'assets/svg/flags/${cleanSymbol.toLowerCase()}.svg';

    return Container(
      width: 40.w,
      height: 40.h,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: SvgPicture.asset(
          flagPath,
          width: 32.w,
          height: 32.h,
          fit: BoxFit.cover,
          placeholderBuilder: (context) => Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(Icons.flag, color: AppColors.primary, size: 20.w),
          ),
        ),
      ),
    );
  }

  void _onSearchTextChanged() {
    if (!widget.favoritesOnly) {
      _searchController2.searchInstruments(_searchController.text);
    } else {
      setState(() {}); // trigger Obx re-filter
    }
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }
}
