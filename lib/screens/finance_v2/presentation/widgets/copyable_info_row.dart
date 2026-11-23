import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// A label / value pair with a trailing copy button.
///
/// Copying puts [value] on the clipboard, shows a toast and then calls
/// [onCopied].
class CopyableInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopied;

  const CopyableInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.onCopied,
  });

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: value));
    CustomToastService.showSuccess(
      message: TranslationUtils.tr(
        'deposit_instruction_screen_label_copied_to_clipboard',
      ).replaceAll('{label}', label),
    );
    onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textGrey,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 4.h),
              // Account numbers and addresses must not be reordered in RTL.
              SizedBox(
                width: double.infinity,
                child: SelectableText(
                  value,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 40.w,
          height: 40.w,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: TranslationUtils.tr('general_copy'),
            onPressed: _copy,
            icon: Icon(
              Icons.copy_rounded,
              color: AppColors.primary,
              size: 18.sp,
            ),
          ),
        ),
      ],
    );
  }
}
