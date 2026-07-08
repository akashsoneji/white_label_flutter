import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        TextFormField(
          cursorColor: AppColors.primary,
          selectionControls: MaterialTextSelectionControls(),
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          focusNode: focusNode,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14.sp,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 14.sp),
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            filled: true,
            fillColor: enabled ? AppColors.card : AppColors.backgroundLight,
          ),
        ),
      ],
    );
  }
}

class AppTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final TextStyle? style;
  final InputDecoration? decoration;
  final TextAlign textAlign;
  final double? width;
  final TextStyle? hintStyle;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsetsGeometry? contentPadding;

  const AppTextFormField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.style,
    this.decoration,
    this.textAlign = TextAlign.start,
    this.width,
    this.hintStyle,
    this.inputFormatters,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    Widget field = TextFormField(
      cursorColor: AppColors.primary,
      selectionControls: MaterialTextSelectionControls(),
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      focusNode: focusNode,
      textAlign: textAlign,
      inputFormatters: inputFormatters,
      style: style ?? TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14.sp,
      ),
      decoration: decoration ?? InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle ??
            TextStyle(color: AppColors.textGrey, fontSize: 14.sp),
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: contentPadding,
        filled: false,
      ),
    );

    if (width != null) {
      field = SizedBox(width: width, child: field);
    }

    if (label == null) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        field,
      ],
    );
  }
}