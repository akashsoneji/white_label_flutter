import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/routes/app_pages.dart';

class TraderCard extends StatelessWidget {
  final String name;
  final String badge;
  final String gain;
  final String copier;
  final String commission;
  final String profitAndLoss;

  const TraderCard({
    super.key,
    required this.name,
    required this.badge,
    required this.gain,
    required this.copier,
    required this.commission,
    required this.profitAndLoss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to trader details
        Get.toNamed(AppPages.TRADER_DETAILS);
      },
      child: Card(
        elevation: 0.5,
        margin: EdgeInsets.only(bottom: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.surface),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Avatar, Name, Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/svg/copy_trading/person_svg.svg',
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.bodyText.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'High Achiever',
                            style: AppTextStyles.bodyText.copyWith(
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w400,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentStatic,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 4),
                Divider(color: AppColors.dashLineColor),
              SizedBox(height: 4),

              // 3-Column Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric('Gain', gain, AppColors.primary),
                  _buildMetric('Copier', copier, AppColors.primary),
                  _buildMetric('Commission', commission, AppColors.primary),
                ],
              ),

              SizedBox(height: 8),

              // Profit and Loss Row
              Text(
                'Profit and Loss',
                style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 12),
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    profitAndLoss,
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    r'$0.00',
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: SizedBox(
                  height: 3, // very thin
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.surface, // light background
                    color: AppColors.primary, // solid purple
                    // Or use gradient (more modern look):
                    value: 0.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 12)),
        SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
