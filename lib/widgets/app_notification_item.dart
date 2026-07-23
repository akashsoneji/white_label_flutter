import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/models/app_notification.dart';
import 'package:crm_app/utils/precision_helper.dart';

/// Individual notification widget for app-wide notifications
/// Supports both generic messages and trading notifications
class AppNotificationItem extends StatelessWidget {
  final AppNotification notification;

  const AppNotificationItem({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    // If it's a trading notification, use trading-specific display
    if (notification.isTradingNotification) {
      return _buildTradingNotification();
    }

    // Otherwise, use generic message display
    return _buildGenericNotification();
  }

  /// Build trading notification (for chart screen compatibility)
  Widget _buildTradingNotification() {
    final typeText =
        notification.tradeType?.toLowerCase() == 'buy' ? 'Buy' : 'Sell';

    // Determine background color based on status
    Color backgroundColor;
    Color leftBorderColor;
    String? statusText;

    switch (notification.status) {
      case NotificationStatus.loading:
        backgroundColor = AppColors.primary;
        leftBorderColor = AppColors.primary;
        statusText = null;
        break;
      case NotificationStatus.success:
        backgroundColor = AppColors.primary;
        leftBorderColor = AppColors.success;
        statusText = 'Done';
        break;
      case NotificationStatus.error:
        backgroundColor = AppColors.primary;
        leftBorderColor = AppColors.error;
        statusText = 'Error';
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4.r),
        border: Border(left: BorderSide(color: leftBorderColor, width: 3.w)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${notification.symbol} $typeText ${PrecisionHelper.formatVolume(notification.volume ?? 0)}',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.whiteColor,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(width: 8.w),
          if (notification.status == NotificationStatus.loading)
            SizedBox(
              width: 16.w,
              height: 16.h,
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: AppColors.whiteColor,
                size: 16,
              ),
            )
          else if (statusText != null)
            Text(
              statusText,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: leftBorderColor,
                decoration: TextDecoration.none,
              ),
            ),
        ],
      ),
    );
  }

  /// Build generic message notification
  Widget _buildGenericNotification() {
    // Determine colors based on notification type
    Color backgroundColor;
    Color leftBorderColor;

    switch (notification.type) {
      case NotificationType.success:
        backgroundColor = AppColors.primary;
        leftBorderColor = AppColors.success;
        break;
      case NotificationType.error:
        backgroundColor = AppColors.primary;
        leftBorderColor = AppColors.error;
        break;
      case NotificationType.info:
        backgroundColor = AppColors.primary;
        leftBorderColor = AppColors.blue;
        break;
      case NotificationType.warning:
        backgroundColor = AppColors.primary;
        leftBorderColor = AppColors.warning;
        break;
      case NotificationType.loading:
        backgroundColor = AppColors.primary;
        leftBorderColor = AppColors.primary;
        break;
    }

    // Use error message if available, otherwise use message
    final displayMessage =
        notification.errorMessage ?? notification.message ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4.r),
        border: Border(left: BorderSide(color: leftBorderColor, width: 3.w)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (notification.title != null &&
                    notification.title!.isNotEmpty)
                  Text(
                    notification.title!,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.whiteColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                if (notification.title != null &&
                    notification.title!.isNotEmpty)
                  SizedBox(height: 2.h),
                Text(
                  displayMessage,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.whiteColor,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          if (notification.status == NotificationStatus.loading)
            Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: SizedBox(
                width: 16.w,
                height: 16.h,
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: AppColors.whiteColor,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
