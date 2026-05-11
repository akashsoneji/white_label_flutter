import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Global connectivity service that monitors network status continuously.
/// Registered as a permanent GetX service so it lives for the entire app lifetime.
class ConnectivityService extends GetxService {
  // Singleton instance
  static ConnectivityService get to => Get.find<ConnectivityService>();

  // Observable connectivity result
  final Rx<ConnectivityResult> _connectivityResult = ConnectivityResult.none.obs;

  /// Current connectivity result
  ConnectivityResult get currentResult => _connectivityResult.value;

  /// Reactive stream of connectivity results
  Rx<ConnectivityResult> get connectivityResult => _connectivityResult;

  /// Whether any network connection is available
  bool get isConnected => _connectivityResult.value != ConnectivityResult.none;

  /// Stream subscription for connectivity changes
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Initialize the service and start listening
  Future<ConnectivityService> init() async {
    // Check initial connectivity state
    await _checkConnectivity();

    // Start listening to connectivity changes
    _startListening();

    return this;
  }

  /// Check current connectivity state
  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectivity(results);
  }

  /// Update the observable with new connectivity results
  void _updateConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      _connectivityResult.value = ConnectivityResult.none;
    } else {
      // Use the first available connection type
      _connectivityResult.value = results.first;
    }
  }

  /// Start listening to connectivity changes
  void _startListening() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _updateConnectivity(results);
      },
    );
  }

  /// Manually trigger a connectivity check (used by refresh button)
  Future<void> checkConnectivity() async {
    await _checkConnectivity();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    // Auto-initialize when service is created
    init();
  }
}
