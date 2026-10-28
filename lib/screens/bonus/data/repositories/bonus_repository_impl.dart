import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/core/network/api_client.dart';
import 'package:crm_app/core/network/api_response.dart';

import '../../domain/repositories/bonus_repository.dart';

class BonusRepositoryImpl implements BonusRepository {
  final ApiClient _api;
  BonusRepositoryImpl(this._api);

  @override
  Future<ApiResponse> getScratchCards({String? token}) {
    return _api.get(endpoint: ApiConstants.getScratchCards, token: token);
  }

  @override
  Future<ApiResponse> revealScratchCard({
    String? token,
    required int cardId,
  }) {
    return _api.post(
      endpoint: ApiConstants.revealScratchCard,
      token: token,
      data: {'card_id': cardId},
    );
  }

  @override
  Future<ApiResponse> getScratchLeaderboard({String? token}) {
    return _api.get(endpoint: ApiConstants.getScratchLeaderboard, token: token);
  }

  @override
  Future<ApiResponse> convertScratchCreditToBalance({
    String? token,
    required int accountId,
  }) {
    return _api.post(
      endpoint: ApiConstants.convertScratchCreditToBalance,
      token: token,
      data: {'account_id': accountId},
    );
  }

  @override
  Future<ApiResponse> claimScratchReward({String? token}) {
    return _api.post(endpoint: ApiConstants.claimScratchReward, token: token);
  }
}
