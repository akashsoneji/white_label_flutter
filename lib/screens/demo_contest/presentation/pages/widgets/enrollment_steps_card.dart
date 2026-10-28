import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/demo_contest_controller.dart';
import 'package:crm_app/models/demo_contest/demo_contest_enrollment_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Enrollment tasks from `GET demo-contest/{id}/steps`. Tapping a step opens
/// its link (if any) and marks it done via `POST demo-contest/step/{id}/click`.
class EnrollmentStepsCard extends StatefulWidget {
  final String contestId;
  const EnrollmentStepsCard({super.key, required this.contestId});

  @override
  State<EnrollmentStepsCard> createState() => _EnrollmentStepsCardState();
}

class _EnrollmentStepsCardState extends State<EnrollmentStepsCard> {
  final _controller = Get.find<DemoContestController>();
  List<DemoContestStep> _steps = const [];
  bool _loading = true;
  String? _busyStepId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final steps = await _controller.fetchSteps(widget.contestId);
    if (!mounted) return;
    setState(() {
      _steps = steps;
      _loading = false;
    });
  }

  Future<void> _onStepTap(DemoContestStep step) async {
    if (step.isCompleted || _busyStepId != null) return;
    setState(() => _busyStepId = step.id);
    final uri = Uri.tryParse(step.url);
    if (uri != null && uri.hasScheme) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    final done = await _controller.completeStep(step.id);
    if (!mounted) return;
    setState(() {
      _busyStepId = null;
      if (done) {
        _steps = [
          for (final s in _steps) s.id == step.id ? s.copyWith(isCompleted: true) : s,
        ];
      }
    });
    if (!done && _controller.errorMessage.value.isNotEmpty) {
      CustomToastService.showError(message: _controller.errorMessage.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_steps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TranslationUtils.tr('dc_enrollment_steps'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        for (final step in _steps)
          Container(
            margin: EdgeInsets.only(bottom: 8.h),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
            ),
            child: ListTile(
              dense: true,
              onTap: () => _onStepTap(step),
              leading: _busyStepId == step.id
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      step.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: step.isCompleted
                          ? AppColors.success
                          : AppColors.textGrey,
                      size: 20.sp,
                    ),
              title: Text(
                step.title,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: step.description.isEmpty
                  ? null
                  : Text(
                      step.description,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}
