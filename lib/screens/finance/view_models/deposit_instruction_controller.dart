import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'dart:io';
import 'dart:async';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/screens/trading/view_models/dashboard_controller.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/finance/presentation/pages/deposit_camera_screen.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';

class DepositInstructionController extends GetxController {
  final FinanceRepository _repo = Get.find<FinanceRepository>();
  // Observable variables

  final isLoading = false.obs;
  final amount = ''.obs;
  final cryptoAddress = 'UGIGfjdsofijofijwesef'.obs;
  var selectedImage = Rx<File?>(null);

  // Cregis-specific fields (ported from crmapp controller)
  final cregisNetworks = <String>[].obs;
  final selectedCregisNetwork = ''.obs;
  final cregisDepositAddress = ''.obs;
  final cregisQrPath = ''.obs;
  final cregisCheckoutUrl = ''.obs;
  final isAddressLoading = false.obs;
  final cregisReferenceNumber = ''.obs;
  final cregisPollingStatus = ''.obs;
  final cregisChainId = ''.obs;
  Map<String, dynamic>? cregisNetworkMap;

  // The moment the user tapped "Generate Address" / proceeded to the waiting
  // screen. The waiting screen polls Transaction History and treats any
  // transaction newer than this timestamp as a successful deposit.
  DateTime? _cregisTapTime;

  // Text editing controller
  final amountController = TextEditingController();

  // Camera controller for taking pictures
  CameraController? cameraController;
  List<CameraDescription>? cameras;

  @override
  void onInit() {
    super.onInit();
    // Initialize any data or fetch crypto address from API
    fetchCryptoAddress();
    // Initialize camera
    initializeCamera();
  }

  @override
  void onClose() {
    amountController.dispose();
    _disposeCamera();
    super.onClose();
  }

  // Dispose camera controller safely
  Future<void> _disposeCamera() async {
    if (cameraController != null) {
      try {
        final camController = cameraController;
        cameraController = null; // Clear reference first
        if (camController!.value.isInitialized) {
          await camController.dispose();
        } else {
          // If not initialized, just dispose
          await camController.dispose();
        }
      } catch (e) {
        print('Error disposing camera: $e');
        // Try to dispose anyway
        try {
          await cameraController?.dispose();
        } catch (e2) {
          print('Error in final camera disposal: $e2');
        }
        cameraController = null;
      }
    }
  }

  // Initialize available cameras
  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      print('Error initializing cameras: $e');
    }
  }

  // Request camera permission
  Future<void> requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  // Fetch crypto address from API
  Future<void> fetchCryptoAddress() async {
    try {
      isLoading.value = true;

      // Example API call
      // final response = await _apiService.getCryptoAddress();
      // cryptoAddress.value = response.address;

      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      cryptoAddress.value = 'UGIGfjdsofijofijwesef';
    } catch (e) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Failed to fetch crypto address: ${e.toString()}',
          title: 'Error',
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Start camera for taking payment proof photo
  Future<void> startCamera() async {
    await requestCameraPermission();

    if (cameras == null || cameras!.isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'No camera available on this device.',
          title: 'Error',
        );
      }
      return;
    }

    // Dispose existing controller if any
    if (cameraController != null) {
      await cameraController!.dispose();
      cameraController = null;
    }

    cameraController = CameraController(
      cameras![0],
      ResolutionPreset
          .medium, // Use medium instead of high for better memory management
    );

    try {
      await cameraController!.initialize();
      // Small delay to ensure camera is fully ready
      await Future.delayed(const Duration(milliseconds: 200));
      Get.to(() => DepositCameraScreen());
    } catch (e) {
      print('Error starting camera: $e');
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Failed to start camera: ${e.toString()}',
          title: 'Error',
        );
      }
      await cameraController?.dispose();
      cameraController = null;
      // Try to navigate back if camera failed
      if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
        Get.back(closeOverlays: true);
      }
    }
  }

  // Capture image from camera
  Future<void> captureImage() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Camera is not ready. Please wait.',
          title: 'Error',
        );
      }
      return;
    }

    try {
      isLoading.value = true;

      // Store reference before disposing
      final camController = cameraController;
      final image = await camController!.takePicture();

      selectedImage.value = File(image.path);

      // Clear reference first, then dispose
      cameraController = null;
      update(); // Notify GetBuilder to rebuild

      // Dispose after a small delay to ensure UI has updated
      await Future.delayed(const Duration(milliseconds: 100));
      await camController.dispose();

      Get.back(closeOverlays: true);

      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showSuccess(
          message: 'Payment proof captured successfully!',
          title: 'Success',
        );
      }
    } catch (e) {
      print('Error capturing image: $e');
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Failed to capture image: ${e.toString()}',
          title: 'Error',
        );
      }

      // Clean up on error
      try {
        final camController = cameraController;
        cameraController = null;
        update();
        await camController?.dispose();
      } catch (disposeError) {
        print('Error disposing camera: $disposeError');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Pick image from gallery using file_picker
  Future<void> pickImageFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.single.path != null) {
        selectedImage.value = File(result.files.single.path!);
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showSuccess(
            message: 'Image selected from gallery',
            title: 'Success',
          );
        }
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Failed to pick image from gallery. Please try again.',
          title: 'Error',
        );
      }
    }
  }

  // Copy crypto address to clipboard
  void copyCryptoAddress() {
    // Clipboard.setData(ClipboardData(text: cryptoAddress.value));

    CustomToastService.showSuccess(message: 'Copied');
  }

  /// Submit deposit instruction (Bank, Crypto, Local, etc.)
  Future<void> submitDepositInstruction(
    Map<String, dynamic> requestData,
  ) async {
    if (selectedImage.value == null) {
      CustomToastService.showError(
        message: 'Please upload a payment proof file',
      );
      return;
    }

    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();

      final response = await _repo.submitDepositRequestWithProof(
        endpoint: ApiConstants.depositRequest,
        file: selectedImage.value!,
        token: token ?? '',
        formData: requestData,
      );

      if (response.success) {
        CustomToastService.showSuccess(
          message: response.message ?? 'Deposit request submitted successfully',
        );

        // Mark dashboard MT5 accounts as stale so it refreshes when user returns to dashboard
        // Don't call API here since we're navigating away from dashboard
        try {
          final dashboardController = Get.find<DashboardController>();
          dashboardController.markMT5AccountsAsStale();
        } catch (_) {}

        Get.toNamed(
          AppPages.TRANSACTION_HISTORY,
          arguments: {'from': 'dashboard'},
        );

        amountController.clear();
        selectedImage.value = null;
      } else {
        // Clear image on error so user has to upload again
        selectedImage.value = null;
        CustomToastService.showError(
          message: response.message ?? 'Deposit submission failed',
        );
      }
    } catch (e, t) {
      print("object   imsgr error $t");
      print("object   imsgr error $e");
      // Clear image on error so user has to upload again
      selectedImage.value = null;
      CustomToastService.showError(
        message: 'Error while submitting deposit: $e',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Submit deposit instruction (Bank, Crypto, Local, etc.)
  Future<void> submitDepositInstructionForCrypto(
    Map<String, dynamic> requestData,
  ) async {
    if (selectedImage.value == null) {
      CustomToastService.showError(
        message: 'Please upload a payment proof file',
      );
      return;
    }

    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();

      final response = await _repo.submitDepositRequestWithProof(
        endpoint: ApiConstants.depositRequest,
        file: selectedImage.value!,
        token: token ?? '',
        formData: requestData,
      );

      if (response.success) {
        CustomToastService.showSuccess(
          message: response.message ?? 'Deposit request submitted successfully',
        );

        // Mark dashboard MT5 accounts as stale so it refreshes when user returns to dashboard
        // Don't call API here since we're navigating away from dashboard
        try {
          final dashboardController = Get.find<DashboardController>();
          dashboardController.markMT5AccountsAsStale();
        } catch (_) {}

        Get.toNamed(
          AppPages.TRANSACTION_HISTORY,
          arguments: {'from': 'finance'},
        );

        amountController.clear();
        selectedImage.value = null;
      } else {
        // Clear image on error so user has to upload again
        selectedImage.value = null;
        CustomToastService.showError(
          message: response.message ?? 'Deposit submission failed',
        );
      }
    } catch (e, t) {
      print("object   imsgr error $t");
      print("object   imsgr error $e");
      // Clear image on error so user has to upload again
      selectedImage.value = null;
      CustomToastService.showError(
        message: 'Error while submitting deposit: $e',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Create a Cregis deposit address for the selected network
  Future<void> createCregisDepositAddress({
    required String gatewayMethodId,
    required String amount,
    required String mt5AccountId,
  }) async {
    if (selectedCregisNetwork.value.isEmpty) {
      CustomToastService.showError(message: 'Please select a network');
      return;
    }

    try {
      isAddressLoading.value = true;
      final token = await SecureStorageService.getAuthToken();

      final response = await ApiService.post(
        endpoint: ApiConstants.cregisDepositCreate,
        token: token,
        data: {
          'gateway_method_id': gatewayMethodId,
          'amount': amount,
          'mt5_account_id': mt5AccountId,
          'crypto_network': selectedCregisNetwork.value,
        },
      );

      if (response.success && response.data != null) {
        final data = response.data['data'] ?? response.data;

        cregisReferenceNumber.value = data['reference_number']?.toString() ?? '';
        cregisChainId.value = data['chain_id']?.toString() ?? '';
        cregisCheckoutUrl.value = data['checkout_url']?.toString() ?? '';
        cregisDepositAddress.value = data['cregis_address']?.toString() ?? '';
        cregisQrPath.value = data['qr_path']?.toString() ?? '';

        if (cregisCheckoutUrl.value.isNotEmpty) {
          _cregisTapTime = DateTime.now();
          Get.toNamed(
            AppPages.CREGIS_SUCCESS,
            arguments: {
              'checkoutUrl': cregisCheckoutUrl.value,
              'referenceNumber': cregisReferenceNumber.value,
              'amount': amount,
              'tapTimeIso': _cregisTapTime!.toIso8601String(),
            },
          );
        } else if (cregisDepositAddress.value.isNotEmpty) {
          CustomToastService.showSuccess(
            message:
                'Deposit address created. Send crypto to the address shown.',
          );
        } else {
          CustomToastService.showError(
            message: 'No deposit address or checkout URL returned',
          );
        }
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to create deposit',
        );
      }
    } catch (e) {
      CustomToastService.showError(
        message: 'Error creating deposit address: $e',
      );
    } finally {
      isAddressLoading.value = false;
    }
  }

  Future<void> submitCregisDeposit({
    required String gatewayMethodId,
    required String amount,
    required String mt5AccountId,
  }) async {
    if (cregisCheckoutUrl.value.isNotEmpty) {
      _cregisTapTime = DateTime.now();
      Get.toNamed(
        AppPages.CREGIS_SUCCESS,
        arguments: {
          'checkoutUrl': cregisCheckoutUrl.value,
          'referenceNumber': cregisReferenceNumber.value,
          'amount': amount,
          'tapTimeIso': _cregisTapTime!.toIso8601String(),
        },
      );
      return;
    }

    if (cregisDepositAddress.value.isEmpty) {
      CustomToastService.showError(
        message: 'Please generate a deposit address first',
      );
      return;
    }

    _cregisTapTime = DateTime.now();
    Get.toNamed(
      AppPages.CREGIS_ADDRESS,
      arguments: {
        'cregisAddress': cregisDepositAddress.value,
        'referenceNumber': cregisReferenceNumber.value,
        'amount': amount,
        'networkKey': selectedCregisNetwork.value,
        'tapTimeIso': _cregisTapTime!.toIso8601String(),
      },
    );
  }

}
