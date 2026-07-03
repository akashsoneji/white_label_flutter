import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../data/datasources/pmam_remote_data_source.dart';
import '../data/repositories/pmam_repository_impl.dart';
import '../data/repositories/pmam_repository.dart';
import '../data/usecases/apply_as_manager.dart';
import '../data/usecases/get_manager_status.dart';
import 'package:crm_app/screens/pmam/view_models/pmam_controller.dart';

class PmamBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PmamRemoteDataSource>(
      () => PmamRemoteDataSource(Get.find<ApiClient>()),
    );
    Get.lazyPut<PmamRepository>(
      () => PmamRepositoryImpl(Get.find<PmamRemoteDataSource>()),
    );

    Get.lazyPut<GetManagerStatus>(
      () => GetManagerStatus(Get.find<PmamRepository>()),
    );
    Get.lazyPut<ApplyAsManager>(
      () => ApplyAsManager(Get.find<PmamRepository>()),
    );

    Get.lazyPut<PmamController>(
      () => PmamController(
        getManagerStatus: Get.find<GetManagerStatus>(),
        applyAsManager: Get.find<ApplyAsManager>(),
        repo: Get.find<PmamRepository>(),
      ),
    );
  }
}

