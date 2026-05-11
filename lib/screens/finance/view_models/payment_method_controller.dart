import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:crm_app/widgets/custom_toast.dart';

import 'package:crm_app/screens/finance/presentation/pages/deposit_real_screen.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/screens/finance/data/repositories/finance_repository.dart';

class PaymentMethodController extends GetxController {
  final FinanceRepository _repo = Get.find<FinanceRepository>();
  // Observable states
  final _isLoading = false.obs;
  final _errorMessage = ''.obs;
  final _successMessage = ''.obs;

  // Getters
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;
  String get successMessage => _successMessage.value;

  // KYC deposits list
  final kycDeposits = <Map<String, dynamic>>[].obs;
  final selectedKYCDeposit = Rxn<Map<String, dynamic>>();

  @override
  void onInit() {
    super.onInit();
    fetchKYCDepositMethods();
  }

  /// Fetch deposit methods that require KYC
  Future<void> fetchKYCDepositMethods() async {
    try {
      _setLoading(true);
      final token = await SecureStorageService.getAuthToken();

      final response = await _repo.getDepositMethods(token: token ?? '');

      if (response.success &&
          response.data != null &&
          response.data['status'] == true &&
          response.data['data'] != null) {
        _setLoading(false);
        final dataList = response.data['data'];
        if (dataList is List) {
          final methods = List<Map<String, dynamic>>.from(
            dataList.map((item) => item is Map<String, dynamic> ? item : {}),
          );
          kycDeposits.assignAll(methods);

          if (methods.isNotEmpty) {
            selectedKYCDeposit.value = methods.first;
            loadDepositIcons(methods);
          }
        } else {
          _setLoading(false);
          kycDeposits.clear();
        }
      } else {
        _setLoading(false);
        kycDeposits.clear();
      }
    } catch (e) {
      _setLoading(false);
      kycDeposits.clear();
      CustomToastService.showError(message: "Error: $e");
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch icon bytes for a list of deposit methods and update them
  /// Optimized: Load images in parallel and show placeholder immediately
  Future<void> loadDepositIcons(List<Map<String, dynamic>> methods) async {
    try {
      final token = await SecureStorageService.getAuthToken();

      // First, update with placeholders immediately for better UX
      final List<Map<String, dynamic>> methodsWithPlaceholders = [];
      Uint8List? placeholderBytes;

      try {
        placeholderBytes =
            (await rootBundle.load(
              'assets/images/placeholder.png',
            )).buffer.asUint8List();
      } catch (e) {
        print('Error loading placeholder: $e');
      }

      for (var method in methods) {
        methodsWithPlaceholders.add({
          ...method,
          'iconBytes': placeholderBytes, // Can be null, which is fine
        });
      }

      // Update UI immediately with placeholders (or null if placeholder failed)
      kycDeposits.assignAll(methodsWithPlaceholders);

      // Then load actual images in parallel
      if (token != null && token.isNotEmpty) {
        final List<Future<Map<String, dynamic>>> imageFutures =
            methods.map((method) async {
              final iconUrl = method['icon'] ?? '';
              Uint8List? bytes;

              if (iconUrl.isNotEmpty) {
                bytes = await fetchImageBytes(iconUrl, token);
              }

              return {...method, 'iconBytes': bytes ?? placeholderBytes};
            }).toList();

        // Load all images in parallel
        final updatedMethods = await Future.wait(imageFutures);

        // Update with actual images
        kycDeposits.assignAll(updatedMethods);
      }
    } catch (e) {
      print('Error loading deposit icons: $e');
    }
  }

  /// Fetch icon bytes from a URL with Authorization token
  Future<Uint8List?> fetchImageBytes(String url, String token) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        // Remove or loosen Accept header
        // 'Accept': '*/*',
      });

      // Log request
      final timestamp = DateTime.now().toIso8601String();
      print('═══════════════════════════════════════════════════════════');
      print('📤 DIRECT HTTP REQUEST [$timestamp]');
      print('═══════════════════════════════════════════════════════════');
      print('Method: GET');
      print('URL: $url');
      print('Headers: ${request.headers}');
      print('═══════════════════════════════════════════════════════════');

      final streamedResponse = await request.send();

      // Log response
      final statusEmoji = streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300 
          ? '✅' 
          : streamedResponse.statusCode >= 400 
              ? '❌' 
              : '⚠️';
      print('═══════════════════════════════════════════════════════════');
      print('$statusEmoji DIRECT HTTP RESPONSE [$timestamp]');
      print('═══════════════════════════════════════════════════════════');
      print('URL: $url');
      print('Status Code: ${streamedResponse.statusCode}');
      print('Headers: ${streamedResponse.headers}');
      print('═══════════════════════════════════════════════════════════');

      if (streamedResponse.statusCode == 200) {
        final bytes = await streamedResponse.stream.toBytes();
        print("Image loaded: ${bytes.length} bytes");
        return bytes;
      } else {
        final body = await streamedResponse.stream.bytesToString();
        print(
          'Failed to fetch image: ${streamedResponse.statusCode}, body: $body',
        );
        return null;
      }
    } catch (e) {
      print('Error fetching image: $e');
      return null;
    }
  }

  /// Select a KYC deposit method
  void setSelectedKYCDeposit(
    Map<String, dynamic> method, {
    String? accountNumber,
  }) {
    selectedKYCDeposit.value = method;
    // Get.to(Page)
    Get.to(
      () => DepositRealScreen(
        object: selectedKYCDeposit.value ?? {},
        preselectedAccountNumber: accountNumber,
      ),
    );
  }

  // Helpers
  void _setLoading(bool loading) => _isLoading.value = loading;

  void clearMessages() {
    _errorMessage.value = '';
    _successMessage.value = '';
  }
}
