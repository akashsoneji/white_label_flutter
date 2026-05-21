import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

class TradeWinRedeemStepper extends StatelessWidget {
  final int currentStep;

  const TradeWinRedeemStepper({super.key, required this.currentStep});

  static const _stepCount = 3;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < _stepCount; index++) ...[
            if (index > 0) _Connector(completed: index < currentStep),
            _StepCircle(
              step: index + 1,
              isActive: index + 1 == currentStep,
              isDone: index + 1 < currentStep,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int step;
  final bool isActive;
  final bool isDone;

  const _StepCircle({
    required this.step,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = isActive || isDone;
    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            highlighted
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.neutralTrack,
      ),
      alignment: Alignment.center,
      child: Text(
        '$step',
        style: AppTextStyles.subheading.copyWith(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: highlighted ? AppColors.primary : AppColors.textGrey,
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  final bool completed;

  const _Connector({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 2.h,
      margin: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: BoxDecoration(
        color: completed ? AppColors.primary : AppColors.neutralTrack,
        borderRadius: BorderRadius.circular(1.r),
      ),
    );
  }
}
