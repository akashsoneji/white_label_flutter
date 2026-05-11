import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/connectivity/connectivity_service.dart';

/// Controller for managing no-internet overlay visibility.
/// Works with ConnectivityService to show/hide the no-internet screen.
class ConnectivityController extends GetxController {
  // Reference to the connectivity service
  late final ConnectivityService _connectivityService;

  /// Whether the device has internet connectivity (reactive)
  final RxBool isConnected = true.obs;

  /// Current connectivity result from service
  ConnectivityResult get currentResult => _connectivityService.currentResult;

  /// Whether the device is on WiFi
  bool get isOnWifi => _connectivityService.currentResult == ConnectivityResult.wifi;

  /// Whether the device is on mobile data
  bool get isOnMobile =>
      _connectivityService.currentResult == ConnectivityResult.mobile;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _connectivityService = Get.find<ConnectivityService>();

    // Sync initial state
    isConnected.value = _connectivityService.isConnected;

    // Listen to service changes and keep isConnected in sync
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      isConnected.value = results.isNotEmpty &&
          !results.contains(ConnectivityResult.none);
    });
  }

  /// Manually refresh connectivity check (called by refresh button)
  Future<void> refresh() async {
    await _connectivityService.checkConnectivity();
    isConnected.value = _connectivityService.isConnected;
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
