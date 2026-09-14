import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/trade_win/view_models/trade_win_controller.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/models/trade_win/trade_win_product_model.dart';
import 'package:crm_app/models/trade_win/trade_win_leaderboard_entry_model.dart';
import 'package:crm_app/utils/trade_win_format.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';
import 'package:crm_app/screens/trade_win/widgets/trade_win_product_image.dart';
import 'package:crm_app/services/language_service.dart';

class IbmPromotionScreen extends StatefulWidget {
  const IbmPromotionScreen({super.key});

  @override
  State<IbmPromotionScreen> createState() => _IbmPromotionScreenState();
}

class _IbmPromotionScreenState extends State<IbmPromotionScreen> {
  late final TradeWinController controller;
  String selectedFilter = 'all'; // all, ready_to_redeem
  final Map<int, int> productQuantities = {};
  Worker? _tabWorker;

  static const int _promotionTabIndex = 1;

  void _fetchData() {
    controller.fetchProducts(
      audience: 'ib',
      availability: 'all',
      category: 'all',
    );
    controller.fetchPastWins(reset: true);
  }

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<TradeWinController>()) {
      controller = Get.find<TradeWinController>();
    } else {
      controller = Get.put(TradeWinController());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
    if (Get.isRegistered<IbmController>()) {
      final ibm = Get.find<IbmController>();
      _tabWorker = ever<int>(ibm.currentTabIndex, (index) {
        if (index == _promotionTabIndex) {
          controller.fetchProducts(
            audience: 'ib',
            availability: controller.selectedAvailability.value,
            category: controller.selectedCategory.value,
            showLoader: false,
          );
          controller.fetchPastWins(reset: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: IbmTopHeader(
        title: TranslationUtils.tr('ibm_promotion_and_rewards'),
        showBackButton: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.products.isEmpty) {
          return Center(
            child: CommonLoadingWidget(size: 45.0, color: AppColors.primary),
          );
        }

        final stats = controller.stats.value;
        final products = controller.products;
        final pastWins = controller.pastWins;
        final leaderboard = controller.leaderboard;

        final availableLots = stats?.totalLots ?? 0.0;
        final lifetimeLots = stats?.lifetimeLots ?? 0.0;
        final spentLots = stats?.spentLots ?? 0.0;
        final totalWins = stats?.pastWinsCount ?? pastWins.length;
        final totalValueWon = stats?.totalPrizeValueWon ?? 0.0;

        final isAllSelected = controller.selectedAvailability.value == 'all';
        final isRedeemableSelected =
            controller.selectedAvailability.value == 'redeemable';

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await controller.fetchProducts(showLoader: false);
            await controller.fetchPastWins(reset: true);
          },
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Top 3 Metric Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12.w) / 3;
                  return Row(
                    children: [
                      _buildTopStatCard(
                        width: cardWidth,
                        icon: Icons.bar_chart,
                        iconBg: AppColors.primary,
                        title: TranslationUtils.tr('ibm_available_ib_lots'),
                        value: availableLots.toStringAsFixed(1),
                        subtitle: TranslationUtils.trArgs(
                          'ibm_lifetime_spent_lots',
                          {
                            'lifetime': lifetimeLots.toStringAsFixed(1),
                            'spent': spentLots.toStringAsFixed(1),
                          },
                        ),
                      ),
                      SizedBox(width: 6.w),
                      _buildTopStatCard(
                        width: cardWidth,
                        icon: Icons.verified_user_outlined,
                        iconBg: AppColors.primary,
                        title: TranslationUtils.tr('tw_past_wins'),
                        value: '$totalWins',
                        subtitle: TranslationUtils.tr('tw_total_redemptions'),
                      ),
                      SizedBox(width: 6.w),
                      _buildTopStatCard(
                        width: cardWidth,
                        icon: Icons.account_balance_wallet_outlined,
                        iconBg: AppColors.primary,
                        title: TranslationUtils.tr('tw_value_won'),
                        value: '\$${totalValueWon.toStringAsFixed(0)}',
                        subtitle: TranslationUtils.tr('tw_total_prize_value'),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 16.h),

              // Filter Chips (All / Ready to Redeem) & Categories
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPillChip(
                      label: TranslationUtils.trArgs('ibm_all_count', {
                        'count': '${products.length}',
                      }),
                      isSelected: isAllSelected,
                      onTap: () {
                        if (!isAllSelected) {
                          controller.fetchProducts(
                            availability: 'all',
                            audience: 'ib',
                            showLoader: false,
                          );
                        }
                      },
                    ),
                    SizedBox(width: 6.w),
                    _buildPillChip(
                      label: TranslationUtils.trArgs(
                        'ibm_ready_to_redeem_count',
                        {
                          'count':
                              '${isRedeemableSelected ? products.length : products.where((p) => p.requiredLots <= availableLots).length}',
                        },
                      ),
                      isSelected: isRedeemableSelected,
                      onTap: () {
                        if (!isRedeemableSelected) {
                          controller.fetchProducts(
                            availability: 'redeemable',
                            audience: 'ib',
                            showLoader: false,
                          );
                        }
                      },
                    ),
                    SizedBox(width: 12.w),
                    Container(height: 20.h, width: 1, color: AppColors.divider),
                    SizedBox(width: 12.w),
                    ...controller.categories.map((cat) {
                      final isSelected =
                          controller.selectedCategory.value.toLowerCase() ==
                          cat.toLowerCase();
                      return Padding(
                        padding: EdgeInsetsDirectional.only(end: 6.w),
                        child: _buildPillChip(
                          label: cat.toUpperCase(),
                          isSelected: isSelected,
                          onTap: () {
                            controller.fetchProducts(
                              category: cat.toLowerCase(),
                              audience: 'ib',
                              showLoader: false,
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Product Catalog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    TranslationUtils.trArgs('ibm_products_available', {
                      'count': '${products.length}',
                    }),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              if (controller.isProductsFiltering.value)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Center(
                    child: CommonLoadingWidget(
                      size: 36.0,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (products.isEmpty)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 30.h),
                  alignment: Alignment.center,
                  child: Text(
                    TranslationUtils.tr('ibm_no_promotional_rewards'),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                )
              else
                ...products
                    .map((product) => _buildProductCard(product, availableLots))
                    .toList(),

              SizedBox(height: 20.h),

              // Live Leaderboard & My Past Wins Section
              _buildLeaderboardAndWinsSection(leaderboard, pastWins),

              SizedBox(height: 30.h),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTopStatCard({
    required double width,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Icon(icon, size: 14.w, color: AppColors.whiteColor),
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 9.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(fontSize: 8.sp, color: AppColors.textGrey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPillChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary
                  : (AppColors.isDarkMode
                      ? Colors.grey[800]
                      : const Color(0xFFF1F1F4)),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.whiteColor : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(TradeWinProductModel product, double availableLots) {
    final qty = productQuantities[product.id] ?? 1;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image Header
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            child: SizedBox(
              height: 180.h,
              width: double.infinity,
              child: TradeWinProductImage(
                imagePath: product.imagePath,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Category Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        product.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  product.description.isNotEmpty
                      ? product.description
                      : TranslationUtils.tr('ibm_exclusive_loyalty_reward'),
                  style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
                ),
                SizedBox(height: 12.h),

                // Lot Requirement Container
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TranslationUtils.tr('ibm_lot_requirement'),
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${product.requiredLots.toStringAsFixed(0)} ',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            TranslationUtils.tr('ibm_lots_lower'),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            TranslationUtils.tr('tw_closed_trades_only'),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),

                // Details Table
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color:
                        AppColors.isDarkMode
                            ? Colors.grey[900]
                            : const Color(0xFFF9F9FB),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        TranslationUtils.tr('ibm_allowed_groups_label'),
                        product.displayAllowedGroups,
                      ),
                      SizedBox(height: 4.h),
                      _buildDetailRow(
                        TranslationUtils.tr('ibm_allowed_symbols_label'),
                        product.displayAllowedSymbols,
                      ),
                      SizedBox(height: 4.h),
                      _buildDetailRow(
                        TranslationUtils.tr('ibm_your_available_lots_label'),
                        availableLots.toStringAsFixed(1),
                        valueColor: Colors.green,
                      ),
                      SizedBox(height: 4.h),
                      _buildDetailRow(
                        TranslationUtils.tr('ibm_your_available_deposit_label'),
                        '\$0',
                        valueColor: Colors.green,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                // Footer (Value, Stock, Claimed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      TranslationUtils.trArgs('ibm_value_amount', {
                        'amount': product.prizeValue.toStringAsFixed(0),
                      }),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      TranslationUtils.trArgs('ibm_stock_left', {
                        'count': '${product.stock}',
                      }),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      TranslationUtils.trArgs('ibm_claimed_times', {
                        'count': '${product.claimsCount}',
                      }),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),

                // Quantity counter & Redeem Now Button
                Row(
                  children: [
                    // Quantity selector
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.remove,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth: 32.w,
                              minHeight: 32.h,
                            ),
                            onPressed:
                                qty > 1
                                    ? () {
                                      setState(() {
                                        productQuantities[product.id] = qty - 1;
                                      });
                                    }
                                    : null,
                          ),
                          Text(
                            '$qty',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth: 32.w,
                              minHeight: 32.h,
                            ),
                            onPressed:
                                qty < product.stock
                                    ? () {
                                      setState(() {
                                        productQuantities[product.id] = qty + 1;
                                      });
                                    }
                                    : null,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    // Redeem Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            () => _showRedeemDialog(context, product, qty),
                        icon: Icon(
                          Icons.redeem,
                          size: 16.w,
                          color: AppColors.whiteColor,
                        ),
                        label: Text(
                          TranslationUtils.tr('tw_redeem_now'),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.whiteColor,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.whiteColor,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(
    BuildContext context,
    TradeWinProductModel product,
    int qty,
  ) {
    int currentStep = 1;
    bool isSubmitting = false;
    String referenceNo = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              padding: EdgeInsetsDirectional.fromSTEB(20.w, 16.h, 20.w, 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: SizedBox(
                          width: 56.w,
                          height: 56.w,
                          child: TradeWinProductImage(imagePath: product.imagePath),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TranslationUtils.tr('tw_redeem_prize'),
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textGrey,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              product.name,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              TranslationUtils.trArgs('ibm_amount_value', {
                                'amount': product.prizeValue.toStringAsFixed(0),
                              }),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: AppColors.textGrey,
                          size: 20.w,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Stepper Line (1 and 2)
                  Row(
                    children: [
                      Container(
                        width: 24.w,
                        height: 24.w,
                        decoration:  BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: AppColors.whiteColor,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: currentStep == 2
                              ?  AppColors.primary
                              : AppColors.divider,
                          margin: EdgeInsets.symmetric(horizontal: 8.w),
                        ),
                      ),
                      Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: BoxDecoration(
                          color: currentStep == 2
                              ?  AppColors.primary
                              : (AppColors.isDarkMode
                                  ? Colors.grey[800]
                                  : const Color(0xFFE0E0E0)),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: currentStep == 2
                                ? AppColors.whiteColor
                                : AppColors.textGrey,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),

                  if (currentStep == 1) ...[
                    // Step 1: Confirm Redemption
                    Text(
                      TranslationUtils.tr('tw_step_confirm'),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Items Box
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.isDarkMode
                            ? Colors.grey[900]
                            : const Color(0xFFF9F9FB),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                TranslationUtils.tr('ibm_item_label'),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              Text(
                                TranslationUtils.tr('ibm_quantity_label'),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '$qty',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Amber Warning Box
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: const Color(0xFFE65100),
                            size: 18.w,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              TranslationUtils.tr('ibm_once_redeemed_warning'),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: const Color(0xFF8D4E00),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Action buttons: Cancel & Yes, Continue
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              side: BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            child: Text(
                              TranslationUtils.tr('account_management_cancel'),
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setModalState(() {
                                      isSubmitting = true;
                                    });
                                    try {
                                      final response = await ApiService.post(
                                        endpoint: ApiConstants.tradeWinClaim,
                                        data: {
                                          'product_id': product.id,
                                          'quantity': qty,
                                          'shipping_details': null,
                                          'audience': 'ib',
                                        },
                                      );

                                      if (response.success &&
                                          response.data != null) {
                                        final ref = response.data['reference_no'] ??
                                            response.data['reference'] ??
                                            response.data['claim_id']?.toString() ??
                                            '';
                                        setModalState(() {
                                          referenceNo = ref.toString();
                                          currentStep = 2;
                                          isSubmitting = false;
                                        });
                                      } else {
                                        setModalState(() {
                                          isSubmitting = false;
                                        });
                                        CustomToastService.showError(
                                          message: response.message ??
                                              TranslationUtils.tr(
                                                'ibm_claim_failed',
                                              ),
                                        );
                                      }
                                    } catch (e) {
                                      setModalState(() {
                                        isSubmitting = false;
                                      });
                                      CustomToastService.showError(
                                        message: 'Error: $e',
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.whiteColor,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            child: isSubmitting
                                ? SizedBox(
                                    width: 18.w,
                                    height: 18.w,
                                    child: CircularProgressIndicator(
                                      color: AppColors.whiteColor,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        TranslationUtils.tr('ibm_yes_continue'),
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.whiteColor,
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 14,
                                        color: AppColors.whiteColor,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Step 2: Redemption Successful!
                    Center(
                      child: Column(
                        children: [
                          SizedBox(height: 10.h),
                          Container(
                            width: 64.w,
                            height: 64.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00C853),
                                width: 3.5,
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              color: const Color(0xFF00C853),
                              size: 40.w,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            TranslationUtils.tr('tw_redemption_successful'),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF004D40),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            TranslationUtils.trArgs('ibm_your_x_is_processing', {
                              'name': product.name,
                            }),
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.textGrey,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: 14.h,
                              horizontal: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.isDarkMode
                                  ? Colors.grey[900]
                                  : const Color(0xFFF9F9FB),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  TranslationUtils.tr('tw_reference_number'),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textGrey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  referenceNo.isNotEmpty
                                      ? referenceNo
                                      : 'INDP-644',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14.h),
                          Text(
                            TranslationUtils.tr('ibm_status_updates_via_email'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.textGrey,
                            ),
                          ),
                          SizedBox(height: 20.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _fetchData();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.whiteColor,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              child: Text(
                                TranslationUtils.tr('navigation_done'),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.whiteColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardAndWinsSection(
    List<dynamic> leaderboard,
    List<dynamic> pastWins,
  ) {
    return Column(
      children: [
        // Live Leaderboard Card
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 16.w,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        TranslationUtils.tr('tw_live_leaderboard'),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      size: 16.w,
                      color: AppColors.textGrey,
                    ),
                    onPressed:
                        () => controller.fetchProducts(showLoader: false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              if (leaderboard.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Center(
                    child: Text(
                      TranslationUtils.tr('ibm_no_leaderboard_data_yet'),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                )
              else
                ...leaderboard.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  String name = TranslationUtils.tr('ibm_trader');
                  String lots = '0.0';
                  int rank = index + 1;

                  if (item is TradeWinLeaderboardEntryModel) {
                    name =
                        item.name.isNotEmpty
                            ? TradeWinFormat.maskName(item.name)
                            : TranslationUtils.trArgs('ibm_trader_numbered', {
                              'rank':
                                  '${item.rank > 0 ? item.rank : index + 1}',
                            });
                    lots = item.lots.toStringAsFixed(1);
                    if (item.rank > 0) rank = item.rank;
                  } else if (item is Map) {
                    final rawName =
                        item['name']?.toString() ??
                        item['trader']?.toString() ??
                        '';
                    name =
                        rawName.isNotEmpty
                            ? TradeWinFormat.maskName(rawName)
                            : TranslationUtils.trArgs('ibm_trader_numbered', {
                              'rank': '${index + 1}',
                            });
                    final rawLots =
                        item['closed_lots'] ?? item['lots'] ?? '0.0';
                    if (rawLots is num) {
                      lots = rawLots.toDouble().toStringAsFixed(1);
                    } else if (rawLots is String) {
                      final parsed = double.tryParse(rawLots);
                      lots =
                          parsed != null ? parsed.toStringAsFixed(1) : rawLots;
                    }
                    if (item['rank'] != null) {
                      rank =
                          int.tryParse(item['rank'].toString()) ?? (index + 1);
                    }
                  } else {
                    name = item.toString();
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    child: Row(
                      children: [
                        _buildRankBadge(rank),
                        SizedBox(width: 10.w),
                        CircleAvatar(
                          radius: 12.r,
                          backgroundColor: const Color(
                            0xFF5F259E,
                          ).withOpacity(0.1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'T',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          TranslationUtils.trArgs('ibm_lots_count', {
                            'count': lots,
                          }),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        // My Past Wins Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.military_tech_outlined,
                    size: 16.w,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    TranslationUtils.tr('tw_my_past_wins'),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              if (pastWins.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          TranslationUtils.tr('ibm_no_redemptions_yet'),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          TranslationUtils.tr('ibm_keep_trading_to_win'),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...pastWins.map((win) {
                  String title = TranslationUtils.tr('ibm_prize');
                  String date = '';
                  String ref = '';
                  String status = 'Delivered';
                  String imagePath = '';
                  double prizeValue = 0;

                  if (win is Map) {
                    title =
                        win['product_name']?.toString() ??
                        TranslationUtils.tr('ibm_prize');
                    date =
                        (win['claim_date'] ?? win['created_at'] ?? '')
                            .toString();
                    ref =
                        (win['reference_no'] ?? 'INDP-${win['id'] ?? ''}')
                            .toString();
                    status = (win['status'] ?? 'Delivered').toString();
                    imagePath = (win['image_path'] ?? '').toString();
                    prizeValue =
                        double.tryParse((win['prize_value'] ?? 0).toString()) ??
                        0;
                  } else {
                    title =
                        win.productName.isNotEmpty
                            ? win.productName
                            : TranslationUtils.tr('ibm_prize');
                    date =
                        win.claimDate.isNotEmpty
                            ? win.claimDate
                            : win.statusDate;
                    ref = win.referenceCode;
                    status = win.status.isNotEmpty ? win.status : 'Delivered';
                    imagePath = win.imagePath;
                    prizeValue = win.prizeValue;
                  }

                  return Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color:
                          AppColors.isDarkMode
                              ? Colors.grey[900]
                              : const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6.r),
                          child: SizedBox(
                            width: 44.w,
                            height: 44.w,
                            child: TradeWinProductImage(imagePath: imagePath),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$title ${prizeValue > 0 ? '(\$${prizeValue.toStringAsFixed(0)} value)' : ''}',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          status.toLowerCase() == 'delivered' ||
                                                  status.toLowerCase() ==
                                                      'approved'
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 8.5.sp,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            status.toLowerCase() ==
                                                        'delivered' ||
                                                    status.toLowerCase() ==
                                                        'approved'
                                                ? const Color(0xFF2E7D32)
                                                : const Color(0xFFE65100),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                TranslationUtils.trArgs(
                                  'cregis_address_screen_reference_number',
                                  {'reference': ref},
                                ),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              if (date.isNotEmpty) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  TranslationUtils.trArgs(
                                    'ibm_promotion_submitted_date',
                                    {'date': date},
                                  ),
                                  style: TextStyle(
                                    fontSize: 9.5.sp,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return const Icon(
        Icons.workspace_premium,
        color: Color(0xFFFFD700),
        size: 20,
      );
    } else if (rank == 2) {
      return const Icon(
        Icons.workspace_premium,
        color: Color(0xFFC0C0C0),
        size: 20,
      );
    } else if (rank == 3) {
      return const Icon(
        Icons.workspace_premium,
        color: Color(0xFFCD7F32),
        size: 20,
      );
    }
    return Container(
      width: 20.w,
      alignment: Alignment.center,
      child: Text(
        '#$rank',
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.textGrey,
        ),
      ),
    );
  }
}
