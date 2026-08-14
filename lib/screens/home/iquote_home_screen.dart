import 'dart:async';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/home/brands/iquote/iquote_chart_screen.dart';
import 'package:crm_app/screens/home/brands/iquote/view_models/iquote_chart_controller.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:crm_app/widgets/dashboard_bottom_sheet.dart';

class IquoteHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final Function(String)? onNavigateToChart;

  const IquoteHomeScreen({
    super.key,
    this.onNavigateToTab,
    this.onNavigateToChart,
  });

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


    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          // padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 30.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header: User Profile Icon (Left) + App Logo (60x60) Centered (Center)
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Promotional button
                    GestureDetector(
                      onTap: () => Get.to(() => const PromotionalScreen()),
                      child: CircleAvatar(
                        radius: 18.r,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        child: Icon(
                          Icons.card_giftcard,
                          size: 18.r,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                    // Centered Logo
                    Expanded(
                      child: Center(
                        child:
                            FlavorConfig.instance.flavor == Flavor.pipze
                                ? BrandLogo(
                                  source: FlavorConfig.instance.splashLogoPath,
                                  height: 28.h,
                                  fit: BoxFit.contain,
                                )
                                : ClipOval(
                                  child: BrandLogo(
                                    source: FlavorConfig.effectiveLogo,
                                    width: 42.r,
                                    height: 42.r,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                      ),
                    ),

                    // Switch account dashboard icon
                    GestureDetector(
                      onTap: () => showDashboardBottomSheet(context),
                      child: CircleAvatar(
                        radius: 18.r,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        child: Icon(
                          Icons.dashboard_outlined,
                          size: 18.r,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 2. Promo Banner Carousel
              _PromoCarousel(
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                isDark: isDark,
              ),

              // 3. Quick Shortcuts Card
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.border.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0.h),
                        child: Text(
                          'Quick Shortcuts',
                          style: AppTextStyles.bodyText.copyWith(
                            color: textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Padding(
                        padding: EdgeInsets.fromLTRB(12.w, 0.h, 12.w, 12.h),
                        child: GridView.count(
                          padding: EdgeInsets.zero,
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8.h,
                          crossAxisSpacing: 8.w,
                          childAspectRatio: 0.88,
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
                              onTap:
                                  () => Get.to(() => const PromotionalScreen()),
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
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Favourites Card
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.border.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0.h),
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
                      SizedBox(height: 4.h),
                      Padding(
                        padding: EdgeInsets.fromLTRB(12.w, 0.h, 12.w, 12.h),
                        child: _buildLiveFavouritesGrid(
                          cardBg,
                          textPrimary,
                          textSecondary,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
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

      return Column(
        children: List.generate(displayList.length, (index) {
          final item = displayList[index];
          return Column(
            children: [
              Dismissible(
                key: Key('fav_${item.symbol}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                    size: 20.r,
                  ),
                ),
                onDismissed: (direction) {
                  _ic.removeFromFavorites(item.symbol);
                  CustomToastService.showSuccess(
                    message: '${item.symbol.replaceAll('.c', '').replaceAll('.r', '')} removed from favorites',
                  );
                },
                child: _LiveTickerCard(
                  instrument: item,
                  controller: _ic,
                  cardBg: cardBg,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                  onNavigateToTab: widget.onNavigateToTab,
                  onNavigateToChart: widget.onNavigateToChart,
                ),
              ),
              if (index < displayList.length - 1)
                Divider(
                  height: 12.h,
                  thickness: 0.5,
                  color: AppColors.border.withOpacity(0.08),
                ),
            ],
          );
        }),
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
    final isDark = AppColors.isDarkMode;
    final iconBg = isDark
        ? color.withOpacity(0.15)
        : color.withOpacity(0.10);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 40.r,
                width: 40.r,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.18),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: color,
                    size: 20.r,
                  ),
                ),
              ),
              if (isHot)
                Positioned(
                  top: -2.h,
                  right: -2.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'HOT',
                      style: AppTextStyles.bodyText.copyWith(
                        color: Colors.white,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              color: textColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              height: 1.1,
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
    final descName = instrument.name ?? '';

    return Obx(() {
      final livePrice = controller.priceRx(sym).value;

      double currentBid = livePrice.bid > 0 ? livePrice.bid : instrument.bid;
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

      final changeBg =
          isUp
              ? const Color(0xFF2ED573).withOpacity(0.12)
              : const Color(0xFFFF4757).withOpacity(0.12);
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
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          child: Row(
            children: [
              _HomeFlagIcon(symbol: displaySym),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displaySym,
                      style: AppTextStyles.bodyText.copyWith(
                        color: textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (descName.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        descName,
                        style: AppTextStyles.bodyText.copyWith(
                          color: textSecondary,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    PrecisionHelper.formatPrice(currentBid, decimals: digits),
                    style: AppTextStyles.bodyText.copyWith(
                      color: textPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: changeBg,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      changeStr,
                      style: AppTextStyles.bodyText.copyWith(
                        color: changeColor,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _HomeFlagIcon extends StatelessWidget {
  final String symbol;
  const _HomeFlagIcon({required this.symbol});

  @override
  Widget build(BuildContext context) {
    String clean =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;

    final flagPath = 'assets/svg/flags/${clean.toLowerCase()}.svg';

    return SizedBox(
      width: 24.w,
      height: 24.w,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Padding(
            padding: EdgeInsets.all(2.r),
            child: SvgPicture.asset(
              flagPath,
              fit: BoxFit.cover,
              placeholderBuilder: (_) => Icon(
                Icons.monetization_on_outlined,
                size: 14.r,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const _PromoCarousel({
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Profit & Bonus Ranking',
      'subtitle': 'Data updated daily',
      'btn': 'View',
      'icon': Icons.emoji_events,
      'iconColor': Colors.orange,
      'action': () => Get.toNamed(AppPages.CHOOSE_ACCOUNT),
    },
    {
      'title': 'Refer & Earn Program',
      'subtitle': 'Invite friends, earn rebates',
      'btn': 'Invite',
      'icon': Icons.group_add_outlined,
      'iconColor': Colors.blue,
      'action': () => IquoteHomeScreen.handleSwitchToIB(),
    },
    {
      'title': 'Exclusive Promotions',
      'subtitle': 'Claim your trading bonuses',
      'btn': 'Claim',
      'icon': Icons.card_giftcard,
      'iconColor': Colors.red,
      'action': () => Get.to(() => const PromotionalScreen()),
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final next = (_currentPage + 1) % _slides.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 4.h),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            height: 124.h,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (val) => setState(() => _currentPage = val),
              itemCount: _slides.length,
              itemBuilder: (context, i) {
                final s = _slides[i];
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 20.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          widget.isDark
                              ? [
                                const Color(0xFF2C344E),
                                const Color(0xFF1E2436),
                              ]
                              : [
                                AppColors.primary.withOpacity(0.08),
                                AppColors.primary.withOpacity(0.02),
                              ],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(
                        widget.isDark ? 0.1 : 0.15,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s['title'],
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: widget.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              s['subtitle'],
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                                color: widget.textSecondary,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            GestureDetector(
                              onTap: s['action'],
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  s['btn'],
                                  style: AppTextStyles.bodyText.copyWith(
                                    color: AppColors.whiteColor,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(s['icon'], size: 56.r, color: s['iconColor']),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 8.h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (idx) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
                  width: _currentPage == idx ? 14.w : 5.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color:
                        _currentPage == idx
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
