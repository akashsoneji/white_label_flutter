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

/// Investor detail for a PAMM master — `GET manager/investors/{id}/detail`
/// (doc 3.21). Same sections as the web drawer (summary, open trades,
/// payouts, fund entries), laid out for a phone.
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

  /// [silent] keeps the current content on screen during pull-to-refresh.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final resp = await PmamService.getManagerInvestorDetail(widget.investorId);
      if (!mounted) return;
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
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Settlements arrive newest first; group them under one date label so
  /// the date is not repeated on every row.
  List<Widget> _payoutGroups(List<PmamDistribution> items) {
    final groups = <String, List<PmamDistribution>>{};
    for (final d in items) {
      groups.putIfAbsent(_fmtDate(d.settledAt), () => []).add(d);
    }
    return [
      for (final group in groups.entries) ...[
        Padding(
          padding: EdgeInsets.only(left: 2.w, bottom: 6.h),
          child: Text(
            group.key,
            style: _ts(10.5, FontWeight.w700, AppColors.textGrey),
          ),
        ),
        _CardBox(
          child: Column(
            children: [
              for (var i = 0; i < group.value.length; i++)
                _PayoutTile(item: group.value[i], showDivider: i > 0),
            ],
          ),
        ),
        SizedBox(height: 8.h),
      ],
    ];
  }

  Widget _content() {
    final data = _data;
    if (data == null) return const SizedBox.shrink();
    final openItems = data.openAllocations;
    final payouts = data.distributions;
    final funds = data.fundEntries;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
        children: [
          _SectionHeader(
            title: TranslationUtils.tr('master_plan_detail_screen_plan_details'),
          ),
          _SummaryCard(investor: data.investor),
          _SectionHeader(
            title: TranslationUtils.tr('dc_open'),
            count: openItems.length,
          ),
          if (openItems.isEmpty)
            _EmptyCard(text: TranslationUtils.tr('pmam_no_open_positions'))
          else
            _CardBox(
              child: Column(
                children: [
                  for (var i = 0; i < openItems.length; i++)
                    _OpenAllocationTile(item: openItems[i], showDivider: i > 0),
                ],
              ),
            ),
          _SectionHeader(
            title: TranslationUtils.tr('ibm_payouts'),
            count: payouts.length,
          ),
          if (payouts.isEmpty)
            _EmptyCard(text: TranslationUtils.tr('pmam_no_settlements_yet'))
          else
            ..._payoutGroups(payouts),
          _SectionHeader(
            title: TranslationUtils.tr('pmam_tab_fund_entries'),
            count: funds.length,
          ),
          if (funds.isEmpty)
            _EmptyCard(text: TranslationUtils.tr('pmam_no_fund_entries'))
          else
            _CardBox(
              child: Column(
                children: [
                  for (var i = 0; i < funds.length; i++)
                    _FundEntryTile(item: funds[i], showDivider: i > 0),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Padding(
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!, style: _ts(12.5, FontWeight.w600, AppColors.error)),
          SizedBox(height: 10.h),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _data?.investor.name ?? '';

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: SvgPicture.asset(
            'assets/svg/trade/arro_back.svg',
            colorFilter:
                ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
          ),
        ),
        title: Text(
          name.isNotEmpty ? name : widget.investorName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? Center(
                child: CommonLoadingWidget(size: 36, color: AppColors.primary),
              )
            : _error != null && _data == null
                ? _errorView()
                : _content(),
      ),
    );
  }
}

TextStyle _ts(double size, FontWeight weight, [Color? color]) {
  return AppTextStyles.bodyText.copyWith(
    fontSize: size.sp,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
  );
}

String _fmtMoney(double value) {
  final sign = value < 0 ? '-' : '';
  return '$sign\$${value.abs().toStringAsFixed(2)}';
}

String _fmtPct(double value) {
  final text = value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  return '${text.isEmpty ? '0' : text}%';
}

String _fmtDate(DateTime? dt) {
  if (dt == null) return '-';
  final local = dt.toLocal();
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
  return '${months[(local.month - 1).clamp(0, 11)]} ${local.day}, ${local.year}';
}

String _fmtTime(DateTime? dt) {
  if (dt == null) return '-';
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

Color _signedColor(double v) => v >= 0 ? AppColors.green : AppColors.error;

Widget _thinDivider() => Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border.withValues(alpha: 0.15),
    );

class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: child,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Text(text, style: _ts(12, FontWeight.w500, AppColors.textGrey)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 2.w, top: 12.h, bottom: 8.h),
      child: Row(
        children: [
          Text(title, style: _ts(13.5, FontWeight.w800)),
          if (count != null) ...[
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '$count',
                style: _ts(10.5, FontWeight.w700, AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.investor});

  final PmamInvestorSummary investor;

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.border.withValues(alpha: 0.15);

    Widget cell(String label, String value, [Color? color]) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(11, FontWeight.w500, AppColors.textGrey),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(15, FontWeight.w800, color ?? AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }

    Widget pair(Widget left, Widget right) {
      return IntrinsicHeight(
        child: Row(
          children: [
            left,
            VerticalDivider(width: 1, thickness: 1, color: dividerColor),
            right,
          ],
        ),
      );
    }

    return _CardBox(
      child: Column(
        children: [
          pair(
            cell(
              TranslationUtils.tr('pmam_invested'),
              _fmtMoney(investor.investedAmount),
            ),
            cell(
              TranslationUtils.tr('pmam_pnl'),
              _fmtMoney(investor.totalPnl),
              _signedColor(investor.totalPnl),
            ),
          ),
          _thinDivider(),
          pair(
            cell(
              TranslationUtils.tr('pmam_current_value'),
              _fmtMoney(investor.currentValue),
            ),
            cell(
              TranslationUtils.tr('pmam_pool_share'),
              _fmtPct(investor.allocationPct),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _ts(10.5, FontWeight.w500, AppColors.textGrey),
        ),
        SizedBox(height: 2.h),
        Text(value, style: _ts(12, FontWeight.w700, color)),
      ],
    );
  }
}

/// One settlement: trade and net amount up front; tap to see the
/// gross share and the commission behind it.
class _PayoutTile extends StatefulWidget {
  const _PayoutTile({required this.item, required this.showDivider});

  final PmamDistribution item;
  final bool showDivider;

  @override
  State<_PayoutTile> createState() => _PayoutTileState();
}

class _PayoutTileState extends State<_PayoutTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.item;
    final commissionColor =
        d.commissionCharged > 0 ? AppColors.error : AppColors.textGrey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDivider) _thinDivider(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.tradeId > 0 ? '#${d.tradeId}' : '-',
                            style: _ts(12.5, FontWeight.w700),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _fmtTime(d.settledAt),
                            style: _ts(10.5, FontWeight.w500, AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _fmtMoney(d.netProfitCredited),
                      style: _ts(
                        13,
                        FontWeight.w800,
                        _signedColor(d.netProfitCredited),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: _KeyValue(
                                  label: TranslationUtils.tr(
                                    'pmam_manager_dashboard_screen_total_aum',
                                  ),
                                  value: _fmtMoney(d.grossProfitShare),
                                  color: _signedColor(d.grossProfitShare),
                                ),
                              ),
                              Expanded(
                                child: _KeyValue(
                                  label: TranslationUtils.tr(
                                    'general_commission',
                                  ),
                                  value: _fmtMoney(d.commissionCharged),
                                  color: commissionColor,
                                ),
                              ),
                              Expanded(
                                child: _KeyValue(
                                  label: TranslationUtils.tr(
                                    'pmam_net_balance',
                                  ),
                                  value: _fmtMoney(d.netProfitCredited),
                                  color: _signedColor(d.netProfitCredited),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FundEntryTile extends StatelessWidget {
  const _FundEntryTile({required this.item, required this.showDivider});

  final PmamFundEntry item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final f = item;
    final type = f.type.trim().toLowerCase();
    final Color typeColor = switch (type) {
      'unsubscribe' => AppColors.error,
      'subscribe' => AppColors.green,
      _ => AppColors.primary,
    };
    final typeLabel = f.typeLabel.isNotEmpty ? f.typeLabel : f.type;
    final status = f.status.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider) _thinDivider(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  typeLabel.isEmpty ? '-' : typeLabel,
                  style: _ts(10.5, FontWeight.w700, typeColor),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtDate(f.entryTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(12, FontWeight.w600),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _fmtTime(f.entryTime),
                      style: _ts(10.5, FontWeight.w500, AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmtMoney(f.amount), style: _ts(13, FontWeight.w800)),
                  if (status.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: _ts(10.5, FontWeight.w500, AppColors.textGrey),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpenAllocationTile extends StatelessWidget {
  const _OpenAllocationTile({required this.item, required this.showDivider});

  final PmamOpenAllocation item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final a = item;
    final lotText = a.allocatedLot == 0
        ? '-'
        : a.allocatedLot.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    final openPriceText =
        a.openPrice == 0 ? '-' : a.openPrice.toStringAsFixed(5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider) _thinDivider(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.symbol.isEmpty ? '-' : a.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(12.5, FontWeight.w700),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${_fmtDate(a.openTime)}, ${_fmtTime(a.openTime)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(10.5, FontWeight.w500, AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${TranslationUtils.tr('scratch_card_screen_lot')} $lotText',
                    style: _ts(12, FontWeight.w700),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${TranslationUtils.tr('open_price')} $openPriceText',
                    style: _ts(10.5, FontWeight.w500, AppColors.textGrey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
