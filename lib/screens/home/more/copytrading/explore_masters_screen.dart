import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_masters_controller.dart';
import 'package:crm_app/screens/home/more/copytrading/master_details_screen.dart';
import 'package:crm_app/services/language_service.dart';

/// Explore Masters — Elite Trading Pro Redesign.
///
/// Features:
///   • Executive Glassmorphic Hero Hub Card (AUM, Avg Gain, Masters & Enrolled counts)
///   • Sleek integrated Search & Filter Bar
///   • Custom Segmented Pill Tab Switcher (All / Enrolled / Discover)
///   • Filter Badges Strip (Risk, Time, Sort)
///   • High-tech Master Trader Cards with verified badge, 3-column stats, and prominent CTA
///   • Custom Shimmer Loading Skeleton
///   • 100% Adaptive & Responsive across all screen sizes
class ExploreMastersScreen extends StatefulWidget {
  const ExploreMastersScreen({super.key});

  @override
  State<ExploreMastersScreen> createState() => _ExploreMastersScreenState();
}

class _ExploreMastersScreenState extends State<ExploreMastersScreen> {
  late final CopyTradingMastersController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(CopyTradingMastersController(), permanent: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.isLoading.value &&
          controller.allMasters.isEmpty &&
          controller.errorMessage.value.isEmpty) {
        controller.refreshMasters();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 0,
        title: Text(
          TranslationUtils.tr('explore_masters_screen_explore_masters'),
          style: AppTextStyles.heading.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: AppColors.textPrimary,
                size: 18.sp,
              ),
            ),
            tooltip: TranslationUtils.tr('common_refresh'),
            onPressed: () {
              HapticFeedback.lightImpact();
              controller.refreshMasters();
            },
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.allMasters.isEmpty) {
          return const _ExploreMastersProShimmer();
        }
        if (controller.errorMessage.value.isNotEmpty &&
            controller.allMasters.isEmpty) {
          return _ErrorState(
            message: controller.errorMessage.value,
            onRetry: controller.refreshMasters,
          );
        }

        // ─── Filtered items ─────────────────────────────────────
        final filter = controller.selectedFilter.value;
        final filtered =
            controller.allMasters.where((m) {
              if (filter == MasterFilterTab.enrolled) return m.isEnrolled;
              if (filter == MasterFilterTab.discover) return !m.isEnrolled;
              return true;
            }).toList();

        final q = controller.searchQuery.value.trim().toLowerCase();
        final visible =
            q.isEmpty
                ? filtered
                : filtered
                    .where(
                      (m) =>
                          m.nickname.toLowerCase().contains(q) ||
                          m.name.toLowerCase().contains(q) ||
                          m.masterCode.toLowerCase().contains(q),
                    )
                    .toList();

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: controller.refreshMasters,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsetsDirectional.fromSTEB(14.w, 12.h, 14.w, 100.h),
            children: [
              // 1. Hero Performance Hub Banner
              const _HeroPerformanceBanner(),
              SizedBox(height: 14.h),

              // 2. Search & Segmented Controls
              _SearchBarSection(controller: controller),
              SizedBox(height: 10.h),

              // 3. Category Tabs (All / Enrolled / Discover)
              _SegmentedFilterTabs(controller: controller),
              SizedBox(height: 10.h),

              // 4. Filter Chips Strip
              _FilterChipsStrip(controller: controller),
              SizedBox(height: 14.h),

              // 5. Trader Cards List
              if (visible.isEmpty)
                _NoSearchMatchesState(
                  query: controller.searchQuery.value,
                  onClear: () {
                    controller.search.value = '';
                    controller.selectedFilter.value = MasterFilterTab.all;
                    controller.riskFilter.value = 'All Risks';
                  },
                )
              else
                ...visible.map((m) => _ProMasterCardWrapper(m: m)),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────── 1. HERO PERFORMANCE BANNER ───────────────────────────

class _HeroPerformanceBanner extends StatelessWidget {
  const _HeroPerformanceBanner();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CopyTradingMastersController>();
    final all = controller.allMasters;
    final communityAum = all.fold<double>(
      0,
      (sum, m) => sum + m.totalAum.toDouble(),
    );
    final gains =
        all
            .map((m) => m.totalGainPercent.toDouble())
            .where((g) => g != 0)
            .toList();
    final avgGain =
        gains.isEmpty ? 0.0 : gains.reduce((a, b) => a + b) / gains.length;
    final enrolled = all.where((m) => m.isEnrolled).length;

    final isDark = AppColors.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.45),
                  AppColors.primary.withValues(alpha: 0.80),
                ]
              : [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.45),
                ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.primary).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Tag + Live Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_graph_rounded,
                            size: 13.sp,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            TranslationUtils.tr('copy_trading_hub_banner_title'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6.r,
                        height: 6.r,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        TranslationUtils.tr('copy_trading_live_pool'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Main Primary KPI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationUtils.tr('copy_trading_total_community_aum'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      _formatMoney(communityAum),
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                // Avg Gain Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        TranslationUtils.tr('copy_trading_avg_return'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 9.sp,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(
                            avgGain >= 0
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            size: 14.sp,
                            color: avgGain >= 0
                                ? const Color(0xFF34D399)
                                : const Color(0xFFF87171),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            '${avgGain >= 0 ? '+' : ''}${_formatPct(avgGain)}%',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                              color: avgGain >= 0
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Bottom Sub-metrics strip
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _heroSubItem(
                    icon: Icons.groups_rounded,
                    label: TranslationUtils.tr('copy_trading_available_masters'),
                    value: '${all.length}',
                  ),
                  Container(
                    height: 20.h,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  _heroSubItem(
                    icon: Icons.verified_user_rounded,
                    label: TranslationUtils.tr('copy_trading_enrolled_by_you'),
                    value: '$enrolled',
                    highlight: enrolled > 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroSubItem({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15.sp, color: Colors.white.withValues(alpha: 0.8)),
        SizedBox(width: 6.w),
        Text(
          '$label: ',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 11.sp,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: highlight ? const Color(0xFF34D399) : Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── 2. SEARCH BAR ───────────────────────────

class _SearchBarSection extends StatelessWidget {
  final CopyTradingMastersController controller;
  const _SearchBarSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        onChanged: (v) => controller.search.value = v.trim(),
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.textPrimary,
          fontSize: 13.sp,
        ),
        decoration: InputDecoration(
          hintText: TranslationUtils.tr('copy_trading_search_master_hint'),
          hintStyle: AppTextStyles.bodyText.copyWith(
            color: AppColors.textGrey,
            fontSize: 12.5.sp,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18.sp,
            color: AppColors.textGrey,
          ),
          suffixIcon: Obx(() {
            if (controller.search.value.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(Icons.clear_rounded, size: 16.sp, color: AppColors.textGrey),
              onPressed: () => controller.search.value = '',
            );
          }),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        ),
      ),
    );
  }
}

// ─────────────────────────── 3. SEGMENTED FILTER TABS ───────────────────────────

class _SegmentedFilterTabs extends StatelessWidget {
  final CopyTradingMastersController controller;
  const _SegmentedFilterTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.selectedFilter.value;
      final all = controller.allMasters;
      final allCount = all.length;
      final enrolledCount = all.where((m) => m.isEnrolled).length;
      final discoverCount = all.where((m) => !m.isEnrolled).length;

      return Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _segmentItem(
                label: TranslationUtils.tr('copy_trading_all_masters'),
                count: allCount,
                isSelected: active == MasterFilterTab.all,
                onTap: () => controller.selectedFilter.value = MasterFilterTab.all,
              ),
            ),
            Expanded(
              child: _segmentItem(
                label: TranslationUtils.tr('dc_enrolled'),
                count: enrolledCount,
                isSelected: active == MasterFilterTab.enrolled,
                onTap: () => controller.selectedFilter.value = MasterFilterTab.enrolled,
              ),
            ),
            Expanded(
              child: _segmentItem(
                label: TranslationUtils.tr('copy_trading_discover'),
                count: discoverCount,
                isSelected: active == MasterFilterTab.discover,
                onTap: () => controller.selectedFilter.value = MasterFilterTab.discover,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _segmentItem({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.5.sp,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.whiteColor : AppColors.textGrey,
              ),
            ),
            SizedBox(width: 4.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppColors.whiteColor : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── 4. FILTER CHIPS STRIP ───────────────────────────

/// Maps a raw filter value (kept untranslated because it drives the filtering
/// logic) onto its localized display label.
String _filterLabel(String raw) => switch (raw) {
      'All Risks' => TranslationUtils.tr('copy_trading_all_risks'),
      'Low (1-2)' => TranslationUtils.tr('copy_trading_risk_low'),
      'Medium (3)' => TranslationUtils.tr('copy_trading_risk_medium'),
      'High (4-5)' => TranslationUtils.tr('copy_trading_risk_high'),
      'All Time' => TranslationUtils.tr('ibm_range_all_time'),
      'Last 7 Days' => TranslationUtils.tr('ibm_last_7_days'),
      'Last 30 Days' => TranslationUtils.tr('ibm_last_30_days'),
      'Last 90 Days' => TranslationUtils.tr('copy_trading_last_90_days'),
      'Last Year' => TranslationUtils.tr('copy_trading_last_year'),
      'Gain %' => TranslationUtils.tr('copy_trading_gain_percent'),
      'AUM' => TranslationUtils.tr('copy_trading_aum'),
      'Copiers' => TranslationUtils.tr('my_plans_tab_copiers'),
      'Active Days' => TranslationUtils.tr('copy_trading_active_days'),
      _ => raw,
    };

class _FilterChipsStrip extends StatelessWidget {
  final CopyTradingMastersController controller;
  const _FilterChipsStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SizedBox(
        height: 32.h,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            _chip(
              label: _filterLabel(controller.riskFilter.value),
              icon: Icons.shield_rounded,
              isActive: controller.riskFilter.value != 'All Risks',
              onTap: () => _showRiskSheet(context, controller),
            ),
            SizedBox(width: 8.w),
            _chip(
              label: _filterLabel(controller.timeFilter.value),
              icon: Icons.timelapse_rounded,
              isActive: controller.timeFilter.value != 'All Time',
              onTap: () => _showTimeSheet(context, controller),
            ),
            SizedBox(width: 8.w),
            _chip(
              label: TranslationUtils.trArgs('copy_trading_sort_value', {
                'value': _filterLabel(controller.sortBy.value),
              }),
              icon: Icons.tune_rounded,
              isActive: controller.sortBy.value != 'Gain %',
              onTap: () => _showSortSheet(context, controller),
            ),
          ],
        ),
      );
    });
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12.5.sp,
              color: isActive ? AppColors.primary : AppColors.textGrey,
            ),
            SizedBox(width: 4.w),
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 2.w),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16.sp,
              color: isActive ? AppColors.primary : AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }

  void _showRiskSheet(BuildContext context, CopyTradingMastersController c) {
    _showOptionsSheet(
      context: context,
      title: TranslationUtils.tr('copy_trading_filter_by_risk_level'),
      options: ['All Risks', 'Low (1-2)', 'Medium (3)', 'High (4-5)'],
      current: c.riskFilter.value,
      onSelect: (v) => c.riskFilter.value = v,
    );
  }

  void _showTimeSheet(BuildContext context, CopyTradingMastersController c) {
    _showOptionsSheet(
      context: context,
      title: TranslationUtils.tr('copy_trading_performance_timeframe'),
      options: [
        'All Time',
        'Last 7 Days',
        'Last 30 Days',
        'Last 90 Days',
        'Last Year',
      ],
      current: c.timeFilter.value,
      onSelect: (v) => c.timeFilter.value = v,
    );
  }

  void _showSortSheet(BuildContext context, CopyTradingMastersController c) {
    _showOptionsSheet(
      context: context,
      title: TranslationUtils.tr('copy_trading_sort_masters_by'),
      options: ['Gain %', 'AUM', 'Copiers', 'Active Days'],
      current: c.sortBy.value,
      onSelect: (v) => c.sortBy.value = v,
    );
  }

  void _showOptionsSheet({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    title,
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  for (final o in options)
                    InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: () {
                        onSelect(o);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        margin: EdgeInsets.only(bottom: 4.h),
                        decoration: BoxDecoration(
                          color: o == current
                              ? AppColors.primary.withValues(alpha: 0.10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _filterLabel(o),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13.5.sp,
                                fontWeight: o == current
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: o == current
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (o == current)
                              Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18.sp),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }
}

// ─────────────────────────── 5. PRO MASTER TRADER CARDS ───────────────────────────

class _ProMasterCardWrapper extends StatelessWidget {
  final dynamic m;
  const _ProMasterCardWrapper({required this.m});

  @override
  Widget build(BuildContext context) {
    try {
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: _ProMasterCard(
          item: m,
          onTap: () {
            HapticFeedback.selectionClick();
            Get.to(() => MasterDetailsScreen(masterCode: m.masterCode));
          },
          onCopy: () {
            HapticFeedback.selectionClick();
            Get.to(() => MasterDetailsScreen(masterCode: m.masterCode));
          },
        ),
      );
    } catch (e, st) {
      debugPrint('[ExploreMasters] render failed: $e');
      debugPrintStack(label: 'card render', stackTrace: st);
      return const SizedBox.shrink();
    }
  }
}

class _ProMasterCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _ProMasterCard({
    required this.item,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final gain = (item.totalGainPercent as num).toDouble();
    final drawdown = (item.maxDrawdown as num).toDouble();
    final pnl = (item.totalPnl as num).toDouble();
    final minInvest = (item.minInvestment as num).toDouble();
    final activeDays = item.activeDays as int;
    final totalCopiers = item.totalCopiers as int;
    final riskScore = item.riskScore as int? ?? 0;
    final hasPlan = (item.planCount as int) > 0;
    final serverType =
        (item.serverType is String && (item.serverType as String).isNotEmpty)
            ? (item.serverType as String)
            : 'mt5';
    final commissionPct = _safeCommission(item);
    final displayName =
        (item.nickname?.toString().isNotEmpty ?? false)
            ? item.nickname.toString()
            : item.name.toString();

    final gainText = '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%';
    final drawdownText = '-${drawdown.toStringAsFixed(0)}%';
    final pnlText = _formatPnl(pnl);
    final minInvestText =
        minInvest == 0 ? '\$0' : '\$${minInvest.toStringAsFixed(0)}';
    final pnlColor = pnl >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final isGainPositive = gain >= 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Squircle Avatar with Pro Badge
                    Stack(
                      children: [
                        Container(
                          width: 46.w,
                          height: 46.h,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF3B82F6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(displayName),
                            style: AppTextStyles.bodyText.copyWith(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          end: -1,
                          bottom: -1,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_rounded,
                              size: 14.sp,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 12.w),
                    // Trader Name & Tags
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  serverType == 'self_hosted'
                                      ? 'SELFHOSTED'
                                      : serverType.toUpperCase(),
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                TranslationUtils.trArgs('copy_trading_days_active', {
                                  'days': '$activeDays',
                                }),
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 11.sp,
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Risk Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: _riskColor(riskScore).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: _riskColor(riskScore).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        TranslationUtils.trArgs('copy_trading_risk_score_pill', {
                          'score': '$riskScore',
                        }),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: _riskColor(riskScore),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),

                // Hero Gain Block (Fintech Style)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isGainPositive
                        ? const Color(0xFF10B981).withValues(alpha: 0.08)
                        : const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isGainPositive
                          ? const Color(0xFF10B981).withValues(alpha: 0.20)
                          : const Color(0xFFEF4444).withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isGainPositive
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 16.sp,
                            color: isGainPositive
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            TranslationUtils.tr('copy_trading_total_gain_roi'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.5.sp,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        gainText,
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: isGainPositive
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),

                // 3-Column Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _statPill(
                        label: TranslationUtils.tr('copy_trading_total_pnl'),
                        value: pnlText,
                        valueColor: pnlColor,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _statPill(
                        label: TranslationUtils.tr('copy_trading_max_drawdown'),
                        value: drawdownText,
                        valueColor: const Color(0xFFEF4444),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _statPill(
                        label: TranslationUtils.tr('copy_trading_min_invest'),
                        value: minInvestText,
                        valueColor: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),

                // Footer Bar (Fee, Copiers, CTA)
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        TranslationUtils.trArgs('copy_trading_fee_value', {
                          'value': commissionPct,
                        }),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 10.5.sp,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.people_alt_rounded,
                      size: 14.sp,
                      color: AppColors.textGrey,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      TranslationUtils.trArgs('copy_trading_count_copiers', {
                        'count': '$totalCopiers',
                      }),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: hasPlan ? onCopy : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.textGrey.withValues(alpha: 0.15),
                        foregroundColor: Colors.white,
                        elevation: hasPlan ? 2 : 0,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        minimumSize: Size(0, 34.h),
                      ),
                      child: Text(
                        hasPlan
                            ? TranslationUtils.tr('copy_trading_copy_strategy')
                            : TranslationUtils.tr('copy_trading_no_plan'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: hasPlan ? AppColors.whiteColor : AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statPill({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 9.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.5.sp,
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── HELPERS ───────────────────────────

String _safeCommission(dynamic item) {
  try {
    final dynamic raw = item.commissionPercentage;
    if (raw is num) return '${raw.toStringAsFixed(0)}%';
  } catch (_) {}
  return '—';
}

Color _riskColor(int risk) {
  if (risk <= 2) return const Color(0xFF10B981);
  if (risk == 3) return const Color(0xFFF59E0B);
  return const Color(0xFFEF4444);
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _formatMoney(num n) {
  final abs = n.abs();
  if (abs >= 1000000) {
    return '\$${(n / 1000000).toStringAsFixed(2)}M';
  }
  if (abs >= 1000) {
    return '\$${(n / 1000).toStringAsFixed(2)}K';
  }
  return '\$${n.toStringAsFixed(0)}';
}

String _formatPct(num n) {
  return n.toStringAsFixed(n.abs() >= 100 ? 0 : 2);
}

String _formatPnl(num n) {
  final abs = n.abs();
  String body;
  if (abs >= 1000) {
    body = '${(abs / 1000).toStringAsFixed(2)}K';
  } else {
    body = abs.toStringAsFixed(2);
  }
  return '${n < 0 ? '-' : (n > 0 ? '+' : '')}\$$body';
}

// ─────────────────────────── PRO SHIMMER SKELETON ───────────────────────────

class _ExploreMastersProShimmer extends StatelessWidget {
  const _ExploreMastersProShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final baseColor = isDark ? const Color(0xFF1E1E28) : const Color(0xFFE5E7EB);
    final highlightColor = isDark ? const Color(0xFF2D2D3D) : const Color(0xFFF3F4F6);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 100.h),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Hero Banner Shimmer
          _shimmerBox(height: 160.h, radius: 20.r),
          SizedBox(height: 14.h),

          // Search Box Shimmer
          _shimmerBox(height: 44.h, radius: 14.r),
          SizedBox(height: 10.h),

          // Segmented Tabs Shimmer
          _shimmerBox(height: 40.h, radius: 14.r),
          SizedBox(height: 10.h),

          // Filter Chips Shimmer
          Row(
            children: [
              _shimmerBox(width: 80.w, height: 32.h, radius: 16.r),
              SizedBox(width: 8.w),
              _shimmerBox(width: 90.w, height: 32.h, radius: 16.r),
              SizedBox(width: 8.w),
              _shimmerBox(width: 90.w, height: 32.h, radius: 16.r),
            ],
          ),
          SizedBox(height: 14.h),

          // Trader Cards Shimmer
          for (int i = 0; i < 3; i++) ...[
            _shimmerBox(height: 210.h, radius: 18.r),
            SizedBox(height: 12.h),
          ],
        ],
      ),
    );
  }

  Widget _shimmerBox({
    double? width,
    required double height,
    double radius = 16,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _NoSearchMatchesState extends StatelessWidget {
  final String query;
  final VoidCallback onClear;
  const _NoSearchMatchesState({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
         
          SizedBox(height: 14.h),
          Text(
            query.isEmpty
                ? TranslationUtils.tr('copy_trading_not_enrolled_in_master')
                : TranslationUtils.trArgs('copy_trading_no_masters_match', {
                    'query': query,
                  }),
            textAlign: TextAlign.center,
            style: AppTextStyles.subheading.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 24.h),
          OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(TranslationUtils.tr('copy_trading_explore_all_masters')),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 36.sp, color: AppColors.error),
            ),
            SizedBox(height: 14.h),
            Text(
              TranslationUtils.tr('copy_trading_failed_to_load_masters'),
              style: AppTextStyles.heading.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              label: Text(TranslationUtils.tr('common_retry')),
            ),
          ],
        ),
      ),
    );
  }
}

