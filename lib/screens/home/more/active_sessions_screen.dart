import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/more/view_models/active_sessions_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

/// Devices logged in to this account, with remote logout.
class ActiveSessionsScreen extends StatelessWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ActiveSessionsController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('active_sessions_title'),
          style: AppTextStyles.screenTitle,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value && controller.sessions.isEmpty) {
            return const Center(child: CommonLoadingWidget(isFullScreen: false));
          }
          if (controller.errorMessage.value.isNotEmpty &&
              controller.sessions.isEmpty) {
            return _CenteredMessage(
              icon: Icons.error_outline_rounded,
              message: controller.errorMessage.value,
              onRetry: controller.loadSessions,
            );
          }
          if (controller.sessions.isEmpty) {
            return _CenteredMessage(
              icon: Icons.devices_other_rounded,
              message: TranslationUtils.tr('active_sessions_empty'),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.loadSessions,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsetsDirectional.fromSTEB(16.w, 8.h, 16.w, 12.h),
              itemCount: controller.sessions.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final session = controller.sessions[index];
                return _SessionCard(
                  session: session,
                  onRevoke: () => _confirmRevoke(context, controller, session),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    ActiveSessionsController controller,
    UserSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(TranslationUtils.tr('active_sessions_logout_device')),
        content: Text(TranslationUtils.tr('active_sessions_logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(TranslationUtils.tr('active_sessions_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              TranslationUtils.tr('active_sessions_logout'),
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.revoke(session);
  }
}

class _SessionCard extends GetView<ActiveSessionsController> {
  final UserSession session;
  final VoidCallback onRevoke;

  const _SessionCard({required this.session, required this.onRevoke});

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final details = [
      session.ipAddress,
      session.location,
    ].where((part) => part.isNotEmpty && part != 'Unknown').join(' • ');
    final lastUsed = _formatDate(session.lastUsedAt);

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(12.w, 10.h, 6.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: session.isCurrent
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.devices_rounded,
            color: session.isCurrent ? AppColors.primary : AppColors.textSecondary,
            size: 22.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.device.isEmpty
                            ? TranslationUtils.tr('active_sessions_unknown_device')
                            : session.device,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (session.isCurrent) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          TranslationUtils.tr('active_sessions_this_device'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (details.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
                if (lastUsed.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    '${TranslationUtils.tr('active_sessions_last_active')}: $lastUsed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!session.isCurrent)
            Obx(
              () => controller.revokingIds.contains(session.id)
                  ? Padding(
                      padding: EdgeInsets.all(12.w),
                      child: SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: TranslationUtils.tr('active_sessions_logout_device'),
                      onPressed: onRevoke,
                      icon: Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                        size: 20.sp,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  const _CenteredMessage({required this.icon, required this.message, this.onRetry});

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
