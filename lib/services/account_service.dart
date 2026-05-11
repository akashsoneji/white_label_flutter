import 'package:get/get.dart';
import 'package:crm_app/models/account_models.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AccountService extends GetxService {
  Future<List<AccountModel>> getAccounts();
  Future<AccountModel?> getActiveAccount();
  Future<void> setActiveAccount(String accountId);
  Future<void> addAccount(AccountModel account);
  Future<void> updateAccount(AccountModel account);
  Future<void> deleteAccount(String accountId);
  Future<void> updateAccountBalance(String accountId, double newBalance);
  Future<void> resetToDefaultAccounts();
}

class AccountServiceImpl extends AccountService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _accountsKey = 'user_accounts';
  static const String _activeAccountKey = 'active_account_id';

  @override
  Future<List<AccountModel>> getAccounts() async {
    try {
      final accountsJson = await _storage.read(key: _accountsKey);

      if (accountsJson == null) {
        final defaultAccounts = _getDefaultAccounts();
        await _saveAccounts(defaultAccounts);
        return defaultAccounts;
      }

      final List<dynamic> accountsList = jsonDecode(accountsJson);
      final accounts =
          accountsList.map((json) => AccountModel.fromJson(json)).toList();

      if (accounts.isEmpty) {
        final defaultAccounts = _getDefaultAccounts();
        await _saveAccounts(defaultAccounts);
        return defaultAccounts;
      }

      return accounts;
    } catch (e) {
      print('AccountService getAccounts error: $e');
      final defaultAccounts = _getDefaultAccounts();
      await _saveAccounts(defaultAccounts);
      return defaultAccounts;
    }
  }

  @override
  Future<AccountModel?> getActiveAccount() async {
    try {
      final activeAccountId = await _storage.read(key: _activeAccountKey);

      if (activeAccountId == null) {
        final accounts = await getAccounts();
        if (accounts.isNotEmpty) {
          await setActiveAccount(accounts.first.id);
          return accounts.first;
        }
        return null;
      }

      final accounts = await getAccounts();
      return accounts.firstWhere(
        (account) => account.id == activeAccountId,
        orElse:
            () =>
                accounts.isNotEmpty
                    ? accounts.first
                    : _getDefaultAccounts().first,
      );
    } catch (e) {
      print('AccountService getActiveAccount error: $e');
      return null;
    }
  }

  @override
  Future<void> setActiveAccount(String accountId) async {
    try {
      await _storage.write(key: _activeAccountKey, value: accountId);

      final accounts = await getAccounts();
      final updatedAccounts =
          accounts.map((account) {
            return account.copyWith(isActive: account.id == accountId);
          }).toList();

      await _saveAccounts(updatedAccounts);
      await _simulateBalanceChange(accountId);
    } catch (e) {
      print('AccountService setActiveAccount error: $e');
    }
  }

  @override
  Future<void> addAccount(AccountModel account) async {
    try {
      final accounts = await getAccounts();
      accounts.add(account);
      await _saveAccounts(accounts);
    } catch (e) {
      print('AccountService addAccount error: $e');
    }
  }

  @override
  Future<void> updateAccount(AccountModel account) async {
    try {
      final accounts = await getAccounts();
      final index = accounts.indexWhere((a) => a.id == account.id);

      if (index != -1) {
        accounts[index] = account;
        await _saveAccounts(accounts);
      }
    } catch (e) {
      print('AccountService updateAccount error: $e');
    }
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    try {
      final accounts = await getAccounts();
      accounts.removeWhere((account) => account.id == accountId);
      await _saveAccounts(accounts);

      final activeAccount = await getActiveAccount();
      if (activeAccount?.id == accountId && accounts.isNotEmpty) {
        await setActiveAccount(accounts.first.id);
      }
    } catch (e) {
      print('AccountService deleteAccount error: $e');
    }
  }

  @override
  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    try {
      final accounts = await getAccounts();
      final index = accounts.indexWhere((account) => account.id == accountId);

      if (index != -1) {
        accounts[index] = accounts[index].copyWith(balance: newBalance);
        await _saveAccounts(accounts);
      }
    } catch (e) {
      print('AccountService updateAccountBalance error: $e');
    }
  }

  @override
  Future<void> resetToDefaultAccounts() async {
    try {
      final defaultAccounts = _getDefaultAccounts();
      await _saveAccounts(defaultAccounts);

      if (defaultAccounts.isNotEmpty) {
        await setActiveAccount(defaultAccounts.first.id);
      }
    } catch (e) {
      print('AccountService resetToDefaultAccounts error: $e');
    }
  }

  Future<void> _saveAccounts(List<AccountModel> accounts) async {
    try {
      final accountsJson = jsonEncode(
        accounts.map((account) => account.toJson()).toList(),
      );
      await _storage.write(key: _accountsKey, value: accountsJson);
    } catch (e) {
      print('AccountService _saveAccounts error: $e');
    }
  }

  Future<void> _simulateBalanceChange(String accountId) async {
    try {
      final accounts = await getAccounts();
      final accountIndex = accounts.indexWhere(
        (account) => account.id == accountId,
      );

      if (accountIndex != -1) {
        final baseBalance = accounts[accountIndex].balance;
        final randomChange = (DateTime.now().millisecondsSinceEpoch % 100) - 50;
        final newBalance = baseBalance + (randomChange * 0.1);

        accounts[accountIndex] = accounts[accountIndex].copyWith(
          balance: double.parse(newBalance.toStringAsFixed(2)),
        );

        await _saveAccounts(accounts);
      }
    } catch (e) {
      print('AccountService _simulateBalanceChange error: $e');
    }
  }

  List<AccountModel> _getDefaultAccounts() {
    return [];
  }
}
