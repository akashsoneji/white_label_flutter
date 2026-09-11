import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/models/dropdown_models.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/services/language_service.dart';

class DropdownService extends GetxService {
  // Observable lists for dropdown data
  final RxList<CountryModel> countries = <CountryModel>[].obs;
  final RxList<StateModel> states = <StateModel>[].obs;
  final RxList<CityModel> cities = <CityModel>[].obs;

  // Loading states
  final RxBool isLoadingCountries = false.obs;
  final RxBool isLoadingStates = false.obs;
  final RxBool isLoadingCities = false.obs;

  // Selected values
  final Rx<CountryModel?> selectedCountry = Rx<CountryModel?>(null);
  final Rx<StateModel?> selectedState = Rx<StateModel?>(null);
  final Rx<CityModel?> selectedCity = Rx<CityModel?>(null);

  @override
  void onInit() {
    super.onInit();
    // Load countries on initialization
    loadCountries();
  }

  // Load countries
  Future<void> loadCountries() async {
    try {
      isLoadingCountries.value = true;

      final response = await Get.find<ApiClient>().get(
        endpoint: ApiConstants.getCountryDropdown,
      );

      if (response.success && response.data != null) {
        final List<dynamic> countryList =
            response.data['data'] ?? response.data;
        countries.value =
            countryList.map((json) => CountryModel.fromJson(json)).toList();
        print('✅ Loaded ${countries.length} countries');
      } else {
        print('❌ Failed to load countries: ${response.message}');
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr('dropdown_failed_load_countries'),
            title: TranslationUtils.tr('general_error'),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading countries: $e');
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr('dropdown_failed_load_countries'),
          title: TranslationUtils.tr('general_error'),
        );
      }
    } finally {
      isLoadingCountries.value = false;
    }
  }

  // Load states by country ID
  Future<void> loadStates(int countryId) async {
    try {
      isLoadingStates.value = true;
      states.clear(); // Clear previous states
      selectedState.value = null; // Clear selected state
      cities.clear(); // Clear cities when country changes
      selectedCity.value = null; // Clear selected city

      final response = await Get.find<ApiClient>().post(
        endpoint: ApiConstants.getStateDropdown,
        data: {'country_id': countryId},
      );

      if (response.success && response.data != null) {
        final List<dynamic> stateList = response.data['data'] ?? response.data;
        states.value =
            stateList.map((json) => StateModel.fromJson(json)).toList();
        print('✅ Loaded ${states.length} states for country $countryId');
      } else {
        print('❌ Failed to load states: ${response.message}');
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr('dropdown_failed_load_states'),
            title: TranslationUtils.tr('general_error'),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading states: $e');
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr('dropdown_failed_load_states'),
          title: TranslationUtils.tr('general_error'),
        );
      }
    } finally {
      isLoadingStates.value = false;
    }
  }

  // Load cities by state ID
  Future<void> loadCities(int stateId) async {
    try {
      isLoadingCities.value = true;
      cities.clear(); // Clear previous cities
      selectedCity.value = null; // Clear selected city

      final response = await Get.find<ApiClient>().post(
        endpoint: ApiConstants.getCityDropdown,
        data: {'state_id': stateId},
      );

      if (response.success && response.data != null) {
        final List<dynamic> cityList = response.data['data'] ?? response.data;
        cities.value =
            cityList.map((json) => CityModel.fromJson(json)).toList();
        print('✅ Loaded ${cities.length} cities for state $stateId');
      } else {
        print('❌ Failed to load cities: ${response.message}');
        if (Get.isRegistered<AppNotificationController>()) {
          Get.find<AppNotificationController>().showError(
            message: TranslationUtils.tr('dropdown_failed_load_cities'),
            title: TranslationUtils.tr('general_error'),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading cities: $e');
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: TranslationUtils.tr('dropdown_failed_load_cities'),
          title: TranslationUtils.tr('general_error'),
        );
      }
    } finally {
      isLoadingCities.value = false;
    }
  }

  // Set selected country and load states
  void selectCountry(CountryModel? country) {
    selectedCountry.value = country;
    if (country != null) {
      loadStates(country.id!);
    } else {
      states.clear();
      cities.clear();
      selectedState.value = null;
      selectedCity.value = null;
    }
  }

  // Set selected state and load cities
  void selectState(StateModel? state) {
    selectedState.value = state;
    if (state != null) {
      loadCities(state.id);
    } else {
      cities.clear();
      selectedCity.value = null;
    }
  }

  // Set selected city
  void selectCity(CityModel? city) {
    selectedCity.value = city;
  }

  // Reset all selections
  void resetSelections() {
    selectedCountry.value = null;
    selectedState.value = null;
    selectedCity.value = null;
    states.clear();
    cities.clear();
  }

  // Get display text for selected values
  String get selectedCountryText => selectedCountry.value?.name ?? '';
  String get selectedStateText => selectedState.value?.name ?? '';
  String get selectedCityText => selectedCity.value?.name ?? '';

  // Check if all required fields are selected
  bool get isComplete =>
      selectedCountry.value != null &&
      selectedState.value != null &&
      selectedCity.value != null;
}
