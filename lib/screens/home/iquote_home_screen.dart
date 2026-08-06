import 'dart:async';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/home/brands/iquote/iquote_chart_screen.dart';
import 'package:crm_app/screens/home/brands/iquote/view_models/iquote_chart_controller.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:crm_app/screens/home/more/promotional/promotional_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/home/search_instruments_screen.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class IquoteHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final Function(String)? onNavigateToChart;

  const IquoteHomeScreen({super.key, this.onNavigateToTab, this.onNavigateToChart});

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

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<InstrumentsController>()) {
      _ic = Get.put(InstrumentsController());
    } else {
      _ic = Get.find<InstrumentsController>();
    }
  }

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
    final bgDark = AppColors.background;
    final cardBg = AppColors.card;
    final textPrimary = AppColors.textPrimary;
    final textSecondary = AppColors.textSecondary;
    final isDark = AppColors.isDarkMode;

    final appTitle =
        FlavorConfig.instance.appTitle.isNotEmpty
            ? FlavorConfig.instance.appTitle
            : FlavorConfig.instance.appName;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          // padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 30.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header: App Logo + Bold Title (brand primary)
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: BrandLogo(
                        source: FlavorConfig.effectiveLogo,
                        width: 32.w,
                        height: 32.w,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      appTitle,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
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
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0.h),
                child: Container(
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
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withOpacity(isDark ? 0.35 : 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
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
              ),
              
              SizedBox(height: 10.h),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal:10.0),
                child: Card(
                  child: Column(
                    children: [
                         SizedBox(height: 16.h),
                  
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
                               
                    ],
                  ),
                ),
              ),

              // Divider(
              //   thickness: 1,
              //   color: AppColors.border,
              //   height: 1,
              // ),
              // SizedBox(height: 16.h),

              // 4. 8 Shortcuts Grid
             // SizedBox(height: 16.h),

              // Divider(
              //   thickness: 1,
              //   color: AppColors.border,
              //   height: 1,
              // ),
              // SizedBox(height: 14.h),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal:10.0),
                child: Card(
                  elevation: 1,
                  // shadowColor: AppColors.hint,
                  child: Column(
                    children: [
                   // 6. Favourites Section Header + Add Button
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 0.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Favourites',
                        style: AppTextStyles.bodyText.copyWith(
                          color: textPrimary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
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
                ),
                
                // Live Favourites Grid with Mini Sparkline Charts
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0.h),
                  child: _buildLiveFavouritesGrid(
                    cardBg,
                    textPrimary,
                    textSecondary,
                    isDark,
                  ),
                ),
                SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),

             
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
          childAspectRatio: 2.2, 
        ),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          return _LiveTickerCard(
            instrument: displayList[index],
            controller: _ic,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
            onNavigateToTab: widget.onNavigateToTab,
            onNavigateToChart: widget.onNavigateToChart,
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
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;
  final Function(int)? onNavigateToTab;
  final Function(String)? onNavigateToChart;

  const _LiveTickerCard({
    required this.instrument,
    required this.controller,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
    this.onNavigateToTab,
    this.onNavigateToChart,
  });

  @override
  Widget build(BuildContext context) {
    final sym = instrument.symbol;
    final displaySym =
        sym.contains('.') ? sym.substring(0, sym.lastIndexOf('.')) : sym;
    final digits = instrument.digits;

    return Obx(() {
      final livePrice = controller.priceRx(sym).value;

      double currentBid =
          livePrice.bid > 0
              ? livePrice.bid
              : instrument.bid;
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

      final changeColor =
          isUp ? const Color(0xFF2ED573) : const Color(0xFFFF4757);
      final changeStr = '$sign${changePct.abs().toStringAsFixed(2)}%';

      return InkWell(
        onTap: () {
          if (onNavigateToChart != null) {
            onNavigateToChart!(sym);
          } else if (onNavigateToTab != null) {
            onNavigateToTab!(2);
            if (Get.isRegistered<IQuoteChartController>()) {
              Get.find<IQuoteChartController>().forceSwitchSymbol(sym);
            } else {
              Get.put(IQuoteChartController(sym));
            }
          } else {
            Get.to(() => IQuoteChartScreen(symbol: sym));
          }
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.28 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
                spreadRadius: 0,
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
            ],
          ),
        ),
      );
    });
  }
}

