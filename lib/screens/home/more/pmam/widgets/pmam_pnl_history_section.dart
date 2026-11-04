import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Collapsible list of `GET investor/pnl-history` rows (doc 2.9): one line
/// per settled trade share with symbol, plan, date and gross / commission /
/// net amounts. Collapsed by default.
class PmamPnlHistorySection extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final bool isLoading;

  const PmamPnlHistorySection({
    super.key,
    required this.rows,
    this.isLoading = false,
  });

  static double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

  static String _signed(double v) =>
      '${v >= 0 ? '+' : '-'}\$${v.abs().toStringAsFixed(2)}';

  /// `settled_at` is ISO-8601; empty values come as `""` (doc 2.9).
  static String _date(dynamic v) {
    final dt = DateTime.tryParse('${v ?? ''}');
    if (dt == null) return '-';
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final net = rows.fold<double>(
      0,
      (sum, r) => sum + _num(r['net_profit_credited']),
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.primary,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        tilePadding: EdgeInsets.symmetric(horizontal: 12.w),
        title: Text(
          TranslationUtils.tr('pmam_pnl_history'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: rows.isEmpty
            ? null
            : Text(
                '${TranslationUtils.trArgs('pmam_pnl_entries_count', {'count': '${rows.length}'})}  •  ${_signed(net)}',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 11.sp,
                  color: net >= 0 ? AppColors.green : AppColors.error,
                ),
              ),
        children: [
          if (isLoading)
            Padding(
              padding: EdgeInsets.all(16.h),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 14.h),
              child: Text(
                TranslationUtils.tr('pmam_no_pnl_history'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 12.sp,
                  color: AppColors.textGrey,
                ),
              ),
            )
          else
            ...rows.map((r) => _PnlRow(row: r)),
          SizedBox(height: 6.h),
        ],
      ),
    );
  }
}

class _PnlRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _PnlRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final alloc = row['trade_allocation'] is Map
        ? row['trade_allocation'] as Map
        : const {};
    final plan = row['plan'] is Map ? row['plan'] as Map : const {};
    final symbol = '${alloc['trade_symbol'] ?? ''}'.trim();
    final planName = '${plan['plan_name'] ?? ''}'.trim();
    final gross = PmamPnlHistorySection._num(row['gross_profit_share']);
    final commission = PmamPnlHistorySection._num(row['commission_charged']);
    final net = PmamPnlHistorySection._num(row['net_profit_credited']);
    final muted = AppTextStyles.bodyText.copyWith(
      fontSize: 10.sp,
      color: AppColors.textGrey,
    );

    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol.isEmpty ? '#${row['trade_id'] ?? '-'}' : symbol,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  [
                    if (planName.isNotEmpty) planName,
                    PmamPnlHistorySection._date(row['settled_at']),
                  ].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                Text(
                  '${TranslationUtils.tr('pmam_gross')}: ${PmamPnlHistorySection._signed(gross)}  •  ${TranslationUtils.tr('general_commission')}: \$${commission.abs().toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            PmamPnlHistorySection._signed(net),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: net >= 0 ? AppColors.green : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
