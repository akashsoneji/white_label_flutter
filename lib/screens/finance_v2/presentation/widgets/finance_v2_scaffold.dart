import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/app_back_button.dart';

/// Screen frame shared by every finance_v2 page: app bar with the app back
/// button, padded body and an optional call-to-action pinned to the bottom.
class FinanceV2Scaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottomCta;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const FinanceV2Scaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottomCta,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final background = AppColors.tradeBackground;
    final cta = bottomCta;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: background,
        leading: AppBackButton(onPressed: onBack),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
        actions: actions,
      ),
      // The CTA lives in the body column (not bottomNavigationBar) so it
      // rises with the keyboard and the scroll area shrinks accordingly.
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
                child: body,
              ),
            ),
            if (cta != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(16.w, 8.h, 16.w, 8.h),
                  child: cta,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
