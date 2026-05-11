import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../services/auth_service.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/auth_repository.dart';
import '../data/usecases/login_user.dart';

class AuthFeatureBinding extends Bindings {
  @override
  void dependencies() {
    // Reuse the existing AuthService singleton registered in initServices().
    // This avoids changing working app flows while we migrate.
    Get.lazyPut<AuthRepository>(
      () => AuthRepositoryImpl(Get.find<AuthService>(), Get.find<ApiClient>()),
    );
    Get.lazyPut<LoginUser>(() => LoginUser(Get.find<AuthRepository>()));
  }
}

