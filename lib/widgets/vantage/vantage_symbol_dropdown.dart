import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

/// Vantage chart AppBar control: tap to pick a symbol from favorites.
class VantageSymbolDropdown extends StatefulWidget {
  final String selectedSymbol;
  final List<String> favorites;
  final ValueChanged<String> onSymbolSelected;
  final String Function(String) formatLabel;
  final VoidCallback? onEmptyTap;

  /// Max rows visible before the menu scrolls.
  static const int maxVisibleItems = 8;
  static const double itemHeight = 44;

  const VantageSymbolDropdown({
    super.key,
    required this.selectedSymbol,
    required this.favorites,
    required this.onSymbolSelected,
    required this.formatLabel,
    this.onEmptyTap,
  });

  @override
  State<VantageSymbolDropdown> createState() => _VantageSymbolDropdownState();

  /// Shows a scrollable favorites menu (max [maxVisibleItems] rows visible).
  static Future<String?> showFavoritesMenu({
    required BuildContext context,
    required double anchorLeft,
    required double anchorTop,
    required double anchorWidth,
    required double anchorHeight,
    required List<String> favorites,
    required String selectedSymbol,
    required String Function(String) formatLabel,
    required bool Function(String, String) symbolsMatch,
  }) {
    if (favorites.isEmpty) return Future.value();

    final visibleCount =
        favorites.length.clamp(1, VantageSymbolDropdown.maxVisibleItems);
    final maxMenuHeight = visibleCount * VantageSymbolDropdown.itemHeight;

    return showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        anchorLeft,
        anchorTop + anchorHeight + 4,
        anchorLeft + anchorWidth,
        anchorTop,
      ),
      constraints: BoxConstraints(
        minWidth: anchorWidth.clamp(140, 280),
        maxWidth: 280,
        maxHeight: maxMenuHeight,
      ),
      elevation: 6,
      color: AppColors.whiteColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      items: favorites.map((symbol) {
        final isSelected = symbolsMatch(symbol, selectedSymbol);
        return PopupMenuItem<String>(
          value: symbol,
          height: VantageSymbolDropdown.itemHeight,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatLabel(symbol),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: 18.sp, color: AppColors.primary),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _VantageSymbolDropdownState extends State<VantageSymbolDropdown> {
  final GlobalKey _anchorKey = GlobalKey();

  bool _symbolsMatch(String a, String b) {
    if (a == b) return true;
    final na = widget.formatLabel(a);
    final nb = widget.formatLabel(b);
    return na == nb;
  }

  Future<void> _openFavoritesMenu() async {
    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null) return;

    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    final selected = await VantageSymbolDropdown.showFavoritesMenu(
      context: context,
      anchorLeft: offset.dx,
      anchorTop: offset.dy,
      anchorWidth: size.width,
      anchorHeight: size.height,
      favorites: widget.favorites,
      selectedSymbol: widget.selectedSymbol,
      formatLabel: widget.formatLabel,
      symbolsMatch: _symbolsMatch,
    );

    if (selected != null && selected.isNotEmpty) {
      widget.onSymbolSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFavorites = widget.favorites.isNotEmpty;
    final label = widget.formatLabel(widget.selectedSymbol);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: _anchorKey,
        onTap: hasFavorites ? _openFavoritesMenu : widget.onEmptyTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label.isNotEmpty ? label : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22.sp,
                color: hasFavorites ? AppColors.primary : AppColors.textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
