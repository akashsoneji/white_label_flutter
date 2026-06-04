import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/routes/app_pages.dart';

class GlobalDrawer extends StatelessWidget {
  const GlobalDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final languageService = Get.find<LanguageService>();

    return Obx(() {
      return Drawer(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16.w, 60.h, 16.w, 20.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30.r,
                    backgroundColor: AppColors.whiteColor,
                    child: Icon(
                      Icons.person,
                      size: 30.h,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    languageService.tr('Welcome User'),
                    style: TextStyle(
                      color: AppColors.whiteColor,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    languageService.tr('trading_platform'),
                    style: TextStyle(
                      color: AppColors.whiteColor.withOpacity(0.8),
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                children: [
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet,
                    title: languageService.tr('account_management_title'),
                    onTap: () {
                      Get.back(closeOverlays: true);
                      Get.toNamed(AppPages.ACCOUNT_MANAGEMENT);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.language,
                    title: languageService.tr('language_selector_title'),
                    onTap: () {
                      Get.back(closeOverlays: true);
                      Get.toNamed(AppPages.LANGUAGE_SELECTOR);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.notifications,
                    title: languageService.tr('notifications'),
                    onTap: () {
                      Get.back(closeOverlays: true);
                      if (Get.isRegistered<AppNotificationController>()) {
                        Get.find<AppNotificationController>().showInfo(
                          message: 'Notifications coming soon',
                          title: 'Info',
                        );
                      }
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info,
                    title: languageService.tr('about'),
                    onTap: () {
                      Get.back(closeOverlays: true);
                      if (Get.isRegistered<AppNotificationController>()) {
                        Get.find<AppNotificationController>().showInfo(
                          message: 'About section coming soon',
                          title: 'Info',
                        );
                      }
                    },
                  ),
                  // _buildDrawerItem(
                  //   icon: Icons.bug_report,
                  //   title: languageService.tr('toast_demo'),
                  //   onTap: () {
                  //     Get.back(closeOverlays: true);
                  //     Get.toNamed(AppPages.TOAST_DEMO);
                  //   },
                  // ),
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: languageService.tr('logout'),
                    iconColor: AppColors.red,
                    textColor: AppColors.red,
                    onTap: () {
                      Get.back(closeOverlays: true);
                      _showLogoutDialog(authController, languageService);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textGrey),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          color: textColor ?? AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(
    AuthController authController,
    LanguageService languageService,
  ) {
    Get.dialog(
      AlertDialog(
        title: Text(languageService.tr('logout_confirm_title')),
        content: Text(languageService.tr('logout_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Get.back(closeOverlays: true),
            child: Text(languageService.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(closeOverlays: true);
              authController.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(
              languageService.tr('logout'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
