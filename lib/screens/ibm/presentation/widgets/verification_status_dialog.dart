import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

class VerificationStatusDialog extends StatelessWidget {
  final dynamic stageCompletion;
  final String ibStatus;

  const VerificationStatusDialog({
    super.key,
    required this.stageCompletion,
    required this.ibStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Check if stageCompletion is a Map or an Object
    bool emailVerified = false;
    bool mobileVerified = false;
    bool personalDetails = false;

    if (stageCompletion != null) {
      if (stageCompletion is Map) {
        emailVerified = stageCompletion['email_verified'] == true;
        mobileVerified = stageCompletion['mobile_verified'] == true;
        personalDetails = stageCompletion['personal_details'] == true;
      } else {
        try {
          emailVerified = stageCompletion.emailVerified == true;
          mobileVerified = stageCompletion.mobileVerified == true;
          personalDetails = stageCompletion.personalDetails == true;
        } catch (_) {}
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      backgroundColor: AppColors.whiteColor,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Text(
              'Verification Status',
              style: AppTextStyles.heading.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Complete all steps to join our IB program',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: _buildStatusBox('Email Verification', emailVerified),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildStatusBox('Mobile Verification', mobileVerified),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildStatusBox(
                    'Personal Information',
                    personalDetails,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(child: _buildAppStatusBox('IB Application', ibStatus)),
              ],
            ),
            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8.r),
                color: Colors.grey.withOpacity(0.05),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 20.w,
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'I accept the IB Terms and Conditions',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'Application Submitted',
                  style: TextStyle(
                    color: AppColors.whiteColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBox(String title, bool isCompleted) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            padding: EdgeInsets.all(4.w),
            child: Icon(
              isCompleted ? Icons.check : Icons.more_horiz,
              color: AppColors.whiteColor,
              size: 16.w,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.sp,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.primary : Colors.grey,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'Pending',
                    style: TextStyle(
                      color: AppColors.whiteColor,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppStatusBox(String title, String status) {
    final isInReview = status == 'inreview';
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            padding: EdgeInsets.all(4.w),
            child: Icon(
              isInReview ? Icons.notifications_none : Icons.more_horiz,
              color: AppColors.whiteColor,
              size: 16.w,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.sp,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isInReview ? Colors.amber.shade700 : Colors.grey,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    isInReview ? 'In Review' : 'Pending',
                    style: TextStyle(
                      color: AppColors.whiteColor,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
