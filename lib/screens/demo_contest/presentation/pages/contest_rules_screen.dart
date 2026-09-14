import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// Static "Contest Rules" page. Shows the universal contest rules +
/// a frequently-asked-questions section.
class ContestRulesScreen extends StatelessWidget {
  const ContestRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();

    final universalRules = [
      _RuleSection(
        emoji: '🎯',
        title: languageService.tr('dc_rule_objective'),
        body: languageService.tr('dc_rule_objective_desc'),
      ),
      _RuleSection(
        emoji: '💼',
        title: languageService.tr('dc_rule_account'),
        body: languageService.tr('dc_rule_account_desc'),
      ),
      _RuleSection(
        emoji: '📊',
        title: languageService.tr('dc_rule_instruments'),
        body: languageService.tr('dc_rule_instruments_desc'),
      ),
      _RuleSection(
        emoji: '⚖️',
        title: languageService.tr('dc_rule_leverage'),
        body: languageService.tr('dc_rule_leverage_desc'),
      ),
      _RuleSection(
        emoji: '🏆',
        title: languageService.tr('dc_rule_ranking'),
        body: languageService.tr('dc_rule_ranking_desc'),
      ),
      _RuleSection(
        emoji: '💵',
        title: languageService.tr('dc_rule_prizes'),
        body: languageService.tr('dc_rule_prizes_desc'),
      ),
      _RuleSection(
        emoji: '🚫',
        title: languageService.tr('dc_rule_fair'),
        body: languageService.tr('dc_rule_fair_desc'),
      ),
    ];

    final faqs = [
      _RuleSection(
        emoji: '❓',
        title: languageService.tr('dc_faq_q1'),
        body: languageService.tr('dc_faq_a1'),
      ),
      _RuleSection(
        emoji: '❓',
        title: languageService.tr('dc_faq_q2'),
        body: languageService.tr('dc_faq_a2'),
      ),
      _RuleSection(
        emoji: '❓',
        title: languageService.tr('dc_faq_q3'),
        body: languageService.tr('dc_faq_a3'),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        title: Text(
          languageService.tr('contest_rule'),
          style: AppTextStyles.screenTitle,
        ),
        leading: AppSvgBackButton(onPressed: () => Get.back()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(20.w, 8.h, 20.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.warning.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.10),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Text('📜', style: AppTextStyles.bodyText.copyWith(fontSize: 30.sp)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageService.tr('dc_rules_title'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          languageService.tr('dc_rules_subtitle'),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.sp,
                            color: AppColors.textGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              languageService.tr('dc_universal_rules').toUpperCase(),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textGrey.withValues(alpha: 0.85),
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 10.h),
            ...universalRules.map((r) => _RuleCard(rule: r)),
            SizedBox(height: 22.h),
            Text(
              languageService.tr('dc_faq').toUpperCase(),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textGrey.withValues(alpha: 0.85),
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 10.h),
            ...faqs.map((r) => _RuleCard(rule: r)),
            SizedBox(height: 28.h),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 10.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textGrey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  languageService.tr('dc_rules_footer'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.textGrey,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleSection {
  final String emoji;
  final String title;
  final String body;
  const _RuleSection({
    required this.emoji,
    required this.title,
    required this.body,
  });
}

class _RuleCard extends StatelessWidget {
  final _RuleSection rule;
  const _RuleCard({required this.rule});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.icongrey.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: Alignment.center,
            child: Text(rule.emoji, style: AppTextStyles.bodyText.copyWith(fontSize: 18.sp)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.title,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  rule.body,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.textGrey,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
