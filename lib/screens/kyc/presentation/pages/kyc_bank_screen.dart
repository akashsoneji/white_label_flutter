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

      // Preselect account type when provided (e.g. "Add Bank Account" flow)
      final preselectedAccountType =
          Get.arguments?['account_type'] as String?;
      if (preselectedAccountType != null &&
          controller.accountTypes.contains(preselectedAccountType)) {
        controller.setAccountType(preselectedAccountType);
      }
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
            title: TranslationUtils.tr('bank_list_screen_add_withdrawal_method'),
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

                                    // Proof upload section — only when the
                                    // API requires proof for this method.
                                    if (controller.isProofRequired)
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
                TranslationUtils.tr('bank_list_screen_add_withdrawal_method'),
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

                                    // Proof upload section — only when the
                                    // API requires proof for this method.
                                    if (controller.isProofRequired)
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
                              message: languageService.tr(
                                'kyc_bank_submitting',
                              ),
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
          labelText: languageService.tr('kyc_bank_screen_account_type'),
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
            labelText: languageService.tr('kyc_bank_screen_account_type'),
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
            languageService.tr(
              'kyc_bank_screen_error_loading_account_type_field',
            ),
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
            languageService.tr('kyc_bank_screen_error_loading_network_field'),
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
            languageService.tr('kyc_bank_screen_error_loading_form_fields'),
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
              languageService.tr(
                'kyc_bank_screen_please_select_an_account_type_to',
              ),
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
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
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
          alignment: AlignmentDirectional.centerEnd,
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
                    ? languageService.tr('kyc_bank_screen_sending')
                    : controller.isOtpCountdownActive.value
                    ? languageService.tr('kyc_bank_screen_resend_otp_in', {
                      'time': controller.getFormattedCountdown(),
                    })
                    : languageService.tr('kyc_bank_screen_resend_otp'),
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
        _otpControllers[index].selection = TextSelection(
          baseOffset: 0,
          extentOffset: _otpControllers[index].text.length,
        );
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
                            message: languageService.tr(
                              'kyc_bank_screen_bank_account_numbers_do_not_match',
                            ),
                            title: languageService.tr(
                              'kyc_bank_screen_validation_error',
                            ),
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
                  controller.isOtpSent.value
                      ? languageService.tr('common_submit')
                      : languageService.tr('forgot_password_screen_send_otp'),
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
                  languageService.tr('kyc_bank_screen_select_account_type'),
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
          labelText: languageService.tr('kyc_bank_screen_relationship'),
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
            labelText: languageService.tr('kyc_bank_screen_relationship'),
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
            languageService.tr('kyc_bank_screen_error_loading_fields'),
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
                  languageService.tr('kyc_bank_screen_select_relationship'),
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

  // Helper for Crypto Network bottom sheet
  void _showCryptoNetworkBottomSheet() {
    showModalBottomSheet(
      isScrollControlled: true,
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
              Obx(() {
                final listHeight = (MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        MediaQuery.of(context).viewInsets.bottom -
                        120)
                    .clamp(200.0, 500.0);
                return SizedBox(
                  height: listHeight,
                  child: controller.allowedCryptoNetworks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.w),
                            child: Text(
                              languageService.tr(
                                'kyc_bank_screen_no_networks_available',
                              ),
                              style: AppTextStyles.bodyText.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: AlwaysScrollableScrollPhysics(),
                          itemCount: controller.allowedCryptoNetworks.length,
                          itemBuilder: (context, index) {
                            final network = controller.allowedCryptoNetworks[index];
                            return ListTile(
                              title: Text(
                                network.label ?? '',
                                style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                              ),
                              trailing: controller.selectedCryptoNetwork.value == network.slug
                                  ? Icon(Icons.check, color: AppColors.primary)
                                  : null,
                              onTap: () {
                                controller.selectedCryptoNetwork.value = network.slug ?? '';
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                );
              }),
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
                  languageService.tr('kyc_bank_screen_select_code_type'),
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
      final result = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (result != null && result.path != null) {
        File imageFile = File(result.path!);
        // Compress image if needed (max 1.5 MB)
        imageFile = await FileCompressionHelper.compressIfNeeded(imageFile);
        controller.setProofFile(imageFile);
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      // Show error message using AppNotificationController
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: languageService.tr(
            'deposit_instruction_controller_failed_to_pick_image_from_gallery',
          ),
          title: languageService.tr('close_position_error'),
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
                  final result = await FilePicker.pickFile(
                    type: FileType.any,
                  );
                  if (result != null && result.path != null) {
                    File imageFile = File(result.path!);
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
              labelText: languageService.tr('kyc_bank_screen_iban_ifsc'),
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
                labelText: languageService.tr('kyc_bank_screen_iban_ifsc'),
                labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Right field - Code input
          Directionality(
            textDirection: TextDirection.ltr,
            child: RTLHelper.rtlTextField(
            controller: _ifscIbanCodeController,
            onChanged: (value) => controller.ifscIbanCode.value = value,
            labelText: languageService.tr('kyc_bank_screen_code'),
            hintText:
                controller.optRadio.value == 'IFSC'
                    ? languageService.tr('kyc_bank_screen_enter_ifsc_code')
                    : languageService.tr('kyc_bank_screen_enter_iban_code'),
            decoration: InputDecoration(
              labelText: languageService.tr('kyc_bank_screen_code'),
              labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
              floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
              hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
            ),
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
        () => Directionality(
          textDirection: TextDirection.ltr,
          child: RTLHelper.rtlTextField(
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
