import 'package:crm_app/models/login_response_model.dart';

class GoogleOtpGenerateData {
  final String qrCodeUrl;
  final String otpAuthUrl;
  final String secretKey;
  final bool verificationRequired;

  GoogleOtpGenerateData({
    required this.qrCodeUrl,
    required this.otpAuthUrl,
    required this.secretKey,
    required this.verificationRequired,
  });

  factory GoogleOtpGenerateData.fromJson(Map<String, dynamic> json) {
    return GoogleOtpGenerateData(
      qrCodeUrl: json['qr_code_url']?.toString() ?? '',
      otpAuthUrl: json['otp_auth_url']?.toString() ?? '',
      secretKey: json['secret_key']?.toString() ?? '',
      verificationRequired: json['verification_required'] == true,
    );
  }
}

class GoogleOtpVerifyData {
  final bool otpEnabled;

  GoogleOtpVerifyData({required this.otpEnabled});

  factory GoogleOtpVerifyData.fromJson(Map<String, dynamic> json) {
    return GoogleOtpVerifyData(
      otpEnabled: _parseBool(json['otp_enabled']),
    );
  }
}

class GoogleOtpLoginChallenge {
  final bool requiresGoogleOtp;
  final String email;

  GoogleOtpLoginChallenge({
    required this.requiresGoogleOtp,
    required this.email,
  });

  factory GoogleOtpLoginChallenge.fromJson(Map<String, dynamic> json) {
    return GoogleOtpLoginChallenge(
      requiresGoogleOtp: json['requires_google_otp'] == true,
      email: json['email']?.toString() ?? '',
    );
  }
}

/// Result of login API — either full session or Google OTP challenge.
class LoginApiResult {
  final LoginResponseModel? loginResponse;
  final GoogleOtpLoginChallenge? googleOtpChallenge;

  LoginApiResult({this.loginResponse, this.googleOtpChallenge});

  bool get requiresGoogleOtp => googleOtpChallenge != null;

  factory LoginApiResult.fromLoginResponse(LoginResponseModel response) {
    return LoginApiResult(loginResponse: response);
  }

  factory LoginApiResult.fromGoogleOtpChallenge(
    GoogleOtpLoginChallenge challenge,
  ) {
    return LoginApiResult(googleOtpChallenge: challenge);
  }
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}
