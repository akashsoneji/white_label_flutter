import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/app_notification.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';

/// iQuote-only notification item that slides in from the right edge and is
/// anchored to the vertical center of the screen. Presented by
/// [AppNotificationStack] when [FlavorConfig.usesIquoteUi] is true.
class IquoteNotificationItem extends StatefulWidget {
  final AppNotification notification;

  const IquoteNotificationItem({super.key, required this.notification});

  @override
  State<IquoteNotificationItem> createState() => _IquoteNotificationItemState();
}

class _IquoteNotificationItemState extends State<IquoteNotificationItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!Get.isRegistered<AppNotificationController>()) return;
    Get.find<AppNotificationController>().removeNotification(
      widget.notification.id,
    );
  }

  Color _accentColor() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return AppColors.success;
      case NotificationType.error:
        return AppColors.error;
      case NotificationType.warning:
        return AppColors.warning;
      case NotificationType.info:
        return AppColors.blue;
      case NotificationType.loading:
        return AppColors.primary;
    }
  }

  IconData _icon() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return Icons.check_rounded;
      case NotificationType.error:
        return Icons.close_rounded;
      case NotificationType.warning:
        return Icons.priority_high_rounded;
      case NotificationType.info:
        return Icons.info_outline_rounded;
      case NotificationType.loading:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final displayMessage =
        widget.notification.errorMessage ?? widget.notification.message ?? '';
    final title = widget.notification.title;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 200) {
                _dismiss();
              }
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 300.w),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.r),
                    bottomLeft: Radius.circular(20.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(-4, 6),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.r),
                    bottomLeft: Radius.circular(20.r),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Left accent bar
                        Container(width: 4.w, color: accent),
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.h,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 30.w,
                                  height: 30.w,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.6),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    _icon(),
                                    color: accent,
                                    size: 18.h,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (title != null && title.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: 2.h),
                                          child: Text(
                                            title,
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  color: AppColors.whiteColor,
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.2,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      Text(
                                        displayMessage,
                                        style: AppTextStyles.bodyText.copyWith(
                                          color: AppColors.whiteColor
                                              .withValues(alpha: 0.95),
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 1.3,
                                          decoration: TextDecoration.none,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                GestureDetector(
                                  onTap: _dismiss,
                                  child: Container(
                                    width: 24.w,
                                    height: 24.w,
                                    decoration: BoxDecoration(
                                      color: AppColors.whiteColor.withValues(
                                        alpha: 0.18,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: AppColors.whiteColor,
                                      size: 14.h,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
