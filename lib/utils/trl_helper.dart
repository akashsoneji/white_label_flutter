import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import '../services/language_service.dart';

/// Extension on Iterable to add firstWhereOrNull method
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (T element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// RTL Helper utility class for creating RTL-aware layouts
class RTLHelper {
  /// Get current text direction
  static TextDirection get textDirection {
    final languageService = Get.find<LanguageService>();
    return languageService.isRTL() ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Check if current language is RTL
  static bool get isRTL {
    final languageService = Get.find<LanguageService>();
    return languageService.isRTL();
  }

  /// Get RTL-aware padding
  static EdgeInsets getRTLPadding({
    double left = 0,
    double right = 0,
    double top = 0,
    double bottom = 0,
  }) {
    if (isRTL) {
      return EdgeInsets.only(
        left: right,
        right: left,
        top: top,
        bottom: bottom,
      );
    }
    return EdgeInsets.only(left: left, right: right, top: top, bottom: bottom);
  }

  /// Get RTL-aware margin
  static EdgeInsets getRTLMargin({
    double left = 0,
    double right = 0,
    double top = 0,
    double bottom = 0,
  }) {
    if (isRTL) {
      return EdgeInsets.only(
        left: right,
        right: left,
        top: top,
        bottom: bottom,
      );
    }
    return EdgeInsets.only(left: left, right: right, top: top, bottom: bottom);
  }

  /// Get RTL-aware alignment
  static Alignment getRTLAlignment(Alignment alignment) {
    if (isRTL) {
      if (alignment == Alignment.centerLeft) return Alignment.centerRight;
      if (alignment == Alignment.centerRight) return Alignment.centerLeft;
      if (alignment == Alignment.topLeft) return Alignment.topRight;
      if (alignment == Alignment.topRight) return Alignment.topLeft;
      if (alignment == Alignment.bottomLeft) return Alignment.bottomRight;
      if (alignment == Alignment.bottomRight) return Alignment.bottomLeft;
    }
    return alignment;
  }

  /// Get RTL-aware crossAxisAlignment
  static CrossAxisAlignment getRTLCrossAxisAlignment(
    CrossAxisAlignment alignment,
  ) {
    if (isRTL) {
      if (alignment == CrossAxisAlignment.start) return CrossAxisAlignment.end;
      if (alignment == CrossAxisAlignment.end) return CrossAxisAlignment.start;
    }
    return alignment;
  }

  /// Get RTL-aware mainAxisAlignment
  static MainAxisAlignment getRTLMainAxisAlignment(
    MainAxisAlignment alignment,
  ) {
    if (isRTL) {
      if (alignment == MainAxisAlignment.start) return MainAxisAlignment.end;
      if (alignment == MainAxisAlignment.end) return MainAxisAlignment.start;
    }
    return alignment;
  }

  /// Create RTL-aware Row
  static Widget rtlRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    TextDirection? textDirection,
    VerticalDirection verticalDirection = VerticalDirection.down,
    TextBaseline? textBaseline,
  }) {
    return Row(
      mainAxisAlignment: getRTLMainAxisAlignment(mainAxisAlignment),
      crossAxisAlignment: getRTLCrossAxisAlignment(crossAxisAlignment),
      mainAxisSize: mainAxisSize,
      textDirection: textDirection ?? RTLHelper.textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      children: isRTL ? children.reversed.toList() : children,
    );
  }

  /// Create RTL-aware Icon
  static Widget rtlIcon(
    IconData icon, {
    double? size,
    Color? color,
    String? semanticLabel,
    TextDirection? textDirection,
  }) {
    // For RTL, we might need to flip certain icons
    IconData rtlIcon = icon;
    if (isRTL) {
      // Flip directional icons
      switch (icon.codePoint) {
        case 0xe5c4: // Icons.arrow_back
          rtlIcon = Icons.arrow_forward;
          break;
        case 0xe5c8: // Icons.arrow_forward
          rtlIcon = Icons.arrow_back;
          break;
        case 0xe5c7: // Icons.arrow_back_ios
          rtlIcon = Icons.arrow_forward_ios;
          break;
        case 0xe5cc: // Icons.arrow_forward_ios
          rtlIcon = Icons.arrow_back_ios;
          break;
        case 0xe5db: // Icons.keyboard_arrow_left
          rtlIcon = Icons.keyboard_arrow_right;
          break;
        case 0xe5dc: // Icons.keyboard_arrow_right
          rtlIcon = Icons.keyboard_arrow_left;
          break;
        case 0xe5dd: // Icons.keyboard_arrow_down
          // Keep as is
          break;
        case 0xe5de: // Icons.keyboard_arrow_up
          // Keep as is
          break;
      }
    }

    return Icon(
      rtlIcon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: textDirection ?? RTLHelper.textDirection,
    );
  }

  /// Create RTL-aware TextField
  /// Create RTL-aware TextField
  static Widget rtlTextField({
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
    FocusNode? focusNode, // ✅ Optional FocusNode
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // ✅ Uses focusNode only if provided
      onTap: onTap,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style:
          style ??
          TextStyle(
            fontSize: 14.sp,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w400,
          ),
      cursorColor: AppColors.primary,
      readOnly: readOnly,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      textDirection: RTLHelper.textDirection,
      textAlign: isRTL ? TextAlign.right : TextAlign.left,
      maxLines: maxLines ?? 1,
      decoration:
          decoration?.copyWith(
            hintStyle: TextStyle(color: AppColors.hint),
            labelStyle: TextStyle(color: AppColors.hint),
            floatingLabelStyle: TextStyle(color: AppColors.primary),
            fillColor: AppColors.textFieldBg,
            filled: true,
            prefixIcon: isRTL ? suffixIcon : prefixIcon,
            suffixIcon: isRTL ? prefixIcon : suffixIcon,
            contentPadding:
                contentPadding ??
                RTLHelper.getRTLPadding(
                  left: 8.w,
                  right: 8.w,
                  top: 0.h,
                  bottom: 0.h,
                ),
          ) ??
          InputDecoration(
            labelStyle: TextStyle(color: AppColors.hint),
            hintStyle: TextStyle(color: AppColors.hint),
            floatingLabelStyle: TextStyle(color: AppColors.primary),
            labelText: labelText,
            hintText: hintText,
            fillColor: AppColors.textFieldBg,
            filled: true,
            prefixIcon: isRTL ? suffixIcon : prefixIcon,
            suffixIcon: isRTL ? prefixIcon : suffixIcon,
            contentPadding:
                contentPadding ??
                RTLHelper.getRTLPadding(
                  left: 8.w,
                  right: 8.w,
                  top: 0.h,
                  bottom: 0.h,
                ),
          ),
    );
  }

  /// Create RTL-aware Button
  static Widget rtlButton({
    required String text,
    required VoidCallback? onPressed,
    Widget? icon,
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isRTL && icon != null ? null : icon,
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: padding ?? EdgeInsets.zero,
        ),
      ),
    );
  }

  /// Create RTL-aware ListTile
  static Widget rtlListTile({
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      leading: isRTL ? trailing : leading,
      trailing: isRTL ? leading : trailing,
      onTap: onTap,
      contentPadding:
          contentPadding ?? RTLHelper.getRTLPadding(left: 16.w, right: 16.w),
    );
  }

  /// Create RTL-aware Card
  static Widget rtlCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
    Color? color,
    double? elevation,
    ShapeBorder? shape,
  }) {
    return Card(
      margin:
          margin ??
          RTLHelper.getRTLMargin(
            left: 16.w,
            right: 16.w,
            top: 8.h,
            bottom: 8.h,
          ),
      color: color,
      elevation: elevation,
      shape: shape,
      child: child,
    );
  }

  /// Get RTL-aware border radius
  static BorderRadius getRTLBorderRadius({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
  }) {
    if (isRTL) {
      return BorderRadius.only(
        topLeft: Radius.circular(topRight),
        topRight: Radius.circular(topLeft),
        bottomLeft: Radius.circular(bottomRight),
        bottomRight: Radius.circular(bottomLeft),
      );
    }
    return BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: Radius.circular(topRight),
      bottomLeft: Radius.circular(bottomLeft),
      bottomRight: Radius.circular(bottomRight),
    );
  }

  /// Create RTL-aware Container with border
  static Widget rtlContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? color,
    BorderRadius? borderRadius,
    BoxBorder? border,
  }) {
    return Container(
      padding: padding,
      margin: margin,
      color: color,
      decoration: BoxDecoration(borderRadius: borderRadius, border: border),
      child: child,
    );
  }
}
