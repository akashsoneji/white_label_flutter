import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/models/demo_contest/demo_contest_enrollment_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Prize claim for an ended contest (`POST demo-contest/claim`).
class ClaimPrizeCard extends StatefulWidget {
  final String contestId;
  final Color cardBg;
  final VoidCallback onClaimed;

  const ClaimPrizeCard({
    super.key,
    required this.contestId,
    required this.cardBg,
    required this.onClaimed,
  });

  @override
  State<ClaimPrizeCard> createState() => _ClaimPrizeCardState();
}

class _ClaimPrizeCardState extends State<ClaimPrizeCard> {
  bool _submitting = false;

  Future<void> _claim() async {
    final accountController = TextEditingController();
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(TranslationUtils.tr('dc_claim')),
        content: TextField(
          controller: accountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: TranslationUtils.tr('dc_real_account_number_optional'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(TranslationUtils.tr('general_cancel')),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(TranslationUtils.tr('dc_claim')),
          ),
        ],
      ),
    );
    final realAccount = accountController.text.trim();
    accountController.dispose();
    if (confirmed != true) return;

    setState(() => _submitting = true);
    final controller = Get.find<DemoContestController>();
    final message = await controller.claimPrize(
      widget.contestId,
      realAccountNumber: realAccount,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (message == null) {
      CustomToastService.showError(message: controller.errorMessage.value);
      return;
    }
    CustomToastService.showSuccess(
      message: message.isNotEmpty
          ? message
          : TranslationUtils.tr('dc_claim_submitted'),
    );
    widget.onClaimed();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, color: AppColors.primary, size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              TranslationUtils.tr('dc_claim_prize_hint'),
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: _submitting ? null : _claim,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(TranslationUtils.tr('dc_claim')),
          ),
        ],
      ),
    );
  }
}

/// Contest account activity: `trading-history` and `rule-violations`.
class ContestActivityCard extends StatefulWidget {
  final String contestId;
  final Color cardBg;

  const ContestActivityCard({
    super.key,
    required this.contestId,
    required this.cardBg,
  });

  @override
  State<ContestActivityCard> createState() => _ContestActivityCardState();
}

class _ContestActivityCardState extends State<ContestActivityCard> {
  final _controller = Get.find<DemoContestController>();
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<DemoContestTrade> _trades = const [];
  DemoContestRuleViolations? _violations;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _controller.fetchTradingHistory(widget.contestId),
        _controller.fetchRuleViolations(widget.contestId),
      ]);
      if (!mounted) return;
      setState(() {
        _trades = results[0] as List<DemoContestTrade>;
        _violations = results[1] as DemoContestRuleViolations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _tabChip(0, TranslationUtils.tr('dc_trading_history')),
              SizedBox(width: 8.w),
              _tabChip(
                1,
                '${TranslationUtils.tr('dc_rule_violations')}'
                '${(_violations?.violationCount ?? 0) > 0 ? ' (${_violations!.violationCount})' : ''}',
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_error != null)
            _message(_error!)
          else if (_tab == 0)
            ..._buildTrades()
          else
            ..._buildViolations(),
        ],
      ),
    );
  }

  Widget _tabChip(int index, String label) {
    final selected = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.icongrey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textGrey,
            fontSize: 12.sp,
          ),
        ),
      );

  List<Widget> _buildTrades() {
    if (_trades.isEmpty) {
      return [_message(TranslationUtils.tr('dc_no_trades_yet'))];
    }
    return [
      for (final t in _trades)
        _row(
          title: '${t.symbol} · ${t.type} · ${_fmt(t.lots)}',
          subtitle: t.isOpen
              ? '${t.openTime} · ${TranslationUtils.tr('dc_open')}'
              : '${t.openTime} → ${t.closeTime}',
          trailing: _fmt(t.profit),
          trailingColor: t.profit >= 0
              ? const Color(0xFF16A34A)
              : const Color(0xFFDC2626),
        ),
    ];
  }

  List<Widget> _buildViolations() {
    final v = _violations;
    if (v == null || v.violations.isEmpty) {
      return [_message(TranslationUtils.tr('dc_no_rule_violations'))];
    }
    return [
      Text(
        '${TranslationUtils.tr('dc_compliance_rate')}: ${_fmt(v.complianceRate)}% '
        '(${v.compliantTrades}/${v.totalTrades})',
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.textGrey,
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(height: 8.h),
      for (final trade in v.violations)
        _row(
          title: '${trade.symbol} · #${trade.tradeId}',
          subtitle: trade.messages.join('\n'),
          trailing: _fmt(trade.profit),
          trailingColor: const Color(0xFFDC2626),
        ),
    ];
  }

  Widget _row({
    required String title,
    required String subtitle,
    required String trailing,
    required Color trailingColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.icongrey.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textGrey,
                    fontSize: 10.5.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            trailing,
            style: AppTextStyles.bodyText.copyWith(
              color: trailingColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(2);
}
