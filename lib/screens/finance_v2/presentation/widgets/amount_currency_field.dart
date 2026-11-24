import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/single_decimal_point_formatter.dart';

/// Amount input with a trailing currency pill.
///
/// The pill opens a picker through [onCurrencyTap] only when [currencies]
/// offers more than one choice. [min] and [max] are already formatted
/// amounts shown as a range in the helper line; [errorText] replaces the
/// helper when set.
class AmountCurrencyField extends StatelessWidget {
  final TextEditingController controller;
  final String currency;
  final List<String>? currencies;
  final VoidCallback? onCurrencyTap;
  final String? min;
  final String? max;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const AmountCurrencyField({
    super.key,
    required this.controller,
    required this.currency,
    this.currencies,
    this.onCurrencyTap,
    this.min,
    this.max,
    this.errorText,
    this.onChanged,
  });

  String? get _rangeText {
    final min = this.min;
    final max = this.max;
    if (min != null && max != null) return '$min – $max $currency';
    if (min != null) return '≥ $min $currency';
    if (max != null) return '≤ $max $currency';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final errorText = this.errorText;
    final hasError = errorText != null && errorText.isNotEmpty;
    final rangeText = _rangeText;
    final canPickCurrency =
        onCurrencyTap != null && (currencies?.length ?? 0) > 1;
    final amountStyle = AppTextStyles.bodyText.copyWith(
      color: AppColors.textPrimary,
      fontSize: 14.sp,
      fontWeight: FontWeight.w700,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TranslationUtils.tr('fv2_amount'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          // Same height and text size as the account picker above it.
          height: 48.h,
          padding: EdgeInsetsDirectional.only(start: 12.w, end: 8.w),
          decoration: BoxDecoration(
            color: AppColors.textFieldBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: hasError ? AppColors.error : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  // Amounts stay left-to-right even in RTL locales.
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    const SingleDecimalPointFormatter(),
                  ],
                  cursorColor: AppColors.primary,
                  style: amountStyle,
                  // Every border is cleared: the app theme's enabled/focused
                  // borders would draw a second box inside the container.
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: amountStyle.copyWith(color: AppColors.hint),
                    contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              _CurrencyPill(
                currency: currency,
                onTap: canPickCurrency ? onCurrencyTap : null,
              ),
            ],
          ),
        ),
        if (hasError || rangeText != null) ...[
          SizedBox(height: 4.h),
          if (hasError)
            Text(
              errorText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.errorText,
                fontSize: 11.sp,
              ),
            )
          else
            Text(
              rangeText ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textGrey,
                fontSize: 11.sp,
              ),
            ),
        ],
      ],
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  final String currency;
  final VoidCallback? onTap;

  const _CurrencyPill({required this.currency, this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20.r);
    final primary = AppColors.primary;

    return Material(
      color: AppColors.iconBgPrimary,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: 12.w,
            vertical: 5.h,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currency,
                style: AppTextStyles.bodyText.copyWith(
                  color: primary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onTap != null) ...[
                SizedBox(width: 4.w),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: primary,
                  size: 16.sp,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
