import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/more/view_models/login_activity_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

/// "Login activity": sign-in history from `GET settings/activitylog`,
/// loading the next page as the list nears its end.
class LoginActivityScreen extends StatelessWidget {
  const LoginActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LoginActivityController());

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: AppColors.backgroundLight,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('login_activity_title'),
          style: AppTextStyles.heading,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final rows = controller.activities.toList();
          if (controller.isLoading.value && rows.isEmpty) {
            return const Center(child: CommonLoadingWidget(isFullScreen: false));
          }
          if (controller.errorMessage.value.isNotEmpty && rows.isEmpty) {
            return _CenteredMessage(
              icon: Icons.error_outline_rounded,
              message: controller.errorMessage.value,
              onRetry: controller.loadActivities,
            );
          }
          if (rows.isEmpty) {
            return _CenteredMessage(
              icon: Icons.history_rounded,
              message: TranslationUtils.tr('login_activity_empty'),
            );
          }
          final showFooter = controller.hasMore;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.loadActivities,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 300) {
                  controller.loadActivities(loadMore: true);
                }
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                itemCount: rows.length + (showFooter ? 1 : 0),
                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                itemBuilder: (_, index) {
                  if (index == rows.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: Center(
                        child: SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  }
                  return _ActivityCard(activity: rows[index]);
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final LoginActivity activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        activity.isSuccess ? AppColors.success : AppColors.error;
    final time = activity.timestamp == null
        ? ''
        : DateFormat('dd MMM yyyy, HH:mm').format(activity.timestamp!);
    final meta = [
      if (activity.ipAddress.isNotEmpty) activity.ipAddress,
      if (activity.location.isNotEmpty) activity.location,
    ].join(' · ');

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activity.isSuccess
                  ? Icons.login_rounded
                  : Icons.gpp_maybe_outlined,
              size: 18.sp,
              color: statusColor,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (activity.device.isNotEmpty || activity.description.isNotEmpty)
                  Text(
                    activity.device.isNotEmpty
                        ? activity.device
                        : activity.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (time.isNotEmpty) ...[
            SizedBox(width: 8.w),
            Text(
              time,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 10.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 40.sp),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 12.h),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(TranslationUtils.tr('common_retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
