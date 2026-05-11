import 'dart:io';

import 'package:crm_app/core/network/api_response.dart';

abstract class FinanceRepository {
  // Deposits
  Future<ApiResponse> topupDemoAccount({
    required String token,
    required Map<String, dynamic> payload,
  });

  Future<ApiResponse> getDepositMethodDetail({
    required String token,
    required String slug,
  });

  Future<ApiResponse> getDepositMethods({required String token});

  Future<ApiResponse> submitDepositRequestWithProof({
    required String token,
    required String endpoint,
    required File file,
    required Map<String, dynamic> formData,
  });

  // Withdrawals
  Future<ApiResponse> getWithdrawalMethods({required String token});

  Future<ApiResponse> getWithdrawalMethodDetail({
    required String token,
    required String slug,
  });

  Future<ApiResponse> sendWithdrawalOtp({
    required String token,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> submitWithdrawal({
    required String token,
    required Map<String, dynamic> payload,
  });

  // Transactions
  Future<ApiResponse> getTransactions({required String token});

  // Accounts (used by finance screens today)
  Future<ApiResponse> getMt5Accounts({required String token});

  Future<ApiResponse> syncMt5Accounts({String? token});

  Future<ApiResponse> changePrimaryAccount({
    String? token,
    required Map<String, dynamic> data,
  });

  Future<ApiResponse> createMt5Account({
    String? token,
    required Map<String, dynamic> data,
  });

  Future<ApiResponse> postRealPlanDetails({
    String? token,
    required Map<String, dynamic> data,
  });

  /// Multipart form POST for withdrawal method add (fields only; same as [ApiClient.postForm]).
  Future<ApiResponse> postWithdrawalRequestForm({
    required String token,
    required Map<String, dynamic> formData,
  });
}

