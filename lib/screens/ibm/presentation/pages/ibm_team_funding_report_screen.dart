import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/screens/ibm/data/ibm_report_models.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_exports_screen.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_report_widgets.dart';
import 'package:crm_app/services/language_service.dart';

/// My Team Deposit / My Team Withdrawal (web: Reports → My Team Deposit /
/// My Team Withdrawal). Both read `GET ibm/portal/client-funding` with a
/// fixed `type`; Export CSV posts `{kind: client_funding, from, to, type}`.
class IbmTeamFundingReportScreen extends StatefulWidget {
  /// `deposit` or `withdrawal`.
  final String type;

  const IbmTeamFundingReportScreen({super.key, required this.type});

  bool get isDeposit => type == 'deposit';

  @override
  State<IbmTeamFundingReportScreen> createState() =>
      _IbmTeamFundingReportScreenState();
}

class _IbmTeamFundingReportScreenState
    extends State<IbmTeamFundingReportScreen> {
  static const int _perPage = 25;
  static final NumberFormat _amountFormat = NumberFormat('#,##0.00');
  static final DateFormat _rowDate = DateFormat('d MMM yyyy HH:mm');

  final IbmApiProvider _api = IbmApiProvider();

  /// Dates being edited in the filter card; empty until the user picks them.
  IbmReportDates _draftDates = const IbmReportDates();

  /// Range the list below was loaded with; null until the first Apply.
  IbmReportDates _appliedDates = const IbmReportDates();

  bool _isLoading = false;
  bool _isLoadingPage = false;
  bool _isExporting = false;
  String? _error;
  IbmFundingReport? _report;

  bool get _hasPendingChanges => !_draftDates.sameAs(_appliedDates);

  Future<void> _load({int page = 1}) async {
    final range = _appliedDates.range;
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

    final res = await _api.getClientFunding(
      from: ibmReportApiDate.format(range.start),
      to: ibmReportApiDate.format(range.end),
      type: widget.type,
      page: page,
      perPage: _perPage,
    );
    if (!mounted) return;

    final body = res.data;
    setState(() {
      _isLoading = false;
      _isLoadingPage = false;
      if (res.success && body is Map && body['data'] is Map) {
        _report = IbmFundingReport.fromJson(
          Map<String, dynamic>.from(body['data'] as Map),
        );
      } else if (!isPageChange) {
        _error = res.message ?? TranslationUtils.tr('ibm_failed_to_load_data');
      }
    });
  }

  void _apply() {
    if (ibmValidateReportDates(_draftDates) == null) return;
    _appliedDates = _draftDates;
    _load();
  }

  Future<void> _export() async {
    final range = ibmValidateReportDates(_draftDates);
    if (range == null) return;
    setState(() => _isExporting = true);
    await runIbmExport(
      kind: 'client_funding',
      filters: {
        'from': ibmReportApiDate.format(range.start),
        'to': ibmReportApiDate.format(range.end),
        'type': widget.type,
      },
    );
    if (mounted) setState(() => _isExporting = false);
  }

  String _formatRowDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : _rowDate.format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.isDeposit;
    return IbmReportScaffold(
      title: TranslationUtils.tr(
        isDeposit ? 'ibm_my_team_deposit' : 'ibm_my_team_withdrawal',
      ),
      subtitle: TranslationUtils.tr(
        isDeposit
            ? 'ibm_my_team_deposit_subtitle'
            : 'ibm_my_team_withdrawal_subtitle',
      ),
      onRefresh: () => _load(page: _report?.pagination.page ?? 1),
      children: [
        IbmReportFilterCard(
          dates: _draftDates,
          onDatesChanged: (dates) => setState(() => _draftDates = dates),
          onApply: _apply,
          onExport: _export,
          isApplying: _isLoading,
          isExporting: _isExporting,
          hasPendingChanges: _hasPendingChanges,
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

    final isDeposit = widget.isDeposit;
    final valueColor = isDeposit ? Colors.green.shade700 : Colors.red.shade700;
    final sign = isDeposit ? '+' : '−';

    return [
      IbmCurrencySummaryGrid(
        cards: [
          for (final total in report.totals)
            IbmCurrencySummaryCard(
              currency: total.currency,
              label: TranslationUtils.tr(
                isDeposit ? 'ibm_filter_deposits' : 'ibm_filter_withdrawals',
              ),
              value:
                  '$sign${_amountFormat.format(isDeposit ? total.deposit : total.withdrawal)}',
              valueColor: valueColor,
            ),
        ],
      ),
      if (report.totals.isNotEmpty) SizedBox(height: 12.h),
      IbmReportListCard(
        title: TranslationUtils.tr('ibm_funding_movements'),
        total: report.pagination.total,
        page: report.pagination.page,
        lastPage: report.pagination.lastPage,
        perPage: _perPage,
        isLoadingPage: _isLoadingPage,
        onPage: (page) => _load(page: page),
        rows: [
          for (final row in report.rows)
            _FundingRow(row: row, date: _formatRowDate(row.movedAt)),
        ],
      ),
    ];
  }
}

/// Mobile version of a "Funding movements" table row:
/// client + Deposit/Withdrawal pill on the left, amount + status on the right,
/// date underneath.
class _FundingRow extends StatelessWidget {
  static final NumberFormat _amountFormat = NumberFormat('#,##0.00');

  final IbmFundingRow row;
  final String date;

  const _FundingRow({required this.row, required this.date});

  @override
  Widget build(BuildContext context) {
    final color = row.isDeposit ? Colors.green.shade700 : Colors.red.shade700;
    return IbmReportRow(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.clientName.isEmpty ? '-' : row.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  row.clientEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    IbmReportPill(
                      text: TranslationUtils.tr(
                        row.isDeposit ? 'ibm_type_deposit' : 'ibm_type_withdrawal',
                      ),
                      color: color,
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_amountFormat.format(row.amount)} ${row.currency}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6.h),
              IbmReportStatusText(status: row.status),
            ],
          ),
        ],
      ),
    );
  }
}
