import 'dart:io';

import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/services/api_service.dart';

/// Adapter that lets legacy [ApiService] satisfy the [ApiClient] contract.
class ApiServiceClient implements ApiClient {
  @override
  Future<ApiResponse> get({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    String? token,
  }) {
    return ApiService.get(
      endpoint: endpoint,
      queryParameters: queryParameters,
      token: token,
    );
  }

  @override
  Future<ApiResponse> post({
    required String endpoint,
    Map<String, dynamic>? data,
    String? token,
  }) {
    return ApiService.post(endpoint: endpoint, data: data, token: token);
  }

  @override
  Future<ApiResponse> put({
    required String endpoint,
    Map<String, dynamic>? data,
    String? token,
  }) {
    return ApiService.put(endpoint: endpoint, data: data, token: token);
  }

  @override
  Future<ApiResponse> delete({required String endpoint, String? token}) {
    return ApiService.delete(endpoint: endpoint, token: token);
  }

  @override
  Future<ApiResponse> postForm({
    required String endpoint,
    required Map<String, dynamic> formData,
    String? token,
    bool? isPayment,
  }) {
    return ApiService.postForm(
      endpoint: endpoint,
      formData: formData,
      token: token,
      isPayment: isPayment,
    );
  }

  @override
  Future<ApiResponse> uploadFile({
    required String endpoint,
    required File file,
    required Map<String, dynamic> formData,
    String? token,
    Function(double)? onProgress,
  }) {
    return ApiService.uploadFile(
      endpoint: endpoint,
      file: file,
      formData: formData,
      token: token,
      onProgress: onProgress,
    );
  }

  @override
  Future<ApiResponse> uploadImageDepositRequest({
    required String endpoint,
    required File file,
    required Map<String, dynamic> formData,
    String? token,
    Function(double)? onProgress,
  }) {
    return ApiService.uploadImageDepositRequest(
      endpoint: endpoint,
      file: file,
      formData: formData,
      token: token,
      onProgress: onProgress,
    );
  }
}

