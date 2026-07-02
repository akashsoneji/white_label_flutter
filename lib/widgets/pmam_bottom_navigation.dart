import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/color.dart';

/// Bottom navigation for the PAMM module.
///
/// Two tab sets are exposed:
/// • [PmamNavMode.manager]  → 5 tabs (Dashboard, Plans, Investors, Explore, Investments)
///                            mirrors the web sidebar shown to approved managers.
/// • [PmamNavMode.investor] → 3 tabs (Become Manager, Explore, Investments)
///                            mirrors the web sidebar shown to non-managers.
enum PmamNavMode { manager, investor }

class PmamBottomNavigation extends StatelessWidget {
  const PmamBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.mode,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final PmamNavMode mode;

  List<_PmamTab> get _tabs => mode == PmamNavMode.manager
      ? const [
          _PmamTab('Dashboard', Icons.dashboard_rounded),
          _PmamTab('Plans', Icons.layers_rounded),
          _PmamTab('Investors', Icons.group_rounded),
          _PmamTab('Explore', Icons.travel_explore_rounded),
          _PmamTab('Invest', Icons.account_balance_wallet_rounded),
        ]
      : const [
          _PmamTab('Become Mgr', Icons.workspace_premium_rounded),
          _PmamTab('Explore', Icons.travel_explore_rounded),
          _PmamTab('Invest', Icons.account_balance_wallet_rounded),
        ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
              final selected = i == currentIndex;
              return Expanded(
                child: _NavItem(
                  tab: tabs[i],
                  selected: selected,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PmamTab {
  final String label;
  final IconData icon;
  const _PmamTab(this.label, this.icon);
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _PmamTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textGrey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, color: color, size: 22.sp),
            SizedBox(height: 4.h),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}