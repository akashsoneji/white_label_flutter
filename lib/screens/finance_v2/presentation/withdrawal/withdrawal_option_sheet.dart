import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

/// Opens a short list of [options] as a bottom sheet and completes with the
/// tapped one, or null when the sheet is dismissed.
///
/// Used for the amount currency and the crypto network of a withdrawal.
Future<T?> showWithdrawalOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T option) labelOf,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBackground,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.7,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (sheetContext) => _OptionSheet<T>(
      title: title,
      options: options,
      labelOf: labelOf,
      selected: selected,
    ),
  );
}

class _OptionSheet<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final String Function(T option) labelOf;
  final T? selected;

  const _OptionSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16.w, 16.h, 16.w, 8.h),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(bottom: 8.h),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return InkWell(
                  onTap: () => Navigator.of(context).pop(option),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 48.h),
                    child: Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: 16.w,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              labelOf(option),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          SizedBox(
                            width: 20.w,
                            child: option == selected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: AppColors.primary,
                                    size: 18.sp,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
