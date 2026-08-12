import 'package:crm_app/flavor_config.dart';

class ApiConstants {
  static String get baseUrl => FlavorConfig.instance.apiBaseUrl;
  static String get socketUrl => FlavorConfig.instance.websocketUrl;

  static const String ajax = 'user/';

  static const String login = '${ajax}login';
  static const String forgotPassword = '${ajax}password/email';
  static const String sendOTP = '${ajax}send-otp';
  static const String verifyOTP = '${ajax}verify-otp';
  static const String resetPassword = '${ajax}reset-password';

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
  static const String googleOtpVerifyLogin = '${ajax}auth/google/verify-login-otp';
  static const String register = '${ajax}register';
  static const String registerFcmToken = '${ajax}register-fcm-token';
  static const String dashboard = '${ajax}dashboard';
  static const String priceAlerts = '${ajax}price-alerts';
  static const String profile = '${ajax}settings/profile';
  static const String getMT5Accounts = '${ajax}mt5accounts/get';
  static const String createMT5Account = '${ajax}mt5accounts/create';
  static const String topupDemoAccount = '${ajax}mt5accounts/setbalance';
  static const String syncMT5Accounts = '${ajax}mt5accounts/mt5AccountSync';
  static const String placeOrder = '${ajax}trade/new-order';
  static const String closePositionByPositionId =
      '${ajax}trade/closePositionByPositionId';
  static const String cancelPendingOrder = '${ajax}trade/cancel-pending-order';
  static const String closePendingOrder = '${ajax}trade/closePendingOrder';
  static const String modifyPendingOrder = '${ajax}trade/modify-pending-order';
  static const String closePositions = '${ajax}trade/closePositions';
  static const String updateTPSL = '${ajax}trade/update-tp-sl';
  static const String updatePendingOrderTPSL = '${ajax}trade/update-pending-order-tp-sl';
  static const String tradeHistory = '${ajax}trade/tradehistory';
  static const String getInstruments = '${ajax}instruments';
  static const String logout = '${ajax}logout';
  static const String depositList = '${ajax}deposit';
  static const String depositRequest = '${ajax}deposit/depositrequest';
  static const String cregisDepositCreate = '${ajax}deposit/cregis';
  static const String cregisDepositStatus = '${ajax}deposit/by-reference';
  static const String realPlanDetails = '${ajax}mt5accounts/plandetails';
  static const String getTransactions = '${ajax}transactions';
  static const String depositProofProxy = '${ajax}deposit-proof-proxy/';
  // Bonus APIs
  static const String bonusList = '${ajax}bonus';
  static const String bonusClaimList = '${ajax}bonus/bonusClaimList';
  static const String bonusClaim = '${ajax}bonus/bonusClaim';
  static const String changePrimaryAccount =
      '${ajax}mt5accounts/changePrimaryAccount';
  static String getInstrumentsByAccount(String accountNumber) =>
      '${ajax}instruments/$accountNumber';

  // Dropdown APIs
  static const String getCountryDropdown = '${ajax}settings/getCountryDropdown';
  static const String getStateDropdown = '${ajax}settings/getStateDropdown';
  static const String getCityDropdown = '${ajax}settings/getCityDropdown';

  // KYC APIs
  static const String kycUpload = '${ajax}kyc/documents/upload';
  static const String kycStatus = '${ajax}kyc';
  static const String regulation = '${ajax}regulation';
  static const String kycProfileUpdate = '${ajax}kyc/profile';
  static const String submitUnifiedKyc = '${ajax}kyc/submit-unified';
  static const String checkMobile = '${ajax}auth/google/check-mobile';
  static const String getWalletData = '${ajax}internaltransfer';
  static const String getWalletDetailsNew = '${ajax}wallet';
  static const String currencyList = '${ajax}utility/currency-list';
  static const String withdrawalRequest = '${ajax}withdrawal';
  static const String withdrawalSendOTPRequest = '${ajax}withdrawal/sendOTP';
  static const String withdrawalSubmitRequest =
      '${ajax}withdrawal/withdrawalrequest';
  static const String checkBalance = '${ajax}withdrawal/checkbalance';
  static const String internalTransferRequest =
      '${ajax}internaltransfer/request';
  static const String internalTransferHistory =
      '${ajax}internaltransfer/history';
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
  static const String ibTrackVisit = '${ajax}ib/track-visit';
  static const String ibCommissionGroups = '${ajax}ib/commission-groups';
  static const String ibManage = '${ajax}ib/manage';
  static const String ibUpdateStatus = '${ajax}ib/update-status/';

  // Scratch Card APIs
  static const String getScratchCards   = 'v1/user/scratch-cards';
  static const String revealScratchCard = 'v1/user/scratch-cards/reveal';
  static const String getScratchLeaderboard = 'v1/user/scratch-cards/leaderboard';
  static const String convertScratchCreditToBalance =
      'v1/user/scratch-cards/convert-credit-to-balance';

  // App Status APIs (public; used before login for version / maintenance)
  static const String mobileAppDetails = '${ajax}mobile-app-details';
  static const String crmSettings = '${ajax}crm-settings';

  // Enabled modules (per-user feature flags)
  static const String enabledModules = '${ajax}enabled-modules';

  // Support Ticket APIs
  static const String ticketDepartments = '${ajax}tickets/departments';
  static const String tickets = '${ajax}tickets';
  static String ticketDetail(String ticketId) => '${ajax}tickets/$ticketId';
  static String ticketReply(String ticketId) => '${ajax}tickets/$ticketId/reply';
  static String ticketClose(String ticketId) => '${ajax}tickets/$ticketId/close';
  static const String ticketAttachment = '${ajax}tickets/attachment';

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
  /// + plans + payouts + recent_trades + alerts).
  /// Example: copytrading/master/dashboard-overview?range=30d
  ///
  /// PREFERRED: use [copyTradingMasterDashboardOverviewPath] and pass the
  /// `range` via `queryParameters` instead — `ApiService.get` uses
  /// `Uri.replace(queryParameters: …)` which strips any query string
  /// already in the endpoint, so inlining `?range=…` here gets silently
  /// dropped when callers also pass other query params (e.g. cache-buster).
  static String copyTradingMasterDashboardOverview({String range = '30d'}) =>
      '$copyTradingMasterDashboardOverviewPath?range=$range';

  /// Path-only form (no query string) of [copyTradingMasterDashboardOverview].
  /// Combine with `queryParameters: {'range': '7d', ...}` when calling
  /// `ApiService.get`.
  static const String copyTradingMasterDashboardOverviewPath =
      '${ajax}copytrading/master/dashboard-overview';

  static const String copyTradingMasterPlans = '${ajax}copytrading/master/plans';
  static String copyTradingMasterPlanOpenPositions(int planId) =>
      '$copyTradingMasterPlans/$planId/open-positions';
  static String copyTradingMasterOpenPositions(int planId) =>
      '$copyTradingMasterPlans/$planId/open-positions';
  static String copyTradingMasterPlanPause(int planId) =>
      '$copyTradingMasterPlans/$planId/pause';
  static String copyTradingMasterPlanResume(int planId) =>
      '$copyTradingMasterPlans/$planId/resume';
  static String copyTradingMasterPlanUpdate(int planId) =>
      '$copyTradingMasterPlans/$planId';
  static const String copyTradingCopierEligibleAccounts =
      '${ajax}copytrading/copier/eligible-accounts';
  static const String copyTradingCopierSubscribe =
      '${ajax}copytrading/copier/subscribe';
  static const String copyTradingCopierSubscriptions =
      '${ajax}copytrading/copier/subscriptions';
  static String copyTradingCopierSubscriptionsList({
    int page = 1,
    int perPage = 20,
  }) =>
      '${ajax}copytrading/copier/subscriptions?page=$page&per_page=$perPage';
  static String copyTradingMasterCopiers({int page = 1, int perPage = 20}) =>
      '${ajax}copytrading/master/copiers?page=$page&per_page=$perPage';
  static String copyTradingCopierSubscriptionDetail(int id) =>
      '${ajax}copytrading/copier/subscriptions/$id/detail';
  static String copyTradingCopierSubscriptionTrades(
    int id, {
    int page = 1,
    int limit = 20,
    int? t,
  }) =>
      '${ajax}copytrading/copier/subscriptions/$id/trades?page=$page&limit=$limit${t != null ? '&_t=$t' : ''}';
  static String copyTradingCopierSubscriptionPnlHistory(int id) =>
      '${ajax}copytrading/copier/subscriptions/$id/pnl-history';
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
  static const String copyTradingMasters = 'copytrading/masters';
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

  static String copyTradingCopierMasterProfile(String masterCode) =>
      '${ajax}copytrading/copier/masters/$masterCode';

  // // Profile APIs
  // static const String profileUpdate = '${ajax}profile_update.php';
  // static const String getProfile = '${ajax}profile';
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