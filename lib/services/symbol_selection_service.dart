import 'package:get/get.dart';
import 'package:crm_app/services/secure_storage_service.dart';

/// Maintains the last selected trading symbol for the current app session.
/// - Defaults to XAUUSD on first use.
/// - Not persisted across app restarts.
class SymbolSelectionService extends GetxService {
  final RxString _lastSymbol = 'XAUUSD'.obs;
  final RxBool _hasUserSelection = false.obs;
  bool _initialized = false;

  String get currentSymbol => _lastSymbol.value;
  bool get hasUserSelection => _hasUserSelection.value;

  /// Update the current symbol and mark that the user made an explicit choice.
  void setSymbol(String symbol) {
    if (symbol.isEmpty) return;
    _lastSymbol.value = symbol;
    _hasUserSelection.value = true;
    // Persist asynchronously; caller doesn't need to await
    SecureStorageService.saveSelectedSymbol(symbol);
  }

  /// Ensure there is a default symbol when nothing has been set yet.
  Future<void> ensureDefault() async {
    await _ensureInitialized();
    if (_lastSymbol.value.isEmpty) {
      _lastSymbol.value = 'XAUUSD';
      SecureStorageService.saveSelectedSymbol(_lastSymbol.value);
    }
  }

  /// Reset back to default and clear the user selection flag.
  void resetToDefault() {
    _lastSymbol.value = 'XAUUSD';
    _hasUserSelection.value = false;
    SecureStorageService.saveSelectedSymbol(_lastSymbol.value);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      final savedSymbol = await SecureStorageService.getSelectedSymbol();
      if (savedSymbol != null && savedSymbol.isNotEmpty) {
        _lastSymbol.value = savedSymbol;
        _hasUserSelection.value = true;
      } else if (_lastSymbol.value.isEmpty) {
        _lastSymbol.value = 'XAUUSD';
        SecureStorageService.saveSelectedSymbol(_lastSymbol.value);
      }
    } catch (_) {
      // Fallback to default if storage fails
      if (_lastSymbol.value.isEmpty) {
        _lastSymbol.value = 'XAUUSD';
        SecureStorageService.saveSelectedSymbol(_lastSymbol.value);
      }
    } finally {
      _initialized = true;
    }
  }
}

