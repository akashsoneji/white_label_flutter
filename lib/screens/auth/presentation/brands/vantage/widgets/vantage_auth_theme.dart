import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../../flavor_config.dart';

/// Theme tokens for the Vantage auth flow (sourced from [FlavorConfig]).
class VantageAuthTheme {
  VantageAuthTheme._();

  static Color get background => FlavorConfig.instance.secondaryColor;
  static const Color card = Colors.white;
  static Color get primary => FlavorConfig.instance.primaryColor;
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color fieldFill = Color(0xFFF3F4F6);
  static const Color fieldBorder = Color(0xFFE5E7EB);

  static const Radius cardRadius = Radius.circular(28);

  static const double fieldBorderRadius = 24;

  static OutlineInputBorder pillOutlineBorder({
    Color borderColor = fieldBorder,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldBorderRadius.r),
      borderSide: BorderSide(color: borderColor, width: width),
    );
  }

  /// Keeps pill radius consistent while focused (avoids M3 theme fallback).
  static InputDecoration pillDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? counterText,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final radius = BorderRadius.circular(fieldBorderRadius.r);
    final padding =
        contentPadding ??
        EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h);

    return InputDecoration(
      hintText: hintText,
      counterText: counterText,
      hintStyle: TextStyle(
        color: muted.withValues(alpha: 0.8),
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: fieldFill,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: padding,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: fieldBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 0, height: 0),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: fieldBorder),
      ),
    );
  }

  static InputDecorationTheme pillInputDecorationTheme() {
    final radius = BorderRadius.circular(fieldBorderRadius.r);
    return InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: fieldBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 0, height: 0),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: fieldBorder),
      ),
    );
  }
}
