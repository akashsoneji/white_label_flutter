import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/screens/ibm/utils/ibm_currency.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

Map<String, dynamic> _dataOf(dynamic body) =>
    body is Map && body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : <String, dynamic>{};

int _toInt(dynamic v, {int fallback = 0}) =>
    v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;

num? _toNum(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');


/// "Distribute to Client" (web: My Commission → Distribute to Client).
/// The IB gives part of its commission to one of its direct clients; the
/// request stays `pending` until an admin approves it, and can be cancelled
/// until then. Not scrollable itself — the host scroll view owns scrolling.
class IbmDistributeToClientSection extends StatefulWidget {
  /// Called after a request is sent or cancelled so the host can refresh the
  /// wallet stat cards (available / pending payout).
  final VoidCallback? onChanged;

  const IbmDistributeToClientSection({super.key, this.onChanged});

  @override
  State<IbmDistributeToClientSection> createState() =>
      _IbmDistributeToClientSectionState();
}

class _IbmDistributeToClientSectionState
    extends State<IbmDistributeToClientSection> {
  static const int _noteMaxLength = 500;
  static const int _perPage = 10;

  final IbmApiProvider _api = IbmApiProvider();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoadingForm = true;
  String? _formError;
  Map<String, dynamic> _form = {};

  Map<String, dynamic>? _selectedClient;
  bool _isSubmitting = false;
  String? _successMessage;

  bool _isLoadingHistory = true;
  String? _historyError;
  List<Map<String, dynamic>> _history = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  final Set<int> _cancellingIds = {};

  @override
  void initState() {
    super.initState();
    _noteController.addListener(() => setState(() {}));
    _loadForm();
    _loadHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _currency => _form['currency']?.toString() ?? 'USD';

  String _fmt(num value) => IbmCurrency.format(value, currencyCode: _currency);

  Future<void> _loadForm() async {
    setState(() {
      _isLoadingForm = true;
      _formError = null;
    });
    final res = await _api.getDistributionFormData();
    if (!mounted) return;
    setState(() {
      _isLoadingForm = false;
      if (res.success) {
        _form = _dataOf(res.data);
      } else {
        _formError =
            res.message ?? TranslationUtils.tr('ibm_failed_to_load_data');
      }
    });
  }

  Future<void> _loadHistory({int page = 1}) async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });
    final res = await _api.getDistributionHistory(page: page, perPage: _perPage);
    if (!mounted) return;
    setState(() {
      _isLoadingHistory = false;
      if (!res.success) {
        _historyError =
            res.message ?? TranslationUtils.tr('ibm_failed_to_load_data');
        return;
      }
      final data = _dataOf(res.data);
      _history = (data['rows'] is List ? data['rows'] as List : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final pagination =
          data['pagination'] is Map ? data['pagination'] as Map : const {};
      _page = _toInt(pagination['current_page'], fallback: page);
      _lastPage = _toInt(pagination['last_page'], fallback: _page);
      _total = _toInt(pagination['total'], fallback: _history.length);
    });
  }

  Future<void> _pickClient() async {
    final client = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => const _ClientPickerSheet(),
    );
    if (client != null) setState(() => _selectedClient = client);
  }

  String? _validateAmount(String? value) {
    final amount = num.tryParse((value ?? '').trim());
    if (amount == null || amount <= 0) {
      return TranslationUtils.tr('ibm_amount_must_be_positive');
    }
    final balance = _toNum(_form['balance']) ?? 0;
    if (amount > balance) {
      return TranslationUtils.tr('ibm_amount_exceeds_balance');
    }
    final min = _toNum(_form['min_amount']);
    if (min != null && amount < min) {
      return TranslationUtils.tr('ibm_amount_min').replaceAll('{min}', _fmt(min));
    }
    final max = _toNum(_form['max_amount']);
    if (max != null && amount > max) {
      return TranslationUtils.tr('ibm_amount_max').replaceAll('{max}', _fmt(max));
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_selectedClient == null) {
      CustomToastService.showError(
        message: TranslationUtils.tr('ibm_select_client_first'),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = num.parse(_amountController.text.trim());
    setState(() {
      _isSubmitting = true;
      _successMessage = null;
    });
    final res = await _api.createDistribution(
      clientUserId: _toInt(_selectedClient!['id']),
      amount: amount,
      comment: _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!res.success) {
      CustomToastService.showError(
        message: res.message ?? TranslationUtils.tr('ibm_request_failed'),
      );
      return;
    }
    _amountController.clear();
    _noteController.clear();
    setState(() {
      _selectedClient = null;
      _successMessage = TranslationUtils.trArgs(
        'ibm_amount_sent_for_approval',
        {'amount': _fmt(amount)},
      );
    });
    _loadForm();
    _loadHistory();
    widget.onChanged?.call();
  }

  Future<void> _cancel(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(TranslationUtils.tr('ibm_cancel_distribution')),
        content: Text(TranslationUtils.tr('ibm_cancel_distribution_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(TranslationUtils.tr('ibm_keep')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: AppColors.whiteColor,
              elevation: 0,
            ),
            child: Text(TranslationUtils.tr('account_management_cancel')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _cancellingIds.add(id));
    final res = await _api.cancelDistribution(id);
    if (!mounted) return;
    setState(() => _cancellingIds.remove(id));

    if (res.success) {
      CustomToastService.showSuccess(
        message: res.message ?? TranslationUtils.tr('ibm_request_cancelled'),
      );
      _loadForm();
      _loadHistory(page: _page);
      widget.onChanged?.call();
    } else {
      CustomToastService.showError(
        message: res.message ?? TranslationUtils.tr('ibm_request_failed'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_successMessage != null) ...[
          _SuccessBanner(
            message: _successMessage!,
            onClose: () => setState(() => _successMessage = null),
          ),
          SizedBox(height: 12.h),
        ],
        _buildFormCard(),
        SizedBox(height: 16.h),
        _buildHistoryCard(),
      ],
    );
  }

  Widget _buildFormCard() {
    if (_isLoadingForm) return _ShimmerBox(height: 360.h);
    if (_formError != null) {
      return _Card(child: _ErrorRetry(message: _formError!, onRetry: _loadForm));
    }

    final enabled = _form['enabled'] != false;
    final isFrozen = _form['is_frozen'] == true;
    final canSubmit = enabled && !isFrozen && !_isSubmitting;
    final balance = _toNum(_form['balance']) ?? 0;
    final noteLeft = _noteMaxLength - _noteController.text.characters.length;

    return _Card(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TranslationUtils.tr('ibm_distribute_description'),
              style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
            ),
            if (!enabled || isFrozen) ...[
              SizedBox(height: 10.h),
              _WarningBanner(
                text: TranslationUtils.tr(
                  isFrozen ? 'ibm_wallet_frozen' : 'ibm_distribution_disabled',
                ),
              ),
            ],
            SizedBox(height: 16.h),
            _FieldLabel(TranslationUtils.tr('ibm_client')),
            _ClientField(
              client: _selectedClient,
              enabled: canSubmit,
              onTap: _pickClient,
              onClear: () => setState(() => _selectedClient = null),
            ),
            _FieldHint(TranslationUtils.tr('ibm_client_search_hint')),
            SizedBox(height: 14.h),
            _FieldLabel(TranslationUtils.tr('ibm_amount')),
            TextFormField(
              controller: _amountController,
              enabled: canSubmit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
              decoration: _inputDecoration(),
              validator: _validateAmount,
            ),
            _FieldHint(
              TranslationUtils.trArgs('ibm_available_amount', {
                'amount': _fmt(balance),
              }),
            ),
            SizedBox(height: 14.h),
            _FieldLabel(TranslationUtils.tr('ibm_note_optional')),
            TextFormField(
              controller: _noteController,
              enabled: canSubmit,
              minLines: 3,
              maxLines: 4,
              maxLength: _noteMaxLength,
              style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
              decoration: _inputDecoration().copyWith(counterText: ''),
            ),
            _FieldHint(
              TranslationUtils.trArgs('ibm_characters_left', {
                'count': '$noteLeft',
              }),
            ),
            SizedBox(height: 16.h),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.4),
                  disabledForegroundColor:
                      AppColors.whiteColor.withValues(alpha: 0.85),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.whiteColor,
                        ),
                      )
                    : Text(
                        TranslationUtils.tr('ibm_send_request'),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: border(AppColors.divider),
      enabledBorder: border(AppColors.divider),
      disabledBorder: border(AppColors.divider),
      focusedBorder: border(AppColors.primary),
    );
  }

  Widget _buildHistoryCard() {
    Widget content;
    if (_isLoadingHistory) {
      content = Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.all(12.w),
              child: _ShimmerBox(height: 56.h),
            ),
        ],
      );
    } else if (_historyError != null) {
      content = _ErrorRetry(
        message: _historyError!,
        onRetry: () => _loadHistory(page: _page),
      );
    } else if (_history.isEmpty) {
      content = Padding(
        padding: EdgeInsets.symmetric(vertical: 28.h),
        child: Center(
          child: Text(
            TranslationUtils.tr('ibm_no_distributions_yet'),
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
        ),
      );
    } else {
      content = Column(
        children: [
          for (final row in _history)
            _DistributionRow(
              row: row,
              isCancelling: _cancellingIds.contains(_toInt(row['id'])),
              onCancel: () => _cancel(_toInt(row['id'])),
            ),
        ],
      );
    }

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
            child: Text(
              TranslationUtils.tr('ibm_distribution_history'),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          content,
          if (!_isLoadingHistory && _historyError == null && _total > 0)
            _PaginationFooter(
              page: _page,
              lastPage: _lastPage,
              shown: _history.length,
              total: _total,
              perPage: _perPage,
              onPage: (page) => _loadHistory(page: page),
            ),
        ],
      ),
    );
  }
}

// ─── History ───────────────────────────────────────────────────────────────

/// One request: client name/email, amount, status pill, requested date and
/// Cancel while still pending — the mobile version of the web table row.
class _DistributionRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isCancelling;
  final VoidCallback onCancel;

  const _DistributionRow({
    required this.row,
    required this.isCancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString().toLowerCase() ?? '';
    final currency = row['currency']?.toString();
    final amount = IbmCurrency.format(
      _toNum(row['amount']) ?? 0,
      currencyCode: currency,
    );
    final comment = row['comment']?.toString() ?? '';
    final rejection = row['rejection_reason']?.toString() ?? '';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['client_name']?.toString() ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      row['client_email']?.toString() ?? '',
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
              SizedBox(width: 8.w),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _StatusPill(status: status),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  row['requested_at']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (status == 'pending')
                isCancelling
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          side: BorderSide(color: AppColors.divider),
                          foregroundColor: AppColors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                        ),
                        child: Text(
                          TranslationUtils.tr('account_management_cancel'),
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              comment,
              style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
            ),
          ],
          if (rejection.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              rejection,
              style: TextStyle(fontSize: 11.sp, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  Color get _color {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = 'ibm_status_$status';
    final translated = TranslationUtils.tr(key);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        translated == key ? status : translated.toLowerCase(),
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

/// "Showing 1–10 of 23" with previous / next arrows.
class _PaginationFooter extends StatelessWidget {
  final int page;
  final int lastPage;
  final int shown;
  final int total;
  final int perPage;
  final ValueChanged<int> onPage;

  const _PaginationFooter({
    required this.page,
    required this.lastPage,
    required this.shown,
    required this.total,
    required this.perPage,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final from = (page - 1) * perPage + 1;
    final to = from + shown - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 6.h, 6.w, 6.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              TranslationUtils.trArgs('ibm_showing_range', {
                'from': '$from',
                'to': '$to',
                'total': '$total',
              }),
              style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
            ),
          ),
          if (lastPage > 1) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: page > 1 ? () => onPage(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: page < lastPage ? () => onPage(page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Form pieces ───────────────────────────────────────────────────────────

class _ClientField extends StatelessWidget {
  final Map<String, dynamic>? client;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _ClientField({
    required this.client,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final selected = client;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18.w, color: AppColors.textSecondary),
            SizedBox(width: 8.w),
            Expanded(
              child: selected == null
                  ? Text(
                      TranslationUtils.tr('ibm_search_name_or_email'),
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected['name']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          selected['email']?.toString() ?? '',
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
            if (selected != null && enabled)
              InkWell(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 18.w,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _FieldHint extends StatelessWidget {
  final String text;

  const _FieldHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _SuccessBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 6.w, 10.h),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: onClose,
            child: Icon(Icons.close, size: 16.w, color: Colors.green.shade800),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String text;

  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.sp, color: Colors.orange.shade800),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: Colors.red),
          ),
          SizedBox(height: 10.h),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(TranslationUtils.tr('ibm_retry')),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;

  const _ShimmerBox({required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }
}

// ─── Client picker (search as you type) ────────────────────────────────────

class _ClientPickerSheet extends StatefulWidget {
  const _ClientPickerSheet();

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _clients = [];
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    // Ignore stale responses when the user types faster than the API answers.
    final seq = ++_requestSeq;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await IbmApiProvider().searchDistributionClients(
      search: _searchController.text.trim(),
    );
    if (!mounted || seq != _requestSeq) return;
    setState(() {
      _isLoading = false;
      if (!res.success) {
        _error = res.message ?? TranslationUtils.tr('ibm_failed_to_load_data');
        return;
      }
      final data = _dataOf(res.data);
      _clients = (data['clients'] is List ? data['clients'] as List : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                TranslationUtils.tr('ibm_select_client'),
                style: AppTextStyles.heading.copyWith(fontSize: 15.sp),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: TranslationUtils.tr('ibm_search_name_or_email'),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return ListView.separated(
        itemCount: 5,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (_, __) => _ShimmerBox(height: 48.h),
      );
    }
    if (_error != null) return _ErrorRetry(message: _error!, onRetry: _search);
    if (_clients.isEmpty) {
      return Center(
        child: Text(
          TranslationUtils.tr('ibm_no_clients_found'),
          style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: _clients.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final client = _clients[index];
        final name = client['name']?.toString() ?? '';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 16.r,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(color: AppColors.primary, fontSize: 13.sp),
            ),
          ),
          title: Text(
            name,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary),
          ),
          subtitle: Text(
            client['email']?.toString() ?? '',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
          ),
          onTap: () => Get.back(result: client),
        );
      },
    );
  }
}
