import 'package:flutter/material.dart';

///
/// Entry `MoreScreen` keeps controllers and navigation. This widget is only
/// responsible for presentation wrappers.
class VantageMoreLayout extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Color backgroundColor;
  final Widget child;

  const VantageMoreLayout({
    super.key,
    this.appBar,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: child,
    );
  }
}

