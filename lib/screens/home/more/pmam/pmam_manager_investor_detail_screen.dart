import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/pmam_manager_investor_detail_model.dart';
import 'package:crm_app/services/pmam_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
        TextStyle(
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
        TextStyle(
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
    TextAlign align = TextAlign.left,
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
                  style: TextStyle(
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
                label: 'Lot',
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
                  label: 'Open Price',
                  value: openPriceText,
                  valueColor: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _richLabelValue(
                  context,
                  label: 'Open Time',
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
                  style: TextStyle(
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
                label: 'Net',
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
                  label: 'Gross',
                  value: _fmtMoney(d.grossProfitShare),
                  valueColor: grossColor,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _richLabelValue(
                  context,
                  label: 'Commission',
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
                  style: TextStyle(
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
                label: 'Type',
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
            label: 'Date',
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
          _error = resp.message ?? 'Failed to load investor details';
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
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
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
        style: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
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
        title: Text(  'Investor: ${widget.investorName}', style: AppTextStyles.heading),
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
                          style: TextStyle(
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
                          child: const Text('Retry'),
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
                                    'Investment Summary',
                                    style: TextStyle(
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
                                          label: 'Invested',
                                          value: _fmtMoney(invested),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: _metricCard(
                                          label: 'P&L',
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
                                          label: 'Current Value',
                                          value: _fmtMoney(currentValue),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: _metricCard(
                                          label: 'Pool Share',
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
                                  labelStyle: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  unselectedLabelStyle: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  tabs: const [
                                    Tab(
                                      child: Center(
                                        child: Text(
                                          'Open\nAllocations',
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                    Tab(
                                      child: Center(
                                        child: Text(
                                          'Settlement\nHistory',
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                    Tab(
                                      child: Center(
                                        child: Text(
                                          'Fund\nEntries',
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
                              final items = _data?.openAllocations ?? const [];
                              if (items.isEmpty) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 18.w,
                                    vertical: 12.h,
                                  ),
                                  child: _emptyHint('No open positions.'),
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
                              final settlements = _data?.distributions ?? const [];
                              return ListView(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18.w,
                                  vertical: 12.h,
                                ),
                                children: [
                                  if (settlements.isEmpty)
                                    _emptyHint('No settlements yet.')
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
                              final funds = _data?.fundEntries ?? const [];
                              if (funds.isEmpty) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 18.w,
                                    vertical: 12.h,
                                  ),
                                  child: _emptyHint('No fund entries.'),
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

