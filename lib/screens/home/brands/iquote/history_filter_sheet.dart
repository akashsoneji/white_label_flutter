import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';

/// Modern bottom sheet used by the History tab to filter trade history.
///
/// Provides:
///   - Period selection (Today / Week / Month / 3M / Custom range)
///   - Direction segmented control (All / Buy / Sell)
///   - Symbol search + multi-select with "Select all"
///   - Sticky action bar with Reset + Apply (badge with active count)
///
/// State-preserving: opens pre-populated with whatever the user last applied
/// (period, symbols, direction, custom range) via [TradingController].
class HistoryFilterScreen extends StatefulWidget {
  final String initialPeriod;
  final String initialDirection;
  final List<String> initialSymbols;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final Future<void> Function(
    String period,
    List<String> symbols,
    String direction,
    DateTime? customStart,
    DateTime? customEnd,
  ) onConfirm;
  final Future<void> Function() onReset;

  const HistoryFilterScreen({
    super.key,
    required this.initialPeriod,
    required this.initialDirection,
    required this.initialSymbols,
    required this.onConfirm,
    required this.onReset,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<HistoryFilterScreen> createState() => _HistoryFilterScreenState();
}

class _HistoryFilterScreenState extends State<HistoryFilterScreen> {
  late String _period;
  late String _direction;
  late Set<String> _selectedSymbols;
  DateTime? _customStart;
  DateTime? _customEnd;
  String _search = '';

  Color get _accent => AppColors.primary;
  Color get _bg => AppColors.background;
  Color get _card => AppColors.card;

  static const List<_PeriodOption> _periods = [
    _PeriodOption('today', 'Today', Icons.today_outlined),
    _PeriodOption('week', '7 Days', Icons.date_range_outlined),
    _PeriodOption('month', '1 Month', Icons.calendar_month_outlined),
    _PeriodOption('threeMonth', '3 Months', Icons.event_note_outlined),
    _PeriodOption('custom', 'Custom', Icons.tune_outlined),
  ];

  static const List<_DirectionOption> _directions = [
    _DirectionOption('All', 'All', Icons.swap_vert),
    _DirectionOption('Buy', 'Buy', Icons.trending_up),
    _DirectionOption('Sell', 'Sell', Icons.trending_down),
  ];

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod.isEmpty ? 'today' : widget.initialPeriod;
    _direction = widget.initialDirection.isEmpty ? 'All' : widget.initialDirection;
    _selectedSymbols = widget.initialSymbols.isEmpty
        ? <String>{'all'}
        : widget.initialSymbols.toSet();
    _customStart = widget.initialStart;
    _customEnd = widget.initialEnd;
  }

  List<String> _availableSymbols() {
    final set = <String>{};
    // Prefer symbols that actually appear in the fetched trade history first.
    if (Get.isRegistered<TradingController>()) {
      set.addAll(Get.find<TradingController>().availableHistorySymbols);
    }
    if (Get.isRegistered<InstrumentsController>()) {
      set.addAll(
        Get.find<InstrumentsController>()
            .instruments
            .map((e) => e.symbol)
            .where((s) => s.isNotEmpty),
      );
    }
    final list = set.toList()..sort();
    return list;
  }

  int get _activeFilterCount {
    var n = 0;
    if (_period != 'today') n++;
    if (_direction != 'All') n++;
    final effectiveSymbols =
        _selectedSymbols.where((s) => s != 'all').toSet();
    if (effectiveSymbols.isNotEmpty &&
        !_selectedSymbols.contains('all')) {
      n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final symbols = _availableSymbols();
    final filteredSymbols = _search.isEmpty
        ? symbols
        : symbols
            .where((s) => s.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          _buildHeader(),
          Divider(height: 1, color: AppColors.divider),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Period'),
                  SizedBox(height: 10.h),
                  _buildPeriodChips(),
                  if (_period == 'custom') ...[
                    SizedBox(height: 12.h),
                    _buildCustomRange(),
                  ],
                  SizedBox(height: 22.h),
                  _sectionLabel('Direction'),
                  SizedBox(height: 10.h),
                  _buildDirectionSegments(),
                  SizedBox(height: 22.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('Symbols'),
                      _buildSelectAllToggle(symbols),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _buildSearchField(),
                  SizedBox(height: 12.h),
                  if (filteredSymbols.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Center(
                        child: Text(
                          _search.isEmpty
                              ? 'No symbols available'
                              : 'No symbols match "$_search"',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    )
                  else
                    _buildSymbolChips(filteredSymbols),
                ],
              ),
            ),
          ),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
      child: Center(
        child: Container(
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 12.w, 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.filter_alt_outlined, color: _accent, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter History',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _activeFilterCount == 0
                      ? 'Refine your closed trades view'
                      : '$_activeFilterCount filter${_activeFilterCount == 1 ? '' : 's'} active',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 22.sp),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );

  Widget _buildPeriodChips() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: _periods.map((opt) {
        final active = _period == opt.id;
        return InkWell(
          onTap: () async {
            setState(() => _period = opt.id);
            if (opt.id == 'custom' &&
                (_customStart == null || _customEnd == null)) {
              await _pickCustomRange();
            }
          },
          borderRadius: BorderRadius.circular(24.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: active ? _accent : _card,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: active ? _accent : AppColors.divider,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  opt.icon,
                  size: 15.sp,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
                SizedBox(width: 6.w),
                Text(
                  opt.label,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomRange() {
    String fmt(DateTime? d) => d == null
        ? 'Select'
        : '${d.day.toString().padLeft(2, '0')} ${_monthShort(d.month)} ${d.year}';

    Widget field(String label, DateTime? value, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: _accent, size: 14.sp),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        fmt(value),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        field('From', _customStart, () => _pickCustomRange(pickStart: true)),
        SizedBox(width: 10.w),
        field('To', _customEnd, () => _pickCustomRange(pickStart: false)),
      ],
    );
  }

  Future<void> _pickCustomRange({bool? pickStart}) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    final initialRange = DateTimeRange(
      start: _customStart ?? DateTime(now.year, now.month, now.day - 6),
      end: _customEnd ?? DateTime(now.year, now.month, now.day),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDateRange: initialRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _accent,
                onPrimary: Colors.white,
              ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  Widget _buildDirectionSegments() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: _directions.map((opt) {
          final active = _direction == opt.id;
          Color activeColor;
          if (opt.id == 'Buy') {
            activeColor = AppColors.statusGreen;
          } else if (opt.id == 'Sell') {
            activeColor = AppColors.statusRed;
          } else {
            activeColor = _accent;
          }
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _direction = opt.id),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: active ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      opt.icon,
                      size: 15.sp,
                      color: active ? Colors.white : AppColors.textSecondary,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      opt.label,
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectAllToggle(List<String> symbols) {
    final selectAll = _selectedSymbols.contains('all');
    return InkWell(
      onTap: () {
        setState(() {
          if (selectAll) {
            _selectedSymbols.clear();
          } else {
            _selectedSymbols
              ..clear()
              ..add('all');
          }
        });
      },
      borderRadius: BorderRadius.circular(6.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selectAll
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 16.sp,
              color: selectAll ? _accent : AppColors.textSecondary,
            ),
            SizedBox(width: 4.w),
            Text(
              selectAll ? 'All selected' : 'Select all',
              style: TextStyle(
                color: selectAll ? _accent : AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _search = v.trim()),
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: 'Search symbol',
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
          prefixIcon: Icon(Icons.search,
              color: AppColors.textSecondary, size: 18.sp),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 4.w, vertical: 12.h),
        ),
      ),
    );
  }

  Widget _buildSymbolChips(List<String> symbols) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: symbols.map((s) {
        final selected = _selectedSymbols.contains(s) &&
            !_selectedSymbols.contains('all');
        final visuallyActive =
            selected || _selectedSymbols.contains('all');
        return InkWell(
          onTap: () {
            setState(() {
              _selectedSymbols.remove('all');
              if (selected) {
                _selectedSymbols.remove(s);
              } else {
                _selectedSymbols.add(s);
              }
              if (_selectedSymbols.isEmpty) {
                _selectedSymbols.add('all');
              }
            });
          },
          borderRadius: BorderRadius.circular(20.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: visuallyActive
                  ? _accent.withValues(alpha: selected ? 1 : 0.15)
                  : _card,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: visuallyActive
                    ? _accent
                    : AppColors.divider,
                width: 1,
              ),
            ),
            child: Text(
              s,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (visuallyActive ? _accent : AppColors.textPrimary),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        12.h + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: () async {
                await widget.onReset();
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Text(
                'Reset',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () async {
                if (_period == 'custom' &&
                    (_customStart == null || _customEnd == null)) {
                  await _pickCustomRange();
                  if (_customStart == null || _customEnd == null) return;
                }
                final syms = _selectedSymbols.toList();
                await widget.onConfirm(
                  _period,
                  syms,
                  _direction,
                  _customStart,
                  _customEnd,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Apply Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_activeFilterCount > 0) ...[
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 7.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '$_activeFilterCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthShort(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[(m - 1).clamp(0, 11)];
  }
}

class _PeriodOption {
  final String id;
  final String label;
  final IconData icon;
  const _PeriodOption(this.id, this.label, this.icon);
}

class _DirectionOption {
  final String id;
  final String label;
  final IconData icon;
  const _DirectionOption(this.id, this.label, this.icon);
}
