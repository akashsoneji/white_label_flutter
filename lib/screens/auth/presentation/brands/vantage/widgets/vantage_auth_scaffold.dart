import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'vantage_auth_theme.dart';

class VantageAuthScaffold extends StatelessWidget {
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? bottom;

  const VantageAuthScaffold({
    super.key,
    required this.child,
    this.showBack = true,
    this.onBack,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: VantageAuthTheme.pillInputDecorationTheme(),
      ),
      child: Scaffold(
      backgroundColor: VantageAuthTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.vertical,
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: 12.h),
                          if (showBack)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppBackButton(
                                onPressed:
                                    onBack ??
                                    () => Navigator.of(context).maybePop(),
                              ),
                            )
                          else
                            SizedBox(height: 44.h),
                          SizedBox(height: 18.h),
                          _CardContainer(child: child),
                          SizedBox(height: 22.h),
                        ],
                      ),
                    ),
                  ),
                ),
                if (bottom != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                    child: bottom!,
                  ),
              ],
            ),
            Positioned(
              left: 24.w,
              top: 56.h,
              child: _LogoBubble(),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 56.h, 20.w, 22.h),
      decoration: BoxDecoration(
        color: VantageAuthTheme.card,
        borderRadius: const BorderRadius.all(VantageAuthTheme.cardRadius),
      ),
      child: child,
    );
  }
}

class _LogoBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72.w,
      width: 72.w,
      decoration: BoxDecoration(
        color: VantageAuthTheme.primary.withAlpha(40),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(14.w),
      child: ClipOval(
        child: BrandLogo(
          source: FlavorConfig.effectiveLogo,
          height: 44.w,
          width: 44.w,
        ),
      ),
    );
  }
}

