class SettingsProfileData {
  final bool status;
  final String message;
  final ProfileData data;

  SettingsProfileData({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SettingsProfileData.fromJson(Map<String, dynamic> json) {
    return SettingsProfileData(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data:
          json['data'] is Map<String, dynamic>
              ? ProfileData.fromJson(json['data'] as Map<String, dynamic>)
              : ProfileData(user: User.empty()),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'message': message, 'data': data.toJson()};
  }

  SettingsProfileData copyWith({
    bool? status,
    String? message,
    ProfileData? data,
  }) => SettingsProfileData(
    status: status ?? this.status,
    message: message ?? this.message,
    data: data ?? this.data,
  );
}

class ProfileData {
  final User user;

  ProfileData({required this.user});

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      user:
          json['user'] is Map<String, dynamic>
              ? User.fromJson(json['user'] as Map<String, dynamic>)
              : User.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'user': user.toJson()};
  }

  ProfileData copyWith({User? user}) => ProfileData(user: user ?? this.user);
}

class User {
  final int id;
  final String email;
  final DateTime emailVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userSlug;
  final String firstName;
  final String lastName;
  final String mobile;
  final String mobileVerifiedAt;
  final String status;
  final int regComplete;
  final String deletedAt;
  final int forceRegulatedForm;
  final int regulationSubmitted;
  final int regulationRequired;
  final int regulatedBrokerEnabled;
  final UserDetails userDetails;

  String get fullName => '$firstName $lastName'.trim();

  User({
    required this.id,
    required this.email,
    required this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.userSlug,
    required this.firstName,
    required this.lastName,
    required this.mobile,
    required this.mobileVerifiedAt,
    required this.status,
    required this.regComplete,
    required this.deletedAt,
    required this.forceRegulatedForm,
    required this.regulationSubmitted,
    required this.regulationRequired,
    required this.regulatedBrokerEnabled,
    required this.userDetails,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      email: json['email'] ?? '',
      emailVerifiedAt: _parseDateTime(json['email_verified_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      userSlug: json['user_slug'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      mobile: json['mobile'] ?? '',
      mobileVerifiedAt: json['mobile_verified_at'] ?? '',
      status: json['status'] ?? '',
      regComplete:
          json['reg_complete'] is int
              ? json['reg_complete']
              : int.tryParse(json['reg_complete'].toString()) ?? 0,
      deletedAt: json['deleted_at'] ?? '',
      forceRegulatedForm:
          json['force_regulated_form'] is int
              ? json['force_regulated_form']
              : int.tryParse(json['force_regulated_form'].toString()) ?? 0,
      regulationSubmitted:
          json['regulation_submitted'] is int
              ? json['regulation_submitted']
              : int.tryParse(json['regulation_submitted'].toString()) ?? 0,
      regulationRequired:
          json['regulation_required'] is int
              ? json['regulation_required']
              : int.tryParse(json['regulation_required'].toString()) ?? 0,
      regulatedBrokerEnabled:
          json['regulated_broker_enabled'] is int
              ? json['regulated_broker_enabled']
              : int.tryParse(json['regulated_broker_enabled'].toString()) ?? 0,
      userDetails:
          json['user_details'] is Map<String, dynamic>
              ? UserDetails.fromJson(
                json['user_details'] as Map<String, dynamic>,
              )
              : UserDetails.empty(),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null || value == '' || value == 'null') return DateTime.now();

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
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'email_verified_at': emailVerifiedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_slug': userSlug,
      'first_name': firstName,
      'last_name': lastName,
      'mobile': mobile,
      'mobile_verified_at': mobileVerifiedAt,
      'status': status,
      'reg_complete': regComplete,
      'deleted_at': deletedAt,
      'force_regulated_form': forceRegulatedForm,
      'regulation_submitted': regulationSubmitted,
      'regulation_required': regulationRequired,
      'regulated_broker_enabled': regulatedBrokerEnabled,
      'user_details': userDetails.toJson(),
    };
  }

  static User empty() {
    return User(
      id: 0,
      email: '',
      emailVerifiedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      userSlug: '',
      firstName: '',
      lastName: '',
      mobile: '',
      mobileVerifiedAt: '',
      status: '',
      regComplete: 0,
      deletedAt: '',
      forceRegulatedForm: 0,
      regulationSubmitted: 0,
      regulationRequired: 0,
      regulatedBrokerEnabled: 0,
      userDetails: UserDetails.empty(),
    );
  }

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
    String? mobileVerifiedAt,
    String? status,
    int? regComplete,
    String? deletedAt,
    int? forceRegulatedForm,
    int? regulationSubmitted,
    int? regulationRequired,
    int? regulatedBrokerEnabled,
    UserDetails? userDetails,
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
    forceRegulatedForm: forceRegulatedForm ?? this.forceRegulatedForm,
    regulationSubmitted: regulationSubmitted ?? this.regulationSubmitted,
    regulationRequired: regulationRequired ?? this.regulationRequired,
    regulatedBrokerEnabled: regulatedBrokerEnabled ?? this.regulatedBrokerEnabled,
    userDetails: userDetails ?? this.userDetails,
  );
}

class UserDetails {
  final int id;
  final int userId;
  final String title;
  final String gender;
  final DateTime dob;
  final String altMobile;
  final String altEmail;
  final String registerSource;
  final String lastLoginAt;
  final String kycStatus;
  final String kycType;
  final String kycVerifiedBy;
  final int byPassKyc;
  final String kycVerifiedAt;
  final String ibAffiliateRefcode;
  final String isIbAffiliate;
  final String ibAffiliateDateAt;
  final int managerId;
  final String managerAssignedAt;
  final String branchId;
  final String branchCode;
  final String branchAssignedAt;
  final String ibId;
  final String affiliateId;
  final String campaignId;
  final String depositStatus;
  final String withdrawalStatus;
  final String transferStatus;
  final String bonusStatus;
  final String notes;
  final String nationality;
  final int country;
  final int state;
  final int city;
  final String address1;
  final String address2;
  final String postcode;
  final String language;
  final String isUsCitizen;
  final String isPoliticallyExposed;
  final String industry;
  final String taxIdentificationNumber;
  final String mt5AccountLimit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String deletedAt;
  final String personalInfoVerifiedBy;
  final String personalInfoVerifiedAt;
  final String identityVerifiedBy;
  final String identityVerifiedAt;
  final String addressVerifiedBy;
  final String addressVerifiedAt;
  final String kycVerificationLevel;
  final String kycVerificationNotes;
  final String branch;
  final bool documentsSubmitted;
  final String documentsSubmittedAt;
  final String country_name;
  final String state_name;
  final String city_name;

  UserDetails({
    required this.id,
    required this.userId,
    required this.title,
    required this.gender,
    required this.dob,
    required this.altMobile,
    required this.altEmail,
    required this.registerSource,
    required this.lastLoginAt,
    required this.kycStatus,
    required this.kycType,
    required this.kycVerifiedBy,
    required this.byPassKyc,
    required this.kycVerifiedAt,
    required this.ibAffiliateRefcode,
    required this.isIbAffiliate,
    required this.ibAffiliateDateAt,
    required this.managerId,
    required this.managerAssignedAt,
    required this.branchId,
    required this.branchCode,
    required this.branchAssignedAt,
    required this.ibId,
    required this.affiliateId,
    required this.campaignId,
    required this.depositStatus,
    required this.withdrawalStatus,
    required this.transferStatus,
    required this.bonusStatus,
    required this.notes,
    required this.nationality,
    required this.country,
    required this.state,
    required this.city,
    required this.address1,
    required this.address2,
    required this.postcode,
    required this.language,
    required this.isUsCitizen,
    required this.isPoliticallyExposed,
    required this.industry,
    required this.taxIdentificationNumber,
    required this.mt5AccountLimit,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.personalInfoVerifiedBy,
    required this.personalInfoVerifiedAt,
    required this.identityVerifiedBy,
    required this.identityVerifiedAt,
    required this.addressVerifiedBy,
    required this.addressVerifiedAt,
    required this.kycVerificationLevel,
    required this.kycVerificationNotes,
    required this.branch,
    required this.documentsSubmitted,
    required this.documentsSubmittedAt,
    required this.country_name,
    required this.state_name,
    required this.city_name,
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      userId:
          json['user_id'] is int
              ? json['user_id']
              : int.tryParse(json['user_id'].toString()) ?? 0,
      title: json['title'] ?? '',
      gender: json['gender'] ?? '',
      dob: _parseDateTime(json['dob']),
      altMobile: json['alt_mobile'] ?? '',
      altEmail: json['alt_email'] ?? '',
      registerSource: json['register_source'] ?? '',
      lastLoginAt: json['last_login_at'] ?? '',
      kycStatus: json['kyc_status'] ?? '',
      kycType: json['kyc_type'] ?? '',
      kycVerifiedBy: json['kyc_verified_by'] ?? '',
      byPassKyc:
          json['by_pass_kyc'] is int
              ? json['by_pass_kyc']
              : int.tryParse(json['by_pass_kyc'].toString()) ?? 0,
      kycVerifiedAt: json['kyc_verified_at'] ?? '',
      ibAffiliateRefcode: json['ib_affiliate_refcode'] ?? '',
      isIbAffiliate: json['is_ib_affiliate'] ?? '',
      ibAffiliateDateAt: json['ib_affiliate_date_at'] ?? '',
      managerId:
          json['manager_id'] is String && json['manager_id'].isEmpty
              ? 0
              : int.tryParse(json['manager_id'].toString()) ?? 0,
      managerAssignedAt: json['manager_assigned_at'] ?? '',
      branchId: json['branch_id'] ?? '',
      branchCode: json['branch_code'] ?? '',
      branchAssignedAt: json['branch_assigned_at'] ?? '',
      ibId: json['ib_id'] ?? '',
      affiliateId: json['affiliate_id'] ?? '',
      campaignId: json['campaign_id'] ?? '',
      depositStatus: json['deposit_status'] ?? '',
      withdrawalStatus: json['withdrawal_status'] ?? '',
      transferStatus: json['transfer_status'] ?? '',
      bonusStatus: json['bonus_status'] ?? '',
      notes: json['notes'] ?? '',
      nationality: json['nationality'] ?? '',
      country:
          json['country'] is String && json['country'].isEmpty
              ? 0
              : int.tryParse(json['country'].toString()) ?? 0,
      state:
          json['state'] is String && json['state'].isEmpty
              ? 0
              : int.tryParse(json['state'].toString()) ?? 0,
      city:
          json['city'] is String && json['city'].isEmpty
              ? 0
              : int.tryParse(json['city'].toString()) ?? 0,
      address1: json['address_1'] ?? '',
      address2: json['address_2'] ?? '',
      postcode: json['postcode'] ?? '',
      language: json['language'] ?? '',
      isUsCitizen: json['is_us_citizen'] ?? '',
      isPoliticallyExposed: json['is_politically_exposed'] ?? '',
      industry: json['industry'] ?? '',
      taxIdentificationNumber: json['tax_identification_number'] ?? '',
      mt5AccountLimit: json['mt5_account_limit'] ?? '',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      deletedAt: json['deleted_at'] ?? '',
      personalInfoVerifiedBy: json['personal_info_verified_by'] ?? '',
      personalInfoVerifiedAt: json['personal_info_verified_at'] ?? '',
      identityVerifiedBy: json['identity_verified_by'] ?? '',
      identityVerifiedAt: json['identity_verified_at'] ?? '',
      addressVerifiedBy: json['address_verified_by'] ?? '',
      addressVerifiedAt: json['address_verified_at'] ?? '',
      kycVerificationLevel: json['kyc_verification_level'] ?? '',
      kycVerificationNotes: json['kyc_verification_notes'] ?? '',
      branch: json['branch'] ?? '',
      documentsSubmitted: _parseBool(json['documents_submitted']),
      documentsSubmittedAt: json['documents_submitted_at']?.toString() ?? '',
      country_name: json['country_name']?.toString() ?? '',
      state_name: json['state_name']?.toString() ?? '',
      city_name: json['city_name']?.toString() ?? '',
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null || value == '' || value == 'null') return DateTime.now();

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
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'gender': gender,
      'dob': dob.toIso8601String(),
      'alt_mobile': altMobile,
      'alt_email': altEmail,
      'register_source': registerSource,
      'last_login_at': lastLoginAt,
      'kyc_status': kycStatus,
      'kyc_type': kycType,
      'kyc_verified_by': kycVerifiedBy,
      'by_pass_kyc': byPassKyc,
      'kyc_verified_at': kycVerifiedAt,
      'ib_affiliate_refcode': ibAffiliateRefcode,
      'is_ib_affiliate': isIbAffiliate,
      'ib_affiliate_date_at': ibAffiliateDateAt,
      'manager_id': managerId,
      'manager_assigned_at': managerAssignedAt,
      'branch_id': branchId,
      'branch_code': branchCode,
      'branch_assigned_at': branchAssignedAt,
      'ib_id': ibId,
      'affiliate_id': affiliateId,
      'campaign_id': campaignId,
      'deposit_status': depositStatus,
      'withdrawal_status': withdrawalStatus,
      'transfer_status': transferStatus,
      'bonus_status': bonusStatus,
      'notes': notes,
      'nationality': nationality,
      'country': country,
      'state': state,
      'city': city,
      'address1': address1,
      'address2': address2,
      'postcode': postcode,
      'language': language,
      'is_us_citizen': isUsCitizen,
      'is_politically_exposed': isPoliticallyExposed,
      'industry': industry,
      'tax_identification_number': taxIdentificationNumber,
      'mt5_account_limit': mt5AccountLimit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt,
      'personal_info_verified_by': personalInfoVerifiedBy,
      'personal_info_verified_at': personalInfoVerifiedAt,
      'identity_verified_by': identityVerifiedBy,
      'identity_verified_at': identityVerifiedAt,
      'address_verified_by': addressVerifiedBy,
      'address_verified_at': addressVerifiedAt,
      'kyc_verification_level': kycVerificationLevel,
      'kyc_verification_notes': kycVerificationNotes,
      'branch': branch,
      'documents_submitted': documentsSubmitted,
      'documents_submitted_at': documentsSubmittedAt,
      'country_name': country_name,
      'state_name': state_name,
      'city_name': city_name,
    };
  }

  static UserDetails empty() {
    return UserDetails(
      id: 0,
      userId: 0,
      title: '',
      gender: '',
      dob: DateTime.now(),
      altMobile: '',
      altEmail: '',
      registerSource: '',
      lastLoginAt: '',
      kycStatus: '',
      kycType: '',
      kycVerifiedBy: '',
      byPassKyc: 0,
      kycVerifiedAt: '',
      ibAffiliateRefcode: '',
      isIbAffiliate: '',
      ibAffiliateDateAt: '',
      managerId: 0,
      managerAssignedAt: '',
      branchId: '',
      branchCode: '',
      branchAssignedAt: '',
      ibId: '',
      affiliateId: '',
      campaignId: '',
      depositStatus: '',
      withdrawalStatus: '',
      transferStatus: '',
      bonusStatus: '',
      notes: '',
      nationality: '',
      country: 0,
      state: 0,
      city: 0,
      address1: '',
      address2: '',
      postcode: '',
      language: '',
      isUsCitizen: '',
      isPoliticallyExposed: '',
      industry: '',
      taxIdentificationNumber: '',
      mt5AccountLimit: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      deletedAt: '',
      personalInfoVerifiedBy: '',
      personalInfoVerifiedAt: '',
      identityVerifiedBy: '',
      identityVerifiedAt: '',
      addressVerifiedBy: '',
      addressVerifiedAt: '',
      kycVerificationLevel: '',
      kycVerificationNotes: '',
      branch: '',
      documentsSubmitted: false,
      documentsSubmittedAt: '',
      country_name: '',
      state_name: '',
      city_name: '',
    );
  }

  UserDetails copyWith({
    int? id,
    int? userId,
    String? title,
    String? gender,
    DateTime? dob,
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
    String? managerAssignedAt,
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
    int? country,
    int? state,
    int? city,
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
    bool? documentsSubmitted,
    String? documentsSubmittedAt,
    String? country_name,
    String? state_name,
    String? city_name,
  }) => UserDetails(
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
    documentsSubmitted: documentsSubmitted ?? this.documentsSubmitted,
    documentsSubmittedAt: documentsSubmittedAt ?? this.documentsSubmittedAt,
    country_name: country_name ?? this.country_name,
    state_name: state_name ?? this.state_name,
    city_name: city_name ?? this.city_name,
  );
}
