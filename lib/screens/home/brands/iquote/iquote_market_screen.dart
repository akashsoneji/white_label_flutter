import 'dart:async';

import 'package:crm_app/screens/home/brands/iquote/iquote_chart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/socket_response.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/chart_socket_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/screens/home/search_instruments_screen.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/symbol_selection_service.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/dashboard_bottom_sheet.dart';

const _kSparklinePoints = 60;

class IquoteMarketScreen extends StatefulWidget {
  final void Function(String)? onNavigateToChart;

  const IquoteMarketScreen({super.key, this.onNavigateToChart});

  @override
  State<IquoteMarketScreen> createState() => _IquoteMarketScreenState();
}

class _IquoteMarketScreenState extends State<IquoteMarketScreen> {
  late final InstrumentsController _ic;
  late final ChartSocketController _socket;
  late final LanguageService _ls;
  late final SymbolSelectionService _sym;
  late final AccountController _accountCtrl;

  StreamSubscription<Map<String, dynamic>>? _tickSub;
  final Map<String, List<double>> _bidHistory = {};

  @override
  void initState() {
    super.initState();
    _ic = Get.find<InstrumentsController>();
    if (Get.isRegistered<ChartSocketController>()) {
      _socket = Get.find<ChartSocketController>();
      _tickSub = _socket.priceStream.listen(_onTick);
    }
    _ls = Get.put(LanguageService());
    _sym = Get.put(SymbolSelectionService(), permanent: true);
    _accountCtrl = Get.find<AccountController>();

    _ic.markInitialScreenOpening();

    for (final e in _ic.instruments) {
      final key = _stripSuffix(e.symbol);
      if (e.bid > 0 && !_bidHistory.containsKey(key)) {
        _bidHistory[key] = List<double>.filled(
          _kSparklinePoints,
          e.bid,
          growable: true,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final deadline = DateTime.now().add(const Duration(milliseconds: 400));
      while (_ic.isLoadingFavorites.value &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      try {
        await _ic.startMarketWatchV2Only();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    super.dispose();
  }

  void _onTick(Map<String, dynamic> m) {
    final sym = m['symbol']?.toString();
    if (sym == null || sym.isEmpty) return;
    final raw = m['bid'] ?? m['Bid'];
    if (raw == null) return;
    final bid = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (bid == null || bid <= 0) return;
    final key = _stripSuffix(sym);
    final hist = _bidHistory.putIfAbsent(key, () => <double>[]);
    hist.add(bid);
    if (hist.length > _kSparklinePoints) hist.removeAt(0);
    if (mounted) setState(() {});
  }

  static String _stripSuffix(String s) =>
      s.contains('.') ? s.substring(0, s.lastIndexOf('.')) : s;

  String _selectedTab = 'Hot';
  static const _tabs = [
    'Hot',
    'Crypto',
    'Commodity',
    'Indices',
    'Forex',
    'Stocks',
  ];

  void _showAccountBottomSheet(BuildContext context) {
    showDashboardBottomSheet(context);
  }

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SearchInstrumentsScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgDark = AppColors.background;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            SizedBox(height: 6.h),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final isDark = AppColors.isDarkMode;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Active Account Selector (Account Number + LIVE/DEMO Badge)
          GestureDetector(
            onTap: () => _showAccountBottomSheet(context),
            child: Obx(() {
              final active = _accountCtrl.activeMT5Account;
              final accNumber = active?.metaAccountNumber ?? '------';
              final rawType = (active?.accountType ?? 'REAL').toUpperCase();
              final isDemo = rawType == 'DEMO';
              final badgeLabel = isDemo ? 'DEMO' : 'LIVE';

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF252C41)
                          : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white12
                            : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$accNumber',
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDemo
                                ? Colors.orange.withValues(alpha: 0.18)
                                : Colors.green.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        badgeLabel,
                        style: AppTextStyles.bodyText.copyWith(
                          color: isDemo ? Colors.orange : Colors.green,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18.r,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              );
            }),
          ),

          // Right: Search Button
          IconButton(
            onPressed: _openSearchSheet,
            icon: Icon(
              Icons.search_rounded,
              size: 22.r,
              color: AppColors.textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _selectTab(String tab) {
    setState(() {
      _selectedTab = tab;
      if (tab == 'Hot') {
        _ic.filterInstruments('Hot');
      } else {
        _ic.filterInstruments(tab);
      }
    });
  }

  Widget _buildTabBar() {
    final activeColor = AppColors.primary;
    final textSecondary = AppColors.textSecondary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children:
            _tabs.map((tab) {
              final selected = tab == _selectedTab;
              return Padding(
                padding: EdgeInsets.only(right: 18.w),
                child: GestureDetector(
                  onTap: () => _selectTab(tab),
                  child: Column(
                    children: [
                      Text(
                        tab,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14.sp,
                          color: selected ? activeColor : textSecondary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      if (selected)
                        Container(
                          width: 24.w,
                          height: 3.h,
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildList() {
    return Obx(() {
      final list =
          _ic.instruments.isNotEmpty ? _ic.instruments : _ic.allInstruments;

      if (list.isEmpty) {
        return Center(
          child: CommonLoadingWidget(
            message: 'Loading...',
            size: 40,
            color: AppColors.primary,
          ),
        );
      }

      return ListView.builder(
        // padding: EdgeInsets.only(top: 10.h, bottom: 10.h),
        itemCount: list.length,
        itemBuilder: (context, i) {
          return _IquoteInstrumentRow(
            instrument: list[i],
            bidHistory: _bidHistory,
            controller: _ic,
            onTap: (sym) {
              if (widget.onNavigateToChart != null) {
                widget.onNavigateToChart!(sym);
              } else {
                Get.to(() => IQuoteChartScreen(symbol: sym));
              }
            },
          );
        },
      );
    });
  }

  bool _matchesBroaderCategory(ListElement e, String tab) {
    final sym = e.symbol.toLowerCase();
    switch (tab) {
      case 'forex':
        return sym.contains('usd') ||
            sym.contains('eur') ||
            sym.contains('gbp') ||
            sym.contains('jpy') ||
            sym.contains('aud') ||
            sym.contains('nzd') ||
            sym.contains('cad') ||
            sym.contains('chf');
      case 'crypto':
        return sym.contains('btc') ||
            sym.contains('eth') ||
            sym.contains('usdt') ||
            sym.contains('bnb') ||
            sym.contains('xrp');
      case 'commodity':
        return sym.contains('xau') ||
            sym.contains('xag') ||
            sym.contains('usoil') ||
            sym.contains('ukoil') ||
            sym.contains('wti') ||
            sym.contains('brent');
      case 'indices':
        return sym.contains('us30') ||
            sym.contains('us500') ||
            sym.contains('nas') ||
            sym.contains('de40') ||
            sym.contains('uk100') ||
            sym.contains('fr40') ||
            sym.contains('jp225') ||
            sym.contains('au200') ||
            sym.contains('es35') ||
            sym.contains('ut100') ||
            sym.contains('hk50') ||
            sym.contains('eu50');
      case 'stocks':
        return sym.contains('.') &&
            !sym.contains('usd') &&
            !sym.contains('usdt');
      default:
        return false;
    }
  }
}

class _IquoteInstrumentRow extends StatelessWidget {
  final ListElement instrument;
  final Map<String, List<double>> bidHistory;
  final InstrumentsController controller;
  final void Function(String)? onTap;

  const _IquoteInstrumentRow({
    required this.instrument,
    required this.bidHistory,
    required this.controller,
    this.onTap,
  });

  String _formatSymbolName(String sym) {
    final clean = sym.replaceAll('.c', '').toUpperCase();
    if (clean.length == 6) {
      return '${clean.substring(0, 3)}/${clean.substring(3)}';
    }
    if (clean.length == 7 && clean.endsWith('USDT')) {
      return '${clean.substring(0, 3)}/USDT';
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final sym = instrument.symbol;
    final displaySym =
        sym.contains('.') ? sym.substring(0, sym.lastIndexOf('.')) : sym;
    final digits = instrument.digits;
    final key = _IquoteMarketScreenState._stripSuffix(sym);
    final isDark = AppColors.isDarkMode;

    return Obx(() {
      final livePrice = controller.priceRx(sym).value;
      final hist = bidHistory[key] ?? <double>[];

      if (livePrice.bid > 0) {
        if (hist.isEmpty || (hist.last - livePrice.bid).abs() > 1e-7) {
          final list = bidHistory.putIfAbsent(key, () => <double>[]);
          list.add(livePrice.bid);
          if (list.length > _kSparklinePoints) list.removeAt(0);
        }
      }

      double currentBid =
          livePrice.bid > 0
              ? livePrice.bid
              : (hist.isNotEmpty ? hist.last : instrument.bid);
      if (currentBid <= 0) {
        currentBid =
            (instrument.dayLow != null && instrument.dayLow! > 0)
                ? instrument.dayLow!
                : 1.0;
      }

      double currentAsk =
          livePrice.ask > 0
              ? livePrice.ask
              : (hist.isNotEmpty
                  ? (hist.last + instrument.spreadDiff)
                  : instrument.ask);
      if (currentAsk <= 0) {
        currentAsk = currentBid + 0.0002;
      }

      final spread =
          livePrice.spreadDiff > 0
              ? livePrice.spreadDiff
              : instrument.spreadDiff;
      final spreadText =
          spread > 0
              ? (spread > 1
                  ? spread.toStringAsFixed(0)
                  : spread.toStringAsFixed(digits > 3 ? 4 : 2))
              : '0';

      final dayLow =
          livePrice.dayLow > 0 ? livePrice.dayLow : (instrument.dayLow ?? 0.0);
      final changeVal = dayLow > 0 ? (currentBid - dayLow) : 0.0;
      final changePct =
          dayLow > 0 ? ((currentBid - dayLow) / dayLow * 100) : 0.0;
      final isUp = changePct >= 0;

      final changeColor =
          isUp ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
      final String valSign = isUp ? '↑' : '↓';
      final String pctSign = isUp ? '+' : '-';
      final changeStr =
          '$valSign${changeVal.abs().toStringAsFixed(digits.clamp(1, 4))} ($pctSign${changePct.abs().toStringAsFixed(2)}%)';

      return GestureDetector(
        onTap: () => onTap?.call(sym),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Symbol Icon + Info
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _FlagIcon(symbol: displaySym),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        _formatSymbolName(sym),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Right: Prices & Spreads & Changes
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Change text
                  Text(
                    changeStr,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 10.5.sp,
                      color: changeColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  // Buy/Sell side-by-side with overlapping center spread badge
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Buy Button (Green)
                          Container(
                            width: 68.w,
                            height: 34.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(6.r),
                                bottomLeft: Radius.circular(6.r),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Buy',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  currentAsk.toStringAsFixed(
                                    digits.clamp(0, 5),
                                  ),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 1.w),
                          // Sell Button (Red)
                          Container(
                            width: 68.w,
                            height: 34.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(6.r),
                                bottomRight: Radius.circular(6.r),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sell',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  currentBid.toStringAsFixed(
                                    digits.clamp(0, 5),
                                  ),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Overlay Spread Oval Badge in Center
                      Positioned(
                        top: 3.h,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: Colors.white24,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            spreadText,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  // Spread Cost
                  Text(
                    '\$${spread.toStringAsFixed(digits.clamp(1, 4))}',
                    style: TextStyle(
                      color: const Color(0xFF22C55E),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _FlagIcon extends StatelessWidget {
  final String symbol;
  const _FlagIcon({required this.symbol});

  @override
  Widget build(BuildContext context) {
    String clean =
        symbol.contains('.')
            ? symbol.substring(0, symbol.lastIndexOf('.'))
            : symbol;
    String primaryCurr =
        clean.length >= 3
            ? clean.substring(0, 3).toLowerCase()
            : clean.toLowerCase();

    final flagPath1 = 'assets/svg/flags/${clean.toLowerCase()}.svg';
    final flagPath2 = 'assets/svg/flags/$primaryCurr.svg';

    return SizedBox(
      width: 32.w,
      height: 32.w,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Padding(
            padding: EdgeInsets.all(3.r),
            child: SvgPicture.asset(
              flagPath1,
              fit: BoxFit.cover,
              placeholderBuilder:
                  (_) => SvgPicture.asset(
                    flagPath2,
                    fit: BoxFit.cover,
                    placeholderBuilder:
                        (_) => Center(
                          child: Text(
                            clean.isNotEmpty ? clean[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
