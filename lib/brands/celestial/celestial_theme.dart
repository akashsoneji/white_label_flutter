// Analyzing celestial...
// No issues found!

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/services/language_service.dart';

/// Global bus used to toggle light/dark theme from the Celestial settings
/// screen. The app shell wires this to its `MaterialApp.themeMode` so the
/// change propagates globally.
class CelThemeBus {
  CelThemeBus._();
  static final CelThemeBus instance = CelThemeBus._();

  final ValueNotifier<bool> isDark = ValueNotifier<bool>(false);

  /// Sets the dark-mode state. The shell rebuilds MaterialApp accordingly.
  void toggle(bool dark) {
    isDark.value = dark;
  }
}

/// Celestial — MT5-inspired design system.
/// Provides light + dark theme colors, typography, and shared widgets
/// used across the 5-tab shell (WatchList / Chart / Trade / History / Settings).
class CelTheme {
  CelTheme._();

  // ── Light palette (MT5 white) ──────────────────────────────────────────────
  static const Color _lightBg = Color(0xFFFFFFFF);
  static const Color _lightHeader = Color(0xFF1E3A8A); // deep blue header text
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightSoftBg = Color(0xFFF7F7F7);
  static const Color _lightDivider = Color(0xFFE6E6E6);
  static const Color _lightSubText = Color(0xFF6B7280);
  static const Color _lightMainText = Color(0xFF111827);
  static const Color _lightSell = Color(0xFFD72E1F);
  static const Color _lightBuy = Color(0xFF1E88E5);
  static const Color _lightPinkBg = Color(0xFFFCE7E7); // trade pill bg

  // ── Dark palette (MT5 dark) ────────────────────────────────────────────────
  static const Color _darkBg = Color(0xFF1E1E1E);
  static const Color _darkCard = Color(0xFF252525);
  static const Color _darkSoftBg = Color(0xFF121212);
  static const Color _darkDivider = Color(0xFF2C2C2C);
  static const Color _darkSubText = Color(0xFF9CA3AF);
  static const Color _darkMainText = Color(0xFFFFFFFF);
  static const Color _darkSell = Color(0xFFFF5A5F);
  static const Color _darkBuy = Color(0xFF42A5F5);
  static const Color _darkPinkBg = Color(0xFF2A1A1A);

  // ── Brand-agnostic, always the same ────────────────────────────────────────
  static const Color sellRed = Color(0xFFD72E1F);
  static const Color buyBlue = Color(0xFF1E88E5);
  static const Color buyBlueBright = Color(0xFF3C9DFF); // net p/l bright blue
  static const Color accentYellow = Color(0xFFFFB800);
  static const Color tpGreen = Color(0xFF22C55E);
  static const Color slRed = Color(0xFFEF4444);
  static const Color neutralGrey = Color(0xFFBFC7D4);
  static const Color tabInactive = Color(0xFF9CA3AF);

  // ── Public, theme-aware getters ────────────────────────────────────────────
  static bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  static Color bg(BuildContext c) => _isDark(c) ? _darkBg : _lightBg;
  static Color headerText(BuildContext c) => _isDark(c) ? _darkMainText : _lightHeader;
  static Color card(BuildContext c) => _isDark(c) ? _darkCard : _lightCard;
  static Color softBg(BuildContext c) => _isDark(c) ? _darkSoftBg : _lightSoftBg;
  static Color divider(BuildContext c) => _isDark(c) ? _darkDivider : _lightDivider;
  static Color subText(BuildContext c) => _isDark(c) ? _darkSubText : _lightSubText;
  static Color mainText(BuildContext c) => _isDark(c) ? _darkMainText : _lightMainText;
  static Color sell(BuildContext c) => _isDark(c) ? _darkSell : _lightSell;
  static Color buy(BuildContext c) => _isDark(c) ? _darkBuy : _lightBuy;
  static Color pillBg(BuildContext c) => _isDark(c) ? _darkPinkBg : _lightPinkBg;
  static Color buyTint(BuildContext c) =>
      _isDark(c) ? const Color(0xFF15243A) : const Color(0xFFEAF3FF);

  // ── Typography ─────────────────────────────────────────────────────────────
  static TextStyle title(BuildContext c) => TextStyle(
        color: headerText(c),
        fontSize: 22.sp,
        fontWeight: FontWeight.w800,
      );

  static TextStyle sectionLabel(BuildContext c) => TextStyle(
        color: subText(c),
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

  static TextStyle bigPrice(BuildContext c, {Color? color}) => TextStyle(
        color: color ?? mainText(c),
        fontSize: 18.sp,
        fontWeight: FontWeight.w800,
      );

  static TextStyle label(BuildContext c) => TextStyle(
        color: subText(c),
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle value(BuildContext c, {Color? color}) => TextStyle(
        color: color ?? mainText(c),
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
      );
}

/// Bottom navigation bar shared by all 5 screens.
/// Shows the 5 tabs (WatchList, Chart, Trade, History, Settings) as seen in the
/// screenshots, with the active tab highlighted in brand blue.
class CelBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CelBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF252525) : Colors.white;
    final border = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEAEAEA);
    final active = CelTheme.buyBlue;
    final inactive = CelTheme.tabInactive;

    final items = <_BarItem>[
      _BarItem(
        icon: Icons.grid_view_rounded,
        label: Get.find<LanguageService>().tr('nav_tab_watchlist'),
      ),
      _BarItem(
        icon: Icons.candlestick_chart,
        label: Get.find<LanguageService>().tr('nav_tab_charts'),
      ),
      _BarItem(
        icon: Icons.show_chart,
        label: Get.find<LanguageService>().tr('nav_tab_trade'),
      ),
      _BarItem(
        icon: Icons.history,
        label: Get.find<LanguageService>().tr('nav_tab_history'),
      ),
      _BarItem(
        icon: Icons.settings,
        label: Get.find<LanguageService>().tr('nav_tab_settings'),
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 60.h,
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: border, width: 0.6)),
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final isActive = i == currentIndex;
            final color = isActive ? active : inactive;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(items[i].icon, color: color, size: 22.sp),
                    SizedBox(height: 2.h),
                    Text(
                      items[i].label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10.sp,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BarItem {
  final IconData icon;
  final String label;
  const _BarItem({required this.icon, required this.label});
}
