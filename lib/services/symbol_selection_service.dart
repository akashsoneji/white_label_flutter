import 'package:get/get.dart';
import 'package:crm_app/screens/trading/view_models/instruments_controller.dart';
import 'package:crm_app/services/market_watch_v2_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';

/// Maintains the last selected trading symbol.
/// - With no saved choice, defaults to [fallbackSymbol] (user's watchlist /
///   broker instrument list — never a hardcoded symbol).
/// - Persisted across app restarts. A restored symbol that is no longer a
///   favourite is replaced once by the chart screen on startup.
class SymbolSelectionService extends GetxService {
  final RxString _lastSymbol = ''.obs;
  final RxBool _hasUserSelection = false.obs;
  bool _initialized = false;
  bool _isRestoredSelection = false;

  @override
  void onInit() {
    super.onInit();
    _ensureInitialized();
    ever(_lastSymbol, (String symbol) {
      if (symbol.isNotEmpty) {
        _hasUserSelection.value = true;
        SecureStorageService.saveSelectedSymbol(symbol);
      }
    });
  }

  String get currentSymbol => _lastSymbol.value;
  RxString get lastSymbolRx => _lastSymbol;
  bool get hasUserSelection => _hasUserSelection.value;

  /// True while the current symbol is the one restored from the previous
  /// session (cleared as soon as a symbol is picked in this session).
  bool get isRestoredSelection => _isRestoredSelection;

  /// Update the current symbol and mark that the user made an explicit choice.
  void setSymbol(String symbol) {
    if (symbol.isEmpty) return;
    _isRestoredSelection = false;
    _lastSymbol.value = symbol;
    _hasUserSelection.value = true;
    // Persist asynchronously; caller doesn't need to await
    SecureStorageService.saveSelectedSymbol(symbol);
  }

  /// Ensure there is a default symbol when nothing has been set yet.
  Future<void> ensureDefault() async {
    await _ensureInitialized();
  }

  /// Reset back to default and clear the user selection flag.
  void resetToDefault() {
    _isRestoredSelection = false;
    _lastSymbol.value = '';
    _hasUserSelection.value = false;
    SecureStorageService.saveSelectedSymbol('');
  }

  /// Default symbol when nothing is selected: the user's first favourite,
  /// else the first instrument the broker sent, else '' (not loaded yet —
  /// callers re-check once instruments arrive).
  static String fallbackSymbol() {
    if (!Get.isRegistered<InstrumentsController>()) return '';
    final inst = Get.find<InstrumentsController>();
    if (inst.favoriteInstruments.isNotEmpty) {
      return inst.favoriteInstruments.first;
    }
    if (inst.allInstruments.isNotEmpty) return inst.allInstruments.first.symbol;
    if (inst.instruments.isNotEmpty) return inst.instruments.first.symbol;
    return '';
  }

  /// Suffix-agnostic check (`XAUUSD` == `XAUUSD.c` == `XAUUSD.r`).
  static bool isInFavorites(String symbol, List<String> favorites) {
    final normalized = MarketWatchV2Service.normalizeSymbol(symbol);
    return favorites.any(
      (fav) => MarketWatchV2Service.normalizeSymbol(fav) == normalized,
    );
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      final savedSymbol = await SecureStorageService.getSelectedSymbol();
      if (savedSymbol != null && savedSymbol.isNotEmpty) {
        if (!_hasUserSelection.value) {
          _lastSymbol.value = savedSymbol;
          _hasUserSelection.value = true;
          _isRestoredSelection = true;
        }
      }
    } catch (_) {
      // Fallback to empty if storage fails
    } finally {
      _initialized = true;
    }
  }
}
