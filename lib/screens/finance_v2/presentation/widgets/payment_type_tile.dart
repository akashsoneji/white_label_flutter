import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

import 'method_icon_stack.dart';

/// One payment type (crypto, bank, card…) on the deposit / withdrawal type
/// screens: the server logos of its methods, the type name and the method
/// names under it.
///
/// A locked tile is dimmed and shows a lock badge with [lockReason], but it
/// still calls [onTap] so the screen can send the user to verification.
class PaymentTypeTile extends StatelessWidget {
  final IconData icon;
  final List<String> iconUrls;
  final String title;
  final String? subtitle;
  final bool isLocked;
  final String? lockReason;
  final VoidCallback onTap;

  const PaymentTypeTile({
    super.key,
    required this.icon,
    this.iconUrls = const <String>[],
    required this.title,
    this.subtitle,
    this.isLocked = false,
    this.lockReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final lockReason = this.lockReason;
    final radius = BorderRadius.circular(16.r);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: radius,
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          onTap: onTap,
          child: Opacity(
            opacity: isLocked ? 0.55 : 1,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(14.w, 14.h, 12.w, 14.h),
              child: Row(
                children: [
                  MethodIconStack(iconUrls: iconUrls, fallbackIcon: icon),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyText.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          SizedBox(height: 3.h),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (isLocked &&
                            lockReason != null &&
                            lockReason.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            lockReason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.warning,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _TrailingBadge(isLocked: isLocked),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrailingBadge extends StatelessWidget {
  final bool isLocked;

  const _TrailingBadge({required this.isLocked});

  @override
  Widget build(BuildContext context) {
    final color = isLocked ? AppColors.warning : AppColors.primary;
    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isLocked
            ? Icons.lock_outline_rounded
            : Icons.arrow_forward_ios_rounded,
        color: color,
        size: isLocked ? 15.sp : 12.sp,
        textDirection: Directionality.of(context),
      ),
    );
  }
}
