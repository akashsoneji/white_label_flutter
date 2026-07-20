import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/home/trading_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/screens/ib/presentation/pages/my_structure_screen.dart';

class IBMoreScreen extends StatefulWidget {
  const IBMoreScreen({super.key});

  @override
  State<IBMoreScreen> createState() => _IBMoreScreenState();
}

class _IBMoreScreenState extends State<IBMoreScreen> {
  late IBController ibController;

  @override
  void initState() {
    super.initState();
    ibController = Get.find<IBController>();
    _loadMoreData();
  }

  Future<void> _loadMoreData() async {
    await Future.wait([ibController.getIBStructure()]);
  }

  Future<void> _onRefresh() async {
    await _loadMoreData();
  }

  void _navigateToMyStructure() {
    Get.to(() => const MyStructureScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
         leading: IconButton(
          icon: SvgPicture.asset("assets/svg/ib_dashboard/home.svg", colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn)),
          onPressed: () => Get.offAllNamed(AppPages.TRADING),
        ),
        title: Text(
          'More',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        backgroundColor: AppColors.whiteColor,
        color: AppColors.primary,
        child: GetBuilder<IBController>(
          id: 'ib_more',
          builder: (controller) {
            if (controller.isLoading.value &&
                controller.ibStructureData.value == null) {
              return Center(
                child: CommonLoadingWidget(
                  message: 'Loading...',
                  size: 50.0,
                  color: AppColors.primary,
                ),
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                children: [
                  // Menu Items
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.whiteColor,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.border.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.home,
                          label: 'Home',
                          onTap: () {
                            // Navigate to dashboard/home
                                      Get.offAllNamed(AppPages.TRADING);

                          },
                          showTopBorder: false,
                        ),
                        _buildMenuItem(
                          icon: Icons.account_tree,
                          label: 'My Structure',
                          onTap: _navigateToMyStructure,
                          showTopBorder: true,
                        ),
                      ],
                    ),
                  ),

                  // Bottom padding for floating navigation bar (safe area + nav bar height + extra spacing)
                  SizedBox(height: 100.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showTopBorder = true,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: showTopBorder
                ? BorderSide(color: AppColors.border, width: 1)
                : BorderSide.none,
          ),
        ),
        child: SizedBox(
          height: 60.h,
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
            minVerticalPadding: 0,
            leading: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20.sp,
                color: AppColors.primary,
              ),
            ),
            title: Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_sharp,
              size: 12.sp,
              color: AppColors.icongrey,
            ),
            onTap: onTap,
            minLeadingWidth: 10,
            horizontalTitleGap: 12.w,
          ),
        ),
      ),
    );
  }
}
