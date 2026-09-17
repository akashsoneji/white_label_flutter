import 'package:get/get.dart';
import 'package:crm_app/bindings/more_bindings.dart';
import 'package:crm_app/bindings/ticket_binding.dart';
import 'package:crm_app/screens/kyc/presentation/pages/kyc_bank_screen.dart';
import 'package:crm_app/screens/kyc/presentation/pages/bank_list_screen.dart';
import 'package:crm_app/screens/bonus/presentation/pages/bonus_screen.dart';
import 'package:crm_app/screens/bonus/presentation/pages/scratch_card_screen.dart';
import 'package:crm_app/screens/home/more/copytrading/copy_trading_hub_screen.dart';
import 'package:crm_app/screens/copy_trading/copy_trading_main_screen.dart';
import 'package:crm_app/screens/copy_trading/trader_details_screen.dart';
import 'package:crm_app/bindings/demo_contest_binding.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/contest_details_screen.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/contest_rules_screen.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/demo_contest_screen.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/join_contest_screen.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/leaderboard_screen.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/my_contest_history_screen.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/demo_contest_my_stats_screen.dart';
import 'package:crm_app/screens/demo_contest/presentation/pages/winners_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/finance_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_dashboard_screen.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_main_screen.dart';
import 'package:crm_app/screens/home/more/setting/setting_screen.dart';
import 'package:crm_app/screens/home/more/support/support_screen.dart';
import 'package:crm_app/screens/home/more/ticket/create_ticket_screen.dart';
import 'package:crm_app/screens/home/more/ticket/ticket_detail_screen.dart';
import 'package:crm_app/screens/home/more/ticket/ticket_list_screen.dart';
import 'package:crm_app/screens/home/more/tools_education/tools_education_screen.dart';
import 'package:crm_app/screens/home/more/partnership_program_screen.dart';
import 'package:crm_app/screens/home/more/more_screen.dart';
import 'package:crm_app/screens/notifications/presentation/pages/notifications_screen.dart';
import 'package:crm_app/screens/notifications/bindings/notification_binding.dart';
import 'package:crm_app/screens/home/open_account_screen.dart';
import 'package:crm_app/screens/home/choose_account_screen.dart';
import 'package:crm_app/screens/home/create_crm_app_account_screen.dart';
import 'package:crm_app/screens/home/chart_screen.dart';
import '../app/ui_registry.dart';
import '../bindings/deposit_binding.dart';
import '../bindings/payment_method_binding.dart';
import '../screens/auth/presentation/pages/legal_documents_screen.dart';
import '../screens/auth/presentation/pages/privacy_policy_screen.dart';
import '../screens/auth/presentation/pages/account_created_screen.dart';
import '../screens/home/change_password_screen.dart';
import '../screens/home/more/two_factor_auth_screen.dart';
import '../screens/auth/presentation/pages/google_login_otp_screen.dart';
import '../screens/home/more/chat_with_us_screen.dart';
import '../screens/home/more/edit_profile_screen.dart';
import '../screens/home/more/view_profile_screen.dart';
import '../screens/finance/presentation/pages/deposit_screen.dart';
import '../screens/finance/presentation/pages/internal_transfer_history_screen.dart';
import '../screens/finance/presentation/pages/internal_transfer_screen.dart';
import '../screens/finance/presentation/pages/wallet_screen.dart';
import '../screens/finance/presentation/pages/withdrawal_screen.dart';
import '../screens/home/more/kyc_verification_screen.dart';
import '../screens/kyc/presentation/pages/kyc_intro_screen.dart';
import '../screens/kyc/presentation/pages/kyc_details_screen.dart';
import '../screens/kyc/presentation/pages/kyc_docs_screen.dart';
import '../screens/kyc/presentation/pages/kyc_success_screen.dart';
import '../screens/kyc/presentation/pages/unified_compliance_wizard.dart';
import '../screens/finance/presentation/pages/transaction_history_screen.dart';
import '../screens/home/order_confirmation_screen.dart';
import '../screens/settings/presentation/pages/language_selector_screen.dart';
import '../screens/settings/presentation/pages/account_management_screen.dart';
import '../screens/copy_trading/settings/wallet_screen.dart';
import '../screens/copy_trading/finance/deposit_screen.dart';
import '../screens/copy_trading/finance/payment_methods_screen.dart';
import '../screens/copy_trading/settings/invite_friend_screen.dart';
import '../screens/copy_trading/finance/internal_transfer_screen.dart';
import '../bindings/splash_binding.dart';
// IBM screens
import '../screens/ibm/presentation/pages/ibm_main_shell.dart';
import '../screens/ibm/presentation/pages/ibm_application_screen.dart';
// PMAM screens
import '../screens/home/more/pmam/pmam_main_screen.dart';
import '../screens/home/more/pmam/pmam_become_manager_screen.dart';
import '../screens/home/more/pmam/pmam_manager_dashboard_screen.dart';
import '../screens/home/more/pmam/pmam_manager_portal_screen.dart';
import '../screens/home/more/pmam/pmam_create_plan_screen.dart';
import '../screens/home/more/pmam/pmam_investor_portal_screen.dart';
import '../screens/home/more/pmam/pmam_my_investment_screen.dart';
import '../screens/home/more/pmam/pmam_manager_detail_screen.dart';
import '../screens/home/more/pmam/pmam_manager_plan_detail_screen.dart';
import '../screens/home/more/pmam/pmam_fund_manager_view_screen.dart';
import '../screens/trade_win/trade_win_main_screen.dart';
import '../screens/trade_win/trade_win_product_detail_screen.dart';
import '../screens/trade_win/trade_win_redeem_screen.dart';
import '../screens/trade_win/trade_win_redemption_success_screen.dart';
import '../screens/trade_win/trade_win_past_win_detail_screen.dart';
import '../bindings/auth_binding.dart';
import '../bindings/account_binding.dart';
import '../bindings/trading_binding.dart';
import '../screens/common/webview_screen.dart';
import '../screens/finance/presentation/pages/cregis_address_screen.dart';
import '../screens/finance/presentation/pages/cregis_success_screen.dart';
import '../screens/finance/view_models/transaction_history_controller.dart';
import '../screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart'
    as vantage;
import '../flavor_config.dart';

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
  static const VIEW_PROFILE = _Paths.VIEW_PROFILE;
  static const WITHDRAWAL = _Paths.WITHDRAWAL;
  static const DEPOSIT = _Paths.DEPOSIT;
  static const WALLET = _Paths.WALLET;
  static const TRANSACTION_HISTORY = _Paths.TRANSACTION_HISTORY;
  static const KYC_VERIFICATION = _Paths.KYC_VERIFICATION;
  static const KYC_INTRO = _Paths.KYC_INTRO;
  static const KYC_DETAILS = _Paths.KYC_DETAILS;
  static const KYC_DOCS = _Paths.KYC_DOCS;
  static const KYC_SUCCESS = _Paths.KYC_SUCCESS;
  static const COMPLIANCE_WIZARD = _Paths.COMPLIANCE_WIZARD;
  static const CHAT_WITH_US = _Paths.CHAT_WITH_US;
  static const CHOOSE_ACCOUNT = _Paths.CHOOSE_ACCOUNT;
  static const CREATE_APP_ACCOUNT = _Paths.CREATE_APP_ACCOUNT;
  static const FINANCE = _Paths.FINANCE;
  static const INTERNAL_TRANSFER = _Paths.INTERNAL_TRANSFER;
  static const INTERNAL_TRANSFER_HISTORY = _Paths.INTERNAL_TRANSFER_HISTORY;
  static const IB_DASHBOARD = _Paths.IB_DASHBOARD;
  static const IB_MAIN = _Paths.IB_MAIN;
  static const COPY_TRADING_MAIN = _Paths.COPY_TRADING_MAIN;
  static const COPY_TRADING_HUB = _Paths.COPY_TRADING_HUB;
  static const TRADER_DETAILS = _Paths.TRADER_DETAILS;
  static const BONUS = _Paths.BONUS;
  static const SCRATCH_CARD = _Paths.SCRATCH_CARD;
  static const DEMO_CONTEST = _Paths.DEMO_CONTEST;
  static const DEMO_CONTEST_RULES = _Paths.DEMO_CONTEST_RULES;
  static const DEMO_CONTEST_JOIN = _Paths.DEMO_CONTEST_JOIN;
  static const DEMO_CONTEST_DETAILS = _Paths.DEMO_CONTEST_DETAILS;
  static const DEMO_CONTEST_LEADERBOARD = _Paths.DEMO_CONTEST_LEADERBOARD;
  static const DEMO_CONTEST_HISTORY = _Paths.DEMO_CONTEST_HISTORY;
  static const DEMO_CONTEST_MY_STATS = _Paths.DEMO_CONTEST_MY_STATS;
  static const DEMO_CONTEST_WINNERS = _Paths.DEMO_CONTEST_WINNERS;
  
  // ── IBM ──
  static const IBM_MANAGER_PORTAL = _Paths.IBM_MANAGER_PORTAL;
  static const IBM_APPLICATION = _Paths.IBM_APPLICATION;
  
  static const SETTING = _Paths.SETTING;
  static const SUPPORT = _Paths.SUPPORT;
  static const TICKET_LIST = _Paths.TICKET_LIST;
  static const TICKET_CREATE = _Paths.TICKET_CREATE;
  static const TICKET_DETAIL = _Paths.TICKET_DETAIL;
  static const TOOLS_EDUCATION = _Paths.TOOLS_EDUCATION;
  static const MORE = _Paths.MORE;
  static const NOTIFICATIONS = _Paths.NOTIFICATIONS;
  static const PARTNERSHIP_PROGRAM = _Paths.PARTNERSHIP_PROGRAM;
  static const BRAND_TEST = _Paths.BRAND_TEST;
  static const KYC_BANK = _Paths.KYC_BANK;
  static const PAYMENT_METHOD = _Paths.PAYMENT_METHOD;
  static const DEPOSIT_INSTRUCTION_SCREEN = _Paths.DEPOSIT_INSTRUCTION_SCREEN;
  static const BANK_LIST = _Paths.BANK_LIST;
  static const CHANGE_PASSWORD = _Paths.CHANGE_PASSWORD;
  static const TWO_FACTOR_AUTH = _Paths.TWO_FACTOR_AUTH;
  static const GOOGLE_LOGIN_OTP = _Paths.GOOGLE_LOGIN_OTP;
  static const TENAX_BROKER_SELECTION = _Paths.TENAX_BROKER_SELECTION;
  static const TENAX_BROKER_INFO = _Paths.TENAX_BROKER_INFO;
  static const COPY_TRADING_WALLET = _Paths.COPY_TRADING_WALLET;
  static const COPY_TRADING_DEPOSIT = _Paths.COPY_TRADING_DEPOSIT;
  static const COPY_TRADING_PAYMENT_METHODS =
      _Paths.COPY_TRADING_PAYMENT_METHODS;
  static const COPY_TRADING_INVITE_FRIEND = _Paths.COPY_TRADING_INVITE_FRIEND;
  static const COPY_TRADING_INTERNAL_TRANSFER =
      _Paths.COPY_TRADING_INTERNAL_TRANSFER;

  // ── PMAM ──
  static const PMAM_MAIN = _Paths.PMAM_MAIN;
  static const PMAM_BECOME_MANAGER = _Paths.PMAM_BECOME_MANAGER;
  static const PMAM_MANAGER_DASHBOARD = _Paths.PMAM_MANAGER_DASHBOARD;
  static const PMAM_MANAGER_PORTAL = _Paths.PMAM_MANAGER_PORTAL;
  static const PMAM_CREATE_PLAN = _Paths.PMAM_CREATE_PLAN;
  static const PMAM_INVESTOR_PORTAL = _Paths.PMAM_INVESTOR_PORTAL;
  static const PMAM_MANAGER_DETAIL = _Paths.PMAM_MANAGER_DETAIL;
  static const PMAM_MANAGER_PLAN_DETAIL = _Paths.PMAM_MANAGER_PLAN_DETAIL;
  static const PMAM_FUND_MANAGER_VIEW = _Paths.PMAM_FUND_MANAGER_VIEW;

  // ── Trade & Win ──
  static const TRADE_WIN_MAIN = _Paths.TRADE_WIN_MAIN;
  static const TRADE_WIN_PRODUCT_DETAIL = _Paths.TRADE_WIN_PRODUCT_DETAIL;
  static const TRADE_WIN_REDEEM = _Paths.TRADE_WIN_REDEEM;
  static const TRADE_WIN_REDEMPTION_SUCCESS =
      _Paths.TRADE_WIN_REDEMPTION_SUCCESS;
  static const TRADE_WIN_PAST_WIN_DETAIL = _Paths.TRADE_WIN_PAST_WIN_DETAIL;
  static const CREGIS_CHECKOUT = _Paths.CREGIS_CHECKOUT;
  static const CREGIS_ADDRESS = _Paths.CREGIS_ADDRESS;
  static const CREGIS_SUCCESS = _Paths.CREGIS_SUCCESS;

  static final routes = [
    GetPage(
      name: _Paths.SPLASH,
      page: () => UiRegistry.instance.splash(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: _Paths.GET_STARTED,
      page: () => UiRegistry.instance.getStarted(),
    ),
    GetPage(name: _Paths.KYC_BANK, page: () => KycBankScreen()),
    GetPage(name: _Paths.CHANGE_PASSWORD, page: () => ChangePasswordScreen()),
    GetPage(
      name: _Paths.TWO_FACTOR_AUTH,
      page: () => const TwoFactorAuthScreen(),
    ),
    GetPage(
      name: _Paths.PAYMENT_METHOD,
      page: () => PaymentMethodsScreen(accountNumber: ''),
      binding: PaymentMethodBinding(),
    ),
    GetPage(name: _Paths.BANK_LIST, page: () => BankListScreen()),
    GetPage(
      name: _Paths.LOGIN,
      page: () => UiRegistry.instance.login(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.GOOGLE_LOGIN_OTP,
      page: () => const GoogleLoginOtpScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.CREATE_ACCOUNT,
      // ✅ Same routing pattern as LOGIN.
      page: () => UiRegistry.instance.createAccount(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.LEGAL_DOCUMENTS,
      page: () => const LegalDocumentsScreen(registrationData: {}),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.PRIVACY_POLICY,
      page: () => const PrivacyPolicyScreen(),
    ),
    GetPage(name: _Paths.ACCOUNT_CREATED, page: () => AccountCreatedScreen()),
    GetPage(
      name: _Paths.FORGOT_PASSWORD,
      page: () => UiRegistry.instance.forgotPassword(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.VERIFY_CODE,
      page: () {
        // Pull email from Get.arguments (set by
        // authController.requestPasswordResetOTP at lib/screens/auth/view_models/auth_controller.dart:1587).
        // Previously this was hardcoded to `email: ''`, which caused the
        // /password/verify-otp request body to ship with `"email": ""` and
        // the backend to reject the OTP.
        final emailArg = Get.arguments;
        final email = emailArg is String ? emailArg : '';
        return UiRegistry.instance.verifyCode(email: email);
      },
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.CREATE_NEW_PASSWORD,
      page: () => UiRegistry.instance.createNewPassword(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.TRADING,
      // Route through UiRegistry so the correct parent UI renders.
      page: () => UiRegistry.instance.tradingMain(),
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
    GetPage(name: _Paths.VIEW_PROFILE, page: () => const ViewProfileScreen()),
    GetPage(name: _Paths.WITHDRAWAL, page: () => const WithdrawalScreen()),
    GetPage(
      name: _Paths.DEPOSIT,
      page: () => DepositScreen(accountNumber: Get.arguments ?? ''),
      binding: DepositBinding(),
    ),
    GetPage(name: _Paths.WALLET, page: () => WalletScreen()),
    GetPage(
      name: _Paths.TRANSACTION_HISTORY,
      page: () {
        // Brands using the shared UI tree use the branded
        // transaction history screen; everything else uses the plain one.
        if (FlavorConfig.usesVantageUi()) {
          return const vantage.VantageTransactionHistoryScreen();
        }
        return const TransactionHistoryScreen();
      },
    ),
    GetPage(
      name: _Paths.KYC_VERIFICATION,
      page: () => const KycVerificationScreen(),
    ),
    GetPage(
      name: _Paths.KYC_INTRO,
      page: () => KycIntroScreen(stageCompletion: Get.arguments),
    ),
    GetPage(name: _Paths.KYC_DETAILS, page: () => const KycDetailsScreen()),
    GetPage(name: _Paths.KYC_DOCS, page: () => const KycDocsScreen()),
    GetPage(name: _Paths.KYC_SUCCESS, page: () => const KycSuccessScreen()),
    GetPage(
      name: _Paths.COMPLIANCE_WIZARD,
      page: () => const UnifiedComplianceWizard(),
    ),
    GetPage(name: _Paths.CHAT_WITH_US, page: () => const ChatWithUsScreen()),
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
      page: () => const InternalTransferScreen(),
    ),
    GetPage(
      name: _Paths.INTERNAL_TRANSFER_HISTORY,
      page: () => const InternalTransferHistoryScreen(),
    ),
    GetPage(name: _Paths.CHART, page: () => const ChartScreen()),
    GetPage(name: _Paths.FINANCE, page: () => const FinanceScreen()),
    GetPage(name: _Paths.IB_DASHBOARD, page: () => const IbDashboardScreen()),
    GetPage(name: _Paths.IB_MAIN, page: () => const IbMainScreen()),
    GetPage(
      name: _Paths.COPY_TRADING_MAIN,
      page: () {
        final initialIndex =
            (Get.arguments is int) ? (Get.arguments as int) : null;
        return CopyTradingMainScreen(initialIndex: initialIndex);
      },
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
    GetPage(
      name: _Paths.SCRATCH_CARD,
      page: () => const ScratchCardListScreen(),
    ),
    GetPage(name: _Paths.DEMO_CONTEST, page: () => const DemoContestScreen()),
    GetPage(
      name: _Paths.DEMO_CONTEST_RULES,
      page: () => const ContestRulesScreen(),
      binding: DemoContestBinding(),
    ),
    GetPage(
      name: _Paths.DEMO_CONTEST_JOIN,
      page: () => const JoinContestScreen(),
      binding: DemoContestBinding(),
    ),
    GetPage(
      name: _Paths.DEMO_CONTEST_DETAILS,
      page: () {
        final id = (Get.arguments as String?) ?? '';
        return ContestDetailsScreen(contestId: id);
      },
      binding: DemoContestBinding(),
    ),
    GetPage(
      name: _Paths.DEMO_CONTEST_LEADERBOARD,
      page: () {
        final id = Get.arguments as String?;
        return LeaderboardScreen(contestIdArg: id);
      },
      binding: DemoContestBinding(),
    ),
    GetPage(
      name: _Paths.DEMO_CONTEST_HISTORY,
      page: () => const MyContestHistoryScreen(),
      binding: DemoContestBinding(),
    ),
    GetPage(
      name: _Paths.DEMO_CONTEST_MY_STATS,
      page: () {
        final id = Get.arguments as String?;
        return DemoContestMyStatsScreen(contestId: id ?? '');
      },
      binding: DemoContestBinding(),
    ),
    GetPage(
      name: _Paths.DEMO_CONTEST_WINNERS,
      page: () {
        final id = Get.arguments as String?;
        return WinnersScreen(contestIdArg: id);
      },
      binding: DemoContestBinding(),
    ),
    
    // ── IBM Routes ──
    GetPage(
      name: _Paths.IBM_MANAGER_PORTAL,
      page: () => const IbmMainShell(),
    ),
    GetPage(
      name: _Paths.IBM_APPLICATION,
      page: () => const IbmApplicationScreen(),
    ),
    
    GetPage(name: _Paths.SETTING, page: () => const SettingScreen()),
    GetPage(name: _Paths.SUPPORT, page: () => const SupportScreen()),
    GetPage(
      name: _Paths.TICKET_LIST,
      page: () => const TicketListScreen(),
      binding: TicketBinding(),
    ),
    GetPage(
      name: _Paths.TICKET_CREATE,
      page: () => const CreateTicketScreen(),
      binding: TicketBinding(),
    ),
    GetPage(
      name: _Paths.TICKET_DETAIL,
      page: () => const TicketDetailScreen(),
      binding: TicketBinding(),
    ),
    GetPage(
      name: _Paths.TOOLS_EDUCATION,
      page: () => const ToolsEducationScreen(),
    ),
    GetPage(
      name: _Paths.MORE,
      page: () => const MoreScreen(),
      binding: MoreBinding(),
    ),
    GetPage(
      name: _Paths.NOTIFICATIONS,
      page: () => const NotificationsScreen(),
      binding: NotificationBinding(),
    ),
    GetPage(
      name: _Paths.PARTNERSHIP_PROGRAM,
      page: () => const PartnershipProgramScreen(),
    ),

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
          tabIndex: args['tabIndex'] ?? 0,
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
    GetPage(name: _Paths.PMAM_MAIN, page: () => const PmamMainScreen()),
    GetPage(
      name: _Paths.PMAM_BECOME_MANAGER,
      page: () => const PmamBecomeManagerScreen(),
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_DASHBOARD,
      page: () => const PmamManagerDashboardScreen(),
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_PORTAL,
      page: () => const PmamManagerPortalScreen(),
    ),
    GetPage(
      name: _Paths.PMAM_CREATE_PLAN,
      page: () => const PmamCreatePlanScreen(),
    ),
    GetPage(
      name: _Paths.PMAM_INVESTOR_PORTAL,
      page: () => const PmamInvestorPortalScreen(),
    ),
    GetPage(
      name: _Paths.PMAM_MY_INVESTMENT,
      page: () => const PmamMyInvestmentScreen(),
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_DETAIL,
      page: () => const PmamManagerDetailScreen(),
    ),
    GetPage(
      name: _Paths.PMAM_MANAGER_PLAN_DETAIL,
      page: () => const PmamManagerPlanDetailScreen(),
    ),
    GetPage(
      name: _Paths.PMAM_FUND_MANAGER_VIEW,
      page: () => const PmamFundManagerViewScreen(),
    ),
    // ── Trade & Win ──
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
      binding: BindingsBuilder(() {
        // Ensure TransactionHistoryController is registered BEFORE the
        // screen builds so the Cregis polling can call
        // `Get.find<TransactionHistoryController>()` from its first tick.
        if (!Get.isRegistered<TransactionHistoryController>()) {
          Get.put(TransactionHistoryController());
        }
      }),
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        return CregisAddressScreen(
          cregisAddress: args?['cregisAddress'] ?? '',
          referenceNumber: args?['referenceNumber'] ?? '',
          amount: args?['amount'] ?? '',
          networkKey: args?['networkKey'] ?? 'trc20',
          tapTimeIso: args?['tapTimeIso'] ?? '',
        );
      },
    ),
    GetPage(
      name: _Paths.CREGIS_SUCCESS,
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<TransactionHistoryController>()) {
          Get.put(TransactionHistoryController());
        }
      }),
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        return CregisSuccessScreen(
          referenceNumber: args?['referenceNumber'] ?? '',
          amount: args?['amount'] ?? '',
          checkoutUrl: args?['checkoutUrl'] ?? '',
          tapTimeIso: args?['tapTimeIso'] ?? '',
        );
      },
    ),
  ];
}
