import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/utils/navigation_helper.dart';
import 'package:crm_app/screens/wallet/view_models/wallet_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/services/language_service.dart';

class InternalTransferScreen extends StatefulWidget {
  const InternalTransferScreen({Key? key}) : super(key: key);

  @override
  State<InternalTransferScreen> createState() => _InternalTransferScreenState();
}

class _InternalTransferScreenState extends State<InternalTransferScreen> {
  final WalletController controller = Get.put(WalletController());
  final LanguageService languageService = Get.find<LanguageService>();
  final TextEditingController _transferFromController = TextEditingController();
  final TextEditingController _transferToController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController _commentController = TextEditingController();
  late final FocusNode _amountFocusNode;

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

  bool _showOtpSection = false;
  String? _selectedTransferFrom;
  String? _selectedTransferFromType; // 'mt5', 'wallet', 'ib'
  String? _selectedTransferTo;
  String? _selectedTransferToType; // 'mt5', 'wallet', 'ib'
  dynamic _selectedTransferFromAccount; // UserMT5Account, Wallet, or null
  dynamic _selectedTransferToAccount; // UserMT5Account, Wallet, or null
  // Reactive submitting flag (GetX)
  final RxBool _isSubmitting = false.obs;

  @override
  void initState() {
    super.initState();
    // Initialize FocusNode for amount field
    _amountFocusNode = FocusNode();
    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus && _amountController.text == '0.00') {
        _amountController.text = '';
      } else if (!_amountFocusNode.hasFocus && _amountController.text.isEmpty) {
        _amountController.text = '0.00';
      }
    });
    // Fetch wallet data when screen loads
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Fetch wallet data which includes MT5 accounts
    await controller.fetchWalletData();

    // Set default values if available
    if (controller.mt5Accounts.isNotEmpty && _selectedTransferFrom == null) {
      final firstAccount = controller.mt5Accounts.first;
      setState(() {
        _selectedTransferFrom = firstAccount.metaAccountNumber;
        _selectedTransferFromType = 'mt5';
        _selectedTransferFromAccount = firstAccount;
        _transferFromController.text =
            '${firstAccount.metaAccountNumber} - \$ ${firstAccount.balance}';
        controller.selectedFromAccount.value = firstAccount;
        controller.selectedFromAccountType.value = 'mt5';
      });
    }
    if (controller.wallet.value != null &&
        _selectedTransferTo == null &&
        _selectedTransferFromType != 'wallet') {
      final wallet = controller.wallet.value!;
      setState(() {
        _selectedTransferTo = wallet.walletId;
        _selectedTransferToType = 'wallet';
        _selectedTransferToAccount = wallet;
        _transferToController.text =
            '${wallet.walletId} - \$ ${wallet.walletBalance}';
        controller.selectedToAccount.value = wallet;
        controller.selectedToAccountType.value = 'wallet';
      });
    }
  }

  // Get account identifier for API request
  String _getAccountIdentifier(String? accountType, dynamic account) {
    if (accountType == 'wallet' && account is Wallet) {
      return account.walletId;
    } else if (accountType == 'mt5' && account is UserMT5Account) {
      return account.metaAccountNumber;
    } else if (accountType == 'ib' && account is UserMT5Account) {
      return account.metaAccountNumber;
    }
    return '';
  }

  @override
  void dispose() {
    _transferFromController.dispose();
    _transferToController.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
    _commentController.dispose();
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
    // Check if keyboard is visible
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: AppColors.grey, // divider color
            width: 1, // divider thickness
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset("assets/svg/trade/arro_back.svg"),
          onPressed: () => NavigationHelper.safeBack(context: context),
        ),
        title: Text(
          languageService.tr('internal_transfer'),
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10.h),

                        // Transfer Form Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Transfer Fields
                              _buildTransferFields(),

                              SizedBox(height: 32.h),

                              // OTP Section (Conditionally Visible)
                              if (_showOtpSection)
                                _buildOtpSection(key: _otpSectionKey),

                              SizedBox(height: 50.h),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Fixed bottom section with button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    children: [
                      // Action Button
                      _buildActionButton(),

                      // Dynamic bottom padding based on keyboard visibility
                      SizedBox(
                        height:
                            isKeyboardVisible
                                ? 20.h
                                : kBottomNavigationBarHeight - 20.h,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Center overlay loader while submitting (reactive)
            Obx(
              () =>
                  _isSubmitting.value
                      ? Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.15),
                          alignment: Alignment.center,
                          child: const CommonLoadingWidget(isFullScreen: true),
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transfer From Field
        _buildTransferFromField(),

        SizedBox(height: 18.h),

        // Transfer To Field
        _buildTransferToField(),

        SizedBox(height: 18.h),

        // Amount Field
        _buildAmountField(),

        SizedBox(height: 18.h),

        // Comment Field
        _buildCommentField(),
      ],
    );
  }

  Widget _buildTransferFromField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: RTLHelper.rtlTextField(
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w400),
        controller: _transferFromController,
        readOnly: true,
        onTap: _showOtpSection ? null : () => _showTransferFromDropdown(),
        suffixIcon:
            _showOtpSection
                ? null
                : InkWell(
                  onTap: () => _showTransferFromDropdown(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: RTLHelper.rtlIcon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ),
                ),
        decoration: InputDecoration(
          labelText: 'Transfer From',
          labelStyle: TextStyle(color: AppColors.textGrey),
          floatingLabelStyle: TextStyle(color: AppColors.primary),
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

  Widget _buildTransferToField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: RTLHelper.rtlTextField(
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w400),
        controller: _transferToController,
        readOnly: true,
        onTap: _showOtpSection ? null : () => _showTransferToDropdown(),
        suffixIcon:
            _showOtpSection
                ? null
                : InkWell(
                  onTap: () => _showTransferToDropdown(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: RTLHelper.rtlIcon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ),
                ),
        decoration: InputDecoration(
          labelText: 'Transfer to',
          labelStyle: TextStyle(color: AppColors.textGrey),
          floatingLabelStyle: TextStyle(color: AppColors.primary),
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

  Widget _buildAmountField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: RTLHelper.rtlTextField(
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w400),
        controller: _amountController,
        focusNode: _amountFocusNode,
        readOnly: _showOtpSection,
        onChanged: (value) {},
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          _SingleDecimalTextFormatter(),
        ],
        keyboardType: TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        decoration: InputDecoration(
          labelText: 'Amount',
          labelStyle: TextStyle(color: AppColors.textGrey),
          floatingLabelStyle: TextStyle(color: AppColors.primary),
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

  Widget _buildCommentField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: RTLHelper.rtlTextField(
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w400),
        controller: _commentController,
        readOnly: _showOtpSection,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Comment',
          labelStyle: TextStyle(color: AppColors.textGrey),
          floatingLabelStyle: TextStyle(color: AppColors.primary),
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

  Widget _buildOtpSection({Key? key}) {
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
      ],
    );
  }

  Widget _buildActionButton() {
    return Obx(
      () => ElevatedButton(
        onPressed: _isSubmitting.value ? null : _onActionButtonPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.whiteColor,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child:
            _isSubmitting.value
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ButtonLoadingWidget(size: 18.0, color: AppColors.whiteColor),
                    SizedBox(width: 10.w),
                    Text(
                      _showOtpSection ? 'Submitting...' : 'Sending OTP...',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ],
                )
                : Text(
                  _showOtpSection ? 'Submit OTP' : 'Transfer Now',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor,
                  ),
                ),
      ),
    );
  }

  void _showTransferFromDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Obx(() {
          final accounts = controller.mt5Accounts;
          final wallet = controller.wallet.value;

          // Build list of accounts to show
          final List<Map<String, dynamic>> accountItems = [];

          // Add MT5 accounts
          for (var account in accounts) {
            accountItems.add({
              'type': 'mt5',
              'account': account,
              'identifier': account.metaAccountNumber,
            });
          }

          // Add Wallet option
          if (wallet != null) {
            accountItems.add({
              'type': 'wallet',
              'wallet': wallet,
              'identifier': wallet.walletId,
            });
          }

          // Add IB Account option if available
          if (controller.ibAccount.value != null &&
              controller.ibAccount.value!.status.isNotEmpty) {
            final ibAccountNumber = controller.ibAccount.value!.referenceLinkId;
            if (ibAccountNumber.isNotEmpty) {
              try {
                final ibAccount = accounts.firstWhere(
                  (acc) => acc.metaAccountNumber == ibAccountNumber,
                );
                accountItems.add({
                  'type': 'ib',
                  'account': ibAccount,
                  'identifier': ibAccount.metaAccountNumber,
                });
              } catch (e) {
                // Account not found, skip
              }
            }
          }

          if (accountItems.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  controller.isLoading.value
                      ? languageService.tr('common_loading')
                      : languageService.tr('common_no_accounts'),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            itemCount: accountItems.length,
            separatorBuilder:
                (_, __) => Divider(height: 1, color: Colors.grey.shade300),
            itemBuilder: (context, index) {
              final item = accountItems[index];
              final accountType = item['type'] as String;
              final identifier = item['identifier'] as String? ?? '';

              // Determine if selected
              bool isSelected = _selectedTransferFrom == identifier;

              return InkWell(
                onTap: () {
                  setState(() {
                    if (accountType == 'mt5') {
                      final account = item['account'] as UserMT5Account;
                      _selectedTransferFrom = account.metaAccountNumber;
                      _transferFromController.text =
                          '${account.metaAccountNumber} - \$ ${account.balance}';
                      _selectedTransferFromAccount = account;
                      _selectedTransferFromType = 'mt5';
                      controller.selectedFromAccount.value = account;
                      controller.selectedFromAccountType.value = 'mt5';
                    } else if (accountType == 'wallet') {
                      final wallet = item['wallet'] as Wallet;
                      _selectedTransferFrom = wallet.walletId;
                      _transferFromController.text =
                          '${wallet.walletId} - \$ ${wallet.walletBalance}';
                      _selectedTransferFromAccount = wallet;
                      _selectedTransferFromType = 'wallet';
                      controller.selectedFromAccount.value = null;
                      controller.selectedFromAccountType.value = 'wallet';
                    } else if (accountType == 'ib') {
                      final account = item['account'] as UserMT5Account;
                      _selectedTransferFrom = account.metaAccountNumber;
                      _transferFromController.text =
                          '${account.metaAccountNumber} - \$ ${account.balance}';
                      _selectedTransferFromAccount = account;
                      _selectedTransferFromType = 'ib';
                      controller.selectedFromAccount.value = account;
                      controller.selectedFromAccountType.value = 'ib';
                    }

                    // Reset Transfer To if it was the same account
                    if (_selectedTransferTo == identifier) {
                      _selectedTransferTo = null;
                      _selectedTransferToType = null;
                      _selectedTransferToAccount = null;
                      _transferToController.clear();
                      controller.selectedToAccount.value = null;
                      controller.selectedToAccountType.value = null;
                    }
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? AppColors.primary.withOpacity(0.1) : null,
                  ),
                  child: Row(
                    children: [
                      // Badge for account type
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
                          accountType == 'wallet'
                              ? 'Wallet'
                              : accountType == 'ib'
                              ? FlavorConfig.instance.appName
                              : (item['account'] as UserMT5Account)
                                  .masterGroupId,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Account identifier
                      Expanded(
                        child: Text(
                          accountType == 'wallet'
                              ? (item['wallet'] as Wallet).walletId
                              : (item['account'] as UserMT5Account)
                                  .metaAccountNumber,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                isSelected ? AppColors.primary : Colors.black87,
                          ),
                        ),
                      ),
                      // Balance
                      Text(
                        accountType == 'wallet'
                            ? '\$ ${(item['wallet'] as Wallet).walletBalance}'
                            : '\$ ${(item['account'] as UserMT5Account).balance}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade700,
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
            },
          );
        });
      },
    );
  }

  void _showTransferToDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Obx(() {
          final accounts = controller.mt5Accounts;
          final wallet = controller.wallet.value;

          // Build list of accounts to show (excluding selected From account)
          final List<Map<String, dynamic>> accountItems = [];

          // Add MT5 accounts (exclude if selected as From)
          for (var account in accounts) {
            final accountId = account.metaAccountNumber;
            if (_selectedTransferFrom != accountId) {
              accountItems.add({
                'type': 'mt5',
                'account': account,
                'identifier': account.metaAccountNumber,
              });
            }
          }

          // Add Wallet option (exclude if selected as From)
          if (wallet != null && _selectedTransferFromType != 'wallet') {
            accountItems.add({
              'type': 'wallet',
              'wallet': wallet,
              'identifier': wallet.walletId,
            });
          }

          // Add IB Account option (exclude if selected as From and if exists)
          if (controller.ibAccount.value != null &&
              controller.ibAccount.value!.status.isNotEmpty &&
              _selectedTransferFromType != 'ib') {
            final ibAccountNumber = controller.ibAccount.value!.referenceLinkId;
            if (ibAccountNumber.isNotEmpty &&
                _selectedTransferFrom != ibAccountNumber) {
              try {
                final ibAccount = accounts.firstWhere(
                  (acc) => acc.metaAccountNumber == ibAccountNumber,
                );
                accountItems.add({
                  'type': 'ib',
                  'account': ibAccount,
                  'identifier': ibAccount.metaAccountNumber,
                });
              } catch (e) {
                // Account not found, skip
              }
            }
          }

          if (accountItems.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  controller.isLoading.value
                      ? languageService.tr('common_loading')
                      : languageService.tr('common_no_accounts'),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            itemCount: accountItems.length,
            separatorBuilder:
                (_, __) => Divider(height: 1, color: Colors.grey.shade300),
            itemBuilder: (context, index) {
              final item = accountItems[index];
              final accountType = item['type'] as String;
              final identifier = item['identifier'] as String? ?? '';

              // Determine if selected
              bool isSelected = false;
              if (accountType == 'wallet') {
                isSelected = _selectedTransferTo == identifier;
              } else {
                isSelected = _selectedTransferTo == identifier;
              }

              return InkWell(
                onTap: () {
                  setState(() {
                    if (accountType == 'mt5') {
                      final account = item['account'] as UserMT5Account;
                      _selectedTransferTo = account.metaAccountNumber;
                      _transferToController.text =
                          '${account.metaAccountNumber} - \$ ${account.balance}';
                      _selectedTransferToAccount = account;
                      _selectedTransferToType = 'mt5';
                      controller.selectedToAccount.value = account;
                      controller.selectedToAccountType.value = 'mt5';
                    } else if (accountType == 'wallet') {
                      final wallet = item['wallet'] as Wallet;
                      _selectedTransferTo = wallet.walletId;
                      _transferToController.text =
                          '${wallet.walletId} - \$ ${wallet.walletBalance}';
                      _selectedTransferToAccount = wallet;
                      _selectedTransferToType = 'wallet';
                      controller.selectedToAccount.value = wallet;
                      controller.selectedToAccountType.value = 'wallet';
                    } else if (accountType == 'ib') {
                      final account = item['account'] as UserMT5Account;
                      _selectedTransferTo = account.metaAccountNumber;
                      _transferToController.text =
                          '${account.metaAccountNumber} - \$ ${account.balance}';
                      _selectedTransferToAccount = account;
                      _selectedTransferToType = 'ib';
                      controller.selectedToAccount.value = account;
                      controller.selectedToAccountType.value = 'ib';
                    }
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? AppColors.primary.withOpacity(0.1) : null,
                  ),
                  child: Row(
                    children: [
                      // Badge for account type
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
                          accountType == 'wallet'
                              ? 'Wallet'
                              : accountType == 'ib'
                              ? FlavorConfig.instance.appName
                              : (item['account'] as UserMT5Account)
                                  .masterGroupId,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Account identifier
                      Expanded(
                        child: Text(
                          accountType == 'wallet'
                              ? (item['wallet'] as Wallet).walletId
                              : (item['account'] as UserMT5Account)
                                  .metaAccountNumber,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                isSelected ? AppColors.primary : Colors.black87,
                          ),
                        ),
                      ),
                      // Balance
                      Text(
                        accountType == 'wallet'
                            ? '\$ ${(item['wallet'] as Wallet).walletBalance}'
                            : '\$ ${(item['account'] as UserMT5Account).balance}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade700,
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
            },
          );
        });
      },
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
      style: TextStyle(
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
        } else if (value.length == 1 && index < 5) {
          // Move to next box when a digit is entered
          _previousOtpValues[index] = value;
          _otpFocusNodes[index + 1].requestFocus();
        } else if (value.isEmpty && index > 0) {
          // Move to previous box when backspace clears the current box
          _previousOtpValues[index] = '';
          _otpFocusNodes[index - 1].requestFocus();
        } else if (value.isEmpty && index == 0) {
          // Clear all fields and reset focus to first box if first box is cleared
          for (int i = 0; i < 6; i++) {
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
          maxLength: 6, // Allow paste of full OTP in first field
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: TextStyle(
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
            } else if (value.length == 1 && index < 5) {
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
            maxLength: 1,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: TextStyle(
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

  void _onActionButtonPressed() async {
    if (!_showOtpSection) {
      // Transfer Now button clicked - validate and start flow

      // 1. Validate inputs
      if (_selectedTransferFrom == null || _selectedTransferFrom!.isEmpty) {
        CustomToastService.showError(
          message: languageService.tr('internal_transfer_select_from'),
        );
        return;
      }

      if (_selectedTransferTo == null || _selectedTransferTo!.isEmpty) {
        CustomToastService.showError(
          message: languageService.tr('internal_transfer_select_to'),
        );
        return;
      }

      final rawText = _amountController.text.trim();
      if (rawText.isEmpty || rawText == '0.00') {
        CustomToastService.showError(
          message: languageService.tr('internal_transfer_enter_amount'),
        );
        return;
      }

      // 2. Parse amount (remove $, commas)
      final cleanedText = rawText.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsedAmount = double.tryParse(cleanedText);
      if (parsedAmount == null || parsedAmount <= 0.0) {
        CustomToastService.showError(
          message: languageService.tr('internal_transfer_valid_amount'),
        );
        return;
      }

      // 3. Get account identifier for balance check
      final fromAccountId = _getAccountIdentifier(
        _selectedTransferFromType,
        _selectedTransferFromAccount,
      );

      if (fromAccountId.isEmpty) {
        CustomToastService.showError(
          message: languageService.tr('internal_transfer_invalid_from'),
        );
        return;
      }

      // 4. Check balance
      final isValid = await controller.checkBalance(
        fromAccountId,
        parsedAmount,
      );
      if (!isValid) {
        // Error already shown in checkBalance method
        return;
      }

      // 5. Send OTP
      _isSubmitting.value = true;
      final otpSent = await controller.sendOTP(fromAccountId);
      _isSubmitting.value = false;
      if (otpSent) {
        setState(() {
          _showOtpSection = true;
        });
        // Scroll to OTP section and focus first field after a short delay
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
    } else {
      // Submit OTP
      final otp = _otpControllers.map((controller) => controller.text).join();
      if (otp.length != 6) {
        CustomToastService.showError(
          message: languageService.tr('internal_transfer_enter_otp'),
        );
        return;
      }

      // Validate accounts are still selected
      if (_selectedTransferFrom == null || _selectedTransferTo == null) {
        CustomToastService.showError(
          message: languageService.tr('internal_transfer_select_both'),
        );
        return;
      }

      // Get account identifiers
      final fromAccountId = _getAccountIdentifier(
        _selectedTransferFromType,
        _selectedTransferFromAccount,
      );
      final toAccountId = _getAccountIdentifier(
        _selectedTransferToType,
        _selectedTransferToAccount,
      );

      if (fromAccountId.isEmpty || toAccountId.isEmpty) {
        CustomToastService.showError(
          message: languageService.tr('internal_transfer_invalid_selection'),
        );
        return;
      }

      // Parse amount
      final rawText = _amountController.text.trim();
      final cleanedText = rawText.replaceAll(RegExp(r'[^0-9.]'), '');

      // Get comment
      final comment = _commentController.text.trim();

      // Submit transfer
      _isSubmitting.value = true;
      final success = await controller.submitInternalTransfer(
        otp,
        comment,
        fromAccountId,
        toAccountId,
        cleanedText,
      );

      if (success && mounted) {
        // Keep submitting state true until we navigate away to avoid
        // a brief enabled/disabled flicker on the button during transition.
        // Navigate back to More screen with bottom navigation after successful transfer
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) {
            // Navigate back to main trading screen (which has bottom navigation)
            // This will clear the navigation stack and return to TradingMainScreen
            // The user can then access the More tab from bottom navigation
            Get.offAllNamed(AppPages.TRADING);
          }
        });
      }
      if (!success && mounted) {
        _isSubmitting.value = false;
      }
    }
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
