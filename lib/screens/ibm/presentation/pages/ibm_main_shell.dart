import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_manager_portal_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_promotion_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_clients_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_wallet_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_links_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_marketing_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_settings_screen.dart';
import 'package:crm_app/services/language_service.dart';

class IbmMainShell extends StatelessWidget {
  const IbmMainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final IbmController controller = Get.put(IbmController());
    final languageService = Get.find<LanguageService>();

    final List<Widget> pages = const [
      IbmManagerPortalScreen(),
      IbmPromotionScreen(),
      IbmClientsScreen(),
      IbmWalletScreen(),
      IbmLinksScreen(),
      IbmMarketingScreen(),
      IbmSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      drawer: _buildIbmDrawer(context, controller, languageService),
      body: Obx(
        () => IndexedStack(
          index: controller.currentTabIndex.value.clamp(0, pages.length - 1),
          children: pages,
        ),
      ),
      bottomNavigationBar: Obx(() {
        final currentIdx = controller.currentTabIndex.value.clamp(
          0,
          pages.length - 1,
        );
        final pendingRequests = controller.requestsData['waiting_count'] ?? 0;

        return Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: Container(
            decoration: BoxDecoration(
              color:
                  AppColors.isDarkMode
                      ? AppColors.pureBlack
                      : AppColors.whiteColor,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 0.8),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: currentIdx,
              onTap: controller.changeTab,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textGrey,
              backgroundColor: AppColors.card,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              iconSize: 18.w,
              selectedFontSize: 8.5.sp,
              unselectedFontSize: 8.5.sp,
              selectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 8.5.sp,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 8.5.sp,
              ),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.dashboard_outlined),
                  activeIcon: const Icon(Icons.dashboard),
                  label: languageService.tr('Dashboard'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.campaign_outlined),
                  activeIcon: const Icon(Icons.campaign),
                  label: languageService.tr('Promotion'),
                ),
                BottomNavigationBarItem(
                  icon:
                      pendingRequests > 0
                          ? Badge(
                            label: Text('$pendingRequests'),
                            child: const Icon(Icons.people_outline),
                          )
                          : const Icon(Icons.people_outline),
                  activeIcon: const Icon(Icons.people),
                  label: languageService.tr('Network'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: const Icon(Icons.account_balance_wallet),
                  label: languageService.tr('Commission'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.link_outlined),
                  activeIcon: const Icon(Icons.link),
                  label: languageService.tr('Links'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.image_outlined),
                  activeIcon: const Icon(Icons.image),
                  label: languageService.tr('Marketing'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.tune_outlined),
                  activeIcon: const Icon(Icons.tune),
                  label: languageService.tr('Settings'),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildIbmDrawer(
    BuildContext context,
    IbmController controller,
    LanguageService languageService,
  ) {
    return Drawer(
      backgroundColor:
          AppColors.isDarkMode ? AppColors.card : AppColors.whiteColor,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5F259E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFF5F259E),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IB Manager Portal',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Partner Workspace',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SizedBox(height: 10.h),

            // 7 Navigation Items matching Screenshot 1
            Expanded(
              child: Obx(() {
                final currentIdx = controller.currentTabIndex.value;
                return ListView(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.dashboard_outlined,
                      title: 'Dashboard',
                      isSelected: currentIdx == 0,
                      hasArrow: false,
                      onTap: () {
                        Get.back();
                        controller.changeTab(0);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.campaign_outlined,
                      title: 'Promotion',
                      isSelected: currentIdx == 1,
                      hasArrow: true,
                      onTap: () {
                        Get.back();
                        controller.changeTab(1);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.person_outline,
                      title: 'Clients & Network',
                      isSelected: currentIdx == 2,
                      hasArrow: true,
                      onTap: () {
                        Get.back();
                        controller.changeTab(2);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Commission',
                      isSelected: currentIdx == 3,
                      hasArrow: true,
                      onTap: () {
                        Get.back();
                        controller.changeTab(3);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.link_outlined,
                      title: 'Referral Links',
                      isSelected: currentIdx == 4,
                      hasArrow: false,
                      onTap: () {
                        Get.back();
                        controller.changeTab(4);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.image_outlined,
                      title: 'Marketing Material',
                      isSelected: currentIdx == 5,
                      hasArrow: false,
                      onTap: () {
                        Get.back();
                        controller.changeTab(5);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.tune_outlined,
                      title: 'Settings',
                      isSelected: currentIdx == 6,
                      hasArrow: false,
                      onTap: () {
                        Get.back();
                        controller.changeTab(6);
                      },
                    ),
                  ],
                );
              }),
            ),

            // Bottom Switch back button
            Padding(
              padding: EdgeInsets.all(16.w),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                tileColor:
                    AppColors.isDarkMode
                        ? Colors.grey[900]
                        : const Color(0xFFF7F8FA),
                leading: const Icon(Icons.arrow_back, color: Color(0xFF5F259E)),
                title: const Text(
                  'Back to Client Portal',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                onTap: () {
                  Get.back();
                  Get.back();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required bool hasArrow,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color:
            isSelected
                ? const Color(0xFF5F259E).withOpacity(0.08)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF5F259E) : AppColors.textPrimary,
          size: 20.w,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF5F259E) : AppColors.textPrimary,
          ),
        ),
        trailing:
            hasArrow
                ? Icon(
                  Icons.chevron_right,
                  size: 16.w,
                  color: AppColors.textGrey,
                )
                : null,
        onTap: onTap,
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      ),
    );
  }
}
