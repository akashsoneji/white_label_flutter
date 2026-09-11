import 'dart:io';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/kyc/data/repositories/kyc_repository.dart';
import 'package:crm_app/services/dropdown_service.dart';
import 'package:crm_app/models/dropdown_models.dart';

class ComplianceController extends GetxController {
  final KycRepository _repo = Get.find<KycRepository>();
  final ApiClient _api = Get.find<ApiClient>();
  final AuthController _authController = Get.find<AuthController>();

  // State Observables
  final RxBool isLoading = false.obs;
  final RxBool isSchemaLoading = false.obs;
  final RxBool isCheckingMobile = false.obs;
  final RxBool isMobileAvailable = true.obs;
  final RxString mobileError = ''.obs;

  // Wizard Routing State
  final RxInt currentStep = 0.obs; // 0 = Questionnaire, 1 = Documents Upload

  // Dynamic Questionnaire State
  final RxList<dynamic> schemaFields = <dynamic>[].obs;
  final RxMap<String, dynamic> formAnswers = <String, dynamic>{}.obs;

  // Selected Documents
  final Rx<File?> idProofFront = Rx<File?>(null);
  final Rx<File?> idProofBack = Rx<File?>(null);
  final Rx<File?> addressProofFront = Rx<File?>(null);
  final Rx<File?> addressProofBack = Rx<File?>(null);

  late final DropdownService dropdownService;

  @override
  void onInit() {
    super.onInit();
    dropdownService = Get.put(DropdownService());
    
    // Bind listeners to sync DropdownService changes to formAnswers
    ever(dropdownService.selectedCountry, (CountryModel? country) {
      if (country != null) {
        formAnswers['country'] = country.id.toString();
        formAnswers['country_name'] = country.name ?? '';
        // Reset state/city
        formAnswers['state'] = '';
        formAnswers['state_name'] = '';
        formAnswers['city'] = '';
        formAnswers['city_name'] = '';
      } else {
        formAnswers['country'] = '';
        formAnswers['country_name'] = '';
      }
    });

    ever(dropdownService.selectedState, (StateModel? state) {
      if (state != null) {
        formAnswers['state'] = state.id.toString();
        formAnswers['state_name'] = state.name;
        // Reset city
        formAnswers['city'] = '';
        formAnswers['city_name'] = '';
      } else {
        formAnswers['state'] = '';
        formAnswers['state_name'] = '';
      }
    });

    ever(dropdownService.selectedCity, (CityModel? city) {
      if (city != null) {
        formAnswers['city'] = city.id.toString();
        formAnswers['city_name'] = city.name;
      } else {
        formAnswers['city'] = '';
        formAnswers['city_name'] = '';
      }
    });

    _prepopulateFromProfile();
  }

  Future<void> _prepopulateFromProfile() async {
    final profile = _authController.profileData;
    if (profile != null) {
      final user = profile.data.user;
      final details = user.userDetails;

      // Basic Profile Info
      formAnswers['email'] = user.email;
      formAnswers['mobile'] = user.mobile;
      formAnswers['first_name'] = user.firstName;
      formAnswers['last_name'] = user.lastName;
      formAnswers['title'] = details.title.isNotEmpty ? details.title : 'Mr';
      formAnswers['gender'] = details.gender.isNotEmpty ? details.gender : 'male';
      formAnswers['dob'] = details.dob.toIso8601String().split('T')[0];

      // Residential Address
      formAnswers['country'] = details.country.toString();
      formAnswers['country_name'] = details.country_name;
      formAnswers['nationality'] = details.nationality;
      formAnswers['state'] = details.state.toString();
      formAnswers['state_name'] = details.state_name;
      formAnswers['city'] = details.city.toString();
      formAnswers['city_name'] = details.city_name;
      formAnswers['address_1'] = details.address1;
      formAnswers['address_2'] = details.address2;
      formAnswers['postcode'] = details.postcode;

      // Questionnaire Options defaults
      formAnswers['us_resident'] = 'no';
      formAnswers['multiple_citizenship'] = 'no';
      formAnswers['employment_type'] = 'employed';
      formAnswers['industry'] = 'banking_and_financial_services';
      formAnswers['annual_basic_salary'] = '15000_50000';
      formAnswers['additional_income'] = 'none';
      formAnswers['estimated_total_annual_income'] = 'lt_25000';
      formAnswers['expected_deposit_12m'] = 'lt_5000';
      formAnswers['source_of_funds'] = 'salary';
      formAnswers['origin_of_wealth'] = 'employment_income';
      formAnswers['multi_jurisdiction_tax'] = 'no';
      formAnswers['tax_residence_country'] = details.country_name.isNotEmpty ? details.country_name : '';
      formAnswers['tin'] = details.taxIdentificationNumber;
      formAnswers['tin_missing_reason'] = 'not_required';

      // Sync dropdown service selected values
      try {
        if (details.country != 0) {
          if (dropdownService.countries.isEmpty) {
            await dropdownService.loadCountries();
          }
          final country = dropdownService.countries.firstWhereOrNull((c) => c.id == details.country);
          if (country != null) {
            dropdownService.selectedCountry.value = country;
            // Always load states for the pre-selected country so dropdown works
            await dropdownService.loadStates(country.id!);
            
            // Re-apply formAnswers since the `ever` listener might have wiped them
            formAnswers['state'] = details.state != 0 ? details.state.toString() : '';
            formAnswers['state_name'] = details.state_name;
            formAnswers['city'] = details.city != 0 ? details.city.toString() : '';
            formAnswers['city_name'] = details.city_name;

            if (details.state != 0) {
              final state = dropdownService.states.firstWhereOrNull((s) => s.id == details.state);
              if (state != null) {
                dropdownService.selectedState.value = state;
                // Always load cities for the pre-selected state so dropdown works
                await dropdownService.loadCities(state.id!);

                // Re-apply city formAnswers since `ever` listener on state might wipe them
                formAnswers['city'] = details.city != 0 ? details.city.toString() : '';
                formAnswers['city_name'] = details.city_name;

                if (details.city != 0) {
                  final city = dropdownService.cities.firstWhereOrNull((c) => c.id == details.city);
                  if (city != null) {
                    dropdownService.selectedCity.value = city;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        print('ComplianceController: Error syncing dropdown service items: $e');
      }
    }
  }

  // Fetch Regulation Dynamic Questionnaire Schema
  Future<void> fetchRegulationSchema() async {
    try {
      isSchemaLoading.value = true;
      final token = await SecureStorageService.getAuthToken();
      if (token == null || token.isEmpty) return;

      final response = await _repo.getRegulationSchema(token: token);
      if (response.success && response.data != null) {
        final schema = response.data['data']?['schema'];
        if (schema is List) {
          schemaFields.assignAll(schema);
        }
      } else {
        print('ComplianceController: Dynamic schema fetch failed');
      }
    } catch (e) {
      print('ComplianceController: Error fetching schema: $e');
    } finally {
      isSchemaLoading.value = false;
    }
  }

  // Check Mobile Number Availability
  Future<void> checkMobileAvailability(String mobile, String countryCode) async {
    if (mobile.isEmpty) return;
    try {
      isCheckingMobile.value = true;
      mobileError.value = '';
      final token = await SecureStorageService.getAuthToken();
      
      final response = await _api.post(
        endpoint: ApiConstants.checkMobile,
        token: token,
        data: {
          'mobile': mobile,
          'country_code': countryCode,
        },
      );

      if (response.success) {
        isMobileAvailable.value = true;
      } else {
        isMobileAvailable.value = false;
        mobileError.value = response.message ?? 'Mobile number is already registered or invalid.';
      }
    } catch (e) {
      print('ComplianceController: Error checking mobile number: $e');
    } finally {
      isCheckingMobile.value = false;
    }
  }

  // Dynamic conditional visibility resolver
  bool isFieldVisible(Map<String, dynamic> field) {
    final visibleWhen = field['visible_when'];
    if (visibleWhen == null || visibleWhen == '' || visibleWhen is! Map) {
      return true;
    }

    final String? dependsOn = visibleWhen['field_key'];
    final String? op = visibleWhen['op'];
    final dynamic expectedValue = visibleWhen['value'];

    if (dependsOn == null || dependsOn.isEmpty) return true;

    final currentValue = formAnswers[dependsOn];
    if (op == 'equals') {
      return currentValue?.toString().toLowerCase() == expectedValue?.toString().toLowerCase();
    }

    return true;
  }

  // Dynamic Questionnaire Submission (Step 1)
  Future<bool> submitQuestionnaire() async {
    try {
      isLoading.value = true;

      // 1. Validation check
      for (final f in schemaFields) {
        if (f is! Map) continue;
        final key = f['field_key']?.toString() ?? '';
        final isRequired = f['is_required'] == true;
        if (isRequired && isFieldVisible(f as Map<String, dynamic>)) {
          final val = formAnswers[key];
          if (val == null || val.toString().trim().isEmpty) {
        CustomToastService.showWarning(
          message:
              '${TranslationUtils.tr('compliance_controller_please_complete_all_required_fields')}: ${f['label']}',
        );
            isLoading.value = false;
            return false;
          }
        }
      }

      // Check mobile number status
      if (!isMobileAvailable.value) {
        CustomToastService.showError(message: 'Please resolve mobile number errors before proceeding.');
        isLoading.value = false;
        return false;
      }

      final token = await SecureStorageService.getAuthToken();
      if (token == null) {
        CustomToastService.showError(message: 'Session expired. Please log in again.');
        isLoading.value = false;
        return false;
      }

      // 2. Build profile snapshot
      final profile = _authController.profileData;
      if (profile == null) {
        CustomToastService.showError(message: 'Profile data missing.');
        isLoading.value = false;
        return false;
      }

      final snapshot = {
        'title': formAnswers['title'] ?? 'Mr',
        'gender': formAnswers['gender'] ?? 'male',
        'full_name': '${formAnswers['first_name'] ?? ''} ${formAnswers['last_name'] ?? ''}'.trim(),
        'date_of_birth': formAnswers['dob'] ?? '',
        'nationality': formAnswers['nationality'] ?? 'United Arab Emirates',
        'email': formAnswers['email'] ?? '',
        'mobile': formAnswers['mobile'] ?? '',
        'address_line1': formAnswers['address_1'] ?? 'N/A',
        'address_line2': formAnswers['address_2'] ?? '',
        'postcode': formAnswers['postcode'] ?? '',
        'country_id': formAnswers['country'] ?? '',
        'state_id': formAnswers['state'] ?? '',
        'city_id': formAnswers['city'] ?? '',
        'country_name': formAnswers['country_name'] ?? '',
        'state_name': formAnswers['state_name'] ?? '',
        'city_name': formAnswers['city_name'] ?? '',
      };

      // 3. Construct API POST body
      final payload = Map<String, dynamic>.from(formAnswers);
      payload['profile_snapshot'] = snapshot;
      payload['purpose'] = '';
      payload['purpose_other'] = '';
      payload['place_of_birth'] = '';
      payload['previous_citizenship'] = {'has': false, 'country': ''};
      payload['dual_nationality'] = {'has': false, 'country': ''};
      payload['id_number'] = '';
      payload['id_issue_date'] = '';
      payload['id_expiry_date'] = '';
      payload['office_phone'] = '';
      payload['profession'] = '';
      payload['profession_other'] = '';
      payload['employer'] = {'name': '', 'industry': '', 'job_title': ''};
      payload['trading_experience'] = {'has': false, 'years': 'lt_1'};
      payload['expected_amount_traded'] = '';
      payload['pep'] = {'is_pep': false, 'type': 'pep'};
      payload['hnwi'] = {'is_hnwi': false, 'band': 'lt_500k'};
      payload['fatca'] = {
        'us_citizen': formAnswers['us_resident'] == 'yes',
        'tax_in_us': formAnswers['us_resident'] == 'yes',
        'has_tin': formAnswers['tin'] != null && formAnswers['tin'].toString().isNotEmpty,
        'tin': formAnswers['tin'] ?? '',
        'tax_residence_country': formAnswers['tax_residence_country'] ?? '',
        'tin_not_applicable_reason': formAnswers['tin_missing_reason'] ?? '',
      };
      payload['deposit_method'] = '';
      payload['hear_about_us'] = '';
      payload['declarations'] = {'not_illegal': true};
      payload['acknowledgement'] = {'read_docs': true, 'info_true': true};

      // 3.1 Send Profile Data first
      final profilePayload = {
        'first_name': formAnswers['first_name'] ?? '',
        'last_name': formAnswers['last_name'] ?? '',
        'mobile': formAnswers['mobile'] ?? '',
        'title': formAnswers['title'] ?? 'Mr',
        'gender': formAnswers['gender'] ?? 'other',
        'dob': formAnswers['dob'] ?? '',
        'nationality': formAnswers['nationality'] ?? '',
        'country': int.tryParse(formAnswers['country']?.toString() ?? '') ?? formAnswers['country'],
        'state': int.tryParse(formAnswers['state']?.toString() ?? '') ?? formAnswers['state'],
        'city': int.tryParse(formAnswers['city']?.toString() ?? '') ?? formAnswers['city'],
        'address_1': formAnswers['address_1'] ?? '',
        'address_2': formAnswers['address_2'] ?? '',
        'postcode': formAnswers['postcode'] ?? '',
      };

      final profileResponse = await _repo.updateKycProfile(
        token: token,
        payload: profilePayload,
      );

      if (!profileResponse.success) {
        CustomToastService.showError(message: profileResponse.message ?? 'Failed to update profile details.');
        isLoading.value = false;
        return false;
      }

      // 3.2 Send Regulation Details


      final response = await _repo.submitRegulationDetails(
        token: token,
        payload: payload,
      );

      if (response.success) {
        CustomToastService.showSuccess(message: 'Regulation questionnaire saved successfully.');
        
        // Refresh local profile status so state resolves regulation_submitted = 1.
        // forceRefresh bypasses the getProfile TTL cache — this read must see the
        // server value we just mutated, not a cached pre-submit profile.
        await _authController.getProfile(forceRefresh: true);
        
        // Proceed to Step 2 (Documents Upload)
        currentStep.value = 1;
        return true;
      } else {
        CustomToastService.showError(message: response.message ?? 'Failed to submit questionnaire.');
        return false;
      }
    } catch (e) {
      print('ComplianceController: Error submitting regulation questionnaire: $e');
      CustomToastService.showError(message: 'Submission error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Upload Documents (Step 2 - Unified KYC)
  Future<bool> submitDocuments() async {
    if (idProofFront.value == null) {
      CustomToastService.showWarning(message: 'Identity Document Front is mandatory.');
      return false;
    }
    if (addressProofFront.value == null) {
      CustomToastService.showWarning(message: 'Address Proof Front is mandatory.');
      return false;
    }

    try {
      isLoading.value = true;
      final token = await SecureStorageService.getAuthToken();
      if (token == null) {
        CustomToastService.showError(message: 'Session expired. Please log in again.');
        isLoading.value = false;
        return false;
      }

      final profile = _authController.profileData;
      if (profile == null) {
        CustomToastService.showError(message: 'Profile data missing.');
        isLoading.value = false;
        return false;
      }

      final user = profile.data.user;
      final details = user.userDetails;

      // Prepare request fields from form answers
      final fields = {
        'email': formAnswers['email'] ?? user.email,
        'firstName': formAnswers['first_name'] ?? user.firstName,
        'lastName': formAnswers['last_name'] ?? user.lastName,
        'mobile': formAnswers['mobile'] ?? user.mobile,
        'title': formAnswers['title'] ?? details.title,
        'gender': formAnswers['gender'] ?? details.gender,
        'dateOfBirth': formAnswers['dob'] ?? details.dob.toIso8601String().split('T')[0],
        'nationality': formAnswers['nationality'] ?? details.nationality,
        'country': formAnswers['country']?.toString() ?? details.country.toString(),
        'state': formAnswers['state']?.toString() ?? details.state.toString(),
        'city': formAnswers['city']?.toString() ?? details.city.toString(),
        'addressLine1': formAnswers['address_1'] ?? 'N/A',
        'addressLine2': formAnswers['address_2'] ?? '',
        'postcode': formAnswers['postcode'] ?? '',
        'is_reupload': '1',
        'profile_complete': '1',
      };

      final response = await _repo.submitUnifiedKyc(
        token: token,
        fields: fields,
        identityFront: idProofFront.value!,
        addressFront: addressProofFront.value!,
        identityBack: idProofBack.value,
        addressBack: addressProofBack.value,
      );

      if (response.success) {
        CustomToastService.showSuccess(message: 'KYC documents submitted successfully.');
        
        // Refresh profile settings locally so that documents_submitted becomes true
        await _authController.getProfile();
        
        return true;
      } else {
        CustomToastService.showError(message: response.message ?? 'KYC document submission failed.');
        return false;
      }
    } catch (e) {
      print('ComplianceController: Error submitting documents: $e');
      CustomToastService.showError(message: 'KYC submission error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Picking Files
  Future<void> pickDocument(String documentType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        final File file = File(result.files.single.path!);
        final size = await file.length();
        if (size > 15 * 1024 * 1024) {
          CustomToastService.showError(message: 'File size exceeds maximum limit of 15MB.');
          return;
        }

        switch (documentType) {
          case 'identity_front':
            idProofFront.value = file;
            break;
          case 'identity_back':
            idProofBack.value = file;
            break;
          case 'address_front':
            addressProofFront.value = file;
            break;
          case 'address_back':
            addressProofBack.value = file;
            break;
        }
      }
    } catch (e) {
      print('ComplianceController: Error picking file: $e');
      CustomToastService.showError(message: 'Failed to pick document: $e');
    }
  }

  // Clear selections
  void clearDocument(String documentType) {
    switch (documentType) {
      case 'identity_front':
        idProofFront.value = null;
        break;
      case 'identity_back':
        idProofBack.value = null;
        break;
      case 'address_front':
        addressProofFront.value = null;
        break;
      case 'address_back':
        addressProofBack.value = null;
        break;
    }
  }

  // Returns formatted size string
  String getUploadedSizeSummary() {
    int totalBytes = 0;
    if (idProofFront.value != null) totalBytes += idProofFront.value!.lengthSync();
    if (idProofBack.value != null) totalBytes += idProofBack.value!.lengthSync();
    if (addressProofFront.value != null) totalBytes += addressProofFront.value!.lengthSync();
    if (addressProofBack.value != null) totalBytes += addressProofBack.value!.lengthSync();

    if (totalBytes <= 0) return '0 Bytes';
    if (totalBytes < 1024) return '$totalBytes Bytes';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int getRequiredCount() {
    int count = 0;
    if (idProofFront.value != null) count++;
    if (addressProofFront.value != null) count++;
    return count;
  }

  int getOptionalCount() {
    int count = 0;
    if (idProofBack.value != null) count++;
    if (addressProofBack.value != null) count++;
    return count;
  }
}
