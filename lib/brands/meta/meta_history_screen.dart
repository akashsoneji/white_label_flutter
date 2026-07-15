// lib/brands/meta/meta_history_screen.dart
//
// Meta-branded History screen — MT5-style UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/trade_history_model.dart';
import '../../screens/trading/view_models/trading_controller.dart';
import 'meta_theme.dart';

class MetaHistoryScreen extends StatefulWidget {
  const MetaHistoryScreen({super.key});

  @override
  State<MetaHistoryScreen> createState() => _MetaHistoryScreenState();
}

class _MetaHistoryScreenState extends State<MetaHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  String _selectedSymbol = 'All symbols';
  String _selectedPeriodLabel = 'Today';
  DateTime? _periodFrom;
  DateTime? _periodTo;
  bool _sortAscending = false;
  String _sortKey = 'Open time';
  final Set<String> _expanded = <String>{};
  String? _lastError;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (mounted && !_tabs.indexIsChanging) setState(() {});
    });
    _applyPeriod(_selectedPeriodLabel);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  TradingController get _tc => Get.find<TradingController>();

  // ── Data ───────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    setState(() {
      _lastError = null;
      _hasMore = true;
    });
    try {
      await _tc.loadTradeHistoryWithFilters(
        symbol: _selectedSymbol == 'All symbols' ? null : _selectedSymbol,
        dateFrom: _isoDate(_periodFrom),
        dateTo: _isoDate(_periodTo),
        sortBy: _sortBackendKey(_sortKey),
        sortDirection: _sortAscending ? 'asc' : 'desc',
        refresh: true,
      );
    } catch (_) {
      if (mounted) setState(() => _lastError = 'Failed to load history.');
    }
  }

  Future<void> _loadMore() async {
    final countBefore = _tc.tradeHistory.length;
    await _tc.loadNextPage();
    if (mounted && _tc.tradeHistory.length <= countBefore) {
      setState(() => _hasMore = false);
    }
  }

  String? _isoDate(DateTime? d) {
    if (d == null) return null;
    final dt = d.toLocal();
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _sortBackendKey(String label) {
    switch (label) {
      case 'Symbol': return 'symbol';
      case 'Ticket': return 'position_id';
      case 'Type': return 'type';
      case 'Volume': return 'volume';
      case 'Close time': return 'close_time';
      case 'Profit': return 'profit';
      case 'Open time': default: return 'open_time';
    }
  }

  void _applyPeriod(String label) {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (label) {
      case 'Today':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'Last week':
        from = now.subtract(const Duration(days: 7));
        break;
      case 'Last month':
        from = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'Last 3 months':
        from = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'Custom period':
        from = null;
        to = null;
        break;
    }
    _selectedPeriodLabel = label;
    _periodFrom = from;
    _periodTo = to;
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = MetaThemeBus.instance.isDark.value;
    final statusBar = isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: MetaTheme.bg(context),
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBar,
      child: Scaffold(
        backgroundColor: MetaTheme.bg(context),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              _buildTabs(context),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _buildList(context, kind: _HistoryKind.positions),
                    _buildList(context, kind: _HistoryKind.orders),
                    _buildList(context, kind: _HistoryKind.deals),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: MetaTheme.bg(context),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu, color: MetaTheme.mainText(context), size: 24),
            onPressed: () => _openDrawer(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('History', style: TextStyle(color: MetaTheme.mainText(context), fontSize: 15, fontWeight: FontWeight.w600, height: 1.1)),
                const SizedBox(height: 1),
                Text(_selectedSymbol, style: TextStyle(color: MetaTheme.subText(context), fontSize: 13, height: 1.1)),
              ],
            ),
          ),
          _HeaderIcon(icon: Icons.refresh, tooltip: 'Cycle period', onTap: () => _openPeriodSheet(context)),
          _HeaderIcon(icon: _sortAscending ? Icons.arrow_upward : Icons.arrow_downward, tooltip: 'Sort', onTap: () => _openSortSheet(context)),
          _HeaderIcon(icon: Icons.calendar_view_month, tooltip: 'Columns', onTap: () => _openColumnsSheet(context)),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    const labels = ['POSITIONS', 'ORDERS', 'DEALS'];
    return Container(
      color: MetaTheme.bg(context),
      child: TabBar(
        controller: _tabs,
        isScrollable: false,
        labelColor: MetaTheme.mainText(context),
        unselectedLabelColor: MetaTheme.subText(context),
        indicatorColor: MetaTheme.buyBlue,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.4),
        tabs: [for (final l in labels) Tab(text: l, height: 44)],
      ),
    );
  }

  Widget _buildList(BuildContext context, {required _HistoryKind kind}) {
    return Obx(() {
      final loading = _tc.isLoadingHistory && _tc.tradeHistory.isEmpty;
      final rows = _projectRows(_tc.tradeHistory.toList(growable: false), kind: kind);
      return RefreshIndicator(
        color: MetaTheme.buyBlue,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildSummary(context),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(MetaTheme.buyBlue))),
                ),
              )
            else if (_lastError != null && rows.isEmpty)
              _buildErrorState(context, _lastError!)
            else if (rows.isEmpty)
              _buildEmptyState(context)
            else
              ..._buildRowList(context, rows),
            _PaginationSentinel(
              hasMore: _hasMore && rows.length >= 10,
              loading: _tc.isLoadingHistory,
              onLoadMore: _loadMore,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSummary(BuildContext context) {
    final t = _tc.tradeHistoryTotals ?? TradeHistoryTotals(profit: 0, deposit: 0, swap: 0, commission: 0, balance: 0, withdrawal: 0);
    final profitColor = _moneyColor(t.profit, context);
    Widget row(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(width: 110, child: Text(label, style: TextStyle(color: MetaTheme.mainText(context), fontSize: 14, height: 1.2))),
            Expanded(child: CustomPaint(size: const Size(double.infinity, 1), painter: _DottedLeaderPainter(color: MetaTheme.subText(context).withOpacity(0.55)))),
            const SizedBox(width: 8),
            Text(value, style: TextStyle(color: valueColor ?? MetaTheme.mainText(context), fontSize: 14, fontWeight: FontWeight.w400, height: 1.2)),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: MetaTheme.bg(context), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('Profit:', _format(t.profit), valueColor: profitColor),
          row('Deposit', _format(t.deposit)),
          row('Swap:', _format(t.swap)),
          row('Commission:', _format(t.commission)),
          row('Balance:', _format(t.balance), valueColor: profitColor),
        ],
      ),
    );
  }

  List<Widget> _buildRowList(BuildContext context, List<TradeHistoryItem> rows) {
    final widgets = <Widget>[];
    for (final r in rows) {
      final key = '${_tabs.index}_${r.tradePositionId}_${r.tradeOpenTime}';
      final isOpen = _expanded.contains(key);
      widgets.add(_PositionCard(row: r, expanded: isOpen, onTap: () => setState(() { isOpen ? _expanded.remove(key) : _expanded.add(key); })));
    }
    return widgets;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
      child: Column(children: [
        Icon(Icons.history, color: MetaTheme.subText(context), size: 56),
        const SizedBox(height: 12),
        Text('No trades in this period', style: TextStyle(color: MetaTheme.subText(context), fontSize: 14)),
      ]),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
      child: Column(children: [
        Icon(Icons.error_outline, color: MetaTheme.sell(context), size: 48),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: MetaTheme.subText(context), fontSize: 13)),
        const SizedBox(height: 16),
        TextButton(onPressed: _refresh, child: Text('Retry', style: TextStyle(color: MetaTheme.buyBlue))),
      ]),
    );
  }

  List<TradeHistoryItem> _projectRows(List<TradeHistoryItem> rows, {required _HistoryKind kind}) {
    List<TradeHistoryItem> list;
    switch (kind) {
      case _HistoryKind.positions: list = rows; break;
      case _HistoryKind.orders:
        list = rows.where((r) => r.tradeOpenTime == r.tradeCloseTime || (_parseDouble(r.tradePriceTp) == 0 && _parseDouble(r.tradePriceSl) == 0)).toList();
        if (list.isEmpty) list = rows;
        break;
      case _HistoryKind.deals: list = rows; break;
    }
    list.sort((a, b) => _localCompare(a, b, _sortKey, _sortAscending));
    return list;
  }

  int _localCompare(TradeHistoryItem a, TradeHistoryItem b, String key, bool asc) {
    int cmp;
    switch (key) {
      case 'Symbol': cmp = a.tradeSymbol.compareTo(b.tradeSymbol); break;
      case 'Ticket': cmp = a.tradePositionId.compareTo(b.tradePositionId); break;
      case 'Type': cmp = a.tradeType.compareTo(b.tradeType); break;
      case 'Volume': cmp = a.volume.compareTo(b.volume); break;
      case 'Close time': cmp = a.tradeCloseTime.compareTo(b.tradeCloseTime); break;
      case 'Profit': cmp = _parseDouble(a.tradeProfit).compareTo(_parseDouble(b.tradeProfit)); break;
      case 'Open time': default: cmp = a.tradeOpenTime.compareTo(b.tradeOpenTime); break;
    }
    return asc ? cmp : -cmp;
  }

  // ── Bottom sheets ──────────────────────────────────────────────────

  Future<void> _openDrawer(BuildContext context) async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetaTheme.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => _MetaSheetWrapper(
        title: 'MENU',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetRow(icon: Icons.calendar_today, leading: 'Period: $_selectedPeriodLabel', onTap: () { Navigator.of(ctx).pop(); _openPeriodSheet(context); }),
          const _SheetDivider(),
          _SheetRow(icon: Icons.sort, leading: 'Sort: $_sortKey', onTap: () { Navigator.of(ctx).pop(); _openSortSheet(context); }),
          const _SheetDivider(),
          _SheetRow(icon: Icons.view_column, leading: 'Symbol: $_selectedSymbol', onTap: () { Navigator.of(ctx).pop(); _openColumnsSheet(context); }),
          const _SheetDivider(),
          _SheetRow(icon: Icons.refresh, leading: 'Reload', onTap: () { Navigator.of(ctx).pop(); _refresh(); }),
        ]),
      ),
    );
  }

  Future<void> _openPeriodSheet(BuildContext context) async {
    const periods = ['Today', 'Last week', 'Last month', 'Last 3 months', 'Custom period'];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetaTheme.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => _MetaSheetWrapper(
        title: 'SELECT PERIOD',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final p in periods) ...[
            _SheetRow(icon: _iconForPeriod(p), leading: p, trailingSub: _rangeLabelForPeriod(p), selected: p == _selectedPeriodLabel,
              onTap: () async {
                Navigator.of(ctx).pop();
                if (p == 'Custom period') {
                  final picked = await _pickCustomRange(context);
                  if (!mounted) return;
                  if (picked != null) { setState(() { _periodFrom = picked.$1; _periodTo = picked.$2; _selectedPeriodLabel = 'Custom period'; }); await _refresh(); }
                  return;
                }
                setState(() => _applyPeriod(p));
                await _refresh();
              }),
            if (p != periods.last) const _SheetDivider(),
          ],
        ]),
      ),
    );
  }

  Future<void> _openSortSheet(BuildContext context) async {
    const options = ['Symbol', 'Ticket', 'Type', 'Volume', 'Open time', 'Close time', 'Profit'];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetaTheme.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => _MetaSheetWrapper(
        title: 'SORT COLUMNS',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final o in options) ...[
            _SheetRow(icon: null, leading: o, showArrow: o == _sortKey, arrowAscending: o == _sortKey ? _sortAscending : !_sortAscending,
              onTap: () async { setState(() { if (_sortKey == o) { _sortAscending = !_sortAscending; } else { _sortKey = o; _sortAscending = false; } }); Navigator.of(ctx).pop(); await _refresh(); }),
            if (o != options.last) const _SheetDivider(),
          ],
        ]),
      ),
    );
  }

  Future<void> _openColumnsSheet(BuildContext context) async {
    final symbols = <String>['All symbols', ..._tc.tradeHistory.map((r) => r.tradeSymbol).toSet()..remove('')];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetaTheme.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => _MetaSheetWrapper(
        title: 'SELECT SYMBOL',
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final s in symbols) ...[
                _SheetRow(icon: null, leading: s, selected: s == _selectedSymbol,
                  onTap: () async { Navigator.of(ctx).pop(); setState(() => _selectedSymbol = s); await _refresh(); }),
                if (s != symbols.last) const _SheetDivider(),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Future<(DateTime, DateTime)?> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final from = await showDatePicker(
      context: context, initialDate: _periodFrom ?? now.subtract(const Duration(days: 7)), firstDate: DateTime(now.year - 5), lastDate: now,
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: MetaTheme.buyBlue, onPrimary: Colors.white, surface: MetaTheme.bg(ctx), onSurface: MetaTheme.mainText(ctx))), child: child!));
    if (from == null) return null;
    final to = await showDatePicker(
      context: context, initialDate: _periodTo ?? now, firstDate: from, lastDate: now,
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: MetaTheme.buyBlue, onPrimary: Colors.white, surface: MetaTheme.bg(ctx), onSurface: MetaTheme.mainText(ctx))), child: child!));
    if (to == null) return null;
    return (DateTime(from.year, from.month, from.day), DateTime(to.year, to.month, to.day, 23, 59, 59));
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _rangeLabelForPeriod(String p) {
    final now = DateTime.now();
    final fmt = DateFormat('M/d/yy');
    String ago(int days) => fmt.format(now.subtract(Duration(days: days)).toLocal());
    switch (p) {
      case 'Today': return fmt.format(now.toLocal());
      case 'Last week': return '${ago(7)} - ${ago(0)}';
      case 'Last month': return '${ago(30)} - ${ago(0)}';
      case 'Last 3 months': return '${ago(90)} - ${ago(0)}';
      case 'Custom period':
        if (_periodFrom != null && _periodTo != null) return '${fmt.format(_periodFrom!.toLocal())} - ${fmt.format(_periodTo!.toLocal())}';
        return '';
    }
    return '';
  }

  IconData _iconForPeriod(String p) {
    switch (p) {
      case 'Today': return Icons.calendar_view_day;
      case 'Last week': return Icons.calendar_view_week;
      case 'Last month': return Icons.calendar_view_month;
      case 'Last 3 months': return Icons.calendar_month;
      case 'Custom period': return Icons.tune;
    }
    return Icons.calendar_today;
  }

  String _format(double v) => NumberFormat.currency(symbol: '', decimalDigits: 2).format(v).trim();
  Color _moneyColor(double v, BuildContext ctx) => v > 0 ? MetaTheme.buy(ctx) : (v < 0 ? MetaTheme.sell(ctx) : MetaTheme.mainText(ctx));
  double _parseDouble(String? v) => (v == null || v.isEmpty) ? 0 : (double.tryParse(v.replaceAll(',', '')) ?? 0);
  // ignore: unused_element
  /// Parse ISO date string — kept for reference (used via inline DateTime.tryParse).
  // ignore: unused_element
  DateTime? _parseDateTime(String v) => v.isEmpty ? null : DateTime.tryParse(v);
}

// ──────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────

enum _HistoryKind { positions, orders, deals }

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final btn = InkResponse(onTap: onTap, radius: 26, child: SizedBox(width: 44, height: 44, child: Center(child: Icon(icon, color: MetaTheme.mainText(context), size: 22))));
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.row, required this.expanded, required this.onTap});
  final TradeHistoryItem row;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profit = _parseProfit(row.tradeProfit);
    final openPrice = _parsePrice(row.tradePriceOrder);
    final closePrice = _parsePrice(row.tradePriceClose);
    final profitColor = profit > 0 ? MetaTheme.buy(context) : (profit < 0 ? MetaTheme.sell(context) : MetaTheme.mainText(context));
    final rawSide = row.tradeType.toLowerCase();
    final sideColor = rawSide == 'buy' ? MetaTheme.buy(context) : rawSide == 'sell' ? MetaTheme.sell(context) : MetaTheme.buyBlue;
    final sideLabel = rawSide == 'buy' ? 'buy' : rawSide == 'sell' ? 'sell' : rawSide;
    final priceFmt = NumberFormat('#,##0.00', 'en_US');
    final volFmt = NumberFormat('0.##');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(color: MetaTheme.bg(context), borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RichText(text: TextSpan(style: TextStyle(color: MetaTheme.mainText(context), fontSize: 15, fontWeight: FontWeight.w600, height: 1.2), children: [
                  TextSpan(text: '${row.tradeSymbol}, '),
                  TextSpan(text: '$sideLabel ${volFmt.format(row.volume)}', style: TextStyle(color: sideColor)),
                ])),
                const SizedBox(height: 2),
                Text('${priceFmt.format(openPrice)} → ${priceFmt.format(closePrice)}', style: TextStyle(color: MetaTheme.subText(context), fontSize: 13, height: 1.2)),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(DateFormat('yyyy.MM.dd HH:mm:ss').format(_parseDate(row.tradeCloseTime).toLocal()), style: TextStyle(color: MetaTheme.subText(context), fontSize: 12)),
                const SizedBox(height: 2),
                Text(_formatProfit(profit), style: TextStyle(color: profitColor, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ]),
            if (expanded) ...[const SizedBox(height: 8), _ExpandedDetail(row: row)],
          ]),
        ),
      ),
    );
  }

  double _parseProfit(String v) => (v.isEmpty) ? 0 : (double.tryParse(v.replaceAll(',', '')) ?? 0);
  double _parsePrice(String v) => (v.isEmpty || v == '0') ? 0 : (double.tryParse(v.replaceAll(',', '')) ?? 0);
  DateTime _parseDate(String v) => DateTime.tryParse(v) ?? DateTime(0);
  String _formatProfit(double v) => NumberFormat.currency(symbol: '', decimalDigits: 2).format(v).trim();
}

class _ExpandedDetail extends StatelessWidget {
  const _ExpandedDetail({required this.row});
  final TradeHistoryItem row;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('0.00');
    final dateFmt = DateFormat('yyyy.MM.dd HH:mm:ss');

    Widget pair(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: MetaTheme.subText(context), fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: valueColor ?? MetaTheme.mainText(context), fontSize: 13))),
        ]),
      );
    }

    final parsedOpen = DateTime.tryParse(row.tradeOpenTime);
    final openTimeStr = parsedOpen == null ? '—' : dateFmt.format(parsedOpen.toLocal());
    final tp = _parseVal(row.tradePriceTp);
    final sl = _parseVal(row.tradePriceSl);
    final ticket = row.tradePositionId == 0 ? '—' : '#${row.tradePositionId}';

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        pair(ticket, ''),
        pair('S / L:', sl == 0 ? '—' : fmt.format(sl)),
        pair('T / P:', tp == 0 ? '—' : fmt.format(tp)),
      ])),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        pair('Open:', openTimeStr),
        pair('Swap:', fmt.format(row.swap)),
        pair('Commission:', fmt.format(_parseVal(row.tradeCommission))),
      ])),
    ]);
  }

  double _parseVal(String v) => (v.isEmpty || v == '0') ? 0 : (double.tryParse(v.replaceAll(',', '')) ?? 0);
}

// ──────────────────────────────────────────────────────────────────────
// Dotted leader painter
// ──────────────────────────────────────────────────────────────────────

class _DottedLeaderPainter extends CustomPainter {
  _DottedLeaderPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    const dotR = 0.7, gap = 4.0;
    final y = size.height - 2;
    double x = 0;
    while (x < size.width) { canvas.drawCircle(Offset(x, y), dotR, paint); x += gap; }
  }
  @override
  bool shouldRepaint(_DottedLeaderPainter old) => old.color != color;
}

// ──────────────────────────────────────────────────────────────────────
// Bottom-sheet primitives
// ──────────────────────────────────────────────────────────────────────

class _MetaSheetWrapper extends StatelessWidget {
  const _MetaSheetWrapper({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: MetaTheme.subText(context).withOpacity(0.35), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: MetaTheme.subText(context), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 0.5),
          child,
        ]),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.onTap, this.icon, this.leading, this.trailingSub, this.selected = false, this.showArrow = false, this.arrowAscending = false});
  final VoidCallback onTap;
  final IconData? icon;
  final String? leading;
  final String? trailingSub;
  final bool selected;
  final bool showArrow;
  final bool arrowAscending;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          SizedBox(width: 32, child: icon == null ? const SizedBox.shrink() : Icon(icon, size: 22, color: MetaTheme.mainText(context))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(leading ?? '', style: TextStyle(color: MetaTheme.mainText(context), fontSize: 15, fontWeight: FontWeight.w500)),
            if (trailingSub != null && trailingSub!.isNotEmpty) ...[const SizedBox(height: 2), Text(trailingSub!, style: TextStyle(color: MetaTheme.subText(context), fontSize: 12))],
          ])),
          if (showArrow) Icon(arrowAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 18, color: MetaTheme.buyBlue)
          else if (selected) Icon(Icons.check, size: 18, color: MetaTheme.buyBlue),
        ]),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 0.4, indent: 48, color: MetaTheme.subText(context).withOpacity(0.15));
}

// ──────────────────────────────────────────────────────────────────────
// Pagination sentinel
// ──────────────────────────────────────────────────────────────────────

class _PaginationSentinel extends StatefulWidget {
  const _PaginationSentinel({required this.hasMore, required this.loading, required this.onLoadMore});
  final bool hasMore;
  final bool loading;
  final Future<void> Function() onLoadMore;
  @override
  State<_PaginationSentinel> createState() => _PaginationSentinelState();
}

class _PaginationSentinelState extends State<_PaginationSentinel> {
  bool _scheduled = false;
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!widget.hasMore || widget.loading || _scheduled) return false;
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 240) {
          _scheduled = true;
          widget.onLoadMore().whenComplete(() { if (mounted) _scheduled = false; });
        }
        return false;
      },
      child: SizedBox(
        height: 56,
        child: Center(
          child: widget.loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(MetaTheme.buyBlue)))
              : widget.hasMore
                  ? Text('Loading more…', style: TextStyle(color: MetaTheme.subText(context), fontSize: 12))
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}