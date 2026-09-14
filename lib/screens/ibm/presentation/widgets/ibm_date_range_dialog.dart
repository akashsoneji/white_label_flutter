import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/language_service.dart';

/// Shows a theme-aware Date Range Dialog supporting Light and Dark modes
Future<DateTimeRange?> showIbmDateRangeDialog(
  BuildContext context, {
  DateTimeRange? initialRange,
}) async {
  DateTime startDate =
      initialRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = initialRange?.end ?? DateTime.now();

  return await showDialog<DateTimeRange>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final isDark = AppColors.isDarkMode;
          final dateFormat = DateFormat('yyyy-MM-dd');

          void applyPreset(String preset) {
            final now = DateTime.now();
            DateTime s = now;
            DateTime e = now;
            switch (preset) {
              case 'today':
                s = DateTime(now.year, now.month, now.day);
                e = DateTime(now.year, now.month, now.day, 23, 59, 59);
                break;
              case '7d':
                s = now.subtract(const Duration(days: 7));
                e = now;
                break;
              case '30d':
                s = now.subtract(const Duration(days: 30));
                e = now;
                break;
              case 'mtd':
                s = DateTime(now.year, now.month, 1);
                e = now;
                break;
              case 'all':
                s = DateTime(2020, 1, 1);
                e = now;
                break;
            }
            setState(() {
              startDate = s;
              endDate = e;
            });
          }

          Future<void> pickDate(bool isStart) async {
            final initial = isStart ? startDate : endDate;
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: isDark
                        ? ColorScheme.dark(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                            surface: const Color(0xFF1E1E1E),
                            onSurface: Colors.white,
                          )
                        : ColorScheme.light(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black87,
                          ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                if (isStart) {
                  startDate = picked;
                  if (endDate.isBefore(startDate)) {
                    endDate = startDate;
                  }
                } else {
                  endDate = picked;
                  if (startDate.isAfter(endDate)) {
                    startDate = endDate;
                  }
                }
              });
            }
          }

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        TranslationUtils.tr('ibm_select_date_range'),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.close,
                          size: 20.w,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Quick presets
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      _buildPresetChip(
                        TranslationUtils.tr('dc_range_today'),
                        () => applyPreset('today'),
                      ),
                      _buildPresetChip(
                        TranslationUtils.tr('ibm_range_7_days'),
                        () => applyPreset('7d'),
                      ),
                      _buildPresetChip(
                        TranslationUtils.tr('ibm_range_30_days'),
                        () => applyPreset('30d'),
                      ),
                      _buildPresetChip(
                        TranslationUtils.tr('ibm_range_mtd'),
                        () => applyPreset('mtd'),
                      ),
                      _buildPresetChip(
                        TranslationUtils.tr('ibm_range_all_time'),
                        () => applyPreset('all'),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),

                  // Start and End Date Cards
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => pickDate(true),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2C2C2C)
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  TranslationUtils.tr('ibm_from_start'),
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppColors.textGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14.w,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      dateFormat.format(startDate),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => pickDate(false),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2C2C2C)
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  TranslationUtils.tr('ibm_to_end'),
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppColors.textGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14.w,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      dateFormat.format(endDate),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 22.h),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                        ),
                        child: Text(
                          TranslationUtils.tr('account_management_cancel'),
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                            DateTimeRange(start: startDate, end: endDate),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 18.w,
                            vertical: 10.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          TranslationUtils.tr('ibm_apply_range'),
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildPresetChip(String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
