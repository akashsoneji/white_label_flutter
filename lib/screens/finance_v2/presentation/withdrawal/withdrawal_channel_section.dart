import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance_v2/data/models/finance_channel.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/channel_quote_card.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_error_retry.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_shimmer.dart';
import 'package:crm_app/services/language_service.dart';

import 'withdrawal_amount_controller.dart';

/// The priced channel cards for the typed withdrawal amount.
class WithdrawalChannelSection extends StatelessWidget {
  final WithdrawalAmountController controller;

  const WithdrawalChannelSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TranslationUtils.tr('fv2_payment_channel'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Obx(() {
          switch (controller.channelsState.value) {
            case WithdrawalChannelsState.idle:
              return _SectionHint(
                text: TranslationUtils.tr('fv2_enter_amount_hint'),
              );
            case WithdrawalChannelsState.loading:
              return const FinanceV2Shimmer.cards();
            case WithdrawalChannelsState.empty:
              return _SectionHint(
                text: TranslationUtils.tr('fv2_no_channel_for_amount'),
              );
            case WithdrawalChannelsState.error:
              final message = controller.channelsError.value ?? '';
              if (controller.channelsNeedKyc.value) {
                return _KycLocked(
                  message: message,
                  onOpenKyc: controller.openKyc,
                );
              }
              return FinanceV2ErrorRetry(
                compact: true,
                message: message.isEmpty
                    ? TranslationUtils.tr('fv2_no_channel_for_amount')
                    : message,
                onRetry: controller.refreshChannels,
              );
            case WithdrawalChannelsState.data:
              return _ChannelCards(
                controller: controller,
                channels: controller.channels.toList(growable: false),
                selectedSlug: controller.selectedChannelSlug.value,
                rejectedCount: controller.rejectedChannels.length,
                isRefreshing: controller.isFetchingChannels.value,
              );
          }
        }),
      ],
    );
  }
}

/// The cards are locked until the client is verified.
class _KycLocked extends StatelessWidget {
  final String message;
  final VoidCallback onOpenKyc;

  const _KycLocked({required this.message, required this.onOpenKyc});

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    final label = TranslationUtils.tr('fv2_verification_required');

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isNotEmpty) ...[
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 8.h),
          ],
          OutlinedButton.icon(
            onPressed: onOpenKyc,
            icon: Icon(Icons.lock_outline_rounded, size: 18.sp, color: primary),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                color: primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(96.w, 40.h),
              side: BorderSide(color: primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHint extends StatelessWidget {
  final String text;

  const _SectionHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.textGrey,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}

class _ChannelCards extends StatelessWidget {
  final WithdrawalAmountController controller;
  final List<FinanceChannel> channels;

  /// Passed in so the cards rebuild when the selection or the refused cards
  /// change; the state of each card is read from [controller].
  final String? selectedSlug;
  final int rejectedCount;
  final bool isRefreshing;

  const _ChannelCards({
    required this.controller,
    required this.channels,
    required this.selectedSlug,
    required this.rejectedCount,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: isRefreshing,
      child: Opacity(
        // Old cards stay visible, dimmed, while the new quotes load.
        opacity: isRefreshing ? 0.5 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final channel in channels)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: ChannelQuoteCard(
                  name: channel.name,
                  logoUrl: channel.logo,
                  youPay: channel.quote?.youPay ?? '',
                  youGet: channel.quote?.youGet ?? '',
                  rateLine: channel.quote?.rateLine,
                  feeLine: channel.quote?.feeLine,
                  state: controller.quoteStateOf(channel),
                  ineligibleReason: controller.ineligibleReasonOf(channel),
                  onTap: () => controller.selectChannel(channel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
