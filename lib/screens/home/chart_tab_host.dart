import 'package:flutter/material.dart';

///
/// This widget is intentionally inert: the parent (`TradingMainScreen`)
/// drives the chart push directly from `_onTabChanged` when the user
/// lands on index 1. Hosting the push in the widget (via an `isSelected`
/// prop) is unreliable because `_screens` is built once in `initState()`
/// and the prop is captured at that moment — it doesn't update when the
/// user taps the Chart tab from another tab.
///
/// Keeping this widget as a transparent placeholder lets the PageView
/// have a stable child at index 1 while the actual chart route lives on
/// top of the navigator stack (so the bottom nav is naturally hidden).
class ChartTabHost extends StatelessWidget {
  const ChartTabHost({super.key});

  @override
  Widget build(BuildContext context) {
    // Transparent — never actually visible because the chart route is
    // pushed on top.
    return const ColoredBox(color: Colors.transparent);
  }
}