import 'package:crm_app/core/network/api_response.dart';
import '../repositories/pmam_repository.dart';

class ApplyAsManager {
  final PmamRepository _repo;
  ApplyAsManager(this._repo);

  Future<ApiResponse> call() => _repo.applyAsManager();
}

