import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/models/search_instruments_model.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/trading/view_models/search_instruments_controller.dart';
import 'celestial_theme.dart';

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
          Expanded(child: Text('WatchList', style: CelTheme.title(c))),
          Obx(() => Icon(
                _c.isConnected.value ? Icons.wifi : Icons.wifi_off,
                size: 14.sp,
                color: _c.isConnected.value
                    ? CelTheme.tpGreen
                    : CelTheme.subText(c),
              )),
          SizedBox(width: 4.w),
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
          Text('No favorites yet',
              style: TextStyle(
                  color: CelTheme.mainText(c),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 6.h),
          Text('Tap  🔍  to search and add symbols',
              style: TextStyle(
                  color: CelTheme.subText(c), fontSize: 12.sp)),
        ],
      ),
    );
  }

  // ── Instrument list with column headers ───────────────────────────────────
  Widget _instrumentList(BuildContext c, List<ListElement> items,
      {required bool showStar}) {
    return Column(
      children: [
        // Column header row
        Padding(
          padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 4.h),
          child: Row(
            children: [
              // Symbol column
              SizedBox(
                width: 110.w,
                child: Text('SYMBOL',
                    style: TextStyle(
                        color: CelTheme.subText(c),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              const Spacer(),
              // BID header
              SizedBox(
                width: 94.w,
                child: Text('BID',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: CelTheme.sell(c),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              // ASK header
              SizedBox(
                width: 94.w,
                child: Text('ASK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: CelTheme.buy(c),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              if (showStar) SizedBox(width: 28.w),
            ],
          ),
        ),
        Divider(
            height: 1, thickness: 0.5, color: CelTheme.divider(c)),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(bottom: 12.h),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
                color: CelTheme.divider(c), height: 1, thickness: 0.5),
            itemBuilder: (_, i) =>
                _row(c, items[i], showStar: showStar),
          ),
        ),
      ],
    );
  }

  // ── Single instrument row ─────────────────────────────────────────────────
  Widget _row(BuildContext c, ListElement item, {required bool showStar}) {
    return Obx(() {
      final price = _c.priceRx(item.symbol).value;
      final digits = price.digits > 0 ? price.digits : item.digits;

      // Change vs mid of day range
      final mid = (price.dayHigh + price.dayLow) / 2;
      final change = mid == 0 ? 0.0 : price.ask - mid;
      final pct = mid == 0 ? 0.0 : (change / mid) * 100;
      final up = change >= 0;
      final changeColor = up ? CelTheme.buy(c) : CelTheme.sell(c);

      return InkWell(
        onTap: () => _onSymbolTap(item.symbol),
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Left block: change% + symbol name + spread ────────────
              SizedBox(
                width: 110.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Change — clipped, never overflows
                    Text(
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%'
                      ' ${change >= 0 ? '+' : ''}${change.toStringAsFixed(digits)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: changeColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      item.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: CelTheme.mainText(c),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Spread ${price.spreadDiff.round()}',
                      style: TextStyle(
                          color: CelTheme.subText(c), fontSize: 10.sp),
                    ),
                  ],
                ),
              ),

              // ── Spacer pushes BID/ASK to the right ───────────────────
              const Spacer(),

              // ── BID column ────────────────────────────────────────────
              SizedBox(
                width: 94.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _fractionPrice(
                        c,
                        price.bid.toStringAsFixed(digits),
                        CelTheme.sell(c)),
                    SizedBox(height: 2.h),
                    Text(
                      'L ${price.dayLow.toStringAsFixed(digits)}',
                      style: TextStyle(
                          color: CelTheme.subText(c), fontSize: 9.sp),
                    ),
                  ],
                ),
              ),

              // ── ASK column ────────────────────────────────────────────
              SizedBox(
                width: 94.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _fractionPrice(
                        c,
                        price.ask.toStringAsFixed(digits),
                        CelTheme.buy(c)),
                    SizedBox(height: 2.h),
                    Text(
                      'H ${price.dayHigh.toStringAsFixed(digits)}',
                      style: TextStyle(
                          color: CelTheme.subText(c), fontSize: 9.sp),
                    ),
                  ],
                ),
              ),

              // ── Star toggle (catalog tabs only) ───────────────────────
              if (showStar)
                Obx(() {
                  final isFav = _c.isFavorite(item.symbol);
                  return GestureDetector(
                    onTap: () => _c.toggleFavorite(item.symbol),
                    child: Padding(
                      padding: EdgeInsets.only(left: 6.w),
                      child: Icon(
                        isFav
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18.sp,
                        color: isFav
                            ? CelTheme.accentYellow
                            : CelTheme.subText(c),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    });
  }

  /// MT5-style: last 2 digits rendered bigger
  Widget _fractionPrice(BuildContext c, String value, Color color) {
    if (value.length < 3) {
      return Text(value,
          style: CelTheme.bigPrice(c, color: color)
              .copyWith(fontSize: 16.sp));
    }
    final dotIdx = value.indexOf('.');
    if (dotIdx < 0 || dotIdx >= value.length - 2) {
      return Text(value,
          style: CelTheme.bigPrice(c, color: color)
              .copyWith(fontSize: 16.sp));
    }
    final head = value.substring(0, value.length - 2);
    final tail = value.substring(value.length - 2);
    return RichText(
      text: TextSpan(children: [
        TextSpan(
            text: head,
            style: CelTheme.bigPrice(c, color: color)
                .copyWith(fontSize: 14.sp)),
        TextSpan(
            text: tail,
            style: CelTheme.bigPrice(c, color: color)
                .copyWith(
                    fontSize: 18.sp, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  // ── Search sheet ──────────────────────────────────────────────────────────
  void _openSearchSheet(BuildContext c) {
    showModalBottomSheet(
      context: c,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: CelTheme.card(c),
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (_) => _SearchSheet(
        ic: _c,
        onTap: _onSymbolTap,
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
  SearchInstrumentsController get _sic =>
      Get.find<SearchInstrumentsController>();

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
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Drag handle
          Container(
            margin: EdgeInsets.only(top: 8.h, bottom: 4.h),
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: CelTheme.divider(c),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          // Title
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Search symbol',
                  style: CelTheme.title(c).copyWith(fontSize: 18.sp)),
            ),
          ),
          // Search field
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
            child: TextField(
              controller: _ctrl,
              autofocus: false,
              onChanged: (v) {
                _sic.searchInstruments(v);
                setState(() {}); // refresh clear button
              },
              style: TextStyle(color: CelTheme.mainText(c)),
              decoration: InputDecoration(
                hintText: 'Type a symbol e.g. XAUUSD',
                hintStyle: TextStyle(color: CelTheme.subText(c)),
                prefixIcon:
                    Icon(Icons.search, color: CelTheme.subText(c)),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: CelTheme.subText(c)),
                        onPressed: () {
                          _ctrl.clear();
                          _sic.searchInstruments('');
                          setState(() {});
                        })
                    : null,
                filled: true,
                fillColor: CelTheme.softBg(c),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          // Category tabs — hidden when user is actively typing a search query
          Obx(() {
            if (_sic.searchQuery.value.isNotEmpty) return const SizedBox.shrink();
            return _categoryTabs(c);
          }),
          Divider(
              height: 1,
              thickness: 0.5,
              color: CelTheme.divider(c)),
          // Results — fills remaining sheet, scrollable
          Expanded(
            child: Obx(() {
              final results = _sic.filteredSymbols;
              if (_sic.isLoading.value && results.isEmpty) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              if (results.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.h),
                    child: Text('No results',
                        style: TextStyle(
                            color: CelTheme.subText(c),
                            fontSize: 13.sp)),
                  ),
                );
              }
              return ListView.separated(
                controller: scrollCtrl,
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
    );
  }

  Widget _categoryTabs(BuildContext c) {
    return Obx(() {
      final categories = _sic.availableCategories;
      final current = _sic.currentCategory.value;
      return SizedBox(
        height: 42.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          itemCount: categories.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (_, i) {
            final cat = categories[i];
            final active = cat == current;
            return GestureDetector(
              onTap: () => _sic.filterByCategory(cat),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: active ? CelTheme.buy(c) : CelTheme.softBg(c),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: active ? Colors.white : CelTheme.subText(c),
                    fontSize: 12.sp,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
    // Show first 3 letters of the symbol as a text avatar
    final initials = symbol.length >= 3 ? symbol.substring(0, 3) : symbol;
    return ListTile(
      contentPadding:
          EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      leading: Container(
        width: 40.w,
        height: 40.h,
        decoration: BoxDecoration(
          color: CelTheme.buyTint(c),
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: CelTheme.buy(c),
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      title: Text(symbol,
          style: TextStyle(
              color: CelTheme.mainText(c),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700)),
      subtitle: Text(s.categoryName,
          style: TextStyle(
              color: CelTheme.subText(c), fontSize: 11.sp)),
      // Star: tap → subscribe + add to favorites (exact same as old code)
      trailing: GestureDetector(
        onTap: () => widget.ic.toggleFavorite(
          symbol,
          searchSymbol: s,
          hydrateAfterChange: true,
        ),
        child: Obx(() {
          final isFav = widget.ic.isFavorite(symbol);
          return Icon(
            isFav ? Icons.star_rounded : Icons.star_outline_rounded,
            color:
                isFav ? CelTheme.accentYellow : CelTheme.subText(c),
            size: 22.sp,
          );
        }),
      ),
      onTap: () {
        Navigator.pop(c);
        widget.onTap(symbol);
      },
    );
  }
}
