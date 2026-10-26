import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_copiers_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/home/more/copytrading/copier_subscription_history_screen.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

String _money(num v) => '\$${v.toStringAsFixed(2)}';

Color _pnlColor(num v) => v >= 0 ? AppColors.green : AppColors.error;

Color _statusColor(String status) => switch (status.toLowerCase()) {
  'active' => AppColors.green,
  'pending' => AppColors.warning,
  'stopped' || 'cancelled' || 'stopped_or_removed' => AppColors.error,
  _ => AppColors.textGrey,
};

String _formatDate(String iso) {
  if (iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  return dt == null ? iso : DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

class MyCopiesScreen extends StatefulWidget {
  const MyCopiesScreen({super.key});

  @override
  State<MyCopiesScreen> createState() => _MyCopiesScreenState();
}

class _MyCopiesScreenState extends State<MyCopiesScreen> {
  late final CopyTradingMasterCopiersController controller;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(CopyTradingMasterCopiersController());
    _searchController.addListener(() {
      final query = _searchController.text;
      if (controller.searchQuery.value != query) {
        controller.searchQuery.value = query;
        controller.currentPage.value = 1;
        controller.load(showLoading: false);
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (controller.hasMore &&
            !controller.isLoadingMore.value &&
            !controller.isLoading.value) {
          controller.loadMore();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    Get.delete<CopyTradingMasterCopiersController>(force: true);
    super.dispose();
  }

  void _applyStatus(String value) {
    controller.statusFilter.value = value;
    controller.currentPage.value = 1;
    controller.load(showLoading: false);
  }

  void _applyPlan(int? planId) {
    controller.planFilter.value = planId;
    controller.currentPage.value = 1;
    controller.load(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('my_copies_screen_my_copiers'),
          style: AppTextStyles.screenTitle,
        ),
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
          ),
          onPressed: () => Get.offAllNamed(AppPages.TRADING),
        ),
        actions: [
          IconButton(
            onPressed: () => controller.load(showLoading: true),
            icon: Icon(Icons.refresh, size: 20.r, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: RefreshIndicator(
            onRefresh: () => controller.load(showLoading: false),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryHero(controller: controller),
                        SizedBox(height: 10.h),
                        _StatusFilterBar(
                          controller: controller,
                          onSelected: _applyStatus,
                        ),
                        SizedBox(height: 8.h),
                        _SearchAndPlanRow(
                          controller: controller,
                          searchController: _searchController,
                          onPlanChanged: _applyPlan,
                        ),
                      ],
                    ),
                  ),
                ),
                _CopierListSliver(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  final CopyTradingMasterCopiersController controller;
  const _SummaryHero({required this.controller});

  @override
  Widget build(BuildContext context) {
    final onColor = AppColors.onColoredBackground;
    return Obx(() {
      final pnl = controller.summaryTotalPnl.value;
      final isUp = pnl >= 0;
      return Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.78),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.tr('copy_trading_combined_pnl_upper'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: onColor.withValues(alpha: 0.8),
              ),
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _money(pnl),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        color: onColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: onColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(
                    isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 14.r,
                    color: onColor,
                  ),
                ),
              ],
            ),
            Text(
              TranslationUtils.tr('copy_trading_lifetime_copier_pnl'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 10.sp,
                color: onColor.withValues(alpha: 0.75),
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
              decoration: BoxDecoration(
                color: onColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _HeroStat(
                        label: TranslationUtils.tr('copy_trading_total_copiers_upper'),
                        value: controller.activeCopiersCount.toString(),
                      ),
                      _HeroDivider(color: onColor),
                      _HeroStat(
                        label: TranslationUtils.tr('copy_trading_capital_allocated_upper'),
                        value: _money(controller.summaryTotalCapital.value),
                      ),
                      _HeroDivider(color: onColor),
                      _HeroStat(
                        label: TranslationUtils.tr('copy_trading_commission_paid_to_you_upper'),
                        value: _money(controller.summaryTotalCommissionPaid.value),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: onColor.withValues(alpha: 0.18),
                    ),
                  ),
                  Row(
                    children: [
                      _HeroStat(
                        label: TranslationUtils.tr('copy_trading_floating_commission_upper'),
                        value: _money(controller.summaryTotalFloatingCommission.value),
                      ),
                      _HeroDivider(color: onColor),
                      _HeroStat(
                        label: TranslationUtils.tr('copy_trading_commission_earned_upper'),
                        value: _money(controller.summaryTotalCommissionEarned.value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final onColor = AppColors.onColoredBackground;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: onColor,
                ),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 8.5.sp,
                fontWeight: FontWeight.w600,
                color: onColor.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  final Color color;
  const _HeroDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30.h,
      color: color.withValues(alpha: 0.25),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final CopyTradingMasterCopiersController controller;
  final ValueChanged<String> onSelected;
  const _StatusFilterBar({required this.controller, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.statusFilter.value;
      final tabs = <(String, String, int)>[
        (TranslationUtils.tr('common_all'), 'all', controller.summaryTotal.value),
        (TranslationUtils.tr('wallet_active'), 'active', controller.summaryActive.value),
        (TranslationUtils.tr('transaction_history_pending'), 'pending', controller.summaryPending.value),
        (TranslationUtils.tr('copy_trading_paused'), 'paused', controller.summaryPaused.value),
        (TranslationUtils.tr('copy_trading_stopped_removed'), 'stopped', controller.summaryStoppedOrRemoved.value),
      ];
      return SizedBox(
        height: 34.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tabs.length,
          separatorBuilder: (_, _) => SizedBox(width: 8.w),
          itemBuilder: (context, index) {
            final (label, value, count) = tabs[index];
            return _StatusChipButton(
              label: label,
              count: count,
              selected: active == value,
              onTap: () => onSelected(value),
            );
          },
        ),
      );
    });
  }
}

class _StatusChipButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChipButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onColoredBackground : AppColors.textPrimary;
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 11.5.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: fg,
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.onColoredBackground.withValues(alpha: 0.22)
                      : AppColors.tradeBackgroundCenterColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  count.toString(),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    color: selected ? fg : AppColors.textGrey,
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

class _SearchAndPlanRow extends StatelessWidget {
  final CopyTradingMasterCopiersController controller;
  final TextEditingController searchController;
  final ValueChanged<int?> onPlanChanged;
  const _SearchAndPlanRow({
    required this.controller,
    required this.searchController,
    required this.onPlanChanged,
  });

  BoxDecoration get _fieldDecoration => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(10.r),
    border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
  );

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyles.bodyText.copyWith(
      fontSize: 12.sp,
      color: AppColors.textPrimary,
    );
    final hintStyle = textStyle.copyWith(color: AppColors.textGrey);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42.h,
            decoration: _fieldDecoration,
            child: TextField(
              controller: searchController,
              style: textStyle,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: TranslationUtils.tr('my_copies_screen_search_copier'),
                hintStyle: hintStyle,
                prefixIcon: Icon(Icons.search, size: 18.r, color: AppColors.textGrey),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: Obx(() {
            final plans = controller.masterPlans;
            return Container(
              height: 42.h,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: _fieldDecoration,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: controller.planFilter.value,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(10.r),
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.filter_list_rounded, size: 16.r, color: AppColors.textGrey),
                  hint: Text(
                    TranslationUtils.tr('my_copies_screen_all_plans'),
                    style: hintStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: textStyle.copyWith(fontWeight: FontWeight.w600),
                  onChanged: onPlanChanged,
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        TranslationUtils.tr('my_copies_screen_all_plans'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...plans.map(
                      (p) => DropdownMenuItem<int?>(
                        value: p.id,
                        child: Text(p.planName, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CopierListSliver extends StatelessWidget {
  final CopyTradingMasterCopiersController controller;
  const _CopierListSliver({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final copiers = controller.copiers;
      final err = controller.errorMessage.value;

      if (controller.isLoading.value && copiers.isEmpty) {
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 24.h),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, _) => SizedBox(height: 8.h),
            itemBuilder: (_, _) => const _CopierCardShimmer(),
          ),
        );
      }

      if (err.isNotEmpty && copiers.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _StateMessage(
            icon: Icons.error_outline_rounded,
            iconColor: AppColors.error,
            message: err,
            onRetry: () => controller.load(showLoading: true),
          ),
        );
      }

      if (copiers.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _StateMessage(
            icon: Icons.group_off_outlined,
            iconColor: AppColors.textGrey,
            message: TranslationUtils.tr('my_copies_screen_no_copiers_found_matching_filters'),
          ),
        );
      }

      final showLoader = controller.isLoadingMore.value;
      // Bottom inset clears the floating copy-trading nav pill, which
      // overlays page content (FAB slot in CopyTradingMainScreen).
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 120.h),
        sliver: SliverList.separated(
          itemCount: copiers.length + (showLoader ? 1 : 0),
          separatorBuilder: (_, _) => SizedBox(height: 8.h),
          itemBuilder: (context, index) {
            if (index == copiers.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Center(
                  child: SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }
            return _CopierCard(
              key: ValueKey(copiers[index].id),
              item: copiers[index],
              controller: controller,
            );
          },
        ),
      );
    });
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final VoidCallback? onRetry;
  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32.r, color: iconColor),
          ),
          SizedBox(height: 14.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              color: AppColors.textGrey,
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(TranslationUtils.tr('common_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.onColoredBackground,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CopierCard extends StatelessWidget {
  final MasterCopierItem item;
  final CopyTradingMasterCopiersController controller;

  const _CopierCard({super.key, required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    // The copiers API sends no net_pnl, so Net P&L is the copier's P&L
    // after the estimated (pending, not yet settled) commission.
    final netPnl = item.totalPnl - item.pendingCommission;
    final subtitle = [item.planName, item.accountNumber]
        .where((s) => s.isNotEmpty)
        .join('  •  ');

    return _ExpandableCard(
      headerBuilder: (expanded) => Padding(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 6.w, 10.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                _initials(item.userName),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      _StatusPill(
                        status: item.status,
                        color: _statusColor(item.status),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 10.5.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(item.totalPnl),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _pnlColor(item.totalPnl),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  TranslationUtils.tr('my_copies_card_pnl'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 9.5.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22.r,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
      // Name, status, plan, account and P&L are already in the header, so
      // the body only carries the remaining fields.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.12)),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MoneyStrip(
                  tiles: [
                    _MoneyTile(
                      label: TranslationUtils.tr('my_copies_card_capital'),
                      value: _money(item.capitalAmount),
                    ),
                    _MoneyTile(
                      label: TranslationUtils.tr('my_copies_card_estimated_commission'),
                      value: _money(item.pendingCommission),
                    ),
                    _MoneyTile(
                      label: TranslationUtils.tr('my_copies_card_net_pnl'),
                      value: _money(netPnl),
                      color: _pnlColor(netPnl),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                _InfoGrid(
                  cells: [
                    _InfoCell(
                      label: TranslationUtils.tr('my_copies_card_commission_rate'),
                      value: item.commissionDisplay,
                    ),
                    _InfoCell(
                      label: TranslationUtils.tr('my_copies_card_open'),
                      value: item.openTradesCount.toString(),
                    ),
                    _InfoCell(
                      label: TranslationUtils.tr('my_copies_card_method'),
                      value: _methodLabel(item),
                    ),
                    _InfoCell(
                      label: TranslationUtils.tr('my_copies_card_last_update'),
                      value: _formatDate(item.updatedAt),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _CardActionButton(
                  icon: Icons.history_rounded,
                  label: TranslationUtils.tr('general_history'),
                  color: AppColors.primary,
                  onPressed: () => Get.to(
                    () => CopierSubscriptionHistoryScreen(copierId: item.id),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card that shows only [headerBuilder] until tapped, then reveals [body].
class _ExpandableCard extends StatefulWidget {
  final Widget Function(bool expanded) headerBuilder;
  final Widget body;
  const _ExpandableCard({required this.headerBuilder, required this.body});

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: widget.headerBuilder(_expanded),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded ? widget.body : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.r,
            height: 6.r,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 5.w),
          Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small upper-case caption used above every value in the expanded card.
Text _caption(String text) => Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 9.5.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.textGrey,
      ),
    );

/// "multiplier_only" + lot_multiplier 3 → "Multiplier Only · 3x".
String _methodLabel(MasterCopierItem item) {
  final name = item.sizingMethod
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  final usesMultiplier = item.sizingMethod.contains('multiplier');
  if (!usesMultiplier || item.lotMultiplier <= 0) return name;
  return '$name · ${item.lotMultiplier}x';
}

/// Capital, estimated commission and net P&L shown as one tinted strip.
class _MoneyStrip extends StatelessWidget {
  final List<_MoneyTile> tiles;
  const _MoneyStrip({required this.tiles});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children.add(Container(
          width: 1,
          height: 28.h,
          color: AppColors.border.withValues(alpha: 0.18),
        ));
      }
      children.add(Expanded(child: tiles[i]));
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(children: children),
    );
  }
}

class _MoneyTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MoneyTile({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 9.5.sp,
              height: 1.2,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column grid of caption/value pairs for the remaining card details.
class _InfoGrid extends StatelessWidget {
  final List<_InfoCell> cells;
  const _InfoGrid({required this.cells});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 10.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[i]),
            SizedBox(width: 12.w),
            Expanded(
              child: i + 1 < cells.length ? cells[i + 1] : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
    }
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(children: rows),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption(label),
        SizedBox(height: 3.h),
        Text(
          value.isEmpty ? '-' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _CardActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16.r, color: fg),
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: fg,
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

class _CopierCardShimmer extends StatelessWidget {
  const _CopierCardShimmer();

  @override
  Widget build(BuildContext context) {
    final block = AppColors.card;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(6.r),
      ),
    );

    return Shimmer.fromColors(
      baseColor: AppColors.border.withValues(alpha: 0.12),
      highlightColor: AppColors.card,
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: block,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 20.r, backgroundColor: block),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(120.w, 12.h), SizedBox(height: 6.h), bar(160.w, 10.h)],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            bar(double.infinity, 54.h),
            SizedBox(height: 12.h),
            bar(double.infinity, 34.h),
            SizedBox(height: 12.h),
            bar(double.infinity, 38.h),
          ],
        ),
      ),
    );
  }
}
