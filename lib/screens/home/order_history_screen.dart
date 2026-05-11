import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/widgets/dashBorder.dart';
import 'package:crm_app/services/language_service.dart';

class CloseOrderScreen extends StatelessWidget {
  final TradePosition position;

  const CloseOrderScreen({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    final isPositive = position.profitLoss >= 0;
    final languageService = Get.find<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(closeOverlays: true),
          icon: SvgPicture.asset('assets/svg/trade/arro_back.svg'),
        ),
        title: Text(
          languageService.tr('order_history_close_order'),
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Order Summary Section
            _buildOrderSummary(position, isPositive),

            // Order Details Section
            Expanded(child: _buildOrderDetails(position)),

            // History Button
            _buildHistoryButton(context, position),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(TradePosition position, bool isPositive) {
    return Container(
      // margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(24.w),

      child: Row(
        children: [
          // Flag and Symbol
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(position.flag, style: TextStyle(fontSize: 30.sp)),
                  SizedBox(width: 8.w),
                  Column(
                    children: [
                      Text(position.symbol, style: AppTextStyles.black14500),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          SvgPicture.asset(
                            position.action == 'Buy'
                                ? 'assets/svg/trade/green_up_icon.svg'
                                : 'assets/svg/trade/red_down_icon.svg',
                            height: 9.h,
                            width: 9.w,
                          ),
                          SizedBox(width: 2.w),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${position.action}',
                                  style: AppTextStyles.black11400,
                                ),
                                TextSpan(
                                  text: ' ${position.volume}',
                                  style: AppTextStyles.grey11400,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Profit/Loss and Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${position.profitLoss.toStringAsFixed(2)}',
                style: AppTextStyles.black14500.copyWith(
                  color: isPositive ? AppColors.success : AppColors.error,
                  height: 1.4,
                ),
              ),

              Text(
                '${position.entryPrice} → ${position.currentPrice}',
                style: AppTextStyles.grey10400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(TradePosition position) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildDetailRow('Open Time', position.openTime),
                _buildDetailRow('Close Time', position.closeTime),
                _buildDetailRow('Close Price', position.currentPrice),
                _buildDetailRow('Reason', position.reason),
                _buildDetailRow('Order No.', position.orderNo),
                _buildDetailRow('Commission', '\$${position.commission}'),
                _buildDetailRow('Swap', '\$${position.swap}'),
                _buildDetailRow('TP (Take Profit)', position.takeProfit),
                _buildDetailRow(
                  'SL (Stop Loss)',
                  position.stopLoss == '-' ? '-' : position.stopLoss,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.black16400h37),
          Text(value, style: AppTextStyles.grey14400h57),
        ],
      ),
    );
  }

  Widget _buildHistoryButton(BuildContext context, TradePosition position) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom - 20.h,
      ),
      child: SizedBox(
        width: 327.w,
        height: 46.h,
        child: OutlinedButton(
          onPressed: () {
            Get.to(() => HistoryScreen(position: position));
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            minimumSize: Size(327.w, 46.h),
          ),
          child: Text(
            'History',
            style: AppTextStyles.label.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final TradePosition position;

  const HistoryScreen({super.key, required this.position});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Track which history entries are expanded
  final Map<int, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    // Initialize all entries as collapsed by default
    _expandedStates[0] = false;
    _expandedStates[1] = false;
    _expandedStates[2] = false;
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedStates[index] = !(_expandedStates[index] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.position.profitLoss >= 0;
    final languageService = Get.find<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        scrolledUnderElevation: 0,
        // elevation: 0,
        shadowColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Get.back(closeOverlays: true),
          icon: SvgPicture.asset('assets/svg/trade/arro_back.svg'),
        ),
        title: Text(
          languageService.tr('order_history_history'),
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Trade Summary
            _buildTradeSummary(widget.position, isPositive),

            // History Entries
            Expanded(child: _buildHistoryEntries()),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeSummary(TradePosition position, bool isPositive) {
    return Container(
      // margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(24.w),

      child: Row(
        children: [
          // Flag and Symbol
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(position.flag, style: TextStyle(fontSize: 30.sp)),
                  SizedBox(width: 8.w),
                  Column(
                    children: [
                      Text(position.symbol, style: AppTextStyles.black14500),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          SvgPicture.asset(
                            position.action == 'Buy'
                                ? 'assets/svg/trade/green_up_icon.svg'
                                : 'assets/svg/trade/red_down_icon.svg',
                            height: 9.h,
                            width: 9.w,
                          ),
                          SizedBox(width: 2.w),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${position.action}',
                                  style: AppTextStyles.black11400,
                                ),
                                TextSpan(
                                  text: ' ${position.volume}',
                                  style: AppTextStyles.grey11400,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Profit/Loss and Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${position.profitLoss.toStringAsFixed(2)}',
                style: AppTextStyles.black14500.copyWith(
                  color: isPositive ? AppColors.success : AppColors.error,
                  height: 1.4,
                ),
              ),

              Text(
                '${position.entryPrice} → ${position.currentPrice}',
                style: AppTextStyles.grey10400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEntries() {
    final languageService = Get.find<LanguageService>();
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      children: [
        _buildHistoryEntry(
          index: 0,
          title: languageService.tr('order_history_order_closed'),
          subtitle: languageService.tr('order_history_manual_operation'),
          profitLoss: '+ \$89.54',
          isPositive: true,
          dateTime: '25 jan 2025 • 12:49',
          expandedDetails: {
            'Device': 'Android',
            'Direction': 'Sell',
            'Close Price': '3,408.65',
            'Volume Closed': '0.03 lots',
            'Overnight fee': '\$0.00',
            'Gross profit': '+\$71.28',
            'Net profit': '+\$71.28',
            'Deal ID': '6341532',
          },
        ),
        _buildHistoryEntry(
          index: 1,
          title: languageService.tr('order_history_order_opened'),
          subtitle: languageService.tr('order_history_manual_operation'),
          profitLoss: '',
          isPositive: false,
          dateTime: '25 jan 2025 • 12:49',
          expandedDetails: {
            'Device': 'Android',
            'Direction': 'Sell',
            'Open Price': '3,408.65',
            'Volume': '0.03 lots',
          },
        ),
        _buildHistoryEntry(
          index: 2,
          title: languageService.tr('order_history_order_closed'),
          subtitle: languageService.tr('order_history_manual_operation'),
          profitLoss: '-\$8.56',
          isPositive: false,
          dateTime: '25 jan 2025 • 12:49',
        ),
      ],
    );
  }

  Widget _buildHistoryEntry({
    required int index,
    required String title,
    required String subtitle,
    required String profitLoss,
    required bool isPositive,
    required String dateTime,
    Map<String, String>? expandedDetails,
  }) {
    final isExpanded = _expandedStates[index] ?? false;

    return GestureDetector(
      onTap: () => _toggleExpanded(index),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          // borderRadius: BorderRadius.circular(8.r),
          border: Border(
            bottom: BorderSide(
              color:
                  (isExpanded)
                      ? AppColors.backgroundLight
                      : AppColors.cardBackGround,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.black15400h9),
                        Text(subtitle, style: AppTextStyles.grey11400),
                      ],
                    ),
                  ),

                  SizedBox(width: 8.w),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (profitLoss.isNotEmpty)
                            Text(
                              profitLoss,
                              style: AppTextStyles.grey14400h57.copyWith(
                                color:
                                    isPositive
                                        ? AppColors.success
                                        : AppColors.error,
                              ),
                            ),
                          Text(dateTime, style: AppTextStyles.grey11400),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.all(5.h),
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 24.h,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Expanded Details
            if (isExpanded && expandedDetails != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.r),
                    bottomRight: Radius.circular(8.r),
                  ),
                ),
                child: Column(
                  children:
                      expandedDetails.entries.map((entry) {
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: AppTextStyles.black16400h37,
                                  ),
                                  Text(
                                    entry.value,
                                    style: AppTextStyles.grey14400h57,
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: DashedUnderline(
                                  color: AppColors.icongreylight,
                                  dashSpace: 7,
                                  dashWidth: 2,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
