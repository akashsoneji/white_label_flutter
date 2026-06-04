import 'package:crm_app/screens/home/trading_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/screens/copy_trading/view_models/copy_trading_hub_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/labeled_app_text_field.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class BecomeMasterTab extends StatefulWidget {
  const BecomeMasterTab({super.key});

  @override
  State<BecomeMasterTab> createState() => _BecomeMasterTabState();
}

class _BecomeMasterTabState extends State<BecomeMasterTab> {
  final _nicknameCtrl = TextEditingController();
  final _strategyCtrl = TextEditingController();
  final _riskInfoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final hub = Get.find<CopyTradingHubController>();
    hub.resetMasterApplyForm();
    _nicknameCtrl.clear();
    _strategyCtrl.clear();
    _riskInfoCtrl.clear();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _strategyCtrl.dispose();
    _riskInfoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hub = Get.find<CopyTradingHubController>();
    final auth = Get.find<AuthController>();
    final user = auth.userData;

    MoreController? moreController;
    if (Get.isRegistered<MoreController>()) {
      moreController = Get.find<MoreController>();
    } else {
      moreController = Get.put(MoreController());
    }

    final userName =
        user != null
            ? '${user.firstName} ${user.lastName}'.trim()
            : 'demo account';

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAll(() => TradingMainScreen()),
        ),
        title: Text(
          'Become a Master Trader',
          style: AppTextStyles.screenTitle.copyWith(fontSize: 16.sp),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Obx(() {
          final status = hub.masterStatus.value;
          final code = hub.masterCode.value;
          final canSubmit = hub.canSubmitMasterApply;
          final applying = hub.isLoading.value;

          final stage =
              moreController?.dashboardModel.value?.data?.stageCompletion;
          final isEmailVerified = stage?.emailVerified != null;
          final isMobileVerified = stage?.mobileVerified != null;
          final isPersonalInfoVerified = stage?.personalDetails == true;
          final isKycCompleted =
              isEmailVerified && isMobileVerified && isPersonalInfoVerified;

          // If pending, show the pending review message
          if (status == CopyTradingMasterApplicationStatus.pending) {
            return _buildPendingReviewView(code);
          }

          final applyBtnFg =
              AppColors.primary.computeLuminance() > 0.5
                  ? AppColors.textPrimaryLight
                  : AppColors.onColoredBackground;
          final isDark = AppColors.isDarkMode;
          final checkBorder =
              isDark ? AppColors.textPrimaryDark : AppColors.primary;
          final checkFill =
              isDark ? AppColors.textPrimaryDark : AppColors.primary;
          final checkMark =
              isDark
                  ? AppColors.textPrimaryLight
                  : AppColors.onColoredBackground;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Complete all steps to become a Copy Trading Master',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),

              // ── Step checklist cards ──
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10.h,
                crossAxisSpacing: 10.w,
                childAspectRatio: 1.5,
                children: [
                  _buildStepCard(
                    title: 'Email Verification',
                    completed: isEmailVerified,
                    icon:
                        isEmailVerified
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                    onTap: () async {
                      if (!isEmailVerified) {
                        final stage =
                            moreController
                                ?.dashboardModel
                                .value
                                ?.data
                                ?.stageCompletion;
                        await Get.toNamed(AppPages.KYC_INTRO, arguments: stage);
                        moreController?.loadMoreScreenData();
                      }
                    },
                  ),
                  _buildStepCard(
                    title: 'Mobile Verification',
                    completed: isMobileVerified,
                    icon:
                        isMobileVerified
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                    onTap: () async {
                      if (!isMobileVerified) {
                        final stage =
                            moreController
                                ?.dashboardModel
                                .value
                                ?.data
                                ?.stageCompletion;
                        await Get.toNamed(AppPages.KYC_INTRO, arguments: stage);
                        moreController?.loadMoreScreenData();
                      }
                    },
                  ),
                  _buildStepCard(
                    title: 'Personal Information',
                    completed: isPersonalInfoVerified,
                    icon:
                        isPersonalInfoVerified
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                    onTap: () async {
                      if (!isPersonalInfoVerified) {
                        final stage =
                            moreController
                                ?.dashboardModel
                                .value
                                ?.data
                                ?.stageCompletion;
                        await Get.toNamed(AppPages.KYC_INTRO, arguments: stage);
                        moreController?.loadMoreScreenData();
                      }
                    },
                  ),
                  _buildStepCard(
                    title: 'Copy Trading Application',
                    completed:
                        status == CopyTradingMasterApplicationStatus.approved,
                    icon:
                        status == CopyTradingMasterApplicationStatus.approved
                            ? Icons.check_circle_rounded
                            : (status ==
                                    CopyTradingMasterApplicationStatus.pending
                                ? Icons.hourglass_empty_rounded
                                : Icons.notifications_none_rounded),
                    labelOverride:
                        status == CopyTradingMasterApplicationStatus.none
                            ? 'Not Applied'
                            : (status ==
                                    CopyTradingMasterApplicationStatus.pending
                                ? 'Pending'
                                : (status ==
                                        CopyTradingMasterApplicationStatus
                                            .rejected
                                    ? 'Rejected'
                                    : 'Completed')),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              if (!isKycCompleted) ...[
                GestureDetector(
                  onTap: () async {
                    final stage =
                        moreController
                            ?.dashboardModel
                            .value
                            ?.data
                            ?.stageCompletion;
                    await Get.toNamed(AppPages.KYC_INTRO, arguments: stage);
                    moreController?.loadMoreScreenData();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.primary,
                          size: 22.r,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verification Required',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Please complete your KYC to submit the application.',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.primary,
                          size: 14.r,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // ── Application Form Section ──
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppColors.textGrey.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Your name
                    Text(
                      'Your name',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tradeBackgroundCenterColor.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: AppColors.textGrey.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        userName,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Shown for admin reference; update in profile if incorrect.',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    // Public nickname
                    LabeledAppTextField(
                      label: 'Public nickname *',
                      controller: _nicknameCtrl,
                      keyboardType: TextInputType.text,
                      hintText: 'e.g. Alpha Trader',
                      onChanged: (s) => hub.masterApplyNicknameDraft.value = s,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Displayed on the public leaderboard and master profile.',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Strategy Description
                    LabeledAppTextField(
                      label: 'Strategy Description *',
                      controller: _strategyCtrl,
                      keyboardType: TextInputType.text,
                      hintText: 'e.g. Conservative gold scalping strategy',
                      onChanged: (s) => hub.masterApplyStrategyDraft.value = s,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Explain your trading logic and strategy to copy investors.',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Risk Info
                    LabeledAppTextField(
                      label: 'Risk Info *',
                      controller: _riskInfoCtrl,
                      keyboardType: TextInputType.text,
                      hintText: 'e.g. Drawdown can reach up to 15%.',
                      onChanged: (s) => hub.masterApplyRiskInfoDraft.value = s,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Provide information about expected drawdown, leverage, or risk constraints.',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Terms check
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24.r,
                          height: 24.r,
                          child: Checkbox(
                            value: hub.masterApplyTermsAccepted.value,
                            side: BorderSide(color: checkBorder, width: 1.5),
                            fillColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return checkFill;
                              }
                              return Colors.transparent;
                            }),
                            checkColor: checkMark,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged:
                                (v) =>
                                    hub.masterApplyTermsAccepted.value =
                                        v ?? false,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'I accept the Master Trader Terms & Conditions and confirm that I will trade responsibly. Copiers may mirror my trades in real time.',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.textPrimary,
                              height: 1.3,
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
                            applying
                                ? null
                                : (!isKycCompleted
                                    ? () async {
                                      final stage =
                                          moreController
                                              ?.dashboardModel
                                              .value
                                              ?.data
                                              ?.stageCompletion;
                                      await Get.toNamed(
                                        AppPages.KYC_INTRO,
                                        arguments: stage,
                                      );
                                      moreController?.loadMoreScreenData();
                                    }
                                    : (canSubmit
                                        ? () async {
                                          final nick =
                                              hub.masterApplyNicknameDraft.value
                                                  .trim();
                                          final strategy =
                                              hub.masterApplyStrategyDraft.value
                                                  .trim();
                                          final riskInfo =
                                              hub.masterApplyRiskInfoDraft.value
                                                  .trim();
                                          final res = await hub.applyForMaster(
                                            nickname: nick,
                                            termsAccepted:
                                                hub
                                                    .masterApplyTermsAccepted
                                                    .value,
                                            strategy: strategy,
                                            riskInfo: riskInfo,
                                          );
                                          if (res.success) {
                                            CustomToastService.showSuccess(
                                              title: 'Submitted',
                                              message:
                                                  res.message ??
                                                  'Application submitted',
                                              duration: Duration(
                                                milliseconds: 2500,
                                              ),
                                            );
                                          } else {
                                            CustomToastService.showError(
                                              title: 'Failed',
                                              message:
                                                  res.message ??
                                                  hub.errorMessage.value,
                                              duration: Duration(
                                                milliseconds: 2500,
                                              ),
                                            );
                                          }
                                        }
                                        : null)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              !isKycCompleted
                                  ? AppColors.primary
                                  : AppColors.primary,
                          foregroundColor:
                              !isKycCompleted
                                  ? AppColors.whiteColor
                                  : applyBtnFg,
                          disabledBackgroundColor: AppColors.textGrey
                              .withValues(alpha: 0.2),
                          disabledForegroundColor: (!isKycCompleted
                                  ? AppColors.whiteColor
                                  : applyBtnFg)
                              .withValues(alpha: 0.4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child:
                            applying
                                ? SizedBox(
                                  width: 18.r,
                                  height: 18.r,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: applyBtnFg,
                                  ),
                                )
                                : Text(
                                  !isKycCompleted
                                      ? 'Complete KYC to Apply'
                                      : 'Submit Application',
                                  style: AppTextStyles.button.copyWith(
                                    color:
                                        !isKycCompleted
                                            ? AppColors.whiteColor
                                            : applyBtnFg,
                                    fontSize: 14.sp,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepCard({
    required String title,
    required bool completed,
    required IconData icon,
    String? labelOverride,
    VoidCallback? onTap,
  }) {
    final isprimary =
        !completed &&
        (title == 'Email Verification' ||
            title == 'Mobile Verification' ||
            title == 'Personal Information');
    final statusColor =
        completed
            ? AppColors.primary
            : (isprimary ? AppColors.primary : AppColors.textGrey);
    final statusText = labelOverride ?? (completed ? 'Completed' : 'Pending');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color:
                onTap != null && !completed
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.textGrey.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 18.r, color: statusColor),
              ],
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingReviewView(String masterCode) {
    return Container(
      margin: EdgeInsets.only(top: 40.h),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.textGrey.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 48.r, color: AppColors.primary),
          SizedBox(height: 14.h),
          Text(
            'Under Review',
            style: TextStyle(
              fontSize: 18.sp,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your application is currently being reviewed by our administration team. We will notify you as soon as your status is updated.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
          if (masterCode.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.tradeBackgroundCenterColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                'Master Code: $masterCode',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
