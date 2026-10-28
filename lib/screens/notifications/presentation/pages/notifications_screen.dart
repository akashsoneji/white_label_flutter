import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/notification_controller.dart';

class NotificationsScreen extends GetView<NotificationController> {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          TranslationUtils.tr('more_notifications'),
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20.r,
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() {
            if (controller.unreadTotal.value == 0) {
              return const SizedBox.shrink();
            }
            return IconButton(
              tooltip: TranslationUtils.tr('notifications_mark_all_read'),
              onPressed: controller.isMarkingAllRead.value
                  ? null
                  : controller.markAllAsRead,
              icon: Icon(
                Icons.done_all_rounded,
                color: AppColors.primary,
                size: 22.r,
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (controller.notifications.isEmpty) {
          return Center(
            child: Text(
              TranslationUtils.tr('notifications_no_notifications_found'),
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 16.sp,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchNotifications,
          color: AppColors.primary,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            itemCount: controller.notifications.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final item = controller.notifications[index];
              final isUnread = item.readAt == null;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => item.isMt5Credentials
                    ? controller.openMt5Credentials(item)
                    : controller.markAsRead(item),
                child: Container(
                decoration: BoxDecoration(
                  color: isUnread ? AppColors.primary.withValues(alpha: 0.05) : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isUnread ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border, 
                    width: 1
                  ),
                ),
                padding: EdgeInsets.all(16.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _getNotificationIcon(item.module, item.type ?? item.title, item.avatar),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title ??
                                item.type ??
                                TranslationUtils.tr('settings_tab_notification'),
                            style: AppTextStyles.cardSubtitle.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            item.fulltext ?? '',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13.sp,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            item.createdAt ?? '',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _getNotificationIcon(String? module, String? type, String? avatar) {
    if ((module == null || module.isEmpty) && (type == null || type.isEmpty)) {
      return _buildDefaultAvatar(avatar);
    }
    
    final lowerModule = module?.toLowerCase() ?? '';
    final lowerType = type?.toLowerCase() ?? '';
    
    IconData iconData = Icons.notifications_outlined;
    Color iconColor = AppColors.primary;
    Color bgColor = AppColors.primary.withValues(alpha: 0.1);

    if (lowerModule.contains('wallet') || lowerType.contains('wallet')) {
      iconData = Icons.account_balance_wallet_outlined;
      iconColor = Colors.blue;
      bgColor = Colors.blue.withValues(alpha: 0.1);
    } else if (lowerModule.contains('deposit') || lowerType.contains('deposit')) {
      iconData = Icons.add_circle_outline;
      iconColor = Colors.green;
      bgColor = Colors.green.withValues(alpha: 0.1);
    } else if (lowerModule.contains('withdraw') || lowerType.contains('withdraw')) {
      iconData = Icons.remove_circle_outline;
      iconColor = Colors.orange;
      bgColor = Colors.orange.withValues(alpha: 0.1);
    } else if (lowerModule.contains('transfer') || lowerType.contains('transfer')) {
      iconData = Icons.swap_horiz;
      iconColor = Colors.purple;
      bgColor = Colors.purple.withValues(alpha: 0.1);
    } else if (lowerModule.contains('kyc') || lowerModule.contains('verify') || lowerModule.contains('document') ||
               lowerType.contains('kyc') || lowerType.contains('verify') || lowerType.contains('document')) {
      iconData = Icons.verified_user_outlined;
      iconColor = Colors.teal;
      bgColor = Colors.teal.withValues(alpha: 0.1);
    } else if (avatar != null && avatar.isNotEmpty) {
       return _buildDefaultAvatar(avatar);
    }

    return Container(
      height: 40.w,
      width: 40.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Center(
        child: Icon(iconData, color: iconColor, size: 20.r),
      ),
    );
  }

  Widget _buildDefaultAvatar(String? avatar) {
    if (avatar != null && avatar.isNotEmpty) {
      return Container(
        height: 40.w,
        width: 40.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(avatar),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      height: 40.w,
      width: 40.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Icon(Icons.notifications_outlined, color: AppColors.primary, size: 20.r),
      ),
    );
  }
}
