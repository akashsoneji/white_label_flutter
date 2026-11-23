import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';

import 'method_icon_stack.dart';

/// How a [ChannelQuoteCard] is drawn and whether it can be tapped.
enum QuoteState { eligible, selected, ineligible }

/// One payment channel with its quote for the entered amount.
///
/// [youPay], [youGet], [rateLine] and [feeLine] are server strings and are
/// shown verbatim. The rate and fee lines appear only on the selected card.
/// An ineligible card is dimmed, ignores taps and shows [ineligibleReason].
class ChannelQuoteCard extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final String youPay;
  final String youGet;
  final String? rateLine;
  final String? feeLine;
  final QuoteState state;
  final String? ineligibleReason;
  final VoidCallback? onTap;

  const ChannelQuoteCard({
    super.key,
    required this.name,
    this.logoUrl,
    required this.youPay,
    required this.youGet,
    this.rateLine,
    this.feeLine,
    this.state = QuoteState.eligible,
    this.ineligibleReason,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = state == QuoteState.selected;
    final isIneligible = state == QuoteState.ineligible;
    final rateLine = this.rateLine;
    final feeLine = this.feeLine;
    final ineligibleReason = this.ineligibleReason;
    final radius = BorderRadius.circular(14.r);
    final metaStyle = AppTextStyles.bodyText.copyWith(
      color: AppColors.textSecondary,
      fontSize: 11.sp,
    );

    return Material(
      color: isSelected ? AppColors.surfacePrimary : AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: isIneligible ? null : onTap,
        child: Opacity(
          opacity: isIneligible ? 0.5 : 1,
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _ChannelLogo(logoUrl: logoUrl),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isSelected) ...[
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 20.sp,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _QuoteAmount(
                        label: TranslationUtils.tr('fv2_you_pay'),
                        value: youPay,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: 8.w,
                      ),
                      // arrow_forward mirrors itself in RTL.
                      child: Icon(
                        Icons.arrow_forward,
                        color: AppColors.textGrey,
                        size: 16.sp,
                      ),
                    ),
                    Expanded(
                      child: _QuoteAmount(
                        label: TranslationUtils.tr('fv2_you_get'),
                        value: youGet,
                      ),
                    ),
                  ],
                ),
                if (isSelected && rateLine != null && rateLine.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    rateLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: metaStyle,
                  ),
                ],
                if (isSelected && feeLine != null && feeLine.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    feeLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: metaStyle,
                  ),
                ],
                if (isIneligible &&
                    ineligibleReason != null &&
                    ineligibleReason.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    ineligibleReason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.errorText,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  final String? logoUrl;

  const _ChannelLogo({this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final logoUrl = this.logoUrl;
    return MethodIconStack(
      iconUrls: logoUrl == null ? const <String>[] : <String>[logoUrl],
      fallbackIcon: Icons.account_balance_outlined,
      size: 30,
    );
  }
}

class _QuoteAmount extends StatelessWidget {
  final String label;
  final String value;

  const _QuoteAmount({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textGrey,
            fontSize: 11.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
