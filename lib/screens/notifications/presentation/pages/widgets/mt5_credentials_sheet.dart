import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

import '../../../data/models/notification_model.dart';

/// One-time MT5 login details. The server will not return the passwords again
/// after this sheet is acknowledged, so the user is asked to save them now.
class Mt5CredentialsSheet extends StatelessWidget {
  final Mt5Credentials credentials;

  const Mt5CredentialsSheet({super.key, required this.credentials});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, bool)>[
      ('mt5_credentials_login', credentials.login, true),
      ('mt5_credentials_server', credentials.server, true),
      ('mt5_credentials_main_password', credentials.mainPassword, true),
      ('mt5_credentials_investor_password', credentials.investorPassword, true),
      ('mt5_credentials_plan', credentials.planTitle, false),
      ('mt5_credentials_leverage', credentials.leverage, false),
      ('mt5_credentials_currency', credentials.currency, false),
    ].where((row) => row.$2.isNotEmpty).toList();

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsetsDirectional.fromSTEB(16.w, 10.h, 16.w, 12.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                TranslationUtils.tr('mt5_credentials_title'),
                style: AppTextStyles.screenTitle,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        TranslationUtils.tr('mt5_credentials_shown_once'),
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              ...rows.map(
                (row) => _CredentialRow(
                  label: TranslationUtils.tr(row.$1),
                  value: row.$2,
                  copyable: row.$3,
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 42.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    TranslationUtils.tr('mt5_credentials_saved'),
                    style: AppTextStyles.bodyText.copyWith(
                      color: AppColors.whiteColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;

  const _CredentialRow({
    required this.label,
    required this.value,
    required this.copyable,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                SelectableText(
                  value,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: TranslationUtils.tr('mt5_credentials_copy'),
              icon: Icon(
                Icons.copy_rounded,
                color: AppColors.primary,
                size: 18.sp,
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                CustomToastService.showSuccess(
                  message: TranslationUtils.tr('mt5_credentials_copied'),
                );
              },
            ),
        ],
      ),
    );
  }
}
