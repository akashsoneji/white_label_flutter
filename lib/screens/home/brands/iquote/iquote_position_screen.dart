import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/screens/trading/view_models/trading_controller.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/account_websocket_service.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/utils/date_helper.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/home/close_position_screen.dart';
import 'package:crm_app/screens/home/edit_order_screen.dart';
import 'package:crm_app/screens/home/brands/iquote/iquote_order_details_screen.dart';

class IQuotePositionScreen extends StatefulWidget {
  final Function(String)? onNavigateToChart;

  const IQuotePositionScreen({super.key, this.onNavigateToChart});

  @override
  State<IQuotePositionScreen> createState() => _IQuotePositionScreenState();
}

class _IQuotePositionScreenState extends State<IQuotePositionScreen> {
  static const Color _brand = Color(0xFF5F259E);
  final Set<String> _expandedCardIds = <String>{};
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
      if (tradingController.selectedTab == 0) {
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
      _accountChangeSubscription = accountController.activeMT5AccountRx.listen((account) {
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
    _expandedCardIds.clear();
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
      backgroundColor: const Color(0xFF262A3B), // match dark bg from image
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildPillTabs(),
            _buildDateFilter(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GetX<AccountController>(
      builder: (accountController) {
        final tradingController = Get.find<TradingController>();
        final accountInfo = tradingController.accountInfo;
        final balance = accountInfo?.balance ?? 0.00;
        final profit = accountInfo?.profit ?? 0.00;
        // Let's assume margin percentage for the display
        final marginLevel = accountInfo?.marginLevel ?? 0.00;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF333950),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      children: [
                        Text('DEMO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                        SizedBox(width: 4.w),
                        Icon(Icons.arrow_drop_down, color: Colors.white, size: 16.sp),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    balance.toStringAsFixed(4),
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${profit >= 0 ? '' : '-'}${profit.abs().toStringAsFixed(4)}(${marginLevel.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: profit >= 0 ? const Color(0xFF2EBD6F) : const Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: Container(height: 3.h, decoration: BoxDecoration(color: const Color(0xFF2EBD6F), borderRadius: BorderRadius.horizontal(left: Radius.circular(2.r)))),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(height: 3.h, color: const Color(0xFFE88A4A)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(height: 3.h, decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.horizontal(right: Radius.circular(2.r)))),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillTabs() {
    final tradingController = Get.find<TradingController>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Obx(() {
        final selected = tradingController.selectedTab;
        return Row(
          children: [
            _tabText('Position', selected == 0, () => tradingController.setSelectedTab(0)),
            SizedBox(width: 24.w),
            _tabText('Pending', selected == 1, () => tradingController.setSelectedTab(1)),
            SizedBox(width: 24.w),
            _tabText('History', selected == 2, () => tradingController.setSelectedTab(2)),
          ],
        );
      }),
    );
  }

  Widget _tabText(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? Colors.white : Colors.white70,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            height: 3.h,
            width: 24.w,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFE88A4A) : Colors.transparent,
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
      
      final now = DateHelper.nowUtc();
      final startDate = DateHelper.formatUtcDateTime(now.subtract(const Duration(days: 7)));
      final endDate = DateHelper.formatUtcDateTime(now);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Text('Start:', style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
            SizedBox(width: 12.w),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2132),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Center(
                  child: Text(startDate, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text('—', style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2132),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Center(
                  child: Text(endDate, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Icon(Icons.history, color: Colors.white70, size: 24.sp),
          ],
        ),
      );
    });
  }

  Widget _buildBody() {
    return GetBuilder<TradingController>(
      builder: (controller) {
        final positions = controller.getFilteredPositions();
        final isLoadingHistory = controller.isLoadingHistory;
        final selectedTab = controller.selectedTab;

        if (selectedTab != 2 && positions.isEmpty) return _buildEmptyState();
        if (selectedTab == 2 && positions.isEmpty && !isLoadingHistory) return _buildEmptyState();

        return RefreshIndicator(
          onRefresh: () async {
            if (controller.selectedTab == 2) await controller.refreshTradeHistory();
          },
          child: ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 90.h),
            itemCount: positions.length + (controller.hasMoreHistoryPages && selectedTab == 2 ? 1 : 0),
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              if (index >= positions.length) return _buildPaginationLoader();
              return _buildPositionCard(controller, positions[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final tradingController = Get.find<TradingController>();
    final tab = tradingController.selectedTab;
    final message = tab == 1 ? 'No Pending Orders' : tab == 2 ? 'No Trade History' : 'No Open Positions';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 44.sp, color: Colors.white54),
          SizedBox(height: 16.h),
          Text(message, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildPaginationLoader() {
    if (!Get.find<TradingController>().isLoadingHistory) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      alignment: Alignment.center,
      child: SizedBox(height: 24.w, width: 24.w, child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand)),
    );
  }

  Widget _buildPositionCard(TradingController tradingController, TradePosition position) {
    final isPositive = position.profitLoss >= 0;
    final isHistory = tradingController.selectedTab == 2;
    final isBuy = position.action.toLowerCase() == 'buy';
    final symbol = _stripSymbol(position.symbol);

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
              leverage: '—',
              profit: PrecisionHelper.formatPnL(position.profitLoss),
              openTime: position.openTime,
              openPrice: position.entryPrice,
              closeTime: position.closeTime,
              closePrice: position.currentPrice,
              closingMethod: position.closeTime.isNotEmpty ? 'Closed by Trader' : '',
              swap: PrecisionHelper.formatPnL(position.swap),
            ),
          ));
        } else {
          _showActionSheet(tradingController, position);
        }
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2233),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: isBuy ? const Color(0xFF2EBD6F).withOpacity(0.15) : const Color(0xFFE53935).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    position.action.capitalizeFirst ?? position.action,
                    style: TextStyle(
                      color: isBuy ? const Color(0xFF2EBD6F) : const Color(0xFFE53935),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  symbol,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${isPositive ? '+' : ''}\$${PrecisionHelper.formatPnL(position.profitLoss)}',
                  style: TextStyle(
                    color: isPositive ? const Color(0xFF2EBD6F) : const Color(0xFFE53935),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.shortcut, color: const Color(0xFFE88A4A), size: 18.sp),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${position.volume}Lot',
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
                Text(
                  isHistory ? '${position.entryPrice} → ${position.currentPrice}' : '${position.entryPrice}',
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
              ],
            ),
            if (isHistory && position.closeTime.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateHelper.formatIsoStringToUtcHistory(position.closeTime),
                    style: TextStyle(color: Colors.white54, fontSize: 11.sp),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _stripSymbol(String symbol) {
    final dot = symbol.indexOf('.');
    if (dot <= 0) return symbol;
    return symbol.substring(0, dot);
  }

  void _showActionSheet(TradingController tradingController, TradePosition position) {
    // simplified for brevity... (same logic as before)
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

  Future<void> _confirmCancelPending(TradePosition position) async {
    // simplified...
  }
}
