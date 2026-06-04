import 'package:crm_app/constants/color.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_master_plan_detail_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

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
        leading: AppBackButton(
          onPressed: () => AppBackButton.popRoute(context),
          
          
        ),
      ),
      body: GetBuilder<CopyTradingMasterPlanDetailController>(
        tag: 'planDetail:$planId',
        builder: (_) {
          final c = controller;
          if (c.isLoading.value && c.detail.value == null) {
            return Center(child: CircularProgressIndicator());
          }

          if (c.errorMessage.value.isNotEmpty && c.detail.value == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 40.r,
                      color: AppColors.error,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      c.errorMessage.value,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.error,
                    ),
                    SizedBox(height: 12.h),
                    ElevatedButton(
                      onPressed: () => c.loadPlanDetail(showLoading: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
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
          final statusColor =
              (status == 'approved' || status == 'active')
                  ? AppColors.green
                  : status.contains('inactive')
                  ? AppColors.textGrey
                  : status.contains('pending')
                  ? AppColors.warning
                  : AppColors.error;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.planName.isNotEmpty
                                    ? d.planName
                                    : 'Plan ${d.id}',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Text(
                                d.status.toLowerCase() == 'pending_admin'
                                    ? 'Pending Review'
                                    : d.status,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14.h),

                        // Top metrics grid
                        _buildTopMetricsGrid(d),
                        SizedBox(height: 14.h),

                        // Commission & fees card
                        _DetailSectionCard(
                          title: 'Commission & fees',
                          children: [
                            _DetailRowWithDesc(
                              label: 'Commission',
                              value:
                                  d.commissionLabel.isNotEmpty
                                      ? d.commissionLabel
                                      : (d.commissionPercentage > 0
                                          ? '${d.commissionPercentage}% commission on profit'
                                          : 'No fee'),
                              desc: 'What copiers pay according to this plan.',
                            ),
                            _DetailRowWithDesc(
                              label: 'Commission type',
                              value:
                                  d.commissionType == 'per_trade'
                                      ? 'Per trade'
                                      : d.commissionType.capitalizeFirst ??
                                          d.commissionType,
                              desc: 'Per profitable trade vs subscription.',
                            ),
                            _DetailRowWithDesc(
                              label: 'Grace period (no fee)',
                              value: '${d.noFeeDays} days',
                              desc:
                                  'Days after join with no commission on trades.',
                            ),
                          ],
                        ),

                        // Copier rules card
                        _DetailSectionCard(
                          title: 'Copier rules',
                          children: [
                            _DetailRowWithDesc(
                              label: 'Min. capital',
                              value: '\$${d.minimumCapital.toStringAsFixed(2)}',
                              desc: 'Minimum balance to subscribe.',
                            ),
                            _DetailRowWithDesc(
                              label: 'Copy ratio',
                              value: d.copyRatio.toString(),
                              desc: 'Volume scaling for copiers.',
                            ),
                            _DetailRowWithDesc(
                              label: 'Max copiers',
                              value:
                                  d.maxCopiers > 0
                                      ? d.maxCopiers.toString()
                                      : 'Unlimited',
                              desc:
                                  'Cap on concurrent copiers (empty = unlimited).',
                            ),
                            _DetailRowWithDesc(
                              label: 'Active / cap',
                              value:
                                  '${d.activeCopiers} / ${d.maxCopiers > 0 ? d.maxCopiers.toString() : ''}',
                              desc: 'Current copiers vs limit.',
                            ),
                            _DetailRowWithDesc(
                              label: 'Plan full',
                              value: d.isFull ? 'Yes' : 'No',
                              desc: 'No new copiers until someone leaves.',
                            ),
                          ],
                        ),

                        // Strategy & risk disclosure card
                        _DetailSectionCard(
                          title: 'Strategy & risk disclosure',
                          children: [
                            _DisclosureRow(
                              title: 'Strategy description',
                              content:
                                  d.strategyDescription.trim().isNotEmpty
                                      ? d.strategyDescription
                                      : '— Not provided. Edit the plan to add a public description for copiers.',
                            ),
                            _DisclosureRow(
                              title: 'Risk information',
                              content:
                                  d.riskInformation.trim().isNotEmpty
                                      ? d.riskInformation
                                      : '— Not provided. Edit the plan to disclose drawdown and risk.',
                            ),
                          ],
                        ),

                        // Account & system card
                        _DetailSectionCard(
                          title: 'Account & system',
                          children: [
                            _DetailRowWithDesc(
                              label: 'Status',
                              value:
                                  d.status.toLowerCase() == 'pending_admin'
                                      ? 'Pending Review'
                                      : d.status,
                              desc: 'Broker / admin approval state.',
                            ),
                            _DetailRowWithDesc(
                              label: 'Server / LP',
                              value:
                                  d.lpProviderName.isNotEmpty
                                      ? d.lpProviderName
                                      : d.tradingServer,
                              desc: 'Execution routing label.',
                            ),
                            _DetailRowWithDesc(
                              label: 'Trading account',
                              value: d.tradingAccountNumber,
                              desc: 'Account number used for this plan.',
                            ),
                            _DetailRowWithDesc(
                              label: 'Initial equity snapshot',
                              value:
                                  '\$${d.initialEquitySnapshot.isNotEmpty ? double.tryParse(d.initialEquitySnapshot)?.toStringAsFixed(2) ?? d.initialEquitySnapshot : '0.00'}',
                              desc:
                                  'Captured when the plan was approved (if recorded).',
                            ),
                            _DetailRowWithDesc(
                              label: 'Created',
                              value: _formatDate(d.createdAt),
                              desc: 'Plan creation timestamp.',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 18.r,
                          color: AppColors.textGrey,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'Trade History',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h),
              child: _TradesTab(trades: d.tradeHistory),
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
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
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
  final TextEditingController _searchCtrl = TextEditingController();
  String _sort = 'newest'; // newest | oldest | profit_desc | profit_asc | volume_desc

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbols = _uniqueSorted(
      widget.trades.map((e) => e.symbol).where((s) => s.trim().isNotEmpty),
    );
    final copiers = _uniqueSorted(
      widget.trades
          .map((e) => '${e.copierAccount}|${e.copierName}')
          .where((s) => s.trim().isNotEmpty),
    );

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered =
        widget.trades.where((t) {
          if (_symbol != null && t.symbol != _symbol) return false;
          if (_direction != null && t.direction.toLowerCase() != _direction)
            return false;
          if (_copierKey != null &&
              '${t.copierAccount}|${t.copierName}' != _copierKey)
            return false;
          if (query.isNotEmpty) {
            final hay = '${t.symbol} ${t.direction} ${t.copierAccount} ${t.copierName} ${t.status}'.toLowerCase();
            if (!hay.contains(query)) return false;
          }
          return true;
        }).toList();

    int cmpByTime(CopyTradingMasterTradeHistoryItem a, CopyTradingMasterTradeHistoryItem b) {
      return a.openTime.compareTo(b.openTime);
    }
    switch (_sort) {
      case 'oldest':
        filtered.sort((a, b) => cmpByTime(a, b));
        break;
      case 'profit_desc':
        filtered.sort((a, b) => b.masterProfit.toDouble().compareTo(a.masterProfit.toDouble()));
        break;
      case 'profit_asc':
        filtered.sort((a, b) => a.masterProfit.toDouble().compareTo(b.masterProfit.toDouble()));
        break;
      case 'volume_desc':
        filtered.sort((a, b) => b.masterVolume.toDouble().compareTo(a.masterVolume.toDouble()));
        break;
      case 'newest':
      default:
        filtered.sort((a, b) => cmpByTime(b, a));
        break;
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Search bar
        Container(
          height: 42.h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18.r, color: AppColors.textGrey),
              SizedBox(width: 8.w),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Search symbol, copier, status…',
                    hintStyle: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
                  ),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                  child: Icon(Icons.close, size: 16.r, color: AppColors.textGrey),
                ),
            ],
          ),
        ),
        SizedBox(height: 10.h),

        // Sort row
        Row(
          children: [
            Icon(Icons.swap_vert, size: 16.r, color: AppColors.textGrey),
            SizedBox(width: 6.w),
            Text(
              'Sort:',
              style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _sortChip('newest', 'Newest'),
                    _sortChip('oldest', 'Oldest'),
                    _sortChip('profit_desc', 'Profit ↓'),
                    _sortChip('profit_asc', 'Profit ↑'),
                    _sortChip('volume_desc', 'Volume ↓'),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),

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
          onChanged:
              (s, d, c) => setState(() {
                _symbol = s;
                _direction = d;
                _copierKey = c;
              }),
        ),
        SizedBox(height: 10.h),
        if (filtered.isEmpty)
          _EmptyCard(message: 'No trades found')
        else
          ...filtered.map((t) => _TradeHistoryCard(item: t)),
      ],
    );
  }

  Widget _sortChip(String value, String label) {
    final selected = _sort == value;
    return Padding(
      padding: EdgeInsets.only(right: 6.w),
      child: GestureDetector(
        onTap: () => setState(() => _sort = value),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.whiteColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.textGrey,
            ),
          ),
        ),
      ),
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
  final void Function(String? symbol, String? direction, String? copier)
  onChanged;

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
          child:
              directions.isEmpty
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
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ];
        for (final it in items) {
          list.add(
            PopupMenuItem<String?>(
              value: it,
              child: Text(
                itemLabelBuilder(it),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          );
        }
        return list;
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color:
              enabled
                  ? AppColors.whiteColor
                  : AppColors.whiteColor.withOpacity(0.65),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.18)),
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
            Icon(
              Icons.keyboard_arrow_down,
              size: 18.r,
              color:
                  enabled
                      ? AppColors.textGrey
                      : AppColors.textGrey.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}


List<String> _uniqueSorted(Iterable<String> values) {
  final set = <String>{};
  for (final v in values) {
    final s = v.trim();
    if (s.isNotEmpty) set.add(s);
  }
  final list =
      set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
    final profitColor = profit >= 0 ? AppColors.green : AppColors.error;
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
          border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
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
                //     color: (isBuy ? AppColors.green : AppColors.error).withOpacity(0.12),
                //     borderRadius: BorderRadius.circular(10.r),
                //   ),
                //   child: Text(
                //     isBuy ? 'BUY' : 'SELL',
                //     style: TextStyle(
                //       fontSize: 11.sp,
                //       fontWeight: FontWeight.w800,
                //       color: isBuy ? AppColors.green : AppColors.error,
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
                              color: (isBuy ? AppColors.green : AppColors.error).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              isBuy ? 'BUY' : 'SELL',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                                color: isBuy ? AppColors.green : AppColors.error,
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
              Divider(color: AppColors.border.withValues(alpha: 0.12), height: 1),
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
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRowWithDesc extends StatelessWidget {
  final String label;
  final String value;
  final String? desc;

  const _DetailRowWithDesc({
    required this.label,
    required this.value,
    this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (desc != null && desc!.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              desc!,
              style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
            ),
          ],
          SizedBox(height: 4.h),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  final String title;
  final String content;

  const _DisclosureRow({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textGrey,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.sp,
              color:
                  content.startsWith('—')
                      ? AppColors.textGrey
                      : AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          SizedBox(height: 6.h),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}

Widget _buildTopMetricsGrid(dynamic d) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              'ACTIVE COPIERS',
              d.activeCopiers.toString(),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _buildMetricCard(
              'PLAN EQUITY (AUM)',
              '\$${d.totalCapital.toStringAsFixed(2)}',
            ),
          ),
        ],
      ),
      SizedBox(height: 10.h),
      Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              'COMMISSION EARNED',
              '\$${d.totalCommissionEarned.toStringAsFixed(2)}',
              valueColor: AppColors.green,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _buildMetricCard(
              'OPEN POSITIONS',
              d.openPositions.toString(),
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildMetricCard(String label, String value, {Color? valueColor}) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
    decoration: BoxDecoration(
      color: AppColors.whiteColor,
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textGrey,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

String _formatDate(String isoString) {
  try {
    final dt = DateTime.parse(isoString);
    return DateFormat('d MMM yyyy').format(dt);
  } catch (_) {
    return isoString;
  }
}
