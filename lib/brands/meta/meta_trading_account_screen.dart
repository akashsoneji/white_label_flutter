import 'package:flutter/material.dart';

import 'package:crm_app/screens/home/dashboard_screen.dart';
import 'meta_theme.dart';

/// Wraps the shared [DashboardScreen]
/// plus button) is rendered by [DashboardScreen] itself, so this wrapper
/// deliberately adds no AppBar to avoid a double-header.
///
/// [onNavigateToTab] is forwarded to [DashboardScreen] so that tapping
/// "Trade" on an account card still switches the bottom-nav tab.
class MetaTradingAccountScreen extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const MetaTradingAccountScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    // DashboardScreen renders its own Meta-themed AppBar (wallet + plus
    // button) so we deliberately avoid adding a second AppBar here.
    return Scaffold(
      backgroundColor: MetaTheme.bg(context),
      body: DashboardScreen(onNavigateToTab: onNavigateToTab),
    );
  }
}