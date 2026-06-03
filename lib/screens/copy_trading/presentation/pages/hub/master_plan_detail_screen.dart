import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_plan_detail_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class MasterPlanDetailScreen extends StatelessWidget {
  final int planId;
  const MasterPlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      CopyTradingMasterPlanDetailController(planId: planId),
      tag: 'planDetail:$planId',
    );

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text('Plan Details', style: AppTextStyles.heading),
        leading: const AppBackButton(),
      ),
      body: GetBuilder<CopyTradingMasterPlanDetailController>(
        tag: 'planDetail:$planId',
        builder: (_) {
          final c = controller;
          if (c.isLoading.value && c.detail.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (c.errorMessage.value.isNotEmpty && c.detail.value == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 40.r, color: AppColors.error),
                    SizedBox(height: 10.h),
                    Text(c.errorMessage.value, textAlign: TextAlign.center, style: AppTextStyles.error),
                    SizedBox(height: 12.h),
                    ElevatedButton(
                      onPressed: () => c.loadPlanDetail(showLoading: true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: Text('Retry', style: AppTextStyles.button),
                    ),
                  ],
                ),
              ),
            );
          }

          final d = c.detail.value;
          if (d == null) {
            return Center(
              child: Text('No detail found', style: AppTextStyles.caption),
            );
          }

          final status = d.status.toLowerCase();
          final statusColor = status == 'approved'
              ? AppColors.statusGreen
              : status.contains('inactive')
                  ? AppColors.statusGrey
                  : status.contains('pending')
                      ? AppColors.statusYellow
                      : AppColors.statusRed;

          return DefaultTabController(
            length: 2,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
                      child: Container(
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: AppColors.whiteColor,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: Colors.grey.withOpacity(0.15)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d.planName.isNotEmpty ? d.planName : 'Plan ${d.id}',
                                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    d.status,
                                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            _DetailRow(
                              label: 'Commission',
                              value: d.commissionLabel.isNotEmpty
                                  ? d.commissionLabel
                                  : (d.commissionType.isNotEmpty ? '${d.commissionType} (${d.commissionPercentage}%)' : '—'),
                            ),
                            _DetailRow(label: 'Subscription Fee', value: '\$${d.subscriptionFee.toStringAsFixed(2)}'),
                            _DetailRow(label: 'Period (days)', value: d.subscriptionPeriodDays.toString()),
                            _DetailRow(label: 'No-fee days', value: d.noFeeDays.toString()),
                            _DetailRow(label: 'Min capital', value: '\$${d.minimumCapital.toStringAsFixed(2)}'),
                            _DetailRow(label: 'Copy ratio', value: d.copyRatio.toString()),
                            _DetailRow(label: 'Active copiers', value: d.activeCopiers.toString()),
                            _DetailRow(label: 'Open positions', value: d.openPositions.toString()),
                            _DetailRow(label: 'Total capital', value: '\$${d.totalCapital.toStringAsFixed(2)}'),
                            _DetailRow(label: 'Commission earned', value: '\$${d.totalCommissionEarned.toStringAsFixed(2)}'),
                            SizedBox(height: 6.h),
                            Text(
                              'TP/SL (pips)',
                              style: AppTextStyles.cardSubtitle.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              children: [
                                Expanded(child: _DetailRow(label: 'Take Profit', value: d.takeProfitPips.toString())),
                                SizedBox(width: 12.w),
                                Expanded(child: _DetailRow(label: 'Stop Loss', value: d.stopLossPips.toString())),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list, size: 18.r, color: AppColors.textGrey),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              'Trade & Commission History',
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabHeaderDelegate(
                      height: 48.h,
                      child: Container(
                        color: AppColors.tradeBackgroundCenterColor,
                        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
                        child: Container(
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(
                            color: AppColors.whiteColor,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.grey.withOpacity(0.12)),
                          ),
                          child: TabBar(
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            labelPadding: EdgeInsets.zero,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textGrey,
                            labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                            unselectedLabelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Trades'),
                              Tab(text: 'Commissions'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h),
                child: TabBarView(
                  children: [
                    _TradesTab(trades: d.tradeHistory),
                    _CommissionsTab(commissions: d.commissionHistory),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}

class _TradesTab extends StatefulWidget {
  final List<CopyTradingMasterTradeHistoryItem> trades;
  const _TradesTab({required this.trades});

  @override
  State<_TradesTab> createState() => _TradesTabState();
}

class _TradesTabState extends State<_TradesTab> {
  String? _symbol;
  String? _direction; // buy/sell
  String? _copierKey; // "account|name"

  @override
  Widget build(BuildContext context) {
    final symbols = _uniqueSorted(widget.trades.map((e) => e.symbol).where((s) => s.trim().isNotEmpty));
    final copiers = _uniqueSorted(
      widget.trades.map((e) => '${e.copierAccount}|${e.copierName}').where((s) => s.trim().isNotEmpty),
    );

    final filtered = widget.trades.where((t) {
      if (_symbol != null && t.symbol != _symbol) return false;
      if (_direction != null && t.direction.toLowerCase() != _direction) return false;
      if (_copierKey != null && '${t.copierAccount}|${t.copierName}' != _copierKey) return false;
      return true;
    }).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _FilterRow(
          symbolValue: _symbol,
          directionValue: _direction,
          copierValue: _copierKey,
          symbols: symbols,
          directions: const ['buy', 'sell'],
          copiers: copiers,
          copierLabelBuilder: (key) {
            final parts = key.split('|');
            final acc = (parts.isNotEmpty ? parts[0] : '').trim();
            final name = (parts.length > 1 ? parts[1] : '').trim();
            if (name.isEmpty) return acc.isNotEmpty ? acc : 'Copier';
            return acc.isNotEmpty ? '$acc ($name)' : name;
          },
          onChanged: (s, d, c) => setState(() {
            _symbol = s;
            _direction = d;
            _copierKey = c;
          }),
        ),
        SizedBox(height: 10.h),
        if (filtered.isEmpty) _EmptyCard(message: 'No trades found') else ...filtered.map((t) => _TradeHistoryCard(item: t)),
      ],
    );
  }
}

class _CommissionsTab extends StatefulWidget {
  final List<CopyTradingMasterCommissionHistoryItem> commissions;
  const _CommissionsTab({required this.commissions});

  @override
  State<_CommissionsTab> createState() => _CommissionsTabState();
}

class _CommissionsTabState extends State<_CommissionsTab> {
  String? _symbol;
  String? _copierKey; // "account|name"

  @override
  Widget build(BuildContext context) {
    final symbols = _uniqueSorted(widget.commissions.map((e) => e.symbol).where((s) => s.trim().isNotEmpty));
    final copiers = _uniqueSorted(
      widget.commissions.map((e) => '${e.copierAccount}|${e.copierName}').where((s) => s.trim().isNotEmpty),
    );

    final filtered = widget.commissions.where((x) {
      if (_symbol != null && x.symbol != _symbol) return false;
      if (_copierKey != null && '${x.copierAccount}|${x.copierName}' != _copierKey) return false;
      return true;
    }).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _FilterRow(
          symbolValue: _symbol,
          directionValue: null,
          copierValue: _copierKey,
          symbols: symbols,
          directions: const [],
          copiers: copiers,
          copierLabelBuilder: (key) {
            final parts = key.split('|');
            final acc = (parts.isNotEmpty ? parts[0] : '').trim();
            final name = (parts.length > 1 ? parts[1] : '').trim();
            if (name.isEmpty) return acc.isNotEmpty ? acc : 'Copier';
            return acc.isNotEmpty ? '$acc ($name)' : name;
          },
          onChanged: (s, d, c) => setState(() {
            _symbol = s;
            _copierKey = c;
          }),
        ),
        SizedBox(height: 10.h),
        if (filtered.isEmpty)
          _EmptyCard(message: 'No commissions found')
        else
          ...filtered.map((x) => _CommissionHistoryCard(item: x)),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String? symbolValue;
  final String? directionValue;
  final String? copierValue;
  final List<String> symbols;
  final List<String> directions;
  final List<String> copiers;
  final String Function(String key) copierLabelBuilder;
  final void Function(String? symbol, String? direction, String? copier) onChanged;

  const _FilterRow({
    required this.symbolValue,
    required this.directionValue,
    required this.copierValue,
    required this.symbols,
    required this.directions,
    required this.copiers,
    required this.copierLabelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DropdownFilter(
            title: 'All Symbols',
            value: symbolValue,
            items: symbols,
            itemLabelBuilder: (s) => s,
            onChanged: (v) => onChanged(v, directionValue, copierValue),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: directions.isEmpty
              ? _DropdownFilter(
                  title: 'All Directions',
                  value: null,
                  items: const [],
                  itemLabelBuilder: (s) => s,
                  enabled: false,
                  onChanged: (_) {},
                )
              : _DropdownFilter(
                  title: 'All Directions',
                  value: directionValue,
                  items: directions,
                  itemLabelBuilder: (s) => s.toUpperCase(),
                  onChanged: (v) => onChanged(symbolValue, v, copierValue),
                ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _DropdownFilter(
            title: 'All Copiers',
            value: copierValue,
            items: copiers,
            itemLabelBuilder: copierLabelBuilder,
            onChanged: (v) => onChanged(symbolValue, directionValue, v),
          ),
        ),
      ],
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String title;
  final String? value;
  final List<String> items;
  final String Function(String v) itemLabelBuilder;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _DropdownFilter({
    required this.title,
    required this.value,
    required this.items,
    required this.itemLabelBuilder,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final display = value == null ? title : itemLabelBuilder(value!);
    return PopupMenuButton<String?>(
      enabled: enabled,
      tooltip: title,
      onSelected: onChanged,
      itemBuilder: (context) {
        final list = <PopupMenuEntry<String?>>[
          PopupMenuItem<String?>(
            value: null,
            child: Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        ];
        for (final it in items) {
          list.add(
            PopupMenuItem<String?>(
              value: it,
              child: Text(itemLabelBuilder(it), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ),
          );
        }
        return list;
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: enabled ? AppColors.whiteColor : AppColors.whiteColor.withOpacity(0.65),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.textPrimary : AppColors.textGrey,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Icon(Icons.keyboard_arrow_down, size: 18.r, color: enabled ? AppColors.textGrey : AppColors.textGrey.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _TabHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

List<String> _uniqueSorted(Iterable<String> values) {
  final set = <String>{};
  for (final v in values) {
    final s = v.trim();
    if (s.isNotEmpty) set.add(s);
  }
  final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

class _TradeHistoryCard extends StatefulWidget {
  final CopyTradingMasterTradeHistoryItem item;
  const _TradeHistoryCard({required this.item});

  @override
  State<_TradeHistoryCard> createState() => _TradeHistoryCardState();
}

class _TradeHistoryCardState extends State<_TradeHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.item;
    final dir = t.direction.toLowerCase();
    final isBuy = dir == 'buy';
    final profit = t.masterProfit.toDouble();
    final profitColor = profit >= 0 ? AppColors.statusGreenDark : AppColors.statusRed;
    final status = t.status.isNotEmpty ? t.status : '—';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Container(
                //   padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                //   decoration: BoxDecoration(
                //     color: (isBuy ? AppColors.statusGreen : AppColors.statusRed).withOpacity(0.12),
                //     borderRadius: BorderRadius.circular(10.r),
                //   ),
                //   child: Text(
                //     isBuy ? 'BUY' : 'SELL',
                //     style: TextStyle(
                //       fontSize: 11.sp,
                //       fontWeight: FontWeight.w800,
                //       color: isBuy ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                //       letterSpacing: 0.2,
                //     ),
                //   ),
                // ),
                // SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            t.symbol,
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          SizedBox(width: 10.w),
                          Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: (isBuy ? AppColors.statusGreen : AppColors.statusRed).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    isBuy ? 'BUY' : 'SELL',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: isBuy ? AppColors.statusGreenDark : AppColors.statusRed,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '${t.copierName.isNotEmpty ? t.copierName : 'Copier'}  •  ${t.copierAccount.isNotEmpty ? t.copierAccount : '—'}',
                        style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '\$${profit.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: profitColor),
                    ),
                  ],
                ),
                SizedBox(width: 6.w),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20.r,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            if (_expanded) ...[
              SizedBox(height: 12.h),
              Divider(color: Colors.grey.withOpacity(0.12), height: 1),
              SizedBox(height: 12.h),
              _KVRow(label: 'Trade ID', value: '#${t.id}'),
              _KVRow(label: 'Open time', value: _formatTime(t.openTime)),
              if (t.closeTime.trim().isNotEmpty) _KVRow(label: 'Close time', value: _formatTime(t.closeTime)),
              _KVRow(label: 'Open price', value: t.openPrice.toString()),
              if (t.closePrice != 0) _KVRow(label: 'Close price', value: t.closePrice.toString()),
              _KVRow(label: 'Master vol', value: t.masterVolume.toString()),
              _KVRow(label: 'Copier vol', value: t.copierVolume.toString()),
              _KVRow(label: 'Copier P&L', value: '\$${t.copierProfit.toDouble().toStringAsFixed(2)}'),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _CommissionHistoryCard extends StatefulWidget {
  final CopyTradingMasterCommissionHistoryItem item;
  const _CommissionHistoryCard({required this.item});

  @override
  State<_CommissionHistoryCard> createState() => _CommissionHistoryCardState();
}

class _CommissionHistoryCardState extends State<_CommissionHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final x = widget.item;
    final credited = x.masterCommissionCredited.toDouble();
    final creditedColor = credited >= 0 ? AppColors.statusGreenDark : AppColors.statusRed;
    final inGrace = x.inGracePeriod;
    final pillColor = inGrace ? AppColors.statusYellow : AppColors.statusGreen;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Container(
                //   padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                //   decoration: BoxDecoration(
                //     color: pillColor.withOpacity(0.12),
                //     borderRadius: BorderRadius.circular(10.r),
                //   ),
                //   child: Text(
                //     inGrace ? 'GRACE' : 'SETTLED',
                //     style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: pillColor),
                //   ),
                // ),
                // SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            x.symbol,
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          SizedBox(width: 10.w),
                            Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: pillColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    inGrace ? 'GRACE' : 'SETTLED',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: pillColor),
                  ),
                ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '${x.copierName.isNotEmpty ? x.copierName : 'Copier'}  •  ${x.copierAccount.isNotEmpty ? x.copierAccount : '—'}',
                        style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${credited.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: creditedColor),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _formatTime(x.settledAt),
                      style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                SizedBox(width: 6.w),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20.r,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            if (_expanded) ...[
              SizedBox(height: 12.h),
              Divider(color: Colors.grey.withOpacity(0.12), height: 1),
              SizedBox(height: 12.h),
              _KVRow(label: 'Commission ID', value: '#${x.id}'),
              _KVRow(label: 'Status', value: x.status.isNotEmpty ? x.status : '—'),
              _KVRow(label: 'Gross profit share', value: '\$${x.grossProfitShare.toDouble().toStringAsFixed(2)}'),
              _KVRow(label: 'Commission charged', value: '\$${x.commissionCharged.toDouble().toStringAsFixed(2)}'),
              _KVRow(label: 'Master credited', value: '\$${x.masterCommissionCredited.toDouble().toStringAsFixed(2)}'),
              _KVRow(label: 'Grace period', value: x.inGracePeriod ? 'Yes' : 'No'),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  const _KVRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textGrey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.black14500,
            ),
          ),
        ],
      ),
    );
  }
}

