import 'package:get/get.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/screens/auth/view_models/auth_controller.dart';
import 'package:crm_app/screens/profile/data/repositories/profile_repository.dart';
// To parse this JSON data, do
//
//     final dashboardModel = dashboardModelFromJson(jsonString);

import 'dart:convert';

DashboardModel dashboardModelFromJson(String str) =>
    DashboardModel.fromJson(json.decode(str));

String dashboardModelToJson(DashboardModel data) => json.encode(data.toJson());

class DashboardModel {
  bool? status;
  String? message;
  Data? data;

  DashboardModel({this.status, this.message, this.data});

  DashboardModel copyWith({bool? status, String? message, Data? data}) =>
      DashboardModel(
        status: status ?? this.status,
        message: message ?? this.message,
        data: data ?? this.data,
      );

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    print('DashboardModel.fromJson - Raw JSON: $json');
    print('DashboardModel.fromJson - data field: ${json["data"]}');

    final model = DashboardModel(
      status: json["status"],
      message: json["message"],
      data: json["data"] == null ? null : Data.fromJson(json["data"]),
    );

    print('DashboardModel.fromJson - Parsed data: ${model.data}');
    print(
      'DashboardModel.fromJson - Parsed profileCompletionPercentage: ${model.data?.profileCompletionPercentage}',
    );
    return model;
  }

  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "data": data?.toJson(),
  };
}

class Data {
  User? user;
  int? profileCompletionPercentage;
  StageCompletion? stageCompletion;

  Data({this.user, this.profileCompletionPercentage, this.stageCompletion});

  Data copyWith({
    User? user,
    int? profileCompletionPercentage,
    StageCompletion? stageCompletion,
  }) => Data(
    user: user ?? this.user,
    profileCompletionPercentage:
        profileCompletionPercentage ?? this.profileCompletionPercentage,
    stageCompletion: stageCompletion ?? this.stageCompletion,
  );

  factory Data.fromJson(Map<String, dynamic> json) {
    print('Data.fromJson - Raw JSON: $json');
    print(
      'Data.fromJson - profile_completion_percentage: ${json["profile_completion_percentage"]}',
    );
    print(
      'Data.fromJson - Type of profile_completion_percentage: ${json["profile_completion_percentage"].runtimeType}',
    );

    final data = Data(
      user: json["user"] == null ? null : User.fromJson(json["user"]),
      profileCompletionPercentage:
          json["profile_completion_percentage"] is int
              ? json["profile_completion_percentage"] as int
              : int.tryParse(
                    json["profile_completion_percentage"].toString(),
                  ) ??
                  0,
      stageCompletion:
          json["stage_completion"] == null
              ? null
              : StageCompletion.fromJson(json["stage_completion"]),
    );

    print(
      'Data.fromJson - Parsed profileCompletionPercentage: ${data.profileCompletionPercentage}',
    );
    return data;
  }

  Map<String, dynamic> toJson() => {
    "user": user?.toJson(),
    "profile_completion_percentage": profileCompletionPercentage,
    "stage_completion": stageCompletion?.toJson(),
  };
}

class StageCompletion {
  bool? mobileVerified;
  bool? emailVerified;
  bool? personalDetails;
  bool? identityVerified;
  bool? addressProofVerified;

  StageCompletion({
    this.mobileVerified,
    this.emailVerified,
    this.personalDetails,
    this.identityVerified,
    this.addressProofVerified,
  });

  StageCompletion copyWith({
    bool? mobileVerified,
    bool? emailVerified,
    bool? personalDetails,
    bool? identityVerified,
    bool? addressProofVerified,
  }) => StageCompletion(
    mobileVerified: mobileVerified ?? this.mobileVerified,
    emailVerified: emailVerified ?? this.emailVerified,
    personalDetails: personalDetails ?? this.personalDetails,
    identityVerified: identityVerified ?? this.identityVerified,
    addressProofVerified: addressProofVerified ?? this.addressProofVerified,
  );

  factory StageCompletion.fromJson(Map<String, dynamic> json) {
    print('StageCompletion.fromJson - Raw JSON: $json');
    print(
      'StageCompletion.fromJson - mobile_verified: ${json["mobile_verified"]}',
    );
    print(
      'StageCompletion.fromJson - email_verified: ${json["email_verified"]}',
    );
    print(
      'StageCompletion.fromJson - personal_details: ${json["personal_details"]}',
    );
    print(
      'StageCompletion.fromJson - identity_verified: ${json["identity_verified"]}',
    );
    print(
      'StageCompletion.fromJson - address_proof_verified: ${json["address_proof_verified"]}',
    );

    return StageCompletion(
      mobileVerified: _parseBool(json["mobile_verified"]),
      emailVerified: _parseBool(json["email_verified"]),
      personalDetails: _parseBool(json["personal_details"]),
      identityVerified: _parseBool(json["identity_verified"]),
      addressProofVerified: _parseBool(json["address_proof_verified"]),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null || value == '' || value == 'null') return null;

    try {
      // Handle different DateTime formats
      String dateString = value.toString();

      // If it's already in ISO format, parse directly
      if (dateString.contains('T') && dateString.contains('Z')) {
        return DateTime.parse(dateString);
      }

      // If it's in custom format like "2025-09-10 16:34:49", convert to ISO
      if (dateString.contains(' ') && !dateString.contains('T')) {
        // Replace space with T and add Z for ISO format
        String isoString = dateString.replaceFirst(' ', 'T') + 'Z';
        return DateTime.parse(isoString);
      }

      // Try parsing as is
      return DateTime.parse(dateString);
    } catch (e) {
      print('Error parsing DateTime: $value, Error: $e');
      return null;
    }
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    if (value is int) {
      return value == 1;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    "mobile_verified": mobileVerified,
    "email_verified": emailVerified,
    "personal_details": personalDetails,
    "identity_verified": identityVerified,
    "address_proof_verified": addressProofVerified,
  };
}

class User {
  int? id;
  String? email;
  DateTime? emailVerifiedAt;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? userSlug;
  String? firstName;
  String? lastName;
  String? mobile;
  DateTime? mobileVerifiedAt;
  String? status;
  int? regComplete;
  String? deletedAt;
  Userdetails? userDetails;
  Userdetails? userdetails;

  User({
    this.id,
    this.email,
    this.emailVerifiedAt,
    this.createdAt,
    this.updatedAt,
    this.userSlug,
    this.firstName,
    this.lastName,
    this.mobile,
    this.mobileVerifiedAt,
    this.status,
    this.regComplete,
    this.deletedAt,
    this.userDetails,
    this.userdetails,
  });

  User copyWith({
    int? id,
    String? email,
    DateTime? emailVerifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userSlug,
    String? firstName,
    String? lastName,
    String? mobile,
    DateTime? mobileVerifiedAt,
    String? status,
    int? regComplete,
    String? deletedAt,
    Userdetails? userDetails,
    Userdetails? userdetails,
  }) => User(
    id: id ?? this.id,
    email: email ?? this.email,
    emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    userSlug: userSlug ?? this.userSlug,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    mobile: mobile ?? this.mobile,
    mobileVerifiedAt: mobileVerifiedAt ?? this.mobileVerifiedAt,
    status: status ?? this.status,
    regComplete: regComplete ?? this.regComplete,
    deletedAt: deletedAt ?? this.deletedAt,
    userDetails: userDetails ?? this.userDetails,
    userdetails: userdetails ?? this.userdetails,
  );

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"],
    email: json["email"],
    emailVerifiedAt: _parseDateTime(json["email_verified_at"]),
    createdAt: _parseDateTime(json["created_at"]),
    updatedAt: _parseDateTime(json["updated_at"]),
    userSlug: json["user_slug"],
    firstName: json["first_name"],
    lastName: json["last_name"],
    mobile: json["mobile"],
    mobileVerifiedAt: _parseDateTime(json["mobile_verified_at"]),
    status: json["status"],
    regComplete: json["reg_complete"],
    deletedAt: json["deleted_at"],
    userDetails:
        json["user_details"] == null
            ? null
            : Userdetails.fromJson(json["user_details"]),
    userdetails:
        json["userdetails"] == null
            ? null
            : Userdetails.fromJson(json["userdetails"]),
  );

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null || value == '' || value == 'null') return null;

    try {
      // Handle different DateTime formats
      String dateString = value.toString();

      // If it's already in ISO format, parse directly
      if (dateString.contains('T') && dateString.contains('Z')) {
        return DateTime.parse(dateString);
      }

      // If it's in custom format like "2025-09-10 16:34:49", convert to ISO
      if (dateString.contains(' ') && !dateString.contains('T')) {
        // Replace space with T and add Z for ISO format
        String isoString = dateString.replaceFirst(' ', 'T') + 'Z';
        return DateTime.parse(isoString);
      }

      // Try parsing as is
      return DateTime.parse(dateString);
    } catch (e) {
      print('Error parsing DateTime: $value, Error: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "email": email,
    "email_verified_at": emailVerifiedAt?.toIso8601String(),
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "user_slug": userSlug,
    "first_name": firstName,
    "last_name": lastName,
    "mobile": mobile,
    "mobile_verified_at": mobileVerifiedAt?.toIso8601String(),
    "status": status,
    "reg_complete": regComplete,
    "deleted_at": deletedAt,
    "user_details": userDetails?.toJson(),
    "userdetails": userdetails?.toJson(),
  };
}

class Userdetails {
  int? id;
  int? userId;
  String? title;
  String? gender;
  String? dob;
  String? altMobile;
  String? altEmail;
  String? registerSource;
  String? lastLoginAt;
  String? kycStatus;
  String? kycType;
  String? kycVerifiedBy;
  int? byPassKyc;
  String? kycVerifiedAt;
  String? ibAffiliateRefcode;
  String? isIbAffiliate;
  String? ibAffiliateDateAt;
  int? managerId;
  DateTime? managerAssignedAt;
  String? branchId;
  String? branchCode;
  String? branchAssignedAt;
  String? ibId;
  String? affiliateId;
  String? campaignId;
  String? depositStatus;
  String? withdrawalStatus;
  String? transferStatus;
  String? bonusStatus;
  String? notes;
  String? nationality;
  String? country;
  String? state;
  String? city;
  String? address1;
  String? address2;
  String? postcode;
  String? language;
  String? isUsCitizen;
  String? isPoliticallyExposed;
  String? industry;
  String? taxIdentificationNumber;
  String? mt5AccountLimit;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? deletedAt;
  String? personalInfoVerifiedBy;
  String? personalInfoVerifiedAt;
  String? identityVerifiedBy;
  String? identityVerifiedAt;
  String? addressVerifiedBy;
  String? addressVerifiedAt;
  String? kycVerificationLevel;
  String? kycVerificationNotes;
  String? branch;
  String? countryName;
  String? stateName;
  String? cityName;

  Userdetails({
    this.id,
    this.userId,
    this.title,
    this.gender,
    this.dob,
    this.altMobile,
    this.altEmail,
    this.registerSource,
    this.lastLoginAt,
    this.kycStatus,
    this.kycType,
    this.kycVerifiedBy,
    this.byPassKyc,
    this.kycVerifiedAt,
    this.ibAffiliateRefcode,
    this.isIbAffiliate,
    this.ibAffiliateDateAt,
    this.managerId,
    this.managerAssignedAt,
    this.branchId,
    this.branchCode,
    this.branchAssignedAt,
    this.ibId,
    this.affiliateId,
    this.campaignId,
    this.depositStatus,
    this.withdrawalStatus,
    this.transferStatus,
    this.bonusStatus,
    this.notes,
    this.nationality,
    this.country,
    this.state,
    this.city,
    this.address1,
    this.address2,
    this.postcode,
    this.language,
    this.isUsCitizen,
    this.isPoliticallyExposed,
    this.industry,
    this.taxIdentificationNumber,
    this.mt5AccountLimit,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.personalInfoVerifiedBy,
    this.personalInfoVerifiedAt,
    this.identityVerifiedBy,
    this.identityVerifiedAt,
    this.addressVerifiedBy,
    this.addressVerifiedAt,
    this.kycVerificationLevel,
    this.kycVerificationNotes,
    this.branch,
    this.countryName,
    this.stateName,
    this.cityName,
  });

  Userdetails copyWith({
    int? id,
    int? userId,
    String? title,
    String? gender,
    String? dob,
    String? altMobile,
    String? altEmail,
    String? registerSource,
    String? lastLoginAt,
    String? kycStatus,
    String? kycType,
    String? kycVerifiedBy,
    int? byPassKyc,
    String? kycVerifiedAt,
    String? ibAffiliateRefcode,
    String? isIbAffiliate,
    String? ibAffiliateDateAt,
    int? managerId,
    DateTime? managerAssignedAt,
    String? branchId,
    String? branchCode,
    String? branchAssignedAt,
    String? ibId,
    String? affiliateId,
    String? campaignId,
    String? depositStatus,
    String? withdrawalStatus,
    String? transferStatus,
    String? bonusStatus,
    String? notes,
    String? nationality,
    String? country,
    String? state,
    String? city,
    String? address1,
    String? address2,
    String? postcode,
    String? language,
    String? isUsCitizen,
    String? isPoliticallyExposed,
    String? industry,
    String? taxIdentificationNumber,
    String? mt5AccountLimit,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deletedAt,
    String? personalInfoVerifiedBy,
    String? personalInfoVerifiedAt,
    String? identityVerifiedBy,
    String? identityVerifiedAt,
    String? addressVerifiedBy,
    String? addressVerifiedAt,
    String? kycVerificationLevel,
    String? kycVerificationNotes,
    String? branch,
    String? countryName,
    String? stateName,
    String? cityName,
  }) => Userdetails(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    gender: gender ?? this.gender,
    dob: dob ?? this.dob,
    altMobile: altMobile ?? this.altMobile,
    altEmail: altEmail ?? this.altEmail,
    registerSource: registerSource ?? this.registerSource,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    kycStatus: kycStatus ?? this.kycStatus,
    kycType: kycType ?? this.kycType,
    kycVerifiedBy: kycVerifiedBy ?? this.kycVerifiedBy,
    byPassKyc: byPassKyc ?? this.byPassKyc,
    kycVerifiedAt: kycVerifiedAt ?? this.kycVerifiedAt,
    ibAffiliateRefcode: ibAffiliateRefcode ?? this.ibAffiliateRefcode,
    isIbAffiliate: isIbAffiliate ?? this.isIbAffiliate,
    ibAffiliateDateAt: ibAffiliateDateAt ?? this.ibAffiliateDateAt,
    managerId: managerId ?? this.managerId,
    managerAssignedAt: managerAssignedAt ?? this.managerAssignedAt,
    branchId: branchId ?? this.branchId,
    branchCode: branchCode ?? this.branchCode,
    branchAssignedAt: branchAssignedAt ?? this.branchAssignedAt,
    ibId: ibId ?? this.ibId,
    affiliateId: affiliateId ?? this.affiliateId,
    campaignId: campaignId ?? this.campaignId,
    depositStatus: depositStatus ?? this.depositStatus,
    withdrawalStatus: withdrawalStatus ?? this.withdrawalStatus,
    transferStatus: transferStatus ?? this.transferStatus,
    bonusStatus: bonusStatus ?? this.bonusStatus,
    notes: notes ?? this.notes,
    nationality: nationality ?? this.nationality,
    country: country ?? this.country,
    state: state ?? this.state,
    city: city ?? this.city,
    address1: address1 ?? this.address1,
    address2: address2 ?? this.address2,
    postcode: postcode ?? this.postcode,
    language: language ?? this.language,
    isUsCitizen: isUsCitizen ?? this.isUsCitizen,
    isPoliticallyExposed: isPoliticallyExposed ?? this.isPoliticallyExposed,
    industry: industry ?? this.industry,
    taxIdentificationNumber:
        taxIdentificationNumber ?? this.taxIdentificationNumber,
    mt5AccountLimit: mt5AccountLimit ?? this.mt5AccountLimit,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    personalInfoVerifiedBy:
        personalInfoVerifiedBy ?? this.personalInfoVerifiedBy,
    personalInfoVerifiedAt:
        personalInfoVerifiedAt ?? this.personalInfoVerifiedAt,
    identityVerifiedBy: identityVerifiedBy ?? this.identityVerifiedBy,
    identityVerifiedAt: identityVerifiedAt ?? this.identityVerifiedAt,
    addressVerifiedBy: addressVerifiedBy ?? this.addressVerifiedBy,
    addressVerifiedAt: addressVerifiedAt ?? this.addressVerifiedAt,
    kycVerificationLevel: kycVerificationLevel ?? this.kycVerificationLevel,
    kycVerificationNotes: kycVerificationNotes ?? this.kycVerificationNotes,
    branch: branch ?? this.branch,
    countryName: countryName ?? this.countryName,
    stateName: stateName ?? this.stateName,
    cityName: cityName ?? this.cityName,
  );

  factory Userdetails.fromJson(Map<String, dynamic> json) => Userdetails(
    id:
        json["id"] is String && json["id"].isEmpty
            ? null
            : int.tryParse(json["id"].toString()),
    userId:
        json["user_id"] is String && json["user_id"].isEmpty
            ? null
            : int.tryParse(json["user_id"].toString()),
    title: json["title"],
    gender: json["gender"],
    dob: json["dob"],
    altMobile: json["alt_mobile"],
    altEmail: json["alt_email"],
    registerSource: json["register_source"],
    lastLoginAt: json["last_login_at"],
    kycStatus: json["kyc_status"],
    kycType: json["kyc_type"],
    kycVerifiedBy: json["kyc_verified_by"],
    byPassKyc:
        json["by_pass_kyc"] is String && json["by_pass_kyc"].isEmpty
            ? null
            : int.tryParse(json["by_pass_kyc"].toString()),
    kycVerifiedAt: json["kyc_verified_at"],
    ibAffiliateRefcode: json["ib_affiliate_refcode"],
    isIbAffiliate: json["is_ib_affiliate"],
    ibAffiliateDateAt: json["ib_affiliate_date_at"],
    managerId:
        json["manager_id"] is String && json["manager_id"].isEmpty
            ? null
            : int.tryParse(json["manager_id"].toString()),
    managerAssignedAt: _parseDateTime(json["manager_assigned_at"]),
    branchId: json["branch_id"],
    branchCode: json["branch_code"],
    branchAssignedAt: json["branch_assigned_at"],
    ibId: json["ib_id"],
    affiliateId: json["affiliate_id"],
    campaignId: json["campaign_id"],
    depositStatus: json["deposit_status"],
    withdrawalStatus: json["withdrawal_status"],
    transferStatus: json["transfer_status"],
    bonusStatus: json["bonus_status"],
    notes: json["notes"],
    nationality: json["nationality"],
    country: json["country"]?.toString(),
    state: json["state"]?.toString(),
    city: json["city"]?.toString(),
    address1: json["address_1"],
    address2: json["address_2"],
    postcode: json["postcode"],
    language: json["language"],
    isUsCitizen: json["is_us_citizen"],
    isPoliticallyExposed: json["is_politically_exposed"],
    industry: json["industry"],
    taxIdentificationNumber: json["tax_identification_number"],
    mt5AccountLimit: json["mt5_account_limit"],
    createdAt: _parseDateTime(json["created_at"]),
    updatedAt: _parseDateTime(json["updated_at"]),
    deletedAt: json["deleted_at"],
    personalInfoVerifiedBy: json["personal_info_verified_by"],
    personalInfoVerifiedAt: json["personal_info_verified_at"],
    identityVerifiedBy: json["identity_verified_by"],
    identityVerifiedAt: json["identity_verified_at"],
    addressVerifiedBy: json["address_verified_by"],
    addressVerifiedAt: json["address_verified_at"],
    kycVerificationLevel: json["kyc_verification_level"],
    kycVerificationNotes: json["kyc_verification_notes"],
    branch: json["branch"],
    countryName: json["country_name"],
    stateName: json["state_name"],
    cityName: json["city_name"],
  );

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null || value == '' || value == 'null') return null;

    try {
      // Handle different DateTime formats
      String dateString = value.toString();

      // If it's already in ISO format, parse directly
      if (dateString.contains('T') && dateString.contains('Z')) {
        return DateTime.parse(dateString);
      }

      // If it's in custom format like "2025-09-10 16:34:49", convert to ISO
      if (dateString.contains(' ') && !dateString.contains('T')) {
        // Replace space with T and add Z for ISO format
        String isoString = dateString.replaceFirst(' ', 'T') + 'Z';
        return DateTime.parse(isoString);
      }

      // Try parsing as is
      return DateTime.parse(dateString);
    } catch (e) {
      print('Error parsing DateTime: $value, Error: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "title": title,
    "gender": gender,
    "dob": dob,
    "alt_mobile": altMobile,
    "alt_email": altEmail,
    "register_source": registerSource,
    "last_login_at": lastLoginAt,
    "kyc_status": kycStatus,
    "kyc_type": kycType,
    "kyc_verified_by": kycVerifiedBy,
    "by_pass_kyc": byPassKyc,
    "kyc_verified_at": kycVerifiedAt,
    "ib_affiliate_refcode": ibAffiliateRefcode,
    "is_ib_affiliate": isIbAffiliate,
    "ib_affiliate_date_at": ibAffiliateDateAt,
    "manager_id": managerId,
    "manager_assigned_at": managerAssignedAt?.toIso8601String(),
    "branch_id": branchId,
    "branch_code": branchCode,
    "branch_assigned_at": branchAssignedAt,
    "ib_id": ibId,
    "affiliate_id": affiliateId,
    "campaign_id": campaignId,
    "deposit_status": depositStatus,
    "withdrawal_status": withdrawalStatus,
    "transfer_status": transferStatus,
    "bonus_status": bonusStatus,
    "notes": notes,
    "nationality": nationality,
    "country": country,
    "state": state,
    "city": city,
    "address_1": address1,
    "address_2": address2,
    "postcode": postcode,
    "language": language,
    "is_us_citizen": isUsCitizen,
    "is_politically_exposed": isPoliticallyExposed,
    "industry": industry,
    "tax_identification_number": taxIdentificationNumber,
    "mt5_account_limit": mt5AccountLimit,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "personal_info_verified_by": personalInfoVerifiedBy,
    "personal_info_verified_at": personalInfoVerifiedAt,
    "identity_verified_by": identityVerifiedBy,
    "identity_verified_at": identityVerifiedAt,
    "address_verified_by": addressVerifiedBy,
    "address_verified_at": addressVerifiedAt,
    "kyc_verification_level": kycVerificationLevel,
    "kyc_verification_notes": kycVerificationNotes,
    "branch": branch,
    "country_name": countryName,
    "state_name": stateName,
    "city_name": cityName,
  };
}

class MoreController extends GetxController {
  final ProfileRepository _repo = Get.find<ProfileRepository>();
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  var dashboardModel = Rxn<DashboardModel>();

  // Store whole model

  @override
  void onInit() {
    super.onInit();

    // Check if user is authenticated before making API calls
    try {
      final authController = Get.find<AuthController>();
      if (authController.isAuthenticated) {
        loadMoreScreenData();
      } else {
        print(
          'MoreController: User not authenticated, skipping loadMoreScreenData',
        );
      }
    } catch (e) {
      print('MoreController: Error checking auth status: $e');
    }
  }

  Future<void> loadMoreScreenData() async {
    final token = await SecureStorageService.getAuthToken();
    dashboardModel.value = null;
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await _repo.getDashboard(token: token ?? '');

      if (response.success) {
        print(
          "object is to me chek parsetage valuenin flutter ${response.data['data']['profile_completion_percentage']}",
        );
        dashboardModel.value = DashboardModel.fromJson(response.data);
        print(
          "object is to me chek parsetage valuenin flutter  122 ${dashboardModel.value?.data?.profileCompletionPercentage}",
        );
        update();
      } else {
        errorMessage.value = response.message ?? 'Failed to load data';
        print(
          'API Error loadMoreScreenData : ${response.message} - ${response.data}',
        );
      }
    } catch (e, t) {
      errorMessage.value = 'Error loading more screen data: $e';
      print('Exception in loadMoreScreenData: $e');
      print('Exception in loadMoreScreenData: $t');
    } finally {
      isLoading.value = false;
    }
  }
}
