import 'package:crm_app/widgets/dashBorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'copy_trading_main_screen.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_copier_subscriptions_controller.dart'
    show
        TradeItem,
        CopierSubscriptionItem,
        CopyTradingCopierSubscriptionsController;
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/components/edit_subscription_sheet.dart';

// ─── Screen ───────────────────────────────────────────────────────
class InvestmentDetailScreen extends StatefulWidget {
  final int? subscriptionId;
  final String traderName;
  final String traderBadge;
  final String equity;

  const InvestmentDetailScreen({
    super.key,
    this.subscriptionId,
    required this.traderName,
    required this.traderBadge,
    required this.equity,
  });

  @override
  State<InvestmentDetailScreen> createState() => _InvestmentDetailScreenState();
}

class _InvestmentDetailScreenState extends State<InvestmentDetailScreen> {
  // 0=Summary, 1=Trades, 2=Options
  int _selectedTab = 0;

  // Toggle for Receive Trading Notifications
  bool _notificationsEnabled = true;

  late final CopyTradingCopierSubscriptionsController _subscriptionsCtrl;
  Map<String, dynamic>? _detailData;

  List<TradeItem> _trades = [];
  bool _isLoadingTrades = false;
  String _tradesError = '';

  CopierSubscriptionItem? get subscriptionItem => _subscriptionsCtrl
      .subscriptions
      .firstWhereOrNull((e) => e.id == widget.subscriptionId);

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<CopyTradingCopierSubscriptionsController>(
      tag: 'copytrading:my_investments',
    )) {
      _subscriptionsCtrl = Get.find<CopyTradingCopierSubscriptionsController>(
        tag: 'copytrading:my_investments',
      );
    } else {
      _subscriptionsCtrl = Get.put(CopyTradingCopierSubscriptionsController());
    }
    _fetchDetail();
    _fetchTrades();
  }

  Future<void> _fetchDetail() async {
    if (!mounted) return;
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSubscriptionDetail(
          widget.subscriptionId ?? 0,
        ),
      );
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _detailData = response.data;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchTrades() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTrades = true;
      _tradesError = '';
    });
    try {
      final response = await ApiService.get(
        endpoint: ApiConstants.copyTradingCopierSubscriptionTrades(
          widget.subscriptionId ?? 0,
          page: 1,
          limit: 100,
        ),
      );
      if (!mounted) return;
      if (response.success && response.data != null) {
        final nestedData = response.data?['data'];
        final data = nestedData is Map ? nestedData['data'] : null;
        if (data is List) {
          setState(() {
            _trades =
                data
                    .whereType<Map>()
                    .map((e) => TradeItem.fromJson(e.cast<String, dynamic>()))
                    .toList();
          });
        }
      } else {
        setState(() {
          _tradesError = response.message ?? 'Failed to load trades';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tradesError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTrades = false;
        });
      }
    }
  }

  void _onPauseTap() async {
    final res = await _subscriptionsCtrl.pause(widget.subscriptionId ?? 0);
    if (res.success) {
      CustomToastService.showSuccess(
        title: 'Success',
        message: 'Subscription paused',
      );
      _fetchDetail();
    } else {
      CustomToastService.showError(
        title: 'Error',
        message: res.message ?? 'Failed to pause',
      );
    }
  }

  void _onResumeTap() async {
    final res = await _subscriptionsCtrl.resume(widget.subscriptionId ?? 0);
    if (res.success) {
      CustomToastService.showSuccess(
        title: 'Success',
        message: 'Subscription resumed',
      );
      _fetchDetail();
    } else {
      CustomToastService.showError(
        title: 'Error',
        message: res.message ?? 'Failed to resume',
      );
    }
  }

  void _onStopTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Stop investment?'),
            content: Text(
              'This is permanent. You\'ll need to re-subscribe.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text('Stop'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final res = await _subscriptionsCtrl.stop(widget.subscriptionId ?? 0);
    if (res.success) {
      CustomToastService.showSuccess(
        title: 'Success',
        message: 'Subscription stopped',
      );
      _fetchDetail();
    } else {
      CustomToastService.showError(
        title: 'Error',
        message: res.message ?? 'Failed to stop',
      );
    }
  }

  void _showAddCapitalDialog() async {
    final amountCtrl = TextEditingController();
    final amount = await showDialog<num?>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Add capital'),
            content: TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(hintText: 'Amount (USD)'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final v = num.tryParse(amountCtrl.text.trim());
                  if (v == null || v <= 0) return;
                  Navigator.of(ctx).pop(v);
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
    if (amount == null) return;
    final res = await _subscriptionsCtrl.addCapital(
      subscriptionId: widget.subscriptionId ?? 0,
      amount: amount,
    );
    if (res.success) {
      CustomToastService.showSuccess(
        title: 'Success',
        message: 'Capital added successfully',
      );
      _fetchDetail();
    } else {
      CustomToastService.showError(
        title: 'Error',
        message: res.message ?? 'Failed to add capital',
      );
    }
  }



  String getCopyMethodDisplay(CopierSubscriptionItem? item) {
    if (item == null) return 'Equal x1';
    final method = item.copyMethod.toLowerCase();
    if (method == 'multiplier') {
      return 'Multiplier: x${item.lotMultiplier.toStringAsFixed(2)}';
    } else if (method == 'fixed') {
      return 'Fixed Lot: ${item.fixedLotSize}';
    } else if (method == 'risk') {
      return 'Risk: ${item.riskPercent}%';
    }
    return 'Equal x1';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/trade/arro_back.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Your Investment', style: AppTextStyles.screenTitle),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Trader header card ──
          _buildTraderHeader(),

          // ── Tab selector ──
          _buildTabBar(),

          // ── Tab content ──
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Trader header card
  // ─────────────────────────────────────────────────────────────────
  Widget _buildTraderHeader() {
    final displayEquity =
        _detailData != null && _detailData!['current_equity'] != null
            ? '\$${double.tryParse(_detailData!['current_equity'].toString())?.toStringAsFixed(2) ?? _detailData!['current_equity']}'
            : widget.equity;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        elevation: 0.8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14),
          child: Row(
            children: [
              // Avatar
              SvgPicture.asset('assets/svg/copy_trading/person_svg.svg'),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.traderName,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Equity',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                ],
              ),
              Spacer(),
              Text(
                displayEquity,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Tab bar — 3 pill buttons
  // ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          _TabButton(
            label: 'Summary',
            index: 0,
            selected: _selectedTab,
            onTap: _onTab,
          ),
          SizedBox(width: 8.w),
          _TabButton(
            label: 'Trades',
            index: 1,
            selected: _selectedTab,
            onTap: _onTab,
          ),
          SizedBox(width: 8.w),
          _TabButton(
            label: 'Options',
            index: 2,
            selected: _selectedTab,
            onTap: _onTab,
          ),
        ],
      ),
    );
  }

  void _onTab(int i) => setState(() => _selectedTab = i);

  // ─────────────────────────────────────────────────────────────────
  // Tab content router
  // ─────────────────────────────────────────────────────────────────
  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildSummaryTab();
      case 1:
        return _buildTradesTab();
      case 2:
        return _buildOptionsTab();
      default:
        return SizedBox();
    }
  }

  Widget _buildSummaryTab() {
    final item = subscriptionItem;

    // Profit
    final profitVal =
        _detailData != null && _detailData!['total_profit_loss'] != null
            ? double.tryParse(_detailData!['total_profit_loss'].toString()) ??
                0.0
            : (item != null ? item.totalPnl.toDouble() : 0.0);
    final profitDisplay = '\$${profitVal.toStringAsFixed(2)}';

    // Capital
    final capitalVal = item != null ? item.capitalAmount.toDouble() : 0.0;

    // Float profit
    final floatProfitVal =
        _detailData != null &&
                _detailData!['current_equity'] != null &&
                item != null
            ? (double.tryParse(_detailData!['current_equity'].toString()) ??
                    0.0) -
                item.accountBalance.toDouble()
            : 0.0;
    final floatProfitDisplay = '\$${floatProfitVal.toStringAsFixed(2)}';

    // Gain
    double gainVal = 0.0;
    if (capitalVal > 0) {
      gainVal = (profitVal / capitalVal) * 100;
    }
    final gainDisplay = '${gainVal.toStringAsFixed(2)}%';

    // Commission display
    final commissionDisplay =
        item != null
            ? '\$${item.totalCommissionPaid.toStringAsFixed(2)}'
            : '\$0.00';

    // Risk score or risk percent
    final riskDisplay =
        item != null && item.riskPercent.isNotEmpty
            ? '${item.riskPercent}%'
            : '1';

    // Equity and balance
    final equityVal =
        _detailData != null && _detailData!['current_equity'] != null
            ? double.tryParse(_detailData!['current_equity'].toString()) ?? 0.0
            : (item != null ? item.capitalAmount.toDouble() : 0.0);
    final balanceVal = item != null ? item.accountBalance.toDouble() : 0.0;

    final leverageDisplay =
        item != null && item.serverType.isNotEmpty
            ? item.serverType.toUpperCase()
            : '1:500';

    final copyingMethodDisplay = getCopyMethodDisplay(item);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Copy proportion indicator
          _SummaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Equal x1 row (Dynamic)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        copyingMethodDisplay,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Icon(
                        Icons.info_outline,
                        size: 18.sp,
                        color: AppColors.textGrey,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                _SummaryRow(
                  'Profit',
                  profitDisplay,
                  valueColor:
                      profitVal >= 0 ? AppColors.green : AppColors.error,
                ),
                _SummaryRow(
                  'Float profit',
                  floatProfitDisplay,
                  valueColor:
                      floatProfitVal >= 0 ? AppColors.green : AppColors.error,
                ),
                _SummaryRow(
                  'Gain',
                  gainDisplay,
                  valueColor: gainVal >= 0 ? AppColors.green : AppColors.error,
                ),
                _SummaryRow(
                  'Commission Paid',
                  commissionDisplay,
                  valueColor: AppColors.error,
                ),
                _SummaryRow(
                  'Risk Score',
                  riskDisplay,
                  valueColor: AppColors.green,
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: DashedUnderline(
                    color: AppColors.dashLineColor,
                    dashWidth: 1,
                    dashSpace: 0,
                  ),
                ),

                // ── Investment range slider bar ──
                _buildBarSection(
                  leftLabel: 'Profit',
                  rightLabel: 'Loss',
                  value: profitVal > 0 ? 1.0 : 0.0,
                  leftColor: AppColors.green,
                  rightColor: AppColors.error,
                ),

                SizedBox(height: 16.h),
                Divider(color: AppColors.surface),
                SizedBox(height: 8.h),

                _SummaryRow(
                  'Equity',
                  '\$${equityVal.toStringAsFixed(2)}',
                  valueColor: AppColors.icongrey,
                ),
                _SummaryRow(
                  'Balance',
                  '\$${balanceVal.toStringAsFixed(2)}',
                  valueColor: AppColors.icongrey,
                ),
                _SummaryRow(
                  'Server Type',
                  leverageDisplay,
                  valueColor: AppColors.icongrey,
                ),
                _SummaryRow(
                  'Daily Avg P&L',
                  item != null
                      ? '\$${(item.totalPnl / 30.0).toStringAsFixed(2)}'
                      : '\$0.00',
                  valueColor:
                      profitVal >= 0 ? AppColors.green : AppColors.error,
                ),
                _SummaryRow(
                  'Status',
                  item != null ? item.status.toUpperCase() : 'UNKNOWN',
                  valueColor:
                      item != null && item.status.toLowerCase() == 'active'
                          ? AppColors.green
                          : AppColors.warning,
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _buildQuickActionsCard(),
          Padding(padding: EdgeInsets.only(bottom: 20.h)),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    final item = subscriptionItem;
    if (item == null) return const SizedBox.shrink();

    final status = _detailData != null && _detailData!['status'] != null
        ? _detailData!['status'].toString().toLowerCase()
        : item.status.toLowerCase();
    final canPause = status == 'active';
    final canResume = status == 'paused';
    final canStop = status == 'active' || status == 'paused';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      color: AppColors.whiteColor,
      elevation: 0.8,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                if (canPause)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _onPauseTap,
                      icon: Icon(Icons.pause, color: Colors.white),
                      label: Text('Pause'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                if (canResume)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _onResumeTap,
                      icon: Icon(Icons.play_arrow, color: Colors.white),
                      label: Text('Resume'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                if (canPause || canResume) SizedBox(width: 12.w),
                if (canStop)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _onStopTap,
                      icon: Icon(Icons.stop, color: Colors.white),
                      label: Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                if (!canPause && !canResume && !canStop)
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackGround,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'No Actions Available (${status.toUpperCase()})',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w500,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarSection({
    required String leftLabel,
    required String rightLabel,
    required double value,
    required Color leftColor,
    required Color rightColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLabel,
              style: TextStyle(
                fontSize: 14.sp,
                color: leftColor,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              '—',
              style: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
            ),
            Text(
              rightLabel,
              style: TextStyle(
                fontSize: 14.sp,
                color: rightColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0.r),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6.h,
                  backgroundColor: AppColors.dashLineColor,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                ),
              ),
            ),
            SizedBox(width: 5.h),

            SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0.r),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6.h,
                  backgroundColor: AppColors.dashLineColor,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }



  // ─────────────────────────────────────────────────────────────────
  // TRADES TAB
  // ─────────────────────────────────────────────────────────────────
  Widget _buildTradesTab() {
    if (_isLoadingTrades && _trades.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    if (_tradesError.isNotEmpty && _trades.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            _tradesError,
            style: TextStyle(color: AppColors.error, fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_trades.isEmpty) {
      return Center(
        child: Text(
          'No trade history found.',
          style: TextStyle(color: AppColors.textGrey, fontSize: 14.sp),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _trades.length,
      itemBuilder: (context, index) {
        return _TradeExpandableCard(trade: _trades[index]);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // OPTIONS TAB
  // ─────────────────────────────────────────────────────────────────
  Widget _buildOptionsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: _SummaryCard(
        child: Column(
          children: [
            _OptionItem(
              icon: Icons.add_circle_outline,
              label: 'Add Investment',
              onTap: _showAddCapitalDialog,
            ),
            _divider(),
            _OptionItem(
              icon: Icons.remove_circle_outline,
              label: 'Reduce Investment',
              onTap: () {
                CustomToastService.showError(
                  title: 'Not Supported',
                  message:
                      'Reducing investment amount is not supported by the copy trading backend directly. To withdraw, please Stop Copying or adjust settings.',
                );
              },
            ),
            _divider(),
            _OptionItem(
              icon: Icons.settings_outlined,
              label: 'Change Copy Proportion',
              onTap: () async {
                final sub = subscriptionItem;
                if (sub == null) return;
                final updated = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder:
                      (ctx) => EditSubscriptionSheet(
                        subscriptionId: widget.subscriptionId ?? 0,
                        masterCode: sub.masterCode,
                        planId: sub.planId,
                        masterName:
                            sub.masterName.isNotEmpty
                                ? sub.masterName
                                : sub.masterCode,
                      ),
                );
                if (updated == true) {
                  _fetchDetail();
                }
              },
            ),
            _divider(),
            _OptionItem(
              icon: Icons.cancel_outlined,
              label: 'Stop Copying',
              onTap: () => _showStopCopyingDialog(),
            ),
            _divider(),
            _OptionItem(
              icon: Icons.grid_view_outlined,
              label: "View Master's Performance",
              onTap:
                  () => Get.offAll(
                    () => CopyTradingMainScreen(initialIndex: 1),
                  ),
            ),
            _divider(),
            _OptionItem(
              icon: Icons.notifications_outlined,
              label: 'Receive Trading Notifications',
              onTap: () {},
              isSwitch: true,
              switchWidget: SizedBox(
                height: 25,
                child: Transform.scale(
                  alignment: Alignment.centerRight,
                  scale: 0.6,
                  child: Switch(
                    value: _notificationsEnabled,
                    onChanged:
                        (val) => setState(() => _notificationsEnabled = val),
                    activeThumbColor: AppColors.primary,
                    inactiveThumbColor: AppColors.whiteColor,
                    inactiveTrackColor: AppColors.switchTrackOff,
                    overlayColor: MaterialStateProperty.all(Colors.transparent),

                    // Border removal when inactive (from previous fix)
                    trackOutlineColor: MaterialStateProperty.resolveWith<
                      Color?
                    >((states) {
                      if (states.contains(MaterialState.selected)) return null;
                      return Colors
                          .transparent; // or AppColors.whiteColor if background is white
                    }),
                    trackOutlineWidth:
                        MaterialStateProperty.resolveWith<double?>((states) {
                          if (states.contains(MaterialState.selected))
                            return null;
                          return 0.0;
                        }),

                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
            // Toggle row
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: AppColors.surface, indent: 36.w);

  void _showStopCopyingDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
            ), // ← main change for width
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20.w, // increased from 8 → looks better
              vertical: 24.h,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 40.sp,
                  color: AppColors.textPrimary,
                ),
                SizedBox(height: 20.h), // slightly more breathing room
                Text(
                  'Are you Sure?',
                  style: TextStyle(
                    fontSize: 18.sp, // optional: little bigger title
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'This investment has a bonus applied. It amounts \$23.50. If you stop copying, the bonus will be cancelled and you will not be able to reapply it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w400,
                    height: 1.4, // ← helps long text feel less cramped
                  ),
                ),
                SizedBox(height: 28.h),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48.h, // slightly taller buttons feel premium
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.cardBackGround,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: SizedBox(
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // Close the dialog
                            final res = await _subscriptionsCtrl.stop(
                              widget.subscriptionId ?? 0,
                            );
                            if (res.success) {
                              CustomToastService.showSuccess(
                                title: 'Success',
                                message: 'Subscription stopped successfully',
                              );
                              _fetchDetail();
                            } else {
                              CustomToastService.showError(
                                title: 'Error',
                                message:
                                    res.message ?? 'Failed to stop copying',
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Close and Stop',
                            style: TextStyle(
                              color: AppColors.whiteColor,
                              fontSize: 13.5.sp, // was 12.8 – little small
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}

// ─── Tab button ───────────────────────────────────────────────────
class _TabButton extends StatelessWidget {
  final String label;
  final int index;
  final int selected;
  final Function(int) onTap;

  const _TabButton({
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = index == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.primary),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.whiteColor : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Trade expandable card ────────────────────────────────────────
class _TradeExpandableCard extends StatefulWidget {
  final TradeItem trade;
  const _TradeExpandableCard({required this.trade});

  @override
  State<_TradeExpandableCard> createState() => _TradeExpandableCardState();
}

class _TradeExpandableCardState extends State<_TradeExpandableCard> {
  bool _expanded = false;

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;
    final bool isBuy = t.tradeType.toLowerCase() == 'buy';

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        children: [
          // ── Symbol + Profit row ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isBuy ? AppColors.green : AppColors.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  t.tradeType.toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.whiteColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                t.copierVolume.toStringAsFixed(2),
                                style: TextStyle(
                                  color: AppColors.icongrey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            t.symbol,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/svg/copy_trading/calendar.svg',
                              ),
                              SizedBox(width: 4),
                              Text(
                                t.status,
                                style: TextStyle(
                                  color: AppColors.icongrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '\$${t.copierProfit.toStringAsFixed(2)}',
                            style: TextStyle(
                              color:
                                  t.copierProfit >= 0
                                      ? AppColors.green
                                      : AppColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 16),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ],
                  ),

                  // Expanded Details
                ],
              ),
            ),
          ),

          // ── Expanded details ──
          AnimatedCrossFade(
            firstChild: SizedBox(width: double.infinity),
            secondChild: _buildDetails(t),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(TradeItem t) {
    return Column(
      children: [
        Divider(height: 1, color: AppColors.surface),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Column(
            children: [
              _DetailRow('Open time', _formatDateTime(t.openTime)),
              _DetailRow('Close time', _formatDateTime(t.closeTime)),
              _DetailRow('Open Price', t.openPrice.toString()),
              _DetailRow('Close Price', t.closePrice.toString()),
              _DetailRow('Order ID', '#${t.id}'),
              _DetailRow(
                'Commission you paid',
                '\$${t.commissionCharged.toStringAsFixed(2)}',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _DetailRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
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
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppColors.surface),
      ],
    );
  }
}

// ─── Option item ──────────────────────────────────────────────────
class _OptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSwitch;
  final Widget switchWidget;

  const _OptionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSwitch = false,
    this.switchWidget = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22.sp),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (!isSwitch)
              Icon(
                Icons.arrow_forward_ios,
                size: 14.sp,
                color: AppColors.textGrey,
              ),
            if (isSwitch) switchWidget,
          ],
        ),
      ),
    );
  }
}

// ─── Shared summary card wrapper ──────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final Widget child;
  const _SummaryCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.surface),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Summary row ─────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow(this.label, this.value, {required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.icongrey,
            ),
          ),
          Flexible(
            child: DashedUnderline(
              color: AppColors.dashLineColor,
              dashSpace: 3,
              dashWidth: 3,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
