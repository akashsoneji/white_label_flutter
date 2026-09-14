import 'package:flutter/material.dart';
import 'package:crm_app/services/language_service.dart';
import '../../../../../constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../constants/color.dart';
import '../../../../../controllers/pmam/pmam_controller.dart';

/// Centered dialog that mirrors the web "Edit plan" modal.
///
/// When the plan has active investors the API only allows editing
/// `plan_name`, `strategy_description`, and `risk_information`.
class EditPlanBottomSheet extends StatefulWidget {
  const EditPlanBottomSheet({super.key, required this.plan});

  final Map<String, dynamic> plan;

  static Future<bool?> show(
    BuildContext context,
    Map<String, dynamic> plan,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => EditPlanBottomSheet(plan: plan),
    );
  }

  @override
  State<EditPlanBottomSheet> createState() => _EditPlanBottomSheetState();
}

class _EditPlanBottomSheetState extends State<EditPlanBottomSheet> {
  final PmamController _c = Get.find<PmamController>();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _strategy;
  late final TextEditingController _risk;
  late final TextEditingController _commission;
  late final TextEditingController _minInvestment;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name = TextEditingController(text: (p['plan_name'] ?? '').toString());
    _strategy = TextEditingController(
      text: (p['strategy_description'] ?? '').toString(),
    );
    _risk = TextEditingController(
      text: (p['risk_information'] ?? '').toString(),
    );
    _commission = TextEditingController(
      text: (p['commission_percentage'] ?? '').toString(),
    );
    _minInvestment = TextEditingController(
      text: (p['minimum_investment'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _strategy.dispose();
    _risk.dispose();
    _commission.dispose();
    _minInvestment.dispose();
    super.dispose();
  }

  bool get _hasActiveInvestors {
    final list = widget.plan['active_live_investors'];
    final fromList = list is List && list.isNotEmpty;
    final fromCount =
        (int.tryParse('${widget.plan['active_investors'] ?? 0}') ?? 0) > 0;
    return fromList || fromCount;
  }

  int get _planId => widget.plan['id'] is int
      ? widget.plan['id'] as int
      : int.tryParse('${widget.plan['id']}') ?? 0;

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_planId <= 0) return;

    final body = <String, dynamic>{
      'plan_name': _name.text.trim(),
      'strategy_description': _strategy.text.trim(),
      'risk_information': _risk.text.trim(),
    };

    if (!_hasActiveInvestors) {
      final originalComm =
          double.tryParse('${widget.plan['commission_percentage'] ?? ''}') ??
              double.nan;
      final newComm = double.tryParse(_commission.text.trim());
      if (newComm != null && newComm != originalComm) {
        body['commission_percentage'] = newComm;
      }

      final originalMin =
          double.tryParse('${widget.plan['minimum_investment'] ?? ''}') ??
              double.nan;
      final newMin = double.tryParse(_minInvestment.text.trim());
      if (newMin != null && newMin != originalMin) {
        body['minimum_investment'] = newMin;
      }
    }

    setState(() => _saving = true);
    final result = await _c.updateManagerPlan(_planId, body);
    if (!mounted) return;
    setState(() => _saving = false);

    Get.snackbar(
      result.ok
          ? TranslationUtils.tr('general_success')
          : TranslationUtils.tr('general_error'),
      result.message,
      backgroundColor: result.ok
          ? AppColors.green.withValues(alpha: 0.95)
          : AppColors.error.withValues(alpha: 0.95),
      colorText: AppColors.onColoredBackground,
      snackPosition: SnackPosition.BOTTOM,
      margin: EdgeInsets.all(12.w),
      borderRadius: 10,
      duration: const Duration(seconds: 3),
    );

    if (result.ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      titlePadding: EdgeInsetsDirectional.fromSTEB(20.w, 16.h, 8.w, 8.h),
      contentPadding: EdgeInsetsDirectional.fromSTEB(20.w, 8.h, 20.w, 0),
      actionsPadding: EdgeInsetsDirectional.fromSTEB(12.w, 8.h, 12.w, 12.h),
      title: Row(
        children: [
          Expanded(
            child: Text(
              TranslationUtils.tr('edit_plan_bottom_sheet_edit_plan'),
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.primary,
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.textGrey, size: 22.sp),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasActiveInvestors) ...[
                  _buildLockBanner(),
                  SizedBox(height: 16.h),
                ],
                _buildLabel(TranslationUtils.tr('pmam_edit_plan_plan_name'),
                    required: true),
                SizedBox(height: 6.h),
                _buildField(
                  controller: _name,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return TranslationUtils.tr(
                          'pmam_edit_plan_plan_name_is_required');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 14.h),
                _buildLabel(TranslationUtils.tr(
                    'master_plan_detail_screen_strategy_description')),
                SizedBox(height: 6.h),
                _buildField(
                  controller: _strategy,
                  maxLines: 3,
                  minLines: 3,
                ),
                SizedBox(height: 14.h),
                _buildLabel(TranslationUtils.tr(
                    'copy_trading_create_plan_risk_information')),
                SizedBox(height: 6.h),
                _buildField(
                  controller: _risk,
                  maxLines: 3,
                  minLines: 3,
                ),
                if (!_hasActiveInvestors) ...[
                  SizedBox(height: 14.h),
                  _buildLabel(
                      TranslationUtils.tr('pmam_edit_plan_commission_percent')),
                  SizedBox(height: 6.h),
                  _buildField(
                    controller: _commission,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    suffix: '%',
                  ),
                  SizedBox(height: 14.h),
                  _buildLabel(TranslationUtils.tr(
                      'trader_details_screen_minimum_investment')),
                  SizedBox(height: 6.h),
                  _buildField(
                    controller: _minInvestment,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefix: '\$',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
              side: BorderSide(color: AppColors.border),
            ),
            foregroundColor: AppColors.textPrimary,
          ),
          child: Text(
            TranslationUtils.tr('general_cancel'),
            style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.onColoredBackground,
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            elevation: 0,
          ),
          child: _saving
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  TranslationUtils.tr('edit_plan_bottom_sheet_save_changes'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLockBanner() => Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18.sp, color: AppColors.error),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                TranslationUtils.tr('pmam_edit_plan_active_investors_lock'),
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.error,
                  fontSize: 12.sp,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildLabel(String text, {bool required = false}) => Row(
        children: [
          Text(
            text,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (required) ...[
            SizedBox(width: 4.w),
            Text(
              '*',
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.error,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      );

  Widget _buildField({
    required TextEditingController controller,
    int maxLines = 1,
    int? minLines,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? prefix,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary, fontSize: 14.sp),
      decoration: InputDecoration(
        isDense: true,
        prefixText: prefix,
        suffixText: suffix,
        prefixStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 14.sp),
        suffixStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 14.sp),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}
