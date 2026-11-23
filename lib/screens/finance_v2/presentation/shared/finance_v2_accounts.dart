import 'package:get/get.dart';

import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/models/mt5_account.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';
import 'package:crm_app/screens/wallet/data/repositories/wallet_repository.dart';
import 'package:crm_app/screens/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';

import '../widgets/finance_account_option.dart';

const String _walletCurrency = 'USD';

/// The accounts a finance_v2 deposit or withdrawal can use: the wallet first,
/// then the live MT5 accounts (demo accounts are left out).
///
/// Reuses the calls the app already makes (wallet details and
/// mt5accounts/get). A source that fails is skipped, so the list is empty
/// only when neither answered. With [forWithdrawal] an MT5 account shows its
/// free margin, the part that can be taken out, instead of its balance.
Future<List<FinanceAccountOption>> loadFinanceV2Accounts({
  bool forWithdrawal = false,
}) async {
  final token = await SecureStorageService.getAuthToken() ?? '';
  final results = await Future.wait(<Future<List<FinanceAccountOption>>>[
    _loadWallet(token),
    _loadLiveAccounts(token, forWithdrawal: forWithdrawal),
  ]);
  return <FinanceAccountOption>[...results[0], ...results[1]];
}

/// Maps the `data` object of the wallet details answer. Empty when the client
/// has no wallet.
List<FinanceAccountOption> financeV2WalletOptions(dynamic walletData) {
  if (walletData is! Map) return const <FinanceAccountOption>[];
  final walletId = (walletData['wallet_id'] ?? '').toString().trim();
  if (walletId.isEmpty) return const <FinanceAccountOption>[];
  final balance =
      (walletData['balance'] ?? walletData['wallet_balance'] ?? '').toString();

  return <FinanceAccountOption>[
    FinanceAccountOption(
      id: walletId,
      title: TranslationUtils.tr('wallet'),
      subtitle: walletId,
      balanceText: _balanceText(balance, _walletCurrency),
      isWallet: true,
    ),
  ];
}

/// Maps the rows of mt5accounts/get, keeping only live accounts.
List<FinanceAccountOption> financeV2Mt5Options(
  List<MT5Account> accounts, {
  bool forWithdrawal = false,
}) {
  return accounts
      .where(
        (account) =>
            account.isRealAccount && account.metaAccountNumber.isNotEmpty,
      )
      .map(
        (account) => FinanceAccountOption(
          id: account.metaAccountNumber,
          title: account.metaAccountNumber,
          subtitle: account.mt5NickName.isNotEmpty
              ? account.mt5NickName
              : account.platformDisplayName,
          balanceText: _balanceText(
            forWithdrawal ? account.freeMargin : account.balance,
            account.currency,
          ),
        ),
      )
      .toList(growable: false);
}

Future<List<FinanceAccountOption>> _loadWallet(String token) async {
  try {
    final repo = Get.isRegistered<WalletRepository>()
        ? Get.find<WalletRepository>()
        : WalletRepositoryImpl(Get.find<ApiClient>());
    final response = await repo.getWalletDetailsNew(token: token);
    return financeV2WalletOptions(_envelopeData(response));
  } catch (_) {
    // A wallet that cannot be read must not hide the MT5 accounts.
    return const <FinanceAccountOption>[];
  }
}

Future<List<FinanceAccountOption>> _loadLiveAccounts(
  String token, {
  required bool forWithdrawal,
}) async {
  try {
    final response =
        await Get.find<FinanceRepository>().getMt5Accounts(token: token);
    final rows = _envelopeData(response);
    if (rows is! List) return const <FinanceAccountOption>[];
    final accounts = rows
        .whereType<Map>()
        .map((row) => MT5Account.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    return financeV2Mt5Options(accounts, forWithdrawal: forWithdrawal);
  } catch (_) {
    // Same as the wallet: the other source is still offered.
    return const <FinanceAccountOption>[];
  }
}

dynamic _envelopeData(ApiResponse response) {
  final body = response.data;
  if (!response.success || body is! Map) return null;
  return body['data'];
}

String? _balanceText(String amount, String currency) {
  final value = amount.trim();
  if (value.isEmpty) return null;
  return currency.isEmpty ? value : '$value $currency';
}
