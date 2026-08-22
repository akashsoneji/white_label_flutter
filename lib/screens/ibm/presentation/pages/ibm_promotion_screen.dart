import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/trade_win/view_models/trade_win_controller.dart';
import 'package:crm_app/models/trade_win/trade_win_product_model.dart';
import 'package:crm_app/models/trade_win/trade_win_leaderboard_entry_model.dart';
import 'package:crm_app/utils/trade_win_format.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';
import 'package:crm_app/screens/trade_win/widgets/trade_win_product_image.dart';

class IbmPromotionScreen extends StatefulWidget {
  const IbmPromotionScreen({super.key});

  @override
  State<IbmPromotionScreen> createState() => _IbmPromotionScreenState();
}

class _IbmPromotionScreenState extends State<IbmPromotionScreen> {
  late final TradeWinController controller;
  String selectedFilter = 'all'; // all, ready_to_redeem
  final Map<int, int> productQuantities = {};

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<TradeWinController>()) {
      controller = Get.find<TradeWinController>();
    } else {
      controller = Get.put(TradeWinController());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchProducts(
        audience: 'ib',
        availability: 'all',
        category: 'all',
      );
      controller.fetchPastWins(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: const IbmTopHeader(
        title: 'Promotion & Rewards',
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
                        title: 'Available IB Lots',
                        value: availableLots.toStringAsFixed(1),
                        subtitle:
                            'Lifetime ${lifetimeLots.toStringAsFixed(1)} · spent ${spentLots.toStringAsFixed(1)}',
                      ),
                      SizedBox(width: 6.w),
                      _buildTopStatCard(
                        width: cardWidth,
                        icon: Icons.verified_user_outlined,
                        iconBg: AppColors.primary,
                        title: 'Past Wins',
                        value: '$totalWins',
                        subtitle: 'Total redemptions',
                      ),
                      SizedBox(width: 6.w),
                      _buildTopStatCard(
                        width: cardWidth,
                        icon: Icons.account_balance_wallet_outlined,
                        iconBg: AppColors.primary,
                        title: 'Value Won',
                        value: '\$${totalValueWon.toStringAsFixed(0)}',
                        subtitle: 'Total prize value',
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
                      label: 'All (${products.length})',
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
                      label:
                          'Ready to Redeem (${isRedeemableSelected ? products.length : products.where((p) => p.requiredLots <= availableLots).length})',
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
                        padding: EdgeInsets.only(right: 6.w),
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
                    '${products.length} products available',
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
                    'No promotional rewards available in this category.',
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
                      : 'Exclusive loyalty reward',
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
                        'LOT REQUIREMENT',
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
                            'lots',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Closed trades only',
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
                        'Allowed Groups:',
                        product.displayAllowedGroups,
                      ),
                      SizedBox(height: 4.h),
                      _buildDetailRow(
                        'Allowed Symbols:',
                        product.displayAllowedSymbols,
                      ),
                      SizedBox(height: 4.h),
                      _buildDetailRow(
                        'Your Available Lots:',
                        availableLots.toStringAsFixed(1),
                        valueColor: Colors.green,
                      ),
                      SizedBox(height: 4.h),
                      _buildDetailRow(
                        'Your Available Deposit:',
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
                      'Value: \$${product.prizeValue.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Stock: ${product.stock} left',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Claimed: ${product.claimsCount} times',
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
                        onPressed: () {
                          Get.toNamed(
                            Routes.TRADE_WIN_REDEEM,
                            arguments: {
                              'productId': product.id,
                              'quantity': qty,
                            },
                          );
                        },
                        icon: Icon(
                          Icons.redeem,
                          size: 16.w,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Redeem Now',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.whiteColor,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
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
                        'Live Leaderboard',
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
                      'No leaderboard data yet.',
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

                  String name = 'Trader';
                  String lots = '0.0';
                  int rank = index + 1;

                  if (item is TradeWinLeaderboardEntryModel) {
                    name =
                        item.name.isNotEmpty
                            ? TradeWinFormat.maskName(item.name)
                            : 'Trader #${item.rank > 0 ? item.rank : index + 1}';
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
                            : 'Trader #${index + 1}';
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
                          '$lots lots',
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
                    'My Past Wins',
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
                          'No redemptions yet',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Keep trading to win!',
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
                  final title =
                      win is Map
                          ? (win['product_name'] ?? 'Prize')
                          : (win.productName ?? 'Prize');
                  final date =
                      win is Map
                          ? (win['created_at'] ?? '')
                          : (win.createdAt ?? '');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: Text(
                      '$title',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '$date',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textGrey,
                      ),
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
