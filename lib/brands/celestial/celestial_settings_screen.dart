import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/services/theme_service.dart';
import 'celestial_theme.dart';

/// Settings screen — real profile, dark-mode toggle, nav to existing routes.
class CelestialSettingsScreen extends StatefulWidget {
  const CelestialSettingsScreen({super.key});

  @override
  State<CelestialSettingsScreen> createState() =>
      _CelestialSettingsScreenState();
}

class _CelestialSettingsScreenState extends State<CelestialSettingsScreen> {
  late bool _darkMode;

  @override
  void initState() {
    super.initState();
    _darkMode = Get.isDarkMode;
  }

  void _toggleTheme(bool v) async {
    setState(() => _darkMode = v);
    await Get.find<ThemeService>().setThemeMode(
        v ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final name  = auth.userFullName ?? 'User';
    final email = auth.userEmail ?? '';

    return Scaffold(
      backgroundColor: CelTheme.bg(context),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          children: [
            // ── Profile card ─────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundColor: CelTheme.buy(context).withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TextStyle(
                          color: CelTheme.buy(context),
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                color: CelTheme.mainText(context),
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800)),
                        if (email.isNotEmpty)
                          Text(email,
                              style: TextStyle(
                                  color: CelTheme.subText(context),
                                  fontSize: 12.sp)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.toNamed(Routes.SETTING),
                    child: Icon(Icons.edit_outlined,
                        color: CelTheme.buy(context), size: 20.sp),
                  ),
                ],
              ),
            ),

            // ── Appearance ───────────────────────────────────────────────────
            _section(context, 'Appearance'),
            _tile(
              context,
              icon: _darkMode ? Icons.dark_mode : Icons.light_mode,
              title: 'Dark Mode',
              trailing: Switch.adaptive(
                value: _darkMode,
                activeColor: CelTheme.buy(context),
                onChanged: _toggleTheme,
              ),
            ),

            // ── Account ──────────────────────────────────────────────────────
            _section(context, 'Account'),
            _tile(context,
                icon: Icons.person_outline,
                title: 'Personal Information',
                onTap: () => Get.toNamed(Routes.SETTING)),
            _tile(context,
                icon: Icons.verified_user_outlined,
                title: 'KYC Verification',
                onTap: () => Get.toNamed(Routes.KYC_VERIFICATION)),
            _tile(context,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Deposit',
                onTap: () => Get.toNamed(Routes.DEPOSIT)),
            _tile(context,
                icon: Icons.upload_outlined,
                title: 'Withdrawal',
                onTap: () => Get.toNamed(Routes.WITHDRAWAL)),
            _tile(context,
                icon: Icons.history,
                title: 'Transaction History',
                onTap: () => Get.toNamed(Routes.TRANSACTION_HISTORY)),

            // ── App ──────────────────────────────────────────────────────────
            _section(context, 'App'),
            _tile(context,
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () {}),
            _tile(context,
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () => Get.toNamed('/change-password')),
            _tile(context,
                icon: Icons.security,
                title: 'Two-Factor Authentication',
                onTap: () => Get.toNamed(Routes.TWO_FACTOR_AUTH)),
            _tile(context,
                icon: Icons.language,
                title: 'Language',
                onTap: () => Get.toNamed(Routes.LANGUAGE_SELECTOR)),

            // ── Support ───────────────────────────────────────────────────────
            _section(context, 'Support'),
            _tile(context,
                icon: Icons.support_agent,
                title: 'Contact Us',
                onTap: () => Get.toNamed(Routes.CHAT_WITH_US)),
            _tile(context,
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () => Get.toNamed(Routes.SUPPORT)),

            SizedBox(height: 16.h),

            // ── Logout ────────────────────────────────────────────────────────
            Container(
              margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: CelTheme.card(context),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: CelTheme.divider(context), width: 0.5),
              ),
              child: ListTile(
                leading: Icon(Icons.logout, color: CelTheme.sell(context), size: 22.sp),
                title: Text('Logout',
                    style: TextStyle(
                        color: CelTheme.sell(context),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700)),
                onTap: () => _confirmLogout(context, auth),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext c, AuthController auth) {
    showDialog(
      context: c,
      builder: (_) => AlertDialog(
        backgroundColor: CelTheme.card(c),
        title: Text('Logout',
            style: TextStyle(color: CelTheme.mainText(c), fontSize: 16.sp)),
        content: Text('Are you sure you want to logout?',
            style: TextStyle(color: CelTheme.subText(c), fontSize: 13.sp)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Cancel',
                  style: TextStyle(color: CelTheme.subText(c)))),
          TextButton(
              onPressed: () {
                Navigator.pop(c);
                auth.logout();
              },
              child: Text('Logout',
                  style: TextStyle(
                      color: CelTheme.sell(c),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _section(BuildContext c, String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: CelTheme.subText(c),
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6)),
    );
  }

  Widget _tile(BuildContext c,
      {required IconData icon,
      required String title,
      Widget? trailing,
      VoidCallback? onTap}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: CelTheme.card(c),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: CelTheme.divider(c), width: 0.5),
      ),
      child: ListTile(
        leading: Icon(icon, color: CelTheme.buy(c), size: 22.sp),
        title: Text(title,
            style: TextStyle(
                color: CelTheme.mainText(c),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600)),
        trailing: trailing ??
            Icon(Icons.chevron_right, color: CelTheme.subText(c), size: 20.sp),
        onTap: trailing != null ? null : onTap,
      ),
    );
  }
}
