import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:crm_app/widgets/labeled_app_text_field.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_hub_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'explore_masters_screen.dart';
import 'master_dashboard_screen.dart';
import 'my_copies_screen.dart';
import 'my_investments_screen.dart';

class CopyTradingHubScreen extends StatelessWidget {
  const CopyTradingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CopyTradingHubController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Copy Trading',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 18.sp,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: AppSvgBackButton(
          onPressed: () => AppSvgBackButton.popRoute(context),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refreshAll(showLoading: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: Obx(() {
            final status = controller.masterStatus.value;
            final code = controller.masterCode.value;
            final hasSubs = controller.hasActiveCopySubscription.value;

            final masterTile = switch (status) {
              CopyTradingMasterApplicationStatus.pending => _HubMenuItem(
                  icon: Icons.access_time,
                  label: 'Pending Review',
                  subtitle: code.isEmpty ? null : 'Code: $code',
                  trailing: _StatusPill(text: 'Pending', color: AppColors.warning),
                  onTap: () => Get.to(() => _PendingReviewScreen(masterCode: code)),
                ),
              CopyTradingMasterApplicationStatus.approved => _HubMenuItem(
                  icon: Icons.verified,
                  label: 'Master Dashboard',
                  subtitle: code.isEmpty ? null : 'Code: $code',
                  trailing: _StatusPill(text: 'Active', color: AppColors.green),
                  onTap: () => Get.to(() => MasterDashboardScreen(masterCode: code)),
                ),
              CopyTradingMasterApplicationStatus.rejected => _HubMenuItem(
                  icon: Icons.error_outline,
                  label: 'Become a Master',
                  subtitle: 'Application rejected — apply again',
                  trailing: _StatusPill(text: 'Rejected', color: AppColors.error),
                  onTap: () => Get.to(() => const _BecomeMasterScreen()),
                ),
              CopyTradingMasterApplicationStatus.unknown => _HubMenuItem(
                  icon: Icons.help_outline,
                  label: 'Become a Master',
                  subtitle: 'Status unknown — try refresh',
                  onTap: () => Get.to(() => const _BecomeMasterScreen()),
                ),
              _ => _HubMenuItem(
                  icon: Icons.tune,
                  label: 'Become a Master',
                  onTap: () => Get.to(() => const _BecomeMasterScreen()),
                ),
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.errorMessage.value.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      controller.errorMessage.value,
                      style: AppTextStyles.bodyText.copyWith(color: AppColors.errorText, fontSize: 12.sp),
                    ),
                  ),

                _SectionCard(
                  children: [
                    _HubMenuItem(
                      icon: Icons.explore_outlined,
                      label: 'Explore Masters',
                      onTap: () => Get.to(() => const ExploreMastersScreen()),
                    ),
                    _divider(),
                    _HubMenuItem(
                      icon: Icons.copy_all_outlined,
                      label: status == CopyTradingMasterApplicationStatus.approved ? 'My Copies' : 'My Investments',
                      trailing:
                          hasSubs
                              ? _StatusPill(text: 'Active', color: AppColors.green)
                              : _StatusPill(text: 'None', color: AppColors.textGrey),
                      onTap: () {
                        if (status == CopyTradingMasterApplicationStatus.approved) {
                          Get.to(() => const MyCopiesScreen());
                        } else {
                          Get.to(() => const MyInvestmentsScreen());
                        }
                      },
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                _SectionCard(children: [masterTile]),

                if (controller.isLoading.value) ...[
                  SizedBox(height: 14.h),
                  Center(
                    child: SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _divider() => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Divider(height: 1, thickness: 0.5, color: AppColors.icongrey.withValues(alpha: 0.14)),
      );
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.icongrey.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _HubMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _HubMenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 20.r, color: AppColors.primary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // if (subtitle != null) ...[
                  //   SizedBox(height: 2.h),
                  //   Text(
                  //     subtitle!,
                  //     style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey),
                  //   ),
                  // ],
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              SizedBox(width: 10.w),
            ],
            Icon(Icons.arrow_forward_ios, size: 14.r, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyText.copyWith(fontSize: 11.sp, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _PendingReviewScreen extends StatelessWidget {
  final String masterCode;
  const _PendingReviewScreen({required this.masterCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        title: Text('Pending Review'),
      ),
      body: Center(
        child: Container(
          margin: EdgeInsets.all(16.r),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time, size: 42.r, color: AppColors.warning),
              SizedBox(height: 10.h),
              Text(
                'Your master application is under review.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              if (masterCode.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text('Code: $masterCode', style: AppTextStyles.bodyText.copyWith(fontSize: 12.sp, color: AppColors.textGrey)),
              ],
              SizedBox(height: 14.h),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor:
                      AppColors.primary.computeLuminance() > 0.5
                          ? AppColors.textPrimaryLight
                          : AppColors.onColoredBackground,
                ),
                child: Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BecomeMasterScreen extends StatefulWidget {
  const _BecomeMasterScreen();

  @override
  State<_BecomeMasterScreen> createState() => _BecomeMasterScreenState();
}

class _BecomeMasterScreenState extends State<_BecomeMasterScreen> {
  final _nicknameCtrl = TextEditingController();
  final _strategyCtrl = TextEditingController();
  final _riskInfoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final hub = Get.find<CopyTradingHubController>();
    hub.resetMasterApplyForm();
    _nicknameCtrl.clear();
    _strategyCtrl.clear();
    _riskInfoCtrl.clear();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _strategyCtrl.dispose();
    _riskInfoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hub = Get.find<CopyTradingHubController>();

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
         leading: AppSvgBackButton(
          onPressed: () => AppSvgBackButton.popRoute(context),
        ),
        title: Text('Become a Master', style: AppTextStyles.screenTitle),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.r),
        child: Obx(() {
          hub.masterApplyNicknameDraft.value;
          hub.masterApplyStrategyDraft.value;
          hub.masterApplyRiskInfoDraft.value;
          hub.masterApplyTermsAccepted.value;
          hub.isLoading.value;

          final canSubmit = hub.canSubmitMasterApply;
          final applying = hub.isLoading.value;
          final applyBtnFg =
              AppColors.primary.computeLuminance() > 0.5
                  ? AppColors.textPrimaryLight
                  : AppColors.onColoredBackground;
          final isDark = AppColors.isDarkMode;
          final checkBorder = isDark ? AppColors.textPrimaryDark : AppColors.primary;
          final checkFill = isDark ? AppColors.textPrimaryDark : AppColors.primary;
          final checkMark = isDark ? AppColors.textPrimaryLight : AppColors.onColoredBackground;

          return Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                LabeledAppTextField(
                  label: 'Nickname *',
                  controller: _nicknameCtrl,
                  keyboardType: TextInputType.text,
                  hintText: 'e.g. Alpha Trader',
                  onChanged: (s) => hub.masterApplyNicknameDraft.value = s,
                ),
                SizedBox(height: 16.h),
                LabeledAppTextField(
                  label: 'Strategy Description *',
                  controller: _strategyCtrl,
                  keyboardType: TextInputType.text,
                  hintText: 'e.g. Conservative gold scalping strategy',
                  onChanged: (s) => hub.masterApplyStrategyDraft.value = s,
                ),
                SizedBox(height: 16.h),
                LabeledAppTextField(
                  label: 'Risk Info *',
                  controller: _riskInfoCtrl,
                  keyboardType: TextInputType.text,
                  hintText: 'e.g. Drawdown can reach up to 15%.',
                  onChanged: (s) => hub.masterApplyRiskInfoDraft.value = s,
                ),
                SizedBox(height: 12.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 26.r,
                      height: 26.r,
                      child: Checkbox(
                        value: hub.masterApplyTermsAccepted.value,
                        side: BorderSide(color: checkBorder, width: 1.5),
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return checkFill;
                          }
                          return Colors.transparent;
                        }),
                        checkColor: checkMark,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) => hub.masterApplyTermsAccepted.value = v ?? false,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 4.w),
                      child: Text(
                        'I accept the Terms & Conditions',
                        style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: canSubmit && !applying
                        ? () async {
                            final nick = hub.masterApplyNicknameDraft.value.trim();
                            final strategy = hub.masterApplyStrategyDraft.value.trim();
                            final riskInfo = hub.masterApplyRiskInfoDraft.value.trim();
                            final res = await hub.applyForMaster(
                              nickname: nick,
                              termsAccepted: hub.masterApplyTermsAccepted.value,
                              strategy: strategy,
                              riskInfo: riskInfo,
                            );
                            if (res.success) {
                              Get.back();
                              CustomToastService.showSuccess(
                                title: 'Submitted',
                                message: res.message ?? 'Application submitted',
                                duration: const Duration(milliseconds: 2500),
                              );
                            } else {
                              CustomToastService.showError(
                                title: 'Failed',
                                message: res.message ?? hub.errorMessage.value,
                                duration: const Duration(milliseconds: 2500),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: applyBtnFg,
                      disabledBackgroundColor: AppColors.textGrey.withValues(alpha: 0.35),
                      disabledForegroundColor: applyBtnFg.withValues(alpha: 0.45),
                      padding: EdgeInsets.zero,
                      minimumSize: Size(double.infinity, 44.h),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: applying
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: applyBtnFg,
                            ),
                          )
                        : Text(
                            'Apply',
                            style: AppTextStyles.button.copyWith(color: applyBtnFg),
                          ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

