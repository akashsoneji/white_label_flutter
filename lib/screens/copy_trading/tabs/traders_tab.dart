import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/constants/color.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/language_service.dart';
import '../components/trader_card.dart';
import '../traders_filter_screen.dart';

class TradersTab extends StatefulWidget {
  const TradersTab({super.key});

  @override
  State<TradersTab> createState() => _TradersTabState();
}

class _TradersTabState extends State<TradersTab> {
  bool _isRiskScoreExpanded = true;
  String _selectedShowFirst = 'Risk score';
  String _selectedTime = 'all time';

  void _navigateToFilterScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TradersFilterScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Master Rating, Search, and Filter
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 0.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      Get.back(canPop: true, closeOverlays: true);
                    },
                    icon: SvgPicture.asset('assets/svg/ib_dashboard/home.svg'),
                  ),
                  Text(
                    TranslationUtils.tr('traders_tab_master_rating'),
                    style: AppTextStyles.bodyText.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: SvgPicture.asset('assets/svg/search-normal.svg'),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.filter_alt_outlined,
                          color: AppColors.textGrey,
                        ),
                        onPressed: _navigateToFilterScreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filters Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 0.5,
                shadowColor: AppColors.icongrey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.surface),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    minTileHeight: 35,
                    iconColor: AppColors.textPrimary,
                    initiallyExpanded: _isRiskScoreExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _isRiskScoreExpanded = expanded;
                      });
                    },
                    title: Text(
                      TranslationUtils.tr('traders_tab_risk_score'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text(
                              TranslationUtils.tr('traders_tab_whom_to_show_first'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.only(left: 10.0),
                            child: Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  'Risk score',
                                  'traders_tab_sort_risk_score',
                                  _selectedShowFirst,
                                  (val) =>
                                      setState(() => _selectedShowFirst = val),
                                ),
                                _buildFilterChip(
                                  'Top gainers',
                                  'traders_tab_sort_top_gainers',
                                  _selectedShowFirst,
                                  (val) =>
                                      setState(() => _selectedShowFirst = val),
                                ),
                                _buildFilterChip(
                                  'Most popular',
                                  'traders_tab_sort_most_popular',
                                  _selectedShowFirst,
                                  (val) =>
                                      setState(() => _selectedShowFirst = val),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text(
                              TranslationUtils.tr('traders_tab_for_what_time'),
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.textGrey,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  '2 weeks',
                                  'traders_tab_range_2_weeks',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                                _buildFilterChip(
                                  '1 month',
                                  'traders_tab_range_1_month',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                                _buildFilterChip(
                                  '3 months',
                                  'traders_tab_range_3_months',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                                _buildFilterChip(
                                  '6 months',
                                  'traders_tab_range_6_months',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                                _buildFilterChip(
                                  'all time',
                                  'traders_tab_range_all_time',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          // 'For what time' section moved to bottom sheet
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Trader List Data using TraderCard
            // ListView(
            //   shrinkWrap: true,
            //   physics: const NeverScrollableScrollPhysics(),
            //   padding: EdgeInsets.all(16),
            //   children: [
            //     TraderCard(
            //       name: 'Prime_traders',
            //       badge: '1 RISK',
            //       gain: '33.71%',
            //       copier: '138',
            //       commission: '35%',
            //       profitAndLoss: r'$12345.67',
            //     ),
            //     TraderCard(
            //       name: 'Prime_traders',
            //       badge: '1 RISK',
            //       gain: '33.71%',
            //       copier: '138',
            //       commission: '35%',
            //       profitAndLoss: r'$12345.67',
            //     ),
            //     TraderCard(
            //       name: 'Prime_traders',
            //       badge: '1 RISK',
            //       gain: '33.71%',
            //       copier: '138',
            //       commission: '35%',
            //       profitAndLoss: r'$12345.67',
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String value,
    String labelKey,
    String selectedValue,
    Function(String) onSelect,
  ) {
    bool isSelected = value == selectedValue;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary
                  : AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          TranslationUtils.tr(labelKey),
          style: AppTextStyles.bodyText.copyWith(
            color: isSelected ? AppColors.whiteColor : AppColors.textPrimary,
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
