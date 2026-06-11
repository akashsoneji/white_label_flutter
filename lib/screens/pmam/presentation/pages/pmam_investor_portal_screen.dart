import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/pmam/view_models/pmam_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/models/pmam_model.dart';
import 'package:crm_app/screens/pmam/presentation/pages/pmam_trade_history_screen.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class PmamInvestorPortalScreen extends StatefulWidget {
  const PmamInvestorPortalScreen({super.key});

  @override
  State<PmamInvestorPortalScreen> createState() =>
      _PmamInvestorPortalScreenState();
}

class _PmamInvestorPortalScreenState extends State<PmamInvestorPortalScreen>
    with SingleTickerProviderStateMixin {
  late final PmamController _ctrl;
  late final TabController _tabCtrl;

  String _searchQuery = '';
  String _myFilter = 'all';
  Timer? _debounce;

  String _fmtMoney(dynamic v) {
    final d = double.tryParse((v ?? 0).toString()) ?? 0;
    return '\$${d.toStringAsFixed(2)}';
  }

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
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} $hh:$min';
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    if (Get.isRegistered<PmamController>()) {
      _ctrl = Get.find<PmamController>();
    } else {
      _ctrl = Get.put(PmamController());
    }
    // Avoid triggering reactive updates during first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.loadManagersDataTable();
      _ctrl.loadInvestorPortal();
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _ctrl.loadManagersDataTable(search: value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: const AppBackButton(),

        title: Text('Investor Portal', style: AppTextStyles.heading),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(46.h),
          child: Container(
            color: AppColors.whiteColor,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textGrey,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(fontSize: 14.sp),
              tabs: const [
                Tab(text: 'Fund Managers'),
                Tab(text: 'My Investments'),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (_ctrl.isLoading.value &&
            _ctrl.enrollments.isEmpty &&
            _ctrl.openAllocations.isEmpty) {
          return Center(
            child: CommonLoadingWidget(size: 40, color: AppColors.primary),
          );
        }
        return TabBarView(
          controller: _tabCtrl,
          children: [_buildFundManagersTab(), _buildMyInvestmentsTab()],
        );
      }),
    );
  }

  Future<void> _showAddFundsDialog(int pmamInvestorId) async {
    final amountCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 18.w),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add funds',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'The amount will be locked and deposited to the pool immediately. It will apply to future trades only.',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Amount (\$)',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '100',
                    filled: true,
                    fillColor: AppColors.tradeBackgroundCenterColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: AppColors.dividerLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: AppColors.dividerLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.dividerMedium),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Obx(() {
                        final busy = _ctrl.isLoading.value;
                        return ElevatedButton(
                          onPressed:
                              busy
                                  ? null
                                  : () async {
                                    final amt =
                                        double.tryParse(
                                          amountCtrl.text.trim(),
                                        ) ??
                                        0;
                                    if (amt <= 0) return;
                                    final ok = await _ctrl.depositToEnrollment(
                                      pmamInvestorId: pmamInvestorId,
                                      amount: amt,
                                    );
                                    if (ok && mounted) Navigator.of(ctx).pop();
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          child:
                              busy
                                  ? SizedBox(
                                    width: 18.sp,
                                    height: 18.sp,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(
                                    'Add funds',
                                    style: TextStyle(
                                      color: AppColors.whiteColor,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmUnsubscribe(int pmamInvestorId) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Withdraw'),
          content: const Text(
            'Are you sure you want to withdraw from this plan? This will trigger proportional trade settlement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _ctrl.unsubscribe(pmamInvestorId);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _showTradesSheet(Map<String, dynamic> enrollment) async {
    final managerCode = (enrollment['manager_code'] ?? '').toString();
    final planId = int.tryParse((enrollment['plan_id'] ?? 0).toString()) ?? 0;
    final investorId = int.tryParse((enrollment['id'] ?? 0).toString()) ?? 0;
    if (managerCode.isEmpty || planId <= 0 || investorId <= 0) return;

    DateTime from = DateTime.now();
    DateTime to = DateTime.now();
    var didInitialLoad = false;

    Future<void> load() async {
      await _ctrl.fetchTradesForEnrollment(
        managerCode: managerCode,
        planId: planId,
        investorId: investorId,
        dateFrom: _fmtYmd(from),
        dateTo: _fmtYmd(to),
        page: 1,
        perPage: 20,
      );
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (!didInitialLoad) {
              didInitialLoad = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                load();
              });
            }

            Future<void> pickFrom() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: from,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              setSheetState(() => from = picked);
              await load();
            }

            Future<void> pickTo() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: to,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              setSheetState(() => to = picked);
              await load();
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.w,
                  right: 16.w,
                  top: 12.h,
                  bottom: 16.h,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.82,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'My P&L Trade History',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(
                        '${enrollment['plan_name'] ?? ''} • ${enrollment['manager_name'] ?? ''}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: InkWell(
                              onTap: pickFrom,
                              borderRadius: BorderRadius.circular(10.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.whiteColor,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: AppColors.dividerLight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _fmtDateShort(from.toIso8601String()),
                                        style: TextStyle(
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
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: InkWell(
                              onTap: pickTo,
                              borderRadius: BorderRadius.circular(10.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.whiteColor,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: AppColors.dividerLight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _fmtDateShort(to.toIso8601String()),
                                        style: TextStyle(
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
                      SizedBox(height: 12.h),
                      Obx(() {
                        final total = _ctrl.tradesTotal.value;
                        final net = _ctrl.tradesNetPnl.value;
                        final comm = _ctrl.tradesCommission.value;
                        final settled = _ctrl.tradesSettledPnl.value;
                        final netPos = net >= 0;
                        final commPos = comm >= 0;
                        final settledPos = settled >= 0;

                        Widget metric(String label, String value, Color color) {
                          return Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppColors.textGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppColors.tradeBackgroundCenterColor,
                            borderRadius: BorderRadius.circular(12.r),
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
                                    netPos ? AppColors.green : AppColors.red,
                                  ),
                                ],
                              ),
                              SizedBox(height: 10.h),
                              Row(
                                children: [
                                  metric(
                                    'Commission:',
                                    '${commPos ? '+' : ''}\$${comm.abs().toStringAsFixed(2)}',
                                    commPos ? AppColors.green : AppColors.red,
                                  ),
                                  SizedBox(width: 10.w),
                                  metric(
                                    'Settled P&L (this period):',
                                    '${settledPos ? '+' : ''}\$${settled.abs().toStringAsFixed(2)}',
                                    settledPos
                                        ? AppColors.green
                                        : AppColors.red,
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
                          if (_ctrl.errorMessage.value.isNotEmpty &&
                              _ctrl.trades.isEmpty &&
                              !_ctrl.isTradesLoading.value) {
                            return Center(
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppColors.red.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.red,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Text(
                                        _ctrl.errorMessage.value,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: AppColors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: load,
                                      child: const Text('Retry'),
                                    ),
                                  ],
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
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            );
                          }

                          return LayoutBuilder(
                            builder: (context, c) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 860.w,
                                  height: c.maxHeight,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8.h),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                'POSITION ID',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: AppColors.textGrey,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'SYMBOL',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: AppColors.textGrey,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'TYPE',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: AppColors.textGrey,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'LOT',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: AppColors.textGrey,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                'CLOSE PRICE',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: AppColors.textGrey,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 4,
                                              child: Text(
                                                'CLOSE TIME',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: AppColors.textGrey,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                'COMMISSION',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: AppColors.textGrey,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                'MY P&L',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: AppColors.textGrey,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height: 1,
                                        color: AppColors.dividerLight,
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: rows.length,
                                          itemBuilder: (_, i) {
                                            final t = rows[i];
                                            final posId =
                                                (t['position_id'] ?? '-')
                                                    .toString();
                                            final symbol =
                                                (t['symbol'] ?? '-').toString();
                                            final type =
                                                (t['type'] ?? '-').toString();
                                            final lot =
                                                (t['lot_size'] ?? '-')
                                                    .toString();
                                            final closePrice =
                                                (t['close_price'] ?? '-')
                                                    .toString();
                                            final closeTime = _fmtDateTimeShort(
                                              t['close_time'],
                                            );
                                            final profitStr =
                                                (t['profit'] ?? '').toString();
                                            final profit =
                                                double.tryParse(profitStr) ?? 0;
                                            final commStr =
                                                (t['commission_charged'] ?? '')
                                                    .toString();
                                            final comm =
                                                double.tryParse(commStr) ?? 0;

                                            final isBuy =
                                                type.toLowerCase() == 'buy';
                                            final pnlPos = profit >= 0;
                                            final pnlColor =
                                                pnlPos
                                                    ? AppColors.green
                                                    : AppColors.red;

                                            return Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10.h,
                                              ),
                                              decoration: const BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: AppColors.dividerLightAlt,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      posId,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      symbol,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      type.toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color:
                                                            isBuy
                                                                ? AppColors
                                                                    .green
                                                                : AppColors.red,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      lot,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      closePrice,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 4,
                                                    child: Text(
                                                      closeTime,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      '${comm >= 0 ? '+' : ''}${comm.toStringAsFixed(2)}',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color:
                                                            comm >= 0
                                                                ? AppColors
                                                                    .green
                                                                : AppColors.red,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      '${pnlPos ? '+' : ''}${profit.toStringAsFixed(2)}',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color: pnlColor,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
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
          },
        );
      },
    );
  }

  Widget _buildFundManagersTab() {
    return Column(
      children: [
        SizedBox(height: 12.h),
        // Search bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _onSearchChanged(v);
              },
              style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search managers by name or code…',
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textGrey,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textGrey,
                  size: 20.sp,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 13.h,
                  horizontal: 16.w,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        // Content
        Expanded(
          child: Obx(() {
            if (_ctrl.isManagersLoading.value) {
              return Center(
                child: CommonLoadingWidget(size: 36, color: AppColors.primary),
              );
            }
            final managers = _ctrl.managersList;
            if (managers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_search_rounded,
                      size: 48.sp,
                      color: AppColors.textGrey.withOpacity(0.4),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No fund managers available'
                          : 'No results for "$_searchQuery"',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh:
                  () => _ctrl.loadManagersDataTable(search: _searchQuery),
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: managers.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, i) {
                  // Map model properties
                  final PmamManager manager = managers[i];
                  final name = manager.managerName ?? 'Unknown';
                  final code = manager.managerCode;
                  final initials =
                      name
                          .split(' ')
                          .take(2)
                          .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
                          .join();
                  final profit = manager.profitPercentage;
                  final profitIsPos = profit >= 0;
                  final totalAum = manager.totalAum.toStringAsFixed(0);
                  final investorsCount = manager.totalInvestors;
                  final avgCommission = manager.avgCommission.toStringAsFixed(
                    0,
                  );
                  final memberSince = manager.memberSince ?? '';

                  return GestureDetector(
                    onTap:
                        () => Get.toNamed(
                          AppPages.PMAM_MANAGER_DETAIL,
                          arguments: manager,
                        ),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 22.r,
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.15,
                                ),
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (code.isNotEmpty)
                                      Text(
                                        code,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    if (memberSince.isNotEmpty)
                                      Text(
                                        'Since $memberSince',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textGrey,
                                size: 24.sp,
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          // Stats chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _PerfChip(
                                  label: 'Profit %',
                                  value:
                                      '${profitIsPos ? '+' : ''}${profit.toStringAsFixed(2)}%',
                                  color:
                                      profitIsPos
                                          ? AppColors.green
                                          : AppColors.red,
                                ),
                                SizedBox(width: 8.w),
                                _PerfChip(label: 'AUM', value: '\$$totalAum'),
                                SizedBox(width: 8.w),
                                _PerfChip(
                                  label: 'Investors',
                                  value: '$investorsCount',
                                ),
                                SizedBox(width: 8.w),
                                _PerfChip(
                                  label: 'Commission',
                                  value: '$avgCommission%',
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMyInvestmentsTab() {
    final all = _ctrl.enrollments;
    final openAllocations = _ctrl.openAllocations;
    final fundEntries = _ctrl.fundEntries;

    double totalInvested = 0, totalPnl = 0, netBalance = 0;
    int activePlans = 0;
    for (final inv in all) {
      totalInvested +=
          double.tryParse((inv['invested_amount'] ?? 0).toString()) ?? 0;
      totalPnl += double.tryParse((inv['total_pnl'] ?? 0).toString()) ?? 0;
      netBalance +=
          double.tryParse((inv['current_value'] ?? 0).toString()) ?? 0;
      if ((inv['status'] ?? '') == 'active') activePlans++;
    }

    final filtered =
        _myFilter == 'all'
            ? all
            : _myFilter == 'active'
            ? all.where((i) => i['status'] == 'active').toList()
            : all.where((i) => i['status'] != 'active').toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4.h),
          if (_ctrl.errorMessage.value.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.red.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.red, size: 18.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      _ctrl.errorMessage.value,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _ctrl.loadInvestorPortal(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],
          // Summary stats
          LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 360;
              final gap = isNarrow ? 8.w : 10.w;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SummaryChip(
                      label: 'Total Invested',
                      value: '\$${totalInvested.toStringAsFixed(2)}',
                    ),
                    SizedBox(width: gap),
                    _SummaryChip(
                      label: 'Total P&L',
                      value:
                          '${totalPnl >= 0 ? '+' : ''}\$${totalPnl.toStringAsFixed(2)}',
                      valueColor:
                          totalPnl >= 0 ? AppColors.green : AppColors.red,
                    ),
                    SizedBox(width: gap),
                    _SummaryChip(
                      label: 'Net Balance',
                      value: '\$${netBalance.toStringAsFixed(2)}',
                    ),
                    SizedBox(width: gap),
                    _SummaryChip(
                      label: 'Active Plans',
                      value: '$activePlans',
                      valueColor: AppColors.primary,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 16.h),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SmallFilterChip(
                  label: 'All',
                  selected: _myFilter == 'all',
                  onTap: () => setState(() => _myFilter = 'all'),
                ),
                SizedBox(width: 8.w),
                _SmallFilterChip(
                  label:
                      'Active (${all.where((i) => i['status'] == 'active').length})',
                  selected: _myFilter == 'active',
                  onTap: () => setState(() => _myFilter = 'active'),
                ),
                SizedBox(width: 8.w),
                _SmallFilterChip(
                  label:
                      'Inactive (${all.where((i) => i['status'] != 'active').length})',
                  selected: _myFilter == 'inactive',
                  onTap: () => setState(() => _myFilter = 'inactive'),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),

          if (filtered.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40.h),
              child: Center(
                child: Text(
                  _ctrl.errorMessage.value.isNotEmpty
                      ? 'Unable to load investments.\nTap Retry to try again.'
                      : 'No investments yet.\nBrowse Fund Managers to get started!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (_, i) {
                final inv = filtered[i];
                final status = (inv['status'] ?? '').toString();
                final pnl =
                    double.tryParse((inv['total_pnl'] ?? 0).toString()) ?? 0;
                final pmamInvestorId =
                    int.tryParse((inv['id'] ?? 0).toString()) ?? 0;
                final statusColor =
                    status == 'active'
                        ? AppColors.green
                        : status == 'pending'
                        ? AppColors.pendingStatusDark
                        : AppColors.textGrey;
                return Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inv['plan_name'] ??
                                      inv['plan']?['plan_name'] ??
                                      'Unnamed Plan',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Manager: ${inv['manager_name'] ?? inv['manager']?['name'] ?? '-'}  •  ${inv['commission_percentage'] ?? 0}% commission',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              status.isEmpty ? 'UNKNOWN' : status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      _InvestmentInfoRow(
                        'Account',
                        (inv['account_number'] ?? '-').toString(),
                      ),
                      _InvestmentInfoRow(
                        'Invested',
                        _fmtMoney(inv['invested_amount']),
                      ),
                      _InvestmentInfoRow(
                        'Total P&L',
                        '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                        valueColor: pnl >= 0 ? AppColors.green : AppColors.red,
                      ),
                      _InvestmentInfoRow(
                        'Current Value',
                        _fmtMoney(inv['current_value']),
                      ),
                      _InvestmentInfoRow(
                        'Locked',
                        _fmtMoney(inv['pmam_locked_amount']),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => PmamTradeHistoryScreen(
                                          enrollment: inv,
                                        ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                              ),
                              child: Text(
                                'View P&L Trades',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (status == 'active' && pmamInvestorId > 0) ...[
                            SizedBox(width: 8.w),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => _showAddFundsDialog(pmamInvestorId),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.primary.withOpacity(0.6),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 8.h),
                                ),
                                child: Text(
                                  'Add Funds',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => _confirmUnsubscribe(pmamInvestorId),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.red.withOpacity(0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 8.h),
                                ),
                                child: Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    color: AppColors.red,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          SizedBox(height: 14.h),
          Container(
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              collapsedIconColor:AppColors.primary,
              iconColor: AppColors.primary,
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              collapsedShape: const RoundedRectangleBorder(
                side: BorderSide.none,
              ),
              title: Text(
                'Fund Entries',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              children: [
                if (fundEntries.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      left: 14.w,
                      right: 14.w,
                      bottom: 14.h,
                      top: 4.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18.sp,
                          color: AppColors.textGrey,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'No fund entries found.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _ctrl.loadInvestorPortal(),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.only(
                      left: 14.w,
                      right: 14.w,
                      bottom: 14.h,
                    ),
                    child: Column(
                      children: [
                        ...fundEntries.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final e = entry.value;
                          final plan =
                              (e['plan_name'] ??
                                      e['plan']?['plan_name'] ??
                                      e['plan'] ??
                                      '-')
                                  .toString();
                          final rawAmount = e['amount'] ?? e['invested_amount'];
                          final amountText =
                              rawAmount == null ? '-' : _fmtMoney(rawAmount);
                          final type =
                              (e['type_label'] ??
                                      e['type'] ??
                                      e['entry_type'] ??
                                      '-')
                                  .toString();
                          final status = (e['status'] ?? '-').toString();
                          final statusLower = status.toLowerCase();
                          final isDeposit = type.toLowerCase() == 'deposit';
                          final statusColor = statusLower == 'active'
                              ? AppColors.green
                              : statusLower == 'withdrawn'
                                  ? AppColors.red
                                  : AppColors.textGrey;
                          final date =
                              e['entry_time'] ??
                              e['date'] ??
                              e['created_at'] ??
                              e['open_time'];

                          final transactionColor =
                              isDeposit ? AppColors.green : AppColors.red;
                          

                          return Container(
                            margin: EdgeInsets.only(
                              top: idx == 0 ? 2.h : 10.h,
                            ),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: AppColors.whiteColor,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: AppColors.dividerLight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: transactionColor,
                                    width: 4.w,
                                  ),
                                ),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row 1: Type (+ / - Label) & Amount
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$type',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: transactionColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        amountText,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  // Row 2: Plan and Status Badge
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: RichText(
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              color: AppColors.textGrey,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Plan: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              TextSpan(
                                                text: plan,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8.w,
                                          vertical: 3.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                        child: Text(
                                          status == '-'
                                              ? '-'
                                              : status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            color: statusColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  // Divider line
                                  Container(
                                    height: 1,
                                    color: AppColors.dividerLight.withOpacity(0.5),
                                  ),
                                  SizedBox(height: 8.h),
                                  // Row 3: Date
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 13.sp,
                                        color: AppColors.textGrey,
                                      ),
                                      SizedBox(width: 6.w),
                                      RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            color: AppColors.textGrey,
                                          ),
                                          children: [
                                            const TextSpan(
                                              text: 'Date: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            TextSpan(
                                              text: _fmtDateTimeShort(date),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        SizedBox(height: 2.h),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          if (openAllocations.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                collapsedShape: const RoundedRectangleBorder(
                  side: BorderSide.none,
                ),
                title: Text(
                  'Open Positions',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: 14.w,
                      right: 14.w,
                      bottom: 12.h,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: openAllocations.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (_, idx) {
                        final a = openAllocations[idx];
                        final plan = (a['plan_name'] ?? '-').toString();
                        final symbol = (a['trade_symbol'] ?? '-').toString();
                        final lot = (a['allocated_lot'] ?? '-').toString();
                        final openPrice = (a['open_price'] ?? '-').toString();
                        final openTime = _fmtDateTimeShort(a['open_time']);
                        final type = (a['trade_type'] ?? 0).toString();
                        final isBuy = type == '0';

                        return Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: AppColors.tradeBackgroundCenterColor,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Text(
                                    symbol,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isBuy
                                              ? AppColors.green
                                              : AppColors.red)
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Text(
                                      isBuy ? 'BUY' : 'SELL',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            isBuy
                                                ? AppColors.green
                                                : AppColors.red,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Lot $lot',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Open $openPrice',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    openTime,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }
}

class _PerfChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _PerfChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.tradeBackgroundCenterColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9.sp, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryChip({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

class _SmallFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SmallFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.dividerMedium,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.whiteColor : AppColors.textGrey,
          ),
        ),
      ),
    );
  }
}

class _InvestmentInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InvestmentInfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
