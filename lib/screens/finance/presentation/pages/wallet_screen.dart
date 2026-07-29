import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance/presentation/pages/internal_transfer_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/utils/navigation_helper.dart';

import 'package:crm_app/screens/wallet/view_models/wallet_controller.dart';
import '../../../../services/language_service.dart';
import '../../../../widgets/common_loading_widget.dart';
import '../../../../widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletController controller = Get.put(WalletController());
  final LanguageService languageService = Get.find<LanguageService>();
  late final FocusNode _amountFocusNode;

  @override
  void initState() {
    super.initState();
    // Initialize FocusNode for amount field
    _amountFocusNode = FocusNode();
    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus &&
          controller.amountController.text == '0.00') {
        controller.amountController.text = '';
      } else if (!_amountFocusNode.hasFocus &&
          controller.amountController.text.isEmpty) {
        controller.amountController.text = '0.00';
      }
    });
    controller.fetchWalletData();
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: AppBackButton(
            onPressed: () => NavigationHelper.safeBack(context: context),
          ),
        ),

        title: Text(
          languageService.tr('wallet_title'),
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SizedBox(height: 10.h),

                  // Wallet Information Section
                  _buildWalletInfoSection(),

                  SizedBox(height: 10.h),

                  // Divider
                  _buildDivider(),

                  SizedBox(height: 16.h),

                  // Wallet History Section
                  _buildWalletHistorySection(),
                ],
              ),
            ),
          ),

          // Loading Overlay - Center of Screen
          Obx(
            () =>
                controller.isLoading.value
                    ? CommonLoadingWidget(
                      message: languageService.tr('wallet_processing'),
                      size: 60.0,
                      color: AppColors.primary,
                      isFullScreen: true,
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 10,
          left: 24.w,
          right: 24.w,
        ),
        child: _buildActionButtons(),
      ),
    );
  }

  Widget _buildWalletInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wallet ID
        _buildDivider(),
        SizedBox(height: 10.h),
        Padding(
          padding: RTLHelper.getRTLPadding(left: 24.w, right: 24.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                languageService.tr('wallet_wallet_id'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.375,
                ),
              ),
              Obx(
                () => Text(
                  controller.wallet.value?.walletId ?? '',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.icongrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),
        _buildDivider(),
        SizedBox(height: 10.h),
        // Balance
        Padding(
          padding: RTLHelper.getRTLPadding(left: 24.w, right: 24.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                languageService.tr('wallet_balance'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16.sp,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Obx(
                () => Text(
                  '\$${controller.balance.value}',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.icongrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: Colors.grey[200]);
  }

  void _showAccountSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Obx(() {
          if (controller.mt5Accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(languageService.tr('common_no_accounts')),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            itemCount: controller.mt5Accounts.length,
            itemBuilder: (context, index) {
              final account = controller.mt5Accounts[index];
              return ListTile(
                title: Text(
                  "${account.metaAccountName} (${account.metaAccountNumber})",
                  style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w500),
                ),
                subtitle: Text("\$ ${account.balance}"),
                onTap: () {
                  controller.selectedFromAccount.value = account;
                  controller.transferFromAccount.value =
                      "${account.metaAccountName} (${account.metaAccountNumber})  \$ ${account.balance}";
                  Navigator.pop(context);
                },
              );
            },
          );
        });
      },
    );
  }

  // ignore: unused_element
  void _showOTPBottomSheet() {
    final List<TextEditingController> otpControllers = List.generate(
      6,
      (index) => TextEditingController(),
    );
    final List<FocusNode> otpFocusNodes = List.generate(
      6,
      (index) => FocusNode(),
    );
    final List<String> previousOtpValues = List.generate(6, (index) => '');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageService.tr('wallet_enter_otp'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: AppColors.textPrimary),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                SizedBox(height: 16.h),

                // OTP Input Fields
                Text(
                  languageService.tr('wallet_enter_otp'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textGrey,
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 50.w,
                      height: 56.h,
                      child:
                          Platform.isAndroid
                              ? _buildOtpBoxAndroid(
                                index,
                                otpControllers,
                                otpFocusNodes,
                                previousOtpValues,
                              )
                              : _buildOtpBox(
                                index,
                                otpControllers,
                                otpFocusNodes,
                                previousOtpValues,
                              ),
                    );
                  }),
                ),

                SizedBox(height: 24.h),

                // Submit Button
                Container(
                  width: double.infinity,
                  height: 40.h,
                  child: Obx(
                    () => ElevatedButton(
                      onPressed:
                          controller.isTransferLoading.value
                              ? null
                              : () async {
                                final otp =
                                    otpControllers.map((c) => c.text).join();
                                if (otp.isEmpty || otp.length != 6) {
                                  CustomToastService.showError(
                                    message: languageService.tr(
                                      'wallet_validation_otp',
                                    ),
                                  );
                                  return;
                                }

                                // Get account identifiers for transfer
                                final fromAccountId =
                                    controller
                                        .selectedFromAccount
                                        .value
                                        ?.metaAccountNumber ??
                                    '';
                                final toAccountId =
                                    controller.wallet.value?.walletId ?? '';

                                // Parse amount
                                final rawAmountText =
                                    controller.amountController.text.trim();
                                final cleanedAmount = rawAmountText.replaceAll(
                                  RegExp(r'[^0-9.]'),
                                  '',
                                );

                                // Submit transfer with all required parameters
                                final success = await controller
                                    .submitInternalTransfer(
                                      otp,
                                      '', // comment - empty for wallet screen
                                      fromAccountId,
                                      toAccountId,
                                      cleanedAmount,
                                    );

                                if (success) {
                                  Navigator.pop(context);
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.whiteColor,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child:
                          controller.isTransferLoading.value
                              ? ButtonLoadingWidget(
                                size: 20.0,
                                color: AppColors.whiteColor,
                              )
                              : Text(
                                languageService.tr('wallet_submit_transfer'),
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.whiteColor,
                                ),
                              ),
                    ),
                  ),
                ),

                SizedBox(height: kBottomNavigationBarHeight),
              ],
            ),
          ),
        );
      },
    );
  }

  // (removed unused `_buildTransferSection`)

  // ignore: unused_element
  Widget _buildTransferFromField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Obx(() {
        return RTLHelper.rtlTextField(
          controller: TextEditingController(
            text: controller.transferFromAccount.value,
          ),
          readOnly: true,
          onTap: _showAccountSelectionSheet,
          suffixIcon: InkWell(
            onTap: _showAccountSelectionSheet,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: RTLHelper.rtlIcon(
                Icons.arrow_drop_down,
                color: Colors.grey,
              ),
            ),
          ),
          decoration: InputDecoration(
            labelText: languageService.tr('wallet_transfer_from'),
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
      }),
    );
  }

  // ignore: unused_element
  Widget _buildTransferToField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextField(
        controller: TextEditingController(
          text: languageService.tr('wallet_title'),
        ),
        readOnly: true,
        decoration: InputDecoration(
          labelText: languageService.tr('wallet_transfer_to'),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 10.h,
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

  // ignore: unused_element
  Widget _buildAmountField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: RTLHelper.rtlTextField(
        controller: controller.amountController,
        focusNode: _amountFocusNode,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          _SingleDecimalTextFormatter(),
        ],
        decoration: InputDecoration(
          labelText: languageService.tr('wallet_amount_label'),
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

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Deposit Wallet Button
        Container(
          width: double.infinity,
          height: 40.h,
          child: Obx(
            () => OutlinedButton(
              onPressed: () {
                Get.to(() => PaymentMethodsScreen(accountNumber: ''));
              },

              // controller.isOtpLoading.value ? null : _onInternalTransfer,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  controller.isOtpLoading.value
                      ? ButtonLoadingWidget(
                        size: 20.0,
                        color: AppColors.primary,
                      )
                      : Text(
                        languageService.tr('wallet_deposit_wallet'),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
            ),
          ),
        ),

        SizedBox(height: 16.h),

        // Internal Transfer Button
        Obx(
          () => ElevatedButton(
            onPressed: () {
              Get.to(() => InternalTransferScreen());
            },
            // controller.isLoading.value ? null : _onInternalTransfer,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.whiteColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child:
                controller.isLoading.value
                    ? ButtonLoadingWidget(
                      size: 20.0,
                      color: AppColors.whiteColor,
                    )
                    : Text(
                      languageService.tr('internal_transfer'),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.whiteColor,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  // (removed unused `_onInternalTransfer`)

  // Build OTP box for iOS
  Widget _buildOtpBox(
    int index,
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
    List<String> previousValues,
  ) {
    return TextField(
      controller: controllers[index],
      focusNode: focusNodes[index],
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
            controllers[i].text = i < otp.length ? otp[i] : '';
            previousValues[i] = i < otp.length ? otp[i] : '';
          }
          if (otp.length == 6) {
            focusNodes[5].requestFocus();
          } else if (otp.length >
              controllers.indexWhere((c) => c.text.isEmpty)) {
            focusNodes[otp.length - 1].requestFocus();
          }
        } else if (value.length == 1 && index < 5) {
          // Move to next box when a digit is entered
          previousValues[index] = value;
          focusNodes[index + 1].requestFocus();
        } else if (value.isEmpty && index > 0) {
          // Move to previous box when backspace clears the current box
          previousValues[index] = '';
          focusNodes[index - 1].requestFocus();
        } else if (value.isEmpty && index == 0) {
          // Clear all fields and reset focus to first box if first box is cleared
          for (int i = 0; i < 6; i++) {
            controllers[i].clear();
            previousValues[i] = '';
          }
          focusNodes[0].requestFocus();
        }
      },
      onTap: () {
        // When user taps on a box, select all text for easy replacement
        if (controllers[index].text.isNotEmpty) {
          controllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: controllers[index].text.length,
          );
        }
      },
    );
  }

  // Build OTP box for Android with RawKeyboardListener for backspace handling
  Widget _buildOtpBoxAndroid(
    int index,
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
    List<String> previousValues,
  ) {
    final keyboardFocusNode = FocusNode();

    return index == 0
        ? TextField(
          controller: controllers[index],
          focusNode: focusNodes[index],
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
                controllers[i].text = i < otp.length ? otp[i] : '';
                previousValues[i] = i < otp.length ? otp[i] : '';
              }
              if (otp.length == 6) {
                focusNodes[5].requestFocus();
              } else if (otp.length >
                  controllers.indexWhere((c) => c.text.isEmpty)) {
                focusNodes[otp.length - 1].requestFocus();
              }
            } else if (value.length == 1 && index < 5) {
              previousValues[index] = value;
              focusNodes[index + 1].requestFocus();
            }
          },
          onTap: () {
            if (controllers[index].text.isNotEmpty) {
              controllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: controllers[index].text.length,
              );
            }
          },
        )
        : RawKeyboardListener(
          focusNode: keyboardFocusNode,
          onKey: (event) {
            if (event is RawKeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.backspace &&
                controllers[index].text.isEmpty &&
                index > 0) {
              // Handle backspace on empty field - move to previous field
              focusNodes[index - 1].requestFocus();
            }
          },
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
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
                previousValues[index] = value;
                focusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                // Move to previous box when backspace clears the current box
                previousValues[index] = '';
                focusNodes[index - 1].requestFocus();
              }
            },
            onTap: () {
              if (controllers[index].text.isNotEmpty) {
                controllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controllers[index].text.length,
                );
              }
            },
          ),
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

  // --- Wallet History Section ---

  Widget _buildWalletHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Text(
            'History Filters',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: _buildFilters(),
        ),
        SizedBox(height: 24.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: _buildHistoryList(),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                label: 'Type',
                value: controller.filterType.value,
                options: ['All Types', 'Deposit', 'Withdrawal', 'Transfer'],
                onChanged: (val) {
                  if (val != null) controller.filterType.value = val;
                },
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildFilterDropdown(
                label: 'Status',
                value: controller.filterStatus.value,
                options: ['All Status', 'Approved', 'Pending', 'Rejected'],
                onChanged: (val) {
                  if (val != null) controller.filterStatus.value = val;
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: controller.clearFilters,
              child: Text(
                'Clear',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton(
              onPressed: controller.applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'Apply Filters',
                style: TextStyle(color: Colors.white, fontSize: 12.sp),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Obx(() => Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: options.contains(value) ? value : options.first,
              items: options.map((opt) {
                return DropdownMenuItem(
                  value: opt,
                  child: Text(opt, style: TextStyle(fontSize: 12.sp)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ));
  }

  Widget _buildHistoryList() {
    return Obx(() {
      if (controller.isHistoryLoading.value && controller.historyTransactions.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20.h),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      if (controller.historyTransactions.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(30.h),
            child: Text(
              'No transactions found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
          ),
        );
      }

      return Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.historyTransactions.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final tx = controller.historyTransactions[index];
              return _buildTransactionCard(tx);
            },
          ),
          SizedBox(height: 20.h),
          _buildPagination(),
        ],
      );
    });
  }

  Widget _buildTransactionCard(dynamic tx) {
    final bool isApproved = tx.status?.toLowerCase() == 'approved';
    final bool isDeposit = tx.transactionType?.toLowerCase() == 'deposit';
    final String amountText = tx.amount?.toString() ?? '0.00';
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1E293B) 
            : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isDeposit ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  tx.transactionType?.toUpperCase() ?? 'UNKNOWN',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: isDeposit ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isApproved ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  tx.status?.toUpperCase() ?? 'PENDING',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: isApproved ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.referenceNumber ?? 'N/A',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    tx.createdAtIso != null 
                        ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.tryParse(tx.createdAtIso!)?.toLocal() ?? DateTime.now())
                        : (tx.createdAt ?? ''),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                (isDeposit ? '+' : '-') + amountText,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: isDeposit ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(color: Colors.grey.withOpacity(0.2)),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account',
                      style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary),
                    ),
                    Text(
                      tx.mt5AccountId ?? 'Wallet',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Method',
                      style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary),
                    ),
                    Text(
                      tx.paymentMethod ?? 'N/A',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing page ${controller.currentPage.value} of ${controller.lastPage.value}',
          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
        ),
        Row(
          children: [
            InkWell(
              onTap: controller.currentPage.value > 1 ? controller.prevPage : null,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: controller.currentPage.value > 1 ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  'Prev',
                  style: TextStyle(
                    color: controller.currentPage.value > 1 ? AppColors.primary : Colors.grey,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            InkWell(
              onTap: controller.currentPage.value < controller.lastPage.value ? controller.nextPage : null,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: controller.currentPage.value < controller.lastPage.value ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  'Next',
                  style: TextStyle(
                    color: controller.currentPage.value < controller.lastPage.value ? AppColors.primary : Colors.grey,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ExampleNavigationScreen extends StatelessWidget {
  const ExampleNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Get.to(() => WalletScreen()),
          child: Text(languageService.tr('wallet_open_wallet')),
        ),
      ),
    );
  }
}
