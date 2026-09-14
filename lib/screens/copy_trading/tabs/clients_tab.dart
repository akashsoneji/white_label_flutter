import 'package:crm_app/screens/copy_trading/trader_details_screen.dart';
import 'package:crm_app/widgets/dashBorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:flutter_svg/svg.dart';
import 'package:crm_app/services/language_service.dart';
import '../../../constants/text_styles.dart';

class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  // Demo data list. If this is empty, it will show the empty state message.
  final List<CopyTradeOrder> _tradeHistory = [
    CopyTradeOrder(
      symbol: 'EURUSD',
      type: 'BUY',
      volume: '0.01',
      status: 'Closed',
      profit: r'$1.00',
      masterName: 'Prime_traders',
      openTime: 'Sep 12,2025 15:51',
      closeTime: 'Sep 12,2025 15:55',
      openPrice: '1.16956',
      closePrice: '1.17056',
      orderId: '#218254316',
      commission: r'$0.00',
    ),
    CopyTradeOrder(
      symbol: 'AUDUSD',
      type: 'BUY',
      volume: '0.01',
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('tw_trades'),
          style: AppTextStyles.heading.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            // Get.back();
          },
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            width: 24.w,
            height: 24.h,
          ),
        ),
      ),
      body:
          _tradeHistory.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                padding: EdgeInsetsDirectional.fromSTEB(16.w, 16.h, 16.w, 80.h),
                itemCount: _tradeHistory.length,
                itemBuilder: (context, index) {
                  return _TradeHistoryCard(data: _tradeHistory[index]);
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(15.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textPrimary.withOpacity(0.8),
                width: 2.2,
              ),
            ),
            child: Icon(
              Icons.access_time, // Replaced with Clock icon matching design
              size: 40.r,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            TranslationUtils.tr('clients_tab_no_transaction_yet'),
            style: AppTextStyles.subheading.copyWith(
              color: AppColors.textGrey,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeHistoryCard extends StatefulWidget {
  final CopyTradeOrder data;
  const _TradeHistoryCard({required this.data});

  @override
  State<_TradeHistoryCard> createState() => _TradeHistoryCardState();
}

class _TradeHistoryCardState extends State<_TradeHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
      ),
      color: AppColors.whiteColor,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(14.0),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  data.type == 'BUY'
                                      ? AppColors.green
                                      : AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data.type,
                              style:   AppTextStyles.bodyText.copyWith(
                                color: AppColors.whiteColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            data.volume,
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.icongrey,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        data.symbol,
                        style: AppTextStyles.bodyText.copyWith(
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
                          SizedBox(width: 4),
                          Text(
                            data.status,
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.icongrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        data.profit,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                SizedBox(height: 12.h),
                Divider(
                  color: AppColors.border.withValues(alpha: 0.1),
                  thickness: 1,
                  height: 1,
                ),
                SizedBox(height: 12.h),
                _buildDetailRow(
                  TranslationUtils.tr('clients_tab_master_name'),
                  data.masterName,
                ),
                _buildDetailRow(
                  TranslationUtils.tr('open_time'),
                  data.openTime,
                ),
                _buildDetailRow(
                  TranslationUtils.tr('pmam_investor_portal_screen_close_time'),
                  data.closeTime,
                ),
                _buildDetailRow(
                  TranslationUtils.tr('trading_order_open_price'),
                  data.openPrice,
                ),
                _buildDetailRow(
                  TranslationUtils.tr('pmam_investor_portal_screen_close_price'),
                  data.closePrice,
                ),
                _buildDetailRow(
                  TranslationUtils.tr('clients_tab_order_id'),
                  data.orderId,
                ),
                _buildDetailRow(
                  TranslationUtils.tr('clients_tab_commission_you_paid'),
                  '\$${data.commission}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.grey14400h57.copyWith(
              fontSize: 14.sp,
              color: AppColors.icongrey,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: DashedUnderline(
              color: AppColors.dashLineColor,
              dashSpace: 3,
              dashWidth: 3,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: CustomPaint(painter: DottedLinePainter()),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.black14500.copyWith(
              fontSize: 14.sp,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared horizontal dotted line painter used across copy-trading screens.
class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.dashLineColor
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    const dashWidth = 1.0;
    const dashSpace = 2.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
