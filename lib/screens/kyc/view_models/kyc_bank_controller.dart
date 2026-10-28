import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/models/bank_withdralList_model.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/models/currency_list_model.dart';
import 'package:crm_app/screens/kyc/presentation/pages/kyc_bank_camera_screen.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/screens/kyc/data/repositories/kyc_repository.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/api_service.dart';
import 'package:crm_app/utils/file_compression_helper.dart';
import 'package:crm_app/utils/camera_permission_helper.dart';

class KycBankController extends GetxController {
  final KycRepository _repo = Get.find<KycRepository>();
  // Observable variables
  final RxBool isLoading = false.obs;
  final RxBool isOtpLoading = false.obs;
  final RxBool hasLoadedOnce = false.obs;
  final RxSet<int> deletingIds = <int>{}.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;

  // Account type selection
  final RxString selectedAccountType = 'Crypto'.obs;
  final RxString selectedRelationship = 'Self'.obs;
  final RxList<String> accountTypes = ['Bank', 'Crypto', 'UPI'].obs;
  final RxList<String> relationShips =
      ['Self','Other'].obs;
  final RxList<String> ifscIbanList = ['IFSC', 'IBAN'].obs;

  // Currency list
  final RxList<String> currencies = <String>[].obs;
  final RxList<WithdrawalMethods> bankWithdrawalList =
      <WithdrawalMethods>[].obs;
  final RxList<AllowedCryptoNetwork> allowedCryptoNetworks =
      <AllowedCryptoNetwork>[].obs;
  // Per-method proof-image requirement from the API, e.g.
  // {bank: true, crypto: false, local: true, upi: true}.
  final RxMap<String, bool> requireProofImageByMethod = <String, bool>{}.obs;
  // final RxString selectedCurrency = 'USD'.obs;
  final RxString selectedIfscIban = 'IFSCs'.obs;
  final RxString selectedCryptoNetwork = ''.obs;

  // Form fields
  final RxString ifscIbanType = ''.obs;
  final RxString bankName = ''.obs;
  final RxString accountHolderName = ''.obs;
  final RxString bankAccountNumber = ''.obs;
  final RxString confirmBankAccountNumber = ''.obs;
  final RxString bankSwiftCode = ''.obs;
  final RxString cryptoAddress = ''.obs;
  final RxString upiAddress = ''.obs;
  final RxString optRadio = 'IFSC'.obs; // For IFSC/IBAN selection
  final RxString ifscIbanCode = ''.obs; // For IFSC/IBAN selection

  // OTP
  final RxString otp = ''.obs;
  final RxBool isOtpSent = false.obs;

  // OTP Countdown Timer
  final RxInt otpCountdownSeconds = 0.obs;
  final RxBool isOtpCountdownActive = false.obs;
  Timer? _otpCountdownTimer;

  // App lifecycle handling
  late AppLifecycleListener _appLifecycleListener;
  DateTime? _backgroundTime;

  // File upload
  final Rx<File?> proofFile = Rx<File?>(null);
  var isBankList = false.obs;

  // Camera controller for taking pictures
  CameraController? cameraController;
  List<CameraDescription>? cameras;

  // Navigation callback
  Function()? onNavigationCallback;

  @override
  void onInit() {
    super.onInit();

    fetchCurrencyList();
    fetchWithdrawalList();
    // Initialize camera
    initializeCamera();

    // Initialize app lifecycle listener
    _appLifecycleListener = AppLifecycleListener(
      onDetach: () {
        print('📱 App detached - stopping timer');
        _otpCountdownTimer?.cancel();
        _otpCountdownTimer = null;
      },
      onHide: () {
        print('📱 App hidden - pausing timer');
        _backgroundTime = DateTime.now();
        _otpCountdownTimer?.cancel();
        _otpCountdownTimer = null;
      },
      onShow: () {
        print('📱 App shown - resuming timer');
        if (_backgroundTime != null && isOtpCountdownActive.value) {
          final backgroundDuration = DateTime.now().difference(
            _backgroundTime!,
          );
          final remainingSeconds =
              otpCountdownSeconds.value - backgroundDuration.inSeconds;

          if (remainingSeconds > 0) {
            otpCountdownSeconds.value = remainingSeconds;
            _startOtpCountdown();
          } else {
            isOtpCountdownActive.value = false;
            otpCountdownSeconds.value = 0;
          }
        }
        _backgroundTime = null;
      },
    );
  }

  // Fetch currency list
  Future<void> fetchCurrencyList() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.getCurrencyList(token: token ?? '');

      if (response.success) {
        print('✅ Currency list fetched successfully');
        final currencyListModel = CurrencyListModel.fromJson(response.data);
        currencies.value = currencyListModel.data?.currencies ?? [];
        print('💰 Found ${currencies.length} currencies');
      } else {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr(
              'kyc_bank_controller_failed_to_fetch_currency_list',
            );
        print('❌ Failed to fetch currency list: ${response.message}');
      }
    } catch (e) {
      errorMessage.value = 'Error fetching currency list: $e';
      print('❌ Error fetching currency list: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchWithdrawalList() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.getBankWithdrawalList(token: token ?? '');

      if (response.success) {
        print('✅ Withdrawal list fetched successfully');
        final currencyListModel = BankWithdrawleList.fromJson(response.data);
        bankWithdrawalList.value =
            currencyListModel.data?.withdrawalMethods ?? [];
        allowedCryptoNetworks.value =
            currencyListModel.data?.allowedCryptoNetworks ?? [];
        requireProofImageByMethod.value =
            currencyListModel.data?.requireProofImageByMethod ?? {};
        _applyAccountTypesFromApi();
        print('💰 Found ${bankWithdrawalList.length} withdrawal methods');
        print('🔌 Found ${allowedCryptoNetworks.length} crypto networks');
      } else {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr(
              'kyc_bank_controller_failed_to_fetch_withdrawal_list',
            );
        print('❌ Failed to fetch withdrawal list: ${response.message}');
      }
    } catch (e) {
      errorMessage.value = 'Error fetching withdrawal list: $e';
      print('❌ Error fetching withdrawal list: $e');
    } finally {
      isLoading.value = false;
      hasLoadedOnce.value = true; // Mark first load complete
    }
  }

  /// `DELETE withdrawal/delete/{id}`; drops the row locally on success.
  Future<bool> deleteWithdrawalMethod(int id) async {
    if (deletingIds.contains(id)) return false;
    deletingIds.add(id);
    try {
      final response = await ApiService.delete(
        endpoint: ApiConstants.withdrawalMethodDelete(id),
      );
      final serverMessage =
          response.message?.isNotEmpty == true ? response.message! : null;
      if (response.success) {
        bankWithdrawalList.removeWhere((m) => m.id == id);
        _notify(
          success: true,
          message: serverMessage ?? TranslationUtils.tr('bank_list_delete_success'),
        );
        return true;
      }
      _notify(
        success: false,
        message: serverMessage ?? TranslationUtils.tr('bank_list_delete_failed'),
      );
      return false;
    } catch (_) {
      _notify(
        success: false,
        message: TranslationUtils.tr('bank_list_delete_failed'),
      );
      return false;
    } finally {
      deletingIds.remove(id);
    }
  }

  final RxBool isVerifyingIfsc = false.obs;

  /// Branch line shown under the code field once `utility/ifsc-code` resolves
  /// the IFSC; cleared whenever the code is edited.
  final RxString ifscBranchInfo = ''.obs;

  /// `POST utility/ifsc-code`. Returns the bank name on success so the form
  /// can fill its bank-name field.
  Future<String?> verifyIfscCode() async {
    final code = ifscIbanCode.value.trim().toUpperCase();
    if (code.isEmpty || isVerifyingIfsc.value) return null;
    isVerifyingIfsc.value = true;
    ifscBranchInfo.value = '';
    try {
      final response = await ApiService.post(
        endpoint: ApiConstants.utilityIfscCode,
        data: {'ifscCode': code},
      );
      final body = response.data;
      final outer = body is Map ? body['data'] : null;
      final details = outer is Map ? outer['data'] : null;
      if (!response.success || details is! Map) {
        _notify(
          success: false,
          message: response.message?.isNotEmpty == true
              ? response.message!
              : TranslationUtils.tr('kyc_bank_ifsc_invalid'),
        );
        return null;
      }
      final bank = details['BANK']?.toString() ?? '';
      ifscBranchInfo.value = [
        details['BRANCH'],
        details['CITY'],
      ].where((v) => v != null && '$v'.isNotEmpty).join(', ');
      if (bank.isNotEmpty) bankName.value = bank;
      return bank.isEmpty ? null : bank;
    } catch (_) {
      _notify(
        success: false,
        message: TranslationUtils.tr('kyc_bank_ifsc_invalid'),
      );
      return null;
    } finally {
      isVerifyingIfsc.value = false;
    }
  }

  void _notify({required bool success, required String message}) {
    if (!Get.isRegistered<AppNotificationController>()) return;
    final notifier = Get.find<AppNotificationController>();
    success
        ? notifier.showSuccess(message: message)
        : notifier.showError(message: message);
  }

  /// Build the account-type dropdown dynamically from the API response
  /// (keys of require_proof_image_by_method, e.g. bank/crypto/local/upi) so
  /// it stays in sync when the broker enables/disables methods server-side.
  void _applyAccountTypesFromApi() {
    final keys = requireProofImageByMethod.keys.toList();
    if (keys.isEmpty) return;
    final types = keys
        .map((k) => k.isEmpty ? k : '${k[0].toUpperCase()}${k.substring(1)}')
        .toList();
    accountTypes.value = types;
    // Keep the current selection valid; otherwise fall back to the first type.
    final currentLower = selectedAccountType.value.toLowerCase();
    if (!keys.contains(currentLower)) {
      selectedAccountType.value = types.first;
    }
  }

  /// Whether the currently selected account type needs a proof image,
  /// driven by the API's require_proof_image_by_method map. Defaults to true
  /// when the method isn't listed (safer to require than to silently skip).
  bool get isProofRequired {
    final key = selectedAccountType.value.toLowerCase();
    return requireProofImageByMethod[key] ?? true;
  }

  // Set account type
  void setAccountType(String accountType) {
    selectedAccountType.value = accountType;
    clearFormFields();
    // Reset OTP state when changing account type
    isOtpSent.value = false;
    otp.value = '';
    // _applyAccountTypeDefaults();
  }

  // void _applyAccountTypeDefaults() {
  //   ifscIbanType.value = selectedAccountType.value.toLowerCase();
  //   if (selectedAccountType.value.toLowerCase() == 'crypto') {
  //     selectedCurrency.value = 'USDT';
  //     _applyDefaultCryptoNetwork();
  //   } else if (selectedCurrency.value == 'USDT') {
  //     selectedCurrency.value = 'USD';
  //   }
  // }

  void _applyDefaultCryptoNetwork() {
    if (allowedCryptoNetworks.isNotEmpty) {
      selectedCryptoNetwork.value = allowedCryptoNetworks.first.slug ?? '';
    } else {
      selectedCryptoNetwork.value = '';
    }
  }

  void setCryptoNetwork(String slug) {
    selectedCryptoNetwork.value = slug;
  }

  void setRelationShip(String relation) {
    selectedRelationship.value = relation;
    clearFormFields();
  }

  // Clear form fields
  void clearFormFields() {
    ifscIbanCode.value = '';
    bankName.value = '';
    accountHolderName.value = '';
    bankAccountNumber.value = '';
    confirmBankAccountNumber.value = '';
    bankSwiftCode.value = '';
    cryptoAddress.value = '';
    upiAddress.value = '';
    selectedCryptoNetwork.value = '';
    otp.value = '';
    isOtpSent.value = false;
    proofFile.value = null;
    accountHolderName.value = "";
  }

  // Send OTP
  Future<void> sendOtp() async {
    try {
      isOtpLoading.value = true;
      errorMessage.value = '';

      // Validate required fields based on account type
      if (!_validateRequiredFields()) {
        return;
      }

      final token = await SecureStorageService.getAuthToken();
      final response = await _repo.sendOtp(token: token ?? '');

      if (response.success) {
        print('✅ OTP sent successfully');
        isOtpSent.value = true;
        // Use API response message instead of static text
        successMessage.value =
            response.message ??
            TranslationUtils.tr('wallet_controller_otp_sent_successfully');

        // Start countdown timer (60 seconds = 1 minute)
        _startOtpCountdown();

        // Use AppNotificationController for consistent notifications
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showSuccess(
            message:
                response.message ??
                TranslationUtils.tr('wallet_controller_otp_sent_successfully'),
          );
        }
      } else {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr('auth_controller_failed_to_send_otp');
        print('❌ Failed to send OTP: ${response.message}');
        // Use AppNotificationController for consistent notifications
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message:
                response.message ??
                TranslationUtils.tr('auth_controller_failed_to_send_otp'),
          );
        }
      }
    } catch (e) {
      errorMessage.value = 'Error sending OTP: $e';
      print('❌ Error sending OTP: $e');
      // Use AppNotificationController for consistent notifications
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
        message:
            '${TranslationUtils.tr('kyc_bank_controller_error_sending_otp')}: $e',
        );
      }
    } finally {
      isOtpLoading.value = false;
    }
  }

  // Submit withdrawal
  Future<void> submitWithdrawal() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Validate OTP
      if (otp.value.isEmpty) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_controller_please_enter_otp',
        );
        // Use AppNotificationController for consistent notifications
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_controller_please_enter_otp',
            ),
          );
        }
        return;
      }

      final token = await SecureStorageService.getAuthToken();

      // Use multipart upload for file submission
      ApiResponse response;
      if (proofFile.value != null) {
        response = await _uploadWithdrawalWithFile(token!);
      } else {
        // Fallback to regular POST if no file
        response = await _repo.submitWithdrawalRequest(
          token: token ?? '',
          payload: _buildWithdrawalRequestParams(),
        );
      }

      if (response.success) {
        print('✅ Withdrawal submitted successfully');
        // Use API response message instead of static text
        successMessage.value =
            response.message ??
            TranslationUtils.tr(
              'kyc_bank_controller_withdrawal_request_submitted_successfully',
            );
        // Use AppNotificationController for consistent notifications
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showSuccess(
            message:
                response.message ??
                TranslationUtils.tr(
                  'kyc_bank_controller_withdrawal_request_submitted_successfully',
                ),
          );
        }
        // Reset form
        clearFormFields();
        selectedAccountType.value = 'Bank';
        ifscIbanType.value = 'bank';
        // selectedCurrency.value = 'USD';

        print('isBankList: ${isBankList.value}');
        if (isBankList.value) {
          // Add a small delay to ensure the success message is shown
          Future.delayed(Duration(milliseconds: 500), () {
            _safeNavigateToBankList();
          });
        } else {
          Get.toNamed(AppPages.KYC_SUCCESS);
        }

        // Navigate to Bank List screen on success
      } else {
        errorMessage.value =
            response.message ??
            TranslationUtils.tr(
              'kyc_bank_controller_failed_to_submit_withdrawal',
            );
        print('❌ Failed to submit withdrawal: ${response.message}');
        // Use AppNotificationController for consistent notifications
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message:
                response.message ??
                TranslationUtils.tr(
                  'kyc_bank_controller_failed_to_submit_withdrawal',
                ),
          );
        }
      }
    } catch (e) {
      errorMessage.value = 'Error submitting withdrawal: $e';
      print('❌ Error submitting withdrawal: $e');
      // Use AppNotificationController for consistent notifications
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Error submitting withdrawal: $e',
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Validate required fields - Dynamic validation based on account type
  bool _validateRequiredFields() {
    // Common validation
    if (selectedAccountType.value.isEmpty) {
      errorMessage.value = TranslationUtils.tr(
        'account_management_validation_type',
      );
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr('account_management_validation_type'),
        );
      }
      return false;
    }

    if (accountHolderName.value.isEmpty) {
      errorMessage.value = TranslationUtils.tr(
        'kyc_bank_controller_please_enter_account_holder_name',
      );
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr(
            'kyc_bank_controller_please_enter_account_holder_name',
          ),
        );
      }
      return false;
    }

    // Dynamic validation based on account type
    if (selectedAccountType.value.toLowerCase() == "bank") {
      if (ifscIbanCode.value.isEmpty) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_controller_please_enter_ifsc_iban_code',
        );
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_controller_please_enter_ifsc_iban_code',
            ),
          );
        }
        return false;
      }
      if (bankName.value.isEmpty) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_controller_please_enter_bank_name',
        );
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_controller_please_enter_bank_name',
            ),
          );
        }
        return false;
      }
      if (bankAccountNumber.value.isEmpty) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_controller_please_enter_bank_account_number',
        );
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_controller_please_enter_bank_account_number',
            ),
          );
        }
        return false;
      }
      if (confirmBankAccountNumber.value.isEmpty) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_controller_please_confirm_bank_account_number',
        );
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_controller_please_confirm_bank_account_number',
            ),
          );
        }
        return false;
      }
      if (bankAccountNumber.value != confirmBankAccountNumber.value) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_screen_bank_account_numbers_do_not_match',
        );
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_screen_bank_account_numbers_do_not_match',
            ),
          );
        }
        return false;
      }
    } else if (selectedAccountType.value.toLowerCase() == "crypto") {
      if (selectedCryptoNetwork.value.isEmpty) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_controller_please_select_network',
        );
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_controller_please_select_network',
            ),
          );
        }
        return false;
      }
      if (cryptoAddress.value.isEmpty) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_controller_please_enter_crypto_address',
        );
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_controller_please_enter_crypto_address',
            ),
          );
        }
        return false;
      }
      if (accountHolderName.value.isNotEmpty &&
          !_isValidCryptoHolderName(accountHolderName.value)) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_controller_crypto_holder_name_can_only_contain',
        );
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_controller_crypto_holder_name_can_only_contain',
            ),
          );
        }
        return false;
      }
    } else {
      // UPI case
      if (upiAddress.value.isEmpty) {
        errorMessage.value = TranslationUtils.tr(
          'kyc_bank_controller_please_enter_upi_address',
        );
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr(
              'kyc_bank_controller_please_enter_upi_address',
            ),
          );
        }
        return false;
      }
    }

    // Proof validation — only required when the API says so for this method.
    if (isProofRequired && proofFile.value == null) {
      errorMessage.value = TranslationUtils.tr(
        'kyc_bank_controller_please_upload_proof_image',
      );
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr(
            'kyc_bank_controller_please_upload_proof_image',
          ),
        );
      }
      return false;
    }

    return true;
  }

  bool _isValidCryptoHolderName(String value) {
    return RegExp(r"^[a-zA-Z\s\-'.]+$").hasMatch(value.trim());
  }

  // Build OTP request parameters - Dynamic based on account type
  Map<String, dynamic> _buildOtpRequestParams() {
    final params = <String, dynamic>{};

    // Add conditional parameters based on account type
    if (selectedAccountType.value.toLowerCase() == "bank") {
      params.addAll({
        "ifsc_iban": ifscIbanCode.value,
        "bank_name": bankName.value,
        "bank_holder_name": accountHolderName.value,
        "bank_account_no": bankAccountNumber.value,
        "confirm_bank_account_no": confirmBankAccountNumber.value,
        "swift_code": bankSwiftCode.value,
        "optradio": ifscIbanType.value,
      });
    } else if (selectedAccountType.value.toLowerCase() == "crypto") {
      params.addAll({
        "crypto_holder_name": accountHolderName.value,
        "crypto_address": cryptoAddress.value,
        "crypto_network": selectedCryptoNetwork.value,
      });
    } else {
      // UPI case
      params.addAll({
        "upi_holder_name": accountHolderName.value,
        "upi_address": upiAddress.value,
      });
    }

    // Add common parameters
    params.addAll({
      "withdrawal_method": selectedAccountType.value.toLowerCase(),
      // "currency": selectedCurrency.value,
      "belogns_to": "",
      "relationship": selectedRelationship.value.toLowerCase(),
      "holder_name": accountHolderName.value,
    });

    return params;
  }

  // Build withdrawal request parameters
  Map<String, dynamic> _buildWithdrawalRequestParams() {
    final params = _buildOtpRequestParams();
    params.addAll({'otp': otp.value});

    // Add proof image with method-specific field name
    String proofFieldName = _getProofFieldName();
    if (proofFile.value != null) {
      params[proofFieldName] = proofFile.value!.path;
    }

    return params;
  }

  // Get the correct proof field name based on withdrawal method
  String _getProofFieldName() {
    switch (selectedAccountType.value.toLowerCase()) {
      case 'bank':
        return 'bank_proof_img';
      case 'upi':
        return 'upi_proof_img';
      case 'crypto':
        return 'crypto_proof_img';
      default:
        return 'deposit_proof';
    }
  }

  // Upload withdrawal request with file using multipart
  Future<ApiResponse> _uploadWithdrawalWithFile(String token) async {
    try {
      final params = _buildWithdrawalRequestParams();
      final proofFieldName = _getProofFieldName();

      // Remove the proof file path from params as it will be handled by multipart
      params.remove(proofFieldName);

      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.withdrawalRequest}',
      );
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll(headers);

      // Add form data
      params.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Add file with the correct field name
      request.files.add(
        await http.MultipartFile.fromPath(
          proofFieldName,
          proofFile.value!.path,
        ),
      );

      print('📤 Uploading withdrawal with file:');
      print('   Field name: $proofFieldName');
      print('   File path: ${proofFile.value!.path}');
      print('   Form data: $params');

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Withdrawal upload response:');
      print('   Status: ${response.statusCode}');
      print('   Body: ${response.body}');

      final responseData = json.decode(response.body);

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: responseData['message'] ?? 'Upload completed',
        data: responseData,
      );
    } catch (e) {
      print('❌ Error uploading withdrawal with file: $e');
      return ApiResponse(
        success: false,
        message: 'Upload failed: $e',
        data: null,
      );
    }
  }

  // Set currency
  // void setCurrency(String currency) {
  //   selectedCurrency.value = currency;
  // }

  // Set IFSC/IBAN code
  void setIfscIbanCode(String ifscIbanCode) {
    this.selectedIfscIban.value = ifscIbanCode;
  }

  // Set IFSC/IBAN radio selection
  void setOptRadio(String value) {
    optRadio.value = value;
  }

  // Set proof file
  void setProofFile(File? file) {
    proofFile.value = file;
  }

  void setIsBankList(bool value) {
    isBankList.value = value;
  }

  void setNavigationCallback(Function()? callback) {
    onNavigationCallback = callback;
  }

  // Clear all data
  void clearAllData() {
    clearFormFields();
    selectedAccountType.value = 'Bank';
    ifscIbanType.value = 'bank';
    // selectedCurrency.value = 'USD';
    currencies.clear();
    allowedCryptoNetworks.clear();
    errorMessage.value = '';
    successMessage.value = '';

    // Clear timer and reset countdown
    _otpCountdownTimer?.cancel();
    _otpCountdownTimer = null;
    isOtpCountdownActive.value = false;
    otpCountdownSeconds.value = 0;
  }

  // OTP Countdown Timer Methods
  void _startOtpCountdown() {
    // Cancel any existing timer
    _otpCountdownTimer?.cancel();

    otpCountdownSeconds.value = 60; // 1 minute = 60 seconds
    isOtpCountdownActive.value = true;

    // Start countdown timer using Timer.periodic
    _otpCountdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      try {
        if (otpCountdownSeconds.value > 0) {
          otpCountdownSeconds.value--;
        } else {
          // Countdown finished
          timer.cancel();
          isOtpCountdownActive.value = false;
          _otpCountdownTimer = null;
          print('⏰ OTP countdown finished - Resend button enabled');
        }
      } catch (e) {
        print('❌ Error in countdown timer: $e');
        timer.cancel();
        _otpCountdownTimer = null;
        isOtpCountdownActive.value = false;
      }
    });
  }

  // Format countdown time as MM:SS
  String getFormattedCountdown() {
    try {
      final minutes = otpCountdownSeconds.value ~/ 60;
      final seconds = otpCountdownSeconds.value % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      print('❌ Error formatting countdown: $e');
      return '00:00';
    }
  }

  // Check if resend button should be enabled
  bool get canResendOtp {
    try {
      return !isOtpCountdownActive.value && !isOtpLoading.value;
    } catch (e) {
      print('❌ Error checking canResendOtp: $e');
      return false;
    }
  }

  /// Safely navigate to bank list screen without snackbar conflicts
  void _safeNavigateToBankList() {
    try {
      // Close any active snackbars first
      try {
        Get.closeCurrentSnackbar();
      } catch (e) {
        print('⚠️ Could not close snackbar: $e');
      }

      // Small delay to ensure snackbar is closed
      Future.delayed(Duration(milliseconds: 100), () {
        try {
          print('🔄 Popping until bank list screen');
          // Try to pop until we reach the existing bank list screen
          // Get.until() will pop routes until the condition is true
          // If bank list is in stack, it will stop there
          // If not found, it will pop all routes and we'll handle it
          try {
            Get.until((route) {
              final routeName = route.settings.name;
              return routeName == AppPages.BANK_LIST;
            });

            // If we reach here, we either found bank list or popped everything
            // Check if current route is now bank list
            Future.delayed(Duration(milliseconds: 100), () {
              if (Get.currentRoute == AppPages.BANK_LIST) {
                print('✅ Found existing bank list screen, popped to it');
                // Refresh the list after popping to existing screen
                Future.delayed(Duration(milliseconds: 200), () {
                  fetchWithdrawalList();
                });
              } else {
                // Bank list not in stack, navigate to it
                print('⚠️ Bank list not in stack, navigating to it');
                Get.offNamed(AppPages.BANK_LIST);
              }
            });
          } catch (untilError) {
            // Get.until() might throw if no routes match, navigate to bank list
            print('⚠️ Could not pop to bank list: $untilError');
            Get.offNamed(AppPages.BANK_LIST);
          }
        } catch (e) {
          print('❌ Error navigating to bank list: $e');
          // Fallback: use offNamed
          try {
            Get.offNamed(AppPages.BANK_LIST);
          } catch (fallbackError) {
            print('❌ Fallback navigation also failed: $fallbackError');
          }
        }
      });
    } catch (e, t) {
      print('❌ Error in safe navigation: $e');
      print('❌ Stack trace: $t');
    }
  }

  // Initialize camera
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

  // Start camera for taking proof photo
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
          );
        }
        return;
      }
    }

    // Dispose existing controller if any and wait for cleanup
    await _disposeCamera();
    await Future.delayed(const Duration(milliseconds: 300)); // Wait for cleanup

    try {
      cameraController = CameraController(
        cameras![0],
        ResolutionPreset
            .medium, // Use medium instead of high for better memory management
        enableAudio: false,
      );

      await cameraController!.initialize();
      // Small delay to ensure camera is fully ready
      await Future.delayed(const Duration(milliseconds: 300));

      // Double check camera is still valid before navigating
      if (cameraController != null && cameraController!.value.isInitialized) {
        // Navigate to camera screen
        Get.to(() => KycBankCameraScreen());
      } else {
        throw Exception('Camera initialization incomplete');
      }
    } catch (e) {
      print('Error starting camera: $e');
      if (e is CameraException &&
          (e.code == 'cameraPermission' ||
              e.code == 'CameraAccessDenied' ||
              (e.description?.toLowerCase().contains('permission') ?? false))) {
        await CameraPermissionHelper.showPermissionSettingsDialog();
      } else if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr(
            'kyc_bank_controller_failed_to_start_camera_please_try',
          ),
        );
      }
      await _disposeCamera();
      // Try to navigate back if camera failed
      if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
        Get.back(closeOverlays: true);
      }
    }
  }

  // Capture image from camera (called from camera screen)
  Future<void> captureImage() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr(
            'deposit_instruction_controller_camera_is_not_ready_please_wait',
          ),
        );
      }
      return;
    }

    try {
      isLoading.value = true;

      // Store reference before disposing
      final camController = cameraController;
      final image = await camController!.takePicture();

      final File imageFile = File(image.path);

      // Compress image if needed (max 1.5 MB)
      final compressedFile = await FileCompressionHelper.compressIfNeeded(
        imageFile,
      );

      // Clear reference first, then dispose
      cameraController = null;
      update(); // Notify GetBuilder to rebuild

      // Dispose after a small delay to ensure UI has updated
      await Future.delayed(const Duration(milliseconds: 100));
      await camController.dispose();

      Get.back(closeOverlays: true); // Close camera screen

      // Set proof file
      setProofFile(compressedFile);

      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showSuccess(
          message: TranslationUtils.tr(
            'kyc_bank_controller_image_captured_successfully',
          ),
        );
      }
    } catch (e) {
      print('❌ Error capturing image: $e');
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Failed to capture image: ${e.toString()}',
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

  @override
  void onClose() {
    // Cancel timer when controller is disposed
    _otpCountdownTimer?.cancel();
    _otpCountdownTimer = null;

    // Dispose app lifecycle listener
    _appLifecycleListener.dispose();

    // Dispose camera
    _disposeCamera();

    super.onClose();
  }
}
