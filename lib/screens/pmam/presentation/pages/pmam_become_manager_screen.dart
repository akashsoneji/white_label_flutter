import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/pmam/view_models/pmam_controller.dart';
import 'package:crm_app/screens/more/view_models/more_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';

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

  Future<void> _submit() async {
    if (!_emailVerified || !_mobileVerified || !_personalInfoDone) {
      Get.snackbar(
        'Incomplete Profile',
        'Please complete all verification steps before applying.',
        backgroundColor: AppColors.error,
        colorText: AppColors.whiteColor,
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
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: AppBackButton(onPressed: ()=> Navigator.of(context).pop(),
        ),
        title: Text('Become a Manager', style: AppTextStyles.heading),
        centerTitle: true,
      ),
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
                  'PMAM Manager Application',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                Text(
                  'Complete all steps to become a PMAM Manager',
                  style: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
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
                    childAspectRatio: 1.6,
                    children: [
                      _StepCard(
                        label: 'Email Verification',
                        done: _emailVerified,
                      ),
                      _StepCard(
                        label: 'Mobile Verification',
                        done: _mobileVerified,
                      ),
                      _StepCard(
                        label: 'Personal Information',
                        done: _personalInfoDone,
                      ),
                      _StepCard(
                        label: 'PMAM Application',
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
                        value: _termsAccepted,
                        onChanged:
                            (v) => setState(() => _termsAccepted = v ?? false),
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
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textGrey,
                          ),
                          children: [
                            const TextSpan(text: 'I accept the '),
                            TextSpan(
                              text: 'PMAM Manager Terms and Conditions',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  ' and confirm that all information provided is accurate.',
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
            Obx(
              () => Padding(
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 16.h),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: double.infinity,
                    height: 44.h,
                    child: ElevatedButton(
                      onPressed:
                          (_termsAccepted && !_ctrl.isLoading.value)
                              ? _submit
                              : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withOpacity(
                          0.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child:
                          _ctrl.isLoading.value
                              ? CommonLoadingWidget(
                                size: 22,
                                color: AppColors.whiteColor,
                              )
                              : Text(
                                'Submit Application',
                                style: TextStyle(
                                  color: AppColors.whiteColor,
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
          color: done ? AppColors.primary : const Color(0xFFE0E0E0),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(12.r),
        color:
            done ? AppColors.primary.withOpacity(0.05) : AppColors.whiteColor,
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
                  color: done ? AppColors.primary : const Color(0xFFD0D0D0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.notifications_outlined,
                  color: AppColors.whiteColor,
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
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: done ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: done ? AppColors.primary : const Color(0xFFBDBDBD),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  done ? 'Completed' : (notApplied ? 'Not Applied' : 'Pending'),
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.whiteColor,
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
