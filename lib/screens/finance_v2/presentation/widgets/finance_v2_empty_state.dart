import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_primary_button.dart';

/// Centred "nothing here" state with an optional action.
///
/// The action button is shown only when both [actionLabel] and [onAction]
/// are given.
class FinanceV2EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FinanceV2EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    final actionLabel = this.actionLabel;
    final hasAction = actionLabel != null && onAction != null;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: 24.w,
          vertical: 16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: AppColors.iconBgPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 32.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (message != null && message.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textGrey,
                  fontSize: 13.sp,
                ),
              ),
            ],
            if (hasAction) ...[
              SizedBox(height: 16.h),
              FinanceV2PrimaryButton(label: actionLabel, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
