import 'dart:io';

import 'package:crm_app/core/network/api_response.dart';

abstract class KycRepository {
  Future<ApiResponse> getCurrencyList({required String token});

  Future<ApiResponse> getBankWithdrawalList({required String token});

  Future<ApiResponse> sendOtp({required String token});

  Future<ApiResponse> submitWithdrawalRequest({
    required String token,
    required Map<String, dynamic> payload,
  });

  Future<ApiResponse> getKycStatus({required String token});

  Future<ApiResponse> uploadKycDocument({
    required String token,
    required File file,
    required Map<String, dynamic> formData,
    void Function(double progress)? onProgress,
  });
}

