import 'dart:io';

import 'package:crm_app/core/network/api_response.dart';

abstract class ApiClient {
  Future<ApiResponse> get({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    String? token,
  });

  Future<ApiResponse> post({
    required String endpoint,
    Map<String, dynamic>? data,
    String? token,
  });

  Future<ApiResponse> put({
    required String endpoint,
    Map<String, dynamic>? data,
    String? token,
  });

  Future<ApiResponse> delete({
    required String endpoint,
    String? token,
  });

  /// Multipart form fields only (no file).
  Future<ApiResponse> postForm({
    required String endpoint,
    required Map<String, dynamic> formData,
    String? token,
    bool? isPayment,
  });

  /// Generic multipart file upload.
  Future<ApiResponse> uploadFile({
    required String endpoint,
    required File file,
    required Map<String, dynamic> formData,
    String? token,
    Function(double)? onProgress,
  });

  /// Deposit proof image upload.
  Future<ApiResponse> uploadImageDepositRequest({
    required String endpoint,
    required File file,
    required Map<String, dynamic> formData,
    String? token,
    Function(double)? onProgress,
  });
}
