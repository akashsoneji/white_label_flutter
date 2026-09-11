import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/widgets/app_back_button.dart';

/// Status of a verification step.
enum _StepState { completed, active, locked }

/// A single feature row inside a step card.
class _StepFeature {
  final IconData icon;
  final String label;
  const _StepFeature(this.icon, this.label);
}

class KycIntroScreen extends StatelessWidget {
  final StageCompletion? stageCompletion;

  const KycIntroScreen({Key? key, this.stageCompletion}) : super(key: key);

  bool get _step1Done =>
      stageCompletion?.mobileVerified != null &&
      stageCompletion?.emailVerified != null &&
      stageCompletion?.personalDetails == true;

  bool get _step2Done =>
      stageCompletion?.identityVerified == true &&
      stageCompletion?.addressProofVerified == true;

  bool get _step3Done => stageCompletion?.addressProofVerified == true;

  void _handleNavigate() {
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
        arguments: {'screen_name': 'Add Withdrawal Method', 'isFromKYC': true},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve step states from real completion data.
    final step1State = _step1Done ? _StepState.completed : _StepState.active;
    final step2State =
        _step2Done
            ? _StepState.completed
            : _step1Done
            ? _StepState.active
            : _StepState.locked;
    final step3State =
        _step3Done
            ? _StepState.completed
            : (stageCompletion?.identityVerified == true)
            ? _StepState.active
            : _StepState.locked;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.scaffold,
        leading: const AppBackButton(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 28.h),
                    _buildTimelineStep(
                      stepNumber: 1,
      title: TranslationUtils.tr('kyc_intro_screen_profile_setup'),
                      state: step1State,
                      headerIcon: Icons.person_outline_rounded,
                      isLast: false,
                      features: const [
                        _StepFeature(
                          Icons.person_outline_rounded,
                          'Complete your personal information',
                        ),
                        _StepFeature(
                          Icons.mail_outline_rounded,
                          'Verify your email & phone number',
                        ),
                        _StepFeature(
                          Icons.home_outlined,
                          'Add your residential address',
                        ),
                      ],
                    ),
                    _buildTimelineStep(
                      stepNumber: 2,
                      title: 'Verification',
                      state: step2State,
                      headerIcon: Icons.badge_outlined,
                      isLast: false,
                      features: const [
                        _StepFeature(
                          Icons.cloud_upload_outlined,
                          'Upload your KYC documents',
                        ),
                        _StepFeature(
                          Icons.verified_user_outlined,
                          'Verify your identity',
                        ),
                        _StepFeature(
                          Icons.credit_card_outlined,
                          'Add & verify your withdrawal method',
                        ),
                      ],
                    ),
                    _buildTimelineStep(
                      stepNumber: 3,
                      title: 'Trading Account',
                      state: step3State,
                      headerIcon: Icons.work_outline_rounded,
                      isLast: true,
                      features: const [
                        _StepFeature(
                          Icons.trending_up_rounded,
                          'Choose Live or Demo',
                        ),
                        _StepFeature(
                          Icons.add_circle_outline_rounded,
                          'Create your trading account',
                        ),
                        _StepFeature(
                          Icons.check_circle_outline_rounded,
                          "You're ready to trade",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header: shield badge + title + subtitle ────────────────────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 88.w,
          width: 88.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.06),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Container(
            height: 60.w,
            width: 60.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.r),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  Color.lerp(AppColors.primary, Colors.black, 0.30)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: AppColors.pureWhite,
              size: 30.w,
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's get you verified",
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Complete these simple steps to unlock all features and start trading',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textGrey,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Timeline step: thin left rail (dot + line) + card (icon lives inside) ──
  Widget _buildTimelineStep({
    required int stepNumber,
    required String title,
    required _StepState state,
    required IconData headerIcon,
    required List<_StepFeature> features,
    required bool isLast,
  }) {
    final bool locked = state == _StepState.locked;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thin left rail: connector dot + line
          SizedBox(
            width: 20.w,
            child: Column(
              children: [
                SizedBox(height: 22.h),
                _buildStatusDot(state),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 2.h),
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // Card (header icon box now sits INSIDE the card)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20.h),
              child: _buildCard(
                stepNumber: stepNumber,
                title: title,
                state: state,
                headerIcon: headerIcon,
                locked: locked,
                features: features,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildIconBox(IconData icon, bool locked) {
    return Container(
      height: 40.w,
      width: 40.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient:
            locked
                ? null
                : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    Color.lerp(AppColors.primary, Colors.black, 0.30)!,
                  ],
                ),
        color: locked ? AppColors.iconBgTertiary : null,
        boxShadow:
            locked
                ? null
                : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Icon(
        icon,
        color: locked ? AppColors.textGrey : AppColors.pureWhite,
        size: 20.w,
      ),
    );
  }


  Widget _buildStatusDot(_StepState state) {
    if (state == _StepState.active) {
      return Container(
        height: 14.w,
        width: 14.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 3,
          ),
        ),
      );
    }
    if (state == _StepState.completed) {
      return Container(
        height: 16.w,
        width: 16.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success,
        ),
        child: Icon(Icons.check, color: AppColors.pureWhite, size: 11.w),
      );
    }
    // locked
    return Container(
      height: 14.w,
      width: 14.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.scaffold,
        border: Border.all(color: AppColors.divider, width: 2),
      ),
    );
  }

  Widget _buildCard({
    required int stepNumber,
    required String title,
    required _StepState state,
    required IconData headerIcon,
    required bool locked,
    required List<_StepFeature> features,
  }) {
    return GestureDetector(
      onTap: _handleNavigate,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color:
                state == _StepState.active
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.kycBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildIconBox(headerIcon, locked),
                SizedBox(width: 12.w),
                _buildStepPill(stepNumber),
                const Spacer(),
                _buildStatusPill(state),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 14.h),
            ...features.map(_buildFeatureRow),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPill(int stepNumber) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        'Step $stepNumber',
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildStatusPill(_StepState state) {
    late final String label;
    late final Color color;
    late final IconData icon;
    switch (state) {
      case _StepState.completed:
        label = 'Completed';
        color = AppColors.success;
        icon = Icons.check_circle;
        break;
      case _StepState.active:
        label = 'Incomplete';
        color = AppColors.primary;
        icon = Icons.circle_outlined;
        break;
      case _StepState.locked:
        label = 'Locked';
        color = AppColors.textGrey;
        icon = Icons.lock_outline_rounded;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          SizedBox(width: 5.w),
          Icon(icon, size: 12.w, color: color),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(_StepFeature feature) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 32.w,
            width: 32.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
            child: Icon(feature.icon, size: 17.w, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              feature.label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer: gradient CTA button + secure note ──────────────────────────────
  Widget _buildFooter() {
    return Container(
      color: AppColors.scaffold,
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _handleNavigate,
            child: Container(
              height: 56.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color.lerp(AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.4), 0.9)!,
                    AppColors.primary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Start Your Verification Journey',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pureWhite,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.pureWhite,
                    size: 20.w,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14.w,
                color: AppColors.textGrey,
              ),
              SizedBox(width: 6.w),
              Text(
                'Your information is secure and encrypted',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
