import 'package:crm_app/screens/auth/data/repositories/auth_repository.dart';
import 'package:crm_app/screens/auth/data/usecases/register_user.dart';
import 'package:crm_app/screens/auth/data/usecases/register_with_otp_verification.dart';
import 'package:crm_app/screens/auth/data/usecases/forgot_password.dart';
import 'package:crm_app/screens/auth/data/usecases/request_password_reset_otp.dart';
import 'package:crm_app/screens/auth/data/usecases/reset_password.dart';
import 'package:crm_app/screens/auth/data/usecases/reset_password_with_otp.dart';
import 'package:crm_app/screens/auth/data/usecases/send_otp.dart';
import 'package:crm_app/screens/auth/data/usecases/verify_password_reset_otp.dart';
import 'package:crm_app/models/login_response_model.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;

  setUp(() {
    repo = _MockAuthRepository();
  });

  test('RegisterUser calls repo.register', () async {
    final uc = RegisterUser(repo);
    when(() => repo.register(data: any(named: 'data'))).thenAnswer(
      (_) async => ApiResponse.success(<String, dynamic>{'ok': true}),
    );

    await uc(data: {'x': 1});

    verify(() => repo.register(data: {'x': 1})).called(1);
  });

  test('ForgotPassword calls repo.forgotPassword', () async {
    final uc = ForgotPassword(repo);
    when(() => repo.forgotPassword(data: any(named: 'data'))).thenAnswer(
      (_) async => ApiResponse.success(<String, dynamic>{'status': true}),
    );

    await uc(data: {'email': 'a@b.com'});

    verify(() => repo.forgotPassword(data: {'email': 'a@b.com'})).called(1);
  });

  test('RegisterWithOtpVerification calls repo.registerWithOTPVerification', () async {
    final uc = RegisterWithOtpVerification(repo);
    when(() => repo.registerWithOTPVerification(data: any(named: 'data'))).thenAnswer(
      (_) async => ApiResponse.success(
        LoginResponseModel.fromJson({
          'status': true,
          'message': 'ok',
          'data': {
            'token': 't',
            'websocket_token': 'w',
            'user': {'email': 'a@b.com'},
          },
        }),
      ),
    );

    await uc(data: {'x': 1});

    verify(() => repo.registerWithOTPVerification(data: {'x': 1})).called(1);
  });

  test('SendOtp calls repo.sendOTP', () async {
    final uc = SendOtp(repo);
    when(() => repo.sendOTP(email: any(named: 'email'))).thenAnswer(
      (_) async => ApiResponse.success(<String, dynamic>{'message': 'sent'}),
    );

    await uc(email: 'a@b.com');

    verify(() => repo.sendOTP(email: 'a@b.com')).called(1);
  });

  test('ResetPassword calls repo.resetPassword', () async {
    final uc = ResetPassword(repo);
    when(
      () => repo.resetPassword(
        email: any(named: 'email'),
        otp: any(named: 'otp'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async => ApiResponse.success(<String, dynamic>{'ok': true}));

    await uc(email: 'a@b.com', otp: '1234', newPassword: 'new');

    verify(
      () => repo.resetPassword(email: 'a@b.com', otp: '1234', newPassword: 'new'),
    ).called(1);
  });

  test('RequestPasswordResetOtp calls repo.requestPasswordResetOTP', () async {
    final uc = RequestPasswordResetOtp(repo);
    when(() => repo.requestPasswordResetOTP(email: any(named: 'email'))).thenAnswer(
      (_) async => ApiResponse.success(<String, dynamic>{'message': 'sent'}),
    );

    await uc(email: 'a@b.com');

    verify(() => repo.requestPasswordResetOTP(email: 'a@b.com')).called(1);
  });

  test('VerifyPasswordResetOtp calls repo.verifyPasswordResetOTP', () async {
    final uc = VerifyPasswordResetOtp(repo);
    when(
      () => repo.verifyPasswordResetOTP(
        email: any(named: 'email'),
        otp: any(named: 'otp'),
      ),
    ).thenAnswer((_) async => ApiResponse.success(<String, dynamic>{'ok': true}));

    await uc(email: 'a@b.com', otp: '1234');

    verify(() => repo.verifyPasswordResetOTP(email: 'a@b.com', otp: '1234')).called(1);
  });

  test('ResetPasswordWithOtp calls repo.resetPasswordWithOTP', () async {
    final uc = ResetPasswordWithOtp(repo);
    when(
      () => repo.resetPasswordWithOTP(
        email: any(named: 'email'),
        otp: any(named: 'otp'),
        password: any(named: 'password'),
        passwordConfirmation: any(named: 'passwordConfirmation'),
      ),
    ).thenAnswer((_) async => ApiResponse.success(<String, dynamic>{'ok': true}));

    await uc(
      email: 'a@b.com',
      otp: '1234',
      password: 'p',
      passwordConfirmation: 'p',
    );

    verify(
      () => repo.resetPasswordWithOTP(
        email: 'a@b.com',
        otp: '1234',
        password: 'p',
        passwordConfirmation: 'p',
      ),
    ).called(1);
  });
}

