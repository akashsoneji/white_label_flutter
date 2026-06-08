import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/vantage/vantage_app_bar.dart';

class VantageChartLayout extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Color backgroundColor;
  final Color primaryColor;
  final int chartFlex;
  final Widget chart;
  final Widget controlDock;
  final Widget? overlay;
  final List<Widget>? actions;

  VantageChartLayout({
    super.key,
    this.title,
    this.titleWidget,
    required this.backgroundColor,
    required this.primaryColor,
    required this.chartFlex,
    required this.chart,
    required this.controlDock,
    this.overlay,
    this.actions,
  }) : assert(
         titleWidget != null ||
             (title != null && title.isNotEmpty),
         'Provide titleWidget or title',
       );

  @override
  Widget build(BuildContext context) {
    final appBarTitle =
        titleWidget ??
        Text(
          title!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColor,
      appBar: VantageAppBar(
        title: appBarTitle,
        backgroundColor: backgroundColor,
        actions: actions,
      ),
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
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18.r),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.10),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18.r),
                                child: chart,
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.12),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20.r),
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

