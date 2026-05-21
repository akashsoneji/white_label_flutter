import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/trade_win/view_models/trade_win_controller.dart';
import 'package:crm_app/models/trade_win/trade_win_leaderboard_entry_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/trade_win_format.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class TradeWinLeaderboardTab extends StatefulWidget {
  const TradeWinLeaderboardTab({super.key});

  @override
  State<TradeWinLeaderboardTab> createState() => _TradeWinLeaderboardTabState();
}

class _TradeWinLeaderboardTabState extends State<TradeWinLeaderboardTab> {
  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    final controller = Get.find<TradeWinController>();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(0.w, 0.h, 0.w, 0),
          child: Row(
            children: [
              const AppBackButton(closeOverlays: true),
              Expanded(
                child: Text(
                  languageService.tr('tw_leaderboard'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading,
                ),
              ),
              SizedBox(width: AppBackButton.leadingSlotSize.w),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            final entries = controller.leaderboard.toList();
            if (entries.isEmpty) {
              return Center(
                child: Text(
                  languageService.tr('tw_no_leaderboard'),
                  style: AppTextStyles.subheading,
                ),
              );
            }

            final top3 =
                entries.where((e) => e.rank <= 3).toList()
                  ..sort((a, b) => a.rank.compareTo(b.rank));
            final rest = entries.where((e) => e.rank > 3).toList();

            return ListView(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h),
              children: [
                if (top3.isNotEmpty)
                  _Podium(top3: top3, languageService: languageService),
                SizedBox(height: 16.h),
                ...rest.map(
                  (e) => _LeaderboardRow(
                    entry: e,
                    languageService: languageService,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  final List<TradeWinLeaderboardEntryModel> top3;
  final LanguageService languageService;

  const _Podium({required this.top3, required this.languageService});

  TradeWinLeaderboardEntryModel? _byRank(int rank) {
    try {
      return top3.firstWhere((e) => e.rank == rank);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _byRank(1);
    final second = _byRank(2);
    final third = _byRank(3);
    final lotsLabel = languageService.tr('tw_lots');

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumColumn(
              entry: second,
              height: 72.h,
              medalAsset: 'assets/svg/more/silver.svg',
              podiumTint: AppColors.icongrey.withValues(alpha: 0.2),
              rank: 2,
              lotsLabel: lotsLabel,
            ),
          ),
          Expanded(
            child: _PodiumColumn(
              entry: first,
              height: 96.h,
              medalAsset: 'assets/svg/more/gold.svg',
              podiumTint: const Color(0xFFF2B92C).withValues(alpha: 0.15),
              rank: 1,
              lotsLabel: lotsLabel,
            ),
          ),
          Expanded(
            child: _PodiumColumn(
              entry: third,
              height: 56.h,
              medalAsset: 'assets/svg/more/copper.svg',
              podiumTint: const Color(0xFFB87333).withValues(alpha: 0.15),
              rank: 3,
              lotsLabel: lotsLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final TradeWinLeaderboardEntryModel? entry;
  final double height;
  final String medalAsset;
  final Color podiumTint;
  final int rank;
  final String lotsLabel;

  const _PodiumColumn({
    required this.entry,
    required this.height,
    required this.medalAsset,
    required this.podiumTint,
    required this.rank,
    required this.lotsLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (entry == null) return SizedBox(height: height);

    return Column(
      children: [
        SvgPicture.asset(medalAsset, height: 32.h, width: 32.w),
        SizedBox(height: 4.h),
        Text(
          TradeWinFormat.maskName(entry!.name),
          style: AppTextStyles.subheading.copyWith(fontSize: 11.sp),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 8.h),
        Container(
          height: height,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          decoration: BoxDecoration(
            color: podiumTint,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
          ),
          alignment: Alignment.center,
          child: Text(
            TradeWinFormat.lotsWithUnit(entry!.lots, lotsLabel),
            style: AppTextStyles.headingblack.copyWith(
              fontSize: 12.sp,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final TradeWinLeaderboardEntryModel entry;
  final LanguageService languageService;

  const _LeaderboardRow({required this.entry, required this.languageService});

  @override
  Widget build(BuildContext context) {
    final lotsLabel = languageService.tr('tw_lots');
    final initial = entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color:
            entry.isMe
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color:
              entry.isMe
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.icongrey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Text(
            '#${entry.rank}',
            style: AppTextStyles.subheading.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              TradeWinFormat.maskName(entry.name),
              style: AppTextStyles.label,
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: TradeWinFormat.lots(entry.lots),
                  style: AppTextStyles.headingblack.copyWith(
                    fontSize: 14.sp,
                    color: AppColors.primary,
                  ),
                ),
                TextSpan(
                  text: ' $lotsLabel',
                  style: AppTextStyles.subheading.copyWith(fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
