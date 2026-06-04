import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:share_plus/share_plus.dart';

enum CommissionPeriod { thisMonth, thisQuarter, thisYear }

class IbDashboardNewScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const IbDashboardNewScreen({super.key, this.onNavigateToTab});

  @override
  State<IbDashboardNewScreen> createState() => _IbDashboardNewScreenState();
}

class _IbDashboardNewScreenState extends State<IbDashboardNewScreen> {
  late IBController ibController;
  CommissionPeriod _selectedPeriod = CommissionPeriod.thisMonth;

  @override
  void initState() {
    super.initState();
    // Get or create IBController
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }
    // Load dashboard and stats data
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await ibController.loadDashboardData();
    if (mounted) {
      setState(() {});
    }
  }

  void _onShare(String text) async {
    final params = ShareParams(text: '$text');
    await SharePlus.instance.share(params);
  }

  // ignore: unused_element
  void _copyReferenceLink(String? link) {
    if (link != null && link.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: link));
      CustomToastService.showSuccess(
        message: 'Reference link copied to clipboard',
      );
    }
  }

  String _getPeriodLabel(CommissionPeriod period) {
    switch (period) {
      case CommissionPeriod.thisMonth:
        return 'This Month';
      case CommissionPeriod.thisQuarter:
        return 'This Quarter';
      case CommissionPeriod.thisYear:
        return 'This Year';
    }
  }

  double _getMyCommission(CommissionPeriod period) {
    final stats = ibController.ibStats.value;
    if (stats == null) return 0.0;
    switch (period) {
      case CommissionPeriod.thisMonth:
        return stats.myCommissionThisMonth ?? 0.0;
      case CommissionPeriod.thisQuarter:
        return stats.myCommissionThisQuarter ?? 0.0;
      case CommissionPeriod.thisYear:
        return stats.myCommissionThisYear ?? 0.0;
    }
  }

  double _getSubIbCommission(CommissionPeriod period) {
    final stats = ibController.ibStats.value;
    if (stats == null) return 0.0;
    switch (period) {
      case CommissionPeriod.thisMonth:
        return stats.subIbCommissionThisMonth ?? 0.0;
      case CommissionPeriod.thisQuarter:
        return stats.subIbCommissionThisQuarter ?? 0.0;
      case CommissionPeriod.thisYear:
        return stats.subIbCommissionThisYear ?? 0.0;
    }
  }

  double _getTotalCommission(CommissionPeriod period) {
    return _getMyCommission(period) + _getSubIbCommission(period);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: AppBackButton(
          onPressed: () => Get.offAllNamed(AppPages.TRADING),
        ),
        automaticallyImplyLeading: false,
        title: Text(
          'IB Dashboard',
          style: TextStyle(
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
              message: 'Loading dashboard...',
              size: 50.0,
              color: AppColors.primary,
            ),
          );
        }

        final dashboardData =
            ibController.ibDashboardResponse.value?.data?.userIBDetails;
        final stats = ibController.ibStats.value;

        return RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // My Reference Links Card
                  _buildReferenceLinksCard(dashboardData),

                  SizedBox(height: 20.h),

                  // Commission Summary Section
                  _buildCommissionSummary(),

                  SizedBox(height: 20.h),

                  // Statistics Cards Grid
                  _buildStatisticsGrid(stats),
                  // Bottom padding for floating navigation bar (safe area + nav bar height + extra spacing)
                  SizedBox(height: 100.h),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildReferenceLinksCard(dynamic dashboardData) {
    final referenceLinkId = dashboardData?.referenceLinkId ?? '';
    final referenceLinksCount = ibController.ibStats.value?.referenceLinks ?? 0;
    final baseUrl = FlavorConfig.instance.apiBaseUrl.replaceAll('api/', '');
    final referenceLink =
        referenceLinkId.isNotEmpty
            ? '${baseUrl}referral?sponsorcode=$referenceLinkId'
            : '';
    // https: //my.pipze.com/referral?sponsorcode=IB_001160
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            referenceLinksCount.toString(),
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          Text(
            'My Reference Links Count',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          if (referenceLink.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.cardBackGround,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      referenceLink,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    // onTap: () => _copyReferenceLink(referenceLink),
                    onTap: () => _onShare(referenceLink),
                    child: Row(
                      children: [
                        Icon(Icons.share, color: AppColors.red, size: 16),
                        // SvgPicture.asset(
                        //   "assets/svg/ib_dashboard/copy.svg",
                        //   height: 18,
                        // ),
                        SizedBox(width: 2.w),
                        Text(
                          'Share',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.red,
                            height: 1.4.h,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommissionSummary() {
    final myCommission = _getMyCommission(_selectedPeriod);
    final subIbCommission = _getSubIbCommission(_selectedPeriod);
    final totalCommission = _getTotalCommission(_selectedPeriod);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with dropdown
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Commission Summary',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 1),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: DropdownButton<CommissionPeriod>(
                iconSize: 16,
                value: _selectedPeriod,
                underline: const SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                items:
                    CommissionPeriod.values.map((period) {
                      return DropdownMenuItem(
                        value: period,
                        child: Text(
                          _getPeriodLabel(period),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        // Commission Cards
        Row(
          children: [
            Expanded(
              child: _buildCommissionCard(
                'My Commission',
                myCommission,
                totalCommission > 0 ? myCommission / totalCommission : 0.0,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildCommissionCard(
                'Sub-IB Commission',
                subIbCommission,
                totalCommission > 0 ? subIbCommission / totalCommission : 0.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommissionCard(String title, double value, double progress) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textGrey,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6.h,
              backgroundColor: AppColors.cardBackGround,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(dynamic stats) {
    if (stats == null) {
      return const SizedBox.shrink();
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          title: 'Total Clients',
          value: (stats.totalClients ?? 0).toString(),
          icon: 'assets/svg/more/ib_dashboard/my-clients.svg',
          onTap: () {
            // Navigate to Clients tab (index 2)
            if (widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(2);
            }
          },
        ),
        _buildStatCard(
          title: 'Total Lot',
          value: (stats.totalLots ?? 0).toStringAsFixed(2),
          icon: 'assets/svg/more/ib_dashboard/overview.svg',
        ),
        _buildStatCard(
          isLongTitle: true,
          title: 'Total Withdrawal Rebate',
          value: '\$${(stats.ibWithdrawalRebate ?? 0).toStringAsFixed(2)}',
          icon: 'assets/svg/more/ib_dashboard/payout-request.svg',
        ),
        _buildStatCard(
          title: 'Available Rebate',
          value: '\$${stats.availableRebate ?? '0.00'}',
          icon: 'assets/svg/more/ib_dashboard/commisson-history.svg',
          isHighlighted: false,
        ),
        _buildStatCard(
          title: 'Total Deposited',
          value: '\$${(stats.totalDeposited ?? 0).toStringAsFixed(2)}',
          icon: 'assets/svg/more/ib_dashboard/overview.svg',
        ),

        _buildStatCard(
          title: 'Total Withdrawal',
          value: '\$${(stats.totalWithdrawal ?? 0).toStringAsFixed(2)}',
          icon: 'assets/svg/more/ib_dashboard/overview.svg',
        ),
        _buildStatCard(
          title: 'Total available equity',
          value: '\$${(stats.totalEquity ?? 0).toStringAsFixed(2)}',
          icon: 'assets/svg/more/ib_dashboard/overview.svg',
        ),
        _buildStatCard(
          title: 'Margin Level below 100%',
          value: (stats.marginLevelBelow100 ?? 0).toString(),
          icon: 'assets/svg/chart_screen_icon/bell_icon.svg',
          isLongTitle: true,
        ),
        _buildStatCard(
          title: 'IB Pending Request',
          value: (stats.ibPendingRequests ?? 0).toString(),
          icon: 'assets/svg/more/ib_dashboard/overview.svg',
          onTap: () {
            // Navigate to Requests tab (index 3)
            if (widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(3);
            }
          },
        ),

        _buildStatCard(
          title: 'Total Rebate Gen.',
          value: '\$${stats.totalRebateGenerated ?? '0.00'}',
          icon: 'assets/svg/more/ib_dashboard/commisson-history.svg',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String icon,
    void Function()? onTap,

    bool isHighlighted = false,
    bool isLongTitle = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                // fontSize: title.toString().length >= 19?11.sp:12.sp,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textGrey,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '${value}',
              style: TextStyle(
                fontSize: title.toString().length >= 19 ? 18.sp : 20.sp,
                // fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );

    //   child: Container(
    //     padding: EdgeInsets.all(isLongTitle ? 12.w : 16.w),
    //     decoration: BoxDecoration(
    //       color: AppColors.whiteColor,
    //       borderRadius: BorderRadius.circular(12.r),
    //       border:
    //           isHighlighted ? Border.all(color: Colors.green, width: 2) : null,
    //       boxShadow: [
    //         BoxShadow(
    //           color: Colors.black.withValues(alpha: 0.1),
    //           blurRadius: 8,
    //           offset: const Offset(0, 2),
    //         ),
    //       ],
    //     ),
    //     child: Column(
    //       crossAxisAlignment: CrossAxisAlignment.center,
    //       mainAxisAlignment: MainAxisAlignment.center,
    //       mainAxisSize: MainAxisSize.min,
    //       children: [
    //         if (icon.isNotEmpty)
    //           SvgPicture.asset(
    //             icon,
    //             height: 20.h,
    //             width: 20.w,
    //             colorFilter: ColorFilter.mode(
    //               AppColors.primary,
    //               BlendMode.srcIn,
    //             ),
    //           ),
    //         SizedBox(height: isLongTitle ? 6.h : 8.h),
    //         Text(
    //           value,
    //           style: TextStyle(
    //             fontSize: 18.sp,
    //             fontWeight: FontWeight.w600,
    //             color: AppColors.primary,
    //             height: 1.2,
    //           ),
    //         ),
    //         SizedBox(height: isLongTitle ? 4.h : 6.h),
    //         Flexible(
    //           child: Text(
    //             title,
    //             textAlign: TextAlign.center,
    //             style: TextStyle(
    //               fontSize: isLongTitle ? 11.sp : 12.sp,
    //               fontWeight: FontWeight.w400,
    //               color: AppColors.textPrimary,
    //               height: 1.1,
    //             ),
    //             maxLines: isLongTitle ? 3 : 2,
    //             overflow: TextOverflow.ellipsis,
    //           ),
    //         ),
    //       ],
    //     ),
    //   ),
    // );
  }
}
