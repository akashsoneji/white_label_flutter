import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/pmam_manager_investor_detail_model.dart';
import 'package:crm_app/services/pmam_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/language_service.dart';

class PmamManagerInvestorDetailScreen extends StatefulWidget {
  final int investorId;
  final String investorName;

  const PmamManagerInvestorDetailScreen({
    super.key,
    required this.investorId,
    required this.investorName,
  });

  @override
  State<PmamManagerInvestorDetailScreen> createState() =>
      _PmamManagerInvestorDetailScreenState();
}

class _PmamManagerInvestorDetailScreenState
    extends State<PmamManagerInvestorDetailScreen> {
  bool _loading = true;
  String? _error;

  PmamManagerInvestorDetailResponse? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtMoney(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    return '\$${(n ?? 0).toStringAsFixed(2)}';
  }

  String _fmtPct(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    return '${(n ?? 0).toStringAsFixed(2)}%';
  }

  String _fmtDateLong(DateTime? dt) {
    if (dt == null) return '-';
    final months = [
      TranslationUtils.tr('month_short_jan'),
      TranslationUtils.tr('month_short_feb'),
      TranslationUtils.tr('month_short_mar'),
      TranslationUtils.tr('month_short_apr'),
      TranslationUtils.tr('month_short_may'),
      TranslationUtils.tr('month_short_jun'),
      TranslationUtils.tr('month_short_jul'),
      TranslationUtils.tr('month_short_aug'),
      TranslationUtils.tr('month_short_sep'),
      TranslationUtils.tr('month_short_oct'),
      TranslationUtils.tr('month_short_nov'),
      TranslationUtils.tr('month_short_dec'),
    ];
    final m = months[(dt.month - 1).clamp(0, 11)];
    return '$m ${dt.day}, ${dt.year}';
  }

  TextStyle _labelStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall?.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textGrey,
        ) ??
        AppTextStyles.bodyText.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textGrey,
        );
  }

  TextStyle _valueStyle(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall?.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textPrimary,
        ) ??
        AppTextStyles.bodyText.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textPrimary,
        );
  }

  Widget _richLabelValue(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    TextAlign align = TextAlign.start,
  }) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      textAlign: align,
      text: TextSpan(
        children: [
          TextSpan(text: '$label: ', style: _labelStyle(context)),
          TextSpan(text: value, style: _valueStyle(context, color: valueColor)),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12.r),
      boxShadow: [
        BoxShadow(
          color: AppColors.border.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _openAllocationCard(PmamOpenAllocation a) {
    final lotText = a.allocatedLot == 0
        ? '-'
        : a.allocatedLot
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'\.?0+$'), '');
    final openPriceText = a.openPrice == 0 ? '-' : a.openPrice.toStringAsFixed(5);
    final openTimeText = _fmtDateLong(a.openTime);

    return Container(
      decoration: _cardDecoration(),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: Symbol + Lot
          Row(
            children: [
              Expanded(
                child: Text(
                  a.symbol.isEmpty ? '-' : a.symbol,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              SizedBox(width: 10.w),
              _richLabelValue(
                context,
                label: TranslationUtils.tr('scratch_card_screen_lot'),
                value: lotText,
                valueColor: AppColors.textPrimary,
                align: TextAlign.right,
              ),
            ],
          ),

          SizedBox(height: 6.h),

          // Line 2: Open Price + Open Time
          Row(
            children: [
              Expanded(
                child: _richLabelValue(
                  context,
                  label: TranslationUtils.tr('open_price'),
                  value: openPriceText,
                  valueColor: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _richLabelValue(
                  context,
                  label: TranslationUtils.tr('open_time'),
                  value: openTimeText,
                  valueColor: AppColors.textPrimary,
                  align: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settlementCard(PmamDistribution d) {
    final net = d.netProfitCredited;
    final netColor = net >= 0 ? AppColors.green : AppColors.error;
    final grossColor =
        d.grossProfitShare >= 0 ? AppColors.green : AppColors.error;
    return Container(
      decoration: _cardDecoration(),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: Date + Net
          Row(
            children: [
              Expanded(
                child: Text(
                  _fmtDateLong(d.settledAt),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              SizedBox(width: 10.w),
              _richLabelValue(
                context,
                label: TranslationUtils.tr('pmam_net'),
                value: _fmtMoney(d.netProfitCredited),
                valueColor: netColor,
                align: TextAlign.right,
              ),
            ],
          ),

          SizedBox(height: 6.h),

          // Line 2: Gross + Commission
          Row(
            children: [
              Expanded(
                child: _richLabelValue(
                  context,
                  label: TranslationUtils.tr('pmam_gross'),
                  value: _fmtMoney(d.grossProfitShare),
                  valueColor: grossColor,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _richLabelValue(
                  context,
                  label: TranslationUtils.tr('general_commission'),
                  value: _fmtMoney(d.commissionCharged),
                  valueColor: d.commissionCharged > 0
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  align: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fundEntryCard(PmamFundEntry f) {
    final type = (f.typeLabel.isNotEmpty ? f.typeLabel : f.type).trim();
    return Container(
      decoration: _cardDecoration(),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: Amount + Type
          Row(
            children: [
              Expanded(
                child: Text(
                  _fmtMoney(f.amount),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              SizedBox(width: 10.w),
              _richLabelValue(
                context,
                label: TranslationUtils.tr('common_type'),
                value: type.isEmpty ? '-' : type,
                valueColor: AppColors.textPrimary,
                align: TextAlign.right,
              ),
            ],
          ),

          SizedBox(height: 6.h),

          // Line 2: Date
          _richLabelValue(
            context,
            label: TranslationUtils.tr('common_date'),
            value: _fmtDateLong(f.entryTime),
            valueColor: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await PmamService.getManagerInvestorDetail(widget.investorId);
      if (!resp.success || resp.data == null) {
        setState(() {
          _error =
              resp.message ??
              TranslationUtils.tr('pmam_failed_load_investor_details');
          _loading = false;
        });
        return;
      }

      setState(() {
        _data = PmamManagerInvestorDetailResponse.fromApi(resp.data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _metricCard({
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        text,
        style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textGrey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = _data?.investor;
    final invested = inv?.investedAmount ?? 0;
    final pnl = inv?.totalPnl ?? 0;
    final currentValue = inv?.currentValue ?? 0;
    final poolShare = inv?.allocationPct ?? 0;

    // P&L colors are applied inside cards where needed.

    return Scaffold(
      backgroundColor: AppColors.card,
       appBar:AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: SvgPicture.asset(
            'assets/svg/trade/arro_back.svg',
            colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
          ),
        ),
        title: Text(
            '${TranslationUtils.tr('pmam_investor_label')}: ${widget.investorName}',
            style: AppTextStyles.heading),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: CommonLoadingWidget(size: 36, color: AppColors.primary),
              )
            : _error != null
                ? Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        Text(
                          _error!,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 14.h),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            foregroundColor: AppColors.onColoredBackground,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: Text(TranslationUtils.tr('common_retry')),
                        ),
                      ],
                    ),
                  )
                : DefaultTabController(
                    length: 3,
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 12.h,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                 
                                  Text(
                                    TranslationUtils.tr(
                                        'pmam_investor_portal_screen_investment_summary'),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _metricCard(
                                          label: TranslationUtils.tr(
                                              'pmam_invested'),
                                          value: _fmtMoney(invested),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: _metricCard(
                                          label: TranslationUtils.tr('pmam_pnl'),
                                          value: _fmtMoney(pnl),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _metricCard(
                                          label: TranslationUtils.tr(
                                              'pmam_current_value'),
                                          value: _fmtMoney(currentValue),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: _metricCard(
                                          label: TranslationUtils.tr(
                                              'pmam_pool_share'),
                                          value: _fmtPct(poolShare),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 14.h),
                                ],
                              ),
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _TabBarHeaderDelegate(
                              height: kTextTabBarHeight,
                              child: Container(
                                height: kTextTabBarHeight,
                                color: AppColors.card,
                                padding: EdgeInsets.symmetric(horizontal: 18.w),
                                child: TabBar(
                                  isScrollable: false,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  labelColor: AppColors.primary,
                                  unselectedLabelColor: AppColors.textGrey,
                                  indicatorColor: AppColors.primary,
                                  // indicatorWeight: 2.5,
                                  labelStyle: AppTextStyles.bodyText.copyWith(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  unselectedLabelStyle: AppTextStyles.bodyText.copyWith(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  tabs: [
                                    Tab(
                                      child: Center(
                                        child: Text(
                                          TranslationUtils.tr(
                                              'pmam_tab_open_allocations'),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                    Tab(
                                      child: Center(
                                        child: Text(
                                          TranslationUtils.tr(
                                              'pmam_tab_settlement_history'),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                    Tab(
                                      child: Center(
                                        child: Text(
                                          TranslationUtils.tr(
                                              'pmam_tab_fund_entries'),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                      body: TabBarView(
                        children: [
                          Builder(
                            builder: (context) {
                              final items = _data?.openAllocations ?? [];
                              if (items.isEmpty) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 18.w,
                                    vertical: 12.h,
                                  ),
                                  child: _emptyHint(TranslationUtils.tr(
                                      'pmam_no_open_positions')),
                                );
                              }
                              return ListView.separated(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18.w,
                                  vertical: 12.h,
                                ),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                                itemBuilder: (_, i) => _openAllocationCard(items[i]),
                              );
                            },
                          ),
                          Builder(
                            builder: (context) {
                              final settlements = _data?.distributions ?? [];
                              return ListView(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18.w,
                                  vertical: 12.h,
                                ),
                                children: [
                                  if (settlements.isEmpty)
                                    _emptyHint(TranslationUtils.tr(
                                        'pmam_no_settlements_yet'))
                                  else
                                    ...List.generate(settlements.length, (i) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 10.h),
                                        child: _settlementCard(settlements[i]),
                                      );
                                    }),
                                  SizedBox(height: 12.h),
                                ],
                              );
                            },
                          ),
                          Builder(
                            builder: (context) {
                              final funds = _data?.fundEntries ?? [];
                              if (funds.isEmpty) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 18.w,
                                    vertical: 12.h,
                                  ),
                                  child: _emptyHint(TranslationUtils.tr(
                                      'pmam_no_fund_entries')),
                                );
                              }
                              return ListView.separated(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18.w,
                                  vertical: 12.h,
                                ),
                                itemCount: funds.length,
                                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                                itemBuilder: (_, i) => _fundEntryCard(funds[i]),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _TabBarHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

