import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';

/// One option for [AppSelectField].
class AppSelectOption<T> {
  final T value;
  final String title;
  final String? subtitle;

  const AppSelectOption({
    required this.value,
    required this.title,
    this.subtitle,
  });
}

/// Tappable field that opens a themed bottom sheet to pick a value.
class AppSelectField<T> extends StatelessWidget {
  final T? value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String hint;
  final String sheetTitle;
  final bool Function(T a, T b)? valueEquals;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final double? fontSize;
  final bool enabled;
  final Color? backgroundColor;

  const AppSelectField({
    super.key,
    required this.options,
    required this.onChanged,
    required this.hint,
    required this.sheetTitle,
    this.value,
    this.valueEquals,
    this.borderRadius = 10,
    this.contentPadding,
    this.fontSize,
    this.enabled = true,
    this.backgroundColor,
  });

  bool _isEqual(T a, T b) {
    if (valueEquals != null) return valueEquals!(a, b);
    return a == b;
  }

  bool _isSelected(T item) {
    if (value == null) return false;
    return _isEqual(value as T, item);
  }

  String? _labelForValue() {
    if (value == null) return null;
    for (final opt in options) {
      if (_isSelected(opt.value)) return opt.title;
    }
    return null;
  }

  void _openSheet(BuildContext context) {
    if (!enabled || options.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.of(ctx).size.height * 0.55;
        return SafeArea(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20.w, 12.h, 20.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  sheetTitle,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder:
                        (_, __) => Divider(
                          height: 1,
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final selected = _isSelected(opt.value);
                      return InkWell(
                        onTap: () {
                          onChanged(opt.value);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(8.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 14.h,
                            horizontal: 8.w,
                          ),
                          decoration: BoxDecoration(
                            color:
                                selected
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : null,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opt.title,
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 14.sp,
                                        fontWeight:
                                            selected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                        color:
                                            selected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (opt.subtitle != null &&
                                        opt.subtitle!.isNotEmpty) ...[
                                      SizedBox(height: 4.h),
                                      Text(
                                        opt.subtitle!,
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 12.sp,
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (selected)
                                Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    start: 8.w,
                                    top: 2.h,
                                  ),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                    size: 20.sp,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSize = fontSize ?? 14.sp;
    final label = _labelForValue();
    final radius = BorderRadius.circular(borderRadius.r);

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _openSheet(context) : null,
          borderRadius: radius,
          child: Ink(
            padding:
                contentPadding ??
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.whiteColor,
              borderRadius: radius,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label ?? hint,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: textSize,
                      fontWeight:
                          label != null ? FontWeight.w500 : FontWeight.w400,
                      color:
                          label != null
                              ? AppColors.textPrimary
                              : AppColors.textGrey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textGrey,
                  size: 22.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
