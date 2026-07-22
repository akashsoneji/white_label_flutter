import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/kyc/view_models/kyc_bank_controller.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/file_compression_helper.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';

import 'package:crm_app/widgets/kyc_scaffold.dart';
import 'package:crm_app/models/bank_withdralList_model.dart';

class KycBankScreen extends StatefulWidget {
  const KycBankScreen({Key? key}) : super(key: key);

  @override
  State<KycBankScreen> createState() => _KycBankScreenState();
}

class _KycBankScreenState extends State<KycBankScreen> {
  late final KycBankController controller;
  final LanguageService languageService = Get.find<LanguageService>();
  final TextEditingController _accountHolderController =
      TextEditingController();
  final TextEditingController _beneficiaryBankController =
      TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _confirmAccountNumberController =
      TextEditingController();
  final TextEditingController _swiftCodeController = TextEditingController();
  final TextEditingController _cryptoAddressController =
      TextEditingController();
  final TextEditingController _upiAddressController = TextEditingController();
  final TextEditingController _ifscIbanCodeController = TextEditingController();

  // OTP Controllers and Focus Nodes
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  final List<String> _previousOtpValues = List.generate(6, (index) => '');

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _otpSectionKey = GlobalKey();

  // Get screen name from arguments
  String? screenName;
  bool? isFromKYC;

  // Account number validation state
  final RxBool _accountNumbersMatch = false.obs;
  final RxBool _showValidationError = false.obs;

  // Static variables for show/hide functionality
  bool _showAccountNumber1 = true;
  bool _showAccountNumber2 = true;

  @override
  void initState() {
    super.initState();
    try {
      // Initialize the controller
      controller = Get.put(KycBankController());
      // Get screen name from Get.arguments
      screenName = Get.arguments?['screen_name'] as String?;
      isFromKYC = Get.arguments?['isFromKYC'] as bool?;
      print('Screen name from arguments: $screenName');
      controller.setIsBankList(screenName == 'Withdrawal Method');
      print('✅ KycBankController initialized successfully');

      // Initialize camera
      controller.initializeCamera();

      // Initialize IFSC/IBAN controller with current value
      _ifscIbanCodeController.text = controller.ifscIbanCode.value;

      // Listen for OTP sent to auto-scroll
      ever(controller.isOtpSent, (bool isSent) {
        if (isSent && mounted) {
          // Clear previous OTP entries
          for (var otpController in _otpControllers) {
            otpController.clear();
          }
          // Wait for the widget to rebuild and show OTP section
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _otpSectionKey.currentContext != null) {
              // Scroll to OTP section
              Scrollable.ensureVisible(
                _otpSectionKey.currentContext!,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: 0.3, // Position OTP section at 30% from top
              );
              // Focus first OTP field after scroll animation
              Future.delayed(const Duration(milliseconds: 350), () {
                if (mounted) {
                  _otpFocusNodes[0].requestFocus();
                }
              });
            }
          });
        }
      });
    } catch (e) {
      print('❌ Error initializing KycBankController: $e');
      // Fallback initialization
      try {
        controller = Get.put(KycBankController());
        print('✅ Fallback KycBankController initialization successful');
      } catch (fallbackError) {
        print('❌ Fallback initialization also failed: $fallbackError');
        // Create a minimal controller
        controller = KycBankController();
        Get.put(controller);
      }
    }
  }

  @override
  void dispose() {
    _accountHolderController.dispose();
    _beneficiaryBankController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _swiftCodeController.dispose();
    _cryptoAddressController.dispose();
    _upiAddressController.dispose();
    _ifscIbanCodeController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  // Handle back navigation - go back (refresh will be handled by bank_list_screen via .then() callback)
  void _handleBackNavigation() {
    // Navigate back - the bank_list_screen will refresh via .then() callback
    Get.back(closeOverlays: true);
  }

  @override
  Widget build(BuildContext context) {
    try {
      return isFromKYC!
          ? KycScaffold(
            title: 'Add Withdrawal Method',
            body: Container(
              color: AppColors.whiteColor, // theme-aware
              child: Stack(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 15.h),

                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              child: Obx(
                                () => Column(
                                  children: [
                                    SizedBox(height: 8.h),
                                    // Account Type field
                                    _buildAccountTypeField(),
                                    SizedBox(height: 8.h),
                                    _buildRelationShipTypeField(),
                                    // Currency field
                                    _buildCurrencyField(),
                                    // SizedBox(height: 8.h),

                                    // Account Holder / Address Holder (common field)
                                    _buildFormField(
                                      languageService.tr(
                                        controller.selectedAccountType.value ==
                                                'Crypto'
                                            ? 'kyc_address_holder_name'
                                            : 'kyc_account_holder_name',
                                      ),
                                      _accountHolderController,
                                      onChanged:
                                          (value) =>
                                              controller
                                                  .accountHolderName
                                                  .value = value,
                                    ),

                                    // Dynamic fields based on account type
                                    ..._buildDynamicFields(),

                                    // SizedBox(height: 8.h),

                                    // Proof upload section
                                    _buildProofUploadSection(),

                                    // OTP section
                                    if (controller.isOtpSent.value) ...[
                                      SizedBox(height: 20.h),
                                      _buildOtpField(key: _otpSectionKey),
                                    ],

                                    SizedBox(height: 40.h),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Proof upload section (required for all account types)
                          // _buildProofUploadSection(),

                          // Action buttons
                          _buildActionButtons(),
                          SizedBox(height: 24.h),
                        ],
                      ),
                    ),
                  ),
                  // Loading overlay
                  Obx(
                    () =>
                        controller.isLoading.value
                            ? CommonLoadingWidget(
                              message: '',
                              backgroundColor: Colors.black.withOpacity(0.5),
                              isFullScreen: true,
                            )
                            : SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          )
          : Scaffold(
            backgroundColor: AppColors.whiteColor,
            appBar: AppBar(
              backgroundColor: AppColors.whiteColor,
              scrolledUnderElevation: 0,
              elevation: 0,
              leading: AppBackButton(
                onPressed: () => _handleBackNavigation(),
              ),
              title: Text(
                'Add Withdrawal Method',
                style: AppTextStyles.heading.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              centerTitle: true,
            ),
            body: Container(
              color: AppColors.whiteColor, // theme-aware
              child: Stack(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 15.h),

                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              child: Obx(
                                () => Column(
                                  children: [
                                    SizedBox(height: 8.h),
                                    // Account Type field
                                    _buildAccountTypeField(),
                                    SizedBox(height: 8.h),
                                    _buildRelationShipTypeField(),
                                    // Currency field
                                    _buildCurrencyField(),
                                    // SizedBox(height: 8.h),

                                    // Account Holder Name (common field)
                                    _buildFormField(
                                      languageService.tr(
                                         controller.selectedAccountType.value ==
                                                'Crypto'
                                            ? 'kyc_address_holder_name'
                                            : 'kyc_account_holder_name',
                                      
                                      ),
                                      _accountHolderController,
                                      onChanged:
                                          (value) =>
                                              controller
                                                  .accountHolderName
                                                  .value = value,
                                    ),

                                    // Dynamic fields based on account type
                                    ..._buildDynamicFields(),

                                    // SizedBox(height: 8.h),

                                    // Proof upload section
                                    _buildProofUploadSection(),

                                    // OTP section
                                    if (controller.isOtpSent.value) ...[
                                      SizedBox(height: 20.h),
                                      _buildOtpField(key: _otpSectionKey),
                                    ],

                                    SizedBox(height: 40.h),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Proof upload section (required for all account types)
                          // _buildProofUploadSection(),

                          // Action buttons
                          _buildActionButtons(),
                          SizedBox(height: 24.h),
                        ],
                      ),
                    ),
                  ),
                  // Loading overlay
                  Obx(
                    () =>
                        controller.isLoading.value
                            ? CommonLoadingWidget(
                              message: 'Submitting withdrawal request...',
                              backgroundColor: Colors.black.withOpacity(0.5),
                              isFullScreen: true,
                            )
                            : SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
    } catch (e) {
      print('Error in KycBankScreen: $e');
      // Fallback UI in case of error
      return Scaffold(
        backgroundColor: AppColors.whiteColor,
        appBar: AppBar(
          backgroundColor: AppColors.whiteColor,
          title: Text(languageService.tr('kyc_withdrawal_title')),
          leading: const AppBackButton(),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                languageService.tr('kyc_error_loading'),
                style: AppTextStyles.bodyText.copyWith(fontSize: 16),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Get.back(closeOverlays: true),
                child: Text(languageService.tr('kyc_go_back')),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Account Type field
  Widget _buildAccountTypeField() {
    try {
      return Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: RTLHelper.rtlTextField(
          readOnly: true,
          onTap: _showAccountTypeOptions,
          controller: TextEditingController(
            text: controller.selectedAccountType.value,
          ),
          labelText: 'Account Type *',
          suffixIcon: InkWell(
            onTap: _showAccountTypeOptions,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: RTLHelper.rtlIcon(
                Icons.keyboard_arrow_down,
                color: AppColors.icongrey,
              ),
            ),
          ),
          decoration: InputDecoration(
            labelText: 'Account Type *',
            labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
            floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
          ),
        ),
      );
    } catch (e) {
      print('Error in _buildAccountTypeField: $e');
      return Container(
        height: 50.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Error loading account type field',
            style: AppTextStyles.bodyText.copyWith(color: Colors.red),
          ),
        ),
      );
    }
  }

  // Currency field
  Widget _buildCurrencyField() {
    try {
      return Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: RTLHelper.rtlTextField(
          readOnly: true,
          onTap: _showCurrencyOptions,
          controller: TextEditingController(
            text: controller.selectedCurrency.value,
          ),
          labelText: 'Currency *',
          suffixIcon: InkWell(
            onTap: _showCurrencyOptions,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: RTLHelper.rtlIcon(
                Icons.keyboard_arrow_down,
                color: AppColors.icongrey,
              ),
            ),
          ),
          decoration: InputDecoration(
            labelText: 'Currency *',
            labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
            floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
          ),
        ),
      );
    } catch (e) {
      print('Error in _buildCurrencyField: $e');
      return Container(
        height: 50.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Error loading currency field',
            style: AppTextStyles.bodyText.copyWith(color: Colors.red),
          ),
        ),
      );
    }
  }

  // Crypto Network field
  Widget _buildCryptoNetworkField() {
    try {
      return Obx(() {
        // Find selected network label
        final selectedNetwork = controller.allowedCryptoNetworks.firstWhere(
          (n) => n.slug == controller.selectedCryptoNetwork.value,
          orElse: () => AllowedCryptoNetwork(slug: '', label: ''),
        );
        final displayName = selectedNetwork.label ?? '';

        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RTLHelper.rtlTextField(
                readOnly: true,
                onTap: _showCryptoNetworkBottomSheet,
                controller: TextEditingController(
                  text: displayName,
                ),
                labelText: languageService.tr('kyc_crypto_network'),
                suffixIcon: InkWell(
                  onTap: _showCryptoNetworkBottomSheet,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: RTLHelper.rtlIcon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.icongrey,
                    ),
                  ),
                ),
                decoration: InputDecoration(
                  labelText: languageService.tr('kyc_crypto_network'),
                  hintText: languageService.tr('kyc_crypto_network_hint'),
                  labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                  floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                languageService.tr('kyc_crypto_network_help'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 12.sp,
                  color: AppColors.textGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      });
    } catch (e) {
      print('Error in _buildCryptoNetworkField: $e');
      return Container(
        height: 50.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Error loading network field',
            style: AppTextStyles.bodyText.copyWith(color: Colors.red),
          ),
        ),
      );
    }
  }

  // Dynamic fields based on account type
  List<Widget> _buildDynamicFields() {
    try {
      return [
        // Animated container for smooth transitions
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(children: _getFieldsForAccountType()),
        ),
      ];
    } catch (e) {
      print('Error in _buildDynamicFields: $e');
      return [
        Container(
          padding: EdgeInsets.all(20.w),
          child: Text(
            'Error loading form fields',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              color: Colors.red,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
  }

  // Get fields based on selected account type
  List<Widget> _getFieldsForAccountType() {
    switch (controller.selectedAccountType.value.toLowerCase()) {
      case 'bank':
        return _buildBankFields();
      case 'crypto':
        return _buildCryptoFields();
      case 'upi':
        return _buildUpiFields();
      default:
        return [
          Container(
            padding: EdgeInsets.all(20.w),
            child: Text(
              'Please select an account type to see relevant fields',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ];
    }
  }

  // Bank fields
  List<Widget> _buildBankFields() {
    return [
      // Bank section header
      // _buildSectionHeader("Bank Details", Icons.account_balance),
      _buildFormField(
        languageService.tr('kyc_bank_name'),
        _beneficiaryBankController,
        onChanged: (value) => controller.bankName.value = value,
        // icon: Icons.account_balance,
      ),
      // IFSC/IBAN Radio Selection
      // _buildIfscIbanRadioSelection(),
      // SizedBox(height: 16.h),
      _buildIfscIbanField(),
      _buildAccountNumberField(
        languageService.tr('kyc_bank_account_number'),
        _accountNumberController,
        onChanged: (value) => controller.bankAccountNumber.value = value,
        isFirstField: true,
      ),
      _buildAccountNumberField(
        languageService.tr('kyc_confirm_bank_account_number'),
        _confirmAccountNumberController,
        onChanged: (value) => controller.confirmBankAccountNumber.value = value,
        isFirstField: false,
      ),
      _buildFormField(
        languageService.tr('kyc_bank_swift_code'),
        _swiftCodeController,
        onChanged: (value) => controller.bankSwiftCode.value = value,
        // icon: Icons.code,
      ),
    ];
  }

  // Crypto fields
  List<Widget> _buildCryptoFields() {
    return [
      // Crypto section header
      // _buildSectionHeader("Crypto Details", Icons.currency_bitcoin),
      _buildCryptoNetworkField(),
      _buildFormField(
        languageService.tr('kyc_crypto_address'),
        _cryptoAddressController,
        onChanged: (value) => controller.cryptoAddress.value = value,
        // icon: Icons.currency_bitcoin,
        keyboardType: TextInputType.text,
      ),
    ];
  }

  // UPI fields
  List<Widget> _buildUpiFields() {
    return [
      // UPI section header
      _buildFormField(
        languageService.tr('kyc_upi_address'),
        _upiAddressController,
        onChanged: (value) => controller.upiAddress.value = value,
        // icon: Icons.payment,
        keyboardType: TextInputType.text,
      ),
    ];
  }

  // Proof upload section
  Widget _buildProofUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageService.tr('kyc_add_proof'),
          style: AppTextStyles.bodyText.copyWith(fontSize: 14.sp, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: _showProofOptions,
          child: Obx(
            () => Container(
              height: 120.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                border: Border.all(
                  color: AppColors.primary,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child:
                  controller.proofFile.value == null
                      ? Center(
                        child: Icon(
                          Icons.add,
                          size: 32.sp,
                          color: AppColors.primary,
                        ),
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Image.file(
                          controller.proofFile.value!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
            ),
          ),
        ),
      ],
    );
  }

  // OTP field
  Widget _buildOtpField({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(languageService.tr('kyc_enter_otp'), style: AppTextStyles.heading),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 50.w,
              height: 56.h,
              child:
                  Platform.isAndroid
                      ? _buildOtpBoxAndroid(index)
                      : _buildOtpBox(index),
            );
          }),
        ),
        SizedBox(height: 16.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.email_outlined, color: AppColors.primary, size: 20.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  languageService.tr('kyc_otp_sent_message'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Resend OTP Button
        SizedBox(height: 12.h),
        Align(
          alignment: Alignment.centerRight,
          child: Obx(
            () => TextButton(
              onPressed:
                  controller.canResendOtp
                      ? () {
                        // Resend OTP functionality
                        controller.sendOtp();
                      }
                      : null,
              child: Text(
                controller.isOtpLoading.value
                    ? 'Sending...'
                    : controller.isOtpCountdownActive.value
                    ? 'Resend OTP in ${controller.getFormattedCountdown()}'
                    : 'Resend OTP',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  color:
                      controller.canResendOtp
                          ? AppColors.primary
                          : AppColors.textGrey,
                  fontWeight: FontWeight.w600,
                  decoration:
                      controller.canResendOtp
                          ? TextDecoration.underline
                          : TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build OTP box for iOS
  Widget _buildOtpBox(int index) {
    return TextField(
      controller: _otpControllers[index],
      focusNode: _otpFocusNodes[index],
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: index == 0 ? 6 : 1,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(index == 0 ? 6 : 1),
      ],
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
      decoration: InputDecoration(
        counterText: '',
        contentPadding: EdgeInsets.symmetric(vertical: 16.h),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      onChanged: (value) {
        if (value.length > 1 && value.length <= 6) {
          // Handle paste - distribute digits across fields
          final otp = value.padRight(6, '');
          for (int i = 0; i < 6; i++) {
            _otpControllers[i].text = i < otp.length ? otp[i] : '';
            _previousOtpValues[i] = i < otp.length ? otp[i] : '';
          }
          if (otp.length == 6) {
            _otpFocusNodes[5].requestFocus();
          } else if (otp.length >
              _otpControllers.indexWhere((c) => c.text.isEmpty)) {
            _otpFocusNodes[otp.length - 1].requestFocus();
          }
          _updateOtpValue();
        } else if (value.length == 1 && index < 5) {
          // Move to next box when a digit is entered
          _previousOtpValues[index] = value;
          _otpFocusNodes[index + 1].requestFocus();
          _updateOtpValue();
        } else if (value.isEmpty && index > 0) {
          // Move to previous box when backspace clears the current box
          _previousOtpValues[index] = '';
          _otpFocusNodes[index - 1].requestFocus();
          _updateOtpValue();
        } else if (value.isEmpty && index == 0) {
          // Clear all fields and reset focus to first box if first box is cleared
          for (int i = 0; i < 6; i++) {
            _otpControllers[i].clear();
            _previousOtpValues[i] = '';
          }
          _otpFocusNodes[0].requestFocus();
          _updateOtpValue();
        } else if (value.length == 1 && index == 5) {
          _previousOtpValues[index] = value;
          _updateOtpValue();
        }
      },
      onTap: () {
        // When user taps on a box, select all text for easy replacement
        if (_otpControllers[index].text.isNotEmpty) {
          _otpControllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _otpControllers[index].text.length,
          );
        }
      },
    );
  }

  // Build OTP box for Android with RawKeyboardListener for backspace handling
  Widget _buildOtpBoxAndroid(int index) {
    final keyboardFocusNode = FocusNode();

    return index == 0
        ? TextField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6, // Allow paste of full OTP in first field
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.symmetric(vertical: 16.h),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onChanged: (value) {
            if (value.length > 1 && value.length <= 6) {
              // Handle paste - distribute digits across fields
              final otp = value.padRight(6, '');
              for (int i = 0; i < 6; i++) {
                _otpControllers[i].text = i < otp.length ? otp[i] : '';
                _previousOtpValues[i] = i < otp.length ? otp[i] : '';
              }
              if (otp.length == 6) {
                _otpFocusNodes[5].requestFocus();
              } else if (otp.length >
                  _otpControllers.indexWhere((c) => c.text.isEmpty)) {
                _otpFocusNodes[otp.length - 1].requestFocus();
              }
              _updateOtpValue();
            } else if (value.length == 1 && index < 5) {
              _previousOtpValues[index] = value;
              _otpFocusNodes[index + 1].requestFocus();
              _updateOtpValue();
            }
          },
          onTap: () {
            if (_otpControllers[index].text.isNotEmpty) {
              _otpControllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _otpControllers[index].text.length,
              );
            }
          },
        )
        : RawKeyboardListener(
          focusNode: keyboardFocusNode,
          onKey: (event) {
            if (event is RawKeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.backspace &&
                _otpControllers[index].text.isEmpty &&
                index > 0) {
              // Handle backspace on empty field - move to previous field
              _otpFocusNodes[index - 1].requestFocus();
            }
          },
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.symmetric(vertical: 16.h),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                _previousOtpValues[index] = value;
                _otpFocusNodes[index + 1].requestFocus();
                _updateOtpValue();
              } else if (value.isEmpty && index > 0) {
                // Move to previous box when backspace clears the current box
                _previousOtpValues[index] = '';
                _otpFocusNodes[index - 1].requestFocus();
                _updateOtpValue();
              } else if (value.isNotEmpty && index == 5) {
                _previousOtpValues[index] = value;
                _updateOtpValue();
              }
            },
            onTap: () {
              if (_otpControllers[index].text.isNotEmpty) {
                _otpControllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _otpControllers[index].text.length,
                );
              }
            },
          ),
        );
  }

  void _updateOtpValue() {
    // Join all OTP digits and update controller
    final otp = _otpControllers.map((controller) => controller.text).join();
    controller.otp.value = otp;
  }

  // Action buttons
  Widget _buildActionButtons() {
    return Obx(
      () => ElevatedButton(
        onPressed:
            controller.isOtpLoading.value || controller.isLoading.value
                ? null
                : () {
                  // Dismiss keyboard when submit button is tapped
                  FocusScope.of(context).unfocus();

                  if (controller.isOtpSent.value) {
                    controller.submitWithdrawal();
                  } else {
                    // Validate account numbers before sending OTP
                    if (controller.selectedAccountType.value.toLowerCase() ==
                        'bank') {
                      if (_validateAccountNumbers()) {
                        controller.sendOtp();
                      } else {
                        // Show error message using AppNotificationController
                        if (Get.isRegistered<AppNotificationController>()) {
                          Get.find<AppNotificationController>().showError(
                            message: 'Bank account numbers do not match',
                            title: 'Validation Error',
                          );
                        }
                      }
                    } else {
                      controller.sendOtp();
                    }
                  }
                },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.zero,
        ),
        child:
            controller.isOtpLoading.value || controller.isLoading.value
                ? ButtonLoadingWidget(size: 20.0, color: AppColors.whiteColor)
                : Text(
                  controller.isOtpSent.value ? 'Submit' : 'Send OTP',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor,
                  ),
                ),
      ),
    );
  }

  // Helper for Account Type bottom sheet
  void _showAccountTypeOptions() {
    showModalBottomSheet(
      backgroundColor: AppColors.whiteColor,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  'Select Account Type',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...controller.accountTypes.map((type) {
                return ListTile(
                  title: Text(
                    type,
                    style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                  ),
                  trailing:
                      controller.selectedAccountType.value == type
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                  onTap: () {
                    controller.setAccountType(type);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRelationShipTypeField() {
    try {
      return Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: RTLHelper.rtlTextField(
          readOnly: true,
          onTap: _showRelationShipBottomSheet,
          controller: TextEditingController(
            text: controller.selectedRelationship.value,
          ),
          labelText: 'Relationship *',
          suffixIcon: InkWell(
            onTap: _showRelationShipBottomSheet,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: RTLHelper.rtlIcon(
                Icons.keyboard_arrow_down,
                color: AppColors.icongrey,
              ),
            ),
          ),
          decoration: InputDecoration(
            labelText: 'Relationship *',
            labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
            floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
          ),
        ),
      );
    } catch (e) {
      print('Error in _buildAccountTypeField: $e');
      return Container(
        height: 50.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Error loading fields',
            style: AppTextStyles.bodyText.copyWith(color: Colors.red),
          ),
        ),
      );
    }
  }

  void _showRelationShipBottomSheet() {
    showModalBottomSheet(
      backgroundColor: AppColors.whiteColor,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  'Select RelationShip',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...controller.relationShips.map((type) {
                return ListTile(
                  title: Text(
                    type,
                    style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                  ),
                  trailing:
                      controller.selectedRelationship.value == type
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                  onTap: () {
                    controller.setRelationShip(type);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // Helper for Currency bottom sheet
  void _showCurrencyOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: _CurrencySelectionBottomSheet(controller: controller),
        );
      },
    );
  }

  // Helper for Crypto Network bottom sheet
  void _showCryptoNetworkBottomSheet() {
    showModalBottomSheet(
      backgroundColor: AppColors.whiteColor,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  languageService.tr('kyc_crypto_network_hint'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                children: controller.allowedCryptoNetworks.isEmpty
                    ? [
                        Padding(
                          padding: EdgeInsets.all(24.w),
                          child: Text(
                            'No networks available',
                            style: AppTextStyles.bodyText.copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      ]
                    : controller.allowedCryptoNetworks.map((network) {
                        return ListTile(
                          title: Text(
                            network.label ?? '',
                            style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                          ),
                          trailing:
                              controller.selectedCryptoNetwork.value == network.slug
                                  ? Icon(Icons.check, color: AppColors.primary)
                                  : null,
                          onTap: () {
                            controller.selectedCryptoNetwork.value = network.slug ?? '';
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
              )),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  // Helper for IFSC/IBAN type selection only
  void _showIfscIbanTypeSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Code Type',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 20.h),

                // IBAN Option
                ListTile(
                  title: Text(
                    'IBAN',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  onTap: () {
                    controller.setOptRadio('IBAN');
                    Navigator.pop(context);
                  },
                ),

                // IFSC Option
                ListTile(
                  title: Text(
                    'IFSC',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  onTap: () {
                    controller.setOptRadio('IFSC');
                    Navigator.pop(context);
                  },
                ),

                SizedBox(height: 10.h),
              ],
            ),
          ),
        );
      },
    );
  }

  // Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.single.path != null) {
        File imageFile = File(result.files.single.path!);
        // Compress image if needed (max 1.5 MB)
        imageFile = await FileCompressionHelper.compressIfNeeded(imageFile);
        controller.setProofFile(imageFile);
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      // Show error message using AppNotificationController
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Failed to pick image from gallery. Please try again.',
          title: 'Error',
        );
      }
    }
  }

  void _showProofOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.textPrimary),
                title: Text(
                  languageService.tr('kyc_take_photo'),
                  style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await controller.startCamera();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.textPrimary),
                title: Text(
                  languageService.tr('kyc_select_from_gallery'),
                  style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.attach_file, color: AppColors.textPrimary),
                title: Text(
                  languageService.tr('kyc_attach_from_documents'),
                  style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                ),
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                  );
                  if (result != null && result.files.single.path != null) {
                    File imageFile = File(result.files.single.path!);
                    // Compress image if needed (max 1.5 MB)
                    imageFile = await FileCompressionHelper.compressIfNeeded(
                      imageFile,
                    );
                    controller.setProofFile(imageFile);
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // IFSC/IBAN Field with two separate fields
  Widget _buildIfscIbanField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        children: [
          // Left field - IBAN/IFSC selection
          Obx(
            () => RTLHelper.rtlTextField(
              readOnly: true,
              onTap: _showIfscIbanTypeSelection,
              controller: TextEditingController(
                text: controller.optRadio.value,
              ),
              labelText: 'IBAN/IFSC',
              suffixIcon: InkWell(
                onTap: _showIfscIbanTypeSelection,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: RTLHelper.rtlIcon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.icongrey,
                  ),
                ),
              ),
              decoration: InputDecoration(
                labelText: 'IBAN/IFSC',
                labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Right field - Code input
          RTLHelper.rtlTextField(
            controller: _ifscIbanCodeController,
            onChanged: (value) => controller.ifscIbanCode.value = value,
            labelText: 'Code',
            hintText:
                controller.optRadio.value == 'IFSC'
                    ? 'Enter IFSC code'
                    : 'Enter IBAN code',
            decoration: InputDecoration(
              labelText: 'Code',
              labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
              floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
              hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    Function(String)? onChanged,
    TextInputType? keyboardType,
    IconData? icon,
    bool obscureText = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: RTLHelper.rtlTextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        labelText: label,
        obscureText: obscureText,
        prefixIcon:
            icon != null
                ? RTLHelper.rtlIcon(
                  icon,
                  color: AppColors.primary.withOpacity(0.7),
                  size: 20,
                )
                : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
          floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }

  // Custom account number field with validation
  Widget _buildAccountNumberField(
    String label,
    TextEditingController controller, {
    Function(String)? onChanged,
    bool isFirstField = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Obx(
        () => RTLHelper.rtlTextField(
          controller: controller,
          onChanged: (value) {
            onChanged?.call(value);
            _validateAccountNumbers();
          },
          keyboardType: TextInputType.number,
          labelText: label,
          obscureText: isFirstField ? _showAccountNumber1 : _showAccountNumber2,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                if (isFirstField) {
                  _showAccountNumber1 = !_showAccountNumber1;
                } else {
                  _showAccountNumber2 = !_showAccountNumber2;
                }
              });
            },
            icon: Icon(
              (isFirstField ? _showAccountNumber1 : _showAccountNumber2)
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: AppColors.primary.withOpacity(0.7),
            ),
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
            floatingLabelStyle: AppTextStyles.bodyText.copyWith(
              color:
                  _showValidationError.value ? Colors.red : AppColors.primary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    _showValidationError.value ? Colors.red : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    _showValidationError.value ? Colors.red : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    _showValidationError.value ? Colors.red : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  // Validate account numbers when Send OTP is clicked
  bool _validateAccountNumbers() {
    final accountNumber = _accountNumberController.text.trim();
    final confirmAccountNumber = _confirmAccountNumberController.text.trim();

    if (accountNumber.isEmpty || confirmAccountNumber.isEmpty) {
      _showValidationError.value = true;
      _accountNumbersMatch.value = false;
      return false;
    }

    if (accountNumber == confirmAccountNumber) {
      _showValidationError.value = false;
      _accountNumbersMatch.value = true;
      return true;
    } else {
      _showValidationError.value = true;
      _accountNumbersMatch.value = false;
      return false;
    }
  }
}

class _CurrencySelectionBottomSheet extends StatefulWidget {
  final KycBankController controller;

  const _CurrencySelectionBottomSheet({required this.controller});

  @override
  State<_CurrencySelectionBottomSheet> createState() =>
      _CurrencySelectionBottomSheetState();
}

class _CurrencySelectionBottomSheetState
    extends State<_CurrencySelectionBottomSheet> {
  late TextEditingController searchController;
  late List<String> filteredCurrencies;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    filteredCurrencies = List.from(widget.controller.currencies);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterCurrencies(String value) {
    setState(() {
      if (value.length < 2) {
        filteredCurrencies = List.from(widget.controller.currencies);
      } else {
        filteredCurrencies =
            widget.controller.currencies
                .where(
                  (currency) =>
                      currency.toUpperCase().contains(value.toUpperCase()),
                )
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final safeAreaTop = mediaQuery.padding.top;
    final safeAreaBottom = mediaQuery.padding.bottom;

    // Calculate available height: screen height - safe area insets - keyboard height
    // When keyboard is visible, reduce the max height accordingly
    final availableHeight =
        screenHeight - safeAreaTop - safeAreaBottom - keyboardHeight;

    // Limit to 75% of available height when keyboard is visible, 65% when not
    // Ensure minimum height of 300 and maximum doesn't exceed available space
    final heightPercentage = keyboardHeight > 0 ? 0.75 : 0.65;
    final maxHeight = (availableHeight * heightPercentage).clamp(
      300.0,
      availableHeight - 20,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, minHeight: 300.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'Select Currency',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Search field
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                controller: searchController,
                onChanged: _filterCurrencies,
                decoration: InputDecoration(
                  hintText: 'Search currency...',
                  prefixIcon: Icon(Icons.search, color: AppColors.icongrey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            // Currency list - use Flexible to take remaining space and ensure it's scrollable
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate available height for list dynamically
                  // Account for: title padding (16*2) + title text (~22) + search field (~60) + spacing (8)
                  final headerSpace = (16.w * 2) + (18.sp * 1.2) + 60.h + 8.h;
                  final listHeight = (constraints.maxHeight - headerSpace)
                      .clamp(150.0, constraints.maxHeight);

                  return SizedBox(
                    height: listHeight > 0 ? listHeight : 200.0,
                    child: ListView.builder(
                      shrinkWrap: false,
                      physics: AlwaysScrollableScrollPhysics(),
                      itemCount: filteredCurrencies.length,
                      itemBuilder: (context, index) {
                        final currency = filteredCurrencies[index];
                        return ListTile(
                          title: Text(
                            currency,
                            style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                          ),
                          trailing:
                              widget.controller.selectedCurrency.value ==
                                      currency
                                  ? Icon(Icons.check, color: AppColors.primary)
                                  : null,
                          onTap: () {
                            widget.controller.setCurrency(currency);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
