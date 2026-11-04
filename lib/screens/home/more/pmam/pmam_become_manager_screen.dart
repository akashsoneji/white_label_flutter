import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/responsive_layout.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/pmam/pmam_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

class PmamBecomeManagerScreen extends StatefulWidget {
  const PmamBecomeManagerScreen({super.key});

  @override
  State<PmamBecomeManagerScreen> createState() =>
      _PmamBecomeManagerScreenState();
}

class _PmamBecomeManagerScreenState extends State<PmamBecomeManagerScreen> {
  late final PmamController _ctrl;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<PmamController>()) {
      _ctrl = Get.find<PmamController>();
    } else {
      _ctrl = Get.put(PmamController());
    }
  }

  bool get _emailVerified {
    try {
      final model = Get.find<MoreController>().dashboardModel.value;
      return model?.data?.stageCompletion?.emailVerified != null;
    } catch (_) {
      return false;
    }
  }

  bool get _mobileVerified {
    try {
      final model = Get.find<MoreController>().dashboardModel.value;
      return model?.data?.stageCompletion?.mobileVerified != null;
    } catch (_) {
      return false;
    }
  }

  bool get _personalInfoDone {
    try {
      final model = Get.find<MoreController>().dashboardModel.value;
      return model?.data?.stageCompletion?.personalDetails == true;
    } catch (_) {
      return false;
    }
  }

  bool get _pmamApplied =>
      _ctrl.managerStatus.value == 'pending' ||
      _ctrl.managerStatus.value == 'approved';

  /// Rejected users may re-apply; pending/approved users and closed
  /// applications (`master_enrollments_enabled == false`) may not.
  bool get _canApply =>
      !_pmamApplied && _ctrl.masterEnrollmentsEnabled.value;

  /// Banner text + colour for the current manager status, or null.
  (String, Color)? get _statusNotice {
    switch (_ctrl.managerStatus.value) {
      case 'pending':
        return (
          TranslationUtils.tr('pmam_manager_status_pending'),
          AppColors.warningText,
        );
      case 'rejected':
        return (
          TranslationUtils.tr('pmam_manager_status_rejected'),
          AppColors.error,
        );
    }
    if (!_ctrl.masterEnrollmentsEnabled.value) {
      return (
        TranslationUtils.tr('pmam_manager_applications_closed'),
        AppColors.textGrey,
      );
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_emailVerified || !_mobileVerified || !_personalInfoDone) {
      Get.snackbar(
        TranslationUtils.tr('pmam_become_manager_screen_incomplete_profile'),
        TranslationUtils.tr(
            'pmam_become_manager_complete_verification_steps_first'),
        backgroundColor: AppColors.error,
        colorText: AppColors.onColoredBackground,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    await _ctrl.applyAsManager();
    if (_ctrl.managerStatus.value == 'pending' && mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      // appBar: AppBar(
      //   scrolledUnderElevation: 0,
      //   backgroundColor: AppColors.tradeBackgroundCenterColor,
      //   elevation: 0,
      //   leading: AppSvgBackButton(
      //     onPressed: () => Get.back(closeOverlays: true),
      //     iconWidth: 30.w,
      //     iconHeight: 30.h,
      //   ),
      //   title: Text('Become a Manager', style: AppTextStyles.heading),
      //   centerTitle: true,
      // ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 16.h),
        child: Column(
          children: [
            // Main card
            Column(
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.show_chart_rounded,
                    color: AppColors.primary,
                    size: 28.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  TranslationUtils.tr(
                      'pmam_become_manager_screen_pamm_manager_application'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                Text(
                  TranslationUtils.tr(
                      'pmam_become_manager_screen_complete_all_steps_to_become_pamm'),
                  style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textGrey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),

                // Steps grid
                Obx(
                  () => GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: ResponsiveGrid.aspectRatio(1.6),
                    children: [
                      _StepCard(
                        label: TranslationUtils.tr('email_verification'),
                        done: _emailVerified,
                      ),
                      _StepCard(
                        label: TranslationUtils.tr('mobile_verification'),
                        done: _mobileVerified,
                      ),
                      _StepCard(
                        label: TranslationUtils.tr('personal_information'),
                        done: _personalInfoDone,
                      ),
                      _StepCard(
                        label: TranslationUtils.tr(
                            'pmam_become_manager_pamm_application'),
                        done: _pmamApplied,
                        notApplied: !_pmamApplied,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Terms checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: Checkbox(
                        checkColor: AppColors.onColoredBackground,
                        side: BorderSide(color: AppColors.textGrey, width: 1.5),
                        value: _termsAccepted,
                        onChanged: (v) =>
                            setState(() => _termsAccepted = v ?? false),
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            color: AppColors.textGrey,
                          ),
                          children: [
                            TextSpan(
                                text: TranslationUtils.tr(
                                    'pmam_become_manager_i_accept_the')),
                            TextSpan(
                              text: TranslationUtils.tr(
                                  'pmam_become_manager_terms_and_conditions'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: TranslationUtils.tr(
                                  'pmam_become_manager_and_confirm_info_accurate'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Submit button
              ],
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final notice = _statusNotice;
              if (notice == null) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(22.w, 12.h, 22.w, 0),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: notice.$2.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: notice.$2.withValues(alpha: 0.3)),
                ),
                child: Text(
                  notice.$1,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    color: notice.$2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }),
            Obx(
              () => Padding(
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 16.h),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: double.infinity,
                    height: 44.h,
                    child: ElevatedButton(
                      onPressed: (_termsAccepted &&
                              _canApply &&
                              !_ctrl.isLoading.value)
                          ? _submit
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.brandPrimary,
                        disabledBackgroundColor: AppColors.primary.withOpacity(
                          0.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: _ctrl.isLoading.value
                          ? CommonLoadingWidget(
                              size: 22,
                              color: AppColors.onColoredBackground,
                            )
                          : Text(
                              TranslationUtils.tr(
                                  'pmam_become_manager_screen_submit_application'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.onColoredBackground,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
}

class _StepCard extends StatelessWidget {
  final String label;
  final bool done;
  final bool notApplied;

  const _StepCard({
    required this.label,
    required this.done,
    this.notApplied = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        border: Border.all(
          color: done ? AppColors.primary : AppColors.neutralTrack,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(12.r),
        color: done
            ? AppColors.primary.withOpacity(0.05)
            : AppColors.whiteColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.isDarkMode
                            ? AppColors.primary.withOpacity(0.5)
                            : AppColors.primary
                      : AppColors.neutralTrackMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.notifications_outlined,
                  color: AppColors.isDarkMode
                      ? AppColors.primary.withOpacity(0.5)
                      : AppColors.onColoredBackground,
                  size: 14.sp,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: done ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: done ? AppColors.primary : AppColors.neutralTrackSoft,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  done
                      ? TranslationUtils.tr('completed')
                      : (notApplied
                          ? TranslationUtils.tr('become_master_tab_not_applied')
                          : TranslationUtils.tr('transaction_history_pending')),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10.sp,
                    color: AppColors.isDarkMode
                        ? AppColors.pureBlack
                        : AppColors.onColoredBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
