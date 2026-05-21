import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_copiers_controller.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_details_controller.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/hub/subscribe_to_plan_screen.dart';
import 'package:crm_app/widgets/AppTextField.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/app_back_button.dart';

/// SVG action icons (tinted with [AppColors.primary] via [ColorFilter]).
class _MyCopiesSvg {
  _MyCopiesSvg._();
  static const edit = 'assets/svg/copy_trading/my_copies/ct_edit.svg';
  static const pause = 'assets/svg/copy_trading/my_copies/ct_pause.svg';
  static const play = 'assets/svg/copy_trading/my_copies/ct_play.svg';
  static const target = 'assets/svg/copy_trading/my_copies/ct_target.svg';
}

class MyCopiesScreen extends StatefulWidget {
  const MyCopiesScreen({super.key});

  @override
  State<MyCopiesScreen> createState() => _MyCopiesScreenState();
}

class _MyCopiesScreenState extends State<MyCopiesScreen> {
  late final CopyTradingMasterCopiersController controller;
  final _searchCtrl = TextEditingController();
  final _statusFilter = 'all'.obs; // all | active | paused | stopped

  void _toastError(String message) {
    final msg = message.trim();
    if (msg.isEmpty) return;
    CustomToastService.showError(
      title: 'Error',
      message: msg,
      duration: const Duration(milliseconds: 2500),
      position: SnackPosition.TOP,
    );
  }

  void _toastSuccess(String message) {
    final msg = message.trim();
    if (msg.isEmpty) return;
    CustomToastService.showSuccess(
      title: 'Success',
      message: msg,
      duration: const Duration(milliseconds: 2500),
      position: SnackPosition.TOP,
    );
  }

  @override
  void initState() {
    super.initState();
    controller = Get.put(CopyTradingMasterCopiersController());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    Get.delete<CopyTradingMasterCopiersController>(force: true);
    super.dispose();
  }

  List<MasterCopierItem> _filtered(List<MasterCopierItem> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final status = _statusFilter.value;
    return all.where((s) {
      final statusOk =
          status == 'all' ? true : s.status.toLowerCase() == status;
      if (!statusOk) return false;
      if (q.isEmpty) return true;
      return s.userName.toLowerCase().contains(q) ||
          s.planName.toLowerCase().contains(q) ||
          s.accountNumber.toLowerCase().contains(q);
    }).toList();
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
        title: Text('My Copies', style: AppTextStyles.screenTitle),
        leading: const AppBackButton(),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.load(showLoading: false),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              final metrics = notification.metrics;
              if (metrics.pixels >= metrics.maxScrollExtent - 200 &&
                  controller.hasMore &&
                  !controller.isLoadingMore.value &&
                  !controller.isLoading.value) {
                controller.loadMore();
              }
            }
            return false;
          },
          child: Obx(() {
            final loading = controller.isLoading.value;
            final err = controller.errorMessage.value;
            final list = controller.copiers.toList();
            final filtered = _filtered(list);

            if (loading && list.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
              children: [
                if (err.isNotEmpty)
                  _InlineError(
                    message: err,
                    onRetry: () {
                      CustomToastService.showError(
                        message: err,
                        title: 'Error',
                      );
                      controller.load(showLoading: true);
                    },
                  ),
                if (err.isNotEmpty) SizedBox(height: 12.h),

                _SearchBox(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 12.h),

                Obx(() {
                  return _FilterRow(
                    selected: _statusFilter.value,
                    onChanged: (v) => _statusFilter.value = v,
                  );
                }),
                SizedBox(height: 12.h),

                _SummaryCard(controller: controller),
                SizedBox(height: 12.h),

                if (filtered.isEmpty)
                  _EmptyState(
                    title: 'No copies found',
                    subtitle:
                        list.isEmpty
                            ? 'Explore masters and subscribe to start copy trading.'
                            : 'Try changing search or filter.',
                  )
                else
                  ...filtered.map(
                    (s) => _SubscriptionCard(
                      item: s,
                      actionLoading: controller.actionLoading,
                      onEdit: () async {
                        final plan = CopyTradingPlan(
                          id: s.planId,
                          planId: s.planId,
                          planName: s.planName,
                          commissionType: 'per_trade',
                          commissionLabel: '',
                          commissionPercentage: 0,
                          subscriptionFee: 0,
                          minimumCapital: 0,
                          copyRatio: s.copyRatio,
                          isFull: false,
                          noFeeDays: 0,
                          subscriptionPeriodDays: 0,
                          activeCopiersCount: 0,
                          totalAum: 0,
                          isEnrolled: false,
                        );
                        await Get.to(
                          () => SubscribeToPlanScreen(
                            masterCode: '',
                            plan: plan,
                            editSubscription: null,
                          ),
                        );
                      },
                      onPause: () async {
                        final res = await controller.pause(s.id);
                        if (!res.success) {
                          _toastError(res.message ?? 'Failed to pause');
                        } else {
                          _toastSuccess(res.message ?? 'Paused');
                        }
                      },
                      onResume: () async {
                        final res = await controller.resume(s.id);
                        if (!res.success) {
                          _toastError(res.message ?? 'Failed to resume');
                        } else {
                          _toastSuccess(res.message ?? 'Resumed');
                        }
                      },
                      onStop: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              backgroundColor: AppColors.card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              title: Text(
                                'Stop copy?',
                                style: AppTextStyles.headingblack,
                              ),
                              content: Text(
                                'This is permanent. You can’t re-activate; you must re-subscribe.',
                                style: AppTextStyles.subheading.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 14.sp,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(
                                    'Stop',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                        if (confirmed != true) return;
                        final res = await controller.stop(s.id);
                        if (!res.success) {
                          _toastError(res.message ?? 'Failed to stop');
                        } else {
                          _toastSuccess(res.message ?? 'Stopped');
                        }
                      },
                    ),
                  ),

                if (loading) ...[
                  SizedBox(height: 12.h),
                  Center(
                    child: SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],

                Obx(() {
                  if (!controller.isLoadingMore.value)
                    return const SizedBox.shrink();
                  return Column(
                    children: [
                      SizedBox(height: 16.h),
                      Center(
                        child: SizedBox(
                          width: 24.r,
                          height: 24.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Center(
                        child: Text(
                          'Loading more...',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],
                  );
                }),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBox({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      // padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.textGrey.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AppTextField(
        controller: controller,
        onChanged: onChanged,
        prefixIcon: Icon(Icons.search, color: AppColors.textGrey),
        hintText: 'Search master / plan / account',
        suffixIcon:
            controller.text.isEmpty
                ? null
                : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: Icon(
                    Icons.close,
                    size: 18.r,
                    color: AppColors.textGrey,
                  ),
                ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        _FilterChip(
          label: 'All',
          value: 'all',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Active',
          value: 'active',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Paused',
          value: 'paused',
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Stopped',
          value: 'stopped',
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = selected == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isOn ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                isOn ? AppColors.primary : AppColors.textGrey.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isOn ? AppColors.whiteColor : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CopyTradingMasterCopiersController controller;
  const _SummaryCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.summaryActive.value;
      final capital = controller.summaryTotalCapital.value;
      final pnl = controller.summaryTotalPnl.value;
      final commission = controller.summaryTotalCommissionPaid.value;
      final total = controller.summaryTotal.value;
      final pending = controller.summaryPending.value;
      final paused = controller.summaryPaused.value;
      final stopped = controller.summaryStopped.value;

      return Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.groups_outlined,
                    size: 16.r,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'My Copiers',
                  style: AppTextStyles.labelOnChartPendingOrderBold,
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '$total total',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Status chips row
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                _StatusChip(
                  label: 'Active',
                  count: active,
                  color: AppColors.green,
                ),
                _StatusChip(
                  label: 'Pending',
                  count: pending,
                  color: AppColors.warning,
                ),
                _StatusChip(
                  label: 'Paused',
                  count: paused,
                  color: AppColors.textGrey,
                ),
                _StatusChip(
                  label: 'Stopped',
                  count: stopped,
                  color: AppColors.error,
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Metrics row
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: 'Total Capital',
                      value: '\$${capital.toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36.h,
                    color: AppColors.textGrey.withValues(alpha: 0.12),
                  ),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Total P&L',
                      value: '\$${pnl.toStringAsFixed(2)}',
                      icon: Icons.trending_up,
                      valueColor: pnl >= 0 ? AppColors.green : AppColors.error,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36.h,
                    color: AppColors.textGrey.withValues(alpha: 0.12),
                  ),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Commission',
                      value: '\$${commission.toStringAsFixed(2)}',
                      icon: Icons.payments_outlined,
                    ),
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

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.r,
            height: 6.r,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 4.w),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          Icon(icon, size: 13.r, color: AppColors.textGrey),
          SizedBox(height: 3.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatefulWidget {
  final MasterCopierItem item;
  final RxBool actionLoading;
  final Future<void> Function() onEdit;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onStop;

  const _SubscriptionCard({
    required this.item,
    required this.actionLoading,
    required this.onEdit,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  State<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<_SubscriptionCard> {
  bool _expanded = false;

  static String _formatStatus(String s) {
    if (s.isEmpty) return 'Unknown';
    return '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
  }

  static String _formatCopyMethod(String m) {
    if (m.isEmpty) return '-';
    final t = m.replaceAll('_', ' ').trim();
    return t
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  static String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = item.status.toLowerCase();

    final Color statusColor = switch (status) {
      'active' => AppColors.green,
      'paused' => AppColors.warning,
      'stopped' => AppColors.error,
      _ => AppColors.textGrey,
    };

    final displayName =
        item.userName.isNotEmpty ? item.userName : 'Copier #${item.userId}';
    final planDisplayName =
        item.planName.isNotEmpty ? item.planName : 'Plan #${item.planId}';

    final bool canPause = status == 'active';
    final bool canResume = status == 'paused';
    final bool canStop = status == 'active' || status == 'paused';
    final bool canEdit = canPause || canResume;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.textGrey.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── HEADER: Avatar + Name + Plan badges + Status ─────────────────────
          Material(
            color: AppColors.card,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: EdgeInsets.fromLTRB(14.w, 14.h, 10.w, 12.h),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 46.r,
                      height: 46.r,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(displayName),
                          style: TextStyle(
                            color: AppColors.onColoredBackground,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Name + Plan badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: AppTextStyles.black16600.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 7.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  planDisplayName,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.serverType.isNotEmpty) ...[
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 7.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.textGrey.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    item.serverType.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status badge
                    _StatusPill(
                      text: _formatStatus(status),
                      color: statusColor,
                      outline: status == 'active',
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 22.r,
                      color: AppColors.textGrey,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── QUICK STATS (always visible, NOT inside expanded) ──────────────────
          Container(
            margin: EdgeInsets.fromLTRB(14.w, 0, 14.w, 0),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.tradeBackgroundCenterColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _QuickStat(
                    label: 'Capital',
                    value: '\$${item.capitalAmount.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28.h,
                  color: AppColors.textGrey.withOpacity(0.15),
                ),
                Expanded(
                  child: _QuickStat(
                    label: 'P&L',
                    value: '\$${item.totalPnl.toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                    valueColor:
                        item.totalPnl >= 0 ? AppColors.green : AppColors.error,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28.h,
                  color: AppColors.textGrey.withOpacity(0.15),
                ),
                Expanded(
                  child: _QuickStat(
                    label: 'Commission',
                    value: '\$${item.totalCommissionPaid.toStringAsFixed(2)}',
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),

          // ── EXPANDED SECTION ────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child:
                _expanded
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Details Grid (2 columns) ──────────────────────────────
                        Padding(
                          padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT COLUMN
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _GridLabel(
                                      label: 'Account',
                                      value: item.accountNumber,
                                    ),
                                    _GridLabel(
                                      label: 'Plan Status',
                                      value:
                                          item.planStatus.isNotEmpty
                                              ? _formatStatus(item.planStatus)
                                              : '-',
                                    ),
                                    _GridLabel(
                                      label: 'Copy Method',
                                      value: _formatCopyMethod(item.copyMethod),
                                    ),
                                    if (item.sizingMethod.isNotEmpty)
                                      _GridLabel(
                                        label: 'Sizing',
                                        value: _formatCopyMethod(
                                          item.sizingMethod,
                                        ),
                                      ),
                                    _GridLabel(
                                      label: 'Open Trades',
                                      value:
                                          item.openTradesCount > 0
                                              ? '${item.openTradesCount}'
                                              : 'None',
                                      valueColor:
                                          item.openTradesCount > 0
                                              ? AppColors.warning
                                              : AppColors.textGrey,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16.w),
                              // RIGHT COLUMN
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _GridLabel(
                                      label: 'Active Since',
                                      value: item.formattedActiveSince,
                                      valueColor: AppColors.primary,
                                    ),
                                    if (item.lotMultiplier > 0)
                                      _GridLabel(
                                        label: 'Lot Multiplier',
                                        value: '${item.lotMultiplier}x',
                                      ),
                                    if (item.takeProfit.isNotEmpty)
                                      _GridLabel(
                                        label: 'Take Profit',
                                        value: item.takeProfit,
                                      ),
                                    if (item.stopLoss.isNotEmpty)
                                      _GridLabel(
                                        label: 'Stop Loss',
                                        value: item.stopLoss,
                                      ),
                                    _GridLabel(
                                      label: 'Commission',
                                      value: item.commissionDisplay,
                                      valueColor: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // ── ACTION BUTTONS ────────────────────────────────────────
                        Padding(
                          padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                          child: Obx(() {
                            final busy = widget.actionLoading.value;
                            return Column(
                              children: [
                                _ActionButton(
                                  icon: _MyCopiesSvg.edit,
                                  label: 'Edit Settings',
                                  color: AppColors.textGrey,
                                  enabled: !busy && canEdit,
                                  onTap: widget.onEdit,
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  children: [
                                    if (canPause)
                                      Expanded(
                                        child: _ActionButton(
                                          icon: _MyCopiesSvg.pause,
                                          label: 'Pause',
                                          color: AppColors.warning,
                                          enabled: !busy,
                                          onTap: widget.onPause,
                                        ),
                                      )
                                    else if (canResume)
                                      Expanded(
                                        child: _ActionButton(
                                          icon: _MyCopiesSvg.play,
                                          label: 'Resume',
                                          color: AppColors.green,
                                          enabled: !busy,
                                          onTap: widget.onResume,
                                        ),
                                      )
                                    else
                                      const Expanded(child: SizedBox.shrink()),
                                    if (canStop) ...[
                                      if (canPause || canResume)
                                        SizedBox(width: 8.w),
                                      Expanded(
                                        child: _ActionButton(
                                          icon: _MyCopiesSvg.target,
                                          label: 'Stop Copy',
                                          color: AppColors.error,
                                          enabled: !busy,
                                          onTap: widget.onStop,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14.r, color: AppColors.textGrey),
          SizedBox(width: 5.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _GridLabel({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final bool enabled;
  final Future<void> Function() onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        enabled ? color : AppColors.textGrey.withOpacity(0.4);
    return Material(
      color: effectiveColor.withOpacity(enabled ? 0.1 : 0.05),
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: enabled ? () => onTap() : null,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                icon,
                width: 18.r,
                height: 18.r,
                colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
              ),
              SizedBox(width: 7.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  /// When true (e.g. Active): outlined badge with primary-style border, no fill.
  final bool outline;
  const _StatusPill({
    required this.text,
    required this.color,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: outline ? color.withOpacity(0.55) : color.withOpacity(0.25),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.textGrey.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.black16600),
          SizedBox(height: 6.h),
          Text(subtitle, style: AppTextStyles.cardSubtitle),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.error.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 18.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text('Retry', style: AppTextStyles.textButton),
          ),
        ],
      ),
    );
  }
}
