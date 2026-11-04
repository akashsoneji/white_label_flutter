import 'package:flutter/material.dart';
import 'package:crm_app/services/language_service.dart';
import '../../../../../constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../constants/color.dart';
import '../../../../../controllers/pmam/pmam_controller.dart';

/// Bottom sheet for the web "Edit plan" modal.
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
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hasActiveInvestors) ...[
                        _buildLockBanner(),
                        SizedBox(height: 12.h),
                      ],
                      _buildLabel(
                        TranslationUtils.tr('pmam_edit_plan_plan_name'),
                        required: true,
                      ),
                      _buildField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return TranslationUtils.tr(
                                'pmam_edit_plan_plan_name_is_required');
                          }
                          return null;
                        },
                      ),
                      if (!_hasActiveInvestors) ...[
                        SizedBox(height: 12.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildLabel(TranslationUtils.tr(
                                      'pmam_edit_plan_commission_percent')),
                                  _buildField(
                                    controller: _commission,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    suffix: '%',
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildLabel(TranslationUtils.tr(
                                      'trader_details_screen_minimum_investment')),
                                  _buildField(
                                    controller: _minInvestment,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    prefix: '\$ ',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 12.h),
                      _buildLabel(TranslationUtils.tr(
                          'trader_details_screen_strategy_description')),
                      _buildField(
                        controller: _strategy,
                        minLines: 2,
                        maxLines: 4,
                      ),
                      SizedBox(height: 12.h),
                      _buildLabel(TranslationUtils.tr(
                          'copy_trading_create_plan_risk_information')),
                      _buildField(
                        controller: _risk,
                        minLines: 2,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = (widget.plan['plan_name'] ?? '').toString();
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16.w, 8.h, 4.w, 8.h),
      child: Column(
        children: [
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationUtils.tr('edit_plan_bottom_sheet_edit_plan'),
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (name.isNotEmpty)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textGrey,
                          fontSize: 12.sp,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: TranslationUtils.tr('general_cancel'),
                icon: Icon(Icons.close, color: AppColors.textGrey, size: 20.sp),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _saving ? null : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(0, 42.h),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  TranslationUtils.tr('general_cancel'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.onColoredBackground,
                  minimumSize: Size(0, 42.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onColoredBackground,
                        ),
                      )
                    : Text(
                        TranslationUtils.tr(
                            'edit_plan_bottom_sheet_save_changes'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.sp,
                          color: AppColors.onColoredBackground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockBanner() => Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.warningText.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: AppColors.warningText.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 16.sp, color: AppColors.warningText),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                TranslationUtils.tr('pmam_edit_plan_active_investors_lock'),
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.warningText,
                  fontSize: 12.sp,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  /// Same size and weight for every label so the form reads evenly.
  Widget _buildLabel(String text, {bool required = false}) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Text.rich(
          TextSpan(
            text: text,
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textGrey,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _buildField({
    required TextEditingController controller,
    int maxLines = 1,
    int? minLines,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    String? prefix,
    String? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: AppTextStyles.bodyText.copyWith(
        color: AppColors.textPrimary,
        fontSize: 14.sp,
      ),
      decoration: InputDecoration(
        isDense: true,
        prefixText: prefix,
        suffixText: suffix,
        prefixStyle: AppTextStyles.bodyText.copyWith(
          color: AppColors.textGrey,
          fontSize: 14.sp,
        ),
        suffixStyle: AppTextStyles.bodyText.copyWith(
          color: AppColors.textGrey,
          fontSize: 14.sp,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
        filled: true,
        fillColor: AppColors.tradeBackgroundCenterColor,
        border: border(AppColors.border.withValues(alpha: 0.5)),
        enabledBorder: border(AppColors.border.withValues(alpha: 0.5)),
        focusedBorder: border(AppColors.primary, 1.5),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.5),
      ),
    );
  }
}
