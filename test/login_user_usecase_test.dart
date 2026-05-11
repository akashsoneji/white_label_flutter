import 'package:crm_app/screens/auth/data/repositories/auth_repository.dart';
import 'package:crm_app/screens/auth/data/usecases/login_user.dart';
import 'package:crm_app/models/login_response_model.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

void main() {
  group('LoginUser', () {
    test('calls repository.login', () async {
      final repo = _MockAuthRepo();
      final usecase = LoginUser(repo);

      final expected = ApiResponse<LoginResponseModel>(
        success: false,
        message: 'nope',
        data: null,
      );
      when(
        () => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fcmToken: any(named: 'fcmToken'),
          deviceType: any(named: 'deviceType'),
        ),
      ).thenAnswer((_) async => expected);

      final result = await usecase(
        email: 'a@b.com',
        password: 'pass',
        fcmToken: 't',
        deviceType: 'android',
      );

      expect(result, same(expected));
      verify(
        () => repo.login(
          email: 'a@b.com',
          password: 'pass',
          fcmToken: 't',
          deviceType: 'android',
        ),
      ).called(1);
      verifyNoMoreInteractions(repo);
    });
  });
}

