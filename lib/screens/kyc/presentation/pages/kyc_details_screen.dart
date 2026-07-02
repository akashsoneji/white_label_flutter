import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/kyc_scaffold.dart';
import 'package:crm_app/widgets/otp_modal.dart';
import 'package:crm_app/utils/trl_helper.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/dropdown_service.dart';
import 'package:crm_app/models/dropdown_models.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/models/settings_profile_model.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:phone_numbers_parser/metadata.dart';

class KycDetailsScreen extends StatefulWidget {
  const KycDetailsScreen({Key? key}) : super(key: key);

  @override
  State<KycDetailsScreen> createState() => _KycDetailsScreenState();
}

class _KycDetailsScreenState extends State<KycDetailsScreen> {
  final TextEditingController _firstNameController = TextEditingController(
    text: 'Brooklyn',
  );
  final TextEditingController _lastNameController = TextEditingController(
    text: 'Simmons',
  );
  final TextEditingController _emailController = TextEditingController(
    text: 'brooklynsimmons@gmail.com',
  );
  final TextEditingController _phoneController = TextEditingController(
    text: '+91 987654321',
  );
  final TextEditingController _addressController = TextEditingController(
    text: 'Value',
  );
  // final TextEditingController _otpController = TextEditingController();
  final TextEditingController _titleController = TextEditingController(
    text: 'Mr',
  );
  final TextEditingController _dobController = TextEditingController(
    text: '1990-01-01',
  );

  final TextEditingController _postcodeController = TextEditingController(
    text: '123456',
  );

  String _selectedGender = 'male';
  String _selectedTitle = 'mr';

  // Dropdown service
  late DropdownService dropdownService;
  late AuthController authController;
  late LanguageService languageService;
  bool _isInitializing = true;

  String _selectedCountryCode = '';
  String _selectedCountryFlag = '';
  IsoCode? _selectedIsoCode;
  int _maxPhoneDigits = 15;

  @override
  void initState() {
    super.initState();
    // Initialize services
    dropdownService = Get.put(DropdownService());
    authController = Get.find<AuthController>();
    languageService = Get.find<LanguageService>();
    _initializeData();
    ever(dropdownService.selectedCountry, (country) {
      if (country != null && _selectedCountryCode.isEmpty) {
        final countries = CountryService().getAll();
        final matchedCountry = countries.firstWhereOrNull(
          (c) => c.name.toLowerCase() == country.name?.toLowerCase() || c.countryCode.toLowerCase() == country.iso2?.toLowerCase()
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

  Future<void> _initializeData() async {
    try {
      // Fetch profile data
      final profileData = await authController.getProfile();

      if (profileData != null) {
        await _populateFormWithProfileData(profileData);
      }
    } catch (e) {
      print('Error initializing KYC data: $e');
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _populateFormWithProfileData(
    SettingsProfileData profileData,
  ) async {
    final user = profileData.data.user;
    final userDetails = user.userDetails;

    // Populate basic fields
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _emailController.text = user.email;
    _parseAndSetPhoneNumber(user.mobile);
    // Set title, default to 'mr' if empty
    _selectedTitle = userDetails.title.isNotEmpty ? userDetails.title : 'Mr';
    _selectedGender = userDetails.gender.toLowerCase();
    _addressController.text = userDetails.address1;
    _postcodeController.text = userDetails.postcode;

    // Format date of birth as yyyy-MM-dd
    final dateStr = userDetails.dob.toString();
    if (dateStr.contains(' ')) {
      _dobController.text = dateStr.split(' ')[0];
    } else {
      _dobController.text = dateStr;
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
      if (country == null) return;
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
        if (state == null) return;
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _titleController.dispose();
    _dobController.dispose();
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
  }

  // ignore: unused_element
  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: AppColors.whiteColor,
        textStyle: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',          
          prefixIcon: Icon(Icons.search, color: AppColors.textPrimary),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.placeholderSoft,
            ),
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

  void _parseAndSetPhoneNumber(String fullNumber) {
    if (fullNumber.isEmpty) {
      _phoneController.text = '';
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
        (c) => c.phoneCode == phoneCode && (countryIso.isEmpty || c.countryCode.toUpperCase() == countryIso.toUpperCase())
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
      if (selectedCountry != null) {
        final countries = CountryService().getAll();
        final country = countries.firstWhereOrNull(
          (c) => c.name.toLowerCase() == selectedCountry.name?.toLowerCase() || c.countryCode.toLowerCase() == selectedCountry.iso2?.toLowerCase()
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
      }
    }

    _phoneController.text = nationalNumber;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return KycScaffold(
        body: Center(
          child: CommonLoadingWidget(
            message: 'Loading profile data...',
            size: 50.0,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return KycScaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24.h),

              // Section Title
              Text(
                'Personal Details',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.75,
                ),
              ),

              SizedBox(height: 15.h),

              // Form Fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 5.h),

                      _buildTitleDropdown(),

                      _buildFormField(
                        label: languageService.tr('kyc_details_first_name'),
                        controller: _firstNameController,
                      ),

                      _buildFormField(
                        label: languageService.tr('kyc_details_last'),
                        controller: _lastNameController,
                      ),

                      _buildFormField(
                        label: languageService.tr('kyc_details_email'),
                        controller: _emailController,
                      ),

                      _buildDateOfBirthField(),

                      _buildGenderDropdown(),

                      // _buildFormField(label: 'OTP', controller: _otpController),
                      _buildPhoneField(),

                      // Country, State, and City dropdowns
                      _buildCountryDropdown(),
                      _buildStateDropdown(),
                      _buildCityDropdown(),
                      _buildFormField(
                        label: languageService.tr('kyc_details_postcode'),
                        controller: _postcodeController,
                        maxLines: 1,
                      ),

                      _buildFormField(
                        label: languageService.tr(
                          'kyc_details_residence_address',
                        ),
                        controller: _addressController,
                        maxLines: 3,
                      ),

                      SizedBox(height: 50.h),
                    ],
                  ),
                ),
              ),

              // Save Button
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed:
                        authController.isLoading
                            ? null
                            : () {
                              // Dismiss keyboard when save button is tapped
                              FocusScope.of(context).unfocus();
                              _handleSave();
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.whiteColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: authController.isLoading
                        ? ButtonLoadingWidget(size: 20.0, color: AppColors.whiteColor)
                        : Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.whiteColor,
                          ),
                        ),
                  ),
                ),
              ),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: RTLHelper.rtlTextField(
        controller: controller,
        maxLines: maxLines,
        style: AppTextStyles.black16400h1_5,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textGrey),
          floatingLabelStyle: TextStyle(color: AppColors.primary),
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
        ),
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: RTLHelper.rtlTextField(
        controller: _dobController,
        readOnly: true,
        onTap: _selectDate,
        style: AppTextStyles.black16400h1_5,
        decoration: InputDecoration(
          labelText: 'Date of Birth (yyyy-MM-dd)',
          labelStyle: TextStyle(color: AppColors.textGrey),
          floatingLabelStyle: TextStyle(color: AppColors.primary),
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
          suffixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: RTLHelper.rtlIcon(
              Icons.calendar_today,
              color: AppColors.icongrey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
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
                style: TextStyle(
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
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\s\-()]')),
                _PhoneDigitsLimitFormatter(() => _maxPhoneDigits),
              ],
              onChanged: (_) => _formatPhoneInput(),
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: AppColors.textGrey),
                floatingLabelStyle: TextStyle(color: AppColors.primary),
                counterText: '',
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 16.h,
                ),
              ),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  // Country Dropdown
  Widget _buildCountryDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Obx(
        () => RTLHelper.rtlTextField(
          readOnly: true,
          controller: TextEditingController(
            text: dropdownService.selectedCountryText,
          ),
          onTap: () => _showCountryOptions(),
          decoration: InputDecoration(
            labelText: 'Country',
            labelStyle: TextStyle(color: AppColors.textGrey),
            floatingLabelStyle: TextStyle(color: AppColors.primary),
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
            suffixIcon:
            // dropdownService.isLoadingCountries.value
            //     ? Padding(
            //       padding: EdgeInsets.symmetric(horizontal: 14.w),
            //       child: SizedBox(
            //         width: 20.w,
            //         height: 20.h,
            //         child: CircularProgressIndicator(
            //           strokeWidth: 2,
            //           valueColor: AlwaysStoppedAnimation<Color>(
            //             AppColors.primary,
            //           ),
            //         ),
            //       ),
            //     )
            //     :
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: RTLHelper.rtlIcon(
                Icons.keyboard_arrow_down,
                color: AppColors.icongrey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // State Dropdown
  Widget _buildStateDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Obx(
        () =>
            (dropdownService.isLoadingStates.value)
                ? ButtonLoadingWidget(size: 20.0, color: AppColors.primary)
                : RTLHelper.rtlTextField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: dropdownService.selectedStateText,
                  ),
                  onTap:
                      dropdownService.selectedCountry.value != null
                          ? () => _showStateOptions()
                          : null,
                  decoration: InputDecoration(
                    labelText: 'State',
                    labelStyle: TextStyle(color: AppColors.textGrey),
                    floatingLabelStyle: TextStyle(color: AppColors.primary),
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
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.error),
                    ),
                    suffixIcon:
                    // dropdownService.isLoadingStates.value
                    // ? Padding(
                    //   padding: EdgeInsets.symmetric(horizontal: 14.w),
                    //   child: SizedBox(
                    //     width: 20.w,
                    //     height: 20.h,
                    //     child: CircularProgressIndicator(
                    //       strokeWidth: 2,
                    //       valueColor: AlwaysStoppedAnimation<Color>(
                    //         AppColors.primary,
                    //       ),
                    //     ),
                    //   ),
                    // )
                    // :
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      child: RTLHelper.rtlIcon(
                        Icons.keyboard_arrow_down,
                        color:
                            dropdownService.selectedCountry.value != null
                                ? AppColors.icongrey
                                : AppColors.icongrey.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  // Helper method to capitalize first letter
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Title Dropdown
  Widget _buildTitleDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: RTLHelper.rtlTextField(
        readOnly: true,
        controller: TextEditingController(
          text: _capitalizeFirst(_selectedTitle),
        ),
        onTap: () => _showTitleOptions(),
        decoration: InputDecoration(
          labelText: languageService.tr('kyc_details_title'),
          labelStyle: TextStyle(color: AppColors.textGrey),
          floatingLabelStyle: TextStyle(color: AppColors.primary),
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
          suffixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: RTLHelper.rtlIcon(
              Icons.keyboard_arrow_down,
              color: AppColors.icongrey,
            ),
          ),
        ),
      ),
    );
  }

  // Show Title Options
  void _showTitleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Select Title',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 24.h),
                ListView(
                  shrinkWrap: true,
                  children:
                      ['Mr', 'Mrs', 'Ms', "Miss"].map((title) {
                        final isSelected =
                            _capitalizeFirst(_selectedTitle) == title;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTitle = title.toLowerCase();
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 16.h,
                              horizontal: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppColors.primary.withOpacity(0.1)
                                      : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
    );
  }

  // Gender Dropdown
  Widget _buildGenderDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: RTLHelper.rtlTextField(
        readOnly: true,
        controller: TextEditingController(
          text: _capitalizeFirst(_selectedGender),
        ),
        onTap: () => _showGenderOptions(),
        decoration: InputDecoration(
          labelText: 'Gender',
          labelStyle: TextStyle(color: AppColors.textGrey),
          floatingLabelStyle: TextStyle(color: AppColors.primary),
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
          suffixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: RTLHelper.rtlIcon(
              Icons.keyboard_arrow_down,
              color: AppColors.icongrey,
            ),
          ),
        ),
      ),
    );
  }

  // Show Gender Options
  void _showGenderOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Select Gender',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 24.h),
                ListView(
                  shrinkWrap: true,
                  children:
                      ['Male', 'Female', 'Other'].map((gender) {
                        final isSelected =
                            _capitalizeFirst(_selectedGender) == gender;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedGender = gender.toLowerCase();
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 16.h,
                              horizontal: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppColors.primary.withOpacity(0.1)
                                      : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    gender,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
    );
  }

  // City Dropdown
  Widget _buildCityDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Obx(
        () =>
            (dropdownService.isLoadingCities.value)
                ? ButtonLoadingWidget(size: 20.0, color: AppColors.primary)
                : RTLHelper.rtlTextField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: dropdownService.selectedCityText,
                  ),
                  onTap:
                      dropdownService.selectedState.value != null
                          ? () => _showCityOptions()
                          : null,
                  decoration: InputDecoration(
                    labelText: 'City',
                    labelStyle: TextStyle(color: AppColors.textGrey),
                    floatingLabelStyle: TextStyle(color: AppColors.primary),
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
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.error),
                    ),
                    suffixIcon:
                    // dropdownService.isLoadingCities.value
                    //     ? Padding(
                    //       padding: EdgeInsets.symmetric(horizontal: 14.w),
                    //       child: SizedBox(
                    //         width: 20.w,
                    //         height: 20.h,
                    //         child: CircularProgressIndicator(
                    //           strokeWidth: 2,
                    //           valueColor: AlwaysStoppedAnimation<Color>(
                    //             AppColors.primary,
                    //           ),
                    //         ),
                    //       ),
                    //     )
                    //     :
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      child: RTLHelper.rtlIcon(
                        Icons.keyboard_arrow_down,
                        color:
                            dropdownService.selectedState.value != null
                                ? AppColors.icongrey
                                : AppColors.icongrey.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  // Show Country Options with Search
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
                  SizedBox(height: 10.h),
                  Text(
                    'Select Country',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  // Search Field
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      if (value.isEmpty) {
                        filteredCountries.value = List.from(
                          dropdownService.countries,
                        );
                      } else {
                        filteredCountries.value =
                            dropdownService.countries
                                .where(
                                  (country) => (country.name ?? '')
                                      .toLowerCase()
                                      .contains(value.toLowerCase()),
                                )
                                .toList();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search countries...',
                      prefixIcon: Icon(Icons.search, color: AppColors.icongrey),
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
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: Obx(() {
                      if (dropdownService.isLoadingCountries.value) {
                        return Center(
                          child: CommonLoadingWidget(
                            size: 40.0,
                            color: AppColors.primary,
                          ),
                        );
                      }

                      if (filteredCountries.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48.w,
                                color: AppColors.icongrey,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No countries found',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredCountries.length,
                        itemBuilder: (context, index) {
                          final country = filteredCountries[index];
                          final isSelected =
                              dropdownService.selectedCountry.value?.id ==
                              country.id;

                          return InkWell(
                            onTap: () {
                              dropdownService.selectCountry(country);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 16.h,
                                horizontal: 16.w,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.primary.withOpacity(0.1)
                                        : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      country.name!,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        color:
                                            isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Show State Options with Search
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
                  SizedBox(height: 24.h),
                  Text(
                    'Select State',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Search Field
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      if (value.isEmpty) {
                        filteredStates.value = List.from(
                          dropdownService.states,
                        );
                      } else {
                        filteredStates.value =
                            dropdownService.states
                                .where((state) => state.name.contains(value))
                                .toList();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search states...',
                      prefixIcon: Icon(Icons.search, color: AppColors.icongrey),
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
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: Obx(() {
                      if (dropdownService.isLoadingStates.value) {
                        return Center(
                          child: CommonLoadingWidget(
                            size: 40.0,
                            color: AppColors.primary,
                          ),
                        );
                      }

                      if (filteredStates.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48.w,
                                color: AppColors.icongrey,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No states found',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredStates.length,
                        itemBuilder: (context, index) {
                          final state = filteredStates[index];
                          final isSelected =
                              dropdownService.selectedState.value?.id ==
                              state.id;

                          return InkWell(
                            onTap: () {
                              dropdownService.selectState(state);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 16.h,
                                horizontal: 16.w,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.primary.withOpacity(0.1)
                                        : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      state.name,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        color:
                                            isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Show City Options with Search
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
                  SizedBox(height: 24.h),
                  Text(
                    'Select City',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Search Field
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      if (value.isEmpty) {
                        filteredCities.value = List.from(
                          dropdownService.cities,
                        );
                      } else {
                        filteredCities.value =
                            dropdownService.cities
                                .where((city) => city.name.contains(value))
                                .toList();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search cities...',
                      prefixIcon: Icon(Icons.search, color: AppColors.icongrey),
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
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: Obx(() {
                      if (dropdownService.isLoadingCities.value) {
                        return Center(
                          child: CommonLoadingWidget(
                            size: 40.0,
                            color: AppColors.primary,
                          ),
                        );
                      }

                      if (filteredCities.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48.w,
                                color: AppColors.icongrey,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No cities found',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredCities.length,
                        itemBuilder: (context, index) {
                          final city = filteredCities[index];
                          final isSelected =
                              dropdownService.selectedCity.value?.id == city.id;

                          return InkWell(
                            onTap: () {
                              dropdownService.selectCity(city);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 16.h,
                                horizontal: 16.w,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.primary.withOpacity(0.1)
                                        : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      city.name,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        color:
                                            isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _dobController.text.isNotEmpty
              ? DateTime.tryParse(_dobController.text) ?? DateTime.now()
              : DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.whiteColor,
              surface: AppColors.whiteColor,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // ignore: unused_element
  void _showOtpModal() {
    Get.bottomSheet(
      OtpModal(
        phoneNumber: _phoneController.text,
        onVerify: () {
          // Handle OTP verification
          Get.back(closeOverlays: true); // Close OTP modal
          if (Get.isRegistered<AppNotificationController>()) {
            Get.find<AppNotificationController>().showSuccess(
              message: 'Phone number verified successfully!',
              title: 'Success',
            );
          }
        },
      ),
      isScrollControlled: true,
    );
  }

  void _handleSave() {
    // Validate form fields
    if (_firstNameController.text.trim().isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Please enter your first name',
          title: 'Error',
        );
      }
      return;
    }

    if (_lastNameController.text.trim().isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Please enter your last name',
          title: 'Error',
        );
      }
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Please enter your email',
          title: 'Error',
        );
      }
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Please enter your phone number',
          title: 'Error',
        );
      }
      return;
    }

    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final combinedPhone = '$_selectedCountryCode$digits';

    if (!dropdownService.isComplete) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Please select country, state, and city',
          title: 'Error',
        );
      }
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Please enter your address',
          title: 'Error',
        );
      }
      return;
    }

    // if (_otpController.text.trim().isEmpty) {
    //   Get.snackbar(
    //     'Error',
    //     'Please enter OTP',
    //     backgroundColor: AppColors.error,
    //     colorText: AppColors.whiteColor,
    //   );
    //   return;
    // }

    if (_selectedTitle.trim().isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Please select title',
          title: 'Error',
        );
      }
      return;
    }

    if (_dobController.text.trim().isEmpty) {
      if (Get.isRegistered<AppNotificationController>()) {
        Get.find<AppNotificationController>().showError(
          message: 'Please enter date of birth',
          title: 'Error',
        );
      }
      return;
    }

    // Call profile update API
    authController.updateProfile(
      title: _selectedTitle,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: combinedPhone,
      dob: _dobController.text.trim(),
      gender: _selectedGender,
      state: dropdownService.selectedState.value?.id ?? 0,
      city: dropdownService.selectedCity.value?.id ?? 0,
      address: _addressController.text.trim(),
      postcode: _postcodeController.text.trim(),
      nationality: dropdownService.selectedCountry.value?.nationality ?? '',
      cityName: dropdownService.selectedCity.value?.name ?? '',
      // otp: _otpController.text.trim(),
      countryId: dropdownService.selectedCountry.value?.id ?? 0,
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
