import 'dart:async';
import 'package:crm_app/constants/text_styles.dart';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/home/chart_screen.dart';
import 'package:crm_app/screens/home/more/promotional/promotional_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/home/search_instruments_screen.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/dashboard_bottom_sheet.dart';

const _kHomeSparklinePoints = 50;

class IquoteHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const IquoteHomeScreen({super.key, this.onNavigateToTab});

  static Future<void> handleSwitchToIB() async {
    try {
      IBController ibController;
      if (Get.isRegistered<IBController>()) {
        ibController = Get.find<IBController>();
      } else {
        ibController = Get.put(IBController());
      }

      Get.dialog(
        Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        ),
        barrierDismissible: false,
      );

      final ibStatusResponse = await ibController.getIBStatus();

      Get.back(closeOverlays: true);

      if (ibStatusResponse != null && ibStatusResponse.status == true) {
        final ibStatus = ibStatusResponse.data?.ibStatus;
        final isApproved = ibStatusResponse.data?.isApproved ?? false;
        final profileCompletion = ibStatusResponse.data?.profileCompletion ?? 0;

        if (ibStatus == 'rejected') {
          CustomToastService.showError(
            message:
                'Your IB application has been rejected. Please contact support for more information.',
          );
          return;
        }
        if (ibStatus == 'not_applied') {
          Get.toNamed(AppPages.PARTNERSHIP_PROGRAM);
        } else if (ibStatus == 'approved' && isApproved == true) {
          Get.toNamed(AppPages.IB_MAIN);
        } else if (profileCompletion == 100) {
          Get.toNamed(AppPages.PARTNERSHIP_PROGRAM);
        } else {
          CustomToastService.showError(
            duration: const Duration(seconds: 2),
            message:
                ibStatusResponse.message ??
                'Profile is not complete. Please complete your profile first.',
          );
        }
      } else {
        String errorMsg =
            ibStatusResponse?.message ?? ibController.errorMessage.value;
        if (errorMsg.isEmpty)
          errorMsg = 'Failed to check IB status. Please try again.';
        CustomToastService.showError(message: errorMsg);
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back(closeOverlays: true);
      }
      CustomToastService.showError(message: 'Error checking IB status: $e');
    }
  }

  @override
  State<IquoteHomeScreen> createState() => _IquoteHomeScreenState();
}

class _IquoteHomeScreenState extends State<IquoteHomeScreen> {
  late final InstrumentsController _ic;
  StreamSubscription<Map<String, dynamic>>? _tickSub;
  final Map<String, List<double>> _bidHistory = {};

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<InstrumentsController>()) {
      _ic = Get.put(InstrumentsController());
    } else {
      _ic = Get.find<InstrumentsController>();
    }

    if (Get.isRegistered<ChartSocketController>()) {
      final socket = Get.find<ChartSocketController>();
      _tickSub = socket.priceStream.listen(_onTick);
    }

    for (final e in _ic.instruments) {
      final key = _stripSuffix(e.symbol);
      if (e.bid > 0 && !_bidHistory.containsKey(key)) {
        _bidHistory[key] = List<double>.filled(_kHomeSparklinePoints, e.bid);
      }
    }
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    super.dispose();
  }

  void _onTick(Map<String, dynamic> m) {
    final sym = m['symbol']?.toString();
    if (sym == null || sym.isEmpty) return;
    final raw = m['bid'] ?? m['Bid'];
    if (raw == null) return;
    final bid = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (bid == null || bid <= 0) return;

    final key = _stripSuffix(sym);
    final hist = _bidHistory.putIfAbsent(key, () => <double>[]);
    hist.add(bid);
    if (hist.length > _kHomeSparklinePoints) hist.removeAt(0);
    if (mounted) setState(() {});
  }

  static String _stripSuffix(String s) =>
      s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SearchInstrumentsScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgDark = IquoteThemeColors.background;
    final cardBg = IquoteThemeColors.cardBackground;
    final textPrimary = IquoteThemeColors.textPrimary;
    final textSecondary = IquoteThemeColors.textSecondary;
    final isDark = AppColors.isDarkMode;

    final appTitle =
        FlavorConfig.instance.appTitle.isNotEmpty
            ? FlavorConfig.instance.appTitle
            : FlavorConfig.instance.appName;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 30.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header: App Title
              Center(
                child: Text(
                  appTitle,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w400,
                    color: textPrimary,
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              // 2. Active Account Card with Switch Account Bottom Sheet
              // _ActiveAccountBar(
              //   cardBg: cardBg,
              //   textPrimary: textPrimary,
              //   textSecondary: textSecondary,
              //   isDark: isDark,
              // ),
              // SizedBox(height: 14.h),

              // 3. Banner: Profit & Bonus Ranking
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isDark
                            ? [const Color(0xFFC3F3A0), const Color(0xFFD6F6B8)]
                            : [
                              AppColors.primary.withOpacity(0.15),
                              AppColors.primary.withOpacity(0.05),
                            ],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  border:
                      isDark
                          ? null
                          : Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profit & Bonus Ranking',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.black : textPrimary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Data updated daily',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.black87 : textSecondary,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black : AppColors.primary,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              'View',
                              style: AppTextStyles.bodyText.copyWith(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.emoji_events, size: 64.r, color: Colors.orange),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // 4. 8 Shortcuts Grid
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 8.w,
                children: [
                  // 1. Demo
                  _buildShortcutItem(
                    icon: Icons.play_circle_outline,
                    label: 'Demo',
                    color: Colors.orangeAccent,
                    textColor: textPrimary,
                    onTap:
                        () => Get.toNamed(
                          AppPages.CHOOSE_ACCOUNT,
                          arguments: {'isDemo': true},
                        ),
                  ),
                  // 2. Real
                  _buildShortcutItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Real',
                    color: Colors.greenAccent,
                    textColor: textPrimary,
                    onTap: () => Get.toNamed(AppPages.CHOOSE_ACCOUNT),
                  ),
                  // 3. IB
                  _buildShortcutItem(
                    icon: Icons.business_center_outlined,
                    label: 'IB',
                    color: Colors.purpleAccent,
                    textColor: textPrimary,
                    isHot: true,
                    onTap: IquoteHomeScreen.handleSwitchToIB,
                  ),
                  // 4. PAMM
                  _buildShortcutItem(
                    icon: Icons.pie_chart_outline,
                    label: 'PAMM',
                    color: Colors.pinkAccent,
                    textColor: textPrimary,
                    isHot: true,
                    onTap: () => Get.toNamed(AppPages.PMAM_MAIN),
                  ),
                  // 5. Scratchcard
                  _buildShortcutItem(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Scratchcard',
                    color: Colors.amber,
                    textColor: textPrimary,
                    onTap: () => Get.to(() => const PromotionalScreen()),
                  ),
                  // 6. Support Ticket
                  _buildShortcutItem(
                    icon: Icons.support_agent_outlined,
                    label: 'Support Ticket',
                    color: Colors.tealAccent,
                    textColor: textPrimary,
                    onTap: () => Get.toNamed(AppPages.TICKET_LIST),
                  ),
                  // 7. Deposit
                  _buildShortcutItem(
                    icon: Icons.add_circle_outline,
                    label: 'Deposit',
                    color: Colors.blueAccent,
                    textColor: textPrimary,
                    onTap:
                        () => Get.to(
                          () => PaymentMethodsScreen(accountNumber: ''),
                        ),
                  ),
                  // 8. Withdrawal
                  _buildShortcutItem(
                    icon: Icons.remove_circle_outline,
                    label: 'Withdrawal',
                    color: Colors.lightBlue,
                    textColor: textPrimary,
                    onTap: () => Get.toNamed(AppPages.WITHDRAWAL),
                  ),
                ],
              ),
              // SizedBox(height: 16.h),

              // 6. Favourites Section Header + Add Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Favourites',
                    style: AppTextStyles.bodyText.copyWith(
                      color: textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  IconButton(
                    onPressed: _openSearchSheet,
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      size: 20.r,
                      color: AppColors.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              // Live Favourites Grid with Mini Sparkline Charts
              _buildLiveFavouritesGrid(
                cardBg,
                textPrimary,
                textSecondary,
                isDark,
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveFavouritesGrid(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Obx(() {
      final instruments = _ic.instruments;

      // Get user favorited instruments or fallback to top market instruments
      final favList =
          instruments.where((e) => _ic.isFavorite(e.symbol)).toList();
      final displayList =
          favList.isNotEmpty ? favList : instruments.take(6).toList();

      if (displayList.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20.h),
            child: Text(
              'No instruments available',
              style: AppTextStyles.bodyText.copyWith(
                color: textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10.h,
          crossAxisSpacing: 10.w,
          childAspectRatio:
              1.6, // Fits Symbol, % Change, Price, AND mini sparkline chart!
        ),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          return _LiveTickerCard(
            instrument: displayList[index],
            controller: _ic,
            bidHistory: _bidHistory,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          );
        },
      );
    });
  }

  Widget _buildShortcutItem({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
    bool isHot = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 44.r,
                width: 44.r,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: Colors.white, size: 24.r),
              ),
              if (isHot)
                Positioned(
                  top: -4.h,
                  right: -4.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Hot',
                      style: AppTextStyles.bodyText.copyWith(
                        color: Colors.white,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              color: textColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTickerCard extends StatelessWidget {
  final ListElement instrument;
  final InstrumentsController controller;
  final Map<String, List<double>> bidHistory;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const _LiveTickerCard({
    required this.instrument,
    required this.controller,
    required this.bidHistory,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sym = instrument.symbol;
    final displaySym =
        sym.contains('.') ? sym.substring(0, sym.lastIndexOf('.')) : sym;
    final digits = instrument.digits;
    final key =
        sym.contains('.') ? sym.substring(0, sym.lastIndexOf('.')) : sym;

    return Obx(() {
      final livePrice = controller.priceRx(sym).value;
      final hist = bidHistory[key] ?? <double>[];

      if (livePrice.bid > 0) {
        if (hist.isEmpty || (hist.last - livePrice.bid).abs() > 1e-7) {
          final list = bidHistory.putIfAbsent(key, () => <double>[]);
          list.add(livePrice.bid);
          if (list.length > _kHomeSparklinePoints) list.removeAt(0);
        }
      }

      double currentBid =
          livePrice.bid > 0
              ? livePrice.bid
              : (hist.isNotEmpty ? hist.last : instrument.bid);
      if (currentBid <= 0) {
        currentBid =
            (instrument.dayLow != null && instrument.dayLow! > 0)
                ? instrument.dayLow!
                : 1.0;
      }

      final dayLow =
          livePrice.dayLow > 0 ? livePrice.dayLow : (instrument.dayLow ?? 0.0);
      final changePct =
          dayLow > 0 ? ((currentBid - dayLow) / dayLow * 100) : 0.0;
      final isUp = changePct >= 0;
      final sign = isUp ? '+' : '';

      final lineColor =
          isUp ? const Color(0xFF2ED573) : const Color(0xFFFF4757);
      final changeColor =
          isUp ? const Color(0xFF2ED573) : const Color(0xFFFF4757);
      final changeStr = '$sign${changePct.abs().toStringAsFixed(2)}%';

      return InkWell(
        onTap: () {
          ChartScreen.setSelectedSymbol(sym);
          Get.to(() => const ChartScreen());
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border.withOpacity(0.15)),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displaySym,
                    style: AppTextStyles.bodyText.copyWith(
                      color: textPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    changeStr,
                    style: AppTextStyles.bodyText.copyWith(
                      color: changeColor,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Text(
                PrecisionHelper.formatPrice(currentBid, decimals: digits),
                style: AppTextStyles.bodyText.copyWith(
                  color: changeColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 2.h),
              SizedBox(
                height: 22.h,
                width: double.infinity,
                child: _HomeSparkline(
                  history: hist,
                  lineColor: lineColor,
                  digits: digits,
                  fallbackPrice: currentBid,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _HomeSparkline extends StatelessWidget {
  final List<double> history;
  final Color lineColor;
  final int digits;
  final double fallbackPrice;

  const _HomeSparkline({
    required this.history,
    required this.lineColor,
    required this.digits,
    required this.fallbackPrice,
  });

  @override
  Widget build(BuildContext context) {
    List<double> dataPoints = List<double>.from(history);
    if (dataPoints.length < 2) {
      final base = fallbackPrice > 0 ? fallbackPrice : 1.0;
      dataPoints = [base, base];
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i]));
    }

    var minY = spots.map((s) => s.y).reduce(math.min);
    var maxY = spots.map((s) => s.y).reduce(math.max);
    if ((maxY - minY).abs() < 1e-9) {
      minY -= 0.01;
      maxY += 0.01;
    }

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [lineColor.withOpacity(0.35), lineColor.withOpacity(0.0)],
    );

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (dataPoints.length - 1).toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 1.5,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, gradient: gradient),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 150),
    );
  }
}

class _ActiveAccountBar extends StatelessWidget {
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const _ActiveAccountBar({
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  void _showAccountBottomSheet(BuildContext context) {
    showDashboardBottomSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AccountController>()) {
      return const SizedBox.shrink();
    }
    final accountController = Get.find<AccountController>();

    return Obx(() {
      final activeAccount = accountController.activeMT5Account;
      final accNumber = activeAccount?.metaAccountNumber ?? '------';
      final accType = (activeAccount?.accountType ?? 'REAL').toUpperCase();
      final equity = '\$${activeAccount?.equity ?? '0.00'}';
      final pnl = '\$${activeAccount?.profit ?? '0.00'}';

      return InkWell(
        onTap: () => _showAccountBottomSheet(context),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.primary,
                      size: 20.r,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Account: #$accNumber',
                            style: AppTextStyles.bodyText.copyWith(
                              color: textPrimary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 1.h,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  accType == 'DEMO'
                                      ? Colors.orange.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              accType,
                              style: AppTextStyles.bodyText.copyWith(
                                color:
                                    accType == 'DEMO'
                                        ? Colors.orange
                                        : Colors.green,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'P&L: $pnl  |  Equity: $equity',
                        style: AppTextStyles.bodyText.copyWith(
                          color: textSecondary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: textSecondary,
                size: 22.r,
              ),
            ],
          ),
        ),
      );
    });
  }
}
