import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
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
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/models/crm_settings_model.dart';
import 'package:crm_app/services/crm_settings_service.dart';

/// Live result of `withdrawal/checkbalance` for the entered amount.
enum _BalanceStatus { idle, checking, valid, invalid }

/// What a From/To tile or picker row shows for one source/destination.
typedef _AccountView = ({
  String type,
  String number,
  String balance,
  String code,
});

typedef _AccountOption = ({String type, dynamic account});

/// `¢1,234.50` for cent accounts, `$1,234.50` otherwise.
String _money(double value, {required bool cent}) {
  final fixed = value.abs().toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = fixed
      .substring(0, dot)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '${value < 0 ? '-' : ''}${cent ? '¢' : r'$'}$whole${fixed.substring(dot)}';
}

String _currencyCode({required bool cent}) => cent ? 'USC' : 'USD';

class InternalTransferScreen extends StatefulWidget {
  /// When true (opened from the Wallet screen), the wallet is preselected as
  /// the "From" account instead of the first MT5 account.
  final bool preselectWallet;

  const InternalTransferScreen({Key? key, this.preselectWallet = false})
    : super(key: key);

  @override
  State<InternalTransferScreen> createState() => _InternalTransferScreenState();
}

class _InternalTransferScreenState extends State<InternalTransferScreen> {
  static const int _resendCooldownSeconds = 60;

  final WalletController controller = Get.put(WalletController());
  final LanguageService languageService = Get.find<LanguageService>();
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
  String? _selectedTransferFromType; // 'mt5', 'wallet', 'ib', 'ibmwallet'
  String? _selectedTransferTo;
  String? _selectedTransferToType; // 'mt5', 'wallet', 'ib', 'ibmwallet'
  dynamic _selectedTransferFromAccount; // UserMT5Account, Wallet, IbmWallet
  dynamic _selectedTransferToAccount; // UserMT5Account, Wallet, IbmWallet
  // Reactive submitting flag (GetX)
  final RxBool _isSubmitting = false.obs;

  Timer? _balanceDebounce;
  int _balanceRequestId = 0;
  String? _balanceCheckKey;
  _BalanceStatus _balanceStatus = _BalanceStatus.idle;
  String _balanceMessage = '';

  Timer? _resendTimer;
  final ValueNotifier<int> _resendSeconds = ValueNotifier<int>(0);

  // Missing settings (API failed / old backend) fall back to all-false
  // defaults: no OTP step, and IB commission cannot go to Wallet.
  CrmFinancialSettings get _financialSettings {
    if (!Get.isRegistered<CrmSettingsService>()) {
      return const CrmFinancialSettings();
    }
    return Get.find<CrmSettingsService>().current?.financialSettings ??
        const CrmFinancialSettings();
  }

  bool get _otpRequired => _financialSettings.internalTransferOtpRequired;

  bool get _isWalletBlockedForSource =>
      _selectedTransferFromType == 'ib' &&
      !_financialSettings.ibCommissionToWalletTransferEnabled;

  @override
  void initState() {
    super.initState();
    _amountFocusNode = FocusNode();
    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus && _amountController.text == '0.00') {
        _amountController.text = '';
      } else if (!_amountFocusNode.hasFocus && _amountController.text.isEmpty) {
        _amountController.text = '0.00';
      }
    });
    _amountController.addListener(_onAmountChanged);
    // Fetch wallet data when screen loads
    _fetchData();
    // Admin may have toggled transfer switches since app start.
    if (Get.isRegistered<CrmSettingsService>()) {
      Get.find<CrmSettingsService>()
          .fetchCrmSettings(force: true)
          .then((_) {
            if (mounted) setState(() {});
          });
    }
    // fetchWalletData sets Rx values synchronously; the WalletController is
    // shared with the Wallet screen underneath, whose Obx would be marked
    // dirty mid-build. Start the fetch after this frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchData();
    });
  }

  Future<void> _fetchData() async {
    await controller.fetchWalletData();
    if (!mounted) return;

    final wallet = controller.wallet.value;
    if (widget.preselectWallet && wallet != null) {
      if (_selectedTransferFrom == null) _selectFrom('wallet', wallet);
      if (controller.mt5Accounts.isNotEmpty && _selectedTransferTo == null) {
        _selectTo('mt5', controller.mt5Accounts.first);
      }
      return;
    }

    if (controller.mt5Accounts.isNotEmpty && _selectedTransferFrom == null) {
      _selectFrom('mt5', controller.mt5Accounts.first);
    }
    if (wallet != null &&
        _selectedTransferTo == null &&
        _selectedTransferFromType != 'wallet' &&
        !_isWalletBlockedForSource) {
      _selectTo('wallet', wallet);
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
    } else if (accountType == 'ibmwallet' && account is IbmWallet) {
      return account.referenceLinkId;
    }
    return '';
  }

  void _selectFrom(String type, dynamic account) {
    final identifier = _getAccountIdentifier(type, account);
    setState(() {
      _selectedTransferFrom = identifier;
      _selectedTransferFromType = type;
      _selectedTransferFromAccount = account;
      controller.selectedFromAccount.value =
          account is UserMT5Account ? account : null;
      controller.selectedFromAccountType.value = type;

      // Reset Transfer To if it was the same account, or if Wallet is no
      // longer a valid destination for this source.
      if (_selectedTransferTo == identifier ||
          (_selectedTransferToType == 'wallet' && _isWalletBlockedForSource)) {
        _selectedTransferTo = null;
        _selectedTransferToType = null;
        _selectedTransferToAccount = null;
        controller.selectedToAccount.value = null;
        controller.selectedToAccountType.value = null;
      }
    });
    _scheduleBalanceCheck();
  }

  void _selectTo(String type, dynamic account) {
    setState(() {
      _selectedTransferTo = _getAccountIdentifier(type, account);
      _selectedTransferToType = type;
      _selectedTransferToAccount = account;
      controller.selectedToAccount.value = account;
      controller.selectedToAccountType.value = type;
    });
    _scheduleBalanceCheck();
  }

  @override
  void dispose() {
    _balanceDebounce?.cancel();
    _resendTimer?.cancel();
    _resendSeconds.dispose();
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

  double? get _enteredAmount {
    final cleaned = _amountController.text.trim().replaceAll(
      RegExp(r'[^0-9.]'),
      '',
    );
    return double.tryParse(cleaned);
  }

  String get _fromBlockedReason {
    final account = _selectedTransferFromAccount;
    return account is UserMT5Account ? account.transferBlockedReason : '';
  }

  void _onAmountChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleBalanceCheck();
  }

  void _setBalanceStatus(_BalanceStatus status, [String message = '']) {
    if (!mounted) return;
    setState(() {
      _balanceStatus = status;
      _balanceMessage = message;
    });
  }

  /// Asks the server (debounced) whether the From account can send the
  /// entered amount, so the banner and button reflect it before submit.
  void _scheduleBalanceCheck() {
    final fromId = _getAccountIdentifier(
      _selectedTransferFromType,
      _selectedTransferFromAccount,
    );
    final toId = _getAccountIdentifier(
      _selectedTransferToType,
      _selectedTransferToAccount,
    );
    final amount = _enteredAmount;
    // The controller also notifies on cursor moves; skip unchanged input.
    // Any account change (either side, incl. switching to a cent account)
    // must re-check so a previous "sufficient" result never lingers.
    final key = '$_selectedTransferFromType|$fromId|$toId|$amount';
    if (key == _balanceCheckKey) return;
    _balanceCheckKey = key;
    _balanceDebounce?.cancel();
    final requestId = ++_balanceRequestId;

    final blockedReason = _fromBlockedReason;
    if (blockedReason.isNotEmpty) {
      _setBalanceStatus(_BalanceStatus.invalid, blockedReason);
      return;
    }
    if (fromId.isEmpty || amount == null || amount <= 0) {
      _setBalanceStatus(_BalanceStatus.idle);
      return;
    }
    final limit = _getTransferFromLimit();
    if (limit != null && amount > limit) {
      _setBalanceStatus(
        _BalanceStatus.invalid,
        TranslationUtils.trArgs(
          'internal_transfer_screen_maximum_transfer_is',
          {'amount': _money(limit, cent: _fromIsCent)},
        ),
      );
      return;
    }

    _setBalanceStatus(_BalanceStatus.checking);
    _balanceDebounce = Timer(const Duration(milliseconds: 600), () async {
      final result = await controller.validateBalance(fromId, amount);
      if (!mounted || requestId != _balanceRequestId) return;
      _setBalanceStatus(
        result.valid ? _BalanceStatus.valid : _BalanceStatus.invalid,
        result.message,
      );
    });
  }

  // Wallet and IB balances are always USD; only MT5 cent accounts and a USC
  // IBM wallet hold cents.
  bool _isCentSide(String? type, dynamic account) {
    if (type == 'mt5' && account is UserMT5Account) return account.isCentAccount;
    if (type == 'ibmwallet' && account is IbmWallet) {
      return account.currency.toUpperCase() == 'USC';
    }
    return false;
  }

  bool get _fromIsCent =>
      _isCentSide(_selectedTransferFromType, _selectedTransferFromAccount);
  bool get _toIsCent =>
      _isCentSide(_selectedTransferToType, _selectedTransferToAccount);

  _AccountView? _describeAccount(String? type, dynamic account) {
    final cent = _isCentSide(type, account);
    final code = _currencyCode(cent: cent);
    if (type == 'wallet' && account is Wallet) {
      return (
        type: TranslationUtils.tr('wallet_title'),
        number: account.walletId,
        balance: _money(double.tryParse(account.walletBalance) ?? 0, cent: false),
        code: code,
      );
    }
    if (type == 'ibmwallet' && account is IbmWallet) {
      return (
        type: TranslationUtils.tr('withdrawal_screen_ib_wallet'),
        number: account.referenceLinkId,
        balance: _money(double.tryParse(account.balance) ?? 0, cent: cent),
        code: code,
      );
    }
    if (account is UserMT5Account) {
      final group = account.masterGroupId.trim();
      return (
        type: type == 'ib'
            ? FlavorConfig.instance.appName
            : (group.isNotEmpty ? group : 'MT5'),
        number: account.metaAccountNumber,
        balance: _money(double.tryParse(account.balance) ?? 0, cent: cent),
        code: code,
      );
    }
    return null;
  }

  double? _getTransferFromLimit() {
    if (_selectedTransferFromAccount == null) return null;
    if (_selectedTransferFromType == 'wallet') {
      final wallet = _selectedTransferFromAccount as Wallet;
      return double.tryParse(wallet.walletBalance);
    } else if (_selectedTransferFromType == 'mt5') {
      // Cap at the balance shown in the picker. The server's
      // available_for_transfer can be a stale 0 for an account that is not
      // blocked (empty transfer_blocked_reason); withdrawal/checkbalance
      // enforces the real rule before the request is sent.
      final account = _selectedTransferFromAccount as UserMT5Account;
      return double.tryParse(account.balance) ?? account.availableForTransfer;
    } else if (_selectedTransferFromType == 'ib') {
      final account = _selectedTransferFromAccount as UserMT5Account;
      return account.availableForTransfer ?? double.tryParse(account.balance);
    } else if (_selectedTransferFromType == 'ibmwallet') {
      final ibmWallet = _selectedTransferFromAccount as IbmWallet;
      return double.tryParse(ibmWallet.balance);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
        leading: AppBackButton(onPressed: ()=> NavigationHelper.safeBack(context: context),
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
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Obx(_buildFormOrState),
                        if (_showOtpSection) ...[
                          SizedBox(height: 14.h),
                          _buildOtpSection(key: _otpSectionKey),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
                  child: _buildActionButton(),
                ),
              ],
            ),

            // Center overlay loader while submitting (reactive)
            Obx(
              () =>
                  _isSubmitting.value
                      ? Positioned.fill(
                        child: Container(
                          color: Colors.black.withAlpha(38),
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

  Widget _buildFormOrState() {
    final isLoading = controller.isLoading.value;
    final error = controller.walletError.value;
    final hasSources =
        controller.mt5Accounts.isNotEmpty || controller.wallet.value != null;
    if (!hasSources && isLoading) return const _AccountTilesShimmer();
    if (!hasSources && error.isNotEmpty) {
      return _LoadErrorCard(message: error, onRetry: () => _fetchData());
    }
    return _buildTransferFields(hasSources: hasSources);
  }

  Widget _buildTransferFields({required bool hasSources}) {
    final placeholder =
        hasSources
            ? TranslationUtils.tr('internal_transfer_screen_select_account')
            : languageService.tr('common_no_accounts');
    final amount = _enteredAmount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(TranslationUtils.tr('internal_transfer_screen_from_account')),
        _AccountTile(
          view: _describeAccount(
            _selectedTransferFromType,
            _selectedTransferFromAccount,
          ),
          placeholder: placeholder,
          onTap: _showOtpSection ? null : _showTransferFromDropdown,
        ),
        const _FlowConnector(),
        _FieldLabel(TranslationUtils.tr('internal_transfer_screen_to_account')),
        _AccountTile(
          view: _describeAccount(
            _selectedTransferToType,
            _selectedTransferToAccount,
          ),
          placeholder: placeholder,
          onTap: _showOtpSection ? null : _showTransferToDropdown,
        ),
        SizedBox(height: 14.h),
        _FieldLabel(languageService.tr('deposit_amount')),
        _buildAmountField(),
        SizedBox(height: 12.h),
        _FieldLabel(
          TranslationUtils.tr('internal_transfer_screen_description_optional'),
        ),
        _buildCommentField(),
        if (amount > 0) ...[
          SizedBox(height: 14.h),
          _buildSummaryBox(amount),
        ],
        if (_balanceStatus != _BalanceStatus.idle) ...[
          SizedBox(height: 10.h),
          _BalanceStatusBanner(
            status: _balanceStatus,
            message: _balanceMessage,
            detail: _balanceDetail(),
          ),
        ],
        if (_financialSettings.internalTransferApprovalRequired) ...[
          SizedBox(height: 10.h),
          _ApprovalNotice(
            text: TranslationUtils.tr('internal_transfer_screen_approval_notice'),
          ),
        ],
      ],
    );
  }

  /// "2000013 · Available for transfer: ¢467.70" — ties the banner to the
  /// account that was actually checked.
  String? _balanceDetail() {
    final from = _describeAccount(
      _selectedTransferFromType,
      _selectedTransferFromAccount,
    );
    final limit = _getTransferFromLimit();
    if (from == null || limit == null) return null;
    final available = TranslationUtils.trArgs(
      'internal_transfer_screen_available_for_transfer',
      {'amount': _money(limit, cent: _fromIsCent)},
    );
    return '${from.number} · $available';
  }

  /// What leaves the From account and what the To account receives. The
  /// server converts at 100 USC = 1 USD (internaltransfer/history:
  /// amount_source 1000 USC -> amount_destination 10 USD); the request itself
  /// always carries the From-currency amount.
  Widget _buildSummaryBox(double amount) {
    final fromCent = _fromIsCent;
    final toCent = _selectedTransferToAccount != null ? _toIsCent : fromCent;
    final received =
        fromCent == toCent ? amount : (fromCent ? amount / 100 : amount * 100);
    final from = _describeAccount(
      _selectedTransferFromType,
      _selectedTransferFromAccount,
    );
    final to = _describeAccount(
      _selectedTransferToType,
      _selectedTransferToAccount,
    );
    return _TransferSummaryBox(
      label: TranslationUtils.tr('internal_transfer_screen_total_transfer_amount'),
      amountText: '${_money(received, cent: toCent)} ${_currencyCode(cent: toCent)}',
      fromSide: (
        number: from?.number ?? '-',
        type: from?.type ?? '',
        amount: '${_money(amount, cent: fromCent)} ${_currencyCode(cent: fromCent)}',
      ),
      toSide: (
        number: to?.number ?? '-',
        type: to?.type ?? '',
        amount: '${_money(received, cent: toCent)} ${_currencyCode(cent: toCent)}',
      ),
      rateText: fromCent == toCent ? null : '100 USC = 1 USD',
    );
  }

  InputDecoration _fieldDecoration({
    String? hint,
    String? helper,
    String? error,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      helperText: helper,
      helperStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
      errorText: error,
      errorStyle: TextStyle(color: AppColors.error, fontSize: 12.sp),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.5),
    );
  }

  void _fillMax(double limit) {
    final max = (limit * 100).floorToDouble() / 100;
    _amountController.text = max.toStringAsFixed(2);
  }

  Widget _buildAmountField() {
    final limit = _getTransferFromLimit();
    final entered = _enteredAmount;
    final fromCent = _fromIsCent;
    String? error;
    if (limit != null && entered != null && entered > limit) {
      error = TranslationUtils.trArgs(
        'internal_transfer_screen_maximum_transfer_is',
        {'amount': _money(limit, cent: fromCent)},
      );
    }
    final showMax = limit != null && limit > 0 && !_showOtpSection;

    return RTLHelper.rtlTextField(
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 15.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      controller: _amountController,
      focusNode: _amountFocusNode,
      readOnly: _showOtpSection,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        _SingleDecimalTextFormatter(),
      ],
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      suffixIcon: Padding(
        padding: EdgeInsetsDirectional.only(end: 8.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMax)
              TextButton(
                onPressed: () => _fillMax(limit),
                style: TextButton.styleFrom(
                  minimumSize: Size(40.w, 32.h),
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  TranslationUtils.tr('internal_transfer_screen_max'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            _CurrencyChip(code: _currencyCode(cent: fromCent)),
          ],
        ),
      ),
      decoration: _fieldDecoration(
        helper:
            limit != null
                ? TranslationUtils.trArgs(
                  'internal_transfer_screen_available_for_transfer',
                  {'amount': _money(limit, cent: fromCent)},
                )
                : null,
        error: error,
      ),
    );
  }

  Widget _buildCommentField() {
    return RTLHelper.rtlTextField(
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      controller: _commentController,
      readOnly: _showOtpSection,
      maxLines: 1,
      decoration: _fieldDecoration(hint: languageService.tr('internal_transfer')),
    );
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendSeconds.value = _resendCooldownSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds.value <= 1) timer.cancel();
      _resendSeconds.value = _resendSeconds.value > 0 ? _resendSeconds.value - 1 : 0;
    });
  }

  Future<void> _resendOtp() async {
    final fromId = _getAccountIdentifier(
      _selectedTransferFromType,
      _selectedTransferFromAccount,
    );
    if (fromId.isEmpty) return;
    final sent = await controller.sendOTP(fromId);
    if (!sent || !mounted) return;
    _startResendCountdown();
    setState(() {}); // OTP channel may have changed
  }

  /// Leaves the OTP step so the user can change accounts or amount.
  void _editDetails() {
    _resendTimer?.cancel();
    _resendSeconds.value = 0;
    for (var i = 0; i < _otpControllers.length; i++) {
      _otpControllers[i].clear();
      _previousOtpValues[i] = '';
    }
    controller.isOtpSent.value = false;
    setState(() => _showOtpSection = false);
  }

  Widget _buildOtpSection({Key? key}) {
    final channel = controller.otpChannel.value.trim();
    return Container(
      key: key,
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
      decoration: BoxDecoration(
        color: AppColors.textFieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  languageService.tr('wallet_enter_otp'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isSubmitting.value ? null : _editDetails,
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  TranslationUtils.tr('internal_transfer_screen_edit_details'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (channel.isNotEmpty)
            Text(
              TranslationUtils.trArgs(
                'internal_transfer_screen_otp_sent_via',
                {'channel': channel},
              ),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 44.w,
                height: 50.h,
                child:
                    Platform.isAndroid
                        ? _buildOtpBoxAndroid(index)
                        : _buildOtpBox(index),
              );
            }),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ValueListenableBuilder<int>(
              valueListenable: _resendSeconds,
              builder: (context, seconds, _) {
                if (seconds > 0) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      TranslationUtils.trArgs(
                        'internal_transfer_screen_resend_otp_in',
                        {'seconds': '$seconds'},
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return TextButton(
                  onPressed: _resendOtp,
                  child: Text(
                    TranslationUtils.tr('internal_transfer_screen_resend_otp'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Both accounts chosen, amount within the limit and the server's balance
  /// check passed. In the OTP step only the OTP itself is left to validate.
  bool get _canProceed {
    if (_showOtpSection) return true;
    final amount = _enteredAmount;
    final limit = _getTransferFromLimit();
    return _selectedTransferFrom != null &&
        _selectedTransferTo != null &&
        amount != null &&
        amount > 0 &&
        (limit == null || amount <= limit) &&
        _balanceStatus == _BalanceStatus.valid;
  }

  Widget _buildActionButton() {
    final String label;
    final String busyLabel;
    if (_showOtpSection) {
      label = TranslationUtils.tr('internal_transfer_screen_verify_and_transfer');
      busyLabel = TranslationUtils.tr('internal_transfer_screen_submitting');
    } else if (_otpRequired) {
      label = TranslationUtils.tr('internal_transfer_screen_send_otp');
      busyLabel = TranslationUtils.tr('internal_transfer_screen_sending_otp');
    } else {
      label = languageService.tr('internal_transfer');
      busyLabel = TranslationUtils.tr('internal_transfer_screen_submitting');
    }
    final canProceed = _canProceed;
    final textStyle = AppTextStyles.bodyText.copyWith(
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.pureWhite,
    );

    return Obx(() {
      final busy = _isSubmitting.value;
      return SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton(
          onPressed: busy || !canProceed ? null : _onActionButtonPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.pureWhite,
            disabledBackgroundColor: AppColors.primary.withAlpha(110),
            disabledForegroundColor: AppColors.pureWhite,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child:
              busy
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ButtonLoadingWidget(size: 18.0, color: AppColors.pureWhite),
                      SizedBox(width: 10.w),
                      Text(busyLabel, style: textStyle),
                    ],
                  )
                  : Text(label, style: textStyle),
        ),
      );
    });
  }

  UserMT5Account? _ibAccountOption() {
    final ib = controller.ibAccount.value;
    if (ib == null || ib.status.isEmpty || ib.referenceLinkId.isEmpty) {
      return null;
    }
    return controller.mt5Accounts.firstWhereOrNull(
      (acc) => acc.metaAccountNumber == ib.referenceLinkId,
    );
  }

  List<_AccountOption> _fromOptions() {
    final wallet = controller.wallet.value;
    final ib = _ibAccountOption();
    final ibmWallet = controller.ibmWallet.value;
    return [
      for (final account in controller.mt5Accounts)
        (type: 'mt5', account: account),
      if (wallet != null) (type: 'wallet', account: wallet),
      if (ib != null) (type: 'ib', account: ib),
      if (ibmWallet != null) (type: 'ibmwallet', account: ibmWallet),
    ];
  }

  List<_AccountOption> _toOptions() {
    final wallet = controller.wallet.value;
    final ib = _ibAccountOption();
    final ibmWallet = controller.ibmWallet.value;
    return [
      for (final account in controller.mt5Accounts)
        if (account.metaAccountNumber != _selectedTransferFrom)
          (type: 'mt5', account: account),
      // Wallet is hidden when it is the source, or when IB commission is not
      // allowed to go to Wallet.
      if (wallet != null &&
          _selectedTransferFromType != 'wallet' &&
          !_isWalletBlockedForSource)
        (type: 'wallet', account: wallet),
      if (ib != null &&
          _selectedTransferFromType != 'ib' &&
          _selectedTransferFrom != ib.metaAccountNumber)
        (type: 'ib', account: ib),
      if (ibmWallet != null && _selectedTransferFromType != 'ibmwallet')
        (type: 'ibmwallet', account: ibmWallet),
    ];
  }

  void _showTransferFromDropdown() => _showAccountPicker(
    title: TranslationUtils.tr('internal_transfer_screen_from_account'),
    options: _fromOptions,
    selectedId: _selectedTransferFrom,
    onSelect: _selectFrom,
  );

  void _showTransferToDropdown() => _showAccountPicker(
    title: TranslationUtils.tr('internal_transfer_screen_to_account'),
    options: _toOptions,
    selectedId: _selectedTransferTo,
    onSelect: _selectTo,
  );

  void _showAccountPicker({
    required String title,
    required List<_AccountOption> Function() options,
    required String? selectedId,
    required void Function(String type, dynamic account) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Obx(() {
            final items = options();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(16.w, 6.h, 4.w, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: languageService.tr('common_close'),
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.divider),
                if (items.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Text(
                      controller.isLoading.value
                          ? languageService.tr('common_loading')
                          : languageService.tr('common_no_accounts'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder:
                          (_, __) => Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final view = _describeAccount(item.type, item.account);
                        if (view == null) return const SizedBox.shrink();
                        return _PickerRow(
                          view: view,
                          isSelected:
                              _getAccountIdentifier(item.type, item.account) ==
                              selectedId,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            onSelect(item.type, item.account);
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          }),
        );
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

      final limit = _getTransferFromLimit();
      if (limit != null && parsedAmount > limit) {
        CustomToastService.showError(
          message: TranslationUtils.trArgs(
            'internal_transfer_screen_amount_cannot_exceed_limit',
            {'amount': _money(limit, cent: _fromIsCent)},
          ),
        );
        return;
      }

      if (_selectedTransferFromAccount is UserMT5Account) {
        final blockedReason =
            (_selectedTransferFromAccount as UserMT5Account)
                .transferBlockedReason;
        if (blockedReason.isNotEmpty) {
          CustomToastService.showError(message: blockedReason);
          return;
        }
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

      // 4. Set submitting to true BEFORE checking balance to disable the button instantly
      _isSubmitting.value = true;

      // Check balance
      final isValid = await controller.checkBalance(
        fromAccountId,
        parsedAmount,
      );
      if (!isValid) {
        // Error already shown in checkBalance method
        _isSubmitting.value = false;
        return;
      }

      if (!_financialSettings.internalTransferOtpRequired) {
        await _submitTransfer(otp: null);
        return;
      }

      // 5. Send OTP
      final otpSent = await controller.sendOTP(fromAccountId);
      _isSubmitting.value = false;
      if (otpSent) {
        _startResendCountdown();
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

      await _submitTransfer(otp: otp);
    }
  }

  Future<void> _submitTransfer({required String? otp}) async {
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
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          // Return to TradingMainScreen (has bottom navigation)
          Get.offAllNamed(AppPages.TRADING);
        }
      });
    }
    if (!success && mounted) {
      _isSubmitting.value = false;
    }
  }
}

/// Formatter that keeps digits and a single decimal point.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        text,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;

  const _TypeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 110.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String code;

  const _CurrencyChip({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        code,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Tappable From/To card: type chip, account number, balance and currency.
class _AccountTile extends StatelessWidget {
  final _AccountView? view;
  final String placeholder;
  final VoidCallback? onTap;

  const _AccountTile({
    required this.view,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final account = view;
    return Material(
      color: AppColors.textFieldBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(minHeight: 52.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              if (account == null)
                Expanded(
                  child: Text(
                    placeholder,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      color: AppColors.hint,
                    ),
                  ),
                )
              else ...[
                _TypeChip(label: account.type),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    account.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      account.balance,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      account.code,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (onTap != null) ...[
                SizedBox(width: 4.w),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20.sp,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final _AccountView view;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerRow({
    required this.view,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final emphasis = isSelected ? AppColors.primary : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? AppColors.primary.withAlpha(20) : null,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            _TypeChip(label: view.type),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                view.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: emphasis,
                ),
              ),
            ),
            Text(
              '${view.balance} ${view.code}',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              width: 18.sp,
              child:
                  isSelected
                      ? Icon(Icons.check, color: AppColors.primary, size: 18.sp)
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Divider between the From and To tiles with a softly moving arrow badge,
/// so the direction of the transfer reads at a glance.
class _FlowConnector extends StatefulWidget {
  const _FlowConnector();

  @override
  State<_FlowConnector> createState() => _FlowConnectorState();
}

class _FlowConnectorState extends State<_FlowConnector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, -0.12),
    end: const Offset(0, 0.12),
  ).animate(CurvedAnimation(parent: _motion, curve: Curves.easeInOut));

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: AppColors.border),
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          line,
          Container(
            width: 30.r,
            height: 30.r,
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withAlpha(25),
              border: Border.all(color: AppColors.primary.withAlpha(90)),
            ),
            child: RepaintBoundary(
              child: SlideTransition(
                position: _offset,
                child: Icon(
                  Icons.south_rounded,
                  size: 16.r,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

typedef _SummarySide = ({String number, String type, String amount});

/// "Total Transfer Amount" with a From → To strip underneath: each side shows
/// its account number, type and the amount in that account's currency.
class _TransferSummaryBox extends StatelessWidget {
  final String label;
  final String amountText;
  final _SummarySide fromSide;
  final _SummarySide toSide;
  final String? rateText;

  const _TransferSummaryBox({
    required this.label,
    required this.amountText,
    required this.fromSide,
    required this.toSide,
    required this.rateText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                amountText,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(height: 1, color: AppColors.primary.withAlpha(40)),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _SummarySideView(
                  side: fromSide,
                  amountTint: AppColors.error,
                  alignEnd: false,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Container(
                  width: 26.r,
                  height: 26.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withAlpha(30),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 15.r,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Expanded(
                child: _SummarySideView(
                  side: toSide,
                  amountTint: AppColors.success,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (rateText != null) ...[
            SizedBox(height: 6.h),
            Text(
              rateText!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummarySideView extends StatelessWidget {
  final _SummarySide side;
  final Color amountTint;
  final bool alignEnd;

  const _SummarySideView({
    required this.side,
    required this.amountTint,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = alignEnd ? TextAlign.end : TextAlign.start;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          side.number,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (side.type.isNotEmpty)
          Text(
            side.type,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 11.sp,
              color: AppColors.textSecondary,
            ),
          ),
        SizedBox(height: 2.h),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            side.amount,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: amountTint,
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceStatusBanner extends StatelessWidget {
  final _BalanceStatus status;
  final String message;
  /// Which account was checked and how much it can send.
  final String? detail;

  const _BalanceStatusBanner({
    required this.status,
    required this.message,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final Color tint;
    final String title;
    String? subtitle;
    switch (status) {
      case _BalanceStatus.checking:
        tint = AppColors.textSecondary;
        title = TranslationUtils.tr('internal_transfer_screen_checking_balance');
        subtitle = detail;
      case _BalanceStatus.valid:
        tint = AppColors.success;
        title = TranslationUtils.tr('internal_transfer_screen_balance_sufficient');
        subtitle = detail ??
            TranslationUtils.tr('internal_transfer_screen_ready_to_proceed');
      case _BalanceStatus.invalid:
        tint = AppColors.error;
        title = message.isNotEmpty
            ? message
            : TranslationUtils.tr(
              'wallet_controller_insufficient_balance_for_this_transfer',
            );
        subtitle = detail;
      case _BalanceStatus.idle:
        return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: tint.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18.sp,
            height: 18.sp,
            child:
                status == _BalanceStatus.checking
                    ? Padding(
                      padding: EdgeInsets.all(2.sp),
                      child: CircularProgressIndicator(strokeWidth: 2, color: tint),
                    )
                    : Icon(
                      status == _BalanceStatus.valid
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 18.sp,
                      color: tint,
                    ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: status == _BalanceStatus.checking
                        ? AppColors.textSecondary
                        : tint,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalNotice extends StatelessWidget {
  final String text;

  const _ApprovalNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16.sp,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountTilesShimmer extends StatelessWidget {
  const _AccountTilesShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    Widget block(double height) => Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
      ),
    );
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          block(52.h),
          SizedBox(height: 26.h),
          block(52.h),
          SizedBox(height: 20.h),
          block(48.h),
          SizedBox(height: 16.h),
          block(48.h),
        ],
      ),
    );
  }
}

class _LoadErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(60)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28.sp),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              minimumSize: Size(96.w, 40.h),
            ),
            child: Text(TranslationUtils.tr('common_retry')),
          ),
        ],
      ),
    );
  }
}

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
