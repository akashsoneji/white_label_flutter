import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/screens/ibm/data/ibm_report_models.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_exports_screen.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_report_widgets.dart';
import 'package:crm_app/services/language_service.dart';

/// IB Withdraw (web: Reports → IB Withdraw). The IB's own payout requests from
/// its commission wallet: `GET ibm/portal/payout-report`; Export CSV posts
/// `{kind: ib_payouts, from, to, status}`.
class IbmPayoutReportScreen extends StatefulWidget {
  const IbmPayoutReportScreen({super.key});

  @override
  State<IbmPayoutReportScreen> createState() => _IbmPayoutReportScreenState();
}

class _IbmPayoutReportScreenState extends State<IbmPayoutReportScreen> {
  static const int _perPage = 25;
  static const List<String> _statuses = [
    'pending',
    'approved',
    'paid',
    'rejected',
    'cancelled',
  ];
  static final NumberFormat _money = NumberFormat('#,##0.00');
  static final DateFormat _rowDate = DateFormat('d MMM yyyy HH:mm');

  final IbmApiProvider _api = IbmApiProvider();

  IbmReportDates _draftDates = const IbmReportDates();
  String? _draftStatus;
  IbmReportDates _appliedDates = const IbmReportDates();
  String? _appliedStatus;

  bool _isLoading = false;
  bool _isLoadingPage = false;
  bool _isExporting = false;
  String? _error;
  IbmPayoutReport? _report;

  bool get _hasPendingChanges =>
      !_draftDates.sameAs(_appliedDates) || _draftStatus != _appliedStatus;

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

    final res = await _api.getPayoutReport(
      from: ibmReportApiDate.format(range.start),
      to: ibmReportApiDate.format(range.end),
      status: _appliedStatus,
      page: page,
      perPage: _perPage,
    );
    if (!mounted) return;

    final body = res.data;
    setState(() {
      _isLoading = false;
      _isLoadingPage = false;
      if (res.success && body is Map && body['data'] is Map) {
        _report = IbmPayoutReport.fromJson(
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
    _appliedStatus = _draftStatus;
    _load();
  }

  Future<void> _export() async {
    final range = ibmValidateReportDates(_draftDates);
    if (range == null) return;
    setState(() => _isExporting = true);
    await runIbmExport(
      kind: 'ib_payouts',
      filters: {
        'from': ibmReportApiDate.format(range.start),
        'to': ibmReportApiDate.format(range.end),
        'status': _draftStatus ?? '',
      },
    );
    if (mounted) setState(() => _isExporting = false);
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : _rowDate.format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return IbmReportScaffold(
      title: TranslationUtils.tr('ibm_ib_withdraw'),
      subtitle: TranslationUtils.tr('ibm_ib_withdraw_subtitle'),
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
          extraFilters: [
            IbmReportDropdown(
              label: TranslationUtils.tr('ibm_status'),
              value: _draftStatus,
              options: {
                null: TranslationUtils.tr('ibm_filter_all'),
                for (final status in _statuses)
                  status: TranslationUtils.tr('ibm_status_$status'),
              },
              onChanged: (v) => setState(() => _draftStatus = v),
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
      IbmCurrencySummaryGrid(
        cards: [
          for (final total in report.totals)
            IbmCurrencySummaryCard(
              currency: total.currency,
              label: TranslationUtils.tr('ibm_total_payouts'),
              value: _money.format(total.amount),
              valueColor: AppColors.textPrimary,
            ),
        ],
      ),
      if (report.totals.isNotEmpty) SizedBox(height: 12.h),
      IbmReportListCard(
        title: TranslationUtils.tr('ibm_payout_requests'),
        total: report.pagination.total,
        page: report.pagination.page,
        lastPage: report.pagination.lastPage,
        perPage: _perPage,
        isLoadingPage: _isLoadingPage,
        onPage: (page) => _load(page: page),
        rows: [
          for (final row in report.rows)
            IbmReportRow(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.method.isEmpty ? '#${row.id}' : row.method,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${TranslationUtils.tr('ibm_requested')}: '
                          '${row.requestedAt.isEmpty ? '-' : _formatDate(row.requestedAt)}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (row.paidAt.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            '${TranslationUtils.tr('ibm_status_paid')}: ${_formatDate(row.paidAt)}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_money.format(row.amount)} ${row.currency}',
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
            ),
        ],
      ),
    ];
  }
}
