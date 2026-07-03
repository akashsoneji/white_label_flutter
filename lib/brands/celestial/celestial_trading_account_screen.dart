import 'package:flutter/material.dart';

import 'package:crm_app/screens/home/dashboard_screen.dart';
import 'celestial_theme.dart';

/// Celestial-only "Trading Account" screen.
///
/// Wraps the shared [DashboardScreen] (used by Vantage / Pipze bottom-nav)
/// inside a Celestial-themed scaffold. The Celestial AppBar (title +
/// wallet pill + plus button) is rendered by [DashboardScreen] itself, so
/// this wrapper deliberately adds no AppBar to avoid a double-header.
///
/// [onNavigateToTab] is forwarded to [DashboardScreen] so that tapping
/// "Trade" on an account card still switches the bottom-nav tab.
class CelestialTradingAccountScreen extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const CelestialTradingAccountScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    // DashboardScreen renders its own Celestial-themed AppBar (wallet + plus
    // button) so we deliberately avoid adding a second AppBar here — that
    // was previously producing a double-appbar stack on Celestial.
    return Scaffold(
      backgroundColor: CelTheme.bg(context),
      body: DashboardScreen(onNavigateToTab: onNavigateToTab),
    );
  }
}
