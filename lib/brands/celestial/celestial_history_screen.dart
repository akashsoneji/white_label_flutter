import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/models/trade_history_model.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'celestial_theme.dart';

/// History screen — MT5-style, wired to [TradingController] trade history API.
class CelestialHistoryScreen extends StatefulWidget {
  /// Called every time the History tab becomes active (initial mount + each
  /// subsequent tab-switch back to it). Used by the shell to trigger a fresh
  /// history fetch so the list is always up-to-date when the user arrives.
  final Future<void> Function()? onActivated;

  const CelestialHistoryScreen({super.key, this.onActivated});

  @override
  State<CelestialHistoryScreen> createState() => _CelestialHistoryScreenState();
}

class _CelestialHistoryScreenState extends State<CelestialHistoryScreen> {
  /// Public refresh hook — wraps the controller call so the shell (or any
  /// caller) can trigger a history re-fetch without reaching into the
  /// controller directly. Pull-to-refresh and tab-switch both route here.
  Future<void> refreshHistory() async {
    try {
      await Get.find<TradingController>().refreshTradeHistory();
    } catch (_) {
      // Swallow: refresh failures are non-fatal; UI keeps showing the
      // previously-cached list.
    }
  }
  TradingController get _c => Get.find<TradingController>();

  String _periodLabel = 'Today';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPeriod('Today');
    });
  }

  /// Display-only label for a raw period id. The raw values stay as-is because
  /// `_applyPeriod` switches on them.
  String _periodLabelText(String label) {
    switch (label) {
      case 'Last Week':
        return TranslationUtils.tr('transaction_history_period_last_week');
      case 'Last Month':
        return TranslationUtils.tr('iquote_position_last_month');
      case 'Last Three Months':
        return TranslationUtils.tr('celestial_history_last_three_months');
      case 'Last Six Months':
        return TranslationUtils.tr('celestial_history_last_six_months');
      case 'Last Year':
        return TranslationUtils.tr('celestial_history_last_year');
      case 'All History':
        return TranslationUtils.tr('celestial_history_all_history');
      case 'Today':
      default:
        return TranslationUtils.tr('dc_range_today');
    }
  }

  // ── Period → timestamps ────────────────────────────────────────────────────
  void _applyPeriod(String label) {
    final now   = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);

    DateTime from;
    DateTime to = now;

    switch (label) {
      case 'Today':
        from = today;
        break;
      case 'Last Week':
        from = today.subtract(const Duration(days: 7));
        break;
      case 'Last Month':
        from = DateTime.utc(now.year, now.month - 1, now.day);
        break;
      case 'Last Three Months':
        from = DateTime.utc(now.year, now.month - 3, now.day);
        break;
      case 'Last Six Months':
        from = DateTime.utc(now.year, now.month - 6, now.day);
        break;
      case 'Last Year':
        from = DateTime.utc(now.year - 1, now.month, now.day);
        break;
      case 'All History':
        from = DateTime.utc(2000);
        break;
      default:
        from = today;
    }

    _c.loadTradeHistoryWithTimestamps(
      page: 1,
      refresh: true,
      fromTimestamp: (from.millisecondsSinceEpoch / 1000).round(),
      toTimestamp:   (to.millisecondsSinceEpoch   / 1000).round(),
      filterType: label.toLowerCase().replaceAll(' ', '_'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CelTheme.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            _summaryRow(context),
            Divider(
                height: 1,
                thickness: 0.5,
                color: CelTheme.divider(context)),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  // ── Header + period picker ─────────────────────────────────────────────────
  Widget _header(BuildContext c) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Row(
        children: [
          Text(Get.find<LanguageService>().tr('celestial_history_title'), style: CelTheme.title(c)),
          const Spacer(),
          GestureDetector(
            onTap: () => _pickPeriod(c),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: CelTheme.softBg(c),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 13.sp, color: CelTheme.subText(c)),
                  SizedBox(width: 5.w),
                  Text(_periodLabelText(_periodLabel),
                      style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.mainText(c),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700)),
                  SizedBox(width: 4.w),
                  Icon(Icons.keyboard_arrow_down,
                      size: 14.sp, color: CelTheme.subText(c)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickPeriod(BuildContext c) {
    const options = [
      'Today', 'Last Week', 'Last Month',
      'Last Three Months', 'Last Six Months', 'Last Year', 'All History',
    ];
    showModalBottomSheet(
      context: c,
      backgroundColor: CelTheme.card(c),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: options.map((o) {
            final active = o == _periodLabel;
            return ListTile(
              title: Text(_periodLabelText(o),
                  style: AppTextStyles.bodyText.copyWith(
                      color: active ? CelTheme.buy(c) : CelTheme.mainText(c),
                      fontWeight:
                          active ? FontWeight.w800 : FontWeight.w500)),
              trailing:
                  active ? Icon(Icons.check, color: CelTheme.buy(c)) : null,
              onTap: () {
                setState(() => _periodLabel = o);
                Navigator.pop(c);
                _applyPeriod(o);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Summary totals row ─────────────────────────────────────────────────────
  Widget _summaryRow(BuildContext c) {
    return Obx(() {
      // touch tradeHistory to re-render when data loads
      _c.tradeHistory.length;
      final t = _c.tradeHistoryTotals;
      final profit = t?.profit ?? 0;

      Widget cell(String label, String value, {Color? color}) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: CelTheme.label(c)),
            SizedBox(height: 2.h),
            Text(value,
                style: AppTextStyles.bodyText.copyWith(
                    color: color ?? CelTheme.mainText(c),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800)),
          ],
        );
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: cell(TranslationUtils.tr('common_deposit'),
                        _n(t?.deposit))),
                Expanded(
                    child: cell(TranslationUtils.tr('general_withdrawal'),
                        _n(t?.withdrawal))),
                Expanded(
                    child: cell(TranslationUtils.tr('dashboard_profit'),
                        _n(profit),
                        color: profit < 0
                            ? CelTheme.sell(c)
                            : CelTheme.tpGreen)),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                    child: cell(TranslationUtils.tr('dashboard_balance'),
                        _n(t?.balance))),
                Expanded(
                    child: cell(
                        TranslationUtils.tr('general_swap'), _n(t?.swap))),
                Expanded(
                    child: cell(TranslationUtils.tr('general_commission'),
                        _n(t?.commission))),
              ],
            ),
          ],
        ),
      );
    });
  }

  String _n(num? v) => (v ?? 0).toStringAsFixed(2);

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _body(BuildContext c) {
    return RefreshIndicator(
      color: CelTheme.buyBlue,
      onRefresh: refreshHistory,
      child: Obx(() {
      if (_c.isLoadingHistory) {
        return Center(child: CircularProgressIndicator());
      }
      final items = _c.tradeHistory.toList();
      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 56.sp, color: CelTheme.subText(c)),
              SizedBox(height: 8.h),
              Text(
                  Get.find<LanguageService>().tr('celestial_history_no_period',
                      {'period': _periodLabelText(_periodLabel)}),
                  style: AppTextStyles.bodyText.copyWith(
                      color: CelTheme.subText(c),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification &&
              n.metrics.extentAfter < 100 &&
              _c.hasMoreHistoryPages) {
            _c.loadTradeHistory(page: _c.currentHistoryPage + 1);
          }
          return false;
        },
        child: ListView.separated(
          padding: EdgeInsets.only(bottom: 12.h),
          itemCount: items.length + (_c.hasMoreHistoryPages ? 1 : 0),
          separatorBuilder: (_, __) =>
              Divider(color: CelTheme.divider(c), height: 1, thickness: 0.5),
          itemBuilder: (_, i) {
            if (i == items.length) {
              return Center(
                  child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator()));
            }
            return _tradeRow(c, items[i]);
          },
        ),
      );
    }),
    );
  }

  // ── Trade row ──────────────────────────────────────────────────────────────
  Widget _tradeRow(BuildContext c, TradeHistoryItem t) {
    final isBuy = t.tradeType.toUpperCase().contains('BUY');
    final sideColor = isBuy ? CelTheme.buy(c) : CelTheme.sell(c);
    final profit = double.tryParse(t.tradeProfit) ?? 0;
    final plColor = profit >= 0 ? CelTheme.tpGreen : CelTheme.sell(c);
    // Use volumeDisplay for consistent 8-decimal MT5-style formatting (e.g. 0.01000000)
    final vol = t.volume;
    final open = t.tradePriceOrder;
    final close = t.tradePriceClose;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left colour bar
          Container(
            width: 3.w,
            height: 52.h,
            decoration: BoxDecoration(
              color: plColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 10.w),
          // Main info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Symbol + side badge row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(t.tradeSymbol,
                        style: AppTextStyles.bodyText.copyWith(
                            color: CelTheme.mainText(c),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800)),
                    SizedBox(width: 6.w),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: sideColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        '${isBuy ? 'BUY' : 'SELL'} $vol',
                        style: AppTextStyles.bodyText.copyWith(
                            color: sideColor,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                // Open → Close price
                Text(Get.find<LanguageService>().tr('celestial_history_open_close', {'open': '$open', 'close': '$close'}),
                    style: AppTextStyles.bodyText.copyWith(
                        color: CelTheme.subText(c),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 2.h),
                // Open time → Close time
                Text(
                  t.tradeCloseTime.isNotEmpty
                      ? '${t.tradeOpenTime}  →  ${t.tradeCloseTime}'
                      : t.tradeOpenTime,
                  style: AppTextStyles.bodyText.copyWith(
                      color: CelTheme.subText(c),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // P/L
          Text(
            '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(2)}',
            style: AppTextStyles.bodyText.copyWith(
                color: plColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
