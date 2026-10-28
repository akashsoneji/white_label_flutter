import '../constants/api_const.dart';
import '../models/demo_contest/demo_contest_enrollment_model.dart';
import '../models/demo_contest/demo_contest_model.dart';
import '../models/demo_contest/leaderboard_entry_model.dart';
import '../models/demo_contest/demo_contest_my_stats_model.dart';
import '../services/api_service.dart';

/// HTTP service for the user Demo Contest module
/// (`Modules/DemoContest/routes/api.php` → `user/demo-contest/*`).
class DemoContestService {
  DemoContestService._internal();
  static final DemoContestService instance = DemoContestService._internal();

  /// All published contests; each row is `{contest, is_enrolled, participant}`.
  Future<List<DemoContest>> fetchContests() async {
    final body = await _get(ApiConstants.demoContestContests, 'Failed to load contests');
    return _list(body['data'])
        .map((e) => DemoContest.fromJson(e))
        .toList(growable: false);
  }

  /// Contests that are open for entry or running.
  Future<List<DemoContest>> fetchFeaturedContests() async {
    final all = await fetchContests();
    return all
        .where((c) => c.acceptingEntries || c.isLive)
        .toList(growable: false);
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard(
    String contestId, {
    int limit = 100,
  }) async {
    final body = await _get(
      ApiConstants.demoContestLeaderboard(contestId),
      'Failed to load leaderboard',
    );
    return _list(body['data'])
        .map((e) => LeaderboardEntry.fromJson(e))
        .take(limit)
        .toList(growable: false);
  }

  /// User's own stats for a given contest.
  Future<DemoContestMyStats?> fetchMyStats(String contestId) async {
    final response = await ApiService.get(
      endpoint: ApiConstants.demoContestMyStats,
      queryParameters: {'contest_id': contestId},
    );
    final body = response.data;
    if (!response.success || body is! Map<String, dynamic>) return null;
    return DemoContestMyStats.fromJson(body);
  }

  Future<DemoContestEnrollPreview> enrollPreview(String contestId) async {
    final body = await _post(
      ApiConstants.demoContestEnrollPreview(contestId),
      null,
      'Failed to check enrollment',
    );
    return DemoContestEnrollPreview.fromJson(_map(body['data']));
  }

  Future<List<DemoContestStep>> fetchSteps(String contestId) async {
    final body = await _get(
      ApiConstants.demoContestSteps(contestId),
      'Failed to load enrollment steps',
    );
    return _list(body['data'])
        .map((e) => DemoContestStep.fromJson(e))
        .toList(growable: false);
  }

  Future<void> clickStep(String stepId) async {
    await _post(
      ApiConstants.demoContestStepClick(stepId),
      null,
      'Failed to complete step',
    );
  }

  Future<DemoContestTerms> fetchTerms(String contestId) async {
    final body = await _get(
      ApiConstants.demoContestTerms(contestId),
      'Failed to load terms',
    );
    return DemoContestTerms(
      enabled: body['enabled'] == true,
      content: body['content']?.toString() ?? '',
    );
  }

  /// Creates the contest MT5 account. Returns the backend success message.
  Future<String> enroll(String contestId, {required bool termsAccepted}) async {
    final body = await _post(
      ApiConstants.demoContestEnroll(contestId),
      {'terms_accepted': termsAccepted},
      'Failed to join contest',
    );
    return body['message']?.toString() ?? '';
  }

  /// Submits a prize claim. Returns the backend success message.
  Future<String> claim(String contestId, {String? realAccountNumber}) async {
    final body = await _post(
      ApiConstants.demoContestClaim,
      {
        'contest_id': int.tryParse(contestId) ?? contestId,
        if (realAccountNumber != null && realAccountNumber.isNotEmpty)
          'real_account_number': realAccountNumber,
      },
      'Failed to submit claim',
    );
    return body['message']?.toString() ?? '';
  }

  Future<List<DemoContestTrade>> fetchTradingHistory(String contestId) async {
    final body = await _get(
      ApiConstants.demoContestTradingHistory(contestId),
      'Failed to load trading history',
    );
    return _list(body['data'])
        .map((e) => DemoContestTrade.fromJson(e))
        .toList(growable: false);
  }

  Future<DemoContestRuleViolations> fetchRuleViolations(
    String contestId,
  ) async {
    final body = await _get(
      ApiConstants.demoContestRuleViolations(contestId),
      'Failed to load rule violations',
    );
    return DemoContestRuleViolations.fromJson(_map(body['data']));
  }

  // ───────────────────────────── Helpers ─────────────────────────────

  Future<Map<String, dynamic>> _get(String endpoint, String fallback) async {
    final response = await ApiService.get(endpoint: endpoint);
    return _bodyOrThrow(response, fallback);
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic>? data,
    String fallback,
  ) async {
    final response = await ApiService.post(endpoint: endpoint, data: data);
    return _bodyOrThrow(response, fallback);
  }

  /// These APIs report business errors as `status: false` + `message`.
  Map<String, dynamic> _bodyOrThrow(ApiResponse response, String fallback) {
    final body = _map(response.data);
    final message = body['message']?.toString();
    if (!response.success || body['status'] == false) {
      throw Exception(
        (message != null && message.isNotEmpty)
            ? message
            : (response.message ?? fallback),
      );
    }
    return body;
  }

  Map<String, dynamic> _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
}
