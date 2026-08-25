import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/models/websocket_trading_response.dart';
import 'package:crm_app/models/trade_history_model.dart';
import 'package:crm_app/models/order_types.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/screens/trading/data/repositories/trading_repository.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/utils/precision_helper.dart';
import 'package:crm_app/utils/app_logger.dart';
import 'account_controller.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/services/trading_websocket_service.dart';
import 'package:crm_app/services/audio_service.dart';

// Trade Position Model
class TradePosition {
  final String symbol;
  final String flag;
  final String action; // "Buy" or "Sell"
  final double volume;
  final double profitLoss;
  final String entryPrice;
  final String currentPrice;
  final String accountId;
  final String orderId;
  final bool isFavorite;
  final String openTime;
  final String closeTime;
  final String reason;
  final String orderNo;
  final double commission;
  final double swap;
  final String takeProfit;
  final String stopLoss;
  final String mt5Account;
  final String time;
  final String duration;
  final int digits;

  TradePosition({
    required this.symbol,
    required this.flag,
    required this.action,
    required this.volume,
    required this.profitLoss,
    required this.entryPrice,
    required this.currentPrice,
    required this.accountId,
    required this.orderId,
    this.isFavorite = false,
    this.openTime = '',
    this.closeTime = '',
    this.reason = '',
    this.orderNo = '',
    this.commission = 0.0,
    this.swap = 0.0,
    this.takeProfit = '',
    this.stopLoss = '',
    this.mt5Account = '',
    this.time = '',
    this.duration = '',
    this.digits = 5,
  });

  // Getters for compatibility
  String get openPrice => entryPrice;
  Color get actionColor =>
      action.toLowerCase() == 'buy' ? Colors.green : Colors.red;

  // ✅ OPTIMIZATION: copyWith for efficient in-place updates
  TradePosition copyWith({
    String? symbol,
    String? flag,
    String? action,
    double? volume,
    double? profitLoss,
    String? entryPrice,
    String? currentPrice,
    String? accountId,
    String? orderId,
    bool? isFavorite,
    String? openTime,
    String? closeTime,
    String? reason,
    String? orderNo,
    double? commission,
    double? swap,
    String? takeProfit,
    String? stopLoss,
    String? mt5Account,
    String? time,
    String? duration,
    int? digits,
  }) {
    return TradePosition(
      symbol: symbol ?? this.symbol,
      flag: flag ?? this.flag,
      action: action ?? this.action,
      volume: volume ?? this.volume,
      profitLoss: profitLoss ?? this.profitLoss,
      entryPrice: entryPrice ?? this.entryPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      accountId: accountId ?? this.accountId,
      orderId: orderId ?? this.orderId,
      isFavorite: isFavorite ?? this.isFavorite,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      reason: reason ?? this.reason,
      orderNo: orderNo ?? this.orderNo,
      commission: commission ?? this.commission,
      swap: swap ?? this.swap,
      takeProfit: takeProfit ?? this.takeProfit,
      stopLoss: stopLoss ?? this.stopLoss,
      mt5Account: mt5Account ?? this.mt5Account,
      time: time ?? this.time,
      duration: duration ?? this.duration,
      digits: digits ?? this.digits,
    );
  }
}

// History Entry Model
class HistoryEntry {
  final String type; // "Order Closed" or "Order Opened"
  final String operation; // "Manual operation"
  final double profitLoss;
  final String dateTime;
  final String device;
  final String direction;
  final String openPrice;
  final String volume;
  final bool isExpanded;

  HistoryEntry({
    required this.type,
    required this.operation,
    required this.profitLoss,
    required this.dateTime,
    this.device = '',
    this.direction = '',
    this.openPrice = '',
    this.volume = '',
    this.isExpanded = false,
  });
}

class TradingController extends GetxController {
  final TradingRepository _tradingRepo = Get.find<TradingRepository>();
  // Observable states
  final _selectedTab = 0.obs;
  final _selectedInstruments = <String>{}.obs;
  final _selectedDirection = 'All'.obs;
  // Tab-specific direction filters (for Pending tab 1 and Closed tab 2)
  final _pendingDirection = 'All'.obs;
  final _closedDirection = 'All'.obs;
  final _isLoading = false.obs;
  final _errorMessage = ''.obs;
  final _successMessage = ''.obs;

  // Order type and trading states
  final _selectedOrderType = OrderType.buyMarket.obs;
  final _currentSymbol = ''.obs;
  final _currentBidPrice = 0.0.obs;
  final _currentAskPrice = 0.0.obs;
  final _pipGapValue = 0.0001.obs; // Default pip gap value
  final _pipSLTPValue = 0.0001.obs; // Default pip SL/TP value

  // Real-time data from WebSocket
  final _websocketData = Rxn<WebSocketTradingResponse>();
  final _accountInfo = Rxn<AccountInfo>();

  // Trade positions data
  final _marketPositions = <TradePosition>[].obs;
  final _pendingPositions = <TradePosition>[].obs;
  final _closedPositions = <TradePosition>[].obs;
  final _historyEntries = <HistoryEntry>[].obs;
  final _marketPositionsById = <String, TradePosition>{};

  // ---- History filter state ----
  /// One of 'today', 'week', 'month', 'threeMonth', 'custom'.
  /// Defaults to 'today' so the History tab is pre-filtered on first open.
  String _historyFilterPeriod = 'today';
  String get historyFilterPeriod => _historyFilterPeriod;

  /// Populated by _applyHistoryFilter() once the user has confirmed.
  DateTime? _historyStartDate;
  DateTime? get historyStartDate => _historyStartDate;

  DateTime? _historyEndDate;
  DateTime? get historyEndDate => _historyEndDate;

  /// Persisted last symbol selection from the filter sheet so re-opening the
  /// sheet shows the user what is currently applied.
  final List<String> _historySelectedSymbols = <String>['all'];
  List<String> get historySelectedSymbols =>
      List<String>.unmodifiable(_historySelectedSymbols);

  /// Whether _applyHistoryFilter has ever been called (used to apply
  /// today's default the first time the History tab is opened).
  bool _historyFilterInitialized = false;
  bool get historyFilterInitialized => _historyFilterInitialized;
  final Map<String, TradePosition> _pendingPositionsById = {};
  final Map<String, TradePosition> _closedPositionsById = {};

  TradePosition? getMarketPositionById(String orderId) =>
      _marketPositionsById[orderId];

  TradePosition? getPendingPositionById(String orderId) =>
      _pendingPositionsById[orderId];

  TradePosition? getClosedPositionById(String orderId) =>
      _closedPositionsById[orderId];

  // Flag to prevent flickering during account switch
  bool _isAccountSwitching = false;

  // Track orders being cancelled to prevent duplicate API calls
  final _cancellingOrderIds = <int>{};

  // Track permanently deleted IDs to prevent websocket from re-adding closed items
  final _deletedPositionIds = <String>{};
  final _deletedPendingOrderIds = <int>{};

  // ✅ OPTIMIZATION: Debounce timer for UI refresh (max 10 updates/sec)
  Timer? _refreshDebounceTimer;

  // ✅ OPTIMIZATION: Pending position updates queue (batch processing)
  final Map<String, TradePosition> _pendingPositionUpdates = {};
  Timer? _flushTimer;
  bool _userScrolling = false;
  Timer? _scrollIdleTimer;

  bool get isUserScrolling => _userScrolling;

  void setUserScrolling(bool value) {
    if (_userScrolling == value) return;
    _userScrolling = value;
    if (!_userScrolling) {
      // When scrolling ends, apply any pending updates quickly.
      _scheduleFlush();
    }
  }

  void notifyUserScrollActivity() {
    // Called frequently while scrolling; mark as scrolling and auto-clear after idle.
    if (!_userScrolling) {
      _userScrolling = true;
    }
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(const Duration(milliseconds: 200), () {
      _userScrolling = false;
      _scheduleFlush();
    });
  }

  // ✅ OPTIMIZATION: Schedule a debounced refresh (60fps = 16ms)
  void _schedulePositionRefresh() {
    if (_refreshDebounceTimer?.isActive ?? false) return;
    // Throttle reactive refresh to reduce UI jank during fast market ticks.
    // 16ms can overwhelm the UI when 100-200+ positions update frequently.
    _refreshDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      _marketPositions.refresh();
    });
  }

  // ✅ OPTIMIZATION: Add single position (for new trades)
  void addPosition(TradePosition position) {
    // ✅ CRITICAL FIX: Check if position was removed - block re-adding
    if (isPositionDeleted(position.orderId)) {
      return; // Position was removed, don't add it back
    }

    // Check if already exists (self-healing)
    final existingIndex = _marketPositions.indexWhere(
      (p) => p.orderId == position.orderId,
    );
    if (existingIndex >= 0) {
      // Already exists, update instead
      _marketPositions[existingIndex] = position;
      _marketPositionsById[position.orderId] = position;
      // Update individual card
      update(['position_${position.orderId}']);
    } else {
      _marketPositions.add(position);
      _marketPositionsById[position.orderId] = position;
      // New position added - update list structure
      update();
    }
  }

  // ✅ OPTIMIZATION: Update position in-place (no list recreation)
  void updatePositionInPlace(String positionId, TradePosition updatedPosition) {
    // ✅ CRITICAL FIX: Check if position was deleted - block updates
    if (isPositionDeleted(positionId)) {
      return; // Position was removed, don't update it
    }

    final index = _marketPositions.indexWhere((p) => p.orderId == positionId);
    if (index >= 0) {
      // Update existing position in place
      _marketPositions[index] = updatedPosition;
      _marketPositionsById[positionId] = updatedPosition;
      _schedulePositionRefresh();
    } else {
      // Self-healing: position not found, but only add if not deleted
      if (!isPositionDeleted(positionId)) {
        _marketPositions.add(updatedPosition);
        _marketPositionsById[positionId] = updatedPosition;
        _schedulePositionRefresh();
      }
    }
  }

  // ✅ OPTIMIZATION: Queue update for batch processing
  void queuePositionUpdate(TradePosition position) {
    // Skip updates for deleted positions to prevent websocket from re-adding them
    if (isPositionDeleted(position.orderId)) {
      return;
    }
    _pendingPositionUpdates[position.orderId] = position;
    _scheduleFlush();
  }

  // ✅ OPTIMIZATION: Schedule flush of pending updates (120fps = 8ms for faster updates)
  // Reduced from 16ms to 8ms to achieve 5-10ms total update time
  void _scheduleFlush() {
    if (_flushTimer?.isActive ?? false) return;
    // Throttle batch flush to keep scrolling smooth with 100-200+ positions.
    _flushTimer = Timer(const Duration(milliseconds: 50), _flushPendingUpdates);
  }

  // ✅ OPTIMIZATION: Flush all pending updates at once with incremental GetBuilder updates
  // This is critical for handling 100+ position batches efficiently
  // OPTIMIZED: Uses Map for O(1) lookups instead of O(n) indexWhere
  void _flushPendingUpdates() {
    if (_pendingPositionUpdates.isEmpty) return;

    // ✅ OPTIMIZATION: Create position index map for O(1) lookups (faster than indexWhere)
    final Map<String, int> positionIndexMap = {};
    for (int i = 0; i < _marketPositions.length; i++) {
      positionIndexMap[_marketPositions[i].orderId] = i;
    }
    final int previousCount = _marketPositions.length;

    // Track which positions changed for incremental UI updates
    final List<String> updatedPositionIds = [];
    bool listStructureChanged = false;

    for (final entry in _pendingPositionUpdates.entries) {
      final positionId = entry.key;
      final position = entry.value;

      // Skip updates for deleted positions to prevent websocket from re-adding them
      if (isPositionDeleted(positionId)) {
        continue;
      }

      // ✅ OPTIMIZATION: O(1) lookup instead of O(n) indexWhere
      final index = positionIndexMap[positionId];
      if (index != null && index >= 0) {
        // Check if position actually changed before updating
        final existingPosition = _marketPositions[index];
        final positionChanged =
            existingPosition.profitLoss != position.profitLoss ||
            existingPosition.currentPrice != position.currentPrice ||
            existingPosition.entryPrice != position.entryPrice ||
            existingPosition.swap != position.swap;

        if (positionChanged) {
          _marketPositions[index] = position;
          _marketPositionsById[positionId] = position;
          updatedPositionIds.add(positionId);
        }
      } else {
        // New position - add it
        _marketPositions.add(position);
        _marketPositionsById[positionId] = position;
        updatedPositionIds.add(positionId);
        listStructureChanged = true;
      }
    }
    _pendingPositionUpdates.clear();

    // ✅ CRITICAL: Use GetBuilder incremental updates instead of full refresh
    // This is 20-50x faster for large batches (100+ positions)
    if (updatedPositionIds.isNotEmpty) {
      // If user is actively scrolling, avoid triggering rebuilds.
      // Keep the data updated, but defer UI updates until scrolling stops.
      if (_userScrolling) {
        return;
      }

      // Only rebuild the list when the number of items changed.
      // For large batches (e.g., 200 positions), rebuilding the whole ListView
      // every tick makes scrolling feel "stuck". Incremental card updates keep it smooth.
      if (listStructureChanged || _marketPositions.length != previousCount) {
        update(); // list structure changed (add/remove) → rebuild ListView
      }

      // Always update the changed cards.
      final updateIds = updatedPositionIds.map((id) => 'position_$id').toList();
      update(updateIds);
    }
  }

  // ✅ OPTIMIZATION: Remove position by ID efficiently
  void removePositionById(String positionId) {
    final index = _marketPositions.indexWhere((p) => p.orderId == positionId);
    if (index >= 0) {
      _marketPositions.removeAt(index);
      _marketPositionsById.remove(positionId);
      // Position removed - update list structure
      update();
    }
    // Also remove from pending updates if queued
    _pendingPositionUpdates.remove(positionId);
  }

  /// Check if an order is currently being cancelled
  bool isOrderBeingCancelled(int orderId) {
    return _cancellingOrderIds.contains(orderId);
  }

  /// Check if an order exists in pending positions
  bool hasPendingOrder(int orderId) {
    return _pendingPositions.any((p) => p.orderId == orderId.toString());
  }

  // Public methods to manage account switching state
  void setAccountSwitching(bool value) {
    _isAccountSwitching = value;
  }

  bool get isAccountSwitching => _isAccountSwitching;

  // Trade history data with pagination
  final _tradeHistory = <TradeHistoryItem>[].obs;
  final _paginationInfo = Rxn<PaginationInfo>();
  final _tradeHistoryTotals = Rxn<TradeHistoryTotals>();
  final _tradeHistorySummary = Rxn<TradeHistorySummary>();
  final _isLoadingHistory = false.obs;
  final _hasDateFilter = false.obs; // Track if date filter is active
  // Store all current filter parameters for pagination (includes timestamps, symbol, action, etc.)
  Map<String, String>? _currentFilterParams;
  // Track active filter type: 'today', 'thisWeek', 'thisMonth', 'custom', or null
  final _activeFilterType = Rxn<String>();

  // ✅ NEW: Track which tab's data is currently displayed
  final _lastDataTab = Rxn<int>(); // null = no data, or tab index

  // Getters
  int get selectedTab => _selectedTab.value;
  Set<String> get selectedInstruments => _selectedInstruments;
  String get selectedDirection => _selectedDirection.value;
  String get pendingDirection => _pendingDirection.value;
  String get closedDirection => _closedDirection.value;
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;
  String get successMessage => _successMessage.value;
  List<TradePosition> get marketPositions => _marketPositions;
  RxList<TradePosition> get marketPositionsRx =>
      _marketPositions; // Expose observable for listeners
  List<TradePosition> get pendingPositions => _pendingPositions;
  RxList<TradePosition> get pendingPositionsRx => _pendingPositions;
  List<TradePosition> get closedPositions => _closedPositions;
  List<HistoryEntry> get historyEntries => _historyEntries;
  WebSocketTradingResponse? get websocketData => _websocketData.value;
  AccountInfo? get accountInfo => _accountInfo.value;

  /// Use inside [Obx] / [GetX] (do not use [accountInfo] getter there).
  Rxn<AccountInfo> get accountInfoRx => _accountInfo;

  // Trade history getters
  List<TradeHistoryItem> get tradeHistory => _tradeHistory;
  PaginationInfo? get paginationInfo => _paginationInfo.value;
  TradeHistoryTotals? get tradeHistoryTotals => _tradeHistoryTotals.value;
  TradeHistorySummary? get tradeHistorySummary => _tradeHistorySummary.value;
  bool get isLoadingHistory => _isLoadingHistory.value;

  // ✅ NEW: Getter for last data tab
  int? get lastDataTab => _lastDataTab.value;

  // Active filter type getter
  String? get activeFilterType => _activeFilterType.value;
  Rxn<String> get activeFilterTypeObs => _activeFilterType;

  /// Get unique symbols from trade history
  Set<String> get availableHistorySymbols {
    final symbols = <String>{};
    for (final item in _tradeHistory) {
      // Get base symbol (remove .c suffix if present)
      final baseSymbol = item.tradeSymbol.replaceAll(RegExp(r'\..+$'), '');
      symbols.add(baseSymbol);
    }
    return symbols;
  }

  // Order type getters
  OrderType get selectedOrderType => _selectedOrderType.value;
  Rx<OrderType> get selectedOrderTypeObs => _selectedOrderType;
  String get currentSymbol => _currentSymbol.value;
  double get currentBidPrice => _currentBidPrice.value;
  double get currentAskPrice => _currentAskPrice.value;
  double get pipGapValue => _pipGapValue.value;
  double get pipSLTPValue => _pipSLTPValue.value;

  // Calculate floating profit from market positions
  double get floatingProfit {
    return _marketPositions.fold(
      0.0,
      (sum, position) => sum + position.profitLoss,
    );
  }

  @override
  void onInit() {
    super.onInit();
    _initializeSampleData();
  }

  // ✅ FIX: WebSocket data handling - instant real-time updates with no delays
  // Process all updates immediately to match website behavior (millisecond updates)
  void updateWebSocketData(WebSocketTradingResponse data) {
    _websocketData.value = data;

    // Update account info immediately for smoothness
    if (data.openPositions != null &&
        data.openPositions!.accountinfo.isNotEmpty) {
      // Only update if values actually changed to prevent unnecessary rebuilds
      final newAccountInfo = data.openPositions!.accountinfo.first;
      if (_accountInfo.value == null ||
          _accountInfo.value!.balance != newAccountInfo.balance ||
          _accountInfo.value!.equity != newAccountInfo.equity ||
          _accountInfo.value!.margin != newAccountInfo.margin) {
        _accountInfo.value = newAccountInfo;
        // ✅ FIX: Only update _lastDataTab if we're on Market/Pending tabs
        // Don't clear History tab's _lastDataTab when WebSocket updates arrive
        final currentTab = _selectedTab.value;
        if (currentTab < 2) {
          // We're on Market or Pending tab - update _lastDataTab
          _lastDataTab.value = currentTab;
        }
        // If we're on History tab (2), don't touch _lastDataTab - preserve it
      }
    }

    // ✅ FIX: Update market positions immediately - no delays for real-time trading
    if (data.openPositions != null) {
      _updateMarketPositions(data.openPositions!.positions);
    }

    // Update pending orders from WebSocket data
    if (data.pendingOrders != null) {
      _updatePendingOrders(data.pendingOrders!.pendingOrders);
    }
  }

  // Update account info from Account WebSocket service
  void updateAccountInfoFromWebSocket(AccountInfo accountInfo) {
    // Validate account number matches current active account
    try {
      final accountController = Get.find<AccountController>();
      final activeAccount = accountController.activeMT5Account;

      if (activeAccount != null) {
        final activeAccountNumber = activeAccount.metaAccountNumber;
        final accountInfoLogin = accountInfo.login.toString();

        // ✅ FIX: Normalize account numbers for comparison (remove leading zeros, handle string/int)
        final normalizedActive = activeAccountNumber.trim();
        final normalizedReceived = accountInfoLogin.trim();

        // Also try comparing as integers if string comparison fails
        final activeAsInt = int.tryParse(normalizedActive);
        final receivedAsInt = int.tryParse(normalizedReceived);

        final accountMatches =
            normalizedActive == normalizedReceived ||
            (activeAsInt != null &&
                receivedAsInt != null &&
                activeAsInt == receivedAsInt);

        // Only update if account number matches current active account
        if (!accountMatches) {
          return; // Don't update with data from wrong account
        }
      }
    } catch (e) {
      // If AccountController not found, proceed with update (shouldn't happen)
    }

    // ✅ OPTIMIZATION: Only update if values actually changed to prevent unnecessary rebuilds
    final currentInfo = _accountInfo.value;
    final shouldUpdate =
        currentInfo == null ||
        currentInfo.balance != accountInfo.balance ||
        currentInfo.equity != accountInfo.equity ||
        currentInfo.margin != accountInfo.margin ||
        currentInfo.profit != accountInfo.profit ||
        currentInfo.marginFree != accountInfo.marginFree ||
        currentInfo.marginLevel != accountInfo.marginLevel;

    if (shouldUpdate) {
      _accountInfo.value = accountInfo;

      // ✅ FIX: Set _lastDataTab for Market/Pending tabs when accountInfo is updated
      // This ensures account data stays visible when switching tabs or when no trades are active
      // Don't clear History tab's _lastDataTab when WebSocket updates arrive
      final currentTab = _selectedTab.value;
      if (currentTab < 2) {
        // We're on Market or Pending tab - update _lastDataTab
        _lastDataTab.value = currentTab;
      }
      // If we're on History tab (2), don't touch _lastDataTab - preserve it

      // ✅ OPTIMIZATION: Use GetBuilder incremental update instead of Obx full rebuild
      // This is faster for real-time account updates (only rebuilds account metrics widget)
      update(['account_info']);
    }
  }

  void _updateMarketPositions(List<TradingPosition> positions) {
    // ✅ FIX: During account switch, always update (even if empty) to clear old data immediately
    if (_isAccountSwitching) {
      final newPositions = positions.map((p) => p.toTradePosition()).toList();
      _marketPositions.value = newPositions;
      _isAccountSwitching = false;
      return;
    }

    // ✅ FIX: Sync local list with WebSocket snapshot to handle removals
    // Create a set of incoming position IDs for efficient lookup
    final incomingIds = positions.map((p) => p.position.toString()).toSet();

    // Remove any positions from our local list that are NOT in the incoming snapshot
    // This handles positions closed externally (e.g., TP/SL hit, or closed on another device)
    final initialCount = _marketPositions.length;
    _marketPositions.removeWhere((p) => !incomingIds.contains(p.orderId));

    if (_marketPositions.length != initialCount) {
      // If items were removed, refresh the UI structure
      update();
    }

    // ✅ OPTIMIZATION: Use batch queue for in-place updates
    // This reduces UI rebuilds from 150+/sec to 10/sec
    // Filter out deleted positions to prevent websocket from re-adding them
    for (final position in positions) {
      final tradePosition = position.toTradePosition();
      // queuePositionUpdate will check for deleted IDs, but we also filter here for efficiency
      if (!isPositionDeleted(tradePosition.orderId)) {
        queuePositionUpdate(tradePosition);
      }
    }
    // Note: queuePositionUpdate schedules a batched flush automatically
  }

  void _updatePendingOrders(List<PendingOrder> orders) {
    // Map to trade positions - always update even if empty to clear screen
    // Similar to how market positions work - they always update, even if empty
    // ✅ FIX: Filter out orders that are being cancelled or deleted to prevent re-adding removed orders
    final newPendingOrders =
        orders
            .where(
              (order) =>
                  !_cancellingOrderIds.contains(order.order) &&
                  !isPendingOrderDeleted(order.order),
            )
            .map((order) => order.toTradePosition())
            .toList();

    // Always update value and refresh - this ensures UI clears when websocket sends empty array
    // Matching the behavior of _updateMarketPositions which always updates
    _pendingPositions.value = newPendingOrders;
    _pendingPositions.refresh();

    // ✅ FIX: Call update() for GetBuilder compatibility
    update();
  }

  // Public method for WebSocket service to update pending orders separately
  void updatePendingOrders(List<PendingOrder> orders) {
    _updatePendingOrders(orders);
    // Commented out to reduce noise - fires frequently
    // if (kDebugMode) {
    //   print('Trading Controller: Updated ${orders.length} pending orders');
    // }
  }

  // Add or update a single pending order (for incremental updates from /ws/po)
  void addOrUpdatePendingOrder(PendingOrder order) {
    final orderId = order.order.toString();
    final orderIdInt = order.order;

    // ✅ FIX: Don't re-add orders that are being cancelled or deleted
    // This prevents WebSocket from re-adding orders that were just removed
    if (_cancellingOrderIds.contains(orderIdInt) ||
        isPendingOrderDeleted(orderIdInt)) {
      return;
    }

    final existingIndex = _pendingPositions.indexWhere(
      (p) => p.orderId == orderId,
    );

    final newTradePosition = order.toTradePosition();

    if (existingIndex != -1) {
      // Update existing - replace the entire object to ensure all fields update
      _pendingPositions[existingIndex] = newTradePosition;
      // Force refresh to ensure UI updates
      _pendingPositions.refresh();
    } else {
      // Add new
      _pendingPositions.add(newTradePosition);
      _pendingPositions.refresh();
    }

    // ✅ FIX: Call update() for GetBuilder compatibility
    update();
  }

  // Remove a pending order by orderId (for /ws/po remove messages)
  void removePendingOrder(int orderId) {
    // ✅ FIX: Mark as deleted FIRST to prevent re-adding from stale websocket updates
    markPendingOrderAsDeleted(orderId);

    final orderIdString = orderId.toString();
    _pendingPositions.removeWhere((p) => p.orderId == orderIdString);

    // Force refresh to ensure UI updates immediately
    _pendingPositions.refresh();

    // ✅ FIX: Call update() for GetBuilder compatibility
    update();

    // Also remove from cancelling set if present (cleanup)
    _cancellingOrderIds.remove(orderId);
  }

  // Check if a position ID is marked as deleted
  bool isPositionDeleted(String positionId) {
    return _deletedPositionIds.contains(positionId);
  }

  // Check if a pending order ID is marked as deleted
  bool isPendingOrderDeleted(int orderId) {
    return _deletedPendingOrderIds.contains(orderId);
  }

  // Mark a position ID as deleted (prevents websocket from re-adding it)
  void markPositionAsDeleted(String positionId) {
    _deletedPositionIds.add(positionId);
  }

  // Unmark a position ID as deleted (allows websocket to re-add it if volume > 0)
  void unmarkPositionAsDeleted(String positionId) {
    _deletedPositionIds.remove(positionId);
  }

  // Mark a pending order ID as deleted (prevents websocket from re-adding it)
  void markPendingOrderAsDeleted(int orderId) {
    _deletedPendingOrderIds.add(orderId);
  }

  void _initializeSampleData() {
    // Market positions
    _marketPositions.value = [];

    // Closed positions
    _closedPositions.value = [];

    // History entries
    _historyEntries.value = [
      HistoryEntry(
        type: 'Order Closed',
        operation: 'Manual operation',
        profitLoss: 89.54,
        dateTime: '25 jan 2025 • 12:49',
        device: 'Android',
        direction: 'Sell',
        openPrice: '3,408.65',
        volume: '0.03 lots',
        isExpanded: true,
      ),
      HistoryEntry(
        type: 'Order Closed',
        operation: 'Manual operation',
        profitLoss: -8.56,
        dateTime: '25 jan 2025 • 12:49',
        device: 'Android',
        direction: 'Sell',
        openPrice: '3,408.65',
        volume: '0.03 lots',
        isExpanded: false,
      ),
    ];
  }

  // Clear data when switching tabs (simplified)
  void clearAccountMetricsForTab(int tabIndex) {
    if (tabIndex == 2) {
      // History tab - clear tradeHistoryTotals
      _tradeHistoryTotals.value = null;
    }
    // Market/Pending tabs - keep accountInfo (shared between tabs)
    update(['account_info']);
  }

  // Tab management (simplified)
  void setSelectedTab(int tabIndex) {
    final previousTab = _selectedTab.value;

    if (previousTab != tabIndex) {
      // Clear old tab's data if needed
      if (previousTab == 2) {
        // Only clear History tab data when leaving it
        clearAccountMetricsForTab(previousTab);
      }

      // For History tab, load data if needed
      if (tabIndex == 2 &&
          (_lastDataTab.value != 2 || _tradeHistoryTotals.value == null)) {
        clearAccountMetricsForTab(tabIndex);
      }
    }

    _selectedTab.value = tabIndex;

    // Always refresh trade history API when switching to Close tab (index 2)
    if (tabIndex == 2) {
      // ✅ FIX: Only load if we don't already have data for History tab
      // This prevents unnecessary reloads that cause blinking
      if (_lastDataTab.value != 2 || _tradeHistoryTotals.value == null) {
        // If filters are active, preserve them; otherwise load without filters
        if (_currentFilterParams != null && _currentFilterParams!.isNotEmpty) {
          loadTradeHistory(
            page: 1,
            refresh: true,
            additionalParams: Map<String, String>.from(_currentFilterParams!),
          );
        } else {
          loadTradeHistory(page: 1, refresh: true);
        }
      }
    }

    // When switching to Market tab (index 0), ensure WebSocket is ready
    if (tabIndex == 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          if (Get.isRegistered<TradingWebSocketService>()) {
            final wsService = Get.find<TradingWebSocketService>();
            // Ensure connection to open positions endpoint is ready
            wsService.ensureOpenPositionsConnection();
          }
        } catch (e) {
          // Error ensuring open positions connection
        }
      });
    }

    // When switching to Pending tab (index 1), ensure pending orders WebSocket is ready
    if (tabIndex == 1) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          if (Get.isRegistered<TradingWebSocketService>()) {
            final wsService = Get.find<TradingWebSocketService>();
            // Ensure connection to pending orders endpoint is ready
            wsService.ensurePendingOrdersConnection();
          }
        } catch (e) {
          // Error ensuring pending orders connection
        }
      });
    }

    // When switching to Pending tab (index 1), ensure WebSocket is ready
    if (tabIndex == 1) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          if (Get.isRegistered<TradingWebSocketService>()) {
            final wsService = Get.find<TradingWebSocketService>();
            // Ensure connection to pending orders endpoint is ready
            wsService.ensurePendingOrdersConnection();
          }
        } catch (e) {
          // Error ensuring pending orders connection
        }
      });
    }

    // Refresh WebSocket subscription when switching between Market and Pending tabs
    // Market tab (0) uses subscribe_all_groups, Pending tab (1) uses subscribe_pending_orders
    // Add debounce to prevent rapid tab switches from causing issues
    if (previousTab != tabIndex &&
        (tabIndex == 0 ||
            tabIndex == 1 ||
            previousTab == 0 ||
            previousTab == 1)) {
      // Debounce: wait a bit before refreshing to avoid race conditions
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          if (Get.isRegistered<TradingWebSocketService>()) {
            final wsService = Get.find<TradingWebSocketService>();
            // Only refresh if still on the same tab (user didn't switch again)
            if (_selectedTab.value == tabIndex) {
              wsService.refreshDataForCurrentTab();
            }
          }
        } catch (e) {
          // Error refreshing WebSocket on tab change
        }
      });
    }
    // ✅ FIX: Call update() to ensure UI rebuilds when tab switches
    update();
  }

  // Instrument filtering
  void addInstrument(String instrument) {
    _selectedInstruments.add(instrument);
    _selectedInstruments.refresh(); // Force reactivity update
    // ✅ FIX: Call update() for GetBuilder compatibility
    update();
  }

  void removeInstrument(String instrument) {
    _selectedInstruments.remove(instrument);
    _selectedInstruments.refresh(); // Force reactivity update
    // ✅ FIX: Call update() for GetBuilder compatibility
    update();
  }

  void clearInstruments() {
    _selectedInstruments.clear();
    _selectedInstruments.refresh(); // Force reactivity update
    // ✅ FIX: Call update() for GetBuilder compatibility
    update();
  }

  // Direction filtering
  void setSelectedDirection(String direction) {
    _selectedDirection.value = direction;
    update();
  }

  // Tab-specific direction filtering
  void setPendingDirection(String direction) {
    _pendingDirection.value = direction;
    update();
  }

  void setClosedDirection(String direction) {
    _closedDirection.value = direction;
    update();
  }

  // Get current direction filter based on active tab
  String getCurrentDirectionFilter() {
    switch (_selectedTab.value) {
      case 1: // Pending tab
        return _pendingDirection.value;
      case 2: // Closed tab
        return _closedDirection.value;
      default: // Market tab (0) uses general direction
        return _selectedDirection.value;
    }
  }

  // Get count of filtered positions for current tab
  int getFilteredCount() {
    return getFilteredPositions().length;
  }

  // Get total count before filtering for current tab
  int getTotalCountBeforeFilter() {
    switch (_selectedTab.value) {
      case 0:
        return _marketPositions.length;
      case 1:
        return _pendingPositions.length;
      case 2:
        return _closedPositions.length;
      default:
        return 0;
    }
  }

  // Check if date filter is active
  bool get hasDateFilter => _hasDateFilter.value;

  // Set date filter state
  void setDateFilterActive(bool active) {
    _hasDateFilter.value = active;
    if (!active) {
      // Clear filter parameters when filter is deactivated
      _currentFilterParams = null;
      _activeFilterType.value = null;
    }
  }

  /// Clear date filter state
  void clearDateFilter() {
    _hasDateFilter.value = false;
    _currentFilterParams = null;
    _activeFilterType.value = null;
    // Also clear instrument filter when date filter is cleared
    clearInstruments();
  }

  /// Reset ALL filters (direction + instrument + date) and reload with today as default
  Future<void> resetAllFilters() async {
    // 1. Reset direction filters for all tabs
    _selectedDirection.value = 'All';
    _pendingDirection.value = 'All';
    _closedDirection.value = 'All';

    // 2. Clear instrument filter
    _selectedInstruments.clear();
    _selectedInstruments.refresh();

    // 3. Reset date filter to today as default
    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    final endOfToday = DateTime.utc(now.year, now.month, now.day);
    final fromTimestamp = startOfToday.millisecondsSinceEpoch ~/ 1000;
    final toTimestamp =
        endOfToday.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000 -
        1;

    await loadTradeHistoryWithTimestamps(
      page: 1,
      refresh: true,
      fromTimestamp: fromTimestamp,
      toTimestamp: toTimestamp,
      filterType: 'today',
    );

    // Force UI rebuild
    update();
  }

  /// Check if any filter is currently active (direction, instrument, or date)
  bool get isAnyFilterActive {
    if (_selectedTab.value != 2) return false;
    final directionActive = _closedDirection.value != 'All';
    final instrumentActive = _selectedInstruments.isNotEmpty;
    final dateActive = _hasDateFilter.value;
    return directionActive || instrumentActive || dateActive;
  }

  // Get all available instruments
  Set<String> get availableInstruments {
    Set<String> instruments = {};
    instruments.addAll(_closedPositions.map((p) => p.symbol));
    return instruments;
  }

  // Get filtered positions based on current tab and filters
  List<TradePosition> getFilteredPositions() {
    List<TradePosition> positions = [];

    switch (_selectedTab.value) {
      case 0: // Market
        positions = _marketPositions;
        break;
      case 1: // Pending
        positions = _pendingPositions;
        break;
      case 2: // Close
        positions = _closedPositions;
        break;
    }

    // Apply filters ONLY on the History tab (tab index 2)
    if (_selectedTab.value == 2) {
      // Apply instrument filter (match base symbols too)
      if (_selectedInstruments.isNotEmpty) {
        positions =
            positions.where((p) {
              // Check if exact symbol matches
              if (_selectedInstruments.contains(p.symbol)) {
                return true;
              }
              // Check if base symbol (without .c suffix) matches
              final baseSymbol = p.symbol.replaceFirst('.c', '');
              return _selectedInstruments.contains(baseSymbol) ||
                  _selectedInstruments.any(
                    (selected) => selected.replaceFirst('.c', '') == baseSymbol,
                  );
            }).toList();
      }

      // Apply direction filter (case-insensitive comparison) - tab-specific (tab 2 only)
      final directionFilter = _closedDirection.value;
      if (directionFilter != 'All') {
        positions =
            positions.where((p) {
              final positionAction = p.action.trim().toLowerCase();
              final selectedDirection = directionFilter.trim().toLowerCase();
              return positionAction == selectedDirection;
            }).toList();
      }
    }

    // Sort Market and Pending tabs positions by timestamp (newest first)
    if (_selectedTab.value == 0 || _selectedTab.value == 1) {
      // Create a copy before sorting to avoid modifying the observable list
      // This prevents issues during Flutter's draw frame cycle
      positions = List<TradePosition>.from(positions);
      positions.sort((a, b) {
        // Parse openTime to timestamp for comparison
        int getTimestamp(TradePosition pos) {
          if (pos.openTime.isEmpty) return 0;
          try {
            // Try parsing as ISO8601 string (standard format from WebSocket)
            final dateTime = DateTime.tryParse(pos.openTime);
            if (dateTime != null) {
              return dateTime.millisecondsSinceEpoch ~/
                  1000; // Convert to seconds
            }
            // If not ISO8601, try parsing as Unix timestamp string/number
            final timestamp = int.tryParse(pos.openTime);
            if (timestamp != null) {
              // If timestamp is in milliseconds (13+ digits), convert to seconds
              if (timestamp > 1000000000000) {
                return timestamp ~/ 1000;
              }
              return timestamp;
            }
          } catch (e) {
            // If parsing fails, return 0 (will be sorted last)
          }
          return 0;
        }

        final timestampA = getTimestamp(a);
        final timestampB = getTimestamp(b);
        // Sort descending (newest first) - higher timestamp comes first
        return timestampB.compareTo(timestampA);
      });
    }

    return positions;
  }

  // Position management
  Future<void> closePosition(String orderId, {double? volume}) async {
    try {
      _setLoading(true);
      _clearError();

      // Find the position to get account info
      final position = _marketPositions.firstWhere(
        (p) => p.orderId == orderId,
        orElse: () => throw Exception('Position not found'),
      );

      // Get correct mt5Account
      String accountToUse = position.accountId.isEmpty ? position.mt5Account : position.accountId;
      if (accountToUse.isEmpty) {
        if (Get.isRegistered<AccountController>()) {
          final accountController = Get.find<AccountController>();
          accountToUse = accountController.activeMT5Account?.metaAccountNumber ?? '';
        }
      }

      // Call the API to close position
      final response = await _tradingRepo.closePositionByPositionId(
        data: {
          'mt5_account': accountToUse,
          'position_id': int.parse(position.orderId),
          if (volume != null) 'volume': volume, // For partial close
        },
      );

      if (response.success) {
        // Only remove from UI if it's a full close
        if (volume == null) {
          // Mark as deleted to prevent websocket re-add
          markPositionAsDeleted(orderId);

          // Remove from market positions immediately (UI update)
          _marketPositions.removeWhere((p) => p.orderId == orderId);
          _marketPositions.refresh();

          // Force UI rebuild
          update();
        }

        _setSuccess('Position closed successfully');
      } else {
        _setError(response.message ?? 'Failed to close position');
      }
    } catch (e) {
      _setError('Failed to close position: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> closeAllPositions({String? mt5Account}) async {
    return _bulkClose(
      mt5Account: mt5Account,
      select: (_) => true,
      summary: 'All positions closed successfully',
    );
  }

  /// Bulk-close a caller-supplied list of positions (used by Meta/Celestial
  /// bottom sheets). Sends a single POST with `position_ids`.
  Future<void> closePositions(List<TradePosition> positions) async {
    if (positions.isEmpty) {
      _setError('No positions found to close');
      return;
    }
    final mt5Account = positions.first.accountId;
    return _bulkClose(
      mt5Account: mt5Account,
      select: (p) => positions.any((x) => x.orderId == p.orderId),
      summary: 'All positions closed successfully',
    );
  }

  /// Close position by position ID (more direct method)
  Future<bool> closePositionById({
    required String mt5Account,
    required int positionId,
    double? volume, // For partial close
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Get correct mt5Account
      String accountToUse = mt5Account;
      if (accountToUse.isEmpty) {
        if (Get.isRegistered<AccountController>()) {
          final accountController = Get.find<AccountController>();
          accountToUse = accountController.activeMT5Account?.metaAccountNumber ?? '';
        }
      }

      // Call the API to close position
      final response = await _tradingRepo.closePositionByPositionId(
        data: {
          'mt5_account': accountToUse,
          'position_id': positionId,
          if (volume != null) 'volume': volume, // For partial close
        },
      );

      if (response.success) {
        // Only remove from UI and mark as deleted if it's a FULL close (volume is null)
        // For partial close, we let the WebSocket update the remaining volume
        if (volume == null) {
          // ✅ FIX: Mark as deleted and remove immediately
          markPositionAsDeleted(positionId.toString());

          // Remove from market positions if it exists
          _marketPositions.removeWhere(
            (p) => p.orderId == positionId.toString(),
          );
          _marketPositions.refresh();

          // ✅ FIX: Call update() for GetBuilder compatibility
          update();
        }

        // Show API response message if available
        _setSuccess(response.message ?? 'Position closed successfully');

        // Play trade close sound when position is closed successfully
        try {
          await AudioService.playTradeCloseSound();
        } catch (e) {
        }

        return true;
      } else {
        _setError(response.message ?? 'Failed to close position');
        return false;
      }
    } catch (e) {
      _setError('Failed to close position: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update Take Profit and Stop Loss for a position
  Future<bool> updateTPSL({
    required String mt5Account,
    required int positionId,
    double? stopLoss,
    double? takeProfit,
    int? digits,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Validate inputs
      if (mt5Account.isEmpty) {
        _setError('MT5 account is required');
        return false;
      }
      if (positionId <= 0) {
        _setError('Invalid position ID');
        return false;
      }
      if (stopLoss == null && takeProfit == null) {
        _setError('At least one of Stop Loss or Take Profit must be provided');
        return false;
      }

      // Prepare payload
      final payload = {'mt5_account': mt5Account, 'position_id': positionId};

      // Add optional TP/SL values
      if (stopLoss != null) {
        payload['stop_loss'] = stopLoss == 0
            ? 0
            : (digits != null
                ? PrecisionHelper.round(stopLoss, decimals: digits)
                : stopLoss);
      }
      if (takeProfit != null) {
        payload['take_profit'] = takeProfit == 0
            ? 0
            : (digits != null
                ? PrecisionHelper.round(takeProfit, decimals: digits)
                : takeProfit);
      }

      // Call the API to update TP/SL
      final response = await _tradingRepo.updateTPSL(data: payload);

      if (response.success) {
        // No toast message - just return success
        return true;
      } else {
        _setError(
          response.message ?? 'Failed to update Take Profit and Stop Loss',
        );
        return false;
      }
    } catch (e) {
      _setError('Failed to update Take Profit and Stop Loss: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update Take Profit, Stop Loss, and Price for a Pending Order
  Future<bool> updatePendingOrderTPSL({
    required String mt5Account,
    required int orderId,
    double? price,
    double? stopLoss,
    double? takeProfit,
    int? digits,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Validate inputs
      if (mt5Account.isEmpty) {
        _setError('MT5 account is required');
        return false;
      }
      if (orderId <= 0) {
        _setError('Invalid order ID');
        return false;
      }

      // Prepare payload
      final payload = {'mt5_account': mt5Account, 'order_id': orderId};

      if (price != null) {
        payload['price'] = price == 0
            ? 0
            : (digits != null
                ? PrecisionHelper.round(price, decimals: digits)
                : price);
      }
      if (stopLoss != null) {
        payload['stop_loss'] = stopLoss == 0
            ? 0
            : (digits != null
                ? PrecisionHelper.round(stopLoss, decimals: digits)
                : stopLoss);
      }
      if (takeProfit != null) {
        payload['take_profit'] = takeProfit == 0
            ? 0
            : (digits != null
                ? PrecisionHelper.round(takeProfit, decimals: digits)
                : takeProfit);
      }

      // Call the API to update Pending Order TP/SL/Price
      final response = await _tradingRepo.updatePendingOrderTPSL(data: payload);

      if (response.success) {
        return true;
      } else {
        _setError(
          response.message ?? 'Failed to update Pending Order',
        );
        return false;
      }
    } catch (e) {
      _setError('Failed to update Pending Order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // New methods for closing different types of positions
  Future<void> _bulkClose({
    required String? mt5Account,
    required bool Function(TradePosition) select,
    required String summary,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      String accountToUse = mt5Account ?? '';
      if (accountToUse.isEmpty && _marketPositions.isNotEmpty) {
        accountToUse = _marketPositions.first.accountId;
      }
      if (accountToUse.isEmpty) {
        _setError('No MT5 account found to close positions');
        return;
      }
      final positionsToClose =
          _marketPositions
              .where((p) => p.accountId == accountToUse && select(p))
              .toList();
      if (positionsToClose.isEmpty) {
        _setError('No positions found to close');
        return;
      }
      final positionIds =
          positionsToClose
              .map((p) => int.tryParse(p.orderId))
              .whereType<int>()
              .toList();
      if (positionIds.isEmpty) {
        _setError('No valid position IDs found');
        return;
      }
      final response = await _tradingRepo.closePositionByPositionId(
        data: {'mt5_account': accountToUse, 'position_ids': positionIds},
      );
      if (response.success) {
        for (final id in positionIds) {
          markPositionAsDeleted(id.toString());
        }
        _marketPositions.removeWhere(
          (p) => p.accountId == accountToUse,
        );
        _marketPositions.refresh();
        update();
        _setSuccess(response.message ?? summary);
        try {
          await AudioService.playTradeCloseSound();
        } catch (e) {}
      } else {
        _setError(response.message ?? 'Failed to close positions');
      }
    } catch (e) {
      _setError('Failed to close positions: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> closeAllProfitablePositions({String? mt5Account}) async {
    return _bulkClose(
      mt5Account: mt5Account,
      select: (p) => p.profitLoss > 0,
      summary: 'All profitable positions closed successfully',
    );
  }

  Future<void> closeAllLosingPositions({String? mt5Account}) async {
    return _bulkClose(
      mt5Account: mt5Account,
      select: (p) => p.profitLoss < 0,
      summary: 'All losing positions closed successfully',
    );
  }

  Future<void> closeAllLongPositions({String? mt5Account}) async {
    return _bulkClose(
      mt5Account: mt5Account,
      select: (p) => p.action == 'Buy',
      summary: 'All long positions closed successfully',
    );
  }

  Future<void> closeAllShortPositions({String? mt5Account}) async {
    return _bulkClose(
      mt5Account: mt5Account,
      select: (p) => p.action == 'Sell',
      summary: 'All short positions closed successfully',
    );
  }

  // Helper methods to calculate totals for different position types
  double getTotalProfitLoss() {
    return _marketPositions.fold(0.0, (sum, p) => sum + p.profitLoss);
  }

  double getTotalProfitableProfitLoss() {
    return _marketPositions
        .where((p) => p.profitLoss > 0)
        .fold(0.0, (sum, p) => sum + p.profitLoss);
  }

  double getTotalLosingProfitLoss() {
    return _marketPositions
        .where((p) => p.profitLoss < 0)
        .fold(0.0, (sum, p) => sum + p.profitLoss);
  }

  double getTotalLongProfitLoss() {
    return _marketPositions
        .where((p) => p.action == 'Buy')
        .fold(0.0, (sum, p) => sum + p.profitLoss);
  }

  double getTotalShortProfitLoss() {
    return _marketPositions
        .where((p) => p.action == 'Sell')
        .fold(0.0, (sum, p) => sum + p.profitLoss);
  }

  int getProfitablePositionsCount() {
    return _marketPositions.where((p) => p.profitLoss > 0).length;
  }

  int getLosingPositionsCount() {
    return _marketPositions.where((p) => p.profitLoss < 0).length;
  }

  int getLongPositionsCount() {
    return _marketPositions.where((p) => p.action == 'Buy').length;
  }

  int getShortPositionsCount() {
    return _marketPositions.where((p) => p.action == 'Sell').length;
  }

  // History management
  void toggleHistoryExpansion(int index) {
    if (index < _historyEntries.length) {
      final entry = _historyEntries[index];
      final updatedEntry = HistoryEntry(
        type: entry.type,
        operation: entry.operation,
        profitLoss: entry.profitLoss,
        dateTime: entry.dateTime,
        device: entry.device,
        direction: entry.direction,
        openPrice: entry.openPrice,
        volume: entry.volume,
        isExpanded: !entry.isExpanded,
      );
      _historyEntries[index] = updatedEntry;
    }
  }

  // Utility methods
  void _setLoading(bool loading) {
    _isLoading.value = loading;
  }

  void _setError(String error) {
    _errorMessage.value = error;
    if (error.isNotEmpty) {
      // Get.snackbar('Error', error, snackPosition: SnackPosition.TOP);
      CustomToastService.showError(title: 'Error', message: error);
    }
  }

  void _setSuccess(String message) {
    _successMessage.value = message;
    if (message.isNotEmpty) {
      CustomToastService.showSuccess(title: 'Success', message: message);
      // Get.snackbar('Success', message, snackPosition: SnackPosition.TOP);
    }
  }

  void _clearError() {
    _errorMessage.value = '';
  }

  void clearMessages() {
    _errorMessage.value = '';
    _successMessage.value = '';
  }

  /// Remove position from list immediately (for Dismissible widget and WebSocket removes)
  void removePositionFromList(String orderId) {
    // ✅ CRITICAL FIX: Mark as deleted FIRST to prevent re-adding
    markPositionAsDeleted(orderId);

    // ✅ FIX: Also remove from pending updates queue to prevent re-adding
    _pendingPositionUpdates.remove(orderId);

    // Remove from list and force immediate refresh (bypass debounce)
    // ✅ FIX: Try both string and int comparison to handle different formats
    final index = _marketPositions.indexWhere(
      (p) =>
          p.orderId == orderId ||
          p.orderId == orderId.toString() ||
          (int.tryParse(p.orderId) != null &&
              int.tryParse(p.orderId) == int.tryParse(orderId)),
    );
    if (index >= 0) {
      _marketPositions.removeAt(index);
      _marketPositions.refresh(); // Immediate refresh - no debounce for removes
      // ✅ CRITICAL FIX: Also call update() to force full UI rebuild
      // This is especially important when removing the last position
      update(); // Force full UI rebuild for GetBuilder widgets
    } else {
      // Position not found - might have been removed already or ID format mismatch
      // Log for debugging
      // Still call update() in case the position was already removed but UI needs refresh
      update();
    }
  }

  /// Close position with immediate UI update (for Dismissible widget)
  Future<void> closePositionWithImmediateUpdate({
    required String mt5Account,
    required int positionId,
    double? volume,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Mark as deleted BEFORE API call to "freeze" updates for this position
      // This prevents UI flickering/jumping while the close operation is in progress
      markPositionAsDeleted(positionId.toString());

      // Call the API
      final response = await _tradingRepo.closePositionByPositionId(
        data: {
          'mt5_account': mt5Account,
          'position_id': positionId,
          if (volume != null) 'volume': volume,
        },
      );

      if (response.success) {
        // Success: Remove from UI permanently
        _marketPositions.removeWhere((p) => p.orderId == positionId.toString());
        _marketPositions.refresh();

        // Trigger full UI rebuild
        update();

        _setSuccess('Position closed successfully');

        // Play trade close sound
        try {
          await AudioService.playTradeCloseSound();
        } catch (e) {
        }
      } else {
        // Failure: Un-mark as deleted so it can resume receiving WebSocket updates
        _deletedPositionIds.remove(positionId.toString());
        _setError(response.message ?? 'Failed to close position');
      }
    } catch (e) {
      // Error: Un-mark as deleted
      _deletedPositionIds.remove(positionId.toString());
      _setError('Failed to close position: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel order with immediate UI update (for pending orders)
  Future<bool> cancelOrderWithImmediateUpdate({
    required String mt5Account,
    required int orderId,
  }) async {
    // Check if order is already being cancelled to prevent duplicate calls
    // if (_cancellingOrderIds.contains(orderId)) {
    //   return;
    // }

    // // Check if order still exists in pending list
    // final orderExists = _pendingPositions.any(
    //   (p) => p.orderId == orderId.toString(),
    // );

    // if (!orderExists) {
    //   // Order already removed (likely by socket), treat as success
    //   return;
    // }

    try {
      // Add to tracking set to prevent duplicate calls
      _cancellingOrderIds.add(orderId);
      _setLoading(true);
      _clearError();

      // Mark as deleted BEFORE API call to "freeze" updates
      markPendingOrderAsDeleted(orderId);

      // Call the API
      final response = await _tradingRepo.closePendingOrder(
        data: {
          'mt5_account': mt5Account,
          'orderIds': [orderId],
        },
      );

      // Handle response
      if (response.success) {
        // Success: Remove from list
        _pendingPositions.removeWhere((p) => p.orderId == orderId.toString());
        _pendingPositions.refresh();

        // Trigger full UI rebuild
        update();

        _setSuccess('Order cancelled successfully');
        return true;
      } else {
        // Check if error is "not found" - means order was already closed
        final errorMessage = response.message?.toLowerCase() ?? '';
        if (errorMessage.contains('not found') ||
            errorMessage.contains('already closed') ||
            errorMessage.contains('does not exist')) {
          _pendingPositions.removeWhere((p) => p.orderId == orderId.toString());
          _pendingPositions.refresh();
          update();
          _cancellingOrderIds.remove(orderId);
          return true;
        } else {
          _deletedPendingOrderIds.remove(orderId);
          _setError(response.message ?? 'Failed to cancel order');
          _cancellingOrderIds.remove(orderId);
          return false;
        }
      }
    } catch (e) {
      _cancellingOrderIds.remove(orderId);
      _deletedPendingOrderIds.remove(orderId);
      
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('not found') ||
          errorString.contains('already closed') ||
          errorString.contains('does not exist')) {
        _pendingPositions.removeWhere((p) => p.orderId == orderId.toString());
        _pendingPositions.refresh();
        update();
        return true;
      } else {
        _setError('Failed to cancel order: $e');
        return false;
      }
    } finally {
      // Remove from tracking set after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        _cancellingOrderIds.remove(orderId);
      });
      _setLoading(false);
    }
  }

  /// Close multiple pending orders at once
  Future<void> closeMultiplePendingOrders({
    required String mt5Account,
    required List<int> orderIds,
  }) async {
    List<int> existingOrders = []; // Declare outside try block for catch access

    try {
      _setLoading(true);
      _clearError();

      if (orderIds.isEmpty) {
        _setError('No orders to close');
        return;
      }

      // Filter out orders that are already being cancelled
      final ordersToCancel =
          orderIds.where((id) => !_cancellingOrderIds.contains(id)).toList();

      if (ordersToCancel.isEmpty) {
        return;
      }

      // Filter out orders that don't exist in pending list (already closed)
      existingOrders =
          ordersToCancel.where((id) {
            return _pendingPositions.any((p) => p.orderId == id.toString());
          }).toList();

      if (existingOrders.isEmpty) {
        return;
      }

      // Add all orders to tracking set
      for (final id in existingOrders) {
        _cancellingOrderIds.add(id);
      }

      // DON'T remove from UI immediately - let API response handle it
      // This prevents issues with Dismissible widget when closing last order

      final response = await _tradingRepo.closePendingOrder(
        data: {'mt5_account': mt5Account, 'orderIds': existingOrders},
      );

      if (response.success) {
        // Mark each as deleted
        for (final id in existingOrders) {
          markPendingOrderAsDeleted(id);
        }

        // Use API response message if available, otherwise use default
        _setSuccess(
          response.message ??
              '${existingOrders.length} orders cancelled successfully',
        );

        // Remove from list immediately after successful API call
        final orderIdSet = existingOrders.map((id) => id.toString()).toSet();
        _pendingPositions.removeWhere((p) => orderIdSet.contains(p.orderId));
        _pendingPositions.refresh(); // Force UI update

        // ✅ FIX: Call update() for GetBuilder compatibility
        update();
      } else {
        // Check if error is "not found" - means some orders were already closed
        final errorMessage = response.message?.toLowerCase() ?? '';
        if (errorMessage.contains('not found') ||
            errorMessage.contains('already closed') ||
            errorMessage.contains('does not exist')) {
          // Some orders already closed, remove them
          final orderIdSet = existingOrders.map((id) => id.toString()).toSet();
          _pendingPositions.removeWhere((p) => orderIdSet.contains(p.orderId));
          _pendingPositions.refresh(); // Force UI update
        } else {
          // Real error - show it
          _setError(response.message ?? 'Failed to cancel orders');
        }
      }
    } catch (e) {
      // Check if error is "not found" related
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('not found') ||
          errorString.contains('already closed') ||
          errorString.contains('does not exist')) {
        // Orders already closed, remove them if existingOrders is not empty
        if (existingOrders.isNotEmpty) {
          final orderIdSet = existingOrders.map((id) => id.toString()).toSet();
          _pendingPositions.removeWhere((p) => orderIdSet.contains(p.orderId));
          _pendingPositions.refresh(); // Force UI update
        }
      } else {
        // Real error - show it
        _setError('Failed to cancel orders: $e');
      }
    } finally {
      // Remove all orders from tracking set after a short delay
      // This gives WebSocket time to process the removals
      Future.delayed(const Duration(seconds: 2), () {
        for (final id in orderIds) {
          _cancellingOrderIds.remove(id);
        }
      });
      _setLoading(false);
    }
  }

  /// Load trade history with pagination
  Future<void> loadTradeHistory({
    int page = 1,
    bool refresh = false,
    Map<String, String>? additionalParams,
  }) async {
    try {
      _isLoadingHistory.value = true;
      _clearError();

      // Get active MT5 account. The trade-history endpoint requires
      // mt5_account to be a real account number — sending an empty
      // string makes the broker reply with
      // "Account number is required. Please provide login,
      // trading_account, or mt5_account parameter" and returns an
      // empty list, which the screen then renders as
      // "No history for <period>". Skip the call and surface a clear
      // message instead.
      String mt5Account = '';
      try {
        final accountController = Get.find<AccountController>();
        final activeAccount = accountController.activeMT5Account;
        mt5Account = activeAccount?.metaAccountNumber ?? '';
      } catch (e) {
        // Error getting active account
      }

      if (mt5Account.isEmpty) {
        if (refresh || page == 1) {
          _tradeHistory.clear();
          _paginationInfo.value = null;
          _tradeHistoryTotals.value = null;
          _tradeHistorySummary.value = null;
          update(['account_info']);
        }
        _setError('No active trading account.');
        return;
      }

      // Build query parameters matching the API format:
      // ?page=1&per_page=10&mt5_account=2000000&from=YYYY-MM-DD&to=YYYY-MM-DD
      final now = DateTime.now().toUtc();
      final defaultStartDate = now.subtract(const Duration(days: 7));
      final defaultFromStr =
          '${defaultStartDate.year}-${defaultStartDate.month.toString().padLeft(2, '0')}-${defaultStartDate.day.toString().padLeft(2, '0')}';
      final defaultToStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': '10',
        'mt5_account': mt5Account,
        '_t': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      };

      // Add additional parameters if provided (including date filters)
      if (additionalParams != null) {
        queryParams.addAll(additionalParams);
      }

      // Only add default dates if no date params provided by filters
      final hasDateFilter =
          queryParams.containsKey('from') || queryParams.containsKey('to');
      if (!hasDateFilter) {
        queryParams['from'] = defaultFromStr;
        queryParams['to'] = defaultToStr;
      }

      final response = await _tradingRepo.getTradeHistory(
        queryParameters: Map<String, dynamic>.from(queryParams),
      );

      if (response.success && response.data != null) {
        final tradeHistoryResponse = TradeHistoryResponse.fromJson(
          response.data!,
        );

        if (refresh || page == 1) {
          _tradeHistory.clear();
          _tradeHistory.value = tradeHistoryResponse.data;
        } else {
          _tradeHistory.addAll(tradeHistoryResponse.data);
        }

        _paginationInfo.value = tradeHistoryResponse.pagination;

        // Store totals and summary
        _tradeHistoryTotals.value  = tradeHistoryResponse.totals;
        _tradeHistorySummary.value = tradeHistoryResponse.summary;

        if (tradeHistoryResponse.totals != null) {
          _lastDataTab.value = 2;
        } else {
          _lastDataTab.value = null;
        }

        update(['account_info']);

        // Update closed positions for compatibility with existing UI
        _updateClosedPositionsFromHistory();
      } else {
        _setError(response.message ?? 'Failed to load trade history');
      }
    } catch (e) {
      _setError('Failed to load trade history: $e');
    } finally {
      _isLoadingHistory.value = false;
    }
  }

  /// Load next page of trade history
  Future<void> loadNextPage() async {
    final pagination = _paginationInfo.value;
    if (pagination != null && pagination.hasNextPage) {
      final nextPage = pagination.currentPage + 1;

      // Preserve all filter parameters if any filters are active
      if (_currentFilterParams != null && _currentFilterParams!.isNotEmpty) {
        await loadTradeHistory(
          page: nextPage,
          refresh: false, // Important: don't clear existing data
          additionalParams: Map<String, String>.from(_currentFilterParams!),
        );
      } else {
        // No filter active, load without filter parameters
        await loadTradeHistory(
          page: nextPage,
          refresh: false, // Important: don't clear existing data
        );
      }
    } else {
    }
  }

  /// Load trade history with specific filters
  Future<void> loadTradeHistoryWithFilters({
    int page = 1,
    bool refresh = false,
    String? symbol,
    String? action,
    String? dateFrom,
    String? dateTo,
    String? sortBy,
    String? sortDirection,
  }) async {
    final additionalParams = <String, String>{};

    if (symbol != null && symbol.isNotEmpty) {
      additionalParams['symbol'] = symbol;
    }
    if (action != null && action.isNotEmpty) {
      additionalParams['action'] = action;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      additionalParams['from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      additionalParams['to'] = dateTo;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      additionalParams['sort_by'] = sortBy;
    }
    if (sortDirection != null && sortDirection.isNotEmpty) {
      additionalParams['sort_direction'] = sortDirection;
    }

    // Store filter parameters for pagination
    if (additionalParams.isNotEmpty) {
      _currentFilterParams = Map<String, String>.from(additionalParams);
      _hasDateFilter.value = dateFrom != null || dateTo != null;
    } else {
      _currentFilterParams = null;
      _hasDateFilter.value = false;
    }

    await loadTradeHistory(
      page: page,
      refresh: refresh,
      additionalParams: additionalParams,
    );
  }

  /// Load trade history with timestamp filters
  Future<void> loadTradeHistoryWithTimestamps({
    int page = 1,
    bool refresh = true,
    required int fromTimestamp,
    required int toTimestamp,
    String? filterType, // 'today', 'thisWeek', 'thisMonth', 'custom'
    List<String>? symbols,
  }) async {
    _hasDateFilter.value = true;

    // Convert timestamps to date strings in YYYY-MM-DD format (UTC)
    final fromDate = DateTime.fromMillisecondsSinceEpoch(
      fromTimestamp * 1000,
      isUtc: true,
    );
    final toDate = DateTime.fromMillisecondsSinceEpoch(
      toTimestamp * 1000,
      isUtc: true,
    );

    // Format dates as YYYY-MM-DD
    final fromDateStr =
        '${fromDate.year.toString().padLeft(4, '0')}-'
        '${fromDate.month.toString().padLeft(2, '0')}-'
        '${fromDate.day.toString().padLeft(2, '0')}';
    final toDateStr =
        '${toDate.year.toString().padLeft(4, '0')}-'
        '${toDate.month.toString().padLeft(2, '0')}-'
        '${toDate.day.toString().padLeft(2, '0')}';

    // Use from/to to match API format:
    // ?page=1&per_page=10&mt5_account=2000000&from=YYYY-MM-DD&to=YYYY-MM-DD
    final additionalParams = <String, String>{
      'from': fromDateStr,
      'to': toDateStr,
    };
    
    if (symbols != null && symbols.isNotEmpty && !symbols.contains('all')) {
      additionalParams['symbol'] = symbols.join(',');
    }

    // Store all filter parameters for pagination
    _currentFilterParams = Map<String, String>.from(additionalParams);

    // Store the filter type so the filter sheet can pre-select it
    if (filterType != null) {
      _activeFilterType.value = filterType;
    }

    await loadTradeHistory(
      page: page,
      refresh: refresh,
      additionalParams: additionalParams,
    );
  }

  /// High-level filter entry-point used by the History tab Filter dialog.
  /// Maps [period] ('today' / 'week' / 'month' / 'threeMonth' / 'custom') to a
  /// start/end DateTime pair, caches them in [_historyStartDate] /
  /// [_historyEndDate] so the date row stays in sync, and forwards to
  /// [loadTradeHistoryWithTimestamps] with the appropriate filterType
  /// so the API matches the existing 'today' / 'thisWeek' / etc. labels.
  ///
  /// [direction] — 'All' / 'Buy' / 'Sell' applied client-side via
  /// [_closedDirection] so the existing [getFilteredPositions] pipeline
  /// keeps working.
  /// [customStart] / [customEnd] — required when [period] == 'custom'.
  Future<void> applyHistoryFilter({
    String? period,
    List<String>? symbols,
    String? direction,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    period ??= _historyFilterPeriod;
    _historyFilterPeriod = period;

    if (direction != null) {
      _closedDirection.value = direction;
    }

    final now = DateTime.now();
    DateTime start;
    DateTime end;
    String filterType;
    switch (period) {
      case 'week':
        start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        end = DateTime(now.year, now.month, now.day);
        filterType = 'thisWeek';
        break;
      case 'month':
        start = DateTime(now.year, now.month - 1, now.day);
        end = DateTime(now.year, now.month, now.day);
        filterType = 'thisMonth';
        break;
      case 'threeMonth':
        start = DateTime(now.year, now.month - 3, now.day);
        end = DateTime(now.year, now.month, now.day);
        filterType = 'last3Months';
        break;
      case 'custom':
        final cs = customStart ?? _historyStartDate ??
            DateTime(now.year, now.month, now.day);
        final ce = customEnd ?? _historyEndDate ??
            DateTime(now.year, now.month, now.day);
        if (cs.isAfter(ce)) {
          start = DateTime(ce.year, ce.month, ce.day);
          end = DateTime(cs.year, cs.month, cs.day);
        } else {
          start = DateTime(cs.year, cs.month, cs.day);
          end = DateTime(ce.year, ce.month, ce.day);
        }
        filterType = 'custom';
        break;
      case 'today':
      default:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day);
        filterType = 'today';
        break;
    }
    _historyStartDate = start;
    _historyEndDate = end;
    _historyFilterInitialized = true;

    if (symbols != null) {
      _historySelectedSymbols
        ..clear()
        ..addAll(symbols);
    }

    // Sync client-side instrument filter used by getFilteredPositions().
    // - ['all'] / empty  → clear so every symbol passes through
    // - explicit list    → apply as-is so rows outside the selection are hidden
    //   (this is what surfaces the empty state when the API returns 0 rows
    //   for the chosen symbols)
    _selectedInstruments.clear();
    final effective = (symbols ?? _historySelectedSymbols)
        .where((s) => s.isNotEmpty && s != 'all')
        .toSet();
    if (effective.isNotEmpty) {
      _selectedInstruments.addAll(effective);
    }
    _selectedInstruments.refresh();

    update(['history_filter']);

    final fromTimestamp = _historyStartDate!.millisecondsSinceEpoch ~/ 1000;
    final toTimestamp = _historyEndDate!
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch ~/
            1000 -
        1;

    await loadTradeHistoryWithTimestamps(
      fromTimestamp: fromTimestamp,
      toTimestamp: toTimestamp,
      filterType: filterType,
      symbols: symbols ?? _historySelectedSymbols,
    );
  }

  /// Reset to today and reload.
  Future<void> resetHistoryFilter() async {
    _historySelectedSymbols
      ..clear()
      ..add('all');
    _closedDirection.value = 'All';
    await applyHistoryFilter(
      period: 'today',
      symbols: const ['all'],
      direction: 'All',
    );
  }

  /// Refresh trade history (load first page)
  Future<void> refreshTradeHistory() async {
    // If filters are active, preserve them
    if (_currentFilterParams != null && _currentFilterParams!.isNotEmpty) {
      await loadTradeHistory(
        page: 1,
        refresh: true,
        additionalParams: Map<String, String>.from(_currentFilterParams!),
      );
    } else {
      await loadTradeHistory(page: 1, refresh: true);
    }
  }

  /// Update closed positions from trade history for UI compatibility
  void _updateClosedPositionsFromHistory() {
    _closedPositions.value =
        _tradeHistory.map((item) {
          final positionData = item.toTradePositionMap();
          return TradePosition(
            symbol: positionData['symbol'],
            flag: positionData['flag'],
            action: positionData['action'],
            volume: positionData['volume'],
            profitLoss: positionData['profitLoss'],
            entryPrice: positionData['entryPrice'],
            currentPrice: positionData['currentPrice'],
            accountId: positionData['accountId'],
            orderId: positionData['orderId'],
            isFavorite: positionData['isFavorite'],
            openTime: positionData['openTime'],
            closeTime: positionData['closeTime'],
            reason: positionData['reason'],
            orderNo: positionData['orderNo'],
            commission: positionData['commission'],
            swap: positionData['swap'],
            takeProfit: positionData['takeProfit'],
            stopLoss: positionData['stopLoss'],
            mt5Account: positionData['mt5Account'],
            time: positionData['time'],
            duration: positionData['duration'] ?? '',
            digits: positionData['digits'] ?? 5,
          );
        }).toList();

    // ✅ FIX: Call update() for GetBuilder compatibility
    update();
  }

  /// Check if there are more pages to load
  bool get hasMoreHistoryPages {
    final pagination = _paginationInfo.value;
    return pagination?.hasNextPage ?? false;
  }

  /// Get current page number
  int get currentHistoryPage {
    final pagination = _paginationInfo.value;
    return pagination?.currentPage ?? 1;
  }

  /// Get total pages
  int get totalHistoryPages {
    final pagination = _paginationInfo.value;
    return pagination?.lastPage ?? 1;
  }

  /// Clear all trading data (called on logout)
  /// [preserveHistoryData] - If true, preserves History tab data (totals and lastDataTab)
  /// If not specified, automatically preserves History data if currently on History tab
  /// [resetTab] - If true, resets selected tab to 0 (default: true for logout, false for account switches)
  void clearAllTradingData({bool? preserveHistoryData, bool resetTab = true}) {
    // ✅ FIX: Auto-detect if we should preserve History data
    // If preserveHistoryData is not explicitly set, check if we're on History tab
    // Store current tab BEFORE any changes
    final currentTab = _selectedTab.value;
    final shouldPreserveHistory = preserveHistoryData ?? (currentTab == 2);

    // ✅ FIX: If preserving History, also preserve the tab (don't reset to 0)
    // This ensures subsequent calls also preserve History data
    final shouldResetTab = resetTab && !shouldPreserveHistory;

    // ✅ FIX: Clear all position data immediately and force UI update
    // Use .value = [] to trigger immediate UI update, not just .clear()
    _marketPositions.value = [];
    _pendingPositions.value = [];
    _closedPositions.value = [];
    _historyEntries.value = [];
    _tradeHistory.value = [];

    // Clear WebSocket data
    _websocketData.value = null;
    _accountInfo.value = null;
    _paginationInfo.value = null;

    // ✅ FIX: Only clear History data if not preserving it
    // This prevents History tab data from disappearing during account switches
    if (!shouldPreserveHistory) {
      _tradeHistoryTotals.value  = null;
      _tradeHistorySummary.value = null;
      _lastDataTab.value = null;
    }

    // Clear filters and selections
    _selectedInstruments.clear();
    _selectedDirection.value = 'All';
    _pendingDirection.value = 'All';
    _closedDirection.value = 'All';

    // ✅ FIX: Only reset tab if explicitly requested AND not preserving History
    // Don't reset tab during account switches to preserve History data
    if (shouldResetTab) {
      _selectedTab.value = 0;
    }

    // Clear messages
    _errorMessage.value = '';
    _successMessage.value = '';
    _isLoading.value = false;
    _isLoadingHistory.value = false;

    // Clear deleted ID tracking sets (prevent memory buildup on account switch/logout)
    _deletedPositionIds.clear();
    _deletedPendingOrderIds.clear();
    _cancellingOrderIds.clear();
    _pendingPositionUpdates.clear();

    // ✅ FIX: Force immediate UI refresh to show cleared state
    _marketPositions.refresh();
    _pendingPositions.refresh();
    _closedPositions.refresh();
    _historyEntries.refresh();
    _tradeHistory.refresh();

    // Trigger full UI rebuild
    update();
  }

  /// Reset to initial state (called on login)
  void resetToInitialState() {
    clearAllTradingData();
    _initializeSampleData();
  }

  // ==================== ENHANCED TRADING METHODS ====================

  /// Set the current trading symbol and update pip values
  void setCurrentSymbol(String symbol) {
    _currentSymbol.value = symbol;
    _updatePipValues(symbol);
  }

  /// Update pip values based on symbol type
  void _updatePipValues(String symbol) {
    if (symbol.contains('JPY')) {
      _pipGapValue.value = 0.01;
      _pipSLTPValue.value = 0.01;
    } else if (symbol.contains('XAU') || symbol.contains('GOLD')) {
      _pipGapValue.value = 0.01;
      _pipSLTPValue.value = 0.01;
    } else if (symbol.contains('XAG') || symbol.contains('SILVER')) {
      _pipGapValue.value = 0.001;
      _pipSLTPValue.value = 0.001;
    } else {
      // Default for major currency pairs
      _pipGapValue.value = 0.0001;
      _pipSLTPValue.value = 0.0001;
    }
  }

  /// Update current market prices
  void updateMarketPrices(double bidPrice, double askPrice) {
    _currentBidPrice.value = bidPrice;
    _currentAskPrice.value = askPrice;

    // Log price updates (only for important symbols to avoid spam)
    if (_currentSymbol.value.isNotEmpty &&
        (_currentSymbol.value.contains('EUR') ||
            _currentSymbol.value.contains('XAU') ||
            _currentSymbol.value.contains('GBP'))) {
      LoggingUtils.logPriceUpdate(
        symbol: _currentSymbol.value,
        bidPrice: bidPrice,
        askPrice: askPrice,
      );
    }
  }

  /// Set the selected order type
  void setOrderType(OrderType orderType) {
    _selectedOrderType.value = orderType;
  }

  /// Get pip value for a given price
  double getPipValue(String price) {
    if (price.isEmpty) return 0.0;
    return double.tryParse(price) ?? 0.0;
  }

  /// Get decimal digits for price formatting
  int getDecimalDigits(String price) {
    if (price.isEmpty) return 5;
    final parts = price.split('.');
    return parts.length > 1 ? parts[1].length : 5;
  }

  /// Calculate pip gap for price validation
  /// FIXED: pipGapValue is already set correctly based on symbol type
  /// - JPY/XAU: 0.01, XAG: 0.001, Major pairs: 0.0001
  double calculatePipGap(String price) {
    return pipGapValue; // Return directly, no need to multiply by full price
  }

  /// Calculate pip gap for SL/TP validation
  /// FIXED: pipSLTPValue is already set correctly based on symbol type
  double calculateSLTPPipGap(String price) {
    return pipSLTPValue; // Return directly, no need to multiply by full price
  }

  /// Validate price for order type
  String? validateOrderPrice(String price, OrderType orderType) {
    if (price.isEmpty) {
      if (orderType.requiresPrice) {
        return "Please add price!!";
      }
      return null;
    }

    final priceValue = double.tryParse(price);
    if (priceValue == null || priceValue <= 0) {
      return "Please enter a valid price";
    }

    final currentPrice =
        orderType.isBuyOrder ? currentAskPrice : currentBidPrice;
    final pipGap = calculatePipGap(price);

    switch (orderType) {
      case OrderType.buyLimit:
        final difference = currentPrice - priceValue;
        if (difference < pipGap) {
          return "Price too close to current market price (need ${pipGap.toStringAsFixed(2)} gap, have ${difference.toStringAsFixed(2)})";
        }
        break;
      case OrderType.sellLimit:
        final difference = priceValue - currentPrice;
        if (difference < pipGap) {
          return "Price too close to current market price (need ${pipGap.toStringAsFixed(2)} gap, have ${difference.toStringAsFixed(2)})";
        }
        break;
      case OrderType.buyStop:
        final difference = priceValue - currentPrice;
        if (difference < pipGap) {
          return "Price too close to current market price (need ${pipGap.toStringAsFixed(2)} gap, have ${difference.toStringAsFixed(2)})";
        }
        break;
      case OrderType.sellStop:
        final difference = currentPrice - priceValue;
        if (difference < pipGap) {
          return "Price too close to current market price (need ${pipGap.toStringAsFixed(2)} gap, have ${difference.toStringAsFixed(2)})";
        }
        break;
      default:
        break;
    }

    return null;
  }

  /// Validate SL/TP values
  String? validateSLTP(
    String slValue,
    String tpValue,
    OrderType orderType,
    String entryPrice,
  ) {
    if (slValue.isEmpty && tpValue.isEmpty) return null;

    final entryPriceValue = double.tryParse(entryPrice) ?? 0.0;
    final slPriceValue = slValue.isNotEmpty ? double.tryParse(slValue) : null;
    final tpPriceValue = tpValue.isNotEmpty ? double.tryParse(tpValue) : null;
    final sltpGap = calculateSLTPPipGap(entryPrice);

    // Validate Take Profit
    if (tpPriceValue != null) {
      if (orderType.isBuyOrder) {
        // For buy orders, TP should be above entry price
        if (tpPriceValue <= entryPriceValue + sltpGap) {
          return "Take Profit should be above entry price";
        }
      } else {
        // For sell orders, TP should be below entry price
        if (tpPriceValue >= entryPriceValue - sltpGap) {
          return "Take Profit should be below entry price";
        }
      }
    }

    // Validate Stop Loss
    if (slPriceValue != null) {
      if (orderType.isBuyOrder) {
        // For buy orders, SL should be below entry price
        if (slPriceValue >= entryPriceValue - sltpGap) {
          return "Stop Loss should be below entry price";
        }
      } else {
        // For sell orders, SL should be above entry price
        if (slPriceValue <= entryPriceValue + sltpGap) {
          return "Stop Loss should be above entry price";
        }
      }
    }

    return null;
  }

  /// Place a trade order with enhanced validation
  Future<bool> placeTradeOrder({
    required String symbol,
    required String volume,
    required OrderType orderType,
    String? price,
    String? takeProfit,
    String? stopLoss,
    String? stopLimitPrice,
    String? mt5Account,
  }) async {
    try {
      // Log order placement attempt
      LoggingUtils.logOrderPlacement(
        symbol: symbol,
        orderType: orderType.value.toString(),
        volume: volume,
        price: price,
        takeProfit: takeProfit,
        stopLoss: stopLoss,
      );

      _setLoading(true);
      _clearError();

      // Validate inputs
      if (symbol.isEmpty) {
        _setError('Symbol is required');
        return false;
      }

      if (volume.isEmpty ||
          double.tryParse(volume) == null ||
          double.parse(volume) <= 0) {
        _setError('Please add lot size!!');
        return false;
      }

      // Validate price for limit/stop orders
      final priceValidation = validateOrderPrice(price ?? '', orderType);
      if (priceValidation != null) {
        // Uncomment the next line to bypass validation for testing
        // _setError(priceValidation);
        // return false;
      }

      // Validate SL/TP
      double actualBid = currentBidPrice;
      double actualAsk = currentAskPrice;

      if (actualBid == 0.0 || actualAsk == 0.0) {
        if (Get.isRegistered<InstrumentsController>()) {
          final instCtrl = Get.find<InstrumentsController>();
          final quote = instCtrl.priceRx(symbol).value;
          if (quote != null) {
            actualBid = quote.bid;
            actualAsk = quote.ask;
          }
        }
      }

      final entryPrice = (price != null && price.isNotEmpty)
          ? price
          : (orderType.isBuyOrder
              ? actualAsk.toString()
              : actualBid.toString());

      final sltpValidation = validateSLTP(
        stopLoss ?? '',
        takeProfit ?? '',
        orderType,
        entryPrice,
      );
      if (sltpValidation != null) {
        _setError(sltpValidation);
        return false;
      }

      // Prepare payload
      String accountToUse = mt5Account ?? '';
      if (accountToUse.isEmpty) {
        if (Get.isRegistered<AccountController>()) {
          final accountController = Get.find<AccountController>();
          accountToUse = accountController.activeMT5Account?.metaAccountNumber ?? '';
        }
      }

      final payload = {
        'symbol': symbol,
        'volume': volume,
        'type': orderType.apiString,
        'mt5_account': accountToUse,
      };

      // Add optional parameters
      if (price != null && price.isNotEmpty) {
        payload['price'] = price;
      }
      if (takeProfit != null && takeProfit.isNotEmpty) {
        payload['take_profit'] = takeProfit;
        payload['tp'] = takeProfit;
      }
      if (stopLoss != null && stopLoss.isNotEmpty) {
        payload['stop_loss'] = stopLoss;
        payload['sl'] = stopLoss;
      }
      if (stopLimitPrice != null && stopLimitPrice.isNotEmpty) {
        payload['stop_limit_price'] = stopLimitPrice;
      }

      // Log the API call details
      AppLogger.api('''
API Call Details:
- Endpoint: ${ApiConstants.placeOrder}
- Full URL: ${ApiConstants.baseUrl}${ApiConstants.placeOrder}
- Payload: $payload
- Headers: Content-Type: application/json, Accept: application/json
      ''');

      // Call the API
      final response = await _tradingRepo.placeOrder(data: payload);

      // Log the API response
      AppLogger.api('''
API Response:
- Success: ${response.success}
- Message: ${response.message}
- Data: ${response.data}

      ''');

      // response.success is true only when:
      // 1. HTTP status code is 200
      // 2. API response has status: true
      if (response.success) {
        AppLogger.order('order is order${response.data}');
        AppLogger.order(
          'Order placed successfully - $symbol ${orderType.displayName}',
        );

        // Play success sound for both buy and sell orders when response is successful
        // Audio plays when HTTP status is 200 AND API status is true
        try {
          // Play audio - don't await to avoid blocking UI
          AudioService.playSuccessSound().catchError((audioError, stackTrace) {
            // Don't fail the order if audio fails
          });
        } catch (audioError) {
          // Don't fail the order if audio fails
        }

        _setSuccess('Order placed successfully');
        return true;
      } else {
        AppLogger.error('Failed to place order: ${response.message}');
        final accountLabel = accountToUse.isNotEmpty ? ' (A/C: $accountToUse)' : '';
        _setError('${response.message ?? 'Failed to place order'}$accountLabel');
        return false;
      }
    } catch (e) {
      AppLogger.error('Exception placing order: $e', error: e);
      _setError('Failed to place order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Helper to get point value (1 in the last decimal place)
  double _getPointValue(int decimals) {
    if (decimals <= 0) return 1.0;
    if (decimals == 1) return 0.1;
    if (decimals == 2) return 0.01;
    if (decimals == 3) return 0.001;
    if (decimals == 4) return 0.0001;
    if (decimals == 5) return 0.00001;
    if (decimals == 6) return 0.000001;
    if (decimals == 7) return 0.0000001;
    if (decimals == 8) return 0.00000001;
    double val = 1.0;
    for (int i = 0; i < decimals; i++) {
      val /= 10.0;
    }
    return val;
  }

  /// Adjust price by pip value
  String adjustPriceByPip(
    String currentPrice,
    bool isIncrease,
    OrderType orderType, {
    required int decimals,
  }) {
    if (currentPrice.isEmpty) {
      final defaultPrice =
          orderType.isBuyOrder ? currentAskPrice : currentBidPrice;
      return PrecisionHelper.formatPrice(
        defaultPrice,
        decimals: decimals,
      );
    }

    final priceValue = double.tryParse(currentPrice) ?? 0.0;
    final stepValue = _getPointValue(decimals);
    final adjustment = isIncrease ? stepValue : -stepValue;

    // Apply order type specific logic
    double newValue = priceValue + adjustment;

    return PrecisionHelper.formatPrice(
      newValue,
      decimals: decimals,
    );
  }

  /// Adjust SL/TP by pip value
  String adjustSLTPByPip(
    String currentValue,
    bool isIncrease,
    OrderType orderType,
    String entryPrice, {
    required int decimals,
  }) {
    if (currentValue.isEmpty) {
      final entryPriceValue = double.tryParse(entryPrice) ?? 0.0;
      final stepValue = _getPointValue(decimals);
      final defaultValue =
          isIncrease ? entryPriceValue + stepValue : entryPriceValue - stepValue;
      return PrecisionHelper.formatPrice(
        defaultValue,
        decimals: decimals,
      );
    }

    final currentValueNum = double.tryParse(currentValue) ?? 0.0;
    final stepValue = _getPointValue(decimals);
    final adjustment = isIncrease ? stepValue : -stepValue;
    final newValue = currentValueNum + adjustment;

    return PrecisionHelper.formatPrice(
      newValue,
      decimals: decimals,
    );
  }

  /// Check if order type is enabled for current market conditions
  bool isOrderTypeEnabled(OrderType orderType) {
    switch (orderType) {
      case OrderType.buyMarket:
      case OrderType.sellMarket:
      case OrderType.buyLimit:
      case OrderType.buyStop:
      case OrderType.buyStopLimit:
      case OrderType.sellLimit:
      case OrderType.sellStop:
      case OrderType.sellStopLimit:
        return true; // All order types are enabled
    }
  }

  /// Get available order types for current symbol
  List<OrderType> getAvailableOrderTypes() {
    return OrderType.values.where((type) => isOrderTypeEnabled(type)).toList();
  }
}
