import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

class LoadingService extends GetxService {
  static LoadingService get to => Get.find();

  final RxBool _isLoading = false.obs;
  final RxString _loadingMessage = ''.obs;

  bool get isLoading => _isLoading.value;
  String get loadingMessage => _loadingMessage.value;

  // Show loading overlay with custom message
  void showLoading({String message = 'Loading...', Color? color}) {
    _loadingMessage.value = message;
    _isLoading.value = true;

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false, // Prevent closing with back button
        child: OverlayLoadingWidget(message: message, size: 60.0, color: color),
      ),
      barrierDismissible: false,
    );
  }

  // Show loading overlay without message
  void showLoadingWithoutMessage({Color? color}) {
    _isLoading.value = true;

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: OverlayLoadingWidget(size: 60.0, color: color),
      ),
      barrierDismissible: false,
    );
  }

  // Hide loading overlay
  void hideLoading() {
    _isLoading.value = false;
    _loadingMessage.value = '';

    if (Get.isDialogOpen ?? false) {
      Get.back(closeOverlays: true);
    }
  }

  // Show loading in a specific context (like a button)
  Widget buildButtonLoading({double size = 20.0, Color? color}) {
    return ButtonLoadingWidget(size: size, color: color);
  }

  // Show loading in center of screen
  Widget buildCenterLoading({
    double size = 50.0,
    Color? color,
    String? message,
  }) {
    return CommonLoadingWidget(size: size, color: color, message: message);
  }

  // Show loading with custom animation
  Widget buildCustomLoading({
    required String animationType,
    double size = 50.0,
    Color? color,
    String? message,
  }) {
    return CommonLoadingWidget(size: size, color: color, message: message);
  }
}

// Extension for easy access to loading service
extension LoadingServiceExtension on GetInterface {
  LoadingService get loading => LoadingService.to;
}
