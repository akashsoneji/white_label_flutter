# White Label App — Exhaustive Screen/API Inventory

Generated from current `lib/` source. Screen implementation files scanned: **261**.

## Interpretation

- API ownership is controller/repository/service based; screens without direct constants inherit the listed controller path.
- Export-only brand wrappers are recorded as aliases and are not counted as independent API implementations.
- `api_refs` are source references, not guessed endpoint paths. Resolve constants from `lib/constants/api_const.dart` and IBM provider maps.
- Local logic flags identify wrapper, WebView, timer/polling, persistence, or no-direct-API screens.

## Auth (24 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `IquoteCreateAccountScreen` | `lib/screens/auth/presentation/brands/iquote/pages/iquote_create_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `RiyadexCreateAccountScreen` | `lib/screens/auth/presentation/brands/riyadex/pages/riyadex_create_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `RiyadexGetStartedScreen` | `lib/screens/auth/presentation/brands/riyadex/pages/riyadex_get_started_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `account_created_screen` | `lib/screens/auth/presentation/brands/vantage/pages/account_created_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `VantageCreateAccountScreen` | `lib/screens/auth/presentation/brands/vantage/pages/create_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `VantageCreateNewPasswordScreen` | `lib/screens/auth/presentation/brands/vantage/pages/create_new_password_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `VantageForgotPasswordScreen` | `lib/screens/auth/presentation/brands/vantage/pages/forgot_password_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `VantageGetStartedScreen` | `lib/screens/auth/presentation/brands/vantage/pages/get_started_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `legal_documents_screen` | `lib/screens/auth/presentation/brands/vantage/pages/legal_documents_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `VantageLoginScreen` | `lib/screens/auth/presentation/brands/vantage/pages/login_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `privacy_policy_screen` | `lib/screens/auth/presentation/brands/vantage/pages/privacy_policy_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `splash_screen` | `lib/screens/auth/presentation/brands/vantage/pages/splash_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `VantageVerifyCodeScreen` | `lib/screens/auth/presentation/brands/vantage/pages/verify_code_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `AccountCreatedScreen` | `lib/screens/auth/presentation/pages/account_created_screen.dart` | `ACCOUNT_CREATED` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CreateAccountScreen` | `lib/screens/auth/presentation/pages/create_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CreateNewPasswordScreen` | `lib/screens/auth/presentation/pages/create_new_password_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ForgotPasswordScreen` | `lib/screens/auth/presentation/pages/forgot_password_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `GetStartedScreen` | `lib/screens/auth/presentation/pages/get_started_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `GoogleLoginOtpScreen` | `lib/screens/auth/presentation/pages/google_login_otp_screen.dart` | `GOOGLE_LOGIN_OTP` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `LegalDocumentsScreen` | `lib/screens/auth/presentation/pages/legal_documents_screen.dart` | `LEGAL_DOCUMENTS` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `LoginScreen` | `lib/screens/auth/presentation/pages/login_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation |
| `PrivacyPolicyScreen` | `lib/screens/auth/presentation/pages/privacy_policy_screen.dart` | `PRIVACY_POLICY` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `SplashScreen` | `lib/screens/auth/presentation/pages/splash_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation; timer/delayed UI or polling logic |
| `VerifyCodeScreen` | `lib/screens/auth/presentation/pages/verify_code_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |

## Bonus (4 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `bonus_screen` | `lib/screens/bonus/presentation/brands/xelthio/pages/bonus_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `scratch_card_screen` | `lib/screens/bonus/presentation/brands/xelthio/pages/scratch_card_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `EligibleBonus` | `lib/screens/bonus/presentation/pages/bonus_screen.dart` | `embedded / no GetPage` | `bonusClaim, bonusClaimList, bonusList` | screen-local presentation only |
| `ScratchCardApiModel` | `lib/screens/bonus/presentation/pages/scratch_card_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |

## Brand / Core (19 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `CelestialChartScreen` | `lib/brands/celestial/celestial_chart_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation |
| `CelestialHistoryScreen` | `lib/brands/celestial/celestial_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CelestialSettingsScreen` | `lib/brands/celestial/celestial_settings_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `CelestialTradeScreen` | `lib/brands/celestial/celestial_trade_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `CelestialTradingAccountScreen` | `lib/brands/celestial/celestial_trading_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CelestialWatchlistScreen` | `lib/brands/celestial/celestial_watchlist_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `DemoGetStartedScreen` | `lib/brands/demo/ui/demo_get_started_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MetaChartScreen` | `lib/brands/meta/meta_chart_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation |
| `MetaClosePositionScreen` | `lib/brands/meta/meta_close_position_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MetaHistoryScreen` | `lib/brands/meta/meta_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MetaModifyPositionScreen` | `lib/brands/meta/meta_modify_position_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MetaNewOrderScreen` | `lib/brands/meta/meta_new_order_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MetaSettingsScreen` | `lib/brands/meta/meta_settings_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `MetaTradeScreen` | `lib/brands/meta/meta_trade_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation; timer/delayed UI or polling logic |
| `MetaTradingAccountScreen` | `lib/brands/meta/meta_trading_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MetaWatchlistScreen` | `lib/brands/meta/meta_watchlist_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `WebViewScreen` | `lib/screens/common/webview_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation |
| `ExampleRTLComponentsScreen` | `lib/screens/example_rtl_components_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ExampleUpdatedScreen` | `lib/screens/example_updated_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |

## Copy Trading (13 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `AddInvestmentScreen` | `lib/screens/copy_trading/add_investment_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ChangeProportionScreen` | `lib/screens/copy_trading/change_proportion_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CopyTradingMainScreen` | `lib/screens/copy_trading/copy_trading_main_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CopyTradingDepositScreen` | `lib/screens/copy_trading/finance/deposit_screen.dart` | `COPY_TRADING_DEPOSIT` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CopyTradingInternalTransferScreen` | `lib/screens/copy_trading/finance/internal_transfer_screen.dart` | `COPY_TRADING_INTERNAL_TRANSFER` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CopyTradingPaymentMethodsScreen` | `lib/screens/copy_trading/finance/payment_methods_screen.dart` | `COPY_TRADING_PAYMENT_METHODS` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `InvestmentDetailScreen` | `lib/screens/copy_trading/investment_detail_screen.dart` | `embedded / no GetPage` | `copyTradingCopierSubscriptionDetail, copyTradingCopierSubscriptionTrades` | screen-local presentation only |
| `ReduceInvestmentScreen` | `lib/screens/copy_trading/reduce_investment_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CopyTradingInviteFriendScreen` | `lib/screens/copy_trading/settings/invite_friend_screen.dart` | `COPY_TRADING_INVITE_FRIEND` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CopyTradingWalletScreen` | `lib/screens/copy_trading/settings/wallet_screen.dart` | `ORDER_CONFIRMATION` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `SubscriptionSetupScreen` | `lib/screens/copy_trading/subscription_setup_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TraderDetailsScreen` | `lib/screens/copy_trading/trader_details_screen.dart` | `TRADER_DETAILS` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TradersFilterScreen` | `lib/screens/copy_trading/traders_filter_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |

## Demo Contest (9 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `demo_contest_screen` | `lib/screens/demo_contest/presentation/brands/xelthio/pages/demo_contest_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `ContestDetailsScreen` | `lib/screens/demo_contest/presentation/pages/contest_details_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `ContestRulesScreen` | `lib/screens/demo_contest/presentation/pages/contest_rules_screen.dart` | `DEMO_CONTEST_RULES` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `DemoContestMyStatsScreen` | `lib/screens/demo_contest/presentation/pages/demo_contest_my_stats_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `DemoContestScreen` | `lib/screens/demo_contest/presentation/pages/demo_contest_screen.dart` | `DEMO_CONTEST` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `JoinContestScreen` | `lib/screens/demo_contest/presentation/pages/join_contest_screen.dart` | `DEMO_CONTEST_JOIN` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `LeaderboardScreen` | `lib/screens/demo_contest/presentation/pages/leaderboard_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MyContestHistoryScreen` | `lib/screens/demo_contest/presentation/pages/my_contest_history_screen.dart` | `DEMO_CONTEST_DETAILS` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `WinnersScreen` | `lib/screens/demo_contest/presentation/pages/winners_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |

## Finance (23 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `deposit_camera_screen` | `lib/screens/finance/presentation/brands/vantage/pages/deposit_camera_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `deposit_instruction_screen` | `lib/screens/finance/presentation/brands/vantage/pages/deposit_instruction_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `deposit_real_screen` | `lib/screens/finance/presentation/brands/vantage/pages/deposit_real_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `DepositScreen` | `lib/screens/finance/presentation/brands/vantage/pages/deposit_screen.dart` | `DEPOSIT` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `finance_screen` | `lib/screens/finance/presentation/brands/vantage/pages/finance_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `InternalTransferScreen` | `lib/screens/finance/presentation/brands/vantage/pages/internal_transfer_screen.dart` | `INTERNAL_TRANSFER` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PaymentMethodsScreen` | `lib/screens/finance/presentation/brands/vantage/pages/payment_methods_screen.dart` | `PAYMENT_METHOD` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `VantageTransactionHistoryScreen` | `lib/screens/finance/presentation/brands/vantage/pages/transaction_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `WalletScreen` | `lib/screens/finance/presentation/brands/vantage/pages/wallet_screen.dart` | `WALLET` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `WithdrawalScreen` | `lib/screens/finance/presentation/brands/vantage/pages/withdrawal_screen.dart` | `WITHDRAWAL` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CregisAddressScreen` | `lib/screens/finance/presentation/pages/cregis_address_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `CregisSuccessScreen` | `lib/screens/finance/presentation/pages/cregis_success_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `DepositCameraScreen` | `lib/screens/finance/presentation/pages/deposit_camera_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `DepositInstructionScreen` | `lib/screens/finance/presentation/pages/deposit_instruction_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `DepositRealScreen` | `lib/screens/finance/presentation/pages/deposit_real_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `DepositScreen` | `lib/screens/finance/presentation/pages/deposit_screen.dart` | `DEPOSIT` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `FinanceScreen` | `lib/screens/finance/presentation/pages/finance_screen.dart` | `FINANCE` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `InternalTransferHistoryScreen` | `lib/screens/finance/presentation/pages/internal_transfer_history_screen.dart` | `INTERNAL_TRANSFER_HISTORY` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `InternalTransferScreen` | `lib/screens/finance/presentation/pages/internal_transfer_screen.dart` | `INTERNAL_TRANSFER` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `PaymentMethodsScreen` | `lib/screens/finance/presentation/pages/payment_methods_screen.dart` | `PAYMENT_METHOD` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TransactionHistoryScreen` | `lib/screens/finance/presentation/pages/transaction_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `WalletScreen` | `lib/screens/finance/presentation/pages/wallet_screen.dart` | `WALLET` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `WithdrawalScreen` | `lib/screens/finance/presentation/pages/withdrawal_screen.dart` | `WITHDRAWAL` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |

## IB (48 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `commission_group_form_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/commission_group_form_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `commission_groups_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/commission_groups_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `commission_history_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/commission_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `ib_clients_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/ib_clients_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `ib_dashboard_new_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/ib_dashboard_new_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `ib_dashboard_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/ib_dashboard_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `ib_main_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/ib_main_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `ib_more_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/ib_more_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `ib_requests_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/ib_requests_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `ib_structure_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/ib_structure_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `ib_support_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/ib_support_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `marketing_tools_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/marketing_tools_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `my_clients_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/my_clients_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `my_structure_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/my_structure_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `overview_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/overview_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `payout_request_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/payout_request_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `referral_links_screen` | `lib/screens/ib/presentation/brands/xelthio/pages/referral_links_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `CommissionGroupFormScreen` | `lib/screens/ib/presentation/pages/commission_group_form_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CommissionGroupsScreen` | `lib/screens/ib/presentation/pages/commission_groups_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CommissionHistoryScreen` | `lib/screens/ib/presentation/pages/commission_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IBClientsScreen` | `lib/screens/ib/presentation/pages/ib_clients_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbCombinedStructureScreen` | `lib/screens/ib/presentation/pages/ib_combined_structure_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbDashboardNewScreen` | `lib/screens/ib/presentation/pages/ib_dashboard_new_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `IbDashboardScreen` | `lib/screens/ib/presentation/pages/ib_dashboard_screen.dart` | `IB_DASHBOARD` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbMainScreen` | `lib/screens/ib/presentation/pages/ib_main_screen.dart` | `IB_MAIN` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `IBMoreScreen` | `lib/screens/ib/presentation/pages/ib_more_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IBRequestsScreen` | `lib/screens/ib/presentation/pages/ib_requests_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IBStructureScreen` | `lib/screens/ib/presentation/pages/ib_structure_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbSupportScreen` | `lib/screens/ib/presentation/pages/ib_support_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbTransferCommissionScreen` | `lib/screens/ib/presentation/pages/ib_transfer_commission_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbTransferCreateScreen` | `lib/screens/ib/presentation/pages/ib_transfer_create_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `MarketingToolsScreen` | `lib/screens/ib/presentation/pages/marketing_tools_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MyClientsScreen` | `lib/screens/ib/presentation/pages/my_clients_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `MyStructureScreen` | `lib/screens/ib/presentation/pages/my_structure_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `OverviewScreen` | `lib/screens/ib/presentation/pages/overview_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PayoutRequestScreen` | `lib/screens/ib/presentation/pages/payout_request_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ReferralLinksScreen` | `lib/screens/ib/presentation/pages/referral_links_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CreateEditPlanScreen` | `lib/screens/ibm/presentation/pages/create_edit_plan_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbmApplicationScreen` | `lib/screens/ibm/presentation/pages/ibm_application_screen.dart` | `IBM_APPLICATION` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbmClientProfileScreen` | `lib/screens/ibm/presentation/pages/ibm_client_profile_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbmClientsScreen` | `lib/screens/ibm/presentation/pages/ibm_clients_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbmLinksScreen` | `lib/screens/ibm/presentation/pages/ibm_links_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbmManagerPortalScreen` | `lib/screens/ibm/presentation/pages/ibm_manager_portal_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbmMarketingScreen` | `lib/screens/ibm/presentation/pages/ibm_marketing_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbmMoreScreen` | `lib/screens/ibm/presentation/pages/ibm_more_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbmPromotionScreen` | `lib/screens/ibm/presentation/pages/ibm_promotion_screen.dart` | `embedded / no GetPage` | `tradeWinClaim` | screen-local presentation only |
| `IbmSettingsScreen` | `lib/screens/ibm/presentation/pages/ibm_settings_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IbmWalletScreen` | `lib/screens/ibm/presentation/pages/ibm_wallet_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |

## KYC (16 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `bank_list_screen` | `lib/screens/kyc/presentation/brands/xelthio/pages/bank_list_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `kyc_bank_camera_screen` | `lib/screens/kyc/presentation/brands/xelthio/pages/kyc_bank_camera_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `kyc_bank_screen` | `lib/screens/kyc/presentation/brands/xelthio/pages/kyc_bank_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `kyc_camera_screen` | `lib/screens/kyc/presentation/brands/xelthio/pages/kyc_camera_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `kyc_details_screen` | `lib/screens/kyc/presentation/brands/xelthio/pages/kyc_details_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `kyc_docs_screen` | `lib/screens/kyc/presentation/brands/xelthio/pages/kyc_docs_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `kyc_intro_screen` | `lib/screens/kyc/presentation/brands/xelthio/pages/kyc_intro_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `kyc_success_screen` | `lib/screens/kyc/presentation/brands/xelthio/pages/kyc_success_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `BankListScreen` | `lib/screens/kyc/presentation/pages/bank_list_screen.dart` | `BANK_LIST` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `KycBankCameraScreen` | `lib/screens/kyc/presentation/pages/kyc_bank_camera_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `KycBankScreen` | `lib/screens/kyc/presentation/pages/kyc_bank_screen.dart` | `KYC_BANK` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `KycCameraScreen` | `lib/screens/kyc/presentation/pages/kyc_camera_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `KycDetailsScreen` | `lib/screens/kyc/presentation/pages/kyc_details_screen.dart` | `KYC_DETAILS` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `KycDocsScreen` | `lib/screens/kyc/presentation/pages/kyc_docs_screen.dart` | `KYC_DOCS` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `KycIntroScreen` | `lib/screens/kyc/presentation/pages/kyc_intro_screen.dart` | `KYC_INTRO` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `KycSuccessScreen` | `lib/screens/kyc/presentation/pages/kyc_success_screen.dart` | `KYC_SUCCESS` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |

## More / Settings (5 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `NotificationsScreen` | `lib/screens/notifications/presentation/pages/notifications_screen.dart` | `NOTIFICATIONS` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `account_management_screen` | `lib/screens/settings/presentation/brands/xelthio/pages/account_management_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `language_selector_screen` | `lib/screens/settings/presentation/brands/xelthio/pages/language_selector_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `AccountManagementScreen` | `lib/screens/settings/presentation/pages/account_management_screen.dart` | `ACCOUNT_MANAGEMENT` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `LanguageSelectorScreen` | `lib/screens/settings/presentation/pages/language_selector_screen.dart` | `LANGUAGE_SELECTOR` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |

## Other (3 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `FeatureUnavailableScreen` | `lib/core/routing/feature_unavailable_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MaintenanceScreen` | `lib/services/app_status/maintenance_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `NoInternetScreen` | `lib/services/connectivity/no_internet_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |

## Trade & Win (5 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `TradeWinMainScreen` | `lib/screens/trade_win/trade_win_main_screen.dart` | `TRADE_WIN_MAIN` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TradeWinPastWinDetailScreen` | `lib/screens/trade_win/trade_win_past_win_detail_screen.dart` | `TRADE_WIN_PAST_WIN_DETAIL` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TradeWinProductDetailScreen` | `lib/screens/trade_win/trade_win_product_detail_screen.dart` | `TRADE_WIN_PRODUCT_DETAIL` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TradeWinRedeemScreen` | `lib/screens/trade_win/trade_win_redeem_screen.dart` | `TRADE_WIN_REDEEM` | `tradeWinSavedAddresses` | screen-local presentation only |
| `TradeWinRedemptionSuccessScreen` | `lib/screens/trade_win/trade_win_redemption_success_screen.dart` | `TRADE_WIN_REDEMPTION_SUCCESS` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |

## Trading (92 screens)

| Screen | File | Route | API references | Local/API ownership |
|---|---|---|---|---|
| `IQuoteChartScreen` | `lib/screens/home/brands/iquote/iquote_chart_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation |
| `IquoteMarketScreen` | `lib/screens/home/brands/iquote/iquote_market_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IQuoteOrderDetailsScreen` | `lib/screens/home/brands/iquote/iquote_order_details_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IQuotePositionDetailScreen` | `lib/screens/home/brands/iquote/iquote_position_detail_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IQuotePositionScreen` | `lib/screens/home/brands/iquote/iquote_position_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ChangeLeverageScreen` | `lib/screens/home/change_leverage_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ChangePasswordScreen` | `lib/screens/home/change_password_screen.dart` | `CHANGE_PASSWORD` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ChartScreen` | `lib/screens/home/chart_screen.dart` | `CHART` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation; timer/delayed UI or polling logic |
| `ChooseAccountScreen` | `lib/screens/home/choose_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ClosePositionScreen` | `lib/screens/home/close_position_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation; timer/delayed UI or polling logic |
| `CreateCrmAppAccountScreen` | `lib/screens/home/create_crm_app_account_screen.dart` | `CHOOSE_ACCOUNT` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `DashboardScreen` | `lib/screens/home/dashboard_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `EditOrderScreen` | `lib/screens/home/edit_order_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation; timer/delayed UI or polling logic |
| `InstrumentsScreen` | `lib/screens/home/instruments_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `IquoteHomeScreen` | `lib/screens/home/iquote_home_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `CameraScreen` | `lib/screens/home/more/camera_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ChatWithUsScreen` | `lib/screens/home/more/chat_with_us_screen.dart` | `CHAT_WITH_US` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CopyTradingCreatePlanScreen` | `lib/screens/home/more/copytrading/copy_trading_create_plan_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CopyTradingEditPlanScreen` | `lib/screens/home/more/copytrading/copy_trading_edit_plan_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CopyTradingHubScreen` | `lib/screens/home/more/copytrading/copy_trading_hub_screen.dart` | `COPY_TRADING_MAIN` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ExploreMastersScreen` | `lib/screens/home/more/copytrading/explore_masters_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MasterDashboardScreen` | `lib/screens/home/more/copytrading/master_dashboard_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MasterDetailsScreen` | `lib/screens/home/more/copytrading/master_details_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MasterPlanDetailScreen` | `lib/screens/home/more/copytrading/master_plan_detail_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MyCopiesScreen` | `lib/screens/home/more/copytrading/my_copies_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MyInvestmentsScreen` | `lib/screens/home/more/copytrading/my_investments_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `SubscribeToPlanScreen` | `lib/screens/home/more/copytrading/subscribe_to_plan_screen.dart` | `embedded / no GetPage` | `copyTradingCopierSubscriptionDetail` | screen-local presentation only |
| `EditProfile` | `lib/screens/home/more/edit_profile_screen.dart` | `EDIT_PROFILE` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `IdUploadScreen` | `lib/screens/home/more/id_upload_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `KycVerificationScreen` | `lib/screens/home/more/kyc_verification_screen.dart` | `TRANSACTION_HISTORY` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `MoreScreen` | `lib/screens/home/more/more_screen.dart` | `MORE` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `OneClickTradingDisclaimerScreen` | `lib/screens/home/more/one_click_trading_disclaimer_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PartnershipProgramScreen` | `lib/screens/home/more/partnership_program_screen.dart` | `PARTNERSHIP_PROGRAM` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `PmamBecomeManagerScreen` | `lib/screens/home/more/pmam/pmam_become_manager_screen.dart` | `PMAM_BECOME_MANAGER` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamCreatePlanScreen` | `lib/screens/home/more/pmam/pmam_create_plan_screen.dart` | `PMAM_CREATE_PLAN` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamExploreManagersScreen` | `lib/screens/home/more/pmam/pmam_explore_managers_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamFundManagerViewScreen` | `lib/screens/home/more/pmam/pmam_fund_manager_view_screen.dart` | `PMAM_FUND_MANAGER_VIEW` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamInvestorPortalScreen` | `lib/screens/home/more/pmam/pmam_investor_portal_screen.dart` | `PMAM_INVESTOR_PORTAL` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `PmamMainScreen` | `lib/screens/home/more/pmam/pmam_main_screen.dart` | `PMAM_MAIN` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamManagerDashboardScreen` | `lib/screens/home/more/pmam/pmam_manager_dashboard_screen.dart` | `PMAM_MANAGER_DASHBOARD` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamManagerDetailScreen` | `lib/screens/home/more/pmam/pmam_manager_detail_screen.dart` | `PMAM_MANAGER_DETAIL` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamManagerInvestorDetailScreen` | `lib/screens/home/more/pmam/pmam_manager_investor_detail_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamManagerPlanDetailScreen` | `lib/screens/home/more/pmam/pmam_manager_plan_detail_screen.dart` | `PMAM_MANAGER_PLAN_DETAIL` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamManagerPortalScreen` | `lib/screens/home/more/pmam/pmam_manager_portal_screen.dart` | `PMAM_MANAGER_PORTAL` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamMyInvestmentScreen` | `lib/screens/home/more/pmam/pmam_my_investment_screen.dart` | `PMAM_MY_INVESTMENT` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PmamTradeHistoryScreen` | `lib/screens/home/more/pmam/pmam_trade_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PromotionalScreen` | `lib/screens/home/more/promotional/promotional_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `SettingScreen` | `lib/screens/home/more/setting/setting_screen.dart` | `SETTING` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `SupportScreen` | `lib/screens/home/more/support/support_screen.dart` | `SUPPORT` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `CreateTicketScreen` | `lib/screens/home/more/ticket/create_ticket_screen.dart` | `TICKET_CREATE` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TicketDetailScreen` | `lib/screens/home/more/ticket/ticket_detail_screen.dart` | `TICKET_DETAIL` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TicketListScreen` | `lib/screens/home/more/ticket/ticket_list_screen.dart` | `TICKET_LIST` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ToolsEducationScreen` | `lib/screens/home/more/tools_education/tools_education_screen.dart` | `TOOLS_EDUCATION` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TwoFactorAuthScreen` | `lib/screens/home/more/two_factor_auth_screen.dart` | `TWO_FACTOR_AUTH` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `ViewProfileScreen` | `lib/screens/home/more/view_profile_screen.dart` | `VIEW_PROFILE` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `OpenAccountScreen` | `lib/screens/home/open_account_screen.dart` | `OPEN_ACCOUNT` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `OrderConfirmationScreen` | `lib/screens/home/order_confirmation_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `CloseOrderScreen` | `lib/screens/home/order_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `PendingOrderScreen` | `lib/screens/home/pending_order_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation; timer/delayed UI or polling logic |
| `SearchInstrumentsScreen` | `lib/screens/home/search_instruments_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service |
| `TabMetricConfig` | `lib/screens/home/trade_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; timer/delayed UI or polling logic |
| `TradingMainScreen` | `lib/screens/home/trading_main_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | no direct endpoint reference; inspect injected controller/service; WebView/chart or external navigation |
| `change_leverage_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/change_leverage_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `change_password_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/change_password_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `chart_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/chart_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `choose_account_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/choose_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `close_position_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/close_position_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `create_crm_app_account_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/create_crm_app_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `dashboard_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/dashboard_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `edit_order_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/edit_order_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `instruments_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/instruments_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `open_account_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/open_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `order_confirmation_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/order_confirmation_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `order_history_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/order_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `pending_order_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/pending_order_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `trade_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/trade_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `trading_main_screen` | `lib/screens/trading/presentation/brands/xelthio/pages/trading_main_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `change_leverage_screen` | `lib/screens/trading/presentation/pages/change_leverage_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `change_password_screen` | `lib/screens/trading/presentation/pages/change_password_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `chart_screen` | `lib/screens/trading/presentation/pages/chart_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `choose_account_screen` | `lib/screens/trading/presentation/pages/choose_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `close_position_screen` | `lib/screens/trading/presentation/pages/close_position_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `create_crm_app_account_screen` | `lib/screens/trading/presentation/pages/create_crm_app_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `dashboard_screen` | `lib/screens/trading/presentation/pages/dashboard_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `edit_order_screen` | `lib/screens/trading/presentation/pages/edit_order_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `instruments_screen` | `lib/screens/trading/presentation/pages/instruments_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `open_account_screen` | `lib/screens/trading/presentation/pages/open_account_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `order_confirmation_screen` | `lib/screens/trading/presentation/pages/order_confirmation_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `order_history_screen` | `lib/screens/trading/presentation/pages/order_history_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `pending_order_screen` | `lib/screens/trading/presentation/pages/pending_order_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `trade_screen` | `lib/screens/trading/presentation/pages/trade_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |
| `trading_main_screen` | `lib/screens/trading/presentation/pages/trading_main_screen.dart` | `embedded / no GetPage` | `inherited/controller-owned` | export/wrapper; API owned by shared target |

## Shared local/API logic

- `ApiService` attaches bearer authentication, retries, parses errors, and handles global unauthenticated redirects.
- Trading screens consume market-watch/symbols/open-position/pending-order WebSockets; chart history uses direct `chartBaseUrl/charthistory` REST.
- Finance, wallet, IB, IBM, copy trading, PMAM, KYC, bonus, contest, Trade & Win, and tickets are controller/repository/service backed; UI wrappers inherit those APIs.
- Vantage-family and Pipze screens share implementation; only `FlavorConfig` URLs and brand UI/features vary.

