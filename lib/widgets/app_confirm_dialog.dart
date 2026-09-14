import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/language_service.dart';

/// A single, theme-aware confirmation dialog used across the app for
/// yes/no and delete/cancel prompts.
///
/// It follows the app theme automatically: [AppColors.card] background,
/// [AppColors.textPrimary] title, [AppColors.textGrey] message. The confirm
/// button uses [AppColors.error] when [isDestructive] is true (delete/remove
/// flows) otherwise [AppColors.primary].
///
/// Returns `true` if the user confirmed, `false`/`null` otherwise.
Future<bool> showAppConfirmDialog({
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
  bool isDestructive = false,
}) async {
  final Color confirmColor =
      isDestructive ? AppColors.error : AppColors.primary;
  final String resolvedConfirmText =
      confirmText ?? TranslationUtils.tr('confirm');
  final String resolvedCancelText =
      cancelText ?? TranslationUtils.tr('account_management_cancel');

  final result = await Get.dialog<bool>(
    Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(22.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.4,
                color: AppColors.textGrey,
              ),
            ),
            SizedBox(height: 22.h),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Get.back(result: false),
                child: Text(
                  resolvedCancelText,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  resolvedConfirmText,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return result ?? false;
}
