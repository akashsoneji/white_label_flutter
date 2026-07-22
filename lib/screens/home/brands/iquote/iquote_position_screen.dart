import 'dart:async';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/account_websocket_service.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/utils/date_helper.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/home/close_position_screen.dart';
import 'package:crm_app/screens/home/edit_order_screen.dart';
import 'package:crm_app/screens/home/brands/iquote/iquote_order_details_screen.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/deposit_screen.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/screens/home/brands/iquote/history_filter_sheet.dart';

class IQuotePositionScreen extends StatefulWidget {
  final Function(String)? onNavigateToChart;

  const IQuotePositionScreen({super.key, this.onNavigateToChart});

  @override
  State<IQuotePositionScreen> createState() => _IQuotePositionScreenState();
}

class _IQuotePositionScreenState extends State<IQuotePositionScreen> {
  Color get _bgColor => AppColors.background;
  Color get _cardColor => AppColors.card;
  Color get _chipBgColor => AppColors.isDarkMode
      ? const Color(0xFF333950)
      : AppColors.primary.withValues(alpha: 0.12);
  Color get _accent => AppColors.primary;
  Color get _green => AppColors.statusGreen;
  Color get _red => AppColors.statusRed;
  Color get _textPrimary => AppColors.textPrimary;
  Color get _textSecondary => AppColors.textSecondary;
  Color get _textMuted => AppColors.isDarkMode
      ? Colors.white38
      : AppColors.textSecondary.withValues(alpha: 0.6);

  final LanguageService languageService = Get.find<LanguageService>();

  late ScrollController _scrollController;
  bool _isLoadingMore = false;
  StreamSubscription? _accountChangeSubscription;
  String? _lastAccountNumber;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _initializeWebSocketServices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<TradingController>()) return;
      final tradingController = Get.find<TradingController>();
      if (tradingController.selectedTab != 0) {
        tradingController.setSelectedTab(0);
      }
      _initializeTradeScreenWebSockets();
      _listenForAccountChanges();
    });
  }

  void _initializeWebSocketServices() {
    if (!Get.isRegistered<TradingWebSocketService>()) {
      Get.put(TradingWebSocketService(), permanent: true);
    }
    if (!Get.isRegistered<AccountWebSocketService>()) {
      Get.put(AccountWebSocketService(), permanent: true);
    }
  }

  void _initializeTradeScreenWebSockets() {
    try {
      if (Get.isRegistered<TradingWebSocketService>()) {
        final wsService = Get.find<TradingWebSocketService>();
        wsService.ensureOpenPositionsConnection();
        wsService.ensurePendingOrdersConnection();
      }
    } catch (e) {
      if (kDebugMode) print('IQuotePosition: WS init error: $e');
    }
  }

  void _listenForAccountChanges() {
    try {
      final accountController = Get.find<AccountController>();
      _lastAccountNumber = accountController.activeMT5Account?.metaAccountNumber;
      _accountChangeSubscription?.cancel();
      _accountChangeSubscription =
          accountController.activeMT5AccountRx.listen((account) {
        if (!mounted) return;
        final newAccountNumber = account?.metaAccountNumber;
        if (newAccountNumber != null && newAccountNumber != _lastAccountNumber) {
          _lastAccountNumber = newAccountNumber;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              if (Get.isRegistered<TradingController>()) {
                Get.find<TradingController>().clearAllTradingData();
              }
              _initializeTradeScreenWebSockets();
              if (mounted) setState(() {});
            } catch (e) {
              if (kDebugMode) print('IQuotePosition: account switch error: $e');
            }
          });
        }
      });
    } catch (e) {
      if (kDebugMode) print('IQuotePosition: account listener error: $e');
    }
  }

  @override
  void dispose() {
    _accountChangeSubscription?.cancel();
    _accountChangeSubscription = null;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    final tradingController = Get.find<TradingController>();
    if (tradingController.selectedTab == 2 && max > 0 && current >= max - 200) {
      _loadMoreIfNeeded();
    }
  }

  void _loadMoreIfNeeded() {
    final tradingController = Get.find<TradingController>();
    if (tradingController.selectedTab == 2 &&
        !_isLoadingMore &&
        !tradingController.isLoadingHistory &&
        tradingController.hasMoreHistoryPages) {
      _isLoadingMore = true;
      tradingController.loadNextPage().then((_) {
        if (mounted) _isLoadingMore = false;
      }).catchError((_) {
        if (mounted) _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFromRealStrip(),
            SizedBox(height: 8.h),
            _buildPillTabs(),
            _buildDateFilter(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GetBuilder<TradingController>(
      id: 'account_info',
      builder: (tradingController) {
        final accountInfo = tradingController.accountInfo;
        final balance = accountInfo?.balance ?? 0.00;
        final profit = accountInfo?.profit ?? 0.00;
        final marginLevel = accountInfo?.marginLevel ?? 0.00;
        final isProfitPositive = profit >= 0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // DEMO / LIVE chip → opens Switch Account sheet
                  InkWell(
                    borderRadius: BorderRadius.circular(6.r),
                    onTap: _openSwitchAccountSheet,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        color: _chipBgColor,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activeAccountLabel(),
                            style: AppTextStyles.bodyText.copyWith(
                              color: _textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.sp,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.arrow_drop_down,
                              color: _textPrimary, size: 18.sp),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Text(
                    balance.toStringAsFixed(4),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${isProfitPositive ? '' : '-'}${profit.abs().toStringAsFixed(4)}(${marginLevel.toStringAsFixed(2)}%)',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isProfitPositive ? _green : _red,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              _buildMarginBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarginBar() {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Container(
            height: 3.h,
            decoration: BoxDecoration(
              color: _green,
              borderRadius:
                  BorderRadius.horizontal(left: Radius.circular(2.r)),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(height: 3.h, color: _accent),
        ),
        Expanded(
          flex: 1,
          child: Container(
            height: 3.h,
            decoration: BoxDecoration(
              color: _red,
              borderRadius:
                  BorderRadius.horizontal(right: Radius.circular(2.r)),
            ),
          ),
        ),
      ],
    );
  }

  /// "From Real" ticker strip showing a sample trade / broadcast row.
  Widget _buildFromRealStrip() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        child: Row(
          children: [
            Text('From Real',
                style: AppTextStyles.bodyText.copyWith(color: _textPrimary, fontSize: 12.sp)),
            SizedBox(width: 12.w),
            Text('arie***',
                style: AppTextStyles.bodyText.copyWith(color: _textSecondary, fontSize: 12.sp)),
            SizedBox(width: 8.w),
            Text('EUR',
                style: AppTextStyles.bodyText.copyWith(color: _textPrimary, fontSize: 12.sp)),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: _green, width: 1),
              ),
              child: Text('Buy 1',
                  style: AppTextStyles.bodyText.copyWith(
                    color: _green,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            SizedBox(width: 8.w),
            Text('Profit \$ 0.04',
                style: AppTextStyles.bodyText.copyWith(color: _green, fontSize: 12.sp)),
            SizedBox(width: 10.w),
            Text(_currentTimeHms(),
                style: AppTextStyles.bodyText.copyWith(color: _textSecondary, fontSize: 12.sp)),
            const Spacer(),
            Icon(Icons.chevron_right, color: _textSecondary, size: 20.sp),
          ],
        ),
      ),
    );
  }

  String _currentTimeHms() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  Widget _buildPillTabs() {
    final tradingController = Get.find<TradingController>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Obx(() {
        final selected = tradingController.selectedTab;
        return Row(
          children: [
            _tabText('Position', selected == 0,
                () => tradingController.setSelectedTab(0)),
            SizedBox(width: 28.w),
            _tabText('Pending', selected == 1,
                () => tradingController.setSelectedTab(1)),
            SizedBox(width: 28.w),
            _tabText('History', selected == 2,
                () => tradingController.setSelectedTab(2)),
            const Spacer(),
            Icon(Icons.swap_vert, color: _textSecondary, size: 20.sp),
            SizedBox(width: 16.w),
            Icon(Icons.more_horiz, color: _textSecondary, size: 20.sp),
          ],
        );
      }),
    );
  }

  Widget _tabText(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 15.sp,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? _textPrimary : _textSecondary,
            ),
          ),
          SizedBox(height: 6.h),
          Container(
            height: 3.h,
            width: 22.w,
            decoration: BoxDecoration(
              color: active ? _accent : Colors.transparent,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    final tradingController = Get.find<TradingController>();
    return Obx(() {
      if (tradingController.selectedTab != 2) return const SizedBox.shrink();

      if (!tradingController.historyFilterInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.find<TradingController>().historyFilterInitialized) return;
          Get.find<TradingController>().applyHistoryFilter();
        });
      }

      final now = DateHelper.nowUtc();
      final start = tradingController.historyStartDate ??
          DateTime(now.year, now.month, now.day);
      final end = tradingController.historyEndDate ?? now;
      final startDate = DateHelper.formatUtcDateTime(start);
      final endDate = DateHelper.formatUtcDateTime(end);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: InkWell(
          onTap: _openHistoryFilterSheet,
          borderRadius: BorderRadius.circular(6.r),
          child: Row(
            children: [
              Text('Start:',
                  style: AppTextStyles.bodyText.copyWith(color: _textSecondary, fontSize: 13.sp)),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Center(
                    child: Text(startDate,
                        style: AppTextStyles.bodyText.copyWith(color: _textPrimary, fontSize: 13.sp)),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text('—',
                    style: AppTextStyles.bodyText.copyWith(color: _textSecondary, fontSize: 13.sp)),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Center(
                    child: Text(endDate,
                        style: AppTextStyles.bodyText.copyWith(color: _textPrimary, fontSize: 13.sp)),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Icon(Icons.history, color: _textSecondary, size: 24.sp),
            ],
          ),
        ),
      );
    });
  }

  void _openHistoryFilterSheet() {
    final controller = Get.find<TradingController>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => HistoryFilterScreen(
        initialPeriod: controller.historyFilterPeriod,
        initialSymbols: controller.selectedInstruments,
        onConfirm: (period, symbols) async {
          controller.clearInstruments();
          if (!symbols.contains('all')) {
            for (final s in symbols) {
              controller.addInstrument(s);
            }
          }
          await controller.applyHistoryFilter(period: period);
        },
        onReset: () async {
          controller.clearInstruments();
          await controller.resetHistoryFilter();
        },
      ),
    );
  }

  Widget _buildBody() {
    return GetBuilder<TradingController>(
      builder: (controller) {
        final positions = controller.getFilteredPositions();
        final isLoadingHistory = controller.isLoadingHistory;
        final selectedTab = controller.selectedTab;

        if (selectedTab != 2 && positions.isEmpty) return _buildEmptyState();
        if (selectedTab == 2 && positions.isEmpty && !isLoadingHistory) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (controller.selectedTab == 2) {
              await controller.refreshTradeHistory();
            }
          },
          child: ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 90.h),
            itemCount: positions.length +
                (controller.hasMoreHistoryPages && selectedTab == 2 ? 1 : 0),
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              if (index >= positions.length) return _buildPaginationLoader();
              final position = positions[index];
              return RepaintBoundary(
                child: GetBuilder<TradingController>(
                  id: 'position_${position.orderId}',
                  builder: (innerController) {
                    final TradePosition? fresh = innerController.selectedTab == 0
                        ? innerController.getMarketPositionById(position.orderId)
                        : (innerController.selectedTab == 1
                            ? innerController
                                .getPendingPositionById(position.orderId)
                            : innerController
                                .getClosedPositionById(position.orderId));
                    return _buildPositionCard(
                        innerController, fresh ?? position);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final tradingController = Get.find<TradingController>();
    final tab = tradingController.selectedTab;
    final message = tab == 1
        ? 'No Pending Orders'
        : tab == 2
            ? 'No Trade History'
            : 'No Open Positions';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 44.sp, color: _textSecondary),
          SizedBox(height: 16.h),
          Text(message,
              style: AppTextStyles.bodyText.copyWith(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPaginationLoader() {
    if (!Get.find<TradingController>().isLoadingHistory) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      alignment: Alignment.center,
      child: SizedBox(
        height: 24.w,
        width: 24.w,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: _accent),
      ),
    );
  }

  Widget _buildPositionCard(
      TradingController tradingController, TradePosition position) {
    final isPositive = position.profitLoss >= 0;
    final isHistory = tradingController.selectedTab == 2;
    final isBuy = position.action.toLowerCase() == 'buy';
    final symbol = _formatSymbol(position.symbol);
    final leverage = _leverageLabel(position);

    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: () {
        if (isHistory) {
          Get.to(() => IQuoteOrderDetailsScreen(
                data: IQuoteOrderData(
                  orderNo: position.orderId,
                  symbol: symbol,
                  buySell: position.action,
                  lots: position.volume.toString(),
                  contractSize: '—',
                  leverage: leverage,
                  profit: PrecisionHelper.formatPnL(position.profitLoss),
                  openTime: position.openTime,
                  openPrice: position.entryPrice,
                  closeTime: position.closeTime,
                  closePrice: position.currentPrice,
                  closingMethod:
                      position.closeTime.isNotEmpty ? 'Closed by Trader' : '',
                  swap: PrecisionHelper.formatPnL(position.swap),
                ),
              ));
        } else {
          _showActionSheet(tradingController, position);
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 8.w, 10.h),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: side chip + symbol • dismiss/close
            Row(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: (isBuy ? _green : _red).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    isBuy ? 'Buy' : 'Sell',
                    style: AppTextStyles.bodyText.copyWith(
                      color: isBuy ? _green : _red,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  symbol,
                  style: AppTextStyles.bodyText.copyWith(
                    color: _textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (!isHistory)
                  InkWell(
                    borderRadius: BorderRadius.circular(20.r),
                    onTap: () {
                      Get.to(() => ClosePositionScreen(position: position));
                    },
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      child: Icon(Icons.cancel,
                          color: _textSecondary, size: 20.sp),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 6.h),
            // Row 2: lot + leverage • PnL
            Row(
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  margin: EdgeInsets.only(right: 6.w),
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  '${position.volume}Lot',
                  style: AppTextStyles.bodyText.copyWith(
                      color: _textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 8.w),
                if (leverage.isNotEmpty)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: _chipBgColor,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      leverage,
                      style: AppTextStyles.bodyText.copyWith(
                          color: _textSecondary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                const Spacer(),
                Text(
                  '${isPositive ? '' : '-'}${position.profitLoss.abs().toStringAsFixed(4)}',
                  style: AppTextStyles.bodyText.copyWith(
                    color: isPositive ? _green : _red,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            // Row 3: VIP badge + swap • prices
            Row(
              children: [
                _buildVipBadge(),
                SizedBox(width: 6.w),
                Text(
                  _formatSwap(position.swap),
                  style: AppTextStyles.bodyText.copyWith(color: _textSecondary, fontSize: 11.sp),
                ),
                const Spacer(),
                Text(
                  position.entryPrice,
                  style: AppTextStyles.bodyText.copyWith(color: _textSecondary, fontSize: 12.sp),
                ),
                SizedBox(width: 6.w),
                Icon(Icons.arrow_forward,
                    color: _textSecondary, size: 12.sp),
                SizedBox(width: 6.w),
                Text(
                  position.currentPrice,
                  style: AppTextStyles.bodyText.copyWith(color: _textPrimary, fontSize: 12.sp),
                ),
              ],
            ),
            if (isHistory && position.closeTime.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  DateHelper.formatIsoStringToUtcHistory(position.closeTime),
                  style: AppTextStyles.bodyText.copyWith(color: _textMuted, fontSize: 11.sp),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVipBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        gradient: LinearGradient(
          colors: [
            _accent.withOpacity(0.9),
            _accent.withOpacity(0.5),
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('V',
              style: AppTextStyles.bodyText.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.sp)),
          SizedBox(width: 3.w),
          Text('VIP 0',
              style: AppTextStyles.bodyText.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 9.sp)),
        ],
      ),
    );
  }

  String _formatSymbol(String raw) {
    final noSuffix = raw.contains('.') ? raw.substring(0, raw.indexOf('.')) : raw;
    if (noSuffix.length == 6) {
      return '${noSuffix.substring(0, 3)}/${noSuffix.substring(3)}';
    }
    return noSuffix;
  }

  String _leverageLabel(TradePosition position) {
    try {
      final acc = Get.find<AccountController>().activeMT5Account;
      final lev = acc?.leverageMax ?? 0;
      if (lev == 0) return '';
      return '${lev}X';
    } catch (_) {
      return '';
    }
  }

  String _formatSwap(double swap) {
    final abs = swap.abs().toStringAsFixed(4);
    return swap >= 0 ? abs : '-$abs';
  }

  String _activeAccountLabel() {
    try {
      final acc = Get.find<AccountController>().activeMT5Account;
      if (acc == null) return 'DEMO';
      return acc.isRealAccount ? 'REAL' : 'DEMO';
    } catch (_) {
      return 'DEMO';
    }
  }

  void _showActionSheet(
      TradingController tradingController, TradePosition position) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Close Position'),
                onTap: () {
                  Get.back();
                  Get.to(() => ClosePositionScreen(position: position));
                },
              ),
              ListTile(
                title: Text('Edit Order'),
                onTap: () {
                  Get.back();
                  Get.to(() => EditOrderScreen(position: position));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Switch-account bottom sheet (REAL / DEMO)
  // ─────────────────────────────────────────────────────────────────────────
  void _openSwitchAccountSheet() {
    Get.bottomSheet(
      _SwitchAccountSheet(
        onCancel: () => Get.back(),
      ),
      backgroundColor: _bgColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
    );
  }
}

/// Bottom sheet body shown when the DEMO/LIVE chip is tapped.
/// Lists REAL and DEMO account rows with a Switch action.
class _SwitchAccountSheet extends StatefulWidget {
  final VoidCallback onCancel;
  const _SwitchAccountSheet({required this.onCancel});

  @override
  State<_SwitchAccountSheet> createState() => _SwitchAccountSheetState();
}

class _SwitchAccountSheetState extends State<_SwitchAccountSheet> {
  static const Color _accent = Color(0xFFE88A4A);

  // Theme-aware text colors — mirrors the getters on the outer
  // _IQuotePositionScreenState but scoped here so the bottom-sheet state
  // (which lives in a separate widget class) can access them.
  Color get _textPrimary => AppColors.textPrimary;
  Color get _textSecondary => AppColors.textSecondary;
  Color get _textMuted =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white38
          : AppColors.textSecondary.withValues(alpha: 0.6);

  String? _selectedAccountNumber;

  @override
  void initState() {
    super.initState();
    try {
      _selectedAccountNumber =
          Get.find<AccountController>().activeMT5Account?.metaAccountNumber;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 6.h),
            Text(
              'Switch account',
              style: AppTextStyles.bodyText.copyWith(
                color: _textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),
            GetBuilder<DashboardController>(
              builder: (dashboard) {
                final real = dashboard.realMT5Accounts;
                final demo = dashboard.demoMT5Accounts;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAccountRow(
                      label: 'REAL',
                      account: real.isNotEmpty ? real.first : null,
                      onDepositTap: (accountNumber) {
                        Get.back();
                        Get.to(() =>
                            PaymentMethodsScreen(accountNumber: accountNumber));
                      },
                      emptyActionLabel: 'Sign in/Sign up',
                      onEmptyAction: () {
                        Get.back();
                        Get.toNamed(Routes.CHOOSE_ACCOUNT);
                      },
                    ),
                    Divider(color: AppColors.border, height: 24.h),
                    _buildAccountRow(
                      label: 'DEMO',
                      account: demo.isNotEmpty ? demo.first : null,
                      onDepositTap: (accountNumber) {
                        Get.back();
                        Get.to(() =>
                            DepositScreen(accountNumber: accountNumber));
                      },
                      emptyActionLabel: 'Open Demo',
                      onEmptyAction: () {
                        Get.back();
                        Get.toNamed(Routes.CHOOSE_ACCOUNT,
                            arguments: {'isDemo': true});
                      },
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: _selectedAccountNumber == null ? null : _onSwitch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  disabledBackgroundColor: _accent.withOpacity(0.4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                ),
                child: Text(
                  'Switch',
                  style: AppTextStyles.bodyText.copyWith(
                      fontSize: 15.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow({
    required String label,
    required MT5Account? account,
    required void Function(String accountNumber) onDepositTap,
    required String emptyActionLabel,
    required VoidCallback onEmptyAction,
  }) {
    final hasAccount = account != null;
    final accountNumber = account?.metaAccountNumber;
    final isSelected =
        hasAccount && _selectedAccountNumber == accountNumber;
    final balance = account?.balance ?? '0.00';

    return InkWell(
      onTap: hasAccount
          ? () => setState(() => _selectedAccountNumber = accountNumber)
          : null,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            // Selection radio
            Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _accent : _textSecondary,
                  width: 2,
                ),
                color: isSelected ? _accent : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.circle, size: 10.sp, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodyText.copyWith(
                          color: _textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.help_outline,
                          color: _textSecondary, size: 14.sp),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    hasAccount ? balance : '---',
                    style: AppTextStyles.bodyText.copyWith(
                      color: hasAccount ? _accent : _textMuted,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            hasAccount
                ? _actionButton(
                    label: 'Deposit',
                    color: const Color(0xFF2EBD6F),
                    icon: Icons.savings_outlined,
                    onTap: () => onDepositTap(accountNumber!),
                  )
                : _actionButton(
                    label: emptyActionLabel,
                    color: const Color(0xFF3A4062),
                    onTap: onEmptyAction,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 14.sp),
              SizedBox(width: 6.w),
            ],
            Text(label,
                style: AppTextStyles.bodyText.copyWith(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _onSwitch() async {
    final target = _selectedAccountNumber;
    if (target == null) return;
    try {
      final accountController = Get.find<AccountController>();
      if (accountController.activeMT5Account?.metaAccountNumber == target) {
        Get.back();
        return;
      }
      Get.back();
      await accountController.setActiveMT5Account(target);
    } catch (e) {
      if (kDebugMode) print('IQuotePosition: switch account error: $e');
    }
  }
}
