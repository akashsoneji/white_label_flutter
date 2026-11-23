import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';

/// Error message with a Retry button.
///
/// The default layout is centred for a whole screen or section; [compact]
/// lays the message and the button out in one row for inline use, such as
/// the channel list under the amount field.
class FinanceV2ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool compact;

  const FinanceV2ErrorRetry({
    super.key,
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.error_outline_rounded,
      color: AppColors.error,
      size: compact ? 20.sp : 28.sp,
    );
    final text = Text(
      message,
      maxLines: compact ? 2 : 4,
      overflow: TextOverflow.ellipsis,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style: AppTextStyles.bodyText.copyWith(
        color: AppColors.textPrimary,
        fontSize: 13.sp,
      ),
    );
    final retryButton = _RetryButton(onPressed: onRetry, compact: compact);

    if (compact) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            icon,
            SizedBox(width: 8.w),
            Expanded(child: text),
            SizedBox(width: 8.w),
            retryButton,
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: 24.w,
          vertical: 16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(height: 8.h),
            text,
            SizedBox(height: 16.h),
            retryButton,
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool compact;

  const _RetryButton({required this.onPressed, required this.compact});

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(compact ? 72.w : 96.w, 40.h),
        padding: EdgeInsetsDirectional.symmetric(horizontal: 12.w),
        foregroundColor: primary,
        side: BorderSide(color: primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      child: Text(
        TranslationUtils.tr('fv2_retry'),
        style: AppTextStyles.bodyText.copyWith(
          color: primary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
