import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class KycIntroScreen extends StatelessWidget {
  final StageCompletion? stageCompletion;

  const KycIntroScreen({Key? key, this.stageCompletion}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: AppColors.grey)),
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.backgroundLight,
        leading: const AppBackButton(),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24.h),

                    // Header Section
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Verify your account",
                            style: AppTextStyles.black24600h1_42,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'To open your trading account, we first need to verify your identity',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.icongrey,
                              height: 1.36,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // Step 1 Card - Personal Details
                    _buildStepCard(
                      stepNumber: 1,
                      title: languageService.tr('kyc_intro_personal_details'),
                      status:
                          stageCompletion?.mobileVerified != null &&
                                  stageCompletion?.emailVerified != null &&
                                  stageCompletion?.personalDetails == true
                              ? 'Completed'
                              : 'Incomplete',
                      backgroundColor:
                          stageCompletion?.mobileVerified != null &&
                                  stageCompletion?.emailVerified != null &&
                                  stageCompletion?.personalDetails == true
                              ? AppColors
                                  .kycStageComplete // Light green
                              : AppColors.kycStageActive, // Light purple
                      iconColor:
                          stageCompletion?.mobileVerified != null &&
                                  stageCompletion?.emailVerified != null &&
                                  stageCompletion?.personalDetails == true
                              ? Colors.green
                              : AppColors.primary,
                      textColor:
                          stageCompletion?.mobileVerified != null &&
                                  stageCompletion?.emailVerified != null &&
                                  stageCompletion?.personalDetails == true
                              ? Colors.green
                              : AppColors.primary,
                      features: [
                        'Deposit up to \$2000 within 14 days',
                        'Limited deposit methods',
                        'Live & demo trading',
                      ],
                      isActive:
                          stageCompletion?.mobileVerified != null &&
                                  stageCompletion?.emailVerified != null &&
                                  stageCompletion?.personalDetails == true
                              ? false
                              : true,
                    ),

                    SizedBox(height: 24.h),

                    // Step 2 Card - ID Verification
                    _buildStepCard(
                      stepNumber: 2,
                      title: languageService.tr('kyc_intro_id_verification'),
                      status:
                          stageCompletion?.identityVerified == true &&
                                  stageCompletion?.addressProofVerified == true
                              ? 'Completed'
                              : 'Incomplete',
                      backgroundColor:
                          stageCompletion?.identityVerified == true &&
                                  stageCompletion?.addressProofVerified == true
                              ? AppColors
                                  .kycStageComplete // Light green
                              : (stageCompletion?.mobileVerified != null &&
                                  stageCompletion?.emailVerified != null &&
                                  stageCompletion?.personalDetails == true)
                              ? AppColors.kycStageActive
                              : AppColors.surface,
                      iconColor:
                          stageCompletion?.identityVerified == true &&
                                  stageCompletion?.addressProofVerified == true
                              ? Colors.green
                              : Colors.grey[400]!,
                      textColor:
                          stageCompletion?.identityVerified == true &&
                                  stageCompletion?.addressProofVerified == true
                              ? Colors.green
                              : (stageCompletion?.mobileVerified != null &&
                                  stageCompletion?.emailVerified != null &&
                                  stageCompletion?.personalDetails == true)
                              ? AppColors.primary.withAlpha(1000)
                              : Colors.grey[400]!,
                      features: [
                        'Unlimited deposits',
                        'Global and local payments',
                        'Withdrawals',
                      ],
                      isActive: stageCompletion?.identityVerified == true,
                    ),

                    SizedBox(height: 24.h),

                    // Step 3 Card - Address Verification
                    _buildStepCard(
                      stepNumber: 3,
                      title: languageService.tr(
                        'kyc_intro_address_verification',
                      ),
                      status:
                          stageCompletion?.addressProofVerified == true
                              ? 'Completed'
                              : stageCompletion?.identityVerified == true
                              ? 'Available'
                              : 'Locked',
                      textColor:
                          stageCompletion?.addressProofVerified == true
                              ? Colors.green
                              : stageCompletion?.identityVerified == true
                              ? AppColors.primary
                              : Colors.grey[400]!,
                      backgroundColor:
                          stageCompletion?.addressProofVerified == true
                              ? AppColors
                                  .kycStageComplete // Light green
                              : stageCompletion?.identityVerified == true
                              ? AppColors
                                  .kycStageActive // Light purple
                              : AppColors.surface,
                      iconColor:
                          stageCompletion?.addressProofVerified == true
                              ? Colors.green
                              : stageCompletion?.identityVerified == true
                              ? AppColors.primary
                              : Colors.grey[400]!,
                      features: [
                        'Unlimited deposits',
                        'Global and local payments',
                        'Withdrawals',
                      ],
                      isActive: stageCompletion?.identityVerified == true,
                    ),

                    SizedBox(height: 90.h),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(height: 80.h, color: AppColors.whiteColor),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                child: ElevatedButton(
                  onPressed: () {
                    if (stageCompletion?.mobileVerified == null ||
                        stageCompletion?.emailVerified == null ||
                        stageCompletion?.personalDetails == false) {
                      Get.toNamed(AppPages.KYC_DETAILS);
                    } else if (stageCompletion?.identityVerified == false ||
                        stageCompletion?.addressProofVerified == false) {
                      Get.toNamed(AppPages.KYC_DOCS);
                    } else {
                      Get.toNamed(
                        AppPages.KYC_BANK,
                        arguments: {
                          'screen_name': 'Add Withdrawal Method',
                          'isFromKYC': true,
                        },
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.whiteColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                  ),
                  child: Text(
                    'Start Verification',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.whiteColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required String status,
    required Color backgroundColor,
    required Color iconColor,
    required Color textColor,
    required List<String> features,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        if (stageCompletion?.mobileVerified == null ||
            stageCompletion?.emailVerified == null ||
            stageCompletion?.personalDetails == false) {
          Get.toNamed(AppPages.KYC_DETAILS);
        } else if (stageCompletion?.identityVerified == false ||
            stageCompletion?.addressProofVerified == false) {
          Get.toNamed(AppPages.KYC_DOCS);
        } else {
          Get.toNamed(
            AppPages.KYC_BANK,
            arguments: {
              'screen_name': 'Add Withdrawal Method',
              'isFromKYC': true,
            },
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border:
              isActive
                  ? Border.all(color: AppColors.primary, width: 1)
                  : Border.all(
                    color: AppColors.kycFeatureBorder.withOpacity(0.6),
                    width: 1,
                  ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              stepNumber == 1
                  ? "assets/svg/kyc/profile-circle.svg"
                  : "assets/svg/kyc/personalcard.svg",
              height: 24.h,
              width: 24.w,
              color: AppColors.primary,
            ),
            SizedBox(width: 10.w),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with title + status on right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon with white outline
                      // SizedBox(width: 16.w),
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step $stepNumber',
                              style: AppTextStyles.black16600,
                            ),
                            Text('$title', style: AppTextStyles.black16600),
                          ],
                        ),
                      ),
                      // Status on the right
                      Text(
                        status,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  // Features list
                  ...features.map(
                    (feature) => Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SvgPicture.asset(
                            'assets/svg/kyc/tick-circle.svg',
                            height: 16.h,
                            width: 16.w,
                            color: AppColors.icongrey,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              feature,
                              style: AppTextStyles.black11400.copyWith(
                                height: 1.29,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
