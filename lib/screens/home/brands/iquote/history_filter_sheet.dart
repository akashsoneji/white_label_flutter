import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';

/// Full-screen page shown when the user taps the History tab's date row.
///
/// Theme-aware palette — uses [AppColors] tokens so the design matches the
/// screenshot in dark mode (deep-navy background, orange accent, purple-blue
/// reset button) and inverts to a light-paper look on the light theme.
///
/// Visual layout mirrors the iQuote filter screenshot:
///   - AppBar: back button + "Filter" title
///   - "Data" section with 2×2 grid of period presets
///   - "Trading pair" section with "Select all" + symbol chips
///   - "Reset" / "Confirm" action row
///
/// Symbol selection is currently UI-only — wiring it to the API would
/// require a server-side symbol filter parameter.
class HistoryFilterScreen extends StatefulWidget {
  final String initialPeriod;
  final Set<String> initialSymbols;
  final Future<void> Function(String period, Set<String> symbols) onConfirm;
  final Future<void> Function() onReset;

  const HistoryFilterScreen({
    super.key,
    required this.initialPeriod,
    this.initialSymbols = const {},
    required this.onConfirm,
    required this.onReset,
  });

  @override
  State<HistoryFilterScreen> createState() => _HistoryFilterScreenState();
}

class _HistoryFilterScreenState extends State<HistoryFilterScreen> {
  late String _selectedPeriod;
  final Set<String> _selectedSymbols = <String>{};

  /// Theme-aware palette derived from [AppColors].
  _ThemePalette get _p {
    if (AppColors.isDarkMode) {
      return const _ThemePalette(
        panel: Color(0xFF0E1424), // dark navy — matches screenshot
        card: Color(0xFF1A2238), // darker than panel for the unselected chips
        reset: Color(0xFF2D3568), // purple-blue — matches "Reset" in screenshot
        textPrimary: Colors.white,
        textSecondary: Color(0xFFB7BCD4),
        accentForeground: Colors.white,
        resetForeground: Colors.white,
      );
    }
    return _ThemePalette(
      panel: AppColors.background,
      card: AppColors.card,
      reset: const Color(0xFFE3E7EF),
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      accentForeground: Colors.white,
      resetForeground: AppColors.textPrimary,
    );
  }

  /// Always-bright-orange accent, matching the brand [AppColors.primary]
  /// (which is `#FF6B1A` in the screenshot).
  Color get _accent => AppColors.primary;

  static const List<_PeriodOption> _periods = [
    _PeriodOption('today', 'Last day'),
    _PeriodOption('week', 'Last week'),
    _PeriodOption('month', 'Last month'),
    _PeriodOption('threeMonth', 'Last 3 month'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod.isEmpty ? 'today' : widget.initialPeriod;
    if (widget.initialSymbols.isEmpty) {
      _selectedSymbols.add('all');
    } else {
      _selectedSymbols.addAll(widget.initialSymbols);
    }
  }

  List<String> _availableSymbols() {
    final symbols = <String>{};
    if (Get.isRegistered<InstrumentsController>()) {
      symbols.addAll(
        Get.find<InstrumentsController>()
            .instruments
            .map((e) => e.symbol)
            .where((s) => s.isNotEmpty),
      );
    }
    final sorted = symbols.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final symbols = _availableSymbols();
    final p = _p;
    final mq = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.85,
      ),
      child: Material(
        color: p.panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(p),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    _buildPeriodGrid(p),
                    SizedBox(height: 20.h),
                    Text(
                      'Trading pair',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    _buildSymbolSection(symbols, p),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16.w,
                8.h,
                16.w,
                mq.padding.bottom + 16.h,
              ),
              child: _buildActions(p),
            ),
          ],
        ),
      ),
    );
  }

  /// Sheet header: drag handle + "Filter" title. No back button — the sheet
  /// is dismissed by swiping down or tapping the scrim, matching iOS-style
  /// modal bottom sheet behavior.
  Widget _buildHeader(_ThemePalette p) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: p.textSecondary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'Filter',
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
        ],
      ),
    );
  }

  Widget _buildPeriodGrid(_ThemePalette p) {
    Widget chip(_PeriodOption opt) {
      final active = _selectedPeriod == opt.id;
      return InkWell(
        onTap: () => setState(() => _selectedPeriod = opt.id),
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: active ? _accent : p.card,
            borderRadius: BorderRadius.circular(8.r),
          ),
          alignment: Alignment.center,
          child: Text(
            opt.label,
            style: TextStyle(
              color: active ? p.accentForeground : p.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10.h,
      crossAxisSpacing: 10.w,
      childAspectRatio: 3.0,
      children: _periods.map(chip).toList(),
    );
  }

  Widget _buildSymbolSection(List<String> symbols, _ThemePalette p) {
    final selectAllSelected = _selectedSymbols.contains('all');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (selectAllSelected) {
              _selectedSymbols.clear();
            } else {
              _selectedSymbols
                ..clear()
                ..add('all')
                ..addAll(symbols);
            }
          }),
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: _accent, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              selectAllSelected ? 'Deselect all' : 'Select all',
              style: TextStyle(
                color: _accent,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (symbols.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: symbols.map((s) {
              final selected = _selectedSymbols.contains(s);
              return InkWell(
                onTap: () => setState(() {
                  _selectedSymbols.remove('all');
                  if (selected) {
                    _selectedSymbols.remove(s);
                  } else {
                    _selectedSymbols.add(s);
                  }
                }),
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: selected ? _accent : p.card,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      color: selected ? p.accentForeground : p.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(_ThemePalette p) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48.h,
            child: ElevatedButton(
              onPressed: () async {
                await widget.onReset();
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: p.reset,
                foregroundColor: p.resetForeground,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
              child: Text('Reset',
                  style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: SizedBox(
            height: 48.h,
            child: ElevatedButton(
              onPressed: () async {
                await widget.onConfirm(_selectedPeriod, _selectedSymbols);
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: p.accentForeground,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
              child: Text('Confirm',
                  style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Immutable theme palette used by [HistoryFilterScreen]. Derived from
/// [AppColors] — different values for dark vs light so the sheet looks
/// correct in both themes.
class _ThemePalette {
  final Color panel;
  final Color card;
  final Color reset;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentForeground;
  final Color resetForeground;

  const _ThemePalette({
    required this.panel,
    required this.card,
    required this.reset,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentForeground,
    required this.resetForeground,
  });
}

class _PeriodOption {
  final String id;
  final String label;
  const _PeriodOption(this.id, this.label);
}