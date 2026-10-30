import 'package:crm_app/screens/finance/presentation/finance_ui_scope.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';
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
import 'package:crm_app/utils/camera_permission_helper.dart';

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
  Future<bool> requestCameraPermission() async {
    return await CameraPermissionHelper.checkAndRequestCameraPermission();
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
        message:
            '${TranslationUtils.tr('deposit_instruction_failed_to_fetch_crypto_address')}: ${e.toString()}',
          title: TranslationUtils.tr('general_error'),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Start camera for taking payment proof photo
  Future<void> startCamera() async {
    final hasPermission = await requestCameraPermission();
    if (!hasPermission) return;

    if (cameras == null || cameras!.isEmpty) {
      await initializeCamera();
      if (cameras == null || cameras!.isEmpty) {
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'deposit_instruction_controller_no_camera_available_on_this_device',
            ),
            title: TranslationUtils.tr('general_error'),
          );
        }
        return;
      }
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
      enableAudio: false,
    );

    try {
      await cameraController!.initialize();
      // Small delay to ensure camera is fully ready
      await Future.delayed(const Duration(milliseconds: 200));
      Get.to(() => DepositCameraScreen());
    } catch (e) {
      print('Error starting camera: $e');
      if (e is CameraException &&
          (e.code == 'cameraPermission' ||
              e.code == 'CameraAccessDenied' ||
              (e.description?.toLowerCase().contains('permission') ?? false))) {
        await CameraPermissionHelper.showPermissionSettingsDialog();
      } else if (Get.isRegistered<AppNotificationController>()) {
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
          message: TranslationUtils.tr(
            'deposit_instruction_controller_camera_is_not_ready_please_wait',
          ),
          title: TranslationUtils.tr('general_error'),
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
          message: TranslationUtils.tr(
            'deposit_instruction_controller_payment_proof_captured_successfully',
          ),
          title: TranslationUtils.tr('general_success'),
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
      final result = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (result != null && result.path != null) {
        selectedImage.value = File(result.path!);
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showSuccess(
            message: TranslationUtils.tr(
              'deposit_instruction_controller_image_selected_from_gallery',
            ),
            title: TranslationUtils.tr('general_success'),
          );
        }
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr(
            'deposit_instruction_controller_failed_to_pick_image_from_gallery',
          ),
          title: TranslationUtils.tr('general_error'),
        );
      }
    }
  }

  // Copy crypto address to clipboard
  void copyCryptoAddress() {
    // Clipboard.setData(ClipboardData(text: cryptoAddress.value));

    CustomToastService.showSuccess(
      message: TranslationUtils.tr('deposit_instruction_copied'),
    );
  }

  /// Submit deposit instruction (Bank, Crypto, Local, etc.)
  Future<void> submitDepositInstruction(
    Map<String, dynamic> requestData,
  ) async {
    if (selectedImage.value == null) {
      CustomToastService.showError(
        message: TranslationUtils.tr(
          'deposit_instruction_controller_please_upload_payment_proof_file',
        ),
      );
      return;
    }

    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();

      debugPrint(
        '[DepositInstruction] REQUEST → ${ApiConstants.depositRequest} formData=$requestData file=${selectedImage.value!.path}',
      );
      final response = await _repo.submitDepositRequestWithProof(
        endpoint: ApiConstants.depositRequest,
        file: selectedImage.value!,
        token: token ?? '',
        formData: requestData,
      );
      debugPrint(
        '[DepositInstruction] RESPONSE ← success=${response.success} message=${response.message} data=${response.data}',
      );

      if (response.success) {
        CustomToastService.showSuccess(
          message:
              response.message ??
              TranslationUtils.tr(
                'deposit_instruction_controller_deposit_request_submitted_successfully',
              ),
        );

        // Mark dashboard MT5 accounts as stale so it refreshes when user returns to dashboard
        // Don't call API here since we're navigating away from dashboard
        try {
          final dashboardController = Get.find<DashboardController>();
          dashboardController.markMT5AccountsAsStale();
        } catch (_) {}

        // Get.toNamed(
        //   AppPages.TRANSACTION_HISTORY,
        //   arguments: {'from': 'dashboard'},
        // );
        Get.to(
          () => FinanceUiScope.widgets.transactionHistory(),
          arguments: {'from': 'dashboard'},
        );
        amountController.clear();
        selectedImage.value = null;
      } else {
        // Clear image on error so user has to upload again
        selectedImage.value = null;
        CustomToastService.showError(
          message:
              response.message ??
              TranslationUtils.tr(
                'deposit_instruction_controller_deposit_submission_failed',
              ),
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
        message: TranslationUtils.tr(
          'deposit_instruction_controller_please_upload_payment_proof_file',
        ),
      );
      return;
    }

    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();

      debugPrint(
        '[DepositInstructionCrypto] REQUEST → ${ApiConstants.depositRequest} formData=$requestData file=${selectedImage.value!.path}',
      );
      final response = await _repo.submitDepositRequestWithProof(
        endpoint: ApiConstants.depositRequest,
        file: selectedImage.value!,
        token: token ?? '',
        formData: requestData,
      );
      debugPrint(
        '[DepositInstructionCrypto] RESPONSE ← success=${response.success} message=${response.message} data=${response.data}',
      );

      if (response.success) {
        CustomToastService.showSuccess(
          message:
              response.message ??
              TranslationUtils.tr(
                'deposit_instruction_controller_deposit_request_submitted_successfully',
              ),
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
          message:
              response.message ??
              TranslationUtils.tr(
                'deposit_instruction_controller_deposit_submission_failed',
              ),
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
    bool requireNetwork = true,
    String depositApi = '',
    String userInputNetAmount = '',
    String userInputCurrency = '',
  }) async {
    if (requireNetwork && selectedCregisNetwork.value.isEmpty) {
      CustomToastService.showError(
        message: TranslationUtils.tr(
          'deposit_instruction_controller_please_select_network',
        ),
      );
      return;
    }

    try {
      isAddressLoading.value = true;
      final token = await SecureStorageService.getAuthToken();
      final requestBody = {
        'gateway_method_id': gatewayMethodId,
        'amount': amount,
        'mt5_account_id': mt5AccountId,
        if (requireNetwork) 'crypto_network': selectedCregisNetwork.value,
        // Exact amount the user typed in the method currency, so the backend
        // charges it as-is instead of re-converting the USD `amount`.
        if (userInputNetAmount.isNotEmpty)
          'user_input_net_amount': userInputNetAmount,
        if (userInputCurrency.isNotEmpty)
          'user_input_currency': userInputCurrency,
      };
      final endpoint = depositApi.trim().isNotEmpty
          ? _relativeDepositEndpoint(depositApi)
          : ApiConstants.cregisDepositCreate;
      debugPrint(
        '[CregisDeposit] REQUEST → $endpoint body=$requestBody',
      );
      final response = await ApiService.post(
        endpoint: endpoint,
        token: token,
        data: requestBody,
      );
      debugPrint(
        '[CregisDeposit] RESPONSE ← success=${response.success} message=${response.message} data=${response.data}',
      );

      if (response.success && response.data != null) {
        final data = response.data['data'] ?? response.data;

        cregisReferenceNumber.value = data['reference_number']?.toString() ?? '';
        cregisChainId.value = data['chain_id']?.toString() ?? '';
        final redirectUrl = data['redirect_url']?.toString() ?? '';
        cregisCheckoutUrl.value = redirectUrl.isNotEmpty
            ? redirectUrl
            : data['checkout_url']?.toString() ?? '';
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
            message: TranslationUtils.tr(
              'deposit_instruction_controller_deposit_address_created_send_crypto_to',
            ),
          );
        } else {
          CustomToastService.showError(
            message: TranslationUtils.tr(
              'deposit_instruction_controller_no_deposit_address_or_checkout_url',
            ),
          );
        }
      } else {
        CustomToastService.showError(
          message:
              response.message ??
              TranslationUtils.tr(
                'deposit_instruction_controller_failed_to_create_deposit',
              ),
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

  /// `deposit_api` is a site path (`/api/user/deposit/cregis`) while
  /// `ApiService` prefixes `baseUrl`, which already ends in `/api/`.
  String _relativeDepositEndpoint(String depositApi) {
    var path = depositApi.trim();
    if (path.startsWith('/')) path = path.substring(1);
    if (path.startsWith('api/')) path = path.substring(4);
    return path;
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
        message: TranslationUtils.tr(
          'deposit_instruction_controller_please_generate_deposit_address_first',
        ),
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

  /// Bank details returned by a dynamic gateway that pays by bank transfer
  /// (`data.account_number` present). Null until such a response arrives.
  final dynamicBankResult = Rxn<Map<String, dynamic>>();

  /// `POST deposit/dynamic/{gatewaySlug}` — same branching as the web
  /// `DepositRequest` submit: hosted payment page, bank details, or a push
  /// prompt sent to the payer's phone.
  /// `POST deposit/unipayment` → opens the hosted `invoice_url` in the same
  /// checkout screen Cregis uses.
  Future<void> submitUniPaymentDeposit({
    required String gatewayMethodId,
    required String mt5AccountId,
    required String amount,
  }) async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();
      final requestBody = {
        'gateway_method_id': gatewayMethodId,
        'mt5_account_id': mt5AccountId,
        'amount': amount,
      };
      debugPrint(
        '[UniPaymentDeposit] REQUEST → ${ApiConstants.uniPaymentDeposit} body=$requestBody',
      );
      final response = await ApiService.post(
        endpoint: ApiConstants.uniPaymentDeposit,
        token: token,
        data: requestBody,
      );
      debugPrint(
        '[UniPaymentDeposit] RESPONSE ← success=${response.success} message=${response.message} data=${response.data}',
      );
      final body = response.data is Map ? response.data as Map : const {};
      final data = body['data'] is Map ? body['data'] as Map : const {};
      final invoiceUrl = data['invoice_url']?.toString() ?? '';
      if (!response.success || invoiceUrl.isEmpty) {
        CustomToastService.showError(
          message: response.message?.isNotEmpty == true
              ? response.message!
              : TranslationUtils.tr('deposit_unipayment_failed'),
        );
        return;
      }
      _markDashboardAccountsStale();
      Get.toNamed(
        AppPages.CREGIS_SUCCESS,
        arguments: {
          'checkoutUrl': invoiceUrl,
          'referenceNumber': data['reference_number']?.toString() ?? '',
          'amount': amount,
          'tapTimeIso': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      CustomToastService.showError(
        message: TranslationUtils.tr('deposit_unipayment_failed'),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitDynamicDeposit({
    required String gatewaySlug,
    required String gatewayMethodId,
    required String amount,
    required String mt5AccountId,
    Map<String, String> extraFields = const {},
  }) async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();
      final endpoint = ApiConstants.dynamicDeposit(gatewaySlug);
      final requestBody = {
        'gateway_method_id': gatewayMethodId,
        'mt5_account_id': mt5AccountId,
        'amount': amount,
        ...extraFields,
      };
      debugPrint('[DynamicDeposit] REQUEST → $endpoint body=$requestBody');
      final response = await ApiService.post(
        endpoint: endpoint,
        token: token,
        data: requestBody,
      );
      debugPrint(
        '[DynamicDeposit] RESPONSE ← success=${response.success} message=${response.message} data=${response.data}',
      );

      final body = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final rawData = body['data'];
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      final message = response.message ?? body['message']?.toString();

      if (!response.success) {
        CustomToastService.showError(
          message: message ?? TranslationUtils.tr('deposit_dynamic_failed'),
        );
        return;
      }

      final reference = data['reference_number']?.toString() ?? '';
      final redirectUrl = data['redirect_url']?.toString() ?? '';
      final accountNumber = data['account_number']?.toString() ?? '';

      if (accountNumber.isNotEmpty) {
        dynamicBankResult.value = data;
        _markDashboardAccountsStale();
        return;
      }

      if (redirectUrl.isNotEmpty) {
        _markDashboardAccountsStale();
        Get.toNamed(
          AppPages.CREGIS_SUCCESS,
          arguments: {
            'checkoutUrl': redirectUrl,
            'referenceNumber': reference,
            'amount': amount,
            'tapTimeIso': DateTime.now().toIso8601String(),
          },
        );
        return;
      }

      if (data['async_ack'] == true || data['async_ack'] == 1) {
        _markDashboardAccountsStale();
        CustomToastService.showSuccess(
          message: message ?? TranslationUtils.tr('deposit_dynamic_prompt_sent'),
        );
        Get.toNamed(
          AppPages.TRANSACTION_HISTORY,
          arguments: {'from': 'finance'},
        );
        return;
      }

      CustomToastService.showError(
        message: message ?? TranslationUtils.tr('deposit_dynamic_no_action'),
      );
    } catch (e) {
      CustomToastService.showError(
        message: TranslationUtils.tr('deposit_dynamic_failed'),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _markDashboardAccountsStale() {
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().markMT5AccountsAsStale();
    }
  }
}
