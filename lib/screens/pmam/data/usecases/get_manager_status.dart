import 'package:crm_app/core/network/api_response.dart';
import '../repositories/pmam_repository.dart';

class GetManagerStatus {
  final PmamRepository _repo;
  GetManagerStatus(this._repo);

  Future<ApiResponse> call() => _repo.getManagerStatus();
}

