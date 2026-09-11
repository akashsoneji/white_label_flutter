import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter_svg/svg.dart';

class TradersFilterScreen extends StatefulWidget {
  const TradersFilterScreen({super.key});

  @override
  State<TradersFilterScreen> createState() => _TradersFilterScreenState();
}

class _TradersFilterScreenState extends State<TradersFilterScreen> {
  bool freeTrial = false;
  String minExpertise = 'All';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:   BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      height: MediaQuery.of(context).size.height * 0.8,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 12),
            Container(
              width: 28,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.icongrey,
                        shape: BoxShape.circle,
                      ),
                      child:   Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width * 0.1,
                    ),
                    child:   Text(
                      TranslationUtils.tr('traders_filter_screen_filters'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        freeTrial = false;
                        minExpertise = 'All';
                      });
                    },
                    child:   Text(
                      TranslationUtils.tr('trade_screen_reset_all'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: AppColors.border),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Minimum Investment
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            TranslationUtils.tr(
                              'traders_filter_screen_25_or_more',
                            ),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Positioned(
                          top: -8,
                          left: 12,
                          child: Container(
                            color: AppColors.whiteColor,
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              TranslationUtils.tr(
                                'trader_details_screen_minimum_investment',
                              ),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    // Free 7-day trial
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          freeTrial = !freeTrial;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              TranslationUtils.tr(
                                'traders_filter_screen_free_day_trial',
                              ),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color:
                                      freeTrial
                                          ? AppColors.primary
                                          : AppColors.textGrey,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                color:
                                    freeTrial
                                        ? AppColors.primary
                                        : Colors.transparent,
                              ),
                              child:
                                  freeTrial
                                      ?   Icon(
                                        Icons.check,
                                        size: 14,
                                        color: AppColors.whiteColor,
                                      )
                                      : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    // Minimum Expertise
                    Card(
                      elevation: 0.8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.transparent),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              TranslationUtils.tr(
                                'traders_filter_screen_minimum_expertise',
                              ),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          _buildExpertiseRadioItem(
                            'Legend',
                            'traders_filter_screen_legend',
                            SvgPicture.asset(
                              "assets/svg/copy_trading/filters/gold_legend.svg",
                              width: 20,
                              height: 20,
                            ),
                            minExpertise,
                            (val) => setState(() => minExpertise = val!),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          _buildExpertiseRadioItem(
                            'Expert',
                            'traders_filter_screen_expert',
                            SvgPicture.asset(
                              "assets/svg/copy_trading/filters/blue_expert.svg",
                              width: 20,
                              height: 20,
                            ),

                            minExpertise,
                            (val) => setState(() => minExpertise = val!),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          _buildExpertiseRadioItem(
                            'High Achiever',
                            'trader_card_high_achiever',
                            SvgPicture.asset(
                              "assets/svg/copy_trading/filters/green_highachiever.svg",
                              width: 20,
                              height: 20,
                            ),

                            minExpertise,
                            (val) => setState(() => minExpertise = val!),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          _buildExpertiseRadioItem(
                            'Growing Talent',
                            'traders_filter_screen_growing_talent',
                            SvgPicture.asset(
                              "assets/svg/copy_trading/filters/grey_growing_talent.svg",
                              width: 14,
                              height: 14,
                            ),

                            minExpertise,
                            (val) => setState(() => minExpertise = val!),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          _buildExpertiseRadioItem(
                            'All',
                            'common_all',
                            SvgPicture.asset(
                              "assets/svg/menu.svg",
                              width: 20,
                              height: 20,
                            ),
                            minExpertise,
                            (val) => setState(() => minExpertise = val!),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 100,
                    ), // padding for the bottom button
                  ],
                ),
              ),
            ),
            Container(
              color: AppColors.whiteColor,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 20,
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child:   Text(
                      TranslationUtils.tr(
                        'traders_filter_screen_show_108_master_traders',
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpertiseRadioItem(
    String title,
    String labelKey,
    Widget icon,
    String groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(title),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            icon,
            SizedBox(width: 12),
            Expanded(
              child: Text(
                TranslationUtils.tr(labelKey),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.icongrey,
                ),
              ),
            ),
            SizedBox(
              width: 20,
              height: 20,
              child: Radio<String>(
                value: title,
                groupValue: groupValue,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                fillColor: MaterialStateProperty.resolveWith<Color>((
                  Set<MaterialState> states,
                ) {
                  if (states.contains(MaterialState.selected)) {
                    return AppColors.primary;
                  }
                  return AppColors.textGrey;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
