import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_copier_subscriptions_controller.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_details_controller.dart';
import 'subscribe_to_plan_screen.dart';
import 'package:crm_app/widgets/AppTextField.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/dashBorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// SVG action icons (tinted with [AppColors.primary] via [ColorFilter]).
class _MyCopiesSvg {
  _MyCopiesSvg._();
  static const add = 'assets/svg/copy_trading/my_copies/ct_add.svg';
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
  late final CopyTradingCopierSubscriptionsController controller;
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
    controller = Get.put(CopyTradingCopierSubscriptionsController(), tag: 'copytrading:my_copies');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    Get.delete<CopyTradingCopierSubscriptionsController>(tag: 'copytrading:my_copies', force: true);
    super.dispose();
  }

  List<CopierSubscriptionItem> _filtered(List<CopierSubscriptionItem> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final status = _statusFilter.value;
    return all.where((s) {
      final statusOk = status == 'all' ? true : s.status.toLowerCase() == status;
      if (!statusOk) return false;
      if (q.isEmpty) return true;
      return s.masterName.toLowerCase().contains(q) ||
          s.masterCode.toLowerCase().contains(q) ||
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
        leading: AppSvgBackButton(
          onPressed: () => AppSvgBackButton.popRoute(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.load(showLoading: false),
        child: Obx(() {
          final loading = controller.isLoading.value;
          final err = controller.errorMessage.value;
          final list = controller.subscriptions.toList();
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
                    CustomToastService.showError(message: err, title: 'Error');
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

              _SummaryCard(items: filtered),
              SizedBox(height: 12.h),

              if (filtered.isEmpty)
                _EmptyState(
                  title: 'No copies found',
                  subtitle: list.isEmpty
                      ? 'Explore masters and subscribe to start copy trading.'
                      : 'Try changing search or filter.',
                )
              else
                ...filtered.map((s) => _SubscriptionCard(
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
                            masterCode: s.masterCode,
                            plan: plan,
                            editSubscription: s,
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
                              title: const Text('Stop copy?'),
                              content: const Text('This is permanent. You can’t re-activate; you must re-subscribe.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Stop')),
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
                      onAddCapital: () async {
                        final amountCtrl = TextEditingController();
                        final amount = await showDialog<num?>(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text('Add capital'),
                              content: TextField(
                                controller: amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(hintText: 'Amount (USD)'),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    final v = num.tryParse(amountCtrl.text.trim());
                                    Navigator.of(ctx).pop(v);
                                  },
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        );
                        if (amount == null || amount <= 0) {
                          _toastError('Enter a valid amount');
                          return;
                        }
                        final res = await controller.addCapital(subscriptionId: s.id, amount: amount);
                        if (!res.success) {
                          _toastError(res.message ?? 'Failed to add capital');
                        } else {
                          _toastSuccess(res.message ?? 'Capital added');
                        }
                      },
                    )),

              if (loading) ...[
                SizedBox(height: 12.h),
                Center(
                  child: SizedBox(
                    width: 18.r,
                    height: 18.r,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              ],
            ],
          );
        }),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: AppTextField(
        controller: controller,
        onChanged: onChanged,
        prefixIcon: Icon(Icons.search, color: AppColors.textGrey),
        hintText: 'Search master / plan / account',
        suffixIcon: controller.text.isEmpty ? null : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: Icon(Icons.close, size: 18.r, color: AppColors.textGrey),
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
        _FilterChip(label: 'All', value: 'all', selected: selected, onChanged: onChanged),
        _FilterChip(label: 'Active', value: 'active', selected: selected, onChanged: onChanged),
        _FilterChip(label: 'Paused', value: 'paused', selected: selected, onChanged: onChanged),
        _FilterChip(label: 'Stopped', value: 'stopped', selected: selected, onChanged: onChanged),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onChanged});

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
          border: Border.all(color: isOn ? AppColors.primary : AppColors.textGrey.withOpacity(0.2)),
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
  final List<CopierSubscriptionItem> items;
  const _SummaryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final active = items.where((e) => e.isActive).length;
    final capital = items.fold<num>(0, (p, e) => p + e.capitalAmount);
    final pnl = items.fold<num>(0, (p, e) => p + e.totalPnl);
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.textGrey.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Expanded(child: _Metric(label: 'Active', value: '$active')),
          Expanded(child: _Metric(label: 'Capital', value: '\$${capital.toStringAsFixed(2)}')),
          Expanded(
            child: _Metric(
              label: 'P&L',
              value: '\$${pnl.toStringAsFixed(2)}',
              valueColor: pnl >= 0 ? AppColors.green : AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Metric({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        SizedBox(height: 4.h),
        Text(value, style: AppTextStyles.black16600.copyWith(color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}

class _SubscriptionCard extends StatefulWidget {
  final CopierSubscriptionItem item;
  final RxBool actionLoading;
  final Future<void> Function() onEdit;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onStop;
  final Future<void> Function() onAddCapital;

  const _SubscriptionCard({
    required this.item,
    required this.actionLoading,
    required this.onEdit,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onAddCapital,
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
    return t.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = item.status.toLowerCase();
    final Color pillColor = switch (status) {
      'active' => AppColors.primary,
      'paused' => AppColors.warning,
      'stopped' => AppColors.error,
      _ => AppColors.textGrey,
    };
    final title = (item.masterName.isNotEmpty ? item.masterName : item.masterCode).toUpperCase();

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.textGrey.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.card,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 10.w, 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTextStyles.black16600.copyWith(fontWeight: FontWeight.w600)),
                          SizedBox(height: 4.h),
                          Text(
                            item.planName.isNotEmpty ? item.planName : 'Plan ${item.planId}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(
                      text: status.isEmpty ? 'Unknown' : _formatStatus(status),
                      color: pillColor,
                      outline: status == 'active',
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 24.r,
                      color: AppColors.textGrey,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Column(
                          children: [
                            _DottedStatRow(label: 'Account', value: item.accountNumber),
                            _DottedStatRow(label: 'Capital', value: '\$${item.capitalAmount.toStringAsFixed(2)}'),
                            _DottedStatRow(label: 'Open trades', value: item.openTrades.toString()),
                            _DottedStatRow(
                              label: 'P&L',
                              value: '\$${item.totalPnl.toStringAsFixed(2)}',
                              valueColor: item.totalPnl >= 0 ? AppColors.green : AppColors.red,
                            ),
                            _DottedStatRow(label: 'Commission', value: '\$${item.totalCommissionPaid.toStringAsFixed(2)}'),
                            _DottedStatRow(label: 'Method', value: _formatCopyMethod(item.copyMethod)),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Padding(
                        // padding: EdgeInsets.zero,
                        padding: EdgeInsets.fromLTRB(0.w, 0, 0.w, 14.h),
                        child: Obx(() {
                          final busy = widget.actionLoading.value;
                          final canPause = status == 'active';
                          final canResume = status == 'paused';
                          final canStop = status == 'active' || status == 'paused';
                          final canEdit = canPause || canResume;
                          return Row(
                            children: [
                              _SubscriptionActionSvg(
                                asset: _MyCopiesSvg.add,
                                tooltip: 'Add capital',
                                enabled: !busy,
                                onTap: widget.onAddCapital,
                              ),
                              _SubscriptionActionSvg(
                                asset: _MyCopiesSvg.edit,
                                tooltip: 'Edit copy settings',
                                enabled: !busy && canEdit,
                                onTap: widget.onEdit,
                              ),
                              if (canPause)
                                _SubscriptionActionSvg(
                                  asset: _MyCopiesSvg.pause,
                                  tooltip: 'Pause copying',
                                  enabled: !busy,
                                  onTap: widget.onPause,
                                )
                              else if (canResume)
                                _SubscriptionActionSvg(
                                  asset: _MyCopiesSvg.play,
                                  tooltip: 'Resume copying',
                                  enabled: !busy,
                                  onTap: widget.onResume,
                                )
                              else
                                _SubscriptionActionSvg(
                                  asset: _MyCopiesSvg.pause,
                                  tooltip: 'Pause',
                                  enabled: false,
                                  onTap: () async {},
                                ),
                              _SubscriptionActionSvg(
                                asset: _MyCopiesSvg.target,
                                tooltip: 'Stop copy',
                                enabled: !busy && canStop,
                                onTap: widget.onStop,
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

class _DottedStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DottedStatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textGrey)),
          SizedBox(width: 8.w),
          Flexible(
            child: DashedUnderline(
              color: AppColors.dashLineColor,
              dashSpace: 3,
              dashWidth: 3,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppTextStyles.black14600.copyWith(color: valueColor ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionActionSvg extends StatelessWidget {
  /// Design: outer box 32×32, inner padding 6, icon 20×20 (logical px via [.r]).
  final String asset;
  final String tooltip;
  final bool enabled;
  final Future<void> Function() onTap;

  const _SubscriptionActionSvg({
    required this.asset,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = enabled ? AppColors.primary : AppColors.textGrey.withOpacity(0.45);
    final Color bg = AppColors.primary.withOpacity(0.10);
    final box = 32.r;
    final pad = 7.r;
    final icon = 22.r;

    return Expanded(
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Tooltip(
            message: tooltip,
            waitDuration: const Duration(milliseconds: 400),
            child: SizedBox(
              width: box,
              height: box,
              child: Material(
                color: bg,
                borderRadius: BorderRadius.circular(8.r),
                child: InkWell(
                  onTap: enabled ? () => onTap() : null,
                  borderRadius: BorderRadius.circular(8.r),
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: SvgPicture.asset(
                      asset,
                      width: icon,
                      height: icon,
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
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
  const _StatusPill({required this.text, required this.color, this.outline = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: outline ? color.withOpacity(0.55) : color.withOpacity(0.25)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: color)),
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
          Expanded(child: Text(message, style: AppTextStyles.caption.copyWith(color: AppColors.error))),
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

