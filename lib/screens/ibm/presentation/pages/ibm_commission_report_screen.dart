import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/screens/ibm/data/ibm_report_models.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_exports_screen.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_report_widgets.dart';
import 'package:crm_app/services/language_service.dart';

/// IB Commission (web: Reports → IB Commission). Reads
/// `GET ibm/portal/commission-report` per trade or per account; Export CSV
/// posts `{kind: commission_history, from, to, mt5_account, symbol, side, view}`.
class IbmCommissionReportScreen extends StatefulWidget {
  const IbmCommissionReportScreen({super.key});

  @override
  State<IbmCommissionReportScreen> createState() =>
      _IbmCommissionReportScreenState();
}

/// One set of filters; the screen keeps a draft and the applied copy.
class _CommissionFilters {
  final IbmReportDates dates;
  final String view;
  final String? account;
  final String? symbol;
  final String? side;

  const _CommissionFilters({
    this.dates = const IbmReportDates(),
    this.view = 'trade',
    this.account,
    this.symbol,
    this.side,
  });

  _CommissionFilters copyWith({
    IbmReportDates? dates,
    String? view,
    String? Function()? account,
    String? Function()? symbol,
    String? Function()? side,
  }) =>
      _CommissionFilters(
        dates: dates ?? this.dates,
        view: view ?? this.view,
        account: account != null ? account() : this.account,
        symbol: symbol != null ? symbol() : this.symbol,
        side: side != null ? side() : this.side,
      );

  bool sameAs(_CommissionFilters other) =>
      dates.sameAs(other.dates) &&
      view == other.view &&
      account == other.account &&
      symbol == other.symbol &&
      side == other.side;
}

class _IbmCommissionReportScreenState extends State<IbmCommissionReportScreen> {
  static const int _perPage = 25;
  static final NumberFormat _money = NumberFormat('#,##0.00');
  static final NumberFormat _precise = NumberFormat('#,##0.00##');
  static final DateFormat _rowDate = DateFormat('d MMM yyyy');

  final IbmApiProvider _api = IbmApiProvider();

  _CommissionFilters _draft = const _CommissionFilters();
  _CommissionFilters _applied = const _CommissionFilters();

  bool _isLoading = false;
  bool _isLoadingPage = false;
  bool _isExporting = false;
  String? _error;
  IbmCommissionReport? _report;

  /// Dropdown options from the first unfiltered response; kept so choosing
  /// an account does not shrink the account / symbol lists.
  List<String> _accountOptions = const [];
  List<String> _symbolOptions = const [];

  Future<void> _load({int page = 1}) async {
    final range = _applied.dates.range;
    if (range == null) return;
    final isPageChange = page != 1 && _report != null;
    setState(() {
      if (isPageChange) {
        _isLoadingPage = true;
      } else {
        _isLoading = true;
        _error = null;
      }
    });

    final filters = _applied;
    final res = await _api.getCommissionReport(
      from: ibmReportApiDate.format(range.start),
      to: ibmReportApiDate.format(range.end),
      view: filters.view,
      mt5Account: filters.account,
      symbol: filters.symbol,
      type: filters.view == 'trade' ? filters.side : null,
      page: page,
      perPage: _perPage,
    );
    if (!mounted) return;

    final body = res.data;
    setState(() {
      _isLoading = false;
      _isLoadingPage = false;
      if (res.success && body is Map && body['data'] is Map) {
        final report = IbmCommissionReport.fromJson(
          Map<String, dynamic>.from(body['data'] as Map),
        );
        _report = report;
        if (report.accountOptions.isNotEmpty &&
            report.accountOptions.length >= _accountOptions.length) {
          _accountOptions = report.accountOptions;
        }
        if (report.symbolOptions.isNotEmpty &&
            report.symbolOptions.length >= _symbolOptions.length) {
          _symbolOptions = report.symbolOptions;
        }
      } else if (!isPageChange) {
        _error = res.message ?? TranslationUtils.tr('ibm_failed_to_load_data');
      }
    });
  }

  void _apply() {
    if (ibmValidateReportDates(_draft.dates) == null) return;
    _applied = _draft;
    _load();
  }

  Future<void> _export() async {
    final filters = _draft;
    final range = ibmValidateReportDates(filters.dates);
    if (range == null) return;
    setState(() => _isExporting = true);
    await runIbmExport(
      kind: 'commission_history',
      filters: {
        'from': ibmReportApiDate.format(range.start),
        'to': ibmReportApiDate.format(range.end),
        'mt5_account': filters.account ?? '',
        'symbol': filters.symbol ?? '',
        'side': filters.view == 'trade' ? filters.side ?? '' : '',
        'view': filters.view,
      },
    );
    if (mounted) setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final all = TranslationUtils.tr('ibm_filter_all');
    return IbmReportScaffold(
      title: TranslationUtils.tr('ibm_ib_commission'),
      subtitle: TranslationUtils.tr('ibm_ib_commission_subtitle'),
      onRefresh: () => _load(page: _report?.pagination.page ?? 1),
      children: [
        IbmReportFilterCard(
          dates: _draft.dates,
          onDatesChanged: (dates) =>
              setState(() => _draft = _draft.copyWith(dates: dates)),
          onApply: _apply,
          onExport: _export,
          isApplying: _isLoading,
          isExporting: _isExporting,
          hasPendingChanges: !_draft.sameAs(_applied),
          extraFilters: [
            _ViewToggle(
              value: _draft.view,
              onChanged: (view) =>
                  setState(() => _draft = _draft.copyWith(view: view)),
            ),
            Row(
              children: [
                Expanded(
                  child: IbmReportDropdown(
                    label: TranslationUtils.tr('ibm_mt5_account'),
                    value: _draft.account,
                    options: {
                      null: all,
                      for (final account in _accountOptions) account: account,
                    },
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(account: () => v),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: IbmReportDropdown(
                    label: TranslationUtils.tr('ibm_symbol'),
                    value: _draft.symbol,
                    options: {
                      null: all,
                      for (final symbol in _symbolOptions) symbol: symbol,
                    },
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(symbol: () => v),
                    ),
                  ),
                ),
              ],
            ),
            if (_draft.view == 'trade')
              IbmReportDropdown(
                label: TranslationUtils.tr('ibm_side'),
                value: _draft.side,
                options: {
                  null: all,
                  'buy': TranslationUtils.tr('ibm_filter_buy'),
                  'sell': TranslationUtils.tr('ibm_filter_sell'),
                },
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(side: () => v)),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        ..._buildResults(),
      ],
    );
  }

  List<Widget> _buildResults() {
    if (_isLoading) return const [IbmReportLoading()];
    if (_error != null) {
      return [IbmReportError(message: _error!, onRetry: _load)];
    }
    final report = _report;
    if (report == null) return const [IbmReportSelectDatesHint()];

    return [
      for (final summary in report.summary) ...[
        _SummaryCard(summary: summary),
        SizedBox(height: 12.h),
      ],
      IbmReportListCard(
        title: TranslationUtils.tr(
          report.isAccountView ? 'ibm_commission_by_account' : 'ibm_commission_by_trade',
        ),
        total: report.pagination.total,
        page: report.pagination.page,
        lastPage: report.pagination.lastPage,
        perPage: _perPage,
        isLoadingPage: _isLoadingPage,
        onPage: (page) => _load(page: page),
        rows: report.isAccountView
            ? [for (final row in report.accountRows) _AccountRow(row: row)]
            : [for (final row in report.tradeRows) _TradeRow(row: row)],
      ),
    ];
  }

  static String formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : _rowDate.format(parsed);
  }
}

/// Per trade / Per account segmented control.
class _ViewToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ViewToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget segment(String key, String label) {
      final selected = value == key;
      return Expanded(
        child: InkWell(
          onTap: selected ? null : () => onChanged(key),
          borderRadius: BorderRadius.circular(18.r),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.whiteColor : AppColors.textGrey,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 36.h,
      decoration: BoxDecoration(
        color: AppColors.isDarkMode
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFF1EEF8),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          segment('trade', TranslationUtils.tr('ibm_per_trade')),
          segment('account', TranslationUtils.tr('ibm_per_account')),
        ],
      ),
    );
  }
}

/// Per-currency summary: big commission figure, then trades / accounts / lots.
class _SummaryCard extends StatelessWidget {
  final IbmCommissionSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    Widget metric(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );

    return IbmReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.currency,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            TranslationUtils.tr('ibm_commission_earned'),
            style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 2.h),
          Text(
            '+${_IbmCommissionReportScreenState._precise.format(summary.commission)}',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade700,
            ),
          ),
          SizedBox(height: 12.h),
          Divider(height: 1, color: AppColors.divider),
          SizedBox(height: 10.h),
          Row(
            children: [
              metric(TranslationUtils.tr('ibm_trades'), '${summary.trades}'),
              metric(TranslationUtils.tr('ibm_accounts'), '${summary.accounts}'),
              metric(
                TranslationUtils.tr('ibm_lots'),
                _IbmCommissionReportScreenState._precise.format(summary.lots),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TradeRow extends StatelessWidget {
  final IbmCommissionTradeRow row;

  const _TradeRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final sideColor = row.isBuy ? Colors.green.shade700 : Colors.red.shade700;
    final profitColor =
        row.profit >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    final money = _IbmCommissionReportScreenState._money;
    final precise = _IbmCommissionReportScreenState._precise;

    return IbmReportRow(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      row.symbol,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    IbmReportPill(text: row.type, color: sideColor),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '#${row.order} · MT5 ${row.mt5Account}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${TranslationUtils.tr('ibm_volume')} ${precise.format(row.volume)}'
                  ' · ${TranslationUtils.tr('ibm_price')} ${row.price}'
                  ' · ${_IbmCommissionReportScreenState.formatDate(row.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${precise.format(row.commission)} ${row.currency}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${TranslationUtils.tr('ibm_profit')} ${money.format(row.profit)}',
                style: TextStyle(fontSize: 11.sp, color: profitColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IbmCommissionAccountRow row;

  const _AccountRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final money = _IbmCommissionReportScreenState._money;
    final precise = _IbmCommissionReportScreenState._precise;
    final profitColor =
        row.profit >= 0 ? Colors.green.shade700 : Colors.red.shade700;

    return IbmReportRow(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MT5 ${row.mt5Account}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${TranslationUtils.tr('ibm_trades')} ${row.trades}'
                  ' · ${TranslationUtils.tr('ibm_lots')} ${precise.format(row.lots)}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${TranslationUtils.tr('ibm_last_trade')}: '
                  '${row.lastTrade.isEmpty ? '-' : _IbmCommissionReportScreenState.formatDate(row.lastTrade)}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${precise.format(row.commission)} ${row.currency}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${TranslationUtils.tr('ibm_profit')} ${money.format(row.profit)}',
                style: TextStyle(fontSize: 11.sp, color: profitColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
