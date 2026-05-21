import 'package:crm_app/widgets/dashBorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'add_investment_screen.dart';
import 'copy_trading_main_screen.dart';
import 'reduce_investment_screen.dart';
import 'change_proportion_screen.dart';
import 'package:crm_app/widgets/app_back_button.dart';

// ─── Mock trade data ──────────────────────────────────────────────
class _TradeItem {
  final String type; // BUY / SELL
  final double lots;
  final String symbol;
  final String status;
  final String profit;
  final String masterName;
  final String openTime;
  final String closeTime;
  final String openPrice;
  final String closePrice;
  final String orderId;
  final String commission;

  const _TradeItem({
    required this.type,
    required this.lots,
    required this.symbol,
    required this.status,
    required this.profit,
    required this.masterName,
    required this.openTime,
    required this.closeTime,
    required this.openPrice,
    required this.closePrice,
    required this.orderId,
    required this.commission,
  });
}

final _mockTrades = [
  const _TradeItem(
    type: 'BUY',
    lots: 0.01,
    symbol: 'EURUSD',
    status: 'Closed',
    profit: r'$1.00',
    masterName: 'Prime_traders',
    openTime: 'Sep 11,2025 15:51',
    closeTime: 'Sep 11,2025 15:55',
    openPrice: '1.16956',
    closePrice: '1.17056',
    orderId: '#218254316',
    commission: r'$0.00',
  ),
  const _TradeItem(
    type: 'BUY',
    lots: 0.01,
    symbol: 'EURUSD',
    status: 'Closed',
    profit: r'$1.00',
    masterName: 'Prime_traders',
    openTime: 'Sep 11,2025 15:51',
    closeTime: 'Sep 11,2025 15:55',
    openPrice: '1.16956',
    closePrice: '1.17056',
    orderId: '#218254317',
    commission: r'$0.00',
  ),
  const _TradeItem(
    type: 'BUY',
    lots: 0.01,
    symbol: 'AUDUSD',
    status: 'Closed',
    profit: r'$1.00',
    masterName: 'Prime_traders',
    openTime: 'Sep 11,2025 15:51',
    closeTime: 'Sep 11,2025 15:55',
    openPrice: '0.64532',
    closePrice: '0.64612',
    orderId: '#218254318',
    commission: r'$0.00',
  ),
  const _TradeItem(
    type: 'BUY',
    lots: 0.01,
    symbol: 'EURUSD',
    status: 'Closed',
    profit: r'$1.00',
    masterName: 'Prime_traders',
    openTime: 'Sep 11,2025 15:51',
    closeTime: 'Sep 11,2025 15:55',
    openPrice: '1.16956',
    closePrice: '1.17056',
    orderId: '#218254319',
    commission: r'$0.00',
  ),
  const _TradeItem(
    type: 'BUY',
    lots: 0.01,
    symbol: 'AUDUSD',
    status: 'Closed',
    profit: r'$1.00',
    masterName: 'Prime_traders',
    openTime: 'Sep 11,2025 15:51',
    closeTime: 'Sep 11,2025 15:55',
    openPrice: '0.64532',
    closePrice: '0.64612',
    orderId: '#218254320',
    commission: r'$0.00',
  ),
];

// ─── Screen ───────────────────────────────────────────────────────
class InvestmentDetailScreen extends StatefulWidget {
  final String traderName;
  final String traderBadge;
  final String equity;

  const InvestmentDetailScreen({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(onPressed: ()=> Navigator.of(context).pop(),
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
              const Spacer(),
              Text(
                widget.equity,
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
        return const SizedBox();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // SUMMARY TAB
  // ─────────────────────────────────────────────────────────────────
  Widget _buildSummaryTab() {
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
                // Equal x1 row
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Equal x1',
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

                _SummaryRow('Profit', r'$0.00', valueColor: AppColors.green),
                _SummaryRow(
                  'Float profit',
                  r'$0.00',
                  valueColor: AppColors.green,
                ),
                _SummaryRow('Gain', '0.00%', valueColor: AppColors.green),
                _SummaryRow('Commission', '30%', valueColor: AppColors.green),
                _SummaryRow('Risk Score', '1', valueColor: AppColors.green),

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
                  leftLabel: r'$0',
                  rightLabel: r'$0',
                  value: 0.0,
                  leftColor: AppColors.green,
                  rightColor: AppColors.red,
                ),

                SizedBox(height: 14.h),
                Center(
                  child: Text(
                    'Profit Factor',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),

                _buildBarWithLabels(
                  leftLabel: '0',
                  rightLabel: '0',
                  centerLabel: '—',
                  subLeft: 'Profit',
                  subRight: 'Loss',
                  value: 0,
                ),

                SizedBox(height: 12.h),

                _buildBarWithLabels(
                  leftLabel: '0',
                  rightLabel: '0',
                  centerLabel: '—',
                  subLeft: 'Buy',
                  subRight: 'Sell',
                  value: 0,
                ),

                SizedBox(height: 16.h),
                Divider(color: Colors.grey.shade200),
                SizedBox(height: 8.h),

                _SummaryRow(
                  'Equity',
                  r'$70.50',
                  valueColor: AppColors.icongrey,
                ),
                _SummaryRow(
                  'Balance',
                  r'$47.00',
                  valueColor: AppColors.icongrey,
                ),
                _SummaryRow(
                  'Leverage',
                  '1:500',
                  valueColor: AppColors.icongrey,
                ),
                _SummaryRow(
                  'Average Daily',
                  '0.00%',
                  valueColor: AppColors.red,
                ),
                _SummaryRow('This Month', '0.00%', valueColor: AppColors.red),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.only(bottom: 20.h)),
        ],
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
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.red),
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

  Widget _buildBarWithLabels({
    required String leftLabel,
    required String rightLabel,
    required String centerLabel,
    required String subLeft,
    required String subRight,
    required double value,
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
                color: AppColors.green,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              centerLabel,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.icongrey,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              rightLabel,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.red,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
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
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.red),
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

        SizedBox(height: 4.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              subLeft,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.icongrey,
              ),
            ),
            Text(
              subRight,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.icongrey,
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
    return ListView(
      padding: EdgeInsets.all(16.w),
      children:
          _mockTrades
              .map((trade) => _TradeExpandableCard(trade: trade))
              .toList(),
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
              onTap:
                  () => Get.to(
                    () => AddInvestmentScreen(traderName: widget.traderName),
                  ),
            ),
            _divider(),
            _OptionItem(
              icon: Icons.remove_circle_outline,
              label: 'Reduce Investment',
              onTap:
                  () => Get.to(
                    () => ReduceInvestmentScreen(traderName: widget.traderName),
                  ),
            ),
            _divider(),
            _OptionItem(
              icon: Icons.settings_outlined,
              label: 'Change Copy Proportion',
              onTap:
                  () => Get.to(
                    () => ChangeProportionScreen(traderName: widget.traderName),
                  ),
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
                    () => const CopyTradingMainScreen(initialIndex: 1),
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
                    inactiveTrackColor: const Color(0xffDCDCDC),
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
      Divider(height: 1, color: Colors.grey.shade200, indent: 36.w);

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
                          onPressed: () => Navigator.pop(context),
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
          duration: const Duration(milliseconds: 200),
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
  final _TradeItem trade;
  const _TradeExpandableCard({required this.trade});

  @override
  State<_TradeExpandableCard> createState() => _TradeExpandableCardState();
}

class _TradeExpandableCardState extends State<_TradeExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.shade200),
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
                                      t.type == 'BUY'
                                          ? AppColors.green
                                          : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  t.type,
                                  style:   TextStyle(
                                    color: AppColors.whiteColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                t.lots.toStringAsFixed(2),
                                style: TextStyle(
                                  color: AppColors.icongrey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.symbol,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/svg/copy_trading/calendar.svg',
                              ),
                              const SizedBox(width: 4),
                              Text(
                                t.status,
                                style: TextStyle(
                                  color: AppColors.icongrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.profit,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
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
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildDetails(t),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(_TradeItem t) {
    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.shade200),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Column(
            children: [
              _DetailRow('Master name', t.masterName),
              _DetailRow('Open time', t.openTime),
              _DetailRow('Close time', t.closeTime),
              _DetailRow('Open Price', t.openPrice),
              _DetailRow('Close Price', t.closePrice),
              _DetailRow('Order ID', t.orderId),
              _DetailRow('Commission you paid', t.commission, isLast: true),
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
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
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
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
