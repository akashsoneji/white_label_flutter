import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import 'package:crm_app/constants/color.dart';

enum _ShimmerVariant { tiles, cards, form }

/// Loading placeholder of the finance_v2 flow.
///
/// Use [FinanceV2Shimmer.tiles] for the payment type list,
/// [FinanceV2Shimmer.cards] for channel quote cards and
/// [FinanceV2Shimmer.form] for a form that is still loading.
class FinanceV2Shimmer extends StatelessWidget {
  final int count;
  final _ShimmerVariant _variant;

  const FinanceV2Shimmer.tiles({super.key, this.count = 6})
    : _variant = _ShimmerVariant.tiles;

  const FinanceV2Shimmer.cards({super.key, this.count = 3})
    : _variant = _ShimmerVariant.cards;

  const FinanceV2Shimmer.form({super.key})
    : count = 4,
      _variant = _ShimmerVariant.form;

  @override
  Widget build(BuildContext context) {
    final blockHeight = switch (_variant) {
      _ShimmerVariant.tiles => 60.h,
      _ShimmerVariant.cards => 88.h,
      _ShimmerVariant.form => 48.h,
    };
    final gap = _variant == _ShimmerVariant.form ? 16.h : 8.h;
    final blockColor = AppColors.pureWhite;

    return Shimmer.fromColors(
      baseColor: AppColors.neutralTrackMuted,
      highlightColor: AppColors.neutralTrackSoft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < count; index++) ...[
            if (index > 0) SizedBox(height: gap),
            Container(
              height: blockHeight,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
