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
  final Future<void> Function(String period, List<String> symbols) onConfirm;
  final Future<void> Function() onReset;

  const HistoryFilterScreen({
    super.key,
    required this.initialPeriod,
    required this.onConfirm,
    required this.onReset,
  });

  @override
  State<HistoryFilterScreen> createState() => _HistoryFilterScreenState();
}

class _HistoryFilterScreenState extends State<HistoryFilterScreen> {
  late String _selectedPeriod;
  final Set<String> _selectedSymbols = <String>{};



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
    _selectedPeriod =
        widget.initialPeriod.isEmpty ? 'today' : widget.initialPeriod;
    _selectedSymbols.add('all');
  }

  List<String> _availableSymbols() {
    if (!Get.isRegistered<InstrumentsController>()) return const [];
    return Get.find<InstrumentsController>().instruments
        .map((e) => e.symbol)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    final symbols = _availableSymbols();
    
    return Material(
      color: AppColors.background,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    _buildPeriodGrid(),
                    if (symbols.isNotEmpty) ...[
                      SizedBox(height: 20.h),
                      _buildSymbolSection(symbols),
                    ],
                  ],
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 16.w, 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Filter History',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 22.sp, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodGrid() {
    Widget chip(_PeriodOption opt) {
      final active = _selectedPeriod == opt.id;
      return InkWell(
        onTap: () => setState(() => _selectedPeriod = opt.id),
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: active ? _accent : AppColors.card,
            borderRadius: BorderRadius.circular(8.r),
          ),
          alignment: Alignment.center,
          child: Text(
            opt.label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
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

  Widget _buildSymbolSection(List<String> symbols) {
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 7.h,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _accent : AppColors.card,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
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

  Widget _buildActions() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                await widget.onReset();
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Text(
                'Reset',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                await widget.onConfirm(
                  _selectedPeriod,
                  _selectedSymbols.toList(),
                );
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodOption {
  final String id;
  final String label;
  const _PeriodOption(this.id, this.label);
}
