import 'package:flutter/material.dart';
import 'package:crm_app/constants/color.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
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
              padding: const EdgeInsets.symmetric(
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
                  const Text(
                    'Master Rating',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: SvgPicture.asset('assets/svg/search-normal.svg'),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.filter_alt_outlined,
                          color: Colors.grey,
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 0.5,
                shadowColor: AppColors.icongrey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
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
                    title: const Text(
                      'Risk Score',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 15),
                            child: const Text(
                              'Whom to show first',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  'Risk score',
                                  _selectedShowFirst,
                                  (val) =>
                                      setState(() => _selectedShowFirst = val),
                                ),
                                _buildFilterChip(
                                  'Top gainers',
                                  _selectedShowFirst,
                                  (val) =>
                                      setState(() => _selectedShowFirst = val),
                                ),
                                _buildFilterChip(
                                  'Most popular',
                                  _selectedShowFirst,
                                  (val) =>
                                      setState(() => _selectedShowFirst = val),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 15),
                            child: const Text(
                              'For what time',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  '2 weeks',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                                _buildFilterChip(
                                  '1 month',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                                _buildFilterChip(
                                  '3 months',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                                _buildFilterChip(
                                  '6 months',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                                _buildFilterChip(
                                  'all time',
                                  _selectedTime,
                                  (val) => setState(() => _selectedTime = val),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 'For what time' section moved to bottom sheet
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Trader List Data using TraderCard
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: const [
                TraderCard(
                  name: 'Prime_traders',
                  badge: '1 RISK',
                  gain: '33.71%',
                  copier: '138',
                  commission: '35%',
                  profitAndLoss: r'$12345.67',
                ),
                TraderCard(
                  name: 'Prime_traders',
                  badge: '1 RISK',
                  gain: '33.71%',
                  copier: '138',
                  commission: '35%',
                  profitAndLoss: r'$12345.67',
                ),
                TraderCard(
                  name: 'Prime_traders',
                  badge: '1 RISK',
                  gain: '33.71%',
                  copier: '138',
                  commission: '35%',
                  profitAndLoss: r'$12345.67',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String selectedValue,
    Function(String) onSelect,
  ) {
    bool isSelected = label == selectedValue;
    return GestureDetector(
      onTap: () => onSelect(label),
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
          label,
          style: TextStyle(
            color: isSelected ? AppColors.whiteColor : AppColors.textPrimary,
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
