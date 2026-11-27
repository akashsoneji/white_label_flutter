import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/plan_controller.dart';
import 'package:crm_app/screens/home/create_crm_app_account_screen.dart';
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
  /// Narrowest a plan card may get; the grid adds a column only when every
  /// card still has this much room (1 on phones, 2 on tablets, 3 wider).
  static const double _minCardWidth = 300.0;

  final PlanController planController = Get.put(PlanController());
  final LanguageService languageService = Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    // Fetch plans based on isDemo parameter (default to false for live accounts)
    planController.fetchPlan(isDemo: widget.isDemo ?? false);
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
            // _buildInstructionalText(),

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
      padding: EdgeInsetsDirectional.only(
        start: 40.w,
        end: 40.w,
        top: 16.h,
        bottom: 8.h,
      ),
      child: Text(
        languageService.tr(
          'choose_account_screen_choose_an_account_type_you_like',
        ),
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyText.copyWith(
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
      final List<PlanModel> plans =
          planController.plan.value != null
              ? [planController.plan.value!]
              : planController.plans.toList();
      if (plans.isEmpty) {
        return Center(
          child: Text(languageService.tr('choose_account_no_plans')),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = 16.w;
          final double spacing = 12.w;
          final double availableWidth =
              constraints.maxWidth - horizontalPadding * 2;
          final int columns =
              (availableWidth / _minCardWidth).floor().clamp(1, 3).toInt();
          final double cardWidth =
              (availableWidth - spacing * (columns - 1)) / columns;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 8.h,
            ),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final plan in plans)
                  SizedBox(width: cardWidth, child: _buildAccountCard(plan)),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildAccountCard(PlanModel accountType) {
    final List<MapEntry<String, String>> specs = [
      MapEntry(
        languageService.tr('choose_account_spread_from'),
        accountType.spread?.toString() ?? '',
      ),
      MapEntry(
        languageService.tr('bonus_screen_min_deposit'),
        accountType.minimumDeposit ?? '',
      ),
      MapEntry(
        languageService.tr('choose_account_maximum_leverage'),
        accountType.leverage ?? '',
      ),
      MapEntry(
        languageService.tr('choose_account_stop_out_level'),
        accountType.stopOutLevel ?? '',
      ),
      for (final property in accountType.customProperties)
        MapEntry(property.label, property.value),
    ];
    final String instruments = accountType.tradingInstruments ?? '';

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            accountType.planTitle ?? '',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              height: 1.3,
            ),
          ),
          SizedBox(height: 8.h),
          _buildSpecTiles(specs),
          if (instruments.isNotEmpty) ...[
            SizedBox(height: 6.h),
            _buildSpecTile(
              languageService.tr('instruments_title'),
              instruments,
            ),
          ],
          SizedBox(height: 10.h),
          SizedBox(
            height: 38.h,
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10.r),
              child: InkWell(
                borderRadius: BorderRadius.circular(10.r),
                onTap: () => _onOpenAccount(accountType),
                child: Center(
                  child: Text(
                    languageService.tr('dashboard_open_account'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.whiteColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Two tiles per row; long values wrap inside their tile instead of being
  /// cut off.
  Widget _buildSpecTiles(List<MapEntry<String, String>> specs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double gap = 6.w;
        // Floored so two tiles plus the gap never round past the row width.
        final double tileWidth =
            ((constraints.maxWidth - gap) / 2).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final spec in specs)
              SizedBox(
                width: tileWidth,
                child: _buildSpecTile(spec.key, spec.value),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSpecTile(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.icongrey,
              height: 1.3,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value.isEmpty ? '-' : value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
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
