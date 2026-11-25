import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/language_service.dart';

/// Optional promo bonus code for live groups with `accepts_promo_code`.
///
/// The server accepts 6-8 letters, digits, `-` or `_` and ignores case, so
/// the field only limits length and characters; [errorText] carries the
/// server's BONUS_CODE_INVALID message.
class BonusCodeField extends StatelessWidget {
  const BonusCodeField({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
  });

  static const int maxLength = 8;

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.error),
    );
    return TextField(
      key: const Key('create_account_bonus_code'),
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.characters,
      maxLength: maxLength,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: TranslationUtils.tr('create_account_bonus_code_label'),
        hintText: TranslationUtils.tr('create_account_bonus_code_hint'),
        errorText: errorText,
        errorMaxLines: 3,
        counterText: '',
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
      ),
    );
  }
}
