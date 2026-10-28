import 'package:crm_app/core/network/api_response.dart';

abstract class BonusRepository {
  Future<ApiResponse> getScratchCards({String? token});

  Future<ApiResponse> revealScratchCard({
    String? token,
    required int cardId,
  });

  Future<ApiResponse> getScratchLeaderboard({String? token});

  Future<ApiResponse> convertScratchCreditToBalance({
    String? token,
    required int accountId,
  });

  Future<ApiResponse> claimScratchReward({String? token});
}
