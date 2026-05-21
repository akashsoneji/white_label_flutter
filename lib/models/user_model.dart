class UserModel {
  final int id;
  final String email;
  final String? emailVerifiedAt;
  final String createdAt;
  final String updatedAt;
  final String userSlug;
  final String firstName;
  final String lastName;
  final String mobile;
  final String? mobileVerifiedAt;
  final String status;
  final int regComplete;
  final String? deletedAt;
  final bool googleOtpEnabled;

  UserModel({
    required this.id,
    required this.email,
    this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.userSlug,
    required this.firstName,
    required this.lastName,
    required this.mobile,
    this.mobileVerifiedAt,
    required this.status,
    required this.regComplete,
    this.deletedAt,
    this.googleOtpEnabled = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : 0,
      email: json['email'] is String ? json['email'] : '',
      emailVerifiedAt: json['email_verified_at'] is String ? json['email_verified_at'] : null,
      createdAt: json['created_at'] is String ? json['created_at'] : '',
      updatedAt: json['updated_at'] is String ? json['updated_at'] : '',
      userSlug: json['user_slug'] is String ? json['user_slug'] : '',
      firstName: json['first_name'] is String ? json['first_name'] : '',
      lastName: json['last_name'] is String ? json['last_name'] : '',
      mobile: json['mobile'] is String ? json['mobile'] : '',
      mobileVerifiedAt: json['mobile_verified_at'] is String ? json['mobile_verified_at'] : null,
      status: json['status'] is String ? json['status'] : '',
      regComplete: json['reg_complete'] is int ? json['reg_complete'] : 0,
      deletedAt: json['deleted_at'] is String ? json['deleted_at'] : null,
      googleOtpEnabled: _parseGoogleOtp(json['google_otp_enabled']),
    );
  }

  static bool _parseGoogleOtp(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'email_verified_at': emailVerifiedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'user_slug': userSlug,
      'first_name': firstName,
      'last_name': lastName,
      'mobile': mobile,
      'mobile_verified_at': mobileVerifiedAt,
      'status': status,
      'reg_complete': regComplete,
      'deleted_at': deletedAt,
      'google_otp_enabled': googleOtpEnabled,
    };
  }

  UserModel copyWith({bool? googleOtpEnabled}) {
    return UserModel(
      id: id,
      email: email,
      emailVerifiedAt: emailVerifiedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userSlug: userSlug,
      firstName: firstName,
      lastName: lastName,
      mobile: mobile,
      mobileVerifiedAt: mobileVerifiedAt,
      status: status,
      regComplete: regComplete,
      deletedAt: deletedAt,
      googleOtpEnabled: googleOtpEnabled ?? this.googleOtpEnabled,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  bool get isEmailVerified => emailVerifiedAt != null;
  bool get isMobileVerified => mobileVerifiedAt != null;
  bool get isActive => status == 'active';
  bool get isRegistrationComplete => regComplete == 1;
} 