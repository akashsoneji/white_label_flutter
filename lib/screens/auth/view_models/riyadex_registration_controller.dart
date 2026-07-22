import 'dart:convert';
import 'package:crm_app/screens/auth/data/models/riyadex_country_config.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';

import '../../../core/storage/session_storage.dart';
import 'auth_controller.dart';

class RiyadexRegistrationController extends GetxController {
  final AuthController _authController = Get.find<AuthController>();

  final RxBool isLoading = true.obs;
  final RxList<RiyadexCountry> countries = <RiyadexCountry>[].obs;
  final Rx<RiyadexCountry?> selectedCountry = Rx<RiyadexCountry?>(null);
  final Rx<RiyadexCountry?> selectedPhoneCountry = Rx<RiyadexCountry?>(null);
  final Rx<RiyadexGeoLocation?> geoCountry = Rx<RiyadexGeoLocation?>(null);
  final Rx<RiyadexConfigData?> configData = Rx<RiyadexConfigData?>(null);
  
  final RxBool allowedToRegister = true.obs;
  final RxString restrictedMessage = ''.obs;
  final RxBool isMinimal = false.obs;

  @override
  void onInit() {
    super.onInit();
    _fetchConfigAndGeo();
  }

  Future<void> _fetchConfigAndGeo() async {
    isLoading.value = true;
    try {
      // Run both requests in parallel
      final results = await Future.wait([
        http.get(Uri.parse('https://register.riyadex.com/countries.php')),
        http.get(Uri.parse('https://register.riyadex.com/geo.php')),
      ]);

      final countriesResponse = results[0];
      final geoResponse = results[1];

      if (countriesResponse.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(countriesResponse.body);
        final response = RiyadexCountriesResponse.fromJson(body);
        if (response.status) {
          countries.assignAll(response.countries);
          configData.value = response.config;
        }
      }

      if (geoResponse.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(geoResponse.body);
        geoCountry.value = RiyadexGeoLocation.fromJson(body);
      }

      // Auto-select country based on geo IP if available
      if (geoCountry.value != null && countries.isNotEmpty) {
        final matchedCountry = countries.firstWhereOrNull(
            (c) => c.iso2 == geoCountry.value!.countryCode);
        if (matchedCountry != null) {
          selectCountry(matchedCountry);
          selectedPhoneCountry.value = matchedCountry;
        } else {
          selectCountry(countries.first);
          selectedPhoneCountry.value = countries.first;
        }
      } else if (countries.isNotEmpty) {
        selectCountry(countries.first);
        selectedPhoneCountry.value = countries.first;
      }
    } catch (e) {
      print('RiyadexRegistrationController init failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void selectCountry(RiyadexCountry country) {
    selectedCountry.value = country;
    _evaluateRules();
  }

  void _evaluateRules() {
    final country = selectedCountry.value;
    if (country == null) return;

    // 1. Check minimal tier logic based on required_fields length and contents
    isMinimal.value = country.requiredFields.length == 2 && 
                      country.requiredFields.contains('email') && 
                      country.requiredFields.contains('password');

    // 2. Check restricted tier logic (geo_rule)
    if (country.tier == 'restricted') {
      final ipCountryCode = geoCountry.value?.countryCode;
      if (ipCountryCode != country.iso2) {
        allowedToRegister.value = false;
        restrictedMessage.value = configData.value?.geoRule.blockedMessage ?? 
            'Sorry, our services are not available in this country.';
      } else {
        allowedToRegister.value = true;
        restrictedMessage.value = '';
      }
    } else {
      allowedToRegister.value = true;
      restrictedMessage.value = '';
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? mobile,
    String? referCode,
  }) async {
    final country = selectedCountry.value;
    if (country == null) return false;

    // Construct the standard API payload expected by AuthController.
    // The missing fields will simply be omitted from the map.
    final payload = <String, dynamic>{
      'email': email,
      'password': password,
      'country': country.iso2.toUpperCase(),
      'country_slug': country.iso2.toLowerCase(),
      'register_event_type': 'register',
    };

    final phoneCountry = selectedPhoneCountry.value ?? country;
    if (phoneCountry.dialCode != null) {
      payload['country_code'] = phoneCountry.dialCode;
      payload['register_country_code'] = phoneCountry.dialCode;
    }

    if (referCode != null && referCode.isNotEmpty) {
      payload['refer_code'] = referCode;
    }

    // Only attach full fields if not minimal
    if (!isMinimal.value) {
      if (firstName != null && firstName.isNotEmpty) {
        payload['first_name'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        payload['last_name'] = lastName;
      }
      if (mobile != null && mobile.isNotEmpty) {
        payload['mobile'] = mobile;
      }
    }

    return await _authController.register(data: payload);
  }

  Future<bool> verifyOtp(String email, String otp) async {
    final payload = <String, dynamic>{
      'email': email,
      'otp': otp,
      'register_event_type': 'verifyOtp',
    };
    return await _authController.registerWithOTPVerification(data: payload);
  }
}
