import 'package:flutter/material.dart';

///
/// Keep this file presentation-only. All existing business logic/controllers
/// remain in the entry `DashboardScreen`.
class VantageDashboardLayout extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Color backgroundColor;
  final Future<void> Function() onRefresh;
  final Widget child;
  final bool dimmed;
  final Widget? loadingOverlay;

  const VantageDashboardLayout({
    super.key,
    required this.appBar,
    required this.backgroundColor,
    required this.onRefresh,
    required this.child,
    required this.dimmed,
    this.loadingOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: Stack(
          children: [
            AnimatedOpacity(
              opacity: dimmed ? 0.35 : 1.0,
              duration: const Duration(milliseconds: 260),
              child: child,
            ),
            if (loadingOverlay != null) loadingOverlay!,
          ],
        ),
      ),
    );
  }
}

