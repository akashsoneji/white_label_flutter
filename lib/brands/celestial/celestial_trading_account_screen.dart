import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/screens/home/dashboard_screen.dart';
import 'celestial_theme.dart';

/// Celestial-only "Trading Account" screen.
///
/// Wraps the shared [DashboardScreen] (used by Vantage / Pipze bottom-nav)
/// inside a Celestial-styled scaffold with a back-arrow app bar.
///
/// [onNavigateToTab] is forwarded to [DashboardScreen] so that tapping
/// "Trade" on an account card still switches the bottom-nav tab.
class CelestialTradingAccountScreen extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const CelestialTradingAccountScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CelTheme.bg(context),
      appBar: AppBar(
        backgroundColor: CelTheme.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: CelTheme.mainText(context), size: 20.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Trading Account',
          style: TextStyle(
            color: CelTheme.mainText(context),
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      // DashboardScreen is self-contained — it puts its own DashboardController
      // and handles WebSocket + API calls internally.
      body: DashboardScreen(onNavigateToTab: onNavigateToTab),
    );
  }
}
