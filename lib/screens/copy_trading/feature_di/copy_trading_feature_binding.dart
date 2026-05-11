import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../data/datasources/copy_trading_remote_data_source.dart';
import '../data/repositories/copy_trading_repository_impl.dart';
import '../data/repositories/copy_trading_repository.dart';

class CopyTradingFeatureBinding extends Bindings {
  @override
  void dependencies() {
    // ApiClient is registered globally in initServices(), so we just reuse it.
    Get.lazyPut<CopyTradingRemoteDataSource>(
      () => CopyTradingRemoteDataSource(Get.find<ApiClient>()),
    );
    Get.lazyPut<CopyTradingRepository>(
      () => CopyTradingRepositoryImpl(Get.find<CopyTradingRemoteDataSource>()),
    );
  }
}

