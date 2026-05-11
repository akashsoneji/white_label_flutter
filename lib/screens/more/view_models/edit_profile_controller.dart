import 'package:get/get.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/dropdown_service.dart';
import 'package:crm_app/models/settings_profile_model.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/profile/data/repositories/profile_repository.dart';

class EditProfileController extends GetxController {
  final ProfileRepository _repo = Get.find<ProfileRepository>();
  // Observable variables
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isInitializing = true.obs;

  // Profile data
  final RxString firstName = ''.obs;
  final RxString lastName = ''.obs;
  final RxString email = ''.obs;
  final RxString phone = ''.obs;
  final RxString address = ''.obs;
  final RxString postcode = ''.obs;
  final RxString title = ''.obs;
  final RxString gender = ''.obs;
  final RxString dateOfBirth = ''.obs;

  // Form validation
  final RxBool isFormValid = false.obs;

  // Dropdown data
  final RxList<String> genderList = ['Male', 'Female', 'Other'].obs;
  final RxList<String> titleList = ['Mr', 'Mrs', 'Ms', 'Dr'].obs;

  // Services
  late DropdownService dropdownService;
  late AuthController authController;

  @override
  void onInit() {
    super.onInit();
    // Initialize services
    dropdownService = Get.put(DropdownService());
    authController = Get.find<AuthController>();
    initializeData();
  }

  Future<void> initializeData() async {
    try {
      // Fetch profile data
      final profileData = await authController.getProfile();

      if (profileData != null) {
        await _populateFormWithProfileData(profileData);
      }
    } catch (e) {
      print('Error initializing profile data: $e');
      errorMessage.value = 'Error loading profile data: $e';
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> _populateFormWithProfileData(
    SettingsProfileData profileData,
  ) async {
    final user = profileData.data.user;
    final userDetails = user.userDetails;

    // Populate basic fields
    firstName.value = user.firstName;
    lastName.value = user.lastName;
    email.value = user.email;
    phone.value = user.mobile;
    title.value = userDetails.title;
    gender.value = userDetails.gender;
    address.value = userDetails.address1;
    postcode.value = userDetails.postcode;

    // Format date of birth as yyyy-MM-dd
    final dateStr = userDetails.dob.toString();
    if (dateStr.contains(' ')) {
      dateOfBirth.value = dateStr.split(' ')[0];
    } else {
      dateOfBirth.value = dateStr;
    }

    // Handle location IDs - convert to names
    if (userDetails.country != 0) {
      final countryId = userDetails.country;
      // Wait for countries to load first
      while (dropdownService.countries.isEmpty &&
          dropdownService.isLoadingCountries.value) {
        await Future.delayed(Duration(milliseconds: 100));
      }

      // Find country by ID and select it
      final country = dropdownService.countries.firstWhereOrNull(
        (c) => c.id == countryId,
      );
      if (country != null) {
        dropdownService.selectCountry(country);

        // Wait for states to load, then find state
        if (userDetails.state != 0) {
          final stateId = userDetails.state;
          // Wait for states to load
          while (dropdownService.states.isEmpty &&
              dropdownService.isLoadingStates.value) {
            await Future.delayed(Duration(milliseconds: 100));
          }

          final state = dropdownService.states.firstWhereOrNull(
            (s) => s.id == stateId,
          );
          if (state != null) {
            dropdownService.selectState(state);

            // Wait for cities to load, then find city
            if (userDetails.city != 0) {
              final cityId = userDetails.city;
              // Wait for cities to load
              while (dropdownService.cities.isEmpty &&
                  dropdownService.isLoadingCities.value) {
                await Future.delayed(Duration(milliseconds: 100));
              }

              final city = dropdownService.cities.firstWhereOrNull(
                (c) => c.id == cityId,
              );
              if (city != null) {
                dropdownService.selectCity(city);
              }
            }
          }
        }
      }
    }

    validateForm();
  }

  // Update profile data
  Future<bool> updateProfile() async {
    final token = await SecureStorageService.getAuthToken();
    try {
      isSaving.value = true;
      errorMessage.value = '';

      final response = await _repo.updateProfile(
        token: token ?? '',
        payload: {
          "page1": {
            "email": email.value,
            "title": title.value,
            "gender": gender.value,
          },
          "page2": {
            "date_of_birth": dateOfBirth.value,
            "alt_mobile": phone.value,
            "alt_email": email.value,
          },
          "page3": {
            "country": dropdownService.selectedCountry.value?.id ?? 0,
            "state": dropdownService.selectedState.value?.id ?? 0,
            "city": dropdownService.selectedCity.value?.id ?? 0,
            "nationality":
                dropdownService.selectedCountry.value?.nationality ?? '',
          },
          "page4": {
            "address_line1": address.value,
            "address_line2": "",
            "postcode": postcode.value,
            "language": "English",
          },
          "page5": {
            "us_citizen": "no",
            "politically_exposed": "no",
            "industry": "finance",
            "tax_identification_number": "",
          },
          "is_app": "1",
          "user_id": authController.userData?.id ?? '',
          "auth_key": token,
        },
      );

      if (response.success) {
        // Show success toast
        CustomToastService.showSuccess(
          message: response.message ?? 'Profile updated successfully!',
        );

        // Refresh user data
        await authController.refreshUserData();

        return true;
      } else {
        errorMessage.value = response.message ?? 'Failed to update profile';
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Error updating profile: $e';
      print('Exception in updateProfile: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // Validate form
  void validateForm() {
    // Required fields: first name, last name, email, phone, date of birth, gender, country
    // Optional fields: state, city, address
    isFormValid.value =
        firstName.value.isNotEmpty &&
        lastName.value.isNotEmpty &&
        email.value.isNotEmpty &&
        phone.value.isNotEmpty &&
        dateOfBirth.value.isNotEmpty &&
        gender.value.isNotEmpty &&
        dropdownService.selectedCountry.value != null;
  }

  // Update individual fields
  void updateFirstName(String value) {
    firstName.value = value;
    validateForm();
  }

  void updateLastName(String value) {
    lastName.value = value;
    validateForm();
  }

  void updateEmail(String value) {
    email.value = value;
    validateForm();
  }

  void updatePhone(String value) {
    phone.value = value;
    validateForm();
  }

  void updateAddress(String value) {
    address.value = value;
    validateForm();
  }

  void updatePostcode(String value) {
    postcode.value = value;
    validateForm();
  }

  void updateTitle(String value) {
    title.value = value;
    validateForm();
  }

  void updateGender(String value) {
    gender.value = value;
    validateForm();
  }

  void updateDateOfBirth(String value) {
    dateOfBirth.value = value;
    validateForm();
  }
}
