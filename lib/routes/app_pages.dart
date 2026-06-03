import 'package:get/get.dart';
import 'package:crm_app/bindings/more_bindings.dart';
import 'package:crm_app/screens/kyc/presentation/pages/kyc_bank_screen.dart';
import 'package:crm_app/screens/kyc/presentation/pages/bank_list_screen.dart';
import 'package:crm_app/screens/bonus/presentation/pages/bonus_screen.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/hub/copy_trading_hub_screen.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/copy_trading_main_screen.dart';
import 'package:crm_app/screens/copy_trading/presentation/pages/trader_details_screen.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/demo_contest_screen.dart';
import 'package:crm_app/screens/finance/presentation/finance_ui_scope.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_dashboard_screen.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_main_screen.dart';
import 'package:crm_app/brands/brand_scope.dart';
import 'package:crm_app/screens/home/more/setting/setting_screen.dart';
import 'package:crm_app/screens/home/more/support/support_screen.dart';
import 'package:crm_app/screens/home/more/tools_education/tools_education_screen.dart';
import 'package:crm_app/screens/home/more/partnership_program_screen.dart';
import 'package:crm_app/screens/home/open_account_screen.dart';
import 'package:crm_app/screens/home/choose_account_screen.dart';
import 'package:crm_app/screens/home/create_crm_app_account_screen.dart';
import 'package:crm_app/screens/home/chart_screen.dart';
import '../bindings/deposit_binding.dart';
import '../bindings/payment_method_binding.dart';
import '../screens/auth/presentation/pages/legal_documents_screen.dart';
import '../screens/auth/presentation/pages/privacy_policy_screen.dart';
import '../screens/auth/presentation/pages/account_created_screen.dart';
import '../screens/home/change_password_screen.dart';
import '../screens/home/more/chat_with_us_screen.dart';
import '../screens/home/more/edit_profile_screen.dart';
import '../screens/home/more/kyc_verification_screen.dart';
import '../screens/kyc/presentation/pages/kyc_details_screen.dart';
import '../screens/kyc/presentation/pages/kyc_docs_screen.dart';
import '../screens/kyc/presentation/pages/kyc_success_screen.dart';
import '../screens/home/order_confirmation_screen.dart';
import '../screens/settings/presentation/pages/language_selector_screen.dart';
import '../screens/settings/presentation/pages/account_management_screen.dart';
import '../screens/brand_test_screen.dart';
import '../core/routing/feature_unavailable_screen.dart';
import '../core/feature_flags/feature_flag_middleware.dart';
import '../core/feature_flags/feature_keys.dart';
import '../screens/copy_trading/presentation/pages/settings/wallet_screen.dart';
import '../screens/copy_trading/presentation/pages/finance/deposit_screen.dart';
import '../screens/copy_trading/presentation/pages/finance/payment_methods_screen.dart';
import '../screens/copy_trading/presentation/pages/settings/invite_friend_screen.dart';
import '../screens/copy_trading/presentation/pages/finance/internal_transfer_screen.dart';
import '../bindings/splash_binding.dart';
// PMAM screens
import '../screens/pmam/presentation/pages/pmam_main_screen.dart';
import '../screens/pmam/presentation/pages/pmam_become_manager_screen.dart';
import '../screens/pmam/presentation/pages/pmam_manager_dashboard_screen.dart';
import '../screens/pmam/presentation/pages/pmam_manager_portal_screen.dart';
import '../screens/pmam/presentation/pages/pmam_create_plan_screen.dart';
import '../screens/pmam/presentation/pages/pmam_investor_portal_screen.dart';
import '../screens/pmam/presentation/pages/pmam_manager_detail_screen.dart';
import '../screens/pmam/presentation/pages/pmam_manager_plan_detail_screen.dart';
import '../screens/finance/presentation/pages/cregis_address_screen.dart';
import '../screens/finance/presentation/pages/cregis_success_screen.dart';
import '../screens/common/webview_screen.dart';
import '../bindings/auth_binding.dart';
import '../screens/auth/presentation/pages/google_login_otp_screen.dart';
import '../screens/home/more/two_factor_auth_screen.dart';
import '../screens/finance/presentation/pages/internal_transfer_history_screen.dart';
import '../screens/trade_win/trade_win_main_screen.dart';
import '../screens/trade_win/trade_win_product_detail_screen.dart';
import '../screens/trade_win/trade_win_redeem_screen.dart';
import '../screens/trade_win/trade_win_redemption_success_screen.dart';
import '../screens/trade_win/trade_win_past_win_detail_screen.dart';
import '../bindings/account_binding.dart';
import '../bindings/trading_binding.dart';
import '../screens/pmam/feature_di/pmam_binding.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const SPLASH = _Paths.SPLASH;
  static const GET_STARTED = _Paths.GET_STARTED;
  static const LOGIN = _Paths.LOGIN;
  static const CREATE_ACCOUNT = _Paths.CREATE_ACCOUNT;
  static const LEGAL_DOCUMENTS = _Paths.LEGAL_DOCUMENTS;
  static const PRIVACY_POLICY = _Paths.PRIVACY_POLICY;
  static const ACCOUNT_CREATED = _Paths.ACCOUNT_CREATED;
  static const FORGOT_PASSWORD = _Paths.FORGOT_PASSWORD;
  static const VERIFY_CODE = _Paths.VERIFY_CODE;
  static const CREATE_NEW_PASSWORD = _Paths.CREATE_NEW_PASSWORD;
  static const TRADING = _Paths.TRADING;
  static const TOAST_DEMO = _Paths.TOAST_DEMO;
  static const LANGUAGE_SELECTOR = _Paths.LANGUAGE_SELECTOR;
  static const ACCOUNT_MANAGEMENT = _Paths.ACCOUNT_MANAGEMENT;
  static const EDIT_PROFILE = _Paths.EDIT_PROFILE;
  static const WITHDRAWAL = _Paths.WITHDRAWAL;
  static const DEPOSIT = _Paths.DEPOSIT;
  static const WALLET = _Paths.WALLET;
  static const TRANSACTION_HISTORY = _Paths.TRANSACTION_HISTORY;
  static const KYC_VERIFICATION = _Paths.KYC_VERIFICATION;
  static const KYC_INTRO = _Paths.KYC_INTRO;
  static const KYC_DETAILS = _Paths.KYC_DETAILS;
  static const KYC_DOCS = _Paths.KYC_DOCS;
  static const KYC_SUCCESS = _Paths.KYC_SUCCESS;
  static const CHAT_WITH_US = _Paths.CHAT_WITH_US;
  static const CHOOSE_ACCOUNT = _Paths.CHOOSE_ACCOUNT;
  static const CREATE_APP_ACCOUNT = _Paths.CREATE_APP_ACCOUNT;
  static const CHART = _Paths.CHART;
  static const FINANCE = _Paths.FINANCE;
  static const INTERNAL_TRANSFER = _Paths.INTERNAL_TRANSFER;
  static const INTERNAL_TRANSFER_HISTORY = _Paths.INTERNAL_TRANSFER_HISTORY;
  static const GOOGLE_LOGIN_OTP = _Paths.GOOGLE_LOGIN_OTP;
  static const TWO_FACTOR_AUTH = _Paths.TWO_FACTOR_AUTH;
  static const TRADE_WIN_MAIN = _Paths.TRADE_WIN_MAIN;
  static const TRADE_WIN_PRODUCT_DETAIL = _Paths.TRADE_WIN_PRODUCT_DETAIL;
  static const TRADE_WIN_REDEEM = _Paths.TRADE_WIN_REDEEM;
  static const TRADE_WIN_REDEMPTION_SUCCESS = _Paths.TRADE_WIN_REDEMPTION_SUCCESS;
  static const TRADE_WIN_PAST_WIN_DETAIL = _Paths.TRADE_WIN_PAST_WIN_DETAIL;
  static const IB_DASHBOARD = _Paths.IB_DASHBOARD;
  static const IB_MAIN = _Paths.IB_MAIN;
  static const COPY_TRADING_MAIN = _Paths.COPY_TRADING_MAIN;
  static const COPY_TRADING_HUB = _Paths.COPY_TRADING_HUB;
  static const TRADER_DETAILS = _Paths.TRADER_DETAILS;
  static const BONUS = _Paths.BONUS;
  static const DEMO_CONTEST = _Paths.DEMO_CONTEST;
  static const SETTING = _Paths.SETTING;
  static const SUPPORT = _Paths.SUPPORT;
  static const TOOLS_EDUCATION = _Paths.TOOLS_EDUCATION;
  static const MORE = _Paths.MORE;
  static const PARTNERSHIP_PROGRAM = _Paths.PARTNERSHIP_PROGRAM;
  static const BRAND_TEST = _Paths.BRAND_TEST;
  static const KYC_BANK = _Paths.KYC_BANK;
  static const PAYMENT_METHOD = _Paths.PAYMENT_METHOD;
  static const DEPOSIT_INSTRUCTION_SCREEN = _Paths.DEPOSIT_INSTRUCTION_SCREEN;
  static const BANK_LIST = _Paths.BANK_LIST;
  static const CHANGE_PASSWORD = _Paths.CHANGE_PASSWORD;
  static const COPY_TRADING_WALLET = _Paths.COPY_TRADING_WALLET;
  static const COPY_TRADING_DEPOSIT = _Paths.COPY_TRADING_DEPOSIT;
  static const COPY_TRADING_PAYMENT_METHODS =
      _Paths.COPY_TRADING_PAYMENT_METHODS;
  static const COPY_TRADING_INVITE_FRIEND = _Paths.COPY_TRADING_INVITE_FRIEND;
  static const COPY_TRADING_INTERNAL_TRANSFER =
      _Paths.COPY_TRADING_INTERNAL_TRANSFER;

  static const FEATURE_UNAVAILABLE = _Paths.FEATURE_UNAVAILABLE;

  // ── PMAM ──
  static const PMAM_MAIN = _Paths.PMAM_MAIN;
  static const PMAM_BECOME_MANAGER = _Paths.PMAM_BECOME_MANAGER;
  static const PMAM_MANAGER_DASHBOARD = _Paths.PMAM_MANAGER_DASHBOARD;
  static const PMAM_MANAGER_PORTAL = _Paths.PMAM_MANAGER_PORTAL;
  static const PMAM_CREATE_PLAN = _Paths.PMAM_CREATE_PLAN;
  static const PMAM_INVESTOR_PORTAL = _Paths.PMAM_INVESTOR_PORTAL;
  static const PMAM_MANAGER_DETAIL = _Paths.PMAM_MANAGER_DETAIL;
  static const PMAM_MANAGER_PLAN_DETAIL = _Paths.PMAM_MANAGER_PLAN_DETAIL;
  static const CREGIS_ADDRESS = _Paths.CREGIS_ADDRESS;
  static const CREGIS_SUCCESS = _Paths.CREGIS_SUCCESS;

  static final routes = [
    GetPage(
      name: _Paths.SPLASH,
      page: () => BrandScope.widgets.splash(),
      binding: SplashBinding(),
    ),
    GetPage(name: _Paths.GET_STARTED, page: () => BrandScope.widgets.getStarted()),
    // GetPage(
    //   name: _Paths.DEPOSIT_INSTRUCTION_SCREEN,
    //   page: () {
    //     return DepositInstructionScreen(object: object, amountString: amountString);
    //   },
    // ),
    GetPage(name: _Paths.KYC_BANK, page: () => KycBankScreen()),
    GetPage(name: _Paths.CHANGE_PASSWORD, page: () => ChangePasswordScreen()),
    GetPage(
      name: _Paths.PAYMENT_METHOD,
      page: () => FinanceUiScope.widgets.paymentMethods(
        accountNumber: (Get.arguments ?? '').toString(),
      ),
      binding: PaymentMethodBinding(),
    ),
    GetPage(name: _Paths.BANK_LIST, page: () => BankListScreen()),
    GetPage(
      name: _Paths.LOGIN,
      page: () => BrandScope.widgets.login(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.CREATE_ACCOUNT,
      page: () => BrandScope.widgets.createAccount(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.LEGAL_DOCUMENTS,
      page: () {
        final args = Get.arguments;
        final data =
            args is Map<String, dynamic>
                ? args
                : <String, dynamic>{};
        return LegalDocumentsScreen(registrationData: data);
      },
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.PRIVACY_POLICY,
      page: () => const PrivacyPolicyScreen(),
    ),
    GetPage(name: _Paths.ACCOUNT_CREATED, page: () => AccountCreatedScreen()),
    GetPage(
      name: _Paths.FORGOT_PASSWORD,
      page: () => BrandScope.widgets.forgotPassword(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.VERIFY_CODE,
      page: () => BrandScope.widgets.verifyCode(email: Get.arguments ?? ''),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.CREATE_NEW_PASSWORD,
      page: () => BrandScope.widgets.createNewPassword(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.GOOGLE_LOGIN_OTP,
      page: () => const GoogleLoginOtpScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.TRADING,
      page: () => BrandScope.widgets.tradingMain(),
      binding: TradingBinding(),
    ),
    GetPage(
      name: _Paths.LANGUAGE_SELECTOR,
      page: () => const LanguageSelectorScreen(),
    ),
    GetPage(
      name: _Paths.ACCOUNT_MANAGEMENT,
      page: () => const AccountManagementScreen(),
      binding: AccountBinding(),
    ),
    GetPage(name: _Paths.EDIT_PROFILE, page: () => EditProfile()),
    GetPage(name: _Paths.WITHDRAWAL, page: () => FinanceUiScope.widgets.withdrawal()),
    GetPage(
      name: _Paths.DEPOSIT,
      page: () => FinanceUiScope.widgets.deposit(
        accountNumber: (Get.arguments ?? '').toString(),
      ),
      binding: DepositBinding(),
    ),
    GetPage(name: _Paths.WALLET, page: () => FinanceUiScope.widgets.wallet()),
    GetPage(
      name: _Paths.TRANSACTION_HISTORY,
      page: () => FinanceUiScope.widgets.transactionHistory(),
    ),
    GetPage(
      name: _Paths.KYC_VERIFICATION,
      page: () => const KycVerificationScreen(),
    ),
    GetPage(
      name: _Paths.KYC_INTRO,
      page: () => BrandScope.widgets.kycIntro(),
    ),
    GetPage(name: _Paths.KYC_DETAILS, page: () => const KycDetailsScreen()),
    GetPage(name: _Paths.KYC_DOCS, page: () => const KycDocsScreen()),
    GetPage(name: _Paths.KYC_SUCCESS, page: () => const KycSuccessScreen()),
    GetPage(name: _Paths.CHAT_WITH_US, page: () => ChatWithUsScreen()),
    GetPage(name: _Paths.OPEN_ACCOUNT, page: () => const OpenAccountScreen()),

    GetPage(
      name: _Paths.CHOOSE_ACCOUNT,
      page: () {
        final arguments = Get.arguments as Map<String, dynamic>?;
        final isDemo = arguments?['isDemo'] as bool?;
        return ChooseAccountScreen(isDemo: isDemo);
      },
    ),
    GetPage(
      name: _Paths.CREATE_APP_ACCOUNT,
      page:
          () => CreateCrmAppAccountScreen(
            accountType: Get.arguments ?? 'demo',
            isDemo: false,
          ),
    ),
    GetPage(
      name: _Paths.INTERNAL_TRANSFER,
      page: () => FinanceUiScope.widgets.internalTransfer(),
    ),
    GetPage(name: _Paths.CHART, page: () => const ChartScreen()),
    GetPage(name: _Paths.FINANCE, page: () => BrandScope.widgets.finance()),
    GetPage(name: _Paths.IB_DASHBOARD, page: () => const IbDashboardScreen()),
    GetPage(name: _Paths.IB_MAIN, page: () => const IbMainScreen()),
    GetPage(
      name: _Paths.COPY_TRADING_MAIN,
      page: () => const CopyTradingMainScreen(),
    ),
    GetPage(
      name: _Paths.COPY_TRADING_HUB,
      page: () => const CopyTradingHubScreen(),
    ),
    GetPage(
      name: _Paths.TRADER_DETAILS,
      page: () => const TraderDetailsScreen(),
    ),
    GetPage(name: _Paths.BONUS, page: () => const BonusScreen()),
    GetPage(name: _Paths.DEMO_CONTEST, page: () => const DemoContestScreen()),
    GetPage(name: _Paths.SETTING, page: () => const SettingScreen()),
    GetPage(name: _Paths.SUPPORT, page: () => const SupportScreen()),
    GetPage(
      name: _Paths.TOOLS_EDUCATION,
      page: () => const ToolsEducationScreen(),
    ),
    GetPage(
      name: _Paths.MORE,
      page: () => BrandScope.widgets.more(),
      binding: MoreBinding(),
    ),
    GetPage(
      name: _Paths.FEATURE_UNAVAILABLE,
      page: () => const FeatureUnavailableScreen(),
    ),
    GetPage(
      name: _Paths.PARTNERSHIP_PROGRAM,
      page: () => const PartnershipProgramScreen(),
    ),
    GetPage(name: _Paths.BRAND_TEST, page: () => const BrandTestScreen()),
    GetPage(
      name: _Paths.ORDER_CONFIRMATION,
      page: () {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        return OrderConfirmationScreen(
          orderData: args['orderData'] ?? {},
          symbol: args['symbol'] ?? '',
          orderType: args['orderType'] ?? '',
          volume: args['volume'] ?? 0.0,
          price: args['price'],
          executionPrice: args['executionPrice'],
          isPlacing: args['isPlacing'] ?? false,
          positionId: args['positionId'],
          orderId: args['orderId'],
          tabIndex: args['tabIndex'] ?? 0, // Default to Market tab (0)
          onNavigateToTrade: args['onNavigateToTrade'],
        );
      },
    ),
    GetPage(
      name: _Paths.COPY_TRADING_WALLET,
      page: () => const CopyTradingWalletScreen(),
    ),
    GetPage(
      name: _Paths.COPY_TRADING_DEPOSIT,
      page: () => const CopyTradingDepositScreen(),
    ),
    GetPage(
      name: _Paths.COPY_TRADING_PAYMENT_METHODS,
      page: () => const CopyTradingPaymentMethodsScreen(),
    ),
    GetPage(
      name: _Paths.COPY_TRADING_INVITE_FRIEND,
      page: () => const CopyTradingInviteFriendScreen(),
    ),
    GetPage(
      name: _Paths.COPY_TRADING_INTERNAL_TRANSFER,
      page: () => const CopyTradingInternalTransferScreen(),
    ),
    // ── PMAM ──
    GetPage(
      name: _Paths.PMAM_MAIN,
      page: () => const PmamMainScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_BECOME_MANAGER,
      page: () => const PmamBecomeManagerScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_DASHBOARD,
      page: () => const PmamManagerDashboardScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_PORTAL,
      page: () => const PmamManagerPortalScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_CREATE_PLAN,
      page: () => const PmamCreatePlanScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_INVESTOR_PORTAL,
      page: () => const PmamInvestorPortalScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_DETAIL,
      page: () => const PmamManagerDetailScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_PLAN_DETAIL,
      page: () => const PmamManagerPlanDetailScreen(),
      binding: PmamBinding(),
      middlewares: [FeatureFlagMiddleware(FeatureKeys.pmam)],
    ),
    GetPage(
      name: _Paths.CREGIS_CHECKOUT,
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        return WebViewScreen(
          url: args?['checkoutUrl'] ?? '',
          title: args?['title'] ?? 'Cregis Payment',
        );
      },
    ),
    GetPage(
      name: _Paths.CREGIS_ADDRESS,
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        return CregisAddressScreen(
          cregisAddress: args?['cregisAddress'] ?? '',
          referenceNumber: args?['referenceNumber'] ?? '',
          amount: args?['amount'] ?? '',
          networkKey: args?['networkKey'] ?? '',
        );
      },
    ),
    GetPage(
      name: _Paths.CREGIS_SUCCESS,
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        return CregisSuccessScreen(
          checkoutUrl: args?['checkoutUrl'] ?? '',
          referenceNumber: args?['referenceNumber'] ?? '',
          amount: args?['amount'] ?? '',
        );
      },
    ),
    GetPage(
      name: _Paths.TWO_FACTOR_AUTH,
      page: () => const TwoFactorAuthScreen(),
    ),
    GetPage(
      name: _Paths.INTERNAL_TRANSFER_HISTORY,
      page: () => const InternalTransferHistoryScreen(),
    ),
    GetPage(
      name: _Paths.TRADE_WIN_MAIN,
      page: () => const TradeWinMainScreen(),
    ),
    GetPage(
      name: _Paths.TRADE_WIN_PRODUCT_DETAIL,
      page: () => const TradeWinProductDetailScreen(),
    ),
    GetPage(
      name: _Paths.TRADE_WIN_REDEEM,
      page: () => const TradeWinRedeemScreen(),
    ),
    GetPage(
      name: _Paths.TRADE_WIN_REDEMPTION_SUCCESS,
      page: () => const TradeWinRedemptionSuccessScreen(),
    ),
    GetPage(
      name: _Paths.TRADE_WIN_PAST_WIN_DETAIL,
      page: () => const TradeWinPastWinDetailScreen(),
    ),
  ];
}
