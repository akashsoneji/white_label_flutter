import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/core/network/network_startup_phase.dart';
export 'package:crm_app/core/network/api_response.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/http_client_service.dart';
import 'package:crm_app/utils/file_compression_helper.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:get/get.dart' as g;

class ApiService {
  static const Duration _timeout = Duration(seconds: 30);

  // Initialize logging on first use
  static bool _loggingInitialized = false;
  static void _initializeLogging() {
    if (!_loggingInitialized) {
      _loggingInitialized = true;
      print('═══════════════════════════════════════════════════════════');
      print(
        '🚀 API SERVICE: Logging enabled - All API requests/responses will be logged',
      );
      print('═══════════════════════════════════════════════════════════');
    }
  }

  // Flag to prevent multiple simultaneous 401 error handlers
  static bool _isHandlingUnauthenticated = false;

  // ✅ FIX: Retry mechanism to prevent logout on app restart
  // Track retry attempts to prevent infinite loops
  static int _retryCount = 0;
  static const int _maxRetries = 1;
  static DateTime? _lastRetryTime;

  /// GET: Fetch data with optional query parameters
  static Future<ApiResponse> get({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    String? token,
  }) async {
    _initializeLogging();
    try {
      // Check network connectivity for critical requests (like login)
      if (endpoint.contains('/login') || endpoint.contains('login')) {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.contains(ConnectivityResult.none)) {
          return ApiResponse.error(
            'No internet connection. Please check your network.',
          );
        }
      }

      // If no token provided, try to get from secure storage
      String? authToken = token;
      if (authToken == null) {
        authToken = await SecureStorageService.getAuthToken();
      }

      // Use persistent client with Keep-Alive headers
      final httpClient = HttpClientService.instance;
      final headers = {
        'Accept': 'application/json',
        // Temporarily disable keep-alive headers for login requests
        if (!endpoint.contains('/login') && !endpoint.contains('login'))
          ...httpClient.keepAliveHeaders, // Add Keep-Alive headers
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      _logRequest(
        'GET',
        endpoint,
        queryParameters: queryParameters,
        extraHeaders: headers,
      );

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}$endpoint',
      ).replace(queryParameters: queryParameters);

      // ✅ FIX: Critical endpoints that need fresh connection (no keep-alive)
      final isCriticalEndpoint =
          endpoint.contains('deposit') ||
          endpoint.contains('create-trading') ||
          endpoint.contains('trading-account') ||
          endpoint.contains('create-account') ||
          endpoint.contains('topup') ||
          endpoint.contains('withdraw') ||
          endpoint.contains('profile') ||
          endpoint.contains('payment-method') ||
          endpoint.contains('wallet');

      // Use fresh client for critical endpoints to avoid keep-alive issues
      final clientToUse =
          isCriticalEndpoint ? httpClient.getFreshClient() : httpClient.client;

      final response = await clientToUse
          .get(uri, headers: headers)
          .timeout(_timeout);

      // Close fresh client after use
      if (clientToUse != httpClient.client) {
        clientToUse.close();
      }

      _logResponse(response);

      // Check for 401 status code
      if (response.statusCode == 401) {
        final errorResponse = _handleError(response);

        // ✅ FIX: Check if we should retry the request
        if (errorResponse.message == 'RETRY_REQUEST' &&
            errorResponse.data != null &&
            errorResponse.data['shouldRetry'] == true) {
          if (kDebugMode) {
            developer.log(
              'ApiService: Retrying GET request to $endpoint',
              name: 'ApiService',
            );
          }
          // Retry the request with fresh connection
          return get(
            endpoint: endpoint,
            queryParameters: queryParameters,
            token: token,
          );
        }

        return errorResponse;
      }

      // Reset retry count on successful request
      _retryCount = 0;

      return _parseApiResponse(response.body);
    } catch (e, t) {
      _logError('GET', endpoint, e, t);
      return _handleError(e);
    }
  }

  /// POST: JSON body
  static Future<ApiResponse> post({
    required String endpoint,
    Map<String, dynamic>? data,
    String? token,
  }) async {
    _initializeLogging();
    try {
      // If no token provided, try to get from secure storage
      String? authToken = token;
      if (authToken == null) {
        authToken = await SecureStorageService.getAuthToken();
      }

      // Use persistent client with Keep-Alive headers
      final httpClient = HttpClientService.instance;
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ...httpClient.keepAliveHeaders, // Add Keep-Alive headers
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      _logRequest('POST', endpoint, data: data, extraHeaders: headers);

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

      // Use shorter timeout for login/register requests to fail faster
      // ✅ FIX: Also use fresh client for deposit and trading account creation
      // to avoid keep-alive connection errors during account setup flow
      final isAuthEndpoint =
          endpoint.contains('/login') ||
          endpoint.contains('login') ||
          endpoint.contains('user/login') ||
          endpoint.contains('/register') ||
          endpoint.contains('register') ||
          endpoint.contains('user/register');

      // ✅ FIX: Critical endpoints that need fresh connection (no keep-alive)
      final isCriticalEndpoint =
          endpoint.contains('deposit') ||
          endpoint.contains('create-trading') ||
          endpoint.contains('trading-account') ||
          endpoint.contains('create-account') ||
          endpoint.contains('topup') ||
          endpoint.contains('withdraw') ||
          endpoint.contains('profile');
      final timeout = isAuthEndpoint ? const Duration(seconds: 15) : _timeout;

      // Use fresh client for login/register AND critical endpoints to avoid keep-alive issues
      final clientToUse =
          (isAuthEndpoint || isCriticalEndpoint)
              ? httpClient.getFreshClient()
              : httpClient.client;

      final response = await clientToUse
          .post(
            uri,
            headers: headers,
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(timeout);

      // Close fresh client after use
      if (clientToUse != httpClient.client) {
        clientToUse.close();
      }

      _logResponse(response);

      // Some servers redirect unauthenticated requests (302) to homepage/login when
      // `Accept: application/json` is not honored or auth is missing/invalid.
      // Treat redirects as errors so UI can show the message.
      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 307 ||
          response.statusCode == 308) {
        return ApiResponse.error(
          'Request was redirected (${response.statusCode}). Please login again and retry.',
        );
      }

      // Check for 401 status code
      if (response.statusCode == 401) {
        final errorResponse = _handleError(response);

        // ✅ FIX: Check if we should retry the request
        if (errorResponse.message == 'RETRY_REQUEST' &&
            errorResponse.data != null &&
            errorResponse.data['shouldRetry'] == true) {
          if (kDebugMode) {
            developer.log(
              'ApiService: Retrying POST request to $endpoint',
              name: 'ApiService',
            );
          }
          // Retry the request with fresh connection
          return post(endpoint: endpoint, data: data, token: token);
        }

        return errorResponse;
      }

      // Reset retry count on successful request
      _retryCount = 0;

      return _parseApiResponse(response.body);
    } catch (e, t) {
      _logError('POST', endpoint, e, t);
      return _handleError(e);
    }
  }

  /// PUT: JSON body
  static Future<ApiResponse> put({
    required String endpoint,
    Map<String, dynamic>? data,
    String? token,
  }) async {
    try {
      // If no token provided, try to get from secure storage
      String? authToken = token;
      if (authToken == null) {
        authToken = await SecureStorageService.getAuthToken();
      }

      // Use persistent client with Keep-Alive headers
      final httpClient = HttpClientService.instance;
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ...httpClient.keepAliveHeaders, // Add Keep-Alive headers
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      _logRequest('PUT', endpoint, data: data, extraHeaders: headers);

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

      // Use persistent HTTP client for connection reuse
      final response = await httpClient.client
          .put(
            uri,
            headers: headers,
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(_timeout);

      _logResponse(response);

      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 307 ||
          response.statusCode == 308) {
        return ApiResponse.error(
          'Request was redirected (${response.statusCode}). Please login again and retry.',
        );
      }

      // Check for 401 status code
      if (response.statusCode == 401) {
        final errorResponse = _handleError(response);

        // ✅ FIX: Check if we should retry the request
        if (errorResponse.message == 'RETRY_REQUEST' &&
            errorResponse.data != null &&
            errorResponse.data['shouldRetry'] == true) {
          if (kDebugMode) {
            developer.log(
              'ApiService: Retrying PUT request to $endpoint',
              name: 'ApiService',
            );
          }
          // Retry the request with fresh connection
          return put(endpoint: endpoint, data: data, token: token);
        }

        return errorResponse;
      }

      // Reset retry count on successful request
      _retryCount = 0;

      return _parseApiResponse(response.body);
    } catch (e, t) {
      _logError('PUT', endpoint, e, t);
      return _handleError(e);
    }
  }

  /// DELETE: Delete resource
  static Future<ApiResponse> delete({
    required String endpoint,
    String? token,
  }) async {
    _initializeLogging();
    try {
      // If no token provided, try to get from secure storage
      String? authToken = token;
      if (authToken == null) {
        authToken = await SecureStorageService.getAuthToken();
      }

      // Use persistent client with Keep-Alive headers
      final httpClient = HttpClientService.instance;
      final headers = {
        'Accept': 'application/json',
        ...httpClient.keepAliveHeaders,
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      _logRequest('DELETE', endpoint, extraHeaders: headers);

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

      final response = await httpClient.client
          .delete(uri, headers: headers)
          .timeout(_timeout);

      _logResponse(response);

      // Check for 401 status code
      if (response.statusCode == 401) {
        final errorResponse = _handleError(response);

        // Check if we should retry the request
        if (errorResponse.message == 'RETRY_REQUEST' &&
            errorResponse.data != null &&
            errorResponse.data['shouldRetry'] == true) {
          if (kDebugMode) {
            developer.log(
              'ApiService: Retrying DELETE request to $endpoint',
              name: 'ApiService',
            );
          }
          // Retry the request with fresh connection
          return delete(endpoint: endpoint, token: token);
        }

        return errorResponse;
      }

      // Reset retry count on successful request
      _retryCount = 0;

      return _parseApiResponse(response.body);
    } catch (e, t) {
      _logError('DELETE', endpoint, e, t);
      return _handleError(e);
    }
  }

  /// POST: Form data
  static Future<ApiResponse> postForm({
    required String endpoint,
    required Map<String, dynamic> formData,
    String? token,
    bool? isPayment = true,
  }) async {
    try {
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      _logRequest('POST_FORM', endpoint, data: formData, extraHeaders: headers);

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request =
          http.MultipartRequest('POST', uri)
            ..headers.addAll(headers)
            ..fields.addAll(
              formData.map((key, value) => MapEntry(key, value.toString())),
            );

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      _logResponse(response);

      // Check for 401 status code
      if (response.statusCode == 401) {
        return _handleError(response);
      }

      return _parseApiResponse(response.body);
    } catch (e, t) {
      _logError('POST_FORM', endpoint, e, t);
      return _handleError(e);
    }
  }

  /// POST: Multipart form data with a single optional file field.
  static Future<ApiResponse> postFormWithFile({
    required String endpoint,
    required Map<String, dynamic> formData,
    File? file,
    String fileField = 'attachment',
    String? token,
  }) async {
    try {
      String? authToken = token;
      if (authToken == null) {
        authToken = await SecureStorageService.getAuthToken();
      }

      final headers = {
        'Accept': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      _logRequest(
        'POST_FORM_FILE',
        endpoint,
        data: formData,
        extraHeaders: headers,
      );

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request =
          http.MultipartRequest('POST', uri)
            ..headers.addAll(headers)
            ..fields.addAll(
              formData.map((key, value) => MapEntry(key, value.toString())),
            );

      if (file != null && await file.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath(fileField, file.path),
        );
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      _logResponse(response);

      if (response.statusCode == 401) {
        return _handleError(response);
      }

      return _parseApiResponse(response.body);
    } catch (e, t) {
      _logError('POST_FORM_FILE', endpoint, e, t);
      return _handleError(e);
    }
  }

  /// Helper method to parse API response and check status
  static ApiResponse _parseApiResponse(String responseBody) {
    try {
      final responseData = jsonDecode(responseBody);

      // Check if the API response indicates success/failure
 if (responseData is Map<String, dynamic>) {
 // Check both 'status' and 'success' fields (some APIs use different fields)
 // NOTE: must resolve dynamic → bool BEFORE the comparison so AOT/release
 // builds don't silently mis-evaluate `true == false` due to type promotion
 // or dart2js/AOT tree-shaking edge cases.
 final rawStatus = responseData['status'];
 final rawSuccess = responseData['success'];
 final bool apiStatus = rawStatus is bool
 ? rawStatus
 : (rawStatus?.toString().toLowerCase() == 'true');
 final bool apiSuccess = rawSuccess is bool
 ? rawSuccess
 : (rawSuccess?.toString().toLowerCase() == 'true');

 // Extract message - prioritize 'message' field, fallback to 'error' or default
 String message =
 responseData['message'] ??
 responseData['error'] ??
 responseData['error_message'] ??
 'Request failed';

 // Treat as error if:
 // 1. status is explicitly false
 // 2. success is explicitly false
 // 3. If neither field present, be conservative (treat as success).
 final bool hasStatusField = responseData.containsKey('status');
 final bool hasSuccessField = responseData.containsKey('success');

 bool isError = false;

 if (hasStatusField) {
 isError = !apiStatus;
 }

 if (!isError && hasSuccessField) {
 isError = !apiSuccess;
 }

 // If neither field exists, check if message suggests an error
        if (!hasStatusField &&
            !hasSuccessField &&
            message != 'Request failed') {
          // If there's a custom message, it might be an error
          // But we'll be conservative and treat as success unless explicitly marked as error
          isError = false;
        }

        if (isError) {
          // API returned status: false or success: false, treat as error
          // Only use data if it's actually a map (not an empty array)
          final errorData = responseData['data'];
          final validErrorData =
              errorData is Map<String, dynamic> ? errorData : null;

          // Log the error message being returned
          print('⚠️ API Error Response Detected:');
          print('   Message: $message');
          print('   Status: $apiStatus');
          print('   Success: $apiSuccess');
          print('   Has Status Field: $hasStatusField');
          print('   Has Success Field: $hasSuccessField');
          print('   Returning error with message: $message');

          return ApiResponse.error(message, data: validErrorData);
        }

        // API returned status: true or success: true, return success
        print('✅ API Success Response:');
        print('   Message: $message');
        print('   Status: $apiStatus');
        print('   Success: $apiSuccess');
        return ApiResponse.success(responseData);
      }

      return ApiResponse.success(responseData);
    } catch (e) {
      print('❌ Error parsing API response: $e');
      print('   Response body: $responseBody');
      return ApiResponse.error('Failed to parse response: $e');
    }
  }

  /// Logging
  static void _logRequest(
    String method,
    String url, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? extraHeaders,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    print('═══════════════════════════════════════════════════════════');
    print('📤 API REQUEST [$timestamp]');
    print('═══════════════════════════════════════════════════════════');
    print('Method: $method');
    print('URL: ${ApiConstants.baseUrl}$url');

    if (queryParameters != null && queryParameters.isNotEmpty) {
      print('Query Parameters:');
      try {
        print(JsonEncoder.withIndent('  ').convert(queryParameters));
      } catch (e) {
        print('  $queryParameters');
      }
    }

    if (data != null && data.isNotEmpty) {
      print('Request Body:');
      try {
        print(JsonEncoder.withIndent('  ').convert(data));
      } catch (e) {
        print('  $data');
      }
    }

    if (extraHeaders != null && extraHeaders.isNotEmpty) {
      print('Headers:');
      // Mask sensitive headers
      final safeHeaders = Map<String, dynamic>.from(extraHeaders);
      if (safeHeaders.containsKey('Authorization')) {
        final authValue = safeHeaders['Authorization'] as String?;
        if (authValue != null && authValue.length > 20) {
          safeHeaders['Authorization'] =
              'Bearer ${authValue.substring(7, 27)}...';
        }
      }
      try {
        print(JsonEncoder.withIndent('  ').convert(safeHeaders));
      } catch (e) {
        print('  $safeHeaders');
      }
    }

    print('═══════════════════════════════════════════════════════════');
  }

  static void _logResponse(http.Response response) {
    final timestamp = DateTime.now().toIso8601String();
    final statusEmoji =
        response.statusCode >= 200 && response.statusCode < 300
            ? '✅'
            : response.statusCode >= 400
            ? '❌'
            : '⚠️';

    print('═══════════════════════════════════════════════════════════');
    print('$statusEmoji API RESPONSE [$timestamp]');
    print('═══════════════════════════════════════════════════════════');
    print('URL: ${response.request?.url ?? 'N/A'}');
    print('Method: ${response.request?.method ?? 'N/A'}');
    print(
      'Status Code: ${response.statusCode} ${_getStatusText(response.statusCode)}',
    );
    print('Response Headers:');
    try {
      print(JsonEncoder.withIndent('  ').convert(response.headers));
    } catch (e) {
      print('  ${response.headers}');
    }

    print('Response Body:');
    if (response.body.isEmpty) {
      print('  [Empty Response Body]');
    } else {
      try {
        // Try to parse as JSON and pretty print
        final jsonData = jsonDecode(response.body);
        print(JsonEncoder.withIndent('  ').convert(jsonData));
      } catch (e) {
        // If not JSON, log as string (truncate if too long)
        final body = response.body;
        if (body.length > 2000) {
          print(
            '  ${body.substring(0, 2000)}...\n  [Truncated - Total length: ${body.length} characters]',
          );
        } else {
          print('  $body');
        }
      }
    }

    print('═══════════════════════════════════════════════════════════');
  }

  static String _getStatusText(int statusCode) {
    switch (statusCode) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 204:
        return 'No Content';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 422:
        return 'Unprocessable Entity';
      case 500:
        return 'Internal Server Error';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      default:
        return '';
    }
  }

  static ApiResponse _handleError(dynamic e) {
    if (e is http.ClientException || e is Exception) {
      return ApiResponse.error('Network error. Please check your connection.');
    } else if (e is http.Response) {
      if (e.statusCode == 401) {
        // ✅ FIX: Check if we should retry before logging out
        // This prevents logout on app restart when HTTP connection was closed
        final now = DateTime.now();
        final shouldRetry =
            _retryCount < _maxRetries &&
            (_lastRetryTime == null ||
                now.difference(_lastRetryTime!).inSeconds > 5);

        if (shouldRetry) {
          _retryCount++;
          _lastRetryTime = now;

          if (kDebugMode) {
            developer.log(
              'ApiService: Got 401, attempting retry ${_retryCount}/$_maxRetries (might be connection issue)',
              name: 'ApiService',
            );
          }

          // Recreate HTTP client to establish fresh connection
          HttpClientService.instance.forceReconnect();

          // Return a special error that tells the caller to retry
          return ApiResponse.error(
            'RETRY_REQUEST', // Special message to trigger retry
            data: {'shouldRetry': true},
          );
        }

        // Reset retry count after successful retry or max retries reached
        _retryCount = 0;

        // Parse the response body to get the actual error message
        try {
          final errorData = jsonDecode(e.body);
          String errorMessage = 'Unauthorized. Please login again.';

          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['message'] ?? errorMessage;
          }

          // Handle 401 error with proper logout and navigation
          _handleUnauthenticatedError(errorMessage);

          return ApiResponse.error(errorMessage);
        } catch (parseError) {
          // If parsing fails, use default message
          _handleUnauthenticatedError(
            'Your session has expired. Please login again.',
          );
          return ApiResponse.error('Unauthorized. Please login again.');
        }
      }

      // Handle other HTTP errors
      try {
        final errorData = jsonDecode(e.body);
        String errorMessage = 'Unexpected error occurred.';
        dynamic errorDetails;

        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['message'] ?? errorMessage;
          if (errorData.containsKey('data')) {
            if (errorData['data'] is Map<String, dynamic>) {
              errorDetails = errorData['data'] as Map<String, dynamic>;
            } else if (errorData['data'] is Map &&
                errorData['data']['errors'] is List) {
              errorDetails = errorData['data']['errors'] as List<dynamic>;
            } else {
              errorDetails = errorData['data'];
            }
          }
        }

        return ApiResponse.error(errorMessage, data: errorDetails);
      } catch (parseError) {
        return ApiResponse.error('Unexpected error occurred.');
      }
    } else {
      return ApiResponse.error('Unexpected error occurred.');
    }
  }

  // Handle 401 unauthenticated error with proper logout and navigation
  static void _handleUnauthenticatedError(String message) async {
    // During app startup, suppress auto-logout to prevent double-navigation
    // The AuthCheckScreen handles navigation after checkAuthStatus() returns
    if (NetworkStartupPhase.isActive) {
      if (kDebugMode) {
        developer.log(
          'ApiService: Startup phase - suppressing global 401 handler (AuthCheckScreen will handle navigation)',
          name: 'ApiService',
        );
      }
      return;
    }

    // Prevent multiple simultaneous 401 handlers
    if (_isHandlingUnauthenticated) {
      print('ApiService: Already handling unauthenticated error, skipping...');
      return;
    }

    try {
      _isHandlingUnauthenticated = true;

      // Check if user is actually authenticated before auto-logout
      // This prevents auto-logout during app reconnection when session is still valid
      bool shouldLogout = false;
      try {
        final authController = g.Get.find<AuthController>();
        // Only logout if user is actually authenticated
        // If not authenticated, this might be a reconnection issue, not a real session expiry
        if (authController.isAuthenticated) {
          // Verify token still exists in storage
          final token = await SecureStorageService.getAuthToken();
          if (token != null && token.isNotEmpty) {
            shouldLogout = true;
            if (kDebugMode) {
              developer.log(
                'ApiService: User is authenticated with valid token, session expired - logging out',
              );
            }
          } else {
            if (kDebugMode) {
              developer.log(
                'ApiService: Token not found in storage, user may already be logged out - skipping auto-logout',
              );
            }
          }
        } else {
          if (kDebugMode) {
            developer.log(
              'ApiService: User not authenticated, 401 might be from reconnection - skipping auto-logout',
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          developer.log(
            'ApiService: Error checking auth state: $e - proceeding with caution',
          );
        }
        // If we can't check auth state, be conservative and don't auto-logout
        // This prevents logout during app reconnection issues
        shouldLogout = false;
      }

      // Only proceed with logout if user is actually authenticated
      if (!shouldLogout) {
        if (kDebugMode) {
          developer.log(
            'ApiService: Skipping auto-logout - user not authenticated or token missing',
          );
        }
        _isHandlingUnauthenticated = false;
        return;
      }

      // Show custom toast message
      CustomToastService.showInfo(message: message, title: 'Session Expired');

      // Wait a moment for the user to see the message
      await Future.delayed(Duration(seconds: 2));

      // Get auth controller and logout properly
      try {
        final authController = g.Get.find<AuthController>();
        await authController.logoutWithOutApi();
      } catch (e) {
        print('AuthController not found, clearing data manually: $e');
        // Fallback: clear auth data and navigate to login
        await SecureStorageService.clearAuthData();
        g.Get.offAllNamed(AppPages.GET_STARTED);
      }
    } catch (e) {
      print('Error handling unauthenticated error: $e');
      // Fallback: just show error message and navigate
      try {
        CustomToastService.showError(
          message: 'Authentication failed. Please login again.',
          title: 'Error',
        );
        await Future.delayed(Duration(seconds: 1));
        await SecureStorageService.clearAuthData();
        g.Get.offAllNamed(AppPages.GET_STARTED);
      } catch (fallbackError) {
        print('Fallback error handling failed: $fallbackError');
        // Last resort: just navigate
        g.Get.offAllNamed(AppPages.GET_STARTED);
      }
    } finally {
      // Reset flag after handling is complete
      _isHandlingUnauthenticated = false;
    }
  }

  /// UPLOAD: Upload file with form data
  static Future<ApiResponse> uploadFile({
    required String endpoint,
    required File file,
    required Map<String, dynamic> formData,
    String? token,
    Function(double)? onProgress,
  }) async {
    try {
      // If no token provided, try to get from secure storage
      String? authToken = token;
      if (authToken == null) {
        authToken = await SecureStorageService.getAuthToken();
      }

      final headers = {
        'Accept': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      _logRequest(
        'UPLOAD',
        endpoint,
        queryParameters: formData,
        extraHeaders: headers,
      );

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll(headers);

      // Don't set Content-Type for multipart requests - let the framework handle it
      // The multipart request will automatically set the correct Content-Type with boundary

      // Ensure we have the correct content type
      request.headers.remove(
        'Content-Type',
      ); // Remove any existing content type

      // Add form data
      formData.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Debug: Log form data
      developer.log('Form data being sent:', name: 'ApiService');
      formData.forEach((key, value) {
        developer.log('$key: $value', name: 'ApiService');
      });

      // Add file - try different field names that the server might expect
      // Common field names: 'file', 'image', 'document', 'upload'
      // Based on the iOS code, it might expect 'document' or 'image'

      // Check if file exists and is readable
      if (!await file.exists()) {
        throw Exception('File does not exist: ${file.path}');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File is empty: ${file.path}');
      }

      // Add file - try different field names that the server might expect
      // Based on the error, the server is not receiving the file data
      request.files.add(
        await http.MultipartFile.fromPath(
          'files[]', // Use 'files[]' as expected by server
          file.path,
        ),
      );

      // Debug: Log the request details
      developer.log('Upload request details:', name: 'ApiService');
      developer.log('Files count: ${request.files.length}', name: 'ApiService');
      developer.log('Fields: ${request.fields}', name: 'ApiService');
      developer.log('File path: ${file.path}', name: 'ApiService');
      developer.log('File exists: ${await file.exists()}', name: 'ApiService');
      developer.log('File size: ${await file.length()}', name: 'ApiService');

      // Log the actual multipart request details
      developer.log('Request headers: ${request.headers}', name: 'ApiService');
      developer.log('Request URL: ${request.url}', name: 'ApiService');

      // Log each file being sent
      for (int i = 0; i < request.files.length; i++) {
        final fileField = request.files[i];
        developer.log(
          'File $i: field=${fileField.field}, filename=${fileField.filename}, length=${fileField.length}',
          name: 'ApiService',
        );
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      _logResponse(response);

      // Check for 401 status code
      if (response.statusCode == 401) {
        return _handleError(response);
      }

      final responseData = json.decode(response.body);

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: responseData['message'] ?? 'Upload completed',
        data: responseData,
      );
    } catch (e, t) {
      _logError('UPLOAD', endpoint, e, t);
      return ApiResponse(
        success: false,
        message: 'Upload failed: $e',
        data: null,
      );
    }
  }

  /// UPLOAD: Upload file with form data
  static Future<ApiResponse> uploadImageDepositRequest({
    required String endpoint,
    required File file,
    required Map<String, dynamic> formData,
    String? token,
    Function(double)? onProgress,
  }) async {
    try {
      // If no token provided, try to get from secure storage
      String? authToken = token;
      if (authToken == null) {
        authToken = await SecureStorageService.getAuthToken();
      }

      final headers = {
        'Accept': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      _logRequest(
        'DepositRequest',
        endpoint,
        queryParameters: formData,
        extraHeaders: headers,
      );

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll(headers);

      // Don't set Content-Type for multipart requests - let the framework handle it
      // The multipart request will automatically set the correct Content-Type with boundary

      // Ensure we have the correct content type
      request.headers.remove(
        'Content-Type',
      ); // Remove any existing content type

      // Add form data
      formData.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Debug: Log form data
      developer.log('Form data being sent:', name: 'ApiService');
      formData.forEach((key, value) {
        developer.log('$key: $value', name: 'ApiService');
      });

      // Add file - try different field names that the server might expect
      // Common field names: 'file', 'image', 'document', 'upload'
      // Based on the iOS code, it might expect 'document' or 'image'

      // Check if file exists and is readable
      // Compress if file size > 1.5 MB
      file = await FileCompressionHelper.compressIfNeeded(file);

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File is empty: ${file.path}');
      }

      // Add file - try different field names that the server might expect
      // Based on the error, the server is not receiving the file data
      request.files.add(await http.MultipartFile.fromPath('proof', file.path));

      // Debug: Log the request details
      developer.log('Upload request details:', name: 'ApiService');
      developer.log('Files count: ${request.files.length}', name: 'ApiService');
      developer.log('Fields: ${request.fields}', name: 'ApiService');
      developer.log('File path: ${file.path}', name: 'ApiService');
      developer.log('File exists: ${await file.exists()}', name: 'ApiService');
      developer.log('File size: ${await file.length()}', name: 'ApiService');

      // Log the actual multipart request details
      developer.log('Request headers: ${request.headers}', name: 'ApiService');
      developer.log('Request URL: ${request.url}', name: 'ApiService');

      // Log each file being sent
      for (int i = 0; i < request.files.length; i++) {
        final fileField = request.files[i];
        developer.log(
          'File $i: field=${fileField.field}, filename=${fileField.filename}, length=${fileField.length}',
          name: 'ApiService',
        );
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      _logResponse(response);

      // Check for 401 status code
      if (response.statusCode == 401) {
        return _handleError(response);
      }

      final responseData = json.decode(response.body);
      file.delete();
      return ApiResponse(
        success: responseData['status'] as bool,
        message:
            responseData['message'] ?? 'Deposit request created successfully',
        data: responseData,
      );
    } catch (e, t) {
      _logError('DepositRequest', endpoint, e, t);
      return ApiResponse(
        success: false,
        message: 'Deposit request failed: $e',
        data: null,
      );
    }
  }

  /// UPLOAD: Upload multiple files with form data
  static Future<ApiResponse> uploadFiles({
    required String endpoint,
    required List<FileUploadData> files,
    required Map<String, dynamic> formData,
    String? token,
    Function(double)? onProgress,
  }) async {
    try {
      // If no token provided, try to get from secure storage
      String? authToken = token;
      if (authToken == null) {
        authToken = await SecureStorageService.getAuthToken();
      }

      final headers = {
        'Accept': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      _logRequest(
        'UPLOAD',
        endpoint,
        queryParameters: formData,
        extraHeaders: headers,
      );

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll(headers);

      // Add form data
      formData.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Add all files with their specific subdocument types
      List<String> subdocumentTypes = [];
      for (int i = 0; i < files.length; i++) {
        var fileData = files[i];
        if (await fileData.file.exists()) {
          final fileSize = await fileData.file.length();
          if (fileSize > 0) {
            // Add file with specific subdocument type
            request.files.add(
              await http.MultipartFile.fromPath(
                'files[]', // Use 'files[]' for multiple files as expected by server
                fileData.file.path,
              ),
            );

            // Collect subdocument types for this specific file
            subdocumentTypes.add(fileData.subdocumentType);

            developer.log(
              'Added file: ${fileData.file.path} for ${fileData.subdocumentType}',
              name: 'ApiService',
            );
          }
        }
      }

      // Add subdocument types as array - each type corresponds to each file
      for (int i = 0; i < subdocumentTypes.length; i++) {
        request.fields['subdocument_types[]'] = subdocumentTypes[i];
      }

      // Debug: Log the request details
      developer.log('Upload request details:', name: 'ApiService');
      developer.log('Files count: ${request.files.length}', name: 'ApiService');
      developer.log('Fields: ${request.fields}', name: 'ApiService');

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      _logResponse(response);

      // Check for 401 status code
      if (response.statusCode == 401) {
        return _handleError(response);
      }

      final responseData = json.decode(response.body);

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: responseData['message'] ?? 'Upload completed',
        data: responseData,
      );
    } catch (e, t) {
      _logError('UPLOAD_FILES', endpoint, e, t);
      return ApiResponse(
        success: false,
        message: 'Upload failed: $e',
        data: null,
      );
    }
  }

  /// UPLOAD: Upload multiple files with form data using custom field keys
  static Future<ApiResponse> uploadMultipleNamedFiles({
    required String endpoint,
    required Map<String, File> files,
    required Map<String, dynamic> formData,
    String? token,
  }) async {
    try {
      // If no token provided, try to get from secure storage
      String? authToken = token ?? await SecureStorageService.getAuthToken();

      final headers = {
        'Accept': 'application/json',
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      _logRequest(
        'UPLOAD_NAMED_FILES',
        endpoint,
        queryParameters: formData,
        extraHeaders: headers,
      );

      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll(headers);
      request.headers.remove('Content-Type'); // Let framework handle multipart boundary

      // Add form data
      formData.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Add files with their specific keys
      for (final entry in files.entries) {
        final fileKey = entry.key;
        final file = entry.value;
        if (await file.exists()) {
          final fileSize = await file.length();
          if (fileSize > 0) {
            request.files.add(
              await http.MultipartFile.fromPath(
                fileKey,
                file.path,
              ),
            );
            developer.log(
              'Added named file: ${file.path} as $fileKey',
              name: 'ApiService',
            );
          }
        }
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      _logResponse(response);

      if (response.statusCode == 401) {
        return _handleError(response);
      }

      final responseData = json.decode(response.body);

      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: responseData['message'] ?? 'Upload completed',
        data: responseData,
      );
    } catch (e, t) {
      _logError('UPLOAD_NAMED_FILES', endpoint, e, t);
      return ApiResponse(
        success: false,
        message: 'Upload failed: $e',
        data: null,
      );
    }
  }

  /// Log errors with full details
  static void _logError(
    String method,
    String endpoint,
    dynamic error,
    StackTrace? stackTrace,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    print('═══════════════════════════════════════════════════════════');
    print('❌ API ERROR [$timestamp]');
    print('═══════════════════════════════════════════════════════════');
    print('Method: $method');
    print('URL: ${ApiConstants.baseUrl}$endpoint');
    print('Error Type: ${error.runtimeType}');
    print('Error Message: $error');
    if (stackTrace != null) {
      print('Stack Trace:');
      print('$stackTrace');
    }
    print('═══════════════════════════════════════════════════════════');
  }
}
