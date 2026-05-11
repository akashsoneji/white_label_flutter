import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/vantage/vantage_app_bar.dart';

class VantageChartLayout extends StatelessWidget {
  final String title;
  final Color backgroundColor;
  final Color primaryColor;
  final int chartFlex;
  final Widget chart;
  final Widget controlDock;
  final Widget? overlay;

  const VantageChartLayout({
    super.key,
    required this.title,
    required this.backgroundColor,
    required this.primaryColor,
    required this.chartFlex,
    required this.chart,
    required this.controlDock,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColor,
      appBar: VantageAppBar.text(title, backgroundColor: backgroundColor),
      body: SafeArea(
        child: Stack(
          children: [
            ColoredBox(
              color: backgroundColor,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Column(
                        children: [
                          Expanded(
                            flex: chartFlex,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18.r),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: backgroundColor,
                                  border: Border.all(
                                    color: primaryColor.withOpacity(0.10),
                                  ),
                                ),
                                child: chart,
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20.r),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.12),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  10.w,
                                  8.h,
                                  10.w,
                                  6.h,
                                ),
                                child: controlDock,
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}

