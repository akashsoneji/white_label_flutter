import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crm_app/models/ib_models.dart';
import 'package:crm_app/services/language_service.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

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
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    await ibController.loadDashboardData();
    if (mounted) setState(() {});
  }

  void _onShare(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  String _getPeriodLabel(CommissionPeriod period) {
    switch (period) {
      case CommissionPeriod.thisMonth:
        return TranslationUtils.tr('time_this_month');
      case CommissionPeriod.thisQuarter:
        return TranslationUtils.tr('ib_this_quarter');
      case CommissionPeriod.thisYear:
        return TranslationUtils.tr('time_this_year');
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

  double _fabScrollExtent(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 32.h;

  String? _buildReferenceUrl(dynamic dashboardData) {
    final referenceLinkId = dashboardData?.referenceLinkId ?? '';
    if (referenceLinkId.isEmpty) return null;
    final baseUrl = FlavorConfig.instance.apiBaseUrl.replaceAll('api/', '');
    return '${baseUrl}referral?sponsorcode=$referenceLinkId';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        title: Text(
          TranslationUtils.tr('more_dashboard'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leadingWidth: 75.w,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/svg/ib_dashboard/home.svg',
            colorFilter: ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => Get.offAllNamed(AppPages.TRADING),
        ),
      ),
      body: Obx(() {
        if (ibController.isLoading.value) {
          return Center(
            child: CommonLoadingWidget(
              message: TranslationUtils.tr(
                'ib_dashboard_new_screen_loading_dashboard',
              ),
              size: 50.0,
              color: AppColors.primary,
            ),
          );
        }

        final dashboardData =
            ibController.ibDashboardResponse.value?.data?.userIBDetails;
        final stats = ibController.ibStats.value;
        final referenceUrl = _buildReferenceUrl(dashboardData);
        final referenceLinksCount = stats?.referenceLinks ?? 0;

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.whiteColor,
          onRefresh: _loadDashboardData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Obx(() {
                      if (ibController.banners.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          BannerCarousel(banners: ibController.banners),
                          SizedBox(height: 16.h),
                        ],
                      );
                    }),
                    _buildReferenceHeroCard(
                      count: referenceLinksCount,
                      referenceUrl: referenceUrl,
                    ),
                    SizedBox(height: 20.h),
                    _buildSectionHeader(
                      title: TranslationUtils.tr(
                        'ib_dashboard_new_screen_commission_summary',
                      ),
                      trailing: _buildPeriodDropdown(),
                    ),
                    SizedBox(height: 12.h),
                    _buildCommissionGrid(),
                    SizedBox(height: 16.h),
                    _buildSectionHeader(
                      title: TranslationUtils.tr('common_overview'),
                    ),
                    SizedBox(height: 8.h),
                  ]),
                ),
              ),
              if (stats != null)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8.w,
                      mainAxisSpacing: 8.h,
                      childAspectRatio: 1.39,
                    ),
                    delegate: SliverChildListDelegate(
                      _buildStatGridChildren(stats),
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom:
                      _fabScrollExtent(context) + kBottomNavigationBarHeight,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSectionHeader({required String title, Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildReferenceHeroCard({
    required int count,
    required String? referenceUrl,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TranslationUtils.tr('ib_dashboard_new_screen_my_reference_links'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey,
                ),
              ),
              Text(
                count.toString(),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (referenceUrl != null && referenceUrl.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.fromLTRB(10.w, 10.h, 6.w, 10.h),
              decoration: BoxDecoration(
                color: AppColors.cardBackGround,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      referenceUrl,
                      maxLines: 3,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8.r),
                    child: InkWell(
                      onTap: () => _onShare(referenceUrl),
                      borderRadius: BorderRadius.circular(8.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 7.h,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.share_rounded,
                              size: 14.sp,
                              color: AppColors.whiteColor,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              TranslationUtils.tr('invite_friend_screen_share_link'),
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.whiteColor,
                              ),
                            ),
                          ],
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
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CommissionPeriod>(
          value: _selectedPeriod,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
          borderRadius: BorderRadius.circular(12.r),
          items:
              CommissionPeriod.values.map((period) {
                return DropdownMenuItem(
                  value: period,
                  child: Text(
                    _getPeriodLabel(period),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedPeriod = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCommissionGrid() {
    final myCommission = _getMyCommission(_selectedPeriod);
    final subIbCommission = _getSubIbCommission(_selectedPeriod);

    return Row(
      children: [
        Expanded(
          child: _buildCommissionTile(
            label: TranslationUtils.tr('ib_my_commission'),
            amount: myCommission,
            isPrimary: true,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildCommissionTile(
            label: TranslationUtils.tr('ib_sub_ib_commission'),
            amount: subIbCommission,
            isPrimary: false,
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionTile({
    required String label,
    required double amount,
    required bool isPrimary,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textGrey,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 4.h,
            color:
                isPrimary
                    ? AppColors.primary
                    : AppColors.border.withValues(alpha: 0.55),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatGridChildren(dynamic stats) {
    final ibType = ibController.ibStatusResponse.value?.data?.ibType ?? 'dynamic';
    final isTraditional = ibType == 'traditional';

    final availableRebate =
        stats.availableRebate != null
            ? double.tryParse(stats.availableRebate.toString()) ?? 0.0
            : 0.0;
    final totalRebate =
        stats.totalRebateGenerated != null
            ? double.tryParse(stats.totalRebateGenerated.toString()) ?? 0.0
            : 0.0;

    // 3×3 grid — order matches reference UI (left → right, top → bottom).
    return [
      _buildStatTile(
        title: TranslationUtils.tr('ib_dashboard_new_screen_total_clients'),
        value: (stats.totalClients ?? 0).toString(),
        onTap:
            widget.onNavigateToTab != null
                ? () => widget.onNavigateToTab!(isTraditional ? 2 : 3)
                : null,
      ),
      _buildStatTile(
        title: TranslationUtils.tr('ib_dashboard_new_screen_total_lot'),
        value: (stats.totalLots ?? 0).toStringAsFixed(2),
      ),
      _buildStatTile(
        title: TranslationUtils.tr('ib_dashboard_new_screen_total_equity'),
        value: '\$${(stats.totalEquity ?? 0).toStringAsFixed(2)}',
      ),
      _buildStatTile(
        title: TranslationUtils.tr('ib_dashboard_new_screen_total_rebate'),
        value: '\$${totalRebate.toStringAsFixed(2)}',
      ),
      _buildStatTile(
        title: TranslationUtils.tr('ib_dashboard_new_screen_rebate_withdrawal'),
        value: '\$${(stats.ibWithdrawalRebate ?? 0).toStringAsFixed(2)}',
      ),
      _buildStatTile(
        title: TranslationUtils.tr('ib_dashboard_new_screen_available_rebate'),
        value: '\$${availableRebate.toStringAsFixed(2)}',
        highlight: true,
      ),

      _buildStatTile(
        title: TranslationUtils.tr('ib_dashboard_new_screen_total_deposit'),
        value: '\$${(stats.totalDeposited ?? 0).toStringAsFixed(2)}',
      ),
      _buildStatTile(
        title: TranslationUtils.tr('ib_dashboard_new_screen_total_withdrawal'),
        value: '\$${(stats.totalWithdrawal ?? 0).toStringAsFixed(2)}',
      ),
      _buildStatTile(
        title: TranslationUtils.tr('ib_dashboard_new_screen_pending_request'),
        value: (stats.ibPendingRequests ?? 0).toString(),
        onTap:
            widget.onNavigateToTab != null && !isTraditional
                ? () => widget.onNavigateToTab!(3)
                : null,
      ),
    ];
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    VoidCallback? onTap,
    bool highlight = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Ink(
          decoration: BoxDecoration(
            color: highlight ? AppColors.cardBackGround : AppColors.whiteColor,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.w, 8.h, 6.w, 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textGrey,
                    height: 1.15,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Padding(
                        padding: EdgeInsets.only(left: 2.w, bottom: 1.h),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16.sp,
                          color: AppColors.textGrey.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;
  const BannerCarousel({super.key, required this.banners});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _stopAutoPlay();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_pageController.hasClients) {
          final nextPage = (_currentPage + 1) % widget.banners.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _stopAutoPlay() {
    _timer?.cancel();
  }

  Future<void> _handleBannerTap(BannerItem banner) async {
    final clickUrl = banner.clickUrl;
    if (clickUrl != null && clickUrl.trim().isNotEmpty) {
      final uri = Uri.parse(clickUrl.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 130.h,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              final imageUrl = banner.imageUrl ?? '';

              return GestureDetector(
                onTap: () => _handleBannerTap(banner),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.cardBackGround,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image_outlined, color: AppColors.textGrey, size: 36.sp),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.cardBackGround,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator.adaptive(),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (index) {
              final isSelected = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                height: 6.h,
                width: isSelected ? 16.w : 6.w,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.textGrey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3.r),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
