import 'package:crm_app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class PartnershipProgramScreen extends StatefulWidget {
  const PartnershipProgramScreen({super.key});

  @override
  State<PartnershipProgramScreen> createState() =>
      _PartnershipProgramScreenState();
}

class _PartnershipProgramScreenState extends State<PartnershipProgramScreen> {
  bool _isApplicationSubmitted = false;

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final moreController = Get.find<MoreController>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: Text(
          languageService.tr('partnership_program'),
          style: AppTextStyles.screenTitle,
        ),
        leading: const AppBackButton(),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verification Cards Grid
            _buildVerificationCards(
              languageService,
              moreController.dashboardModel.value?.data?.stageCompletion,
            ),

            // Submit IB Application Button
            _buildSubmitButton(
              languageService,
              moreController.dashboardModel.value?.data?.stageCompletion,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCards(
    LanguageService languageService,
    dynamic stageCompletion,
  ) {
    // Check verification status from API data
    final isEmailVerified = stageCompletion?.emailVerified != null;
    final isMobileVerified = stageCompletion?.mobileVerified != null;
    final isPersonalInfoVerified = stageCompletion?.personalDetails == true;
    final isIbRequestCompleted =
        stageCompletion?.identityVerified == true &&
        stageCompletion?.addressProofVerified == true;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16.w,
      mainAxisSpacing: 16.h,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: [
        _buildVerificationCard(
          icon: 'assets/svg/partnership_program/email.svg',
          title: languageService.tr('email_verification'),
          isCompleted: isEmailVerified,
          isPending: !isEmailVerified,
          onTap: () {
            // Handle email verification
          },
        ),
        _buildVerificationCard(
          icon: 'assets/svg/partnership_program/mobile.svg',
          title: languageService.tr('mobile_verification'),
          isCompleted: isMobileVerified,
          isPending: !isMobileVerified,
          onTap: () {
            // Handle mobile verification
          },
        ),
        GetBuilder<MoreController>(
          builder: (controller) {
            return _buildVerificationCard(
              icon: 'assets/svg/partnership_program/document-copy.svg',
              title: languageService.tr('personal_information'),
              isCompleted: isPersonalInfoVerified,
              isPending: !isPersonalInfoVerified,
              onTap: () async {
                final model = controller.dashboardModel.value;
                final stage = model?.data?.stageCompletion;
                // Navigate to KYC intro and refresh data when returning
                await Get.toNamed(AppPages.KYC_INTRO, arguments: stage);
                // Refresh data when returning from KYC screens
                controller.loadMoreScreenData();
                // Handle personal information
              },
            );
          },
        ),
        _buildVerificationCard(
          icon: 'assets/svg/partnership_program/message-question.svg',
          title: languageService.tr('ib_request'),
          isCompleted: isIbRequestCompleted,
          isPending: !isIbRequestCompleted,
          onTap: () {
            // Handle IB request
          },
        ),
      ],
    );
  }

  Widget _buildVerificationCard({
    required String icon,
    required String title,
    required bool isCompleted,
    bool isPending = false,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 163.5,
      height: 98,
      padding: EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // 10% opacity
            blurRadius: 6, // matches Figma blur
            offset: const Offset(0, 0), // X: 0, Y: 0
            spreadRadius: 0,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(0.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with status indicator
              Stack(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        '$icon',
                        width: 30.55.w,
                        height: 30.55.w,
                        colorFilter: ColorFilter.mode(
                          AppColors.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  // Status indicator
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        color:
                            isCompleted
                                ? AppColors.primary
                                : isPending
                                ? Colors.orange
                                : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.whiteColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isCompleted
                              ? Icons.check
                              : isPending
                              ? Icons.priority_high
                              : Icons.close,
                          size: 12.w,
                          color: AppColors.whiteColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              // Title
              Text(
                title,
                style: AppTextStyles.labelOnChartPendingOrder.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(
    LanguageService languageService,
    dynamic stageCompletion,
  ) {
    // Check if all verifications are completed
    final isEmailVerified = stageCompletion?.emailVerified != null;
    final isMobileVerified = stageCompletion?.mobileVerified != null;
    final isPersonalInfoVerified = stageCompletion?.personalDetails == true;

    final canSubmit =
        isEmailVerified && isMobileVerified && isPersonalInfoVerified;

    return ElevatedButton(
      onPressed:
          _isApplicationSubmitted
              ? () async {
                // Navigate using IBM Gatekeeper
                final ibmController = Get.put(IbmController());
                await ibmController.checkSystemAndNavigate();
              }
              : canSubmit
              ? _showIbApplicationDialog
              : null,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor:
            _isApplicationSubmitted || canSubmit
                ? AppColors.primary
                : Colors.grey,
        foregroundColor: AppColors.whiteColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        elevation: 0,
      ),
      child: Text(
        _isApplicationSubmitted
            ? 'IB Dashboard'
            : languageService.tr('submit_ib_application'),
        style: AppTextStyles.button.copyWith(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showIbApplicationDialog() {
    bool isAgreed = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              'IB Application',
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            width: 23.w,
                            height: 23.w,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/svg/partnership_program/cancel.svg',
                                  width: 30.55.w,
                                  height: 30.55.w,
                                  colorFilter: ColorFilter.mode(
                                    AppColors.textPrimary,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    // Content
                    Text(
                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.33,
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 16.h,
                          width: 16.w,
                          child: Checkbox(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            activeColor: AppColors.primary,
                            checkColor: AppColors.whiteColor,
                            side: BorderSide(
                              color: AppColors.textGrey,
                              width: 1.5,
                            ),
                            fillColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.primary;
                              }
                              return AppColors.card;
                            }),
                            value: isAgreed,
                            onChanged: (value) {
                              setDialogState(() {
                                isAgreed = value ?? false;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'I agree to the IB Terms',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              height: 1.58,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20.h),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton(
                        onPressed:
                            isAgreed
                                ? () async {
                                  Navigator.of(context).pop();
                                  await _submitIBApplication();
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.whiteColor,
                          disabledBackgroundColor: AppColors.neutralTrack,
                          disabledForegroundColor: AppColors.textSecondary,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Submit',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.whiteColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitIBApplication() async {
    try {
      // Get or create IBController
      IBController ibController;
      if (Get.isRegistered<IBController>()) {
        ibController = Get.find<IBController>();
      } else {
        ibController = Get.put(IBController());
      }

      // Show loading
      Get.dialog(
        Center(
          child: CommonLoadingWidget(
            message: 'Submitting IB application...',
            size: 50.0,
            color: AppColors.primary,
          ),
        ),
        barrierDismissible: false,
      );

      // Submit IB Application
      final success = await ibController.submitIBApplication(
        termsAccepted: true,
      );

      // Close loading dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (success) {
        // Wait briefly to allow the loading dialog pop animation to finish.
        // This prevents Flutter Navigator from getting confused by simultaneous pops.
        await Future.delayed(const Duration(milliseconds: 150));

        // Pop the IB application dialog
        if (Get.isDialogOpen ?? false) {
          Get.back();
        } else {
          Navigator.of(context).pop();
        }

        // Wait briefly again
        await Future.delayed(const Duration(milliseconds: 50));

        // Navigate back to the settings screen
        Get.back();
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      CustomToastService.showError(
        message: 'Error submitting IB application: $e',
      );
    }
  }
}
