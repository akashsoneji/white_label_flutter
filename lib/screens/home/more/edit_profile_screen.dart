import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    isProfileVerified = Get.arguments ?? false;
    dropdownService = Get.find<DropdownService>();
    _addListeners();
    _bindControllerData();
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
      controller.updatePhone(_phoneController.text);
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
    ever(controller.firstName, (value) {
      if (_firstNameController.text != value) {
        _firstNameController.text = value;
      }
    });
    ever(controller.lastName, (value) {
      if (_lastNameController.text != value) {
        _lastNameController.text = value;
      }
    });
    ever(controller.email, (value) {
      if (_emailController.text != value) {
        _emailController.text = value;
      }
    });
    ever(controller.phone, (value) {
      if (_phoneController.text != value) {
        _phoneController.text = value;
      }
    });
    ever(controller.address, (value) {
      if (_addressController.text != value) {
        _addressController.text = value;
      }
    });
    ever(controller.postcode, (value) {
      if (_postcodeController.text != value) {
        _postcodeController.text = value;
      }
    });
    ever(controller.title, (value) {
      if (_titleController.text != value) {
        _titleController.text = value;
      }
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // 18 years ago
      firstDate: DateTime.now().subtract(
        const Duration(days: 36500),
      ), // 100 years ago
      lastDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // 18 years ago
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
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
                    'Select Country',
                    style: TextStyle(
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
                    decoration: InputDecoration(
                      hintText: 'Search countries...',
                      prefixIcon: Icon(Icons.search),
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
                              style: TextStyle(fontSize: 24),
                            ),
                            title: Text(country.name ?? ''),
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
                    'Select State',
                    style: TextStyle(
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
                    decoration: InputDecoration(
                      hintText: 'Search states...',
                      prefixIcon: Icon(Icons.search),
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
                            title: Text(state.name),
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
                    'Select City',
                    style: TextStyle(
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
                    decoration: InputDecoration(
                      hintText: 'Search cities...',
                      prefixIcon: Icon(Icons.search),
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
                            title: Text(city.name),
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
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(items[index]),
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
                      message: 'Loading profile data...',
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
                          labelStyle: TextStyle(color: AppColors.textGrey),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_enter_first_name',
                          ),
                          hintStyle: TextStyle(color: AppColors.textGrey),
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
                            labelStyle: TextStyle(color: AppColors.textGrey),
                            floatingLabelStyle: TextStyle(
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
                          labelStyle: TextStyle(color: AppColors.textGrey),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_enter_last_name',
                          ),
                          hintStyle: TextStyle(color: AppColors.textGrey),
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
                          labelStyle: TextStyle(color: AppColors.textGrey),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_enter_email',
                          ),
                          hintStyle: TextStyle(color: AppColors.textGrey),
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
                      RTLHelper.rtlTextField(
                        controller: _phoneController,
                        readOnly: isProfileVerified,
                        labelText: languageService.tr(
                          'edit_profile_mobile_number',
                        ),
                        hintText: languageService.tr(
                          'edit_profile_please_enter_mobile_number',
                        ),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: languageService.tr(
                            'edit_profile_mobile_number',
                          ),
                          labelStyle: TextStyle(color: AppColors.textGrey),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_enter_mobile_number',
                          ),
                          hintStyle: TextStyle(color: AppColors.textGrey),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return languageService.tr(
                              'edit_profile_please_enter_mobile_number',
                            );
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
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
                              padding: const EdgeInsets.symmetric(
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
                            labelStyle: TextStyle(color: AppColors.textGrey),
                            floatingLabelStyle: TextStyle(
                              color: AppColors.primary,
                            ),
                            hintText: languageService.tr(
                              'edit_profile_please_select_dob',
                            ),
                            hintStyle: TextStyle(color: AppColors.textGrey),
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
                            labelStyle: TextStyle(color: AppColors.textGrey),
                            floatingLabelStyle: TextStyle(
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
                          labelStyle: TextStyle(color: AppColors.textGrey),
                          floatingLabelStyle: TextStyle(
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
                          labelStyle: TextStyle(color: AppColors.textGrey),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.primary,
                          ),
                          hintText: languageService.tr(
                            'edit_profile_please_enter_postcode',
                          ),
                          hintStyle: TextStyle(color: AppColors.textGrey),
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
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 10,
                  left: 16.w,
                  right: 16.w,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: Obx(
                    () => RTLHelper.rtlButton(
                      text:
                          controller.isSaving.value
                              ? 'Saving...'
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
      child: Obx(
        () => RTLHelper.rtlTextField(
          readOnly: true,
          controller: TextEditingController(
            text: dropdownService.selectedCountryText,
          ),
          onTap: isProfileVerified ? null : () => _showCountryOptions(),
          decoration: InputDecoration(
            labelText: languageService.tr('register_country'),
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
    );
  }

  Widget _buildStateDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Obx(
        () => RTLHelper.rtlTextField(
          readOnly: true,
          controller: TextEditingController(
            text: dropdownService.selectedStateText,
          ),
          onTap:
              isProfileVerified
                  ? null
                  : (dropdownService.selectedCountry.value != null
                      ? () => _showStateOptions()
                      : null),
          decoration: InputDecoration(
            labelText: languageService.tr('edit_profile_state'),
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
            suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.icongrey),
          ),
        ),
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Obx(
        () => RTLHelper.rtlTextField(
          readOnly: true,
          controller: TextEditingController(
            text: dropdownService.selectedCityText,
          ),
          onTap:
              isProfileVerified
                  ? null
                  : (dropdownService.selectedState.value != null
                      ? () => _showCityOptions()
                      : null),
          decoration: InputDecoration(
            labelText: languageService.tr('edit_profile_city'),
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
            suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.icongrey),
          ),
        ),
      ),
    );
  }
}
