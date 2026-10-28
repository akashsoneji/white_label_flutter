import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Sets the account nickname via `POST mt5accounts/setnickname`
/// (web `submitNickname`), then refreshes the dashboard account list.
class RenameAccountDialog extends StatefulWidget {
  const RenameAccountDialog({super.key, required this.account});

  final MT5Account account;

  @override
  State<RenameAccountDialog> createState() => _RenameAccountDialogState();
}

class _RenameAccountDialogState extends State<RenameAccountDialog> {
  static const _maxLength = 50;

  final LanguageService _lang = Get.find<LanguageService>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.account.mt5NickName);

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nameController.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = _lang.tr('account_rename_empty'));
      return;
    }

    setState(() {
      _error = null;
      _isSaving = true;
    });
    try {
      final token = await SecureStorageService.getAuthToken();
      final response = await ApiService.post(
        endpoint: ApiConstants.setMt5Nickname,
        token: token,
        data: {
          'meta_account_number': widget.account.metaAccountNumber,
          'mt5_nick_name': nickname,
        },
      );
      if (!mounted) return;
      if (!response.success) {
        setState(() => _isSaving = false);
        CustomToastService.showError(
          message: response.message ?? _lang.tr('account_rename_failed'),
        );
        return;
      }

      Get.back();
      CustomToastService.showSuccess(
        message: response.message ?? _lang.tr('account_rename_success'),
      );
      if (Get.isRegistered<DashboardController>()) {
        await Get.find<DashboardController>().refreshMT5Accounts(force: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToastService.showError(message: _lang.tr('account_rename_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: BorderSide(color: AppColors.border),
    );

    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lang.tr('account_rename_title'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '#${widget.account.metaAccountNumber}',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: _maxLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSaving ? null : _save(),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: _lang.tr('account_rename_label'),
                hintText: _lang.tr('account_rename_hint'),
                errorText: _error,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 12.h,
                ),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSaving ? null : Get.back,
                    child: Text(
                      _lang.tr('navigation_cancel'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.whiteColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: _isSaving
                        ? ButtonLoadingWidget(
                            size: 18.0,
                            color: AppColors.whiteColor,
                          )
                        : Text(
                            _lang.tr('account_rename_save'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.whiteColor,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
