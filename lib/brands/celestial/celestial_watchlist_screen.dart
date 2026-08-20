import 'package:flutter/material.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/models/search_instruments_model.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/search_instruments_controller.dart';
import 'celestial_theme.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'celestial_trade_screen.dart';

// SearchInstrumentsController is lazily registered here so the search sheet
// can always find it via Get.find(), regardless of which route opened this screen.

class CelestialWatchlistScreen extends StatefulWidget {
  final ValueChanged<String>? onSymbolTap;
  const CelestialWatchlistScreen({super.key, this.onSymbolTap});

  @override
  State<CelestialWatchlistScreen> createState() =>
      _CelestialWatchlistScreenState();
}

class _CelestialWatchlistScreenState
    extends State<CelestialWatchlistScreen> {
  InstrumentsController get _c => Get.find<InstrumentsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.startWebSocket();
      // Register SearchInstrumentsController if not already registered,
      // so the search bottom sheet can always find it.
      if (!Get.isRegistered<SearchInstrumentsController>()) {
        Get.put(SearchInstrumentsController());
      }
    });
  }

  void _onSymbolTap(String symbol) {
    try {
      Get.find<ChartSocketController>().currentSymbol.value = symbol;
    } catch (_) {}
    widget.onSymbolTap?.call(symbol);
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
            Expanded(child: _favoritesBody(context)),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(BuildContext c) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 4.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              Get.find<LanguageService>().tr('celestial_watchlist_title'),
              style: AppTextStyles.bodyText.copyWith(
                color: CelTheme.headerText(c),
                fontSize: 22.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search,
                color: CelTheme.mainText(c), size: 22.sp),
            onPressed: () => _openSearchSheet(c),
          ),
        ],
      ),
    );
  }

  // ── Favorites-only body ───────────────────────────────────────────────────
  Widget _favoritesBody(BuildContext c) {
    return Obx(() {
      final items = _c.instruments.toList();
      if (items.isEmpty) {
        return _emptyFavorites(c);
      }
      return _instrumentList(c, items, showStar: false);
    });
  }

  // ── Empty states ──────────────────────────────────────────────────────────
  Widget _emptyFavorites(BuildContext c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline_rounded,
              size: 52.sp, color: CelTheme.subText(c)),
          SizedBox(height: 10.h),
          Text(Get.find<LanguageService>().tr('celestial_watchlist_no_favorites'),
              style: AppTextStyles.bodyText.copyWith(
                  color: CelTheme.mainText(c),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 6.h),
          Text(Get.find<LanguageService>().tr('celestial_watchlist_search_hint'),
              style: AppTextStyles.bodyText.copyWith(
                  color: CelTheme.subText(c), fontSize: 12.sp)),
        ],
      ),
    );
  }

  // ── Instrument list — no column headers (matches screenshot) ──────────────
  Widget _instrumentList(BuildContext c, List<ListElement> items,
      {required bool showStar}) {
    return ListView.separated(
      padding: EdgeInsets.only(bottom: 8.h),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
          color: CelTheme.divider(c), height: 1, thickness: 0.5),
      itemBuilder: (_, i) =>
          _row(c, items[i], showStar: showStar),
    );
  }

  // ── Single instrument row — matches Screenshot 3 layout ─────────────────
  //  change% / SYMBOL / time+sync      |  BID / L  |  ASK / H
  Widget _row(BuildContext c, ListElement item, {required bool showStar}) {
    return Obx(() {
      final price = _c.priceRx(item.symbol).value;
      final digits = price.digits > 0 ? price.digits : item.digits;

      // Change vs mid of day range
      final mid = (price.dayHigh + price.dayLow) / 2;
      final change = mid == 0 ? 0.0 : price.ask - mid;
      final pct = mid == 0 ? 0.0 : (change / mid) * 100;
      // green when up, red when down, app/neutral color when unchanged
      final changeColor = change > 0
          ? CelTheme.buy(c)
          : change < 0
              ? CelTheme.sell(c)
              : CelTheme.mainText(c);

      return InkWell(
        onTap: () => _onSymbolTap(item.symbol),
        onLongPress: () {
          final accountController = Get.find<AccountController>();
          final tradingController = Get.find<TradingController>();
          showModalBottomSheet(
            context: c,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CelestialOrderTicket(
              symbol: item.symbol,
              canChangeSymbol: false,
              bid: price.bid,
              ask: price.ask,
              digits: digits,
              onSubmit: (selectedSymbol, isSell, type, volume, priceStr, tp, sl) {
                final activeAccount = accountController.activeMT5Account;
                if (activeAccount == null || activeAccount.metaAccountNumber.isEmpty) {
                  if (Get.isRegistered<AppNotificationController>()) {
                    Get.find<AppNotificationController>().showError(
                      title: 'Error',
                      message: 'No active trading account found',
                    );
                  }
                  return Future.value(false);
                }
                return tradingController.placeTradeOrder(
                  mt5Account: activeAccount.metaAccountNumber,
                  symbol: selectedSymbol,
                  volume: volume.toStringAsFixed(2),
                  orderType: type,
                  price: priceStr,
                  takeProfit: tp,
                  stopLoss: sl,
                );
              },
            ),
          );
        },
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Left block: change% + symbol + (time + tick) ──────────
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%'
                      '  ${change >= 0 ? '+' : ''}${change.toStringAsFixed(digits)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                          color: changeColor,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      item.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.headerText(c),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // ── BID column ────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _fractionPrice(
                        c, price.bid, digits, CelTheme.sell(c)),
                    SizedBox(height: 1.h),
                    Text(
                      'L: ${price.dayLow.toStringAsFixed(digits)}',
                      style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.subText(c), fontSize: 10.sp),
                    ),
                  ],
                ),
              ),

              // ── SPREAD & ASK column (Combined for visual centering) ───────────
              Expanded(
                flex: 4,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Spread text takes all available empty space and centers itself
                    Expanded(
                      child: Container(
                        alignment: Alignment.bottomCenter,
                        padding: EdgeInsets.only(top: 18.h),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: CelTheme.subText(c).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            price.spreadDiff.toInt().toString(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyText.copyWith(
                                color: CelTheme.subText(c), fontSize: 10.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    // ASK column shrink-wraps and stays on the right
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _fractionPrice(
                            c, price.ask, digits, CelTheme.tpGreen),
                        SizedBox(height: 1.h),
                        Text(
                          'H: ${price.dayHigh.toStringAsFixed(digits)}',
                          style: AppTextStyles.bodyText.copyWith(
                              color: CelTheme.subText(c), fontSize: 10.sp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Mirrors crmapp instruments_screen.dart:_buildPriceTextSpans exactly.
  /// Renders a price like "0.69796" as:
  ///   "0." at 14sp/w500  (prefix = chars before last 2)
  ///   "97" at 20sp/bold  (bigPart = last 2 chars)
  ///   "6"  at 10sp raised-11 via WidgetSpan + Transform.translate (lastDigit)
  Widget _fractionPrice(BuildContext c, dynamic price, int digits, Color color) {
    final priceStr = price.toStringAsFixed(digits);

    if (priceStr.length < 3) {
      return Text(priceStr,
          style: AppTextStyles.bodyText.copyWith(
              color: color, fontSize: 15.sp, fontWeight: FontWeight.w500));
    }

    final lastDigit = priceStr.substring(priceStr.length - 1);
    final bigPart = priceStr.substring(priceStr.length - 3, priceStr.length - 1);
    final prefix = priceStr.substring(0, priceStr.length - 3);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
              text: prefix,
              style: AppTextStyles.bodyText.copyWith(
                  color: color, fontSize: 14.sp, fontWeight: FontWeight.w500)),
          TextSpan(
              text: bigPart,
              style: AppTextStyles.bodyText.copyWith(
                  color: color, fontSize: 20.sp, fontWeight: FontWeight.w700)),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Transform.translate(
              offset: const Offset(0, -11),
              child: Text(
                lastDigit,
                style: AppTextStyles.bodyText.copyWith(
                    color: color, fontSize: 10.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search sheet ──────────────────────────────────────────────────────────
  void _openSearchSheet(BuildContext c) {
    Navigator.of(c).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black.withValues(alpha: 0.0),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => _SearchSheet(
          ic: _c,
          onTap: _onSymbolTap,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Sheet
// Uses SearchInstrumentsController.filteredSymbols
// Star tap → toggleFavorite(symbol, searchSymbol: s, hydrateAfterChange: true)
// ─────────────────────────────────────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final InstrumentsController ic;
  final ValueChanged<String> onTap;
  const _SearchSheet({required this.ic, required this.onTap});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _ctrl = TextEditingController();
  SearchInstrumentsController get _sic => Get.find<SearchInstrumentsController>();

  LanguageService get languageService => Get.find<LanguageService>();

  @override
  void initState() {
    super.initState();
    // Load full list on open
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _sic.searchInstruments(''));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: CelTheme.bg(c),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: search field + X close ─────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 4.h),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: (v) {
                        _sic.searchInstruments(v);
                        setState(() {});
                      },
                      style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.mainText(c), fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: Get.find<LanguageService>().tr('celestial_watchlist_search_btn'),
                        hintStyle: AppTextStyles.bodyText.copyWith(
                            color: CelTheme.subText(c), fontSize: 14.sp),
                        prefixIcon: Icon(Icons.search,
                            color: CelTheme.subText(c), size: 20.sp),
                        suffixIcon: _ctrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close,
                                    color: CelTheme.subText(c), size: 18.sp),
                                onPressed: () {
                                  _ctrl.clear();
                                  _sic.searchInstruments('');
                                  setState(() {});
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 10.h),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: CelTheme.divider(c), width: 0.5),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: CelTheme.subText(c), width: 0.5),
                        ),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: CelTheme.divider(c), width: 0.5),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: CelTheme.mainText(c), size: 22.sp),
                    onPressed: () => Navigator.of(c).pop(),
                  ),
                ],
              ),
            ),
            // ── Category tabs (underline style) ─────────────────────────
            _categoryTabs(c),
            // ── Results list ────────────────────────────────────────────
            Expanded(
              child: Obx(() {
                final results = _sic.filteredSymbols;
                if (_sic.isLoading.value && results.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }
                if (results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.h),
                      child: Text(Get.find<LanguageService>().tr('celestial_watchlist_no_results'),
                          style: AppTextStyles.bodyText.copyWith(
                              color: CelTheme.subText(c), fontSize: 13.sp)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.only(bottom: 16.h),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => Divider(
                      color: CelTheme.divider(c),
                      height: 1,
                      thickness: 0.5),
                  itemBuilder: (_, i) {
                    final SearchSymbol s = results[i];
                    final symbol = s.displaySymbol;
                    return _searchRow(c, s, symbol);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTabs(BuildContext c) {
    return Obx(() {
      final categories = _sic.availableCategories;
      final current = _sic.currentCategory.value;
      return SizedBox(
        height: 38.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          itemCount: categories.length,
          separatorBuilder: (_, __) => SizedBox(width: 18.w),
          itemBuilder: (_, i) {
            final cat = categories[i];
            final active = cat == current;
            return GestureDetector(
              onTap: () => _sic.filterByCategory(cat),
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active
                          ? CelTheme.mainText(c)
                          : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Text(
                  cat,
                  style: AppTextStyles.bodyText.copyWith(
                    color: active
                        ? CelTheme.mainText(c)
                        : CelTheme.subText(c),
                    fontSize: 14.sp,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _searchRow(BuildContext c, SearchSymbol s, String symbol) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(c).pop();
        widget.onTap(symbol);
      },
      child: Row(
        children: [
          // ── Add / Added circular toggle on the LEFT ───────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.ic.toggleFavorite(
              symbol,
              searchSymbol: s,
              hydrateAfterChange: true,
            ),
            child: Container(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 16.h, bottom: 16.h),
              color: Colors.transparent,
              child: Obx(() {
                final isFav = widget.ic.isFavorite(symbol);
                if (isFav) {
                  return Container(
                    width: 22.w,
                    height: 22.w,
                    decoration: const BoxDecoration(
                      color: CelTheme.tpGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.check,
                        color: Colors.white, size: 14.sp),
                  );
                }
                return Icon(Icons.add,
                    color: CelTheme.mainText(c).withValues(alpha: 0.8), size: 24.sp);
              }),
            ),
          ),
          // ── Symbol + description ──────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 16.w, top: 12.h, bottom: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.headerText(c),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500)),
                  Text(s.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                          color: CelTheme.subText(c), fontSize: 11.sp)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
