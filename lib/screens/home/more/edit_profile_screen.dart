import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/more/view_models/edit_profile_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/dropdown_service.dart';
import 'package:crm_app/models/dropdown_models.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/utils/app_picker_theme.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:phone_numbers_parser/metadata.dart';

import '../../../constants/text_styles.dart';
import '../../../widgets/common_loading_widget.dart';

class EditProfile extends StatefulWidget {
  EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _titleController = TextEditingController();

  DateTime? _selectedDate;
  final LanguageService languageService = Get.find<LanguageService>();
  final EditProfileController controller = Get.put(EditProfileController());
  late DropdownService dropdownService;
  late bool isProfileVerified;

  String _selectedCountryCode = '';
  String _selectedCountryFlag = '';
  IsoCode? _selectedIsoCode;
  int _maxPhoneDigits = 15;

  @override
  void initState() {
    super.initState();
    isProfileVerified = Get.arguments ?? false;
    dropdownService = Get.find<DropdownService>();
    _addListeners();
    _bindControllerData();
    ever(dropdownService.selectedCountry, (country) {
      if (country != null && _selectedCountryCode.isEmpty) {
        final countries = CountryService().getAll();
        final matchedCountry = countries.firstWhereOrNull(
          (c) =>
              c.name.toLowerCase() == country.name?.toLowerCase() ||
              c.countryCode.toLowerCase() == country.iso2?.toLowerCase(),
        );
        if (matchedCountry != null) {
          _applyCountry(
            phoneCode: matchedCountry.phoneCode,
            flagEmoji: matchedCountry.flagEmoji,
            countryIso2: matchedCountry.countryCode,
          );
        }
      }
    });
  }

  void _addListeners() {
    _firstNameController.addListener(() {
      controller.updateFirstName(_firstNameController.text);
    });
    _lastNameController.addListener(() {
      controller.updateLastName(_lastNameController.text);
    });
    _emailController.addListener(() {
      controller.updateEmail(_emailController.text);
    });
    _phoneController.addListener(() {
      final digits = _phoneDigits;
      final combined = '$_selectedCountryCode$digits';
      if (controller.phone.value != combined) {
        controller.updatePhone(combined);
      }
    });
    _addressController.addListener(() {
      controller.updateAddress(_addressController.text);
    });
    _postcodeController.addListener(() {
      controller.updatePostcode(_postcodeController.text);
    });
    _titleController.addListener(() {
      controller.updateTitle(_titleController.text);
    });
  }

  void _bindControllerData() {
    // Listen to controller data changes and update text controllers
    void _syncController(TextEditingController target, String value) {
      if (target.text == value) return;
      target.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }

    ever(controller.firstName, (value) {
      _syncController(_firstNameController, value);
    });
    ever(controller.lastName, (value) {
      _syncController(_lastNameController, value);
    });
    ever(controller.email, (value) {
      _syncController(_emailController, value);
    });
    ever(controller.phone, (value) {
      _parseAndSetPhoneNumber(value);
    });
    ever(controller.address, (value) {
      _syncController(_addressController, value);
    });
    ever(controller.postcode, (value) {
      _syncController(_postcodeController, value);
    });
    ever(controller.title, (value) {
      _syncController(_titleController, value);
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _postcodeController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  IsoCode? _isoFromCountryCode(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return null;
    final upper = countryCode.toUpperCase();
    for (final iso in IsoCode.values) {
      if (iso.name == upper) return iso;
    }
    return null;
  }

  int _maxDigitsForIso(IsoCode? iso) {
    if (iso == null) return 15;
    final lengths = metadataLenghtsByIsoCode[iso];
    if (lengths == null) return 15;
    final all = <int>[
      ...lengths.general,
      ...lengths.mobile,
      ...lengths.fixedLine,
    ];
    if (all.isEmpty) return 15;
    return all.reduce((a, b) => a > b ? a : b);
  }

  String get _phoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

  // ignore: unused_element
  bool _isPhoneValid() {
    final digits = _phoneDigits;
    if (digits.isEmpty) return false;
    final iso = _selectedIsoCode;
    if (iso == null) return digits.length >= 6;
    try {
      final number = PhoneNumber.parse(digits, destinationCountry: iso);
      return number.isValid(type: PhoneNumberType.mobile) || number.isValid();
    } catch (_) {
      return false;
    }
  }

  void _formatPhoneInput() {
    final iso = _selectedIsoCode;
    final digits = _phoneDigits;
    if (iso == null || digits.isEmpty) return;
    try {
      final formatted =
          PhoneNumber.parse(digits, destinationCountry: iso).formatNsn();
      if (formatted.isNotEmpty && formatted != _phoneController.text) {
        _phoneController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    } catch (_) {}
  }

  void _applyCountry({
    required String phoneCode,
    required String flagEmoji,
    required String countryIso2,
  }) {
    final iso = _isoFromCountryCode(countryIso2);
    setState(() {
      _selectedCountryCode = "+$phoneCode";
      _selectedCountryFlag = "$flagEmoji +$phoneCode";
      _selectedIsoCode = iso;
      _maxPhoneDigits = _maxDigitsForIso(iso);
    });
    final digits = _phoneDigits;
    if (digits.length > _maxPhoneDigits) {
      _phoneController.text = digits.substring(0, _maxPhoneDigits);
    }
    _formatPhoneInput();

    final combined = '$_selectedCountryCode$digits';
    if (controller.phone.value != combined) {
      controller.updatePhone(combined);
    }
  }

  // ignore: unused_element
  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: AppColors.whiteColor,
        textStyle: AppTextStyles.bodyText.copyWith(fontSize: 16, color: AppColors.textPrimary),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: languageService.tr('edit_profile_search'),
          hintText: languageService.tr('edit_profile_start_typing'),
          prefixIcon: Icon(Icons.search, color: AppColors.textPrimary),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.placeholderSoft),
          ),
        ),
      ),
      onSelect: (Country country) {
        _applyCountry(
          phoneCode: country.phoneCode,
          flagEmoji: country.flagEmoji,
          countryIso2: country.countryCode,
        );
      },
    );
  }

  void _applyDefaultDeviceCountryCode() {
    final deviceCountryCode = Get.deviceLocale?.countryCode ?? 'US';
    final countries = CountryService().getAll();
    final countryToApply = countries.firstWhereOrNull(
      (c) => c.countryCode.toUpperCase() == deviceCountryCode.toUpperCase(),
    ) ?? countries.firstWhereOrNull((c) => c.countryCode == 'US');

    if (countryToApply != null) {
      final iso = _isoFromCountryCode(countryToApply.countryCode);
      setState(() {
        _selectedCountryCode = "+${countryToApply.phoneCode}";
        _selectedCountryFlag = "${countryToApply.flagEmoji} +${countryToApply.phoneCode}";
        _selectedIsoCode = iso;
        _maxPhoneDigits = _maxDigitsForIso(iso);
      });
    }
  }

  void _parseAndSetPhoneNumber(String fullNumber) {
    if (fullNumber.isEmpty) {
      if (_phoneController.text.isNotEmpty) {
        _phoneController.text = '';
      }
      _applyDefaultDeviceCountryCode();
      return;
    }

    String nationalNumber = fullNumber;
    String phoneCode = '';
    String countryIso = '';

    if (fullNumber.startsWith('+')) {
      try {
        final parsed = PhoneNumber.parse(fullNumber);
        phoneCode = parsed.countryCode;
        nationalNumber = parsed.nsn;
        countryIso = parsed.isoCode.name;
      } catch (e) {
        final countries = CountryService().getAll();
        for (final country in countries) {
          final prefix = '+${country.phoneCode}';
          if (fullNumber.startsWith(prefix)) {
            phoneCode = country.phoneCode;
            nationalNumber = fullNumber.substring(prefix.length);
            countryIso = country.countryCode;
            break;
          }
        }
      }
    }

    if (phoneCode.isNotEmpty) {
      final countries = CountryService().getAll();
      final country = countries.firstWhereOrNull(
        (c) =>
            c.phoneCode == phoneCode &&
            (countryIso.isEmpty ||
                c.countryCode.toUpperCase() == countryIso.toUpperCase()),
      );
      if (country != null) {
        final iso = _isoFromCountryCode(country.countryCode);
        setState(() {
          _selectedCountryCode = "+${country.phoneCode}";
          _selectedCountryFlag = "${country.flagEmoji} +${country.phoneCode}";
          _selectedIsoCode = iso;
          _maxPhoneDigits = _maxDigitsForIso(iso);
        });
      }
    } else {
      final selectedCountry = dropdownService.selectedCountry.value;
      Country? country;
      if (selectedCountry != null) {
        final countries = CountryService().getAll();
        country = countries.firstWhereOrNull(
          (c) =>
              c.name.toLowerCase() == selectedCountry.name?.toLowerCase() ||
              c.countryCode.toLowerCase() ==
                  selectedCountry.iso2?.toLowerCase(),
        );
      }
      
      if (country != null) {
        final iso = _isoFromCountryCode(country!.countryCode);
        setState(() {
          _selectedCountryCode = "+${country!.phoneCode}";
          _selectedCountryFlag = "${country!.flagEmoji} +${country!.phoneCode}";
          _selectedIsoCode = iso;
          _maxPhoneDigits = _maxDigitsForIso(iso);
        });
      } else {
        _applyDefaultDeviceCountryCode();
      }
    }

    final currentDigits = _phoneController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final newDigits = nationalNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (currentDigits != newDigits) {
      _phoneController.value = TextEditingValue(
        text: nationalNumber,
        selection: TextSelection.collapsed(offset: nationalNumber.length),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await AppPickerTheme.showAppDatePicker(
      context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // 18 years ago
      firstDate: DateTime.now().subtract(
        const Duration(days: 36500),
      ), // 100 years ago
      lastDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // 18 years ago
    );
    if (picked != null && picked != _selectedDate) {
      _selectedDate = picked;
      controller.updateDateOfBirth(DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  void _showCountryOptions() {
    final TextEditingController searchController = TextEditingController();
    final RxList<CountryModel> filteredCountries = <CountryModel>[].obs;

    // Initialize filtered list with all countries
    filteredCountries.value = List.from(dropdownService.countries);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    languageService.tr('edit_profile_select_country'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  TextField(
                    controller: searchController,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: languageService.tr('edit_profile_search_countries'),
                      hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                      prefixIcon: Icon(Icons.search, color: AppColors.iconGrey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      filteredCountries.value =
                          dropdownService.countries
                              .where(
                                (country) => country.name!
                                    .toLowerCase()
                                    .contains(value.toLowerCase()),
                              )
                              .toList();
                    },
                  ),
                  SizedBox(height: 20.h),
                  Expanded(
                    child: Obx(
                      () => ListView.builder(
                        itemCount: filteredCountries.length,
                        itemBuilder: (context, index) {
                          final country = filteredCountries[index];
                          return ListTile(
                            leading: Text(
                              country.emoji ?? '',
                              style: AppTextStyles.bodyText.copyWith(fontSize: 24),
                            ),
                            title: Text(
                              country.name ?? '',
                              style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                            ),
                            onTap: () {
                              dropdownService.selectCountry(country);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showStateOptions() {
    final TextEditingController searchController = TextEditingController();
    final RxList<StateModel> filteredStates = <StateModel>[].obs;

    // Initialize filtered list with all states
    filteredStates.value = List.from(dropdownService.states);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    languageService.tr('edit_profile_select_state'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  TextField(
                    controller: searchController,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: languageService.tr('edit_profile_search_states'),
                      hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                      prefixIcon: Icon(Icons.search, color: AppColors.iconGrey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      filteredStates.value =
                          dropdownService.states
                              .where(
                                (state) => state.name.toLowerCase().contains(
                                  value.toLowerCase(),
                                ),
                              )
                              .toList();
                    },
                  ),
                  SizedBox(height: 20.h),
                  Expanded(
                    child: Obx(
                      () => ListView.builder(
                        itemCount: filteredStates.length,
                        itemBuilder: (context, index) {
                          final state = filteredStates[index];
                          return ListTile(
                            title: Text(
                              state.name,
                              style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                            ),
                            onTap: () {
                              dropdownService.selectState(state);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showCityOptions() {
    final TextEditingController searchController = TextEditingController();
    final RxList<CityModel> filteredCities = <CityModel>[].obs;

    // Initialize filtered list with all cities
    filteredCities.value = List.from(dropdownService.cities);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    languageService.tr('edit_profile_select_city'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  TextField(
                    controller: searchController,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: languageService.tr('edit_profile_search_cities'),
                      hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                      prefixIcon: Icon(Icons.search, color: AppColors.iconGrey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      filteredCities.value =
                          dropdownService.cities
                              .where(
                                (city) => city.name.toLowerCase().contains(
                                  value.toLowerCase(),
                                ),
                              )
                              .toList();
                    },
                  ),
                  SizedBox(height: 20.h),
                  Expanded(
                    child: Obx(
                      () => ListView.builder(
                        itemCount: filteredCities.length,
                        itemBuilder: (context, index) {
                          final city = filteredCities[index];
                          return ListTile(
                            title: Text(
                              city.name,
                              style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                            ),
                            onTap: () {
                              dropdownService.selectCity(city);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showBottomSheetList({
    required BuildContext context,
    required List<String> items,
    required String title,
    required ValueChanged<String> onItemSelected,
  }) {
    final itemHeight = 56.0;
    final maxHeight =
        MediaQuery.of(context).size.height * 0.85; // below app bar
    final totalHeight =
        (items.length * itemHeight) + 80; // include padding + title

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: totalHeight > maxHeight ? maxHeight : totalHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  title,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        items[index],
                        style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onItemSelected(items[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            scrolledUnderElevation: 0.0,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.backgroundLight,
            title: Text(
              languageService.tr('edit_profile'),
              style: AppTextStyles.screenTitle,
            ),
            leading: const AppBackButton(),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Obx(() {
                if (controller.isInitializing.value) {
                  return Center(
                    child: CommonLoadingWidget(
                      message: languageService.tr('edit_profile_loading'),
                      size: 50.0,
                      color: AppColors.primary,
                    ),
                  );
                }

                if (controller.errorMessage.value.isNotEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        SizedBox(height: 50.h),
                        Icon(
                          Icons.error_outline,
                          size: 48.h,
                          color: AppColors.red,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          controller.errorMessage.value,
                          style: AppTextStyles.subheading.copyWith(
                            color: AppColors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton(
                          onPressed: () {
                            controller.initializeData();
                          },
                          child: Text(languageService.tr('edit_profile_retry')),
                        ),
                      ],
                    ),
                  );
                }

                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RTLHelper.rtlTextField(
                        controller: _firstNameController,
                        readOnly: isProfileVerified,
                        labelText: languageService.tr(
                          'edit_profile_first_name',
                        ),
                        hintText: languageService.tr(
                          'edit_profile_please_enter_first_name',
                        ),
                        decoration: InputDecoration(
                          labelText: languageService.tr(
                            'edit_profile_first_name',
                          ),
                          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                          floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_enter_first_name',
                          ),
                          hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageService.tr(
                              'edit_profile_please_enter_first_name',
                            );
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      Obx(
                        () => RTLHelper.rtlTextField(
                          controller: TextEditingController(
                            text: controller.title.value,
                          ),
                          labelText: languageService.tr('kyc_details_title'),
                          readOnly: true,
                          onTap:
                              isProfileVerified
                                  ? null
                                  : () => _showBottomSheetList(
                                    context: context,
                                    items: controller.titleList,
                                    title: languageService.tr(
                                      'edit_profile_select_title',
                                    ),
                                    onItemSelected: (value) {
                                      controller.updateTitle(value);
                                    },
                                  ),
                          suffixIcon: Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.icongrey,
                          ),
                          decoration: InputDecoration(
                            labelText: languageService.tr('kyc_details_title'),
                            labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                            floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (value) {
                            if (controller.title.value.isEmpty) {
                              return languageService.tr(
                                'edit_profile_select_title',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16.h),
                      RTLHelper.rtlTextField(
                        controller: _lastNameController,
                        readOnly: isProfileVerified,
                        labelText: languageService.tr('edit_profile_last_name'),
                        hintText: languageService.tr(
                          'edit_profile_please_enter_last_name',
                        ),
                        decoration: InputDecoration(
                          labelText: languageService.tr(
                            'edit_profile_last_name',
                          ),
                          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                          floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_enter_last_name',
                          ),
                          hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageService.tr(
                              'edit_profile_please_enter_last_name',
                            );
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      RTLHelper.rtlTextField(
                        controller: _emailController,
                        readOnly: isProfileVerified,
                        labelText: languageService.tr('edit_profile_email'),
                        hintText: languageService.tr(
                          'edit_profile_please_enter_email',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: languageService.tr('edit_profile_email'),
                          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                          floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_enter_email',
                          ),
                          hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageService.tr(
                              'edit_profile_please_enter_email',
                            );
                          }
                          if (!RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          ).hasMatch(value)) {
                            return languageService.tr(
                              'edit_profile_please_enter_valid_email',
                            );
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: null,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 16.h,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _selectedCountryFlag.isNotEmpty
                                      ? _selectedCountryFlag
                                      : "🌐 +--",
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 16.sp,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                readOnly: true,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9\s\-()]'),
                                  ),
                                  _PhoneDigitsLimitFormatter(
                                    () => _maxPhoneDigits,
                                  ),
                                ],
                                onChanged: (_) => _formatPhoneInput(),
                                style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  labelText: languageService.tr(
                                    'edit_profile_mobile_number',
                                  ),
                                  labelStyle: AppTextStyles.bodyText.copyWith(
                                    color: AppColors.textGrey,
                                  ),
                                  floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                                    color: AppColors.primary,
                                  ),
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.error,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 16.h,
                                  ),
                                ),
                                validator: (value) {
                                  final digits = (value ?? '').replaceAll(
                                    RegExp(r'[^0-9]'),
                                    '',
                                  );
                                  if (digits.isEmpty) {
                                    return languageService.tr(
                                      'edit_profile_please_enter_mobile_number',
                                    );
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // SizedBox(height: 16.h),
                      Obx(
                        () => RTLHelper.rtlTextField(
                          controller: TextEditingController(
                            text:
                                controller.dateOfBirth.value.isEmpty
                                    ? ''
                                    : controller.dateOfBirth.value,
                          ),
                          labelText: languageService.tr(
                            'edit_profile_date_of_birth',
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_select_dob',
                          ),
                          readOnly: true,
                          onTap: isProfileVerified ? null : _selectDate,
                          suffixIcon: InkWell(
                            onTap: isProfileVerified ? null : _selectDate,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: AppColors.icongrey,
                              ),
                            ),
                          ),
                          decoration: InputDecoration(
                            labelText: languageService.tr(
                              'edit_profile_date_of_birth',
                            ),
                            labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                            floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                              color: AppColors.primary,
                            ),
                            hintText: languageService.tr(
                              'edit_profile_please_select_dob',
                            ),
                            hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                          ),
                          validator: (value) {
                            if (controller.dateOfBirth.value.isEmpty) {
                              return languageService.tr(
                                'edit_profile_please_select_dob',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Obx(
                        () => RTLHelper.rtlTextField(
                          controller: TextEditingController(
                            text: controller.gender.value,
                          ),
                          labelText: languageService.tr('edit_profile_gender'),
                          readOnly: true,
                          onTap:
                              isProfileVerified
                                  ? null
                                  : () => _showBottomSheetList(
                                    context: context,
                                    items: controller.genderList,
                                    title: languageService.tr(
                                      'edit_profile_select_gender',
                                    ),
                                    onItemSelected: (value) {
                                      controller.updateGender(value);
                                    },
                                  ),
                          suffixIcon: Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.icongrey,
                          ),
                          decoration: InputDecoration(
                            labelText: languageService.tr(
                              'edit_profile_gender',
                            ),
                            labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                            floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (value) {
                            if (controller.gender.value.isEmpty) {
                              return languageService.tr(
                                'edit_profile_select_gender',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _buildCountryDropdown(),
                      // SizedBox(height: 16.h),
                      _buildStateDropdown(),
                      _buildCityDropdown(),

                      // SizedBox(height: 16.h),
                      TextFormField(
                        controller: _addressController,
                        readOnly: isProfileVerified,
                        maxLines: 3,
                        minLines: 3,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          labelText: languageService.tr('register_address'),
                          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                          floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                          ),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 12.h,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageService.tr(
                              'edit_profile_please_enter_address',
                            );
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      RTLHelper.rtlTextField(
                        controller: _postcodeController,
                        readOnly: isProfileVerified,
                        labelText: languageService.tr('edit_profile_postcode'),
                        hintText: languageService.tr(
                          'edit_profile_please_enter_postcode',
                        ),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: languageService.tr(
                            'edit_profile_postcode',
                          ),
                          labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                          floatingLabelStyle: AppTextStyles.bodyText.copyWith(
                            color: AppColors.primary,
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_enter_postcode',
                          ),
                          hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageService.tr(
                              'edit_profile_please_enter_postcode',
                            );
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 32.h),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.backgroundLight,
      bottomNavigationBar:
          isProfileVerified
              ? SizedBox.shrink()
              : Padding(
                padding: EdgeInsetsDirectional.only(
                  bottom: MediaQuery.of(context).padding.bottom + 10,
                  start: 16.w,
                  end: 16.w,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: Obx(
                    () => RTLHelper.rtlButton(
                      text:
                          controller.isSaving.value
                              ? languageService.tr('edit_profile_saving')
                              : languageService.tr('navigation_save'),
                      onPressed:
                          controller.isFormValid.value &&
                                  !controller.isSaving.value
                              ? () async {
                                // Dismiss keyboard when save button is tapped
                                FocusScope.of(context).unfocus();
                                if (_formKey.currentState!.validate()) {
                                  final success =
                                      await controller.updateProfile();
                                  if (success) {
                                    Navigator.of(context).pop();
                                  }
                                }
                              }
                              : null,
                      backgroundColor: AppColors.primary,
                      foregroundColor:
                          controller.isFormValid.value &&
                                  !controller.isSaving.value
                              ? AppColors.whiteColor
                              : AppColors.textGrey,
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildCountryDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: InkWell(
        onTap: isProfileVerified ? null : () => _showCountryOptions(),
        borderRadius: BorderRadius.circular(12),
        child: AbsorbPointer(
          absorbing: !isProfileVerified,
          child: Obx(
            () => RTLHelper.rtlTextField(
              readOnly: true,
              controller: TextEditingController(
                text: dropdownService.selectedCountryText,
              ),
              decoration: InputDecoration(
                labelText: languageService.tr('register_country'),
                labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 16.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.error),
                ),
                suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.icongrey),
              ),
              validator: (value) {
                if (dropdownService.selectedCountry.value == null) {
                  return languageService.tr('validation_country_required');
                }
                return null;
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: InkWell(
        onTap:
            isProfileVerified
                ? null
                : (dropdownService.selectedCountry.value != null
                    ? () => _showStateOptions()
                    : null),
        borderRadius: BorderRadius.circular(12),
        child: AbsorbPointer(
          absorbing: !isProfileVerified,
          child: Obx(
            () => RTLHelper.rtlTextField(
              readOnly: true,
              controller: TextEditingController(
                text: dropdownService.selectedStateText,
              ),
              decoration: InputDecoration(
                labelText: languageService.tr('edit_profile_state'),
                labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 16.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.error),
                ),
                suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.icongrey),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: InkWell(
        onTap:
            isProfileVerified
                ? null
                : (dropdownService.selectedState.value != null
                    ? () => _showCityOptions()
                    : null),
        borderRadius: BorderRadius.circular(12),
        child: AbsorbPointer(
          absorbing: !isProfileVerified,
          child: Obx(
            () => RTLHelper.rtlTextField(
              readOnly: true,
              controller: TextEditingController(
                text: dropdownService.selectedCityText,
              ),
              decoration: InputDecoration(
                labelText: languageService.tr('edit_profile_city'),
                labelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                floatingLabelStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primary),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 16.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.error),
                ),
                suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.icongrey),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneDigitsLimitFormatter extends TextInputFormatter {
  _PhoneDigitsLimitFormatter(this.maxDigits);

  final int Function() maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= maxDigits()) {
      return newValue;
    }
    return oldValue;
  }
}
