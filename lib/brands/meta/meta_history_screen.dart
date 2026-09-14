// lib/brands/meta/meta_history_screen.dart
//
// Meta-branded History screen — MT5-style UI.

import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/trade_history_model.dart';
import '../../screens/trading/view_models/trading_controller.dart';
import 'meta_theme.dart';
import 'package:crm_app/services/language_service.dart';

class MetaHistoryScreen extends StatefulWidget {
  /// Called every time the History tab becomes active (initial mount +
  /// each subsequent tab-switch back to it). The shell uses it to
  /// trigger a fresh history fetch so the list is always up-to-date
  /// when the user arrives.
  final Future<void> Function()? onActivated;

  /// Called when the user taps the hamburger icon in the top-left.
  /// The shell is expected to switch to the Settings tab (index 4).
  final VoidCallback? onHamburgerTap;

  const MetaHistoryScreen({super.key, this.onActivated, this.onHamburgerTap});

  @override
  State<MetaHistoryScreen> createState() => _MetaHistoryScreenState();
}

class _MetaHistoryScreenState extends State<MetaHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  String _selectedSymbol = 'All symbols';
  String _selectedPeriodLabel = 'Today';
  DateTime? _periodFrom;
  DateTime? _periodTo;
  bool _sortAscending = false;
  String _sortKey = 'Open time';
  final Set<String> _expanded = <String>{};
  String? _lastError;

  // Dynamic cache for all symbols seen, initialized with common defaults
  final Set<String> _cachedSymbols = {
    'All symbols',
    'BTCUSD.c',
    'XAUUSD.c',
    'EURUSD.c',
    'GBPUSD.c',
    'USDJPY',
    'EURUSD',
    'XAUUSD'
  };

  @override
  void initState() {
    super.initState();
    _applyPeriod(_selectedPeriodLabel);

    // Infinite scrolling scroll listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_tc.isLoadingHistory && _hasMore) {
          _loadMore();
        }
      }
    });

    // Initial fetch — populate the list the first time the History
    // tab is rendered. Subsequent tab-switches back to this screen
    // route through `refreshHistory()` (see `MetaHistoryScreen.onActivated`).
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Public refresh hook called by the shell when the user taps the
  /// History tab in the bottom nav. Re-runs the same query as a
  /// pull-to-refresh so the list is always fresh on arrival.
  Future<void> refreshHistory() => _refresh();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  TradingController get _tc => Get.find<TradingController>();

  bool get _hasMore => _tc.paginationInfo?.hasNextPage ?? false;

  // ── Data ───────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    setState(() {
      _lastError = null;
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
      if (mounted) {
        setState(
          () => _lastError = TranslationUtils.tr(
            'meta_history_failed_to_load',
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    await _tc.loadNextPage();
  }

  String? _isoDate(DateTime? d) {
    if (d == null) return null;
    final dt = d.toLocal();
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Display-only label for a raw sort key. The raw values stay as-is because
  /// they drive `_sortBackendKey` and `_localCompare`.
  String _sortKeyLabel(String key) {
    switch (key) {
      case 'Symbol':
        return TranslationUtils.tr('meta_watchlist_symbol');
      case 'Ticket':
        return TranslationUtils.tr('meta_history_ticket');
      case 'Type':
        return TranslationUtils.tr('common_type');
      case 'Volume':
        return TranslationUtils.tr('general_volume');
      case 'Close time':
        return TranslationUtils.tr('pmam_investor_portal_screen_close_time');
      case 'Profit':
        return TranslationUtils.tr('dashboard_profit');
      case 'Open time':
      default:
        return TranslationUtils.tr('open_time');
    }
  }

  /// Display-only label for a raw period id.
  String _periodLabelText(String label) {
    switch (label) {
      case 'Last week':
        return TranslationUtils.tr('transaction_history_period_last_week');
      case 'Last month':
        return TranslationUtils.tr('iquote_position_last_month');
      case 'Last 3 months':
        return TranslationUtils.tr('iquote_position_last_3_months');
      case 'Custom period':
        return TranslationUtils.tr('meta_history_custom_period');
      case 'Today':
      default:
        return TranslationUtils.tr('dc_range_today');
    }
  }

  /// Display-only label for a raw symbol filter value.
  String _symbolLabel(String symbol) => symbol == 'All symbols'
      ? TranslationUtils.tr('meta_history_all_symbols')
      : symbol;

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

  List<TradeHistoryItem> _getFilteredAndSortedRows() {
    final originalList = _tc.tradeHistory.toList(growable: true);

    // Cache any new symbols dynamically
    for (final item in originalList) {
      if (item.tradeSymbol.isNotEmpty) {
        _cachedSymbols.add(item.tradeSymbol);
      }
    }

    List<TradeHistoryItem> list = originalList;

    // Filter by symbol locally if necessary
    if (_selectedSymbol != 'All symbols') {
      list = list.where((item) => item.tradeSymbol == _selectedSymbol).toList();
    }

    // Sort list locally
    list.sort((a, b) => _localCompare(a, b, _sortKey, _sortAscending));

    // Append virtual Deposit transaction if at the end of the pages
    final totals = _tc.tradeHistoryTotals;
    if (!_hasMore && _selectedSymbol == 'All symbols' && totals != null && totals.deposit > 0) {
      String depositTime = '';
      if (originalList.isNotEmpty) {
        final sortedByTime = List<TradeHistoryItem>.from(originalList)
          ..sort((a, b) => a.tradeOpenTime.compareTo(b.tradeOpenTime));
        final earliestTime = DateTime.tryParse(sortedByTime.first.tradeOpenTime);
        if (earliestTime != null) {
          depositTime = earliestTime.subtract(const Duration(minutes: 1)).toString();
        }
      }
      if (depositTime.isEmpty) {
        depositTime = '2026-07-05 10:45:42';
      }

      final virtualDeposit = TradeHistoryItem(
        mt5Account: originalList.isNotEmpty ? originalList.first.mt5Account : 2000004,
        tradePositionId: 0,
        tradeType: 'balance',
        tradeSymbol: '',
        tradeVolume: '0.00',
        tradePriceOrder: '0.00',
        tradeOpenTime: depositTime,
        tradeCloseTime: depositTime,
        tradePriceClose: '0.00',
        tradeProfit: totals.deposit.toString(),
        tradePriceTp: '0.00',
        tradePriceSl: '0.00',
        tradeCommission: '0.00',
        swap: 0.0,
        duration: '',
      );

      // Deposit is the oldest transaction, so it belongs at the bottom when sorting by time descending,
      // or at the top if sorting is ascending. Let's add it before sorting to let it fit organically.
      if (!list.any((element) => element.tradeType == 'balance')) {
        list.add(virtualDeposit);
        list.sort((a, b) => _localCompare(a, b, _sortKey, _sortAscending));
      }
    }

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
              Expanded(
                child: _buildList(context),
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
      padding: EdgeInsetsDirectional.fromSTEB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu, color: MetaTheme.mainText(context), size: 24),
                    onPressed: () => widget.onHamburgerTap?.call(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Get.find<LanguageService>().tr('meta_history_title'), style: AppTextStyles.bodyText.copyWith(color: MetaTheme.mainText(context), fontSize: 15, fontWeight: FontWeight.w600, height: 1.1)),
                SizedBox(height: 1),
                Text(_selectedSymbol, style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 13, height: 1.1)),
              ],
            ),
          ),
          _HeaderIcon(icon: Icons.sync, tooltip: Get.find<LanguageService>().tr('meta_history_select_symbol_hint'), onTap: () => _openSymbolSheet(context)),
          _HeaderIcon(icon: Icons.swap_vert, tooltip: Get.find<LanguageService>().tr('meta_history_sort_columns_hint'), onTap: () => _openSortSheet(context)),
          InkResponse(
            onTap: () => _openPeriodSheet(context),
            radius: 26,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: CalendarIcon(
                  color: MetaTheme.mainText(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Obx(() {
      final loading = _tc.isLoadingHistory && _tc.tradeHistory.isEmpty;
      final rows = _getFilteredAndSortedRows();

      return RefreshIndicator(
        color: MetaTheme.buyBlue,
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 24),
          children: [
            _buildSummary(context),
            if (loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
                ),
              )
            else if (_lastError != null && rows.isEmpty)
              _buildErrorState(context, _lastError!)
            else if (rows.isEmpty)
              _buildEmptyState(context)
            else
              ..._buildRowList(context, rows),
            _PaginationSentinel(
              hasMore: _hasMore,
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
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: AppTextStyles.bodyText.copyWith(color: MetaTheme.mainText(context), fontSize: 14, height: 1.2)),
            SizedBox(width: 4),
            Expanded(child: CustomPaint(size: const Size(double.infinity, 1), painter: _DottedLeaderPainter(color: MetaTheme.subText(context).withOpacity(0.35)))),
            SizedBox(width: 4),
            Text(value, style: AppTextStyles.bodyText.copyWith(color: valueColor ?? MetaTheme.mainText(context), fontSize: 14, fontWeight: FontWeight.w400, height: 1.2)),
          ],
        ),
      );
    }
    return Container(
      color: MetaTheme.bg(context),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(TranslationUtils.tr('meta_history_profit'), _format(t.profit), valueColor: profitColor),
          row(Get.find<LanguageService>().tr('meta_history_deposit'), _format(t.deposit)),
          row(Get.find<LanguageService>().tr('meta_history_swap'), _format(t.swap)),
          row(Get.find<LanguageService>().tr('meta_history_commission'), _format(t.commission)),
          row(TranslationUtils.tr('meta_history_balance'), _format(t.balance)),
          SizedBox(height: 8),
          Divider(height: 1, thickness: 0.5, color: MetaTheme.divider(context)),
        ],
      ),
    );
  }

  List<Widget> _buildRowList(BuildContext context, List<TradeHistoryItem> rows) {
    final widgets = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final key = '${r.tradePositionId}_${r.tradeOpenTime}';
      final isOpen = _expanded.contains(key);
      widgets.add(_PositionCard(row: r, expanded: isOpen, onTap: () => setState(() { isOpen ? _expanded.remove(key) : _expanded.add(key); })));
      if (i < rows.length - 1) {
        widgets.add(Divider(height: 1, thickness: 0.5, color: MetaTheme.divider(context)));
      }
    }
    return widgets;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, color: MetaTheme.subText(context).withOpacity(0.4), size: 80),
          SizedBox(height: 16),
          Text(Get.find<LanguageService>().tr('meta_history_empty'), style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 14, fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(24, 60, 24, 0),
      child: Column(children: [
        Icon(Icons.error_outline, color: MetaTheme.sell(context), size: 48),
        SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 13)),
        SizedBox(height: 16),
        TextButton(onPressed: _refresh, child: Text(Get.find<LanguageService>().tr('meta_history_retry'), style: AppTextStyles.bodyText.copyWith(color: MetaTheme.buyBlue))),
      ]),
    );
  }

  // ── Bottom sheets ──────────────────────────────────────────────────

  Future<void> _openDrawer(BuildContext context) async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetaTheme.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => _MetaSheetWrapper(
        title: Get.find<LanguageService>().tr('common_menu'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetRow(icon: Icons.calendar_today, leading: TranslationUtils.trArgs('meta_history_period_value', {'period': _periodLabelText(_selectedPeriodLabel)}), onTap: () { Navigator.of(ctx).pop(); _openPeriodSheet(context); }),
          const _SheetDivider(),
          _SheetRow(icon: Icons.sort, leading: TranslationUtils.trArgs('meta_history_sort_value', {'sort': _sortKeyLabel(_sortKey)}), onTap: () { Navigator.of(ctx).pop(); _openSortSheet(context); }),
          const _SheetDivider(),
          _SheetRow(icon: Icons.view_column, leading: TranslationUtils.trArgs('meta_history_symbol_value', {'symbol': _symbolLabel(_selectedSymbol)}), onTap: () { Navigator.of(ctx).pop(); _openSymbolSheet(context); }),
          const _SheetDivider(),
          _SheetRow(icon: Icons.refresh, leading: TranslationUtils.tr('meta_history_reload'), onTap: () { Navigator.of(ctx).pop(); _refresh(); }),
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
        title: Get.find<LanguageService>().tr('meta_history_select_period'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final p in periods) ...[
            _SheetRow(icon: _iconForPeriod(p), leading: _periodLabelText(p), trailingSub: _rangeLabelForPeriod(p), selected: p == _selectedPeriodLabel,
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
        title: Get.find<LanguageService>().tr('meta_history_sort_columns'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final o in options) ...[
            _SheetRow(icon: null, leading: _sortKeyLabel(o), showArrow: o == _sortKey, arrowAscending: o == _sortKey ? _sortAscending : !_sortAscending,
              onTap: () async { setState(() { if (_sortKey == o) { _sortAscending = !_sortAscending; } else { _sortKey = o; _sortAscending = false; } }); Navigator.of(ctx).pop(); await _refresh(); }),
            if (o != options.last) const _SheetDivider(),
          ],
        ]),
      ),
    );
  }

  Future<void> _openSymbolSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetaTheme.bg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => _MetaSheetWrapper(
        title: Get.find<LanguageService>().tr('meta_history_select_symbol_filter'),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final s in _cachedSymbols) ...[
                _SheetRow(icon: null, leading: _symbolLabel(s), selected: s == _selectedSymbol,
                  onTap: () async { Navigator.of(ctx).pop(); setState(() => _selectedSymbol = s); await _refresh(); }),
                if (s != _cachedSymbols.last) const _SheetDivider(),
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
      case 'Today': return Icons.calendar_today_outlined;
      case 'Last week': return Icons.date_range_outlined;
      case 'Last month': return Icons.calendar_month_outlined;
      case 'Last 3 months': return Icons.calendar_month;
      case 'Custom period': return Icons.date_range;
    }
    return Icons.calendar_today;
  }

  String _format(double v) => NumberFormat.currency(symbol: '', decimalDigits: 2).format(v).trim();
  Color _moneyColor(double v, BuildContext ctx) => v > 0 ? MetaTheme.buy(ctx) : (v < 0 ? MetaTheme.sell(ctx) : MetaTheme.mainText(ctx));
  double _parseDouble(String? v) => (v == null || v.isEmpty) ? 0 : (double.tryParse(v.replaceAll(',', '')) ?? 0);
}

// ──────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────

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
    final rawSide = row.tradeType.toLowerCase();
    final isBalance = rawSide == 'balance' || rawSide == 'deposit';
    final priceFmt = NumberFormat('#,##0.00', 'en_US');

    if (isBalance) {
      final depositAmount = _parseProfit(row.tradeProfit);
      final depositColor = MetaTheme.buy(context);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Get.find<LanguageService>().tr('meta_history_balance'),
                    style: AppTextStyles.bodyText.copyWith(color: MetaTheme.mainText(context), fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
                  ),
                  SizedBox(height: 2),
                  Text(
                    Get.find<LanguageService>().tr('meta_history_deposit'),
                    style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 13, height: 1.2),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (row.tradeCloseTime.isNotEmpty)
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm:ss').format(_parseDate(row.tradeCloseTime).toLocal()),
                    style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 12),
                  ),
                SizedBox(height: 2),
                Text(
                  priceFmt.format(depositAmount),
                  style: AppTextStyles.bodyText.copyWith(color: depositColor, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final profit = _parseProfit(row.tradeProfit);
    final openPrice = _parsePrice(row.tradePriceOrder);
    final closePrice = _parsePrice(row.tradePriceClose);
    final profitColor = profit > 0 ? MetaTheme.buy(context) : (profit < 0 ? MetaTheme.sell(context) : MetaTheme.mainText(context));
    final sideColor = rawSide == 'buy' ? MetaTheme.buy(context) : rawSide == 'sell' ? MetaTheme.sell(context) : MetaTheme.buyBlue;
    final sideLabel = rawSide == 'buy' ? 'buy' : rawSide == 'sell' ? 'sell' : rawSide;
    final volFmt = NumberFormat('0.##');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(style: AppTextStyles.bodyText.copyWith(color: MetaTheme.mainText(context), fontSize: 15, fontWeight: FontWeight.w600, height: 1.2), children: [
                TextSpan(text: '${row.tradeSymbol}, '),
                TextSpan(text: '$sideLabel ${volFmt.format(row.volume)}', style: AppTextStyles.bodyText.copyWith(color: sideColor)),
              ])),
              SizedBox(height: 2),
              Text('${_formatPrice(openPrice, row.tradeSymbol)} → ${_formatPrice(closePrice, row.tradeSymbol)}', style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 13, height: 1.2)),
            ])),
            SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(DateFormat('yyyy.MM.dd HH:mm:ss').format(_parseDate(row.tradeCloseTime).toLocal()), style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 12)),
              SizedBox(height: 2),
              Text(_formatProfit(profit), style: AppTextStyles.bodyText.copyWith(color: profitColor, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ]),
          if (expanded) ...[SizedBox(height: 8), _ExpandedDetail(row: row)],
        ]),
      ),
    );
  }

  String _formatPrice(double price, String symbol) {
    if (price == 0) return '0.00';
    int decimals = 2;
    final upperSymbol = symbol.toUpperCase();
    if (upperSymbol.contains('USD') && !upperSymbol.contains('JPY') && !upperSymbol.contains('XAU') && !upperSymbol.contains('BTC') && !upperSymbol.contains('ETH')) {
      decimals = 5;
    } else if (price < 10) {
      decimals = 5;
    }
    return NumberFormat.currency(symbol: '', decimalDigits: decimals).format(price).trim();
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
    const double fontSize = 13;
    final labelStyle = AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: fontSize);
    final valueStyle = AppTextStyles.bodyText.copyWith(color: MetaTheme.mainText(context), fontSize: fontSize);
    final ticketStyle = AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: fontSize);

    final fmt = NumberFormat('0.00');
    final dateFmt = DateFormat('yyyy.MM.dd HH:mm:ss');
    
    final parsedOpen = DateTime.tryParse(row.tradeOpenTime);
    final openTimeStr = parsedOpen == null ? '—' : dateFmt.format(parsedOpen.toLocal());
    final tp = _parseVal(row.tradePriceTp);
    final sl = _parseVal(row.tradePriceSl);
    final ticket = row.tradePositionId == 0 ? '—' : '#${row.tradePositionId}';
    final comm = _parseVal(row.tradeCommission);

    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (40% width)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket, style: ticketStyle),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(Get.find<LanguageService>().tr('meta_history_sl'), style: labelStyle),
                    const Spacer(),
                    Text(sl == 0 ? '—' : fmt.format(sl), style: valueStyle),
                    SizedBox(width: 8),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(Get.find<LanguageService>().tr('meta_history_tp'), style: labelStyle),
                    const Spacer(),
                    Text(tp == 0 ? '—' : fmt.format(tp), style: valueStyle),
                    SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
          // Right Column (60% width)
          Expanded(
            flex: 6,
            child: Column(
              children: [
                Row(
                  children: [
                    Text(Get.find<LanguageService>().tr('meta_history_open'), style: labelStyle),
                    const Spacer(),
                    Text(openTimeStr, style: valueStyle),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(Get.find<LanguageService>().tr('meta_history_swap'), style: labelStyle),
                    const Spacer(),
                    Text(fmt.format(row.swap), style: valueStyle),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(Get.find<LanguageService>().tr('meta_history_commission'), style: labelStyle),
                    const Spacer(),
                    Text(fmt.format(comm), style: valueStyle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        padding: EdgeInsets.only(top: 8, bottom: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: MetaTheme.subText(context).withOpacity(0.35), borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 10),
          Text(title, style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          SizedBox(height: 6),
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          SizedBox(width: 32, child: icon == null ? const SizedBox.shrink() : Icon(icon, size: 22, color: MetaTheme.mainText(context))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(leading ?? '', style: AppTextStyles.bodyText.copyWith(color: MetaTheme.mainText(context), fontSize: 15, fontWeight: FontWeight.w500)),
            if (trailingSub != null && trailingSub!.isNotEmpty) ...[SizedBox(height: 2), Text(trailingSub!, style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 12))],
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

class _PaginationSentinel extends StatelessWidget {
  const _PaginationSentinel({required this.hasMore, required this.loading, required this.onLoadMore});
  final bool hasMore;
  final bool loading;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Center(
        child: loading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MetaTheme.buyBlue))
            : hasMore
                ? Text(Get.find<LanguageService>().tr('meta_history_loading_more'), style: AppTextStyles.bodyText.copyWith(color: MetaTheme.subText(context), fontSize: 12))
                : const SizedBox.shrink(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Custom Calendar Icon
// ──────────────────────────────────────────────────────────────────────

class CalendarIcon extends StatelessWidget {
  final Color color;
  const CalendarIcon({required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            width: double.infinity,
            color: color,
          ),
          Expanded(
            child: Center(
              child: Text(
                '3',
                style: AppTextStyles.bodyText.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}