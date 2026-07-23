import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/controllers/pmam/pmam_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/utils/app_picker_theme.dart';

class PmamTradeHistoryScreen extends StatefulWidget {
  const PmamTradeHistoryScreen({super.key, required this.enrollment});

  final Map<String, dynamic> enrollment;

  @override
  State<PmamTradeHistoryScreen> createState() => _PmamTradeHistoryScreenState();
}

class _PmamTradeHistoryScreenState extends State<PmamTradeHistoryScreen> {
  final PmamController _ctrl = Get.find<PmamController>();

  late final String _managerCode;
  late final int _planId;
  late final int _investorId;

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  final ScrollController _listCtrl = ScrollController();
  bool _isLoadingMore = false;

  String _fmtYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _fmtDateShort(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    if (s.isEmpty) return '-';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s.length >= 10 ? s.substring(0, 10) : s;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }

  String _fmtDateTimeShort(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    if (s.isEmpty) return '-';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} $hh:$mi';
  }

  @override
  void initState() {
    super.initState();
    _managerCode = (widget.enrollment['manager_code'] ?? '').toString();
    _planId = int.tryParse((widget.enrollment['plan_id'] ?? 0).toString()) ?? 0;
    _investorId = int.tryParse((widget.enrollment['id'] ?? 0).toString()) ?? 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });

    _listCtrl.addListener(() {
      if (!_listCtrl.hasClients) return;
      final pos = _listCtrl.position;
      if (pos.maxScrollExtent <= 0) return;
      if (pos.pixels >= pos.maxScrollExtent - 240) {
        _loadMoreIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_managerCode.isEmpty || _planId <= 0 || _investorId <= 0) return;
    await _ctrl.fetchTradesForEnrollment(
      managerCode: _managerCode,
      planId: _planId,
      investorId: _investorId,
      dateFrom: _fmtYmd(_from),
      dateTo: _fmtYmd(_to),
      page: 1,
      perPage: 20,
      append: false,
    );
  }

  Future<void> _loadMoreIfNeeded() async {
    if (_isLoadingMore) return;
    if (_ctrl.isTradesLoading.value) return;
    final currentPage = _ctrl.tradesPage.value;
    final totalPages = _ctrl.tradesTotalPages.value;
    if (currentPage >= totalPages) return;

    try {
      _isLoadingMore = true;
      await _ctrl.fetchTradesForEnrollment(
        managerCode: _managerCode,
        planId: _planId,
        investorId: _investorId,
        dateFrom: _fmtYmd(_from),
        dateTo: _fmtYmd(_to),
        page: currentPage + 1,
        perPage: _ctrl.tradesPerPage.value,
        append: true,
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> _pickFrom() async {
    final picked = await AppPickerTheme.showAppDatePicker(
      context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _from = picked);
    await _load();
  }

  Future<void> _pickTo() async {
    final picked = await AppPickerTheme.showAppDatePicker(
      context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _to = picked);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final planName = (widget.enrollment['plan_name'] ?? '').toString();
    final managerName = (widget.enrollment['manager_name'] ?? '').toString();

    Widget metric(String label, String value, Color valueColor) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: AppSvgBackButton(
          onPressed: () => Get.back(closeOverlays: true),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
        title: Text(
          'My P&L Trade History',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (planName.isNotEmpty || managerName.isNotEmpty)
                Text(
                  '$planName • $managerName',
                  style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, color: AppColors.textGrey),
                ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Text(
                    'From',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InkWell(
                      onTap: _pickFrom,
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _fmtDateShort(_from.toIso8601String()),
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16.sp,
                              color: AppColors.textGrey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'To',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTo,
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _fmtDateShort(_to.toIso8601String()),
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16.sp,
                              color: AppColors.textGrey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Obx(() {
                final total = _ctrl.tradesTotal.value;
                final net = _ctrl.tradesNetPnl.value;
                final comm = _ctrl.tradesCommission.value;
                final settled = _ctrl.tradesSettledPnl.value;

                final netPos = net >= 0;
                final commPos = comm >= 0;
                final settledPos = settled >= 0;

                return Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.tradeBackgroundCenterColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          metric(
                            'Trades:',
                            total.toString(),
                            AppColors.textPrimary,
                          ),
                          SizedBox(width: 10.w),
                          metric(
                            'Net P&L:',
                            '${netPos ? '+' : ''}\$${net.abs().toStringAsFixed(2)}',
                            netPos ? AppColors.green : AppColors.error,
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          metric(
                            'Commission:',
                            '${commPos ? '+' : ''}\$${comm.abs().toStringAsFixed(2)}',
                            commPos ? AppColors.green : AppColors.error,
                          ),
                          SizedBox(width: 10.w),
                          metric(
                            'Settled P&L (this period):',
                            '${settledPos ? '+' : ''}\$${settled.abs().toStringAsFixed(2)}',
                            settledPos ? AppColors.green : AppColors.error,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 12.h),
              Expanded(
                child: Obx(() {
                  if (_managerCode.isEmpty ||
                      _planId <= 0 ||
                      _investorId <= 0) {
                    return Center(
                      child: Text(
                        'Missing enrollment info for trades.',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                    );
                  }

                  if (_ctrl.isTradesLoading.value) {
                    return Center(
                      child: CommonLoadingWidget(
                        size: 28,
                        color: AppColors.primary,
                      ),
                    );
                  }

                  final rows = _ctrl.trades;
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        'No trades found for the selected dates.',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: _listCtrl,
                    padding: EdgeInsets.only(bottom: 8.h),
                    itemCount: rows.length + 1,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (_, i) {
                      if (i >= rows.length) {
                        final currentPage = _ctrl.tradesPage.value;
                        final totalPages = _ctrl.tradesTotalPages.value;
                        final hasMore = currentPage < totalPages;
                        if (!hasMore) return SizedBox(height: 6.h);
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Center(
                            child: OutlinedButton(
                              onPressed:
                                  _ctrl.isTradesLoading.value
                                      ? null
                                      : () => _loadMoreIfNeeded(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.primary.withOpacity(0.55),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 10.h,
                                ),
                              ),
                              child:
                                  _ctrl.isTradesLoading.value
                                      ? SizedBox(
                                        width: 16.sp,
                                        height: 16.sp,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Text(
                                        'Load more',
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                            ),
                          ),
                        );
                      }
                      final t = rows[i];
                      final posId = (t['position_id'] ?? '-').toString();
                      final symbol = (t['symbol'] ?? '-').toString();
                      final type = (t['type'] ?? '-').toString();
                      final lot = (t['lot_size'] ?? '-').toString();
                      final closePrice = (t['close_price'] ?? '-').toString();
                      final closeTime = _fmtDateTimeShort(t['close_time']);
                      final profit =
                          double.tryParse((t['profit'] ?? 0).toString()) ?? 0;
                      final comm =
                          double.tryParse(
                            (t['commission_charged'] ?? 0).toString(),
                          ) ??
                          0;

                      final isBuy = type.toLowerCase() == 'buy';
                      final pnlPos = profit >= 0;
                      final pnlColor = pnlPos ? AppColors.green : AppColors.error;
                      final typeBg =
                          isBuy
                              ? AppColors.green.withValues(alpha: 0.12)
                              : AppColors.error.withValues(alpha: 0.12);
                      final typeFg = isBuy ? AppColors.green : AppColors.error;

                      Widget kv(String k, String v, {Color? vColor}) {
                        return Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                k,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 10.sp,
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                v,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.sp,
                                  color: vColor ?? AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.border.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    symbol,
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: typeBg,
                                    borderRadius: BorderRadius.circular(999.r),
                                  ),
                                  child: Text(
                                    type.toUpperCase(),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w900,
                                      color: typeFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              children: [
                                Text(
                                  'Position #$posId',
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 11.sp,
                                    color: AppColors.textGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${pnlPos ? '+' : ''}\$${profit.abs().toStringAsFixed(2)}',
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w900,
                                    color: pnlColor,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              children: [
                                kv('Lot', lot),
                                SizedBox(width: 10.w),
                                kv('Close price', closePrice),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              children: [
                                kv('Close time', closeTime),
                                SizedBox(width: 10.w),
                                kv(
                                  'Commission',
                                  '${comm >= 0 ? '+' : ''}\$${comm.abs().toStringAsFixed(2)}',
                                  vColor:
                                      comm >= 0
                                          ? AppColors.green
                                          : AppColors.error,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
