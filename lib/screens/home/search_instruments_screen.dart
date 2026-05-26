import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/search_instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/models/search_instruments_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/services/symbol_selection_service.dart';
import 'package:crm_app/screens/home/chart_screen.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class SearchInstrumentsScreen extends StatefulWidget {
  final Function(String)? onNavigateToChart;

  const SearchInstrumentsScreen({super.key, this.onNavigateToChart});

  @override
  State<SearchInstrumentsScreen> createState() =>
      _SearchInstrumentsScreenState();
}

class _SearchInstrumentsScreenState extends State<SearchInstrumentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchInstrumentsController _controller = Get.put(
    SearchInstrumentsController(),
  );
  final SymbolSelectionService _symbolSelectionService =
      Get.find<SymbolSelectionService>();
  final LanguageService languageService = Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    // Reset each visit: controller may be reused via Get.put with a stale tab.
    _controller.filterByCategory('Currency');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryFilters(),
            Expanded(
              child: Obx(() {
                if (_controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_controller.filteredSymbols.isEmpty) {
                  return _buildNoData();
                }
                return _buildInstrumentsList(_controller.filteredSymbols);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle for bottom sheet
        Container(
          margin: EdgeInsets.only(top: 12.h),
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: AppColors.textGrey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              AppBackButton(onPressed: () => Get.back(closeOverlays: true),
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
      if (_controller.availableCategories.isEmpty)
        return const SizedBox.shrink();

      return Container(
        height: 50.h,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: _controller.availableCategories.length,
          itemBuilder: (context, index) {
            final category = _controller.availableCategories[index];

            return Obx(() {
              final isSelected = category == _controller.currentCategory.value;
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: GestureDetector(
                  onTap: () => _controller.filterByCategory(category),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors.chipSelected
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: AppTextStyles.input.copyWith(
                          fontSize: 12.sp,
                          color:
                              isSelected
                                  ? AppColors.chipText
                                  : AppColors.primary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
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
        final symbol = symbols[index];
        return _buildInstrumentItem(symbol);
      },
    );
  }

  Widget _buildInstrumentItem(SearchSymbol symbol) {
    final instrumentsController = Get.find<InstrumentsController>();

    return GestureDetector(
      onTap: () {
        _navigateToChartWithSymbol(symbol.displaySymbol);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 45.w,
              alignment: Alignment.centerLeft,
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
            SizedBox(width: 8.w),
            Obx(() {
              final isFavorite = instrumentsController.isFavorite(
                symbol.displaySymbol,
              );
              return GestureDetector(
                onTap: () async {
                  final ic = instrumentsController;
                  await ic.toggleFavorite(symbol.displaySymbol);
                  await ic.syncMarketWatchV2AfterFavoriteChange(
                    symbol.displaySymbol,
                    isFavoriteNow: ic.isFavorite(symbol.displaySymbol),
                  );
                },
                child: Icon(
                  isFavorite ? Icons.check_circle : Icons.add_circle_outline,
                  size: 24.h,
                  color:
                      isFavorite
                          ? AppColors.primary
                          : AppColors.textGrey.withOpacity(0.5),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _navigateToChartWithSymbol(String symbol) {
    _symbolSelectionService.setSymbol(symbol);
    ChartScreen.setSelectedSymbol(symbol);

    if (widget.onNavigateToChart != null) {
      widget.onNavigateToChart!(symbol);
      Get.back(); // Go back to main screen which then switches tab
    } else {
      // If no callback, maybe we are in a standalone mode, just go back
      Get.back();
    }
  }

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

  String _removeSymbolSuffix(String symbol) {
    if (symbol.contains('.')) {
      return symbol.substring(0, symbol.lastIndexOf('.'));
    }
    return symbol;
  }

  String _getFlagPath(String symbol) {
    String cleanSymbol =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;
    return 'assets/svg/flags/${cleanSymbol.toLowerCase()}.svg';
  }

  Widget _buildFlagIcon(String symbol) {
    final flagPath = _getFlagPath(symbol);
    return Container(
      width: 40.w,
      height: 40.h,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: SvgPicture.asset(
          flagPath,
          width: 32.w,
          height: 32.h,
          fit: BoxFit.cover,
          placeholderBuilder: (context) => _buildFallbackFlag(),
        ),
      ),
    );
  }

  Widget _buildFallbackFlag() {
    return Container(
      width: 40.w,
      height: 40.h,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(Icons.flag, color: AppColors.primary, size: 20.w),
    );
  }

  void _onSearchTextChanged() {
    _controller.searchInstruments(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }
}
