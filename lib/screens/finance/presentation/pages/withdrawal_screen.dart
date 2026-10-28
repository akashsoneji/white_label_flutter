import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/utils/navigation_helper.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/screens/finance/view_models/withdrawal_controller.dart';
import '../../../../widgets/common_loading_widget.dart';
import '../../../../widgets/custom_toast.dart';
import '../../../../routes/app_pages.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/feature_maintenance_gate.dart';
import 'package:crm_app/utils/currency_format.dart';
import 'package:crm_app/models/mt5_account.dart' as mt5m;
import 'package:crm_app/screens/trading/view_models/account_controller.dart';

mt5m.MT5Account? _resolveMt5Account(String? metaAccountNumber) {
  if (metaAccountNumber == null || metaAccountNumber.isEmpty) return null;
  if (!Get.isRegistered<AccountController>()) return null;
  for (final acc in Get.find<AccountController>().mt5Accounts) {
    if (acc.metaAccountNumber == metaAccountNumber) return acc;
  }
  return null;
}

class WithdrawalScreen extends StatefulWidget {
  final String? accountNumber;

  const WithdrawalScreen({super.key, this.accountNumber});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final WithdrawalController controller = Get.put(WithdrawalController());
  final TextEditingController amountController = TextEditingController(
    text: '0.00',
  );
  /// Read-only payout amount (e.g. INR), derived from [amountController]
  /// using the API's conversion_rate.
  final TextEditingController payoutAmountController = TextEditingController();
  final LanguageService languageService = Get.find<LanguageService>();
  late final FocusNode amountFocusNode;
  bool isAmountConfirmed = true; // Checkbox state

  // OTP Controllers and Focus Nodes
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _otpSectionKey = GlobalKey();

  // Validation state
  final RxString _validationMessage = ''.obs;
  final RxBool _showValidationError = false.obs;

  // Add a variable to track previous values for better backspace detection
  final List<String> _previousOtpValues = List.generate(6, (index) => '');

  @override
  void initState() {
    super.initState();

    // Set preselected account number in controller if provided
    if (widget.accountNumber != null && widget.accountNumber!.isNotEmpty) {
      controller.setPreselectedAccountNumber(widget.accountNumber);
      print(
        "WithdrawalScreen: Set preselected account number in controller: \"${widget.accountNumber}\"",
      );
    }

    // Listen for success messages and automatically show success toast
    ever(controller.successMessage, (String message) {
      if (message.isNotEmpty && mounted) {
        CustomToastService.showSuccess(message: message);
        // Clear the message after showing
        controller.successMessage.value = '';
      }
    });

    // Listen for error messages and automatically show error toast
    ever(controller.errorMessage, (String message) {
      if (message.isNotEmpty && mounted) {
        CustomToastService.showError(message: message);
        // Clear the message after showing
        controller.errorMessage.value = '';
      }
    });

    // Listen for OTP sent to auto-scroll
    ever(controller.isOtpSent, (bool isSent) {
      if (isSent && mounted) {
        // Clear previous OTP entries
        for (var otpController in _otpControllers) {
          otpController.clear();
        }
        // Reset previous values
        for (int i = 0; i < _previousOtpValues.length; i++) {
          _previousOtpValues[i] = '';
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

    // Initialize previous values tracking
    for (int i = 0; i < _otpControllers.length; i++) {
      _previousOtpValues[i] = '';
    }

    // Initialize FocusNode for amount field
    amountFocusNode = FocusNode();
    amountFocusNode.addListener(() {
      if (amountFocusNode.hasFocus && amountController.text == '0.00') {
        amountController.text = '';
      } else if (!amountFocusNode.hasFocus && amountController.text.isEmpty) {
        amountController.text = '0.00';
      }
    });
    amountController.addListener(() {
      _syncPayoutFromSource();
      if (mounted) setState(() {});
    });
    // USC↔USD account switch or a new method changes the rate.
    ever(controller.selectedAccount, (_) => _syncPayoutFromSource());
    ever(controller.withdrawalMethodDetail, (_) => _syncPayoutFromSource());

    // OTP handling is now done directly in _buildOtpBox and _buildOtpBoxAndroid methods
  }

  void _syncPayoutFromSource() {
    if (!mounted || !controller.hasConversion) return;
    final source = double.tryParse(amountController.text.trim()) ?? 0;
    payoutAmountController.text = source > 0
        ? controller.convertToPayoutCurrency(source).toStringAsFixed(2)
        : '0.00';
  }

  // Method to refresh withdrawal method details when returning from bank list
  void _refreshOnReturn() {
    final selectedMethod = controller.selectedWithdrawalMethod.value;
    if (selectedMethod != null && selectedMethod.methodSlug != null) {
      // Refresh the current method details to get updated userWithdrawalMethods
      controller.fetchWithdrawalMethodDetails(
        selectedMethod.methodSlug!,
        preselectedAccountNumber: widget.accountNumber,
      );
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    payoutAmountController.dispose();
    amountFocusNode.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Vantage's WithdrawalScreen delegates here, so this covers all brands.
    return FeatureMaintenanceGate(
      feature: MaintenanceFeature.withdrawal,
      child: Builder(builder: _buildScreen),
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsetsDirectional.only(start: 10.w),
          child: AppBackButton(
            onPressed: () => NavigationHelper.safeBack(context: context),
          ),
        ),
        shape: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300, // divider color
            width: 1, // divider thickness
          ),
        ),

        title: Text(
          languageService.tr('withdrawal'),
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Obx(() {
          // Show loading indicator while fetching data OR until we've received initial response
          if (controller.isLoading ||
              !controller.hasReceivedInitialResponse.value) {
            return Center(
              child: CommonLoadingWidget(
                message: languageService.tr('withdrawal_loading_details'),
                size: 50.0,
                color: AppColors.primary,
              ),
            );
          }

          // Show no data view when API returns status: false with message
          final showNoData = controller.showNoDataView.value;
          print("WithdrawalScreen: showNoDataView = $showNoData");

          if (showNoData) {
            return _buildNoDataView();
          }

          // Show normal form view
          final form = SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 32.h),

                // Withdrawal Method Field
                _buildWithdrawalMethodField(),

                SizedBox(height: 24.h),

                // Withdraw From Field
                _buildWithdrawFromField(),

                Obx(() {
                  final method =
                      controller.selectedPaymentMethod.value.toLowerCase();
                  if (method == 'bank') {
                    return Column(
                      children: [SizedBox(height: 32.h), _buildBankFromField()],
                    );
                  } else if (method == 'crypto') {
                    // Only show Crypto Type for crypto method, not for local
                    return Column(
                      children: [
                        SizedBox(height: 32.h),
                        _buildCryptoFromField(),
                      ],
                    );
                  } else {
                    // For local or other methods, don't show Crypto Type
                    return SizedBox.shrink();
                  }
                }),

                SizedBox(height: 24.h),

                // Amount Field
                _buildAmountField(),

                // OTP Field (shown only when OTP is sent)
                Obx(() {
                  if (controller.isOtpSent.value) {
                    return Column(
                      children: [
                        SizedBox(height: 24.h),
                        _buildOtpField(key: _otpSectionKey),
                      ],
                    );
                  }
                  return SizedBox.shrink();
                }),

                Obx(() {
                  if (controller.isOtpSent.value) {
                    return SizedBox.shrink();
                  }
                  return SizedBox(height: 16.h);
                }),

                // Confirmation Checkbox
                _buildConfirmationCheckbox(),
                 SizedBox(height: 16.h),

                // Validation message
                _buildValidationMessage(),

                SizedBox(height: 24.h),
              ],
            ),
          );

          // Button stays pinned above the scroll content so it is always
          // visible; it rides up with the keyboard via resizeToAvoidBottomInset.
          return Column(
            children: [
              Expanded(child: form),
              Container(
                padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 16.h),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: _buildSendOtpButton(),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildWithdrawalMethodField() {
    return Obx(
      () => RTLHelper.rtlTextField(
        controller: TextEditingController(
          text:
              controller.selectedWithdrawalMethod.value != null
                  ? '${controller.selectedWithdrawalMethod.value!.methodName ?? ''}'
                  : controller.selectedPaymentMethod.value,
        ),
        readOnly: true,
        onTap: () => _showWithdrawalMethodDropdown(),
        suffixIcon: InkWell(
          onTap: () => _showWithdrawalMethodDropdown(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: RTLHelper.rtlIcon(
              Icons.keyboard_arrow_down_outlined,
              color: Colors.grey,
            ),
          ),
        ),
        decoration: InputDecoration(
          labelText: TranslationUtils.tr(
            'withdrawal_screen_withdrawal_method_label',
          ),
          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
          floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawFromField() {
    return Obx(() {
      // Get display text with account number and balance
      final displayText = _getAccountDisplayText();

      return RTLHelper.rtlTextField(
        controller: TextEditingController(text: displayText),
        readOnly: true,
        onTap: () => _showAccountDropdown(),
        suffixIcon: InkWell(
          onTap: () => _showAccountDropdown(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: RTLHelper.rtlIcon(
              Icons.keyboard_arrow_down_outlined,
              color: Colors.grey,
            ),
          ),
        ),
        decoration: InputDecoration(
          labelText: languageService.tr('withdrawal_withdrawFrom'),
          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
          floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error),
          ),
        ),
      );
    });
  }

  // Helper method to format account display text with balance
  String _getAccountDisplayText() {
    final selectedAccountId = controller.selectedAccount.value;

    if (selectedAccountId == null || selectedAccountId.isEmpty) {
      return '';
    }

    // Check if it's a wallet
    final wallet = controller.wallet.value;
    if (wallet != null && wallet.walletId == selectedAccountId) {
      return '${wallet.walletId ?? ''} - \$ ${wallet.walletBalance ?? '0.00'}';
    }

    // Check if it's the IBM wallet
    final ibmWallet = controller.ibmWallet.value;
    if (ibmWallet != null && ibmWallet.referenceLinkId == selectedAccountId) {
      return '${ibmWallet.referenceLinkId ?? ''} - \$ ${ibmWallet.balance ?? '0.00'}';
    }

    // Check if it's an MT5 account
    final accounts = controller.userMT5Accounts;
    try {
      final selectedAccount = accounts.firstWhere(
        (account) => account.metaAccountNumber == selectedAccountId,
      );
      final resolved = _resolveMt5Account(selectedAccount.metaAccountNumber);
      final freeMargin =
          double.tryParse(selectedAccount.freeMargin.toString()) ?? 0;
      return '${selectedAccount.metaAccountNumber} - ${CurrencyFormat.amount(freeMargin, resolved)}';
    } catch (e) {
      // Account not found, return just the ID
      return selectedAccountId;
    }
  }

  Widget _buildBankFromField() {
    return Obx(
      () => RTLHelper.rtlTextField(
        controller: TextEditingController(
          text: controller.selectedBankAccount.value ?? '',
        ),
        readOnly: true,
        onTap: () => _showBankDropDown(),
        suffixIcon: InkWell(
          onTap: () => _showBankDropDown(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: RTLHelper.rtlIcon(
              Icons.keyboard_arrow_down_outlined,
              color: Colors.grey,
            ),
          ),
        ),
        decoration: InputDecoration(
          labelText: languageService.tr('withdrawal_screen_bank_account'),
          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
          floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  Widget _buildCryptoFromField() {
    return Obx(() {
      final userWithdrawalMethods =
          controller
              .withdrawalMethodDetail
              .value
              ?.data
              ?.userWithdrawalMethods ??
          [];
      final hasMethods = userWithdrawalMethods.isNotEmpty;

      // If no methods available, show "Add Method" button
      if (!hasMethods) {
        return Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textGrey,
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      languageService.tr(
                        'withdrawal_screen_no_crypto_withdrawal_methods_available',
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                // Navigate directly to add withdrawal method form with
                // Crypto preselected. Refresh when returning.
                Get.toNamed(
                  AppPages.KYC_BANK,
                  arguments: {
                    'screen_name': 'Withdrawal Method',
                    'account_type': 'Crypto',
                    'isFromKYC': false,
                  },
                )?.then((_) {
                  _refreshOnReturn();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.whiteColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // padding: EdgeInsets.symmetric(vertical: 16.h),
                minimumSize: Size(double.infinity, 44.h),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20.sp,color: AppColors.whiteColor,),
                  SizedBox(width: 8.w),
                  Text(
                    languageService.tr('withdrawal_screen_add_method'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.whiteColor
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      // Show dropdown if methods are available
      // Get display text for selected crypto account
      String displayText = '';
      if (controller.selectedCryptoAccount.value != null &&
          controller.selectedCryptoAccount.value!.isNotEmpty) {
        // Find the selected method to get display text
        final selectedValue = controller.selectedCryptoAccount.value!;
        for (final method in userWithdrawalMethods) {
          final cryptoAddress = method.cryptoAddress ?? '';
          final holderName = method.holderName ?? '';
          final methodId = method.id ?? '';

          if (methodId == selectedValue ||
              (cryptoAddress.isNotEmpty &&
                  (cryptoAddress == selectedValue ||
                      selectedValue.contains(cryptoAddress)))) {
            // Build display text
            if (cryptoAddress.isNotEmpty) {
              displayText = cryptoAddress;
            } else if (holderName.isNotEmpty) {
              displayText = holderName;
            }

            break;
          }
        }

        // If not found, use the stored value
        if (displayText.isEmpty) {
          displayText = selectedValue;
        }
      }

      return RTLHelper.rtlTextField(
        controller: TextEditingController(text: displayText),
        readOnly: true,
        onTap: () => _showCryptoTypeDropdown(),
        suffixIcon: InkWell(
          onTap: () => _showCryptoTypeDropdown(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: RTLHelper.rtlIcon(
              Icons.keyboard_arrow_down_outlined,
              color: Colors.grey,
            ),
          ),
        ),
        decoration: InputDecoration(
          labelText: languageService.tr('withdrawal_screen_crypto_type'),
          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
          floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error),
          ),
        ),
      );
    });
  }

  /// Limits from the API are in USD; cent accounts also see the USC figure.
  String _formatLimit(double usdLimit) {
    final usd = '${usdLimit.toStringAsFixed(2)} USD';
    if (!controller.isSelectedAccountCent) return usd;
    return '$usd (${(usdLimit * 100).toStringAsFixed(2)} USC)';
  }

  Widget _buildAmountField() {
    return Obx(() {
      final m = controller.withdrawalMethodDetail.value?.data?.withdrawalMethod;
      final minLimit = double.tryParse(m?.minLimit?.toString() ?? '');
      final maxLimit = double.tryParse(m?.maxLimit?.toString() ?? '');
      final sourceCurrency = controller.sourceCurrency;
      final isCent = controller.isSelectedAccountCent;
      final hasConversion = controller.hasConversion;

      final entered = double.tryParse(amountController.text.trim()) ?? 0;
      final usdValue = controller.toUsd(entered);

      String? error;
      if (entered > 0) {
        if (minLimit != null && usdValue < minLimit) {
          error = TranslationUtils.trArgs(
            'withdrawal_screen_minimum_withdrawal_is',
            {'amount': _formatLimit(minLimit)},
          );
        } else if (maxLimit != null && usdValue > maxLimit) {
          error = TranslationUtils.trArgs(
            'withdrawal_screen_maximum_withdrawal_is',
            {'amount': _formatLimit(maxLimit)},
          );
        }
      }
      final limitText = (minLimit != null && maxLimit != null)
          ? TranslationUtils.trArgs('deposit_real_screen_limit_min_max', {
              'min': _formatLimit(minLimit),
              'max': _formatLimit(maxLimit),
            })
          : null;

      final amountStyle = AppTextStyles.bodyText.copyWith(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
      );
      final amountFormatters = [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        _SingleDecimalTextFormatter(),
      ];

      final sourceField = RTLHelper.rtlTextField(
        style: amountStyle,
        controller: amountController,
        focusNode: amountFocusNode,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        inputFormatters: amountFormatters,
        decoration: _amountDecoration(
          label: languageService.tr('deposit_amount'),
          currency: sourceCurrency,
          hasError: error != null,
        ),
      );

      final helperStyle = AppTextStyles.bodyText.copyWith(
        fontSize: 12.sp,
        color: AppColors.textSecondary,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasConversion)
            Row(
              children: [
                Expanded(child: sourceField),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Text(
                    '=',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: payoutAmountController,
                    readOnly: true,
                    canRequestFocus: false,
                    enableInteractiveSelection: false,
                    style: amountStyle.copyWith(fontWeight: FontWeight.w600),
                    textDirection: TextDirection.ltr,
                    decoration: _amountDecoration(
                      label: languageService.tr('withdrawal_you_receive'),
                      currency: controller.payoutCurrency,
                    ).copyWith(
                      filled: true,
                      fillColor: AppColors.primary.withOpacity(0.05),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                ),
              ],
            )
          else
            sourceField,
          SizedBox(height: 6.h),
          if (error != null)
            Text(
              error,
              style: TextStyle(color: AppColors.error, fontSize: 12.sp),
            )
          else if (limitText != null)
            Text(limitText, style: helperStyle),
          if (isCent && entered > 0) ...[
            SizedBox(height: 4.h),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${entered.toStringAsFixed(2)} USC → ${usdValue.toStringAsFixed(2)} USD',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          if (hasConversion) ...[
            SizedBox(height: 4.h),
            Text(
              '${languageService.tr('withdrawal_exchange_rate')}: 1 USD = ${controller.conversionRate.toStringAsFixed(2)} ${controller.payoutCurrency}',
              style: helperStyle,
            ),
          ],
          SizedBox(height: 16.h),
          _buildTotalWithdrawal(usdValue),
        ],
      );
    });
  }

  InputDecoration _amountDecoration({
    required String label,
    required String currency,
    bool hasError = false,
  }) {
    final borderColor = hasError ? AppColors.error : AppColors.border;
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
      floatingLabelStyle: AppTextStyles.bodyText.copyWith(
        color: hasError ? AppColors.error : AppColors.primary,
      ),
      hintText: '0.00',
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      suffixIcon: _buildCurrencyTag(currency),
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? AppColors.error : AppColors.primary,
          width: 2,
        ),
      ),
    );
  }

  Widget _buildCurrencyTag(String currency) {
    return Container(
      margin: EdgeInsetsDirectional.only(end: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        currency,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildTotalWithdrawal(double usdValue) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              languageService.tr('withdrawal_total_withdrawal'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              'USD ${usdValue.toStringAsFixed(2)}',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              isAmountConfirmed = !isAmountConfirmed;
            });
          },
          child: Container(
            width: 20.w,
            height: 20.h,
            decoration: BoxDecoration(
              color: isAmountConfirmed ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color:
                    isAmountConfirmed ? AppColors.primary : Colors.grey[400]!,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child:
                isAmountConfirmed
                    ? Icon(Icons.check, color: AppColors.whiteColor, size: 14)
                    : null,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${languageService.tr('withdrawal_confirmAmount')} ',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextSpan(
                  text: languageService.tr('withdrawal_terms'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpField({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageService.tr('wallet_enter_otp'),
          style: AppTextStyles.heading,
        ),
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
                  languageService.tr('withdrawal_otp_sent'),
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
      cursorColor: AppColors.primary,
      selectionControls: MaterialTextSelectionControls(),
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
        } else if (value.length == 1 && index < _otpControllers.length - 1) {
          // Move to next box when a digit is entered
          _previousOtpValues[index] = value;
          _otpFocusNodes[index + 1].requestFocus();
        } else if (value.isEmpty && index > 0) {
          // Move to previous box when backspace clears the current box
          _previousOtpValues[index] = '';
          _otpFocusNodes[index - 1].requestFocus();
        } else if (value.isEmpty && index == 0) {
          // Clear all fields and reset focus to first box if first box is cleared
          for (int i = 0; i < _otpControllers.length; i++) {
            _otpControllers[i].clear();
            _previousOtpValues[i] = '';
          }
          _otpFocusNodes[0].requestFocus();
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
          cursorColor: AppColors.primary,
          selectionControls: MaterialTextSelectionControls(),
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
            } else if (value.length == 1 &&
                index < _otpControllers.length - 1) {
              _previousOtpValues[index] = value;
              _otpFocusNodes[index + 1].requestFocus();
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
            cursorColor: AppColors.primary,
            selectionControls: MaterialTextSelectionControls(),
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
              if (value.isNotEmpty && index < _otpControllers.length - 1) {
                _previousOtpValues[index] = value;
                _otpFocusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                // Move to previous box when backspace clears the current box
                _previousOtpValues[index] = '';
                _otpFocusNodes[index - 1].requestFocus();
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

  // Validation method
  bool _validateForm() {
    _showValidationError.value = false;
    _validationMessage.value = '';

    // Check withdrawal method
    if (controller.selectedWithdrawalMethod.value == null ||
        controller.selectedPaymentMethod.value.isEmpty) {
      _validationMessage.value = languageService.tr(
        'withdrawal_screen_please_select_withdrawal_method',
      );
      _showValidationError.value = true;
      return false;
    }

    // Check withdraw from account
    if (controller.selectedAccount.value == null ||
        controller.selectedAccount.value!.isEmpty) {
      _validationMessage.value = languageService.tr(
        'withdrawal_screen_please_select_account_to_withdraw_from',
      );
      _showValidationError.value = true;
      return false;
    }

    // Check bank account (if bank method selected)
    if (controller.selectedPaymentMethod.value.toLowerCase() == 'bank') {
      if (controller.selectedBankAccount.value == null ||
          controller.selectedBankAccount.value!.isEmpty) {
        _validationMessage.value = languageService.tr(
          'withdrawal_screen_please_select_bank_account',
        );
        _showValidationError.value = true;
        return false;
      }
    }

    // Check crypto account (if crypto method selected)
    if (controller.selectedPaymentMethod.value.toLowerCase() == 'crypto') {
      if (controller.selectedCryptoAccount.value == null ||
          controller.selectedCryptoAccount.value!.isEmpty) {
        _validationMessage.value = languageService.tr(
          'withdrawal_screen_please_select_crypto_account',
        );
        _showValidationError.value = true;
        return false;
      }
    }

    // Check amount
    String amountText = amountController.text.trim();
    if (amountText.isEmpty || amountText == '0.00') {
      _validationMessage.value = languageService.tr(
        'withdrawal_screen_please_enter_withdrawal_amount',
      );
      _showValidationError.value = true;
      return false;
    }

    // Check if amount is valid
    String cleanAmount = amountText;
    if (cleanAmount.isEmpty) {
      _validationMessage.value = languageService.tr(
        'deposit_validation_amount',
      );
      _showValidationError.value = true;
      return false;
    }

    // Check if amount is greater than 0
    double? amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0) {
      _validationMessage.value = languageService.tr(
        'withdrawal_screen_amount_must_be_greater_than_zero',
      );
      _showValidationError.value = true;
      return false;
    }

    final m = controller.withdrawalMethodDetail.value?.data?.withdrawalMethod;
    if (m != null) {
      final minLimit = double.tryParse(m.minLimit?.toString() ?? '');
      final maxLimit = double.tryParse(m.maxLimit?.toString() ?? '');
      final usdAmount = controller.toUsd(amount);
      if (minLimit != null && usdAmount < minLimit) {
        _validationMessage.value = languageService.tr(
          'withdrawal_screen_amount_cannot_be_less_than_minimum',
          {'amount': _formatLimit(minLimit)},
        );
        _showValidationError.value = true;
        return false;
      }
      if (maxLimit != null && usdAmount > maxLimit) {
        _validationMessage.value = languageService.tr(
          'withdrawal_screen_amount_cannot_be_more_than_maximum',
          {'amount': _formatLimit(maxLimit)},
        );
        _showValidationError.value = true;
        return false;
      }
    }

    // Check OTP if OTP is sent
    if (controller.isOtpSent.value) {
      final otp = _otpControllers.map((controller) => controller.text).join();
      if (otp.isEmpty) {
        _validationMessage.value = languageService.tr(
          'kyc_bank_controller_please_enter_otp',
        );
        _showValidationError.value = true;
        return false;
      }
      if (otp.length != 6) {
        _validationMessage.value = languageService.tr(
          'withdrawal_screen_otp_must_be_six_digits',
        );
        _showValidationError.value = true;
        return false;
      }
    }

    return true;
  }

  // Show validation message
  Widget _buildValidationMessage() {
    return Obx(() {
      if (!_showValidationError.value || _validationMessage.value.isEmpty) {
        return SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 20.w),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                _validationMessage.value,
                style: AppTextStyles.bodyText.copyWith(
                  color: Colors.red,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSendOtpButton() {
    return Obx(
      () => Container(
        width: double.infinity,
        height: 40.h,
        child: ElevatedButton(
          onPressed:
              (isAmountConfirmed && !controller.isOtpLoading.value && !controller.isLoading)
                  ? () {
                    // Dismiss keyboard
                    FocusScope.of(context).unfocus();
                    
                    // Validate form before proceeding
                    if (!_validateForm()) {
                      return;
                    }

                    if (controller.isOtpSent.value) {
                      // Submit withdrawal with OTP
                      final otp =
                          _otpControllers
                              .map((controller) => controller.text)
                              .join();
                      controller.submitWithdrawalWithOtp(otp);
                    } else {
                      // Send OTP
                      controller.withdrawalAmount.value = amountController.text;
                      controller.submitWithdrawal();
                      // Auto-scroll will be handled by the listener in initState
                    }
                  }
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.whiteColor,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
          child:
              (controller.isOtpLoading.value || controller.isLoading)
                  ? ButtonLoadingWidget(size: 20.0, color: AppColors.whiteColor)
                  : Text(
                    controller.isOtpSent.value
                        ? languageService.tr(
                          'withdrawal_screen_submit_withdrawal',
                        )
                        : languageService.tr('forgot_password_screen_send_otp'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.whiteColor,
                    ),
                  ),
        ),
      ),
    );
  }

  void _showWithdrawalMethodDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  languageService.tr(
                    'withdrawal_screen_select_withdrawal_method',
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 24.h),
                Container(
                  height: 200.h,
                  child: Obx(
                    () => ListView.builder(
                      itemCount: controller.withdrawalMethods.length,
                      itemBuilder: (context, index) {
                        final method = controller.withdrawalMethods[index];
                        final isSelected =
                            method == controller.selectedPaymentMethod.value;
                        return InkWell(
                          onTap: () {
                            // Clear crypto account when withdrawal method changes
                            controller.selectedCryptoAccount.value = null;
                            controller.selectedBankAccount.value = null;

                            controller.selectedPaymentMethod.value =
                                method.methodName!;
                            controller.selectedWithdrawalMethod.value =
                                method; // Set the complete withdrawal method object
                            controller.fetchWithdrawalMethodDetails(
                              method.methodSlug ?? '',
                              preselectedAccountNumber: widget.accountNumber,
                            );
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 16.h,
                              horizontal: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppColors.primary.withOpacity(0.1)
                                      : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    method.methodName!.camelCase ?? '',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 16.sp,
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showAccountDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Obx(() {
          final accounts = controller.userMT5Accounts;
          final wallet = controller.wallet.value;
          final ibmWallet = controller.ibmWallet.value;

          // Check if we have any accounts (MT5 or Wallet)
          final bool hasMT5Accounts = accounts.isNotEmpty;
          final bool hasWallet =
              wallet != null &&
              wallet.walletId != null &&
              wallet.walletId!.isNotEmpty &&
              // Treat a missing status as active — some endpoints omit it.
              (wallet.walletStatus == null ||
                  wallet.walletStatus!.isEmpty ||
                  wallet.walletStatus!.toLowerCase() == 'active');
          final bool hasIbmWallet =
              ibmWallet != null &&
              ibmWallet.referenceLinkId != null &&
              ibmWallet.referenceLinkId!.isNotEmpty;

          if (!hasMT5Accounts && !hasWallet && !hasIbmWallet) {
            return Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  languageService.tr('common_no_accounts'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }

          // Calculate total items (MT5 accounts + wallet + ibm wallet)
          final int totalItems = accounts.length +
              (hasWallet ? 1 : 0) +
              (hasIbmWallet ? 1 : 0);

          return ListView.separated(
            shrinkWrap: true,
            itemCount: totalItems,
            separatorBuilder:
                (_, __) => Divider(height: 1, color: Colors.grey.shade300),
            itemBuilder: (context, index) {
              // IBM wallet is the very last item when present.
              final int ibmWalletIndex =
                  accounts.length + (hasWallet ? 1 : 0);
              final bool isIbmWalletItem =
                  hasIbmWallet && index == ibmWalletIndex;

              if (isIbmWalletItem) {
                final isSelected = ibmWallet.referenceLinkId ==
                    controller.selectedAccount.value;

                return InkWell(
                  onTap: () {
                    controller.selectedAccount.value =
                        ibmWallet.referenceLinkId;
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            languageService.tr('withdrawal_screen_ib_wallet'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            ibmWallet.referenceLinkId ?? "-",
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          "\$ ${ibmWallet.balance ?? '0.00'}",
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (isSelected) ...[
                          SizedBox(width: 8.w),
                          Icon(Icons.check,
                              color: AppColors.primary, size: 20),
                        ],
                      ],
                    ),
                  ),
                );
              }

              // Check if this is the wallet item
              final bool isWalletItem = hasWallet && index == accounts.length;

              if (isWalletItem) {
                // Render Wallet item
                final isSelected =
                    wallet.walletId == controller.selectedAccount.value;

                return InkWell(
                  onTap: () {
                    controller.selectedAccount.value = wallet.walletId;
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : null,
                    ),
                    child: Row(
                      children: [
                        // Wallet badge (orange color to distinguish from MT5)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            languageService.tr('bottom_navigation_wallet'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Wallet ID
                        Expanded(
                          child: Text(
                            wallet.walletId ?? "-",
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // Wallet Balance
                        Text(
                          "\$ ${wallet.walletBalance ?? '0.00'}",
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                          ),
                        ),
                        if (isSelected) ...[
                          SizedBox(width: 8.w),
                          Icon(Icons.check, color: AppColors.primary, size: 20),
                        ],
                      ],
                    ),
                  ),
                );
              } else {
                // Render MT5 Account item
                final account = accounts[index];
                final isSelected =
                    account.metaAccountNumber ==
                    controller.selectedAccount.value;

                return InkWell(
                  onTap: () {
                    controller.selectedAccount.value =
                        account.metaAccountNumber;
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : null,
                    ),
                    child: Row(
                      children: [
                        // Group label (Standard / Wallet)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            account.masterGroupId,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),

                        SizedBox(width: 12.w),

                        // Account number
                        Expanded(
                          child: Text(
                            account.metaAccountNumber,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),

                        // Balance
                        Text(
                          CurrencyFormat.amount(
                            double.tryParse(account.freeMargin.toString()) ?? 0,
                            _resolveMt5Account(account.metaAccountNumber),
                          ),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                          ),
                        ),

                        if (isSelected) ...[
                          SizedBox(width: 8.w),
                          Icon(Icons.check, color: AppColors.primary, size: 20),
                        ],
                      ],
                    ),
                  ),
                );
              }
            },
          );
        });
      },
    );
  }

  void _showBankDropDown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Obx(() {
            final userWithdrawalMethods =
                controller
                    .withdrawalMethodDetail
                    .value
                    ?.data
                    ?.userWithdrawalMethods ??
                [];

            return Container(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle indicator
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  // Title
                  Text(
                    languageService.tr('withdrawal_screen_select_bank_account'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  if (userWithdrawalMethods.isEmpty) ...[
                    // Empty state
                    Icon(
                      Icons.account_balance_outlined,
                      size: 48.w,
                      color: AppColors.textGrey.withOpacity(0.5),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      languageService.tr(
                        'withdrawal_screen_no_bank_account_found',
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      languageService.tr(
                        'withdrawal_screen_please_add_bank_account_to_proceed',
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.sp,
                        color: AppColors.textGrey,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Get.toNamed(
                            AppPages.KYC_BANK,
                            arguments: {
                              'screen_name': 'Withdrawal Method',
                              'account_type': 'Bank',
                              'isFromKYC': false,
                            },
                          )?.then((_) {
                            _refreshOnReturn();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.whiteColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: Size(double.infinity, 44.h),
                        ),
                        icon: Icon(Icons.add, size: 20.sp,color: AppColors.whiteColor,),
                        label: Text(
                          languageService.tr(
                            'withdrawal_screen_add_bank_account',
                          ),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.whiteColor
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ] else ...[
                    // Bank account list
                    Container(
                      constraints: BoxConstraints(maxHeight: 220.h),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: userWithdrawalMethods.length,
                        itemBuilder: (context, index) {
                          final method = userWithdrawalMethods[index];
                          final bankName = method.bankName ?? '';
                          final accountNumber = method.bankAccountNo ?? '';
                          final holderName = method.holderName ?? '';
                          final displayLabel =
                              bankName.isNotEmpty ? bankName : holderName;
                          final isSelected =
                              controller.selectedBankAccount.value ==
                              accountNumber;

                          return InkWell(
                            onTap: () {
                              controller.selectedBankAccount.value =
                                  accountNumber;
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 14.h,
                                horizontal: 12.w,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.primary.withOpacity(0.1)
                                        : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (displayLabel.isNotEmpty)
                                          Text(
                                            displayLabel,
                                            style: AppTextStyles.bodyText.copyWith(
                                              fontSize: 15.sp,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                              color:
                                                  isSelected
                                                      ? AppColors.primary
                                                      : AppColors.textPrimary,
                                            ),
                                          ),
                                        if (accountNumber.isNotEmpty)
                                          Text(
                                            accountNumber,
                                            style: AppTextStyles.bodyText.copyWith(
                                              fontSize: 13.sp,
                                              color:
                                                  isSelected
                                                      ? AppColors.primary
                                                      : AppColors.textGrey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64.w,
              color: AppColors.primary.withOpacity(0.6),
            ),
            SizedBox(height: 24.h),
            Text(
              controller.noDataMessage.value.isNotEmpty
                  ? controller.noDataMessage.value
                  : languageService.tr('ticket_no_data'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Text(
              languageService.tr(
                'withdrawal_screen_please_complete_the_required_verification_or',
              ),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                color: AppColors.icongrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.toNamed(AppPages.KYC_INTRO);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.whiteColor,
                  padding: EdgeInsets.zero,
                  // padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  languageService.tr('withdrawal_screen_complete_verification'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCryptoTypeDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Obx(() {
            final userWithdrawalMethods =
                controller
                    .withdrawalMethodDetail
                    .value
                    ?.data
                    ?.userWithdrawalMethods ??
                [];

            if (userWithdrawalMethods.isEmpty) {
              return Container(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Icon(
                      Icons.info_outline,
                      size: 48.sp,
                      color: AppColors.textGrey,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      languageService.tr(
                        'withdrawal_screen_no_crypto_withdrawal_methods_available',
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      languageService.tr(
                        'withdrawal_screen_please_add_withdrawal_method_to_continue',
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to bank list screen to add withdrawal method
                        // Refresh when returning from bank list
                        Get.toNamed(AppPages.BANK_LIST)?.then((_) {
                          _refreshOnReturn();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.whiteColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 20.sp),
                          SizedBox(width: 8.w),
                          Text(
                            languageService.tr('withdrawal_screen_add_method'),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              );
            }

            return Container(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    languageService.tr('withdrawal_screen_select_crypto_type'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    constraints: BoxConstraints(maxHeight: 400.h),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: userWithdrawalMethods.length,
                      separatorBuilder:
                          (_, __) =>
                              Divider(height: 1, color: Colors.grey.shade300),
                      itemBuilder: (context, index) {
                        final method = userWithdrawalMethods[index];
                        final cryptoAddress = method.cryptoAddress ?? '';
                        final holderName = method.holderName ?? '';
                        final status = method.status?.toLowerCase() ?? '';
                        final methodId = method.id ?? '';

                        // Create display text
                        String displayText = '';
                        if (cryptoAddress.isNotEmpty) {
                          displayText = cryptoAddress;
                        } else if (holderName.isNotEmpty) {
                          displayText = holderName;
                        } else {
                          displayText = languageService.tr(
                            'withdrawal_screen_crypto_method_n',
                            {'number': '${index + 1}'},
                          );
                        }

                        final isSelected =
                            controller.selectedCryptoAccount.value == methodId;

                        // API may not return status for existing methods.
                        // Hide only explicitly rejected/inactive methods.
                        if (status == 'rejected' || status == 'inactive') {
                          return SizedBox.shrink();
                        }

                        return InkWell(
                          onTap: () {
                            controller.selectedCryptoAccount.value = methodId;
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 16.h,
                              horizontal: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppColors.primary.withOpacity(0.1)
                                      : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayText,
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 16.sp,
                                          color:
                                              isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            );
          }),
    );
  }
}

/// Formatter that keeps digits and a single decimal point.
class _SingleDecimalTextFormatter extends TextInputFormatter {
  const _SingleDecimalTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final sanitized = _sanitize(newValue.text);
    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );
  }

  String _sanitize(String value) {
    String clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (clean.contains('.')) {
      final parts = clean.split('.');
      clean =
          parts[0] + (parts.length > 1 ? '.${parts.sublist(1).join('')}' : '');
    }
    return clean;
  }
}
