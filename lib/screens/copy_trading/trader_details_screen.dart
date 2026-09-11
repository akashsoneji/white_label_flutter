import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:crm_app/services/language_service.dart';
import 'subscription_setup_screen.dart';

class TraderDetailsScreen extends StatefulWidget {
  const TraderDetailsScreen({super.key});

  @override
  State<TraderDetailsScreen> createState() => _TraderDetailsScreenState();
}

class CopyTradeOrder {
  final String symbol;
  final String type; // BUY or SELL
  final String volume;
  final String status;
  final String profit;
  final String masterName;
  final String openTime;
  final String closeTime;
  final String openPrice;
  final String closePrice;
  final String orderId;
  final String commission;

  CopyTradeOrder({
    required this.symbol,
    required this.type,
    required this.volume,
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

class _TraderDetailsScreenState extends State<TraderDetailsScreen> {
  int _tabIndex = 0; // 0 for Summary, 1 for Trades
  int? _expandedTradeIndex;

  // Dummy API Data
  final List<CopyTradeOrder> _dummyTrades = [
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
      backgroundColor: AppColors.whiteColor, // theme-aware
      appBar: AppBar(
        title: Text(
          TranslationUtils.tr('trader_details_screen_master_performance'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/trade/arro_back.svg',
            colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 0.0,
          bottom: 16.0, // Reduced space, replaced by bottomNavigationBar
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(),
            SizedBox(height: 10),
            _buildTabs(),
            SizedBox(height: 16),
            if (_tabIndex == 0) ...[
              _buildMinimumInvestmentCard(),
              SizedBox(height: 10),
              _buildPerformanceCard(),
              SizedBox(height: 10),
              _buildAccountDetailsCard(),
              SizedBox(height: 10),
              _buildRiskManagementCard(),
              SizedBox(height: 10),
              _buildActivityCard(),
            ] else ...[
              _buildTradesList(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: AppColors.whiteColor,
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.of(context).padding.bottom + 16.0,
        ),
        child: ElevatedButton(
          onPressed: () {
            Get.to(() => const SubscriptionSetupScreen());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child:   Text(
            TranslationUtils.tr('trader_details_screen_set_up_copying'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.0),
        child: Row(
          children: [
            SvgPicture.asset('assets/svg/copy_trading/person_svg.svg'),
            SizedBox(width: 12),
            Text(
              'Prime_traders',
              style: AppTextStyles.bodyText.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _tabIndex = 0;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _tabIndex == 0 ? AppColors.primary : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
              ),
              child: Center(
                child: Text(
                  TranslationUtils.tr('common_summary'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: _tabIndex == 0 ? AppColors.whiteColor : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _tabIndex = 1;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _tabIndex == 1 ? AppColors.primary : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
              ),
              child: Center(
                child: Text(
                  TranslationUtils.tr('tw_trades'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: _tabIndex == 1 ? AppColors.whiteColor : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTradesList() {
    return Column(
      children: List.generate(_dummyTrades.length, (index) {
        final trade = _dummyTrades[index];
        bool isExpanded = _expandedTradeIndex == index;
        return Card(
          elevation: 0.5,
          margin: EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                if (_expandedTradeIndex == index) {
                  _expandedTradeIndex = null;
                } else {
                  _expandedTradeIndex = index;
                }
              });
            },
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
                                      trade.type == 'BUY'
                                          ? AppColors.green
                                          : AppColors.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  trade.type,
                                  style:   AppTextStyles.bodyText.copyWith(
                                    color: AppColors.whiteColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                trade.volume,
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
                            trade.symbol,
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
                                trade.status,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: AppColors.icongrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            trade.profit,
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
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                  // Expanded Details
                  if (isExpanded) ...[
                    SizedBox(height: 14),
                    Divider(height: 1, thickness: 1, color: AppColors.border),
                    SizedBox(height: 10),
                    _buildDetailRow(
                      TranslationUtils.tr('clients_tab_master_name'),
                      trade.masterName,
                    ),
                    _buildDetailRow(
                      TranslationUtils.tr('open_time'),
                      trade.openTime,
                    ),
                    _buildDetailRow(
                      TranslationUtils.tr(
                        'pmam_investor_portal_screen_close_time',
                      ),
                      trade.closeTime,
                    ),
                    _buildDetailRow(
                      TranslationUtils.tr('trading_order_open_price'),
                      trade.openPrice,
                    ),
                    _buildDetailRow(
                      TranslationUtils.tr(
                        'pmam_investor_portal_screen_close_price',
                      ),
                      trade.closePrice,
                    ),
                    _buildDetailRow(
                      TranslationUtils.tr('clients_tab_order_id'),
                      trade.orderId,
                    ),
                    _buildDetailRow(
                      TranslationUtils.tr('clients_tab_commission_you_paid'),
                      trade.commission,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // Detail row with dotted line (exactly as in your image)
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(fontSize: 13.5, color: AppColors.textGrey),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Divider(height: 1, thickness: 1, color: AppColors.border),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeDetailRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 12)),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            ' . ' * 20,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: AppTextStyles.bodyText.copyWith(color: AppColors.border, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(width: 4),
        Text(value, style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 13)),
      ],
    );
  }

  Widget _buildAccountDetailsCard() {
    return _buildBaseCard(
      title: TranslationUtils.tr('trader_details_screen_account_details'),
      child: Column(
        children: [
          _buildInfoRow(
            TranslationUtils.tr('trader_details_screen_floating_profit'),
            r'$0.00',
          ),
          SizedBox(height: 16),
          _buildInfoRow(TranslationUtils.tr('general_balance'), r'$510.01'),
          SizedBox(height: 16),
          _buildInfoRow(
            TranslationUtils.tr('trader_details_screen_master_traders_bonus'),
            r'$0.00',
          ),
          SizedBox(height: 16),
          _buildInfoRow(TranslationUtils.tr('common_leverage'), '1:500'),
        ],
      ),
    );
  }

  Widget _buildRiskManagementCard() {
    return _buildBaseCard(
      title: TranslationUtils.tr('pending_order_risk_management_label'),
      child: Column(
        children: [
          _buildInfoRow(
            TranslationUtils.tr('trader_details_screen_maximum_unrealised_loss'),
            r'-$20 555.00',
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            TranslationUtils.tr('trader_details_screen_maximum_drawdown_duration'),
            '21d',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return _buildBaseCard(
      title: TranslationUtils.tr('trader_details_screen_activity'),
      child: Column(
        children: [SizedBox(height: 8), SteppedActivityChart()],
      ),
    );
  }

  Widget _buildChartYAxisRow(String label) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 12)),
        SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.border)),
      ],
    );
  }

  Widget _buildMinimumInvestmentCard() {
    return _buildBaseCard(
      title: TranslationUtils.tr('trader_details_screen_minimum_investment'),
      titleTrailing: Text(
        r'$25',
        style: AppTextStyles.bodyText.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentStatic,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  TranslationUtils.tr('trader_details_screen_risk'),
                  style: AppTextStyles.bodyText.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.info_outline, color: AppColors.textGrey, size: 16),
            ],
          ),
          SizedBox(height: 8),
            Divider(color: AppColors.dashLineColor),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.star, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    TranslationUtils.tr('trader_card_high_achiever'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.icongrey,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.info_outline,
                color: AppColors.icongrey,
                size: 16,
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn(
                TranslationUtils.tr('general_equity'),
                r'$567.89',
                isPrimaryValue: true,
              ),
              _buildMetricColumn(
                TranslationUtils.tr('general_commission'),
                '40%',
                isPrimaryValue: true,
              ),
              _buildMetricColumn(
                TranslationUtils.tr('trader_details_screen_with_us'),
                '645D',
                isPrimaryValue: true,
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            TranslationUtils.tr('master_plan_detail_screen_strategy_description'),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 8),
          Text(
            TranslationUtils.tr('trader_details_screen_welcome_strategy_desc'),
            style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return _buildBaseCard(
      title: TranslationUtils.tr('portfolio_performance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn(
                TranslationUtils.tr('trader_card_gain'),
                '33.71%',
                isPrimaryValue: true,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TranslationUtils.tr('my_plans_tab_copiers'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.icongrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '138',
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: AppColors.green,
                            size: 14,
                          ),
                          Text(
                            '35',
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
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
          SizedBox(height: 16),
          Text(
            TranslationUtils.tr('trader_card_profit_and_loss'),
            style: AppTextStyles.bodyText.copyWith(color: AppColors.icongrey, fontSize: 10),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                r'$123.45',
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                r'$0.00',
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            height: 2,
            width: double.infinity,
            color: AppColors.border,
            alignment: Alignment.centerLeft,
            child: Container(width: 80, height: 2, color: AppColors.primary),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeChip('2W', false),
              _buildTimeChip('1M', false),
              _buildTimeChip('3M', true),
              _buildTimeChip('6M', false),
              _buildTimeChip(TranslationUtils.tr('common_all'), false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, bool isSelected) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyText.copyWith(
          color: isSelected ? AppColors.whiteColor : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildMetricColumn(
    String label,
    String value, {
    bool isPrimaryValue = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.icongrey,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            color: isPrimaryValue ? AppColors.primary : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildBaseCard({
    required String title,
    required Widget child,
    Widget? titleTrailing,
  }) {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (titleTrailing != null) titleTrailing,
              ],
            ),
            SizedBox(height: 8),
              Divider(color: AppColors.dashLineColor),
            SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.icongrey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            Icon(Icons.info_outline, color: AppColors.icongrey, size: 16),
          ],
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class SteppedActivityChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Sample data to match your screenshot ≈ (adjust these values to your real data)
    // x = time/index (0 to ~10), y = dollar amount
    final List<FlSpot> spots = [
      FlSpot(0, 12000),
      FlSpot(1, 12000),
      FlSpot(2, 12500),
      FlSpot(3, 14000),
      FlSpot(4, 14000),
      FlSpot(5, 14500),
      FlSpot(6, 16000),
      FlSpot(7, 16000),
      FlSpot(8, 15800), // small step down
      FlSpot(9, 15800),
      FlSpot(10, 20000),
      FlSpot(11, 20000),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: Text(
            TranslationUtils.tr('trader_details_screen_activity'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 240, // tune this to fit your screen
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isStepLineChart: true,
                  lineChartStepData: LineChartStepData(
                    stepDirection: 0.5, // try 0.0 / 0.5 / 1.0
                  ),
                  barWidth: 0,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withOpacity(0.75),
                  ),
                ),
              ],

              // Clean minimal style
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: SizedBox.shrink(),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    interval: 4000,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text(
                          '\$${value.toStringAsFixed(0)}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: spots.last.x + 1,
              minY: 11000,
              maxY: 21000,
              lineTouchData: const LineTouchData(
                enabled: false,
              ), // no tooltip/interaction needed?
            ),
          ),
        ),
      ],
    );
  }
}
