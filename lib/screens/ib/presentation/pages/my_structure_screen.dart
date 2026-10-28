import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/responsive_layout.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/models/ib_models.dart';
import 'package:crm_app/services/language_service.dart';

class MyStructureScreen extends StatefulWidget {
  final bool isEmbedded;
  const MyStructureScreen({super.key, this.isEmbedded = false});

  @override
  State<MyStructureScreen> createState() => _MyStructureScreenState();
}

class _MyStructureScreenState extends State<MyStructureScreen> {
  late IBController ibController;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final statusResponse = await ibController.getIBStatus(showLoading: false);
    final ibType =
        statusResponse?.data?.ibType ??
        ibController.ibStatusResponse.value?.data?.ibType ??
        'dynamic';

    if (ibType == 'traditional') {
      await ibController.loadProgressiveStats(showLoading: true);
    } else {
      await ibController.getIBStructure(showLoading: true);
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar:
          widget.isEmbedded
              ? null
              : AppBar(
                scrolledUnderElevation: 0,
                backgroundColor: AppColors.tradeBackgroundCenterColor,
                elevation: 0,
                leading: AppSvgBackButton(
                  onPressed: () => Get.back(closeOverlays: true),
                  iconWidth: 30.w,
                  iconHeight: 30.h,
                ),
                title: Text(
                  TranslationUtils.tr('my_structure_screen_my_structure'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                centerTitle: true,
              ),
      body: Obx(() {
        if (ibController.isLoading.value) {
          return Center(
            child: CommonLoadingWidget(
              message: TranslationUtils.tr(
                'my_structure_screen_loading_structure',
              ),
              size: 50.0,
              color: AppColors.primary,
            ),
          );
        }

        final ibType =
            ibController.ibStatusResponse.value?.data?.ibType ?? 'dynamic';

        return RefreshIndicator(
          onRefresh: _onRefresh,
          backgroundColor: AppColors.whiteColor,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16.w),
            child:
                ibType == 'traditional'
                    ? _buildTraditionalPerformanceDashboard()
                    : _buildDynamicStructureDashboard(),
          ),
        );
      }),
    );
  }

  // =========================================================================
  // TRADITIONAL IB TYPE DESIGN (Progressive Stats / Performance Dashboard)
  // =========================================================================
  Widget _buildTraditionalPerformanceDashboard() {
    final stats = ibController.progressiveStatsData.value;
    if (stats == null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48.sp,
                color: AppColors.textGrey,
              ),
              SizedBox(height: 12.h),
              Text(
                TranslationUtils.tr('ib_no_progressive_stats'),
                style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          TranslationUtils.tr('ib_performance_dashboard'),
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          fontFamily: 'SF UI'),
        ),
        SizedBox(height: 2.h),
        Text(
          TranslationUtils.tr('ib_track_network_metrics'),
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textGrey,
          ),
        ),
        SizedBox(height: 16.h),
        _buildMetricsGrid(stats),
        SizedBox(height: 20.h),
        if (stats.nextTier != null) _buildUnlockTierCard(stats),
        SizedBox(height: 20.h),
        if (stats.currentRebates != null && stats.currentRebates!.isNotEmpty)
          _buildActiveRebatesList(stats),
        SizedBox(height: 100.h),
      ],
    );
  }

  Widget _buildMetricsGrid(dynamic stats) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10.w,
      mainAxisSpacing: 10.h,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: ResponsiveGrid.aspectRatio(2.2),
      children: [
        _buildMetricCard(
          TranslationUtils.tr('ib_active_clients').toUpperCase(),
          (stats.activeClients ?? 0).toString(),
          Icons.people_alt_outlined,
        ),
        _buildMetricCard(
          TranslationUtils.tr(
            'ib_dashboard_new_screen_total_deposit',
          ).toUpperCase(),
          '\$${(stats.totalDeposit ?? 0).toStringAsFixed(2)}',
          Icons.arrow_outward_rounded,
        ),
        _buildMetricCard(
          TranslationUtils.tr(
            'ib_dashboard_new_screen_total_withdrawal',
          ).toUpperCase(),
          '\$${(stats.totalWithdrawal ?? 0).toStringAsFixed(2)}',
          Icons.south_west_rounded,
        ),
        _buildMetricCard(
          TranslationUtils.tr('ib_net_deposit_volume').toUpperCase(),
          '\$${(stats.netDeposit ?? 0).toStringAsFixed(2)}',
          Icons.account_balance_wallet_outlined,
        ),
        _buildMetricCard(
          TranslationUtils.tr('ib_current_tier').toUpperCase(),
          stats.currentTier?.name ?? TranslationUtils.tr('common_none'),
          Icons.verified_outlined,
        ),
        _buildMetricCard(
          TranslationUtils.tr('ib_dashboard_new_screen_total_lot').toUpperCase(),
          (stats.totalLots ?? 0).toStringAsFixed(2),
          Icons.grid_view_rounded,
        ),
        _buildMetricCard(
          TranslationUtils.tr('ib_current_tier_rebate').toUpperCase(),
          '\$${(stats.currentTierEarnings ?? 0).toStringAsFixed(2)}',
          Icons.percent_rounded,
        ),
        _buildMetricCard(
          TranslationUtils.tr('ib_total_earned').toUpperCase(),
          '\$${(stats.totalEarned ?? 0).toStringAsFixed(2)}',
          Icons.payments_outlined,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textGrey,
                    letterSpacing: 0.3,
                  fontFamily: 'SF UI'),
                ),
                SizedBox(height: 3.h),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  fontFamily: 'SF UI'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockTierCard(dynamic stats) {
    final nextTier = stats.nextTier;
    final clientsNeeded = nextTier?.clientsNeeded ?? 0;
    final depositNeeded = nextTier?.depositNeeded ?? 0.0;
    final currentClients = stats.activeClients ?? 0;
    final currentDeposit = stats.netDeposit ?? 0.0;
    final totalClientsTarget = currentClients + clientsNeeded;
    final totalDepositTarget = currentDeposit + depositNeeded;
    final clientProgress =
        totalClientsTarget > 0
            ? (currentClients / totalClientsTarget).clamp(0.0, 1.0)
            : 0.0;
    final depositProgress =
        totalDepositTarget > 0
            ? (currentDeposit / totalDepositTarget).clamp(0.0, 1.0)
            : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: AppColors.primary,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TranslationUtils.trArgs('ib_unlock_tier', {
                          'tier':
                              nextTier?.name ??
                              TranslationUtils.tr('ib_next_tier'),
                        }),
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                        fontFamily: 'SF UI'),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        TranslationUtils.tr('ib_achieve_both_targets'),
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProgressBar(
                  TranslationUtils.tr('ib_active_clients_requirement'),
                  currentClients.toString(),
                  totalClientsTarget.toString(),
                  clientProgress,
                  TranslationUtils.trArgs('ib_count_remaining', {
                    'count': '$clientsNeeded',
                  }),
                  Icons.people_outline,
                ),
                SizedBox(height: 16.h),
                _buildProgressBar(
                  TranslationUtils.tr('ib_net_deposit_requirement'),
                  '\$${currentDeposit.toStringAsFixed(2)}',
                  '\$${totalDepositTarget.toStringAsFixed(2)}',
                  depositProgress,
                  TranslationUtils.trArgs('ib_amount_remaining', {
                    'amount': depositNeeded.toStringAsFixed(2),
                  }),
                  Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    String title,
    String current,
    String target,
    double progress,
    String remaining,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 15.sp, color: AppColors.primary),
                SizedBox(width: 6.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  fontFamily: 'SF UI'),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  current,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  fontFamily: 'SF UI'),
                ),
                Text(
                  ' / $target',
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textGrey,
                  fontFamily: 'SF UI'),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border.withValues(alpha: 0.5),
            color: AppColors.primary,
            minHeight: 7.h,
          ),
        ),
        SizedBox(height: 4.h),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            remaining,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textGrey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveRebatesList(dynamic stats) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Text(
              TranslationUtils.tr('ib_active_rebates_per_lot'),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              fontFamily: 'SF UI'),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            color: AppColors.tradeBackgroundCenterColor.withValues(alpha: 0.5),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textGrey,
                      letterSpacing: 0.5,
                    fontFamily: 'SF UI'),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    TranslationUtils.tr('ib_payout_rates').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textGrey,
                      letterSpacing: 0.5,
                    fontFamily: 'SF UI'),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.currentRebates!.length,
            separatorBuilder:
                (context, index) => Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
            itemBuilder: (context, index) {
              final rebate = stats.currentRebates![index];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 15.sp,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              rebate.categoryName ?? '',
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              fontFamily: 'SF UI'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children:
                            (rebate.levels ?? []).map<Widget>((level) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 7.w,
                                  vertical: 3.5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'L${level.level}',
                                      style: TextStyle(
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textGrey,
                                      fontFamily: 'SF UI'),
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      '\$${level.rate?.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12.5.sp,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.green,
                                      fontFamily: 'SF UI'),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // DYNAMIC IB TYPE DESIGN (Web Screenshot Replica for Mobile)
  // =========================================================================
  Widget _buildDynamicStructureDashboard() {
    final structureData = ibController.ibStructureData.value;
    if (structureData == null ||
        structureData.masterGroups == null ||
        structureData.masterGroups!.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 48.sp,
                color: AppColors.textGrey,
              ),
              SizedBox(height: 12.h),
              Text(
                TranslationUtils.tr(
                  'my_structure_screen_no_structure_data_found',
                ),
                style: TextStyle(fontSize: 14.sp, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      );
    }

    final masterGroups = structureData.masterGroups!;
    final symbolCategories = structureData.symbolCategories ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Info Cards (Standard Groups & Private Groups)
        // _buildDynamicInfoCards(),
        // SizedBox(height: 20.h),

        // Section Title / Tab Banner
        Container(
          padding: EdgeInsets.only(bottom: 8.h),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.brandPrimary, width: 2.5),
            ),
          ),
          child: Text(
            TranslationUtils.tr('ib_groups'),
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            fontFamily: 'SF UI'),
          ),
        ),
        SizedBox(height: 16.h),

        // Horizontally Scrollable Master Groups Cards
        SizedBox(
          height: 480.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: masterGroups.length,
            separatorBuilder: (context, index) => SizedBox(width: 14.w),
            itemBuilder: (context, index) {
              final group = masterGroups[index];
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.78,
                child: _buildMasterGroupCard(group, symbolCategories),
              );
            },
          ),
        ),

        SizedBox(height: 100.h),
      ],
    );
  }

  Widget _buildDynamicInfoCards() {
    return Column(
      children: [
        _buildInfoCard(
          title: TranslationUtils.tr('commission_groups_screen_standard_groups'),
          description:
              TranslationUtils.tr(
                'my_structure_screen_these_commission_rates_are_used_for',
              ),
        ),
        SizedBox(height: 12.h),
        _buildInfoCard(
          title: TranslationUtils.tr('commission_groups_screen_private_groups'),
          description:
              TranslationUtils.tr('ib_private_groups_description'),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required String description}) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 2.h),
            width: 10.w,
            height: 10.h,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  fontFamily: 'SF UI'),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textGrey,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterGroupCard(
    MasterGroup group,
    List<SymbolCategory> categories,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner (Brand Primary color)
          Container(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            color: AppColors.brandPrimary,
            alignment: Alignment.center,
            child: Text(
              (group.groupName ?? group.planTitle ?? 'GROUP').toUpperCase(),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.whiteColor,
                letterSpacing: 1.0,
              fontFamily: 'SF UI'),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.all(14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    categories.map((cat) {
                      final catName = cat.categoryName ?? '';
                      final rate = _getCommissionValue(group, catName);
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              catName,
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              fontFamily: 'SF UI'),
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackGround,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: AppColors.border.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                '\$  $rate',
                                style: TextStyle(
                                  fontSize: 14.5.sp,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textPrimary,
                                fontFamily: 'SF UI'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCommissionValue(MasterGroup group, String categoryName) {
    if (group.commissions == null) return '0.00';
    final value = group.commissions![categoryName];
    if (value == null || value.isEmpty) return '0.00';
    return value;
  }
}
