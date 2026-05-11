import 'package:crm_app/core/network/api_response.dart';
import '../repositories/pmam_repository.dart';

class GetManagerDashboard {
  final PmamRepository _repo;
  GetManagerDashboard(this._repo);

  Future<List<ApiResponse>> call() {
    return Future.wait([
      _repo.getManagerDashboardStats(),
      _repo.getManagerPlans(),
    ]);
  }
}

