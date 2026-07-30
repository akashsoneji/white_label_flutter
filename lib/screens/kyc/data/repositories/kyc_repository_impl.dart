import 'dart:io';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

import 'kyc_repository.dart';

class KycRepositoryImpl implements KycRepository {
  final ApiClient _api;
  KycRepositoryImpl(this._api);

  @override
  Future<ApiResponse> getCurrencyList({required String token}) {
    return _api.get(endpoint: ApiConstants.currencyList, token: token);
  }

  @override
  Future<ApiResponse> getBankWithdrawalList({required String token}) {
    return _api.get(endpoint: ApiConstants.bankWithdrawalList, token: token);
  }

  @override
  Future<ApiResponse> sendOtp({required String token}) {
    return _api.get(endpoint: ApiConstants.withdrawalSendOTPRequest, token: token);
  }

  @override
  Future<ApiResponse> submitWithdrawalRequest({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    return _api.post(endpoint: ApiConstants.withdrawalRequest, token: token, data: payload);
  }

  @override
  Future<ApiResponse> getKycStatus({required String token}) {
    return _api.get(endpoint: ApiConstants.kycStatus, token: token);
  }

  @override
  Future<ApiResponse> uploadKycDocument({
    required String token,
    required File file,
    required Map<String, dynamic> formData,
    void Function(double progress)? onProgress,
  }) {
    return _api.uploadFile(
      endpoint: ApiConstants.kycUpload,
      file: file,
      formData: formData,
      token: token,
      onProgress: onProgress,
    );
  }

  @override
  Future<ApiResponse> getRegulationSchema({required String token}) {
    return _api.get(endpoint: ApiConstants.regulation, token: token);
  }

  @override
  Future<ApiResponse> updateKycProfile({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    return _api.post(endpoint: ApiConstants.kycProfileUpdate, token: token, data: payload);
  }

  @override
  Future<ApiResponse> submitRegulationDetails({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    return _api.post(endpoint: ApiConstants.regulation, token: token, data: payload);
  }

  @override
  Future<ApiResponse> submitUnifiedKyc({
    required String token,
    required Map<String, dynamic> fields,
    required File identityFront,
    required File addressFront,
    File? identityBack,
    File? addressBack,
  }) {
    final Map<String, File> files = {
      'identity_front': identityFront,
      'address_front': addressFront,
      if (identityBack != null) 'identity_back': identityBack,
      if (addressBack != null) 'address_back': addressBack,
    };
    return _api.uploadMultipleNamedFiles(
      endpoint: ApiConstants.submitUnifiedKyc,
      files: files,
      formData: fields,
      token: token,
    );
  }
}

