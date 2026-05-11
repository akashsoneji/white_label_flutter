import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/home/brands/vantage/vantage_glass_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

class VantageMoreItem {
  final String? iconAsset;
  final IconData? iconData;
  final String label;
  final Color tint;
  final VoidCallback onTap;
  final bool showSwitch;
  final bool switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  const VantageMoreItem({
    this.iconAsset,
    this.iconData,
    required this.label,
    required this.tint,
    required this.onTap,
    this.showSwitch = false,
    this.switchValue = false,
    this.onSwitchChanged,
  });
}

class VantageMoreOptionsList extends StatelessWidget {
  final List<VantageMoreItem> items;

  const VantageMoreOptionsList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final borderAlpha = AppColors.isDarkMode ? 0.22 : 0.14;

    return Container(
      decoration: VantageUiTokens.groupDecoration(),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isLast = idx == items.length - 1;

          return Column(
            children: [
              _VantageOptionRow(item: item),
              if (!isLast)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: Divider(
                    height: 1,
                    color: AppColors.border.withValues(alpha: borderAlpha),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class VantageMoreQuickActionsGrid extends StatelessWidget {
  final List<VantageMoreItem> items;

  const VantageMoreQuickActionsGrid({super.key, required this.items})
    : assert(items.length > 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: VantageUiTokens.cardDecoration(),
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children:
            items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: idx == items.length - 1 ? 0 : 8.w),
                  child: _VantageQuickActionTile(item: item),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _VantageQuickActionTile extends StatelessWidget {
  final VantageMoreItem item;

  const _VantageQuickActionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: item.tint.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child:
                      item.iconData != null
                          ? Icon(item.iconData, size: 18.w, color: item.tint)
                          : SvgPicture.asset(
                            item.iconAsset ?? '',
                            width: 18.w,
                            height: 18.w,
                            colorFilter: ColorFilter.mode(
                              item.tint,
                              BlendMode.srcIn,
                            ),
                          ),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.8.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VantageOptionRow extends StatelessWidget {
  final VantageMoreItem item;

  const _VantageOptionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.showSwitch ? null : item.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: item.tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child:
                      item.iconData != null
                          ? Icon(item.iconData, size: 20.w, color: item.tint)
                          : SvgPicture.asset(
                            item.iconAsset ?? '',
                            width: 18.w,
                            height: 18.w,
                            colorFilter: ColorFilter.mode(
                              item.tint,
                              BlendMode.srcIn,
                            ),
                          ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
              ),
              if (item.showSwitch)
                _VantageMiniToggle(
                  value: item.switchValue,
                  color: item.tint,
                  onChanged: item.onSwitchChanged ?? (_) => item.onTap(),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22.w,
                  color: AppColors.textGrey.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VantageMiniToggle extends StatelessWidget {
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;

  const _VantageMiniToggle({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 44.w,
        height: 22.h,
        padding: EdgeInsets.symmetric(horizontal: 3.w),
        decoration: BoxDecoration(
          color:
              value
                  ? color.withValues(alpha: 0.95)
                  : AppColors.border.withValues(
                    alpha: AppColors.isDarkMode ? 0.35 : 0.22,
                  ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16.w,
            height: 16.w,
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

