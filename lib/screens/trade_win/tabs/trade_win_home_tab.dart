import 'package:crm_app/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/responsive_layout.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trade_win/view_models/trade_win_controller.dart';
import 'package:crm_app/models/trade_win/trade_win_product_model.dart';
import 'package:crm_app/models/trade_win/trade_win_stats_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trade_win_format.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/trade_win/widgets/trade_win_product_image.dart';

class TradeWinHomeTab extends StatelessWidget {
  const TradeWinHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final controller = Get.find<TradeWinController>();

    return Obx(() {
      if (controller.isLoading.value && controller.products.isEmpty) {
        return Center(
          child: CommonLoadingWidget(size: 40, color: AppColors.primary),
        );
      }

      if (!controller.moduleEnabled.value) {
        return _ModuleDisabled(languageService: languageService);
      }

      final stats = controller.stats.value;
      final selectedCategory = controller.selectedCategory.value;
      final categories = controller.categories;

      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification n) {
          if (n is! ScrollUpdateNotification) return false;
          final m = n.metrics;
          if (!m.hasPixels || m.maxScrollExtent <= 0) return false;
          if (m.pixels >= m.maxScrollExtent - 280) {
            controller.loadMoreProducts();
          }
          return false;
        },
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () =>
              controller.fetchProducts(showLoader: false, audience: 'client'),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.w, 0.h, 0.w, 0),
                  child: Row(
                    children: [
                      const AppBackButton(closeOverlays: true),
                      Expanded(
                        child: Text(
                          languageService.tr('tw_title'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.heading,
                        ),
                      ),
                      SizedBox(width: AppBackButton.leadingSlotSize.w),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
                  child: _OverviewSection(
                    stats: stats,
                    languageService: languageService,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(16.w, 8.h, 16.w, 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        languageService.tr('tw_product_catalog'),
                        style: AppTextStyles.headingblack,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => SizedBox(width: 8.w),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final selected = selectedCategory == cat;
                      final label =
                          cat == 'all'
                              ? languageService.tr('tw_all')
                              : controller.categoryDisplayName(cat);
                      return _CatalogFilterChip(
                        label: label,
                        selected: selected,
                        onTap: () => controller.selectCategory(cat),
                      );
                    },
                  ),
                ),
              ),
              Obx(() {
                final items = controller.filteredProducts;
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.h),
                      child: Center(
                        child: Text(
                          languageService.tr('tw_no_products'),
                          style: AppTextStyles.subheading,
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16.w, 12.h, 16.w, 0),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12.h,
                      crossAxisSpacing: 12.w,
                      childAspectRatio: ResponsiveGrid.aspectRatio(0.46), // reduced to give more height and prevent overflow
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ProductCatalogCard(
                        product: items[index],
                        languageService: languageService,
                      ),
                      childCount: items.length,
                    ),
                  ),
                );
              }),
              Obx(() {
                if (!controller.isLoadingMoreProducts.value) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Center(
                      child: CommonLoadingWidget(
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              }),
              SliverToBoxAdapter(child: SizedBox(height: 100.h)),
            ],
          ),
        ),
      );
    });
  }
}

class _ModuleDisabled extends StatelessWidget {
  final LanguageService languageService;

  const _ModuleDisabled({required this.languageService});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              languageService.tr('tw_module_disabled'),
              style: AppTextStyles.heading,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => Get.back(),
              child: Text(languageService.tr('tw_back')),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final TradeWinStatsModel? stats;
  final LanguageService languageService;

  const _OverviewSection({required this.stats, required this.languageService});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Text(
          languageService.tr('tw_no_data'),
          style: AppTextStyles.subheading,
        ),
      );
    }

    final cards = [
      _OverviewCardData(
        icon: Icons.show_chart_rounded,
        title: languageService.tr('tw_available_lots'),
        value: TradeWinFormat.lots(s.totalLots),
        valueColor: AppColors.green,
        subtitle: languageService.tr('tw_spendable_volume'),
        footerLines: [
          _OverviewFooterLine(
            prefix: languageService.tr('tw_total_traded_prefix'),
            value: languageService.tr('tw_lots_amount', {
              'lots': TradeWinFormat.lots(s.lifetimeLots),
            }),
          ),
          _OverviewFooterLine(
            prefix: languageService.tr('tw_already_spent_prefix'),
            value: languageService.tr('tw_lots_amount', {
              'lots': TradeWinFormat.lots(s.spentLots),
            }),
          ),
        ],
      ),
      _OverviewCardData(
        icon: Icons.account_balance_wallet_outlined,
        title: languageService.tr('tw_available_points'),
        value: TradeWinFormat.pointsValue(s.totalPoints),
        subtitle: languageService.tr('tw_spendable_balance'),
      ),
      _OverviewCardData(
        icon: Icons.military_tech_outlined,
        title: languageService.tr('tw_past_wins'),
        value: '${s.pastWinsCount}',
        subtitle: languageService.tr('tw_total_redemptions'),
      ),
      _OverviewCardData(
        icon: Icons.emoji_events_outlined,
        title: languageService.tr('tw_value_won'),
        value: TradeWinFormat.currency(s.totalPrizeValueWon),
        subtitle: languageService.tr('tw_total_prize_value'),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              _OverviewCompactRow(data: cards[i]),
              if (i < cards.length - 1)
                Divider(
                  height: 1,
                  indent: 48.w,
                  endIndent: 12.w,
                  color: AppColors.icongrey.withValues(alpha: 0.12),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewCardData {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color? valueColor;
  final List<_OverviewFooterLine> footerLines;

  const _OverviewCardData({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.valueColor,
    this.footerLines = const [],
  });
}

class _OverviewFooterLine {
  final String prefix;
  final String value;

  const _OverviewFooterLine({required this.prefix, required this.value});
}

class _OverviewCompactRow extends StatelessWidget {
  final _OverviewCardData data;

  const _OverviewCompactRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(10.w, 8.h, 12.w, 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Icon(data.icon, color: AppColors.primary, size: 16.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        data.title.toUpperCase(),
                        style: AppTextStyles.subheading.copyWith(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Text(
                      data.value,
                      style: AppTextStyles.headingblack.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: data.valueColor ?? AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  data.subtitle,
                  style: AppTextStyles.subheading.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (data.footerLines.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  for (var i = 0; i < data.footerLines.length; i++) ...[
                    _OverviewFooterText(line: data.footerLines[i]),
                    if (i < data.footerLines.length - 1) SizedBox(height: 2.h),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewFooterText extends StatelessWidget {
  final _OverviewFooterLine line;

  const _OverviewFooterText({required this.line});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.subheading.copyWith(
          fontSize: 11.sp,
          color: AppColors.textGrey,
        ),
        children: [
          TextSpan(text: line.prefix),
          TextSpan(
            text: ' ${line.value}',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color labelColor;

  const _CatalogInfoChip({
    required this.label,
    required this.value,
    required this.bg,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 7.sp,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: AppTextStyles.headingblack.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ProductCatalogCard extends StatelessWidget {
  final TradeWinProductModel product;
  final LanguageService languageService;

  const _ProductCatalogCard({
    required this.product,
    required this.languageService,
  });

  @override
  Widget build(BuildContext context) {
    final progress = product.progressFraction;
    final percent = (progress * 100).round();

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: TradeWinProductImage(
              imagePath: product.imagePath,
              width: 130.w,
              height: 130.w,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            product.name,
            style: AppTextStyles.headingblack.copyWith(fontSize: 14.sp),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              TradeWinFormat.categoryTag(product.category),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 8.h),
          _CatalogInfoChip(
            label: languageService.tr('tw_lot_required'),
            value: languageService.tr('tw_lot_required_chip', {
              'lots': TradeWinFormat.lots(product.requiredLots),
            }),
            bg: AppColors.primary.withValues(alpha: 0.1),
            labelColor: AppColors.primary,
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6.h,
              backgroundColor: AppColors.icongrey.withValues(alpha: 0.2),
              color: AppColors.green,
            ),
          ),
          SizedBox(height: 6.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              languageService.tr('tw_progress_lots', {
                'current': TradeWinFormat.lots(product.availableLots),
                'required': TradeWinFormat.lots(product.requiredLots),
                'percent': '$percent',
              }),
              style: AppTextStyles.subheading.copyWith(fontSize: 11.sp),
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _onRedeem(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor:
                    ThemeData.estimateBrightnessForColor(AppColors.primary) ==
                            Brightness.light
                        ? Colors.black
                        : Colors.white,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  side: BorderSide.none,
                ),
              ),
              child: Text(
                languageService.tr('tw_redeem_now'),
                style: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                  color:
                      ThemeData.estimateBrightnessForColor(AppColors.primary) ==
                              Brightness.light
                          ? Colors.black
                          : Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onRedeem(BuildContext context) {
    if (!product.canRedeem) {
      CustomToastService.showWarning(
        message: languageService.tr('tw_insufficient_eligibility'),
      );
      return;
    }
    Get.toNamed(
      AppPages.TRADE_WIN_PRODUCT_DETAIL,
      arguments: {'productId': product.id},
    );
  }
}

class _CatalogFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CatalogFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color:
                selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.chipSurface,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.sp,
            ),
          ),
        ),
      ),
    );
  }
}
