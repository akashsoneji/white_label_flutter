import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/models/chart_notification.dart';
import 'package:crm_app/utils/precision_helper.dart';

/// Individual trading notification widget for chart screen
class ChartTradingNotification extends StatelessWidget {
  final ChartNotification notification;

  const ChartTradingNotification({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final typeText = notification.type.toLowerCase() == 'buy' ? 'Buy' : 'Sell';

    // Determine background color based on status
    Color backgroundColor;
    Color leftBorderColor;
    String statusText;

    switch (notification.status) {
      case NotificationStatus.loading:
        backgroundColor = AppColors.primary;
        leftBorderColor = AppColors.primary;
        statusText = '';
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Notification text
          Text(
            '${notification.symbol} $typeText ${PrecisionHelper.formatVolume(notification.volume)}',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.whiteColor,
            ),
          ),
          SizedBox(width: 8.w),
          // Status indicator (loading spinner or text)
          if (notification.status == NotificationStatus.loading)
            SizedBox(
              width: 16.w,
              height: 16.h,
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: AppColors.whiteColor,
                size: 16,
              ),
            )
          else
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: leftBorderColor,
              ),
            ),
        ],
      ),
    );
  }
}

/// Stack widget to display multiple notifications
class ChartNotificationStack extends StatelessWidget {
  final List<ChartNotification> notifications;

  const ChartNotificationStack({super.key, required this.notifications});

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10.h,
      left: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children:
            notifications.map((notification) {
              return ChartTradingNotification(notification: notification);
            }).toList(),
      ),
    );
  }
}
