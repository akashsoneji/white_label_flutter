import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/plan_controller.dart';
import 'package:crm_app/screens/home/create_crm_app_account_screen.dart';
import 'package:crm_app/widgets/dashBorder.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/services/language_service.dart';
import '../../routes/app_pages.dart';

class ChooseAccountScreen extends StatefulWidget {
  final bool? isDemo;

  const ChooseAccountScreen({Key? key, this.isDemo}) : super(key: key);

  @override
  State<ChooseAccountScreen> createState() => _ChooseAccountScreenState();
}

class _ChooseAccountScreenState extends State<ChooseAccountScreen> {
  static const double _cardViewportFraction = 0.85;
  late final PageController _pageController;
  int _currentIndex = 0;

  final PlanController planController = Get.put(PlanController());
  final LanguageService languageService = Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _cardViewportFraction);
    // Fetch plans based on isDemo parameter (default to false for live accounts)
    planController.fetchPlan(isDemo: widget.isDemo ?? false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: AppColors.grey)),
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.backgroundLight,
        leading: AppBackButton(
          onPressed: () {
            final args = Get.arguments;
            if (args != null &&
                args is Map &&
                args['from'] == 'account_created') {
              Get.offAllNamed(AppPages.TRADING);
            } else {
              Get.back(closeOverlays: true);
            }
          },
        ),
        title: Text(
          languageService.tr('choose_account_title'),
          style: AppTextStyles.heading,
        ),
      ),
      // backgroundColor: AppAppColors.whiteColorColor,
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Instructional Text
            _buildInstructionalText(),

            // Account Cards with proper spacing
            Expanded(
              child: Container(
                margin: EdgeInsets.only(top: 8.h, bottom: 16.h),
                child: _buildAccountCards(),
              ),
            ),

            // Page Indicator
            // _buildPageIndicator(),
            // SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionalText() {
    return Padding(
      padding: EdgeInsets.only(left: 40.w, right: 40.w, top: 16.h, bottom: 8.h),
      child: Text(
        'Choose an account type you\'d like to start trading with',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17.sp,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
          height: 1.59,
        ),
      ),
    );
  }

  Widget _buildAccountCards() {
    return Obx(() {
      if (planController.isLoading.value) {
        return Center(
          child: CommonLoadingWidget(size: 50.0, color: AppColors.primary),
        );
      }
      if (planController.errorMessage.isNotEmpty) {
        return Center(child: Text(planController.errorMessage.value));
      }
      if (planController.plan.value != null) {
        return Center(child: _buildAccountCard(planController.plan.value!, 0));
      }
      if (planController.plans.isNotEmpty) {
        print('planController.plans.length ${planController.plans.length}');
        return PageView.builder(
          controller: _pageController,
          clipBehavior: Clip.none,
          padEnds: true,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemCount: planController.plans.length,
          itemBuilder: (context, index) {
            return _buildAccountCard(planController.plans[index], index);
          },
        );
      }
      return Center(child: Text(languageService.tr('choose_account_no_plans')));
    });
  }

  Widget _buildAccountCard(PlanModel accountType, int index) {
    final bool isCurrentCard = index == _currentIndex;
    final double cardWidth = _calculateCardWidth(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardWidth, minWidth: cardWidth),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          padding: EdgeInsets.all(Platform.isIOS ? 16.w : 20.w),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.primary),
            boxShadow:
                isCurrentCard
                    ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.12),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                        spreadRadius: 2,
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 6),
                      ),
                    ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${accountType.tradingPlatform ?? ''} ${accountType.planTitle ?? ''}',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSpecificationRow(
                    'Spread from',
                    accountType.spread?.toString() ?? "",
                  ),
                  _buildDivider(),
                  _buildSpecificationRow(
                    'Instruments',
                    accountType.tradingInstruments ?? "",
                    maxLine: 2,
                  ),
                  _buildDivider(),
                  _buildSpecificationRow(
                    'Min deposit',
                    accountType.minimumDeposit ?? "",
                  ),
                  _buildDivider(),
                  _buildSpecificationRow(
                    'Maximum leverage',
                    accountType.leverage ?? "",
                  ),
                  _buildDivider(),
                  _buildSpecificationRow(
                    'Margin call',
                    accountType.marginCallLevel ?? "-",
                  ),
                  _buildDivider(),
                  _buildSpecificationRow(
                    'Stop Out level',
                    accountType.stopOutLevel ?? "",
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              SizedBox(
                width: double.infinity,
                height: 44.h,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: () => _onOpenAccount(accountType),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Open Account',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.whiteColor,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateCardWidth(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double maxWidth = 420.0;
    const double minWidth = 320.0;
    final double width = screenWidth * _cardViewportFraction;
    if (width > maxWidth) return maxWidth;
    if (width < minWidth) return minWidth;
    return width;
  }

  Widget _buildSpecificationRow(String label, String value, {int maxLine = 1}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                height: 1.38,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            flex: 2,
            child: Text(
              value,
              maxLines: maxLine,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.sp,
                overflow: TextOverflow.ellipsis,
                fontWeight: FontWeight.w500,
                color: AppColors.icongrey,
                height: 1.57,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return DashedUnderline();
    // return Container(height: 1, color: Colors.grey[200]);
  }

  void _onOpenAccount(PlanModel accountType) {
    print('accountType.planTitle ${accountType.id}');
    print('accountType.planTitle ${accountType.planTitle}');
    // Navigate to the new app account creation screen
    Get.to(
      () => CreateCrmAppAccountScreen(
        accountType: accountType.planTitle ?? "",
        isDemo: false,
        plan: accountType,
      ),
    );
  }
}
