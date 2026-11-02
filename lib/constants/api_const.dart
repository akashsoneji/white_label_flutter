import 'package:crm_app/flavor_config.dart';

class ApiConstants {
  static String get baseUrl => FlavorConfig.instance.apiBaseUrl;
  static String get socketUrl => FlavorConfig.instance.websocketUrl;

  static const String ajax = 'user/';

  static const String login = '${ajax}login';
  // Password reset OTP flow endpoints
  static const String requestPasswordResetOTP = '${ajax}password/forgot';
  static const String verifyPasswordResetOTP = '${ajax}password/verify-otp';
  static const String resetPasswordWithOTP = '${ajax}password/reset';
  static const String deleteAccount = '${ajax}settings/delete-account';
  static const String changePassword = '${ajax}mt5accounts/changepassword';
  static const String resetInvestorPassword =
      '${ajax}mt5accounts/resetinvestorpassword';
  static const String changeLeverage = '${ajax}mt5accounts/changeleverage';
  static const String changeUserPassword = '${ajax}settings/change-password';
  static const String googleOtpGenerate = '${ajax}settings/google-otp/generate';
  static const String googleOtpVerify = '${ajax}settings/google-otp/verify';
  static const String googleOtpDisable = '${ajax}settings/google-otp/disable';
  static const String googleOtpStatus = '${ajax}settings/google-otp/status';
  static const String userSessions = '${ajax}sessions';
  static String userSession(int id) => '${ajax}sessions/$id';
  static const String platformLinks = '${ajax}platform-links';
  static const String settingsActivityLog = '${ajax}settings/activitylog';
  static const String utilityIfscCode = '${ajax}utility/ifsc-code';
  static const String uniPaymentDeposit = '${ajax}deposit/unipayment';

  static const String mobileVerificationSend = '${ajax}mobile-verification/send';
  static const String mobileVerificationVerify =
      '${ajax}mobile-verification/verify';
  static const String googleOtpVerifyLogin = '${ajax}auth/google/verify-login-otp';
  static const String register = '${ajax}register';

  // Deep linking (public, no auth). See docs/DEEP_LINKING_BACKEND_SPEC.md §6-7.
  static const String deepLinkDeferredClaim = 'deeplink/deferred/claim';
  static const String deepLinkAttribution = 'deeplink/attribution';
  static const String registerFcmToken = '${ajax}register-fcm-token';
  static const String marketWatch = '${ajax}trade/marketwatch';
  static const String dashboard = '${ajax}dashboard';
  static const String setMt5Nickname = '${ajax}mt5accounts/setnickname';
  static const String sessionCheck = '${ajax}session/check';
  static const String getNotifications = '${ajax}notifications';
  static const String allNotifications = '${ajax}notifications/all';
  static String dynamicDeposit(String gatewaySlug) =>
      '${ajax}deposit/dynamic/$gatewaySlug';
  static const String activeNotices = '${ajax}notices/active';
  static const String liveChatConfig = '${ajax}live-chat';
  static const String markAllNotificationsRead =
      '${ajax}notifications/markasread';
  static String markNotificationRead(int id) =>
      '${ajax}notifications/markasread/$id';
  static String mt5CredentialsNotification(int id) =>
      '${ajax}notifications/mt5-credentials/$id';
  static String mt5CredentialsAck(int id) =>
      '${ajax}notifications/mt5-credentials/$id/ack';
  static const String priceAlerts = '${ajax}price-alerts';
  static const String priceAlertsUpdateFcmToken =
      '${ajax}price-alerts/update-fcm-token';
  static const String depositByReference = '${ajax}deposit/by-reference';
  static const String profile = '${ajax}settings/profile';
  static const String getMT5Accounts = '${ajax}mt5accounts/get';
  static const String createMT5Account = '${ajax}mt5accounts/create';
  static const String topupDemoAccount = '${ajax}mt5accounts/setbalance';
  static const String syncMT5Accounts = '${ajax}tradingaccounts/sync';
  static const String placeOrder = '${ajax}trade/new-order';
  static const String closePositionByPositionId =
      '${ajax}trade/closePositionByPositionId';
  static const String closePendingOrder = '${ajax}trade/closePendingOrder';
  static const String updateTPSL = '${ajax}trade/update-tp-sl';
  static const String updatePendingOrderTPSL = '${ajax}trade/update-pending-order-tp-sl';
  static const String tradeHistory = '${ajax}trade/tradehistory';
  static const String logout = '${ajax}logout';
  static const String depositList = '${ajax}deposit';
  static const String depositRequest = '${ajax}deposit/depositrequest';
  static const String cregisDepositCreate = '${ajax}deposit/cregis';
  static const String realPlanDetails = '${ajax}mt5accounts/plandetails';
  static const String getFinanceActivity = '${ajax}finance-activity';
  static const String depositProofProxy = '${ajax}deposit-proof-proxy/';
  // Bonus APIs
  static const String bonusList = '${ajax}bonus';
  static const String bonusClaimList = '${ajax}bonus/bonusClaimList';
  static const String bonusClaim = '${ajax}bonus/bonusClaim';
  static const String bonusClaimCancel = '${ajax}bonus/bonusClaimCancel';
  static const String changePrimaryAccount =
      '${ajax}mt5accounts/changePrimaryAccount';
  static String getInstrumentsByAccount(String accountNumber) =>
      '${ajax}instruments/$accountNumber';

  // Dropdown APIs
  static const String getCountryDropdown = '${ajax}settings/getCountryDropdown';
  static String kycStates(int countryId) => '${ajax}kyc/states/$countryId';
  static String kycCities(int stateId) => '${ajax}kyc/cities/$stateId';

  // KYC APIs
  static const String kycUpload = '${ajax}kyc/documents/upload';
  static String kycImageProxy(int documentId) =>
      '${ajax}kyc-image-proxy/$documentId';
  static const String kycStatus = '${ajax}kyc';
  static const String regulation = '${ajax}regulation';
  static const String kycProfileUpdate = '${ajax}kyc/profile';
  static const String submitUnifiedKyc = '${ajax}kyc/submit-unified';
  static const String sumsubToken = '${ajax}kyc/sumsub/token';
  static const String sumsubRefresh = '${ajax}kyc/sumsub/refresh';
  static const String checkMobile = '${ajax}auth/google/check-mobile';
  static const String getWalletData = '${ajax}internaltransfer';
  static const String getWalletDetailsNew = '${ajax}wallet';

  static const String currencyList = '${ajax}utility/currency-list';
  static const String withdrawalRequest = '${ajax}withdrawal';
  static String withdrawalMethodDelete(int id) => '${ajax}withdrawal/delete/$id';
  static String withdrawalImageProxy(int id) => '${ajax}image-proxy/$id';
  static const String withdrawalSendOTPRequest = '${ajax}withdrawal/sendOTP';
  static const String withdrawalSubmitRequest =
      '${ajax}withdrawal/withdrawalrequest';
  static const String checkBalance = '${ajax}withdrawal/checkbalance';
  static const String internalTransferRequest =
      '${ajax}internaltransfer/request';
  static const String internalTransferHistory =
      '${ajax}internaltransfer/history';
  static const String traderTransferConfig = '${ajax}trader-transfer/config';
  static const String traderTransferVerifyRecipient =
      '${ajax}trader-transfer/verify-recipient';
  static const String traderTransferSendOtp = '${ajax}trader-transfer/send-otp';
  static const String traderTransferSubmit = '${ajax}trader-transfer/submit';
  static const String traderTransferHistory = '${ajax}trader-transfer/history';
  static const String withdrawalMethods =
      '${ajax}withdrawal/withdrawal-method/';
  static const String bankWithdrawalList =
      '${ajax}withdrawal/getUserWithdrawalMethods';

  // IB (Introducing Broker) APIs
  static const String ibStatus = '${ajax}ib/status';
  static const String ibApplication = '${ajax}ib/application';
  static const String ibDashboard = '${ajax}ib/dashboard';
  static const String ibClients = '${ajax}ib/clients';
  static const String ibSubIbs = '${ajax}ib/sub-ibs';
  static const String ibTradeHistory = '${ajax}ib/trade-history';
  static const String ibStats = '${ajax}ib/stats';
  static const String ibSubIbStructure = '${ajax}ib/sub-ib-structure/';
  static const String ibSubIbSubIbs = '${ajax}ib/sub-ib-sub-ibs/';
  static const String ibSubIbStats = '${ajax}ib/sub-ib-stats/';
  static const String ibStructure = '${ajax}ib/structure';
  static const String ibSubIbApprovalRequests = '${ajax}ib/approval/requests';
  
  // IB Transfer Endpoints
  static const String ibTransferCreate = '${ajax}ib/transfer/create';
  static const String ibTransferClientsSearch = '${ajax}ib/transfer/clients/search';
  static const String ibTransferStore = '${ajax}ib/transfer/store';
  static const String ibTransferHistory = '${ajax}ib/transfer/history';
  static const String ibTransferCancel = '${ajax}ib/transfer/'; // Append {id}/cancel

  // Web-style IB requests list (datatable)
  static const String ibRequestList = '${ajax}ib/ib-request-list';
  static const String ibCommissionGroups = '${ajax}ib/commission-groups';
  static const String ibManage = '${ajax}ib/manage';
  static const String ibUpdateStatus = '${ajax}ib/update-status/';
  static const String ibActivities = '${ajax}ib/activities';
  static const String ibTreeStructure = '${ajax}ib/tree-structure';
  static const String ibGetIbDetails = '${ajax}ib/get-ib-details/'; // + {userSlug}
  static const String ibTemplateRates = '${ajax}ib/get-template-rates/'; // + {templateId}

  // Scratch Card APIs
  static const String getScratchCards   = 'v1/user/scratch-cards';
  static const String revealScratchCard = 'v1/user/scratch-cards/reveal';
  static const String claimScratchReward = 'v1/user/scratch-cards/claim';
  static const String getScratchLeaderboard = 'v1/user/scratch-cards/leaderboard';
  static const String convertScratchCreditToBalance =
      'v1/user/scratch-cards/convert-credit-to-balance';

  // App Status APIs (public; used before login for version / maintenance)
  static const String mobileAppDetails = '${ajax}mobile-app-details';
  static const String crmSettings = '${ajax}crm-settings';
  static const String appSettings = '${ajax}app-settings';

  // Enabled modules (per-user feature flags)
  static const String enabledModules = '${ajax}enabled-modules';

  // Support Ticket APIs
  static const String ticketDepartments = '${ajax}tickets/departments';
  static const String tickets = '${ajax}tickets';
  static String ticketDetail(String ticketId) => '${ajax}tickets/$ticketId';
  static String ticketReply(String ticketId) => '${ajax}tickets/$ticketId/reply';
  static String ticketClose(String ticketId) => '${ajax}tickets/$ticketId/close';
  static const String ticketAttachment = '${ajax}tickets/attachment';

  // Demo Contest APIs
  static const String demoContestContests = '${ajax}demo-contest/contests';
  static const String demoContestMyStats = '${ajax}demo-contest/my-stats';
  static const String demoContestClaim = '${ajax}demo-contest/claim';
  static String demoContestLeaderboard(String id) =>
      '${ajax}demo-contest/$id/leaderboard';
  static String demoContestEnrollPreview(String id) =>
      '${ajax}demo-contest/$id/enroll-preview';
  static String demoContestEnroll(String id) => '${ajax}demo-contest/$id/enroll';
  static String demoContestSteps(String id) => '${ajax}demo-contest/$id/steps';
  static String demoContestStepClick(String stepId) =>
      '${ajax}demo-contest/step/$stepId/click';
  static String demoContestTerms(String id) => '${ajax}demo-contest/$id/terms';
  static String demoContestTradingHistory(String id) =>
      '${ajax}demo-contest/$id/trading-history';
  static String demoContestRuleViolations(String id) =>
      '${ajax}demo-contest/$id/rule-violations';
  // IB-side contest management (no `user/` prefix).
  static const String ibDemoContestMyContests = 'ib/demo-contest/my-contests';
  static const String ibDemoContestInstruments = 'ib/demo-contest/instruments';
  static const String ibDemoContestStore = 'ib/demo-contest/store';
  static String ibDemoContestUpdate(int id) => 'ib/demo-contest/$id/update';
  static String ibDemoContestCancel(int id) => 'ib/demo-contest/$id/cancel';
  static String ibDemoContestAddPrizeFund(int id) =>
      'ib/demo-contest/$id/add-prize-fund';
  static String ibDemoContestEnrollments(int id) =>
      'ib/demo-contest/$id/enrollments';
  static String ibDemoContestEnrollmentApprove(int id) =>
      'ib/demo-contest/enrollment/$id/approve';
  static String ibDemoContestEnrollmentReject(int id) =>
      'ib/demo-contest/enrollment/$id/reject';

  // Trade & Win APIs
  static const String tradeWinProducts = 'v1/user/trade-win/products';
  static const String tradeWinPastWins = 'v1/user/trade-win/past-wins';
  static const String tradeWinSavedAddresses = 'v1/user/trade-win/saved-addresses';
  static const String tradeWinClaim = 'v1/user/trade-win/claim';

  // Copy Trading APIs
  // User (authenticated) endpoints
  static const String copyTradingMasterApply = '${ajax}copytrading/master/apply';
  static const String copyTradingMasterStatus =
      '${ajax}copytrading/master/status';
  static const String copyTradingMasterDashboardStats =
      '${ajax}copytrading/master/dashboard-stats';

  /// Master dashboard overview (range + hero + main chart + copier_health
  /// + plans + payouts + recent_trades + alerts). Pass `range` (e.g. `30d`)
  /// via `queryParameters` — `ApiService.get` replaces any inline query string.
  static const String copyTradingMasterDashboardOverviewPath =
      '${ajax}copytrading/master/dashboard-overview';

  static const String copyTradingMasterPlans = '${ajax}copytrading/master/plans';
  static String copyTradingMasterOpenPositions(int planId) =>
      '$copyTradingMasterPlans/$planId/open-positions';
  static const String copyTradingCopierEligibleAccounts =
      '${ajax}copytrading/copier/eligible-accounts';
  static const String copyTradingCopierSubscribe =
      '${ajax}copytrading/copier/subscribe';
  static String copyTradingCopierSubscriptionsList({
    int page = 1,
    int perPage = 20,
  }) =>
      '${ajax}copytrading/copier/subscriptions?page=$page&per_page=$perPage';
  static String copyTradingMasterCopierSubscriptionHistory(int copierId) =>
      '${ajax}copytrading/master/copiers/$copierId/subscription-history';
  static const String copyTradingMasterSettlements =
      '${ajax}copytrading/master/settlements';
  static String copyTradingCopierSubscriptionDetail(int id) =>
      '${ajax}copytrading/copier/subscriptions/$id/detail';
  static String copyTradingCopierSubscriptionTrades(
    int id, {
    int page = 1,
    int limit = 20,
    int? t,
  }) =>
      '${ajax}copytrading/copier/subscriptions/$id/trades?page=$page&limit=$limit${t != null ? '&_t=$t' : ''}';
  static String copyTradingCopierSubscriptionAddCapital(int id) =>
      '${ajax}copytrading/copier/subscriptions/$id/add-capital';
  static String copyTradingCopierSubscriptionPause(int id) =>
      '${ajax}copytrading/copier/subscriptions/$id/pause';
  static String copyTradingCopierSubscriptionResume(int id) =>
      '${ajax}copytrading/copier/subscriptions/$id/resume';
  static String copyTradingCopierSubscriptionStop(int id) =>
      '${ajax}copytrading/copier/subscriptions/$id/stop';
  static String copyTradingCopierSubscriptionUpdate(int id) =>
      '${ajax}copytrading/copier/subscriptions/$id/update';

  // Public endpoints
  static const String copyTradingPlans = 'copytrading/plans';
  static const String copyTradingMastersSearch = 'copytrading/masters/search';
  static const String copyTradingPlansSearch = 'copytrading/plans/search';
  static String copyTradingMasterProfile(
    String masterCode, {
    String? timeframe,
    String? selectedPlanId,
  }) {
    final base = 'copytrading/masters/$masterCode';
    final params = <String>[];
    if (timeframe != null && timeframe.isNotEmpty) {
      params.add('timeframe=$timeframe');
    }
    if (selectedPlanId != null && selectedPlanId.isNotEmpty) {
      params.add('plan_id=$selectedPlanId');
    }
    if (params.isEmpty) return base;
    return '$base?${params.join('&')}';
  }

  static String copyTradingMasterTradeHistory(
    String masterCode, {
    String? timeframe,
    String? selectedPlanId,
    int page = 1,
    int perPage = 20,
  }) {
    final base = '${ajax}copytrading/copier/masters/$masterCode/trade-history';
    final params = <String>[];
    if (timeframe != null && timeframe.isNotEmpty) {
      params.add('timeframe=$timeframe');
    }
    if (selectedPlanId != null && selectedPlanId.isNotEmpty) {
      params.add('plan_id=$selectedPlanId');
    }
    params.add('page=$page');
    params.add('per_page=$perPage');
    return '$base?${params.join('&')}';
  }
}

// struct APIConstant {
    
//     // NEW API
//     static let BaseUrl                          = "https://my.app.com/"
//     static let API                              =  BaseUrl + "api/"
//     static var SocketURL                        = "wss://my.app.com:8080"
            
//     static let AjaxTiles                        = API + "user/"
        
//     static let LoginAPI                         = AjaxTiles + "login"
//     static let RegisterAPI                      = AjaxTiles + "register"
//     static let ForgotPasswordAPI                = AjaxTiles + "password/email"
//     static let ResetPasswordAPI                 = AjaxTiles + "settings/change-password"
//     static let DashBoardAPI                     = AjaxTiles + "dashboard"
//     static let LogoutAPI                        = AjaxTiles + "logout"
//     static let deleteAccountAPI                 = AjaxTiles + "settings/delete-account"
    
//     static let ProfileAPI                       = AjaxTiles + "settings/profile"
//     static let GetCountryAPI                    = AjaxTiles + "settings/getCountryDropdown"
//     static let GetStateAPI                      = AjaxTiles + "settings/getStateDropdown"
//     static let GetCityAPI                       = AjaxTiles + "settings/getCityDropdown"
    
//     static let KYCStatusAPI                     = AjaxTiles + "kyc"
//     static let GetImageFromSlugAPI              = AjaxTiles + "kyc/documents/viewDocument/"
//     static let KYCUploadAPI                     = AjaxTiles + "kyc/documents/upload"
    
//     static let GetMT5Account                    = AjaxTiles + "mt5accounts/get"
//     static let GetMT5LivePackagesAPI            = AjaxTiles + "mt5accounts/plandetails"
//     static let CreatetMT5AccountAPI             = AjaxTiles + "mt5accounts/create"
//     static let UpdateMT5AccountLevarageAPI      = AjaxTiles + "mt5accounts/changeleverage"
//     static let UpdateMT5AccountPasswordAPI      = AjaxTiles + "mt5accounts/changepassword"
//     static let changePrimaryAccountMT5API       = AjaxTiles + "mt5accounts/changePrimaryAccount"
//     static let setDemoAccountBalanceAPI         = AjaxTiles + "mt5accounts/setbalance"

    
//     static let GetInternalTransferAPI           = AjaxTiles + "internaltransfer"
//     static let InternalTransferAPI              = AjaxTiles + "internaltransfer/request"
//     static let TransactionHistoryAPI            = AjaxTiles + "transactions"
    
//     static let DepositTypeAPI                   = AjaxTiles + "deposit"
//     static let DepositAmountAPI                 = AjaxTiles + "deposit/depositrequest"
    
//     static let withdrawalListApi                = AjaxTiles + "withdrawal"
//     static let getWithdrawalByIDAPI             = AjaxTiles + "withdrawal/withdrawal-method/"
//     static let WithdrawalRequestAPI             = AjaxTiles + "withdrawal/withdrawalrequest"
//     static let GetUserWithdrawalMethodsAPI      = AjaxTiles + "withdrawal/getUserWithdrawalMethods"
//     static let getOTPAPI                        = AjaxTiles + "withdrawal/sendOTP"
//     static let CheckBalanceAPI                  = AjaxTiles + "withdrawal/checkbalance"

//     static let GetWalletDetailAPI               = AjaxTiles + "wallet"
    
//     static let BonusAPI                         = AjaxTiles + "bonus"
//     static let BonusClaimListAPI                = AjaxTiles + "bonus/bonusClaimList"
//     static let DepositBonusClaimAPI             = AjaxTiles + "bonus/bonusClaim"
    
//     static let GetCurrencyListAPI               = AjaxTiles + "utility/currency-list"
//     static let CheckIFSCCodeAPI                 = AjaxTiles + "utility/ifsc-code"
//     static let CurrencyRatesAPI                 = AjaxTiles + "utility/currency-rates"
    
    
//     static let ChartAPI                         = BaseUrl + "user/chart/"

//     static let Trade                            = AjaxTiles + "trade/"
    
    
//     static let TradingAPI                      = Trade + "new-order"
//     static let ClosePositionAPI                = Trade + "closePositionByPositionId"

//     static let DeletePendingOrderAPI            = Trade + "closePendingOrder"
//     static let GetScriptDetailsAPI              = Trade + "getSymbolDetails"

//     static let GetTradeHistoryAPI              = Trade + "tradehistory"
//     static let getSymbolAPI                     = Trade + "symbols" // NEW API
    
    
//     // OLD API
    
//     static let RegisterValidationAPI            = AjaxTiles + "register_validation.php"
//     static let LoginWithGoogleAPI               = AjaxTiles + "login_with_google.php"
//     static let AccountListAPI                   = AjaxTiles + "account_list.php"
//     static let CommonAPI                        = AjaxTiles + "common_api.php"
//     static let AddDepositAPI                    = AjaxTiles + "add_deposit.php"
//     static let AppConfigAPI                     = AjaxTiles + "app_config.php"


        
//     static let RemoveKYCAPI                     = AjaxTiles + "kyc_remove_image.php"
    
//     static let GetUserPrefrenceAPI              = AjaxTiles + "get_user_prefrence.php"

//     static let SpinWheelClaimAPI                = AjaxTiles + "spin_wheel_claim.php"
//     static let UpdateProfileAPI                 = AjaxTiles + "profile_update.php"
//     static let GetSocketAPI                     = AjaxTiles + "get_socket_url.php"

//     static let TradeAndWinAPI                   = AjaxTiles + "trade_and_win.php"

//     static let IBApplicationStatusAPI           = AjaxTiles + "ib_application_status.php"
//     static let AddIBApplicationAPI              = AjaxTiles + "add_ibapplication.php"
//     static let GetDashboardAPI                  = AjaxTiles + "get_dashboard.php"
    
    
//     static let PartnershipRequestManageAPI      = AjaxTiles + "partnership_request_manage.php"
//     static let StructuresManageAPI              = AjaxTiles + "structures_manage.php"
//     static let MyTradersAPI                     = AjaxTiles + "my_traders.php"
//     static let SponserMTDataAPI                 = AjaxTiles + "sponser_mt_data_ajax.php"
//     static let FantasticFourOfferAPI            = AjaxTiles + "fantastic_four_offer.php"

    
    
    
//     static let Database                         = BaseUrl + "datatable/"
        
//     static let SpinAndWinListAPI                = Database + "spin_and_win_list.php"
//     static let PartnershipRequestsAPI           = Database + "partnership_requests.php"

//     static let MyStructuresAPI                  = Database + "my_structures.php"

//     static let Trading                          = AjaxTiles + "trading/"

//     static let OpenPendingtradeAPI              = Trading + "get_open_trade.php"
//     static let GetScriptAPI                     = Trading + "get_script.php"
//     static let AddMarketWatchAPI                = Trading + "add_marketwatch.php"
//     static let DeleteMarketWatchAPI             = Trading + "delete_marketwatch.php"
//     static let GetMarketWatchAPI                = Trading + "get_marketwatch.php"

//     static let TradingCloseAPI                  = Trading + "trade_place_close.php"
//     static let UpdateOrderProfitLossAPI         = Trading + "update_order_profit_loss.php"
//     static let ScriptsSortingsAPI               = Trading + "scripts_sortings.php"
//     static let GetSymbolUsdRateAPI              = Trading + "get_symbol_usd_rate.php"
// }