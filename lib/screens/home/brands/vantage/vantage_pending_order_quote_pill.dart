import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class VantagePendingOrderQuotePill extends StatelessWidget {
  final ChartSocketController chartSocketController;

  const VantagePendingOrderQuotePill({
    super.key,
    required this.chartSocketController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
      ),
      child: Obx(() {
        final bid = chartSocketController.getBidPrice() ?? 0.0;
        final ask = chartSocketController.getAskPrice() ?? 0.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuoteCell(
              label: 'Bid',
              value: bid.toString(),
              valueColor: AppColors.error,
            ),
            SizedBox(width: 8.w),
            Container(
              width: 1,
              height: 22.h,
              color: AppColors.border.withValues(alpha: 0.45),
            ),
            SizedBox(width: 8.w),
            _QuoteCell(
              label: 'Ask',
              value: ask.toString(),
              valueColor: AppColors.blue,
            ),
          ],
        );
      }),
    );
  }
}

class _QuoteCell extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _QuoteCell({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            fontSize: 9.5.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          value,
          style: AppTextStyles.heading.copyWith(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w800,
            color: valueColor,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

