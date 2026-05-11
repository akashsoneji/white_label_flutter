import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:fl_chart/fl_chart.dart';
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
        title: const Text(
          "Master's Performance",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset('assets/svg/trade/arro_back.svg'),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 0.0,
          bottom: 16.0, // Reduced space, replaced by bottomNavigationBar
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 10),
            _buildTabs(),
            const SizedBox(height: 16),
            if (_tabIndex == 0) ...[
              _buildMinimumInvestmentCard(),
              const SizedBox(height: 10),
              _buildPerformanceCard(),
              const SizedBox(height: 10),
              _buildAccountDetailsCard(),
              const SizedBox(height: 10),
              _buildRiskManagementCard(),
              const SizedBox(height: 10),
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child:   Text(
            'Set Up Copying',
            style: TextStyle(
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
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.0),
        child: Row(
          children: [
            SvgPicture.asset('assets/svg/copy_trading/person_svg.svg'),
            SizedBox(width: 12),
            Text(
              'Prime_traders',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _tabIndex == 0 ? AppColors.primary : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
              ),
              child: Center(
                child: Text(
                  'Summary',
                  style: TextStyle(
                    color: _tabIndex == 0 ? AppColors.whiteColor : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _tabIndex = 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _tabIndex == 1 ? AppColors.primary : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
              ),
              child: Center(
                child: Text(
                  'Trades',
                  style: TextStyle(
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
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
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
                                      trade.type == 'BUY'
                                          ? AppColors.green
                                          : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  trade.type,
                                  style:   TextStyle(
                                    color: AppColors.whiteColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                trade.volume,
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
                            trade.symbol,
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
                                trade.status,
                                style: TextStyle(
                                  color: AppColors.icongrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            trade.profit,
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
                    const SizedBox(height: 14),
                    const Divider(height: 1, thickness: 1, color: Colors.grey),
                    const SizedBox(height: 10),
                    _buildDetailRow('Master name', trade.masterName),
                    _buildDetailRow('Open time', trade.openTime),
                    _buildDetailRow('Close time', trade.closeTime),
                    _buildDetailRow('Open Price', trade.openPrice),
                    _buildDetailRow('Close Price', trade.closePrice),
                    _buildDetailRow('Order ID', trade.orderId),
                    _buildDetailRow('Commission you paid', trade.commission),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsCard() {
    return _buildBaseCard(
      title: 'Account Details',
      child: Column(
        children: [
          _buildInfoRow('Floating Profit', r'$0.00'),
          const SizedBox(height: 16),
          _buildInfoRow('Balance', r'$510.01'),
          const SizedBox(height: 16),
          _buildInfoRow("Master Trader's Bonus", r'$0.00'),
          const SizedBox(height: 16),
          _buildInfoRow('Leverage', '1:500'),
        ],
      ),
    );
  }

  Widget _buildRiskManagementCard() {
    return _buildBaseCard(
      title: 'Risk Management',
      child: Column(
        children: [
          _buildInfoRow('Maximum Unrealised Loss', r'-$20 555.00'),
          const SizedBox(height: 16),
          _buildInfoRow('Maximum Drawdown Duration', '21d'),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return _buildBaseCard(
      title: 'Activity',
      child: Column(
        children: [const SizedBox(height: 8), SteppedActivityChart()],
      ),
    );
  }

  Widget _buildMinimumInvestmentCard() {
    return _buildBaseCard(
      title: 'Minimum Investment',
      titleTrailing: const Text(
        r'$25',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '1 RISK',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.info_outline, color: Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 8),
            Divider(color: AppColors.dashLineColor),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.star, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'High Achiever',
                    style: TextStyle(
                      color: AppColors.icongrey,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.info_outline,
                color: AppColors.icongrey,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn('Equity', r'$567.89', isPrimaryValue: true),
              _buildMetricColumn('Commission', '40%', isPrimaryValue: true),
              _buildMetricColumn('With Us', '645D', isPrimaryValue: true),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Strategy Description',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Welcome to our group of expert traders. We are providing safe and secure trading strategies to make profit for our copiers, stay with us and make safe profit.',
            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return _buildBaseCard(
      title: 'Performance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn('Gain', '33.71%', isPrimaryValue: true),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Copiers',
                    style: TextStyle(
                      color: AppColors.icongrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '138',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: Colors.green,
                            size: 14,
                          ),
                          Text(
                            '35',
                            style: TextStyle(
                              color: Colors.green,
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
          const SizedBox(height: 16),
          const Text(
            'Profit and Loss',
            style: TextStyle(color: AppColors.icongrey, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                r'$123.45',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                r'$0.00',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: double.infinity,
            color: Colors.grey.shade200,
            alignment: Alignment.centerLeft,
            child: Container(width: 80, height: 2, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeChip('2W', false),
              _buildTimeChip('1M', false),
              _buildTimeChip('3M', true),
              _buildTimeChip('6M', false),
              _buildTimeChip('All', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.whiteColor : Colors.black87,
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
          style: const TextStyle(
            color: AppColors.icongrey,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isPrimaryValue ? AppColors.primary : Colors.black87,
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
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (titleTrailing != null) titleTrailing,
              ],
            ),
            const SizedBox(height: 8),
              Divider(color: AppColors.dashLineColor),
            const SizedBox(height: 8),
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
              style: const TextStyle(
                color: AppColors.icongrey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Icon(Icons.info_outline, color: AppColors.icongrey, size: 16),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: Text(
            'Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
                  axisNameWidget: const SizedBox.shrink(),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    interval: 4000,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '\$${value.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
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
