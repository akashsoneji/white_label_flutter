import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// One-line summary of the paid add-on bought with a Copy Trading
/// subscription or a PAMM investment: name, fee and a "Refunded" tag.
class AddonPurchaseLine extends StatelessWidget {
  final String name;
  final num fee;
  final bool refunded;

  const AddonPurchaseLine({
    super.key,
    required this.name,
    required this.fee,
    this.refunded = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTextStyles.bodyText.copyWith(
      fontSize: 11.sp,
      color: AppColors.textGrey,
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(Icons.add_card_outlined, size: 14.r, color: AppColors.primary),
          SizedBox(width: 6.w),
          Text('${TranslationUtils.tr('addon_purchase_label')}: ', style: labelStyle),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            '\$${fee.toStringAsFixed(2)}',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              decoration: refunded ? TextDecoration.lineThrough : null,
            ),
          ),
          if (refunded) ...[
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                TranslationUtils.tr('addon_purchase_refunded'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
