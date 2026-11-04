import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/pmam/pmam_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

/// Manager side "Commissions": settled profit-share rows from
/// `GET pmam/manager/commissions`, paginated on scroll.
class PmamManagerCommissionsScreen extends StatefulWidget {
  const PmamManagerCommissionsScreen({super.key});

  @override
  State<PmamManagerCommissionsScreen> createState() =>
      _PmamManagerCommissionsScreenState();
}

class _PmamManagerCommissionsScreenState
    extends State<PmamManagerCommissionsScreen> {
  final PmamController _c = Get.find<PmamController>();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadManagerCommissions();
      _c.loadManagerPlans();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300) {
      _c.loadManagerCommissions(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('pmam_commissions_title'),
          style: AppTextStyles.screenTitle,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final rows = _c.commissions.toList();
          final loading = _c.isCommissionsLoading.value;

          if (loading && rows.isEmpty) {
            return const Center(child: CommonLoadingWidget(isFullScreen: false));
          }
          if (_c.commissionsError.value.isNotEmpty && rows.isEmpty) {
            return _CenteredMessage(
              icon: Icons.error_outline_rounded,
              message: _c.commissionsError.value,
              onRetry: _c.loadManagerCommissions,
            );
          }
          if (rows.isEmpty) {
            return _CenteredMessage(
              icon: Icons.payments_outlined,
              message: TranslationUtils.tr('pmam_commissions_empty'),
            );
          }

          final totalCommission = rows.fold<double>(
            0,
            (sum, r) => sum + _toDouble(r['commission_charged']),
          );
          final hasMore =
              _c.commissionsPage.value < _c.commissionsLastPage.value;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _c.loadManagerCommissions,
            child: ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsetsDirectional.fromSTEB(16.w, 8.h, 16.w, 12.h),
              itemCount: rows.length + 2,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SummaryCard(
                    total: _c.commissionsTotal.value,
                    loadedCommission: totalCommission,
                  );
                }
                if (index == rows.length + 1) {
                  return hasMore
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Center(
                            child: SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                }
                return _CommissionCard(row: rows[index - 1]);
              },
            ),
          );
        }),
      ),
    );
  }
}

double _toDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _money(dynamic value) => _toDouble(value).toStringAsFixed(2);

class _SummaryCard extends StatelessWidget {
  final int total;
  final double loadedCommission;

  const _SummaryCard({required this.total, required this.loadedCommission});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: TranslationUtils.tr('pmam_commissions_settlements'),
              value: '$total',
            ),
          ),
          Expanded(
            child: _Stat(
              label: TranslationUtils.tr('pmam_commissions_earned'),
              value: '\$${loadedCommission.toStringAsFixed(2)}',
              valueColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Stat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 11.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CommissionCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _CommissionCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final planName = (row['plan_name'] ?? '').toString();
    final investorName = (row['investor_name'] ?? '').toString();
    final settledAt = (row['settled_at'] ?? '').toString();
    final tradeId = (row['trade_id'] ?? '').toString();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '+\$${_money(row['commission_charged'])}',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            [
              if (investorName.isNotEmpty) investorName,
              if (tradeId.isNotEmpty) '#$tradeId',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 11.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: TranslationUtils.tr('pmam_commissions_gross_share'),
                  value: '\$${_money(row['gross_profit_share'])}',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: TranslationUtils.tr('pmam_commissions_net_credited'),
                  value: '\$${_money(row['net_profit_credited'])}',
                ),
              ),
            ],
          ),
          if (settledAt.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              settledAt,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 40.sp),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 12.h),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(TranslationUtils.tr('common_retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
