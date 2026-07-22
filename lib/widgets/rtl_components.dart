import 'package:flutter/material.dart';
import '../constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/trl_helper.dart';
import '../constants/color.dart';

/// RTL-aware reusable components with default sizes
class RTLComponents {
  // Default sizes
  static const double defaultHeight = 46.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 8.0;

  /// RTL-aware Elevated Button with default styling
  static Widget elevatedButton({
    required String text,
    required VoidCallback? onPressed,
    Widget? icon,
    Color? backgroundColor,
    Color? foregroundColor,
    double? width,
    double height = defaultHeight,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: width,
      height: height.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: foregroundColor ?? AppColors.whiteColor,
          padding:
              padding ?? EdgeInsets.symmetric(horizontal: defaultPadding.w),
          // Use fixedSize to match SizedBox constraints and avoid conflicts
          fixedSize: Size(width ?? double.infinity, height.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              (borderRadius?.topLeft.x ?? defaultBorderRadius).r,
            ),
          ),
          elevation: 0,
        ),
        child:
            isLoading
                ? SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      foregroundColor ?? AppColors.whiteColor,
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon, SizedBox(width: 8.w)],
                    Text(
                      text,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  /// RTL-aware Outlined Button with default styling
  static Widget outlinedButton({
    required String text,
    required VoidCallback? onPressed,
    Widget? icon,
    Color? borderColor,
    Color? textColor,
    double? width,
    double height = defaultHeight,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: width,
      height: height.h,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? AppColors.primary,
          side: BorderSide(color: borderColor ?? AppColors.primary, width: 1.5),
          padding:
              padding ?? EdgeInsets.symmetric(horizontal: defaultPadding.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              (borderRadius?.topLeft.x ?? defaultBorderRadius).r,
            ),
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      textColor ?? AppColors.primary,
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon, SizedBox(width: 8.w)],
                    Text(
                      text,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  /// RTL-aware Text Button with default styling
  static Widget textButton({
    required String text,
    required VoidCallback? onPressed,
    Widget? icon,
    Color? textColor,
    double? width,
    double height = defaultHeight,
    EdgeInsetsGeometry? padding,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: width,
      height: height.h,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: textColor ?? AppColors.primary,
          padding:
              padding ?? EdgeInsets.symmetric(horizontal: defaultPadding.w),
        ),
        child:
            isLoading
                ? SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      textColor ?? AppColors.primary,
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon, SizedBox(width: 8.w)],
                    Text(
                      text,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  /// RTL-aware Text Field with default styling
  static Widget textField({
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
    TextStyle? style,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    InputDecoration? decoration,
    EdgeInsetsGeometry? contentPadding,
    bool readOnly = false,
    VoidCallback? onTap,
    int? maxLines,
    double height = defaultHeight,
    Color? borderColor,
    Color? focusedBorderColor,
  }) {
    return SizedBox(
      height: height.h,
      child: RTLHelper.rtlTextField(
        controller: controller,
        labelText: labelText,
        hintText: hintText,
        keyboardType: keyboardType,
        obscureText: obscureText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        style: style ?? AppTextStyles.bodyText.copyWith(fontSize: 16.sp),
        validator: validator,
        onChanged: onChanged,
        decoration:
            decoration?.copyWith(
              contentPadding:
                  contentPadding ??
                  EdgeInsets.symmetric(
                    horizontal: defaultPadding.w,
                    vertical: (defaultPadding / 2).h,
                  ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(defaultBorderRadius.r),
                borderSide: BorderSide(
                  color: borderColor ?? AppColors.border,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(defaultBorderRadius.r),
                borderSide: BorderSide(
                  color: borderColor ?? AppColors.border,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(defaultBorderRadius.r),
                borderSide: BorderSide(
                  color: focusedBorderColor ?? AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(defaultBorderRadius.r),
                borderSide: BorderSide(color: AppColors.error, width: 1.5),
              ),
            ) ??
            InputDecoration(
              labelText: labelText,
              hintText: hintText,
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              contentPadding:
                  contentPadding ??
                  EdgeInsets.symmetric(
                    horizontal: defaultPadding.w,
                    vertical: (defaultPadding / 2).h,
                  ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(defaultBorderRadius.r),
                borderSide: BorderSide(
                  color: borderColor ?? AppColors.border,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(defaultBorderRadius.r),
                borderSide: BorderSide(
                  color: borderColor ?? AppColors.border,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(defaultBorderRadius.r),
                borderSide: BorderSide(
                  color: focusedBorderColor ?? AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(defaultBorderRadius.r),
                borderSide: BorderSide(color: AppColors.error, width: 1.5),
              ),
            ),
        contentPadding:
            contentPadding ??
            EdgeInsets.symmetric(
              horizontal: defaultPadding.w,
              vertical: (defaultPadding / 2).h,
            ),
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
      ),
    );
  }

  /// RTL-aware Card with default styling
  static Widget card({
    required Widget child,
    EdgeInsetsGeometry? margin,
    Color? color,
    double? elevation,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    return Card(
      margin:
          margin ??
          RTLHelper.getRTLMargin(
            left: defaultMargin.w,
            right: defaultMargin.w,
            top: defaultMargin.h,
            bottom: defaultMargin.h,
          ),
      color: color ?? AppColors.backgroundLight,
      elevation: elevation ?? 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          (borderRadius?.topLeft.x ?? defaultBorderRadius).r,
        ),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(defaultPadding.w),
        child: child,
      ),
    );
  }

  /// RTL-aware Container with default styling
  static Widget container({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? color,
    BorderRadius? borderRadius,
    BoxBorder? border,
    double? width,
    double? height,
    AlignmentGeometry? alignment,
  }) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? EdgeInsets.all(defaultPadding.w),
      margin:
          margin ??
          RTLHelper.getRTLMargin(
            left: defaultMargin.w,
            right: defaultMargin.w,
            top: defaultMargin.h,
            bottom: defaultMargin.h,
          ),
      color: color,
      alignment: alignment,
      decoration: BoxDecoration(
        borderRadius:
            borderRadius ?? BorderRadius.circular(defaultBorderRadius.r),
        border: border,
      ),
      child: child,
    );
  }

  /// RTL-aware Row with default spacing
  static Widget row({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    double spacing = defaultPadding,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;

    // Create a list with spacing widgets between children
    final List<Widget> spacedChildren = [];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(width: spacing.w));
      }
    }

    return RTLHelper.rtlRow(
      children: spacedChildren,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
    );
  }

  /// RTL-aware Column with default spacing
  static Widget column({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    double spacing = defaultPadding,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;

    // Create a list with spacing widgets between children
    final List<Widget> spacedChildren = [];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(height: spacing.h));
      }
    }

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: spacedChildren,
    );
  }

  /// RTL-aware Icon Button with default styling
  static Widget iconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    double? size,
    Color? backgroundColor,
    Color? foregroundColor,
    double? width,
    double height = defaultHeight,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return SizedBox(
      width: width,
      height: height.h,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: size ?? 24.sp,
          color: foregroundColor ?? AppColors.primary,
        ),
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: padding ?? EdgeInsets.all((defaultPadding / 2).w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              (borderRadius?.topLeft.x ?? defaultBorderRadius).r,
            ),
          ),
        ),
      ),
    );
  }

  /// RTL-aware List Tile with default styling
  static Widget listTile({
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    EdgeInsetsGeometry? contentPadding,
    Color? titleColor,
    Color? subtitleColor,
  }) {
    return RTLHelper.rtlListTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      contentPadding:
          contentPadding ??
          RTLHelper.getRTLPadding(
            left: defaultPadding.w,
            right: defaultPadding.w,
            top: (defaultPadding / 2).h,
            bottom: (defaultPadding / 2).h,
          ),
    );
  }

  /// Spacing widget for consistent spacing between elements
  static Widget spacing({double? width, double? height}) {
    return SizedBox(width: width?.w, height: height?.h);
  }

  /// Horizontal spacing
  static Widget hSpacing([double? spacing]) {
    return SizedBox(width: (spacing ?? defaultPadding).w);
  }

  /// Vertical spacing
  static Widget vSpacing([double? spacing]) {
    return SizedBox(height: (spacing ?? defaultPadding).h);
  }
}
