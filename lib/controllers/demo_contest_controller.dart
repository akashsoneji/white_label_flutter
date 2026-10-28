import 'package:get/get.dart';

import '../models/demo_contest/contest_winner_model.dart';
import '../models/demo_contest/demo_contest_enrollment_model.dart';
import '../models/demo_contest/demo_contest_model.dart';
import '../models/demo_contest/leaderboard_entry_model.dart';
import '../models/demo_contest/my_contest_entry_model.dart';
import '../models/demo_contest/demo_contest_my_stats_model.dart';
import '../services/demo_contest_service.dart';
import '../services/language_service.dart';

/// Reactive controller for the Demo Contest module.
///
/// All flows (Join Contest, Contest Details, Leaderboard, My History)
/// read from the same shared state so changes propagate across screens
/// immediately. e.g. joinContest() updates [myEntries] and
/// [entriesByContestId], which makes both "Join" and "My Contest
/// History" re-render in real time without refetching.
class DemoContestController extends GetxController {
  static DemoContestController get to => Get.find();

  final DemoContestService _service = DemoContestService.instance;

  // ────────── State ──────────
  final RxList<DemoContest> contests = <DemoContest>[].obs;
  final RxList<DemoContest> featured = <DemoContest>[].obs;

  /// All historical/current user entries.
  final RxList<MyContestEntry> myEntries = <MyContestEntry>[].obs;

  /// Lookup by contestId for fast per-screen state.
  final RxMap<String, MyContestEntry> entriesByContestId =
      <String, MyContestEntry>{}.obs;

  /// Leaderboard keyed by contestId. Refreshing also preserves the user
  /// highlighted position.
  final RxMap<String, RxList<LeaderboardEntry>> leaderboards =
      <String, RxList<LeaderboardEntry>>{}.obs;

  final RxList<ContestWinner> winners = <ContestWinner>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isJoining = false.obs;
  final RxBool isLoadingLeaderboard = false.obs;

  final RxString errorMessage = ''.obs;

  // ────────── Lifecycle ──────────

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  /// Reload everything from the service.
  Future<void> refreshAll() async {
    isLoading.value = true;
    errorMessage.value = '';
    update();

    String? contestsError;
    String? entriesError;
    String? winnersError;

    try {
      final loaded = await _service.fetchContests();
      contests.assignAll(loaded);
      featured.assignAll(loaded.where(
        (c) => c.acceptingEntries || c.isLive,
      ));

      // Build myEntries from contests where isEnrolled is true
      final myContests = loaded.where((c) => c.isEnrolled).toList();
      // Wait, we need MyContestEntry but the new UI design just uses the DemoContest directly for enrolled.
      // I will leave entriesByContestId mostly empty or just mock it since we use DemoContest directly now.
    } catch (e) {
      contestsError = e.toString();
    } finally {
      errorMessage.value = contestsError ?? '';
      isLoading.value = false;
    }
  }

  // ────────── Public actions ──────────

  Future<void> refreshPull() async {
    isRefreshing.value = true;
    try {
      await refreshAll();
    } finally {
      isRefreshing.value = false;
    }
  }

  DemoContest? contestById(String id) {
    try {
      return contests.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  MyContestEntry? entryFor(String contestId) =>
      entriesByContestId[contestId];

  bool isJoined(String contestId) =>
      contests.any((c) => c.id == contestId && c.isEnrolled);

  /// Loads the leaderboard for a contest into the controller cache. The
  /// UI observes [leaderboards] and rerenders when state changes.
  Future<void> loadLeaderboard(String contestId) async {
    if (leaderboards.containsKey(contestId)) return;
    leaderboards[contestId] = <LeaderboardEntry>[].obs;
    await refreshLeaderboard(contestId);
  }

  Future<void> refreshLeaderboard(String contestId) async {
    isLoadingLeaderboard.value = true;
    try {
      final list = await _service.fetchLeaderboard(contestId);
      // `is_me` from the API marks the current user's row.
      final decorated = list
          .map(
            (e) => e.copyWithFlag(
              flagEmoji: countryToFlagEmoji(e.countryCode),
              isTop3: e.rank <= 3,
            ),
          )
          .toList();
      (leaderboards[contestId] ??= <LeaderboardEntry>[].obs)
          .assignAll(decorated);
    } catch (e) {
      errorMessage.value = _cleanError(e);
    } finally {
      isLoadingLeaderboard.value = false;
    }
  }

  /// Enrollment steps (tasks) for a contest; empty when steps are disabled.
  Future<List<DemoContestStep>> fetchSteps(String contestId) async {
    try {
      return await _service.fetchSteps(contestId);
    } catch (e) {
      errorMessage.value = _cleanError(e);
      return const [];
    }
  }

  Future<bool> completeStep(String stepId) async {
    try {
      await _service.clickStep(stepId);
      return true;
    } catch (e) {
      errorMessage.value = _cleanError(e);
      return false;
    }
  }

  /// Web flow: `enroll-preview` (eligibility + fee) → `enroll`. The backend
  /// rejects missing terms / unfinished steps with a message we surface.
  /// Returns the success message, or null on failure ([errorMessage] set).
  Future<String?> joinContest(
    String contestId, {
    bool termsAccepted = true,
  }) async {
    if (isJoined(contestId)) return '';
    isJoining.value = true;
    errorMessage.value = '';
    try {
      final preview = await _service.enrollPreview(contestId);
      if (!preview.canEnroll) {
        errorMessage.value = preview.maxParticipations > 0 &&
                preview.currentParticipations >= preview.maxParticipations
            ? TranslationUtils.tr('dc_max_participations_reached')
            : TranslationUtils.tr('dc_cannot_enroll');
        return null;
      }
      final message = await _service.enroll(
        contestId,
        termsAccepted: termsAccepted,
      );
      await refreshAll();
      return message;
    } catch (e) {
      errorMessage.value = _cleanError(e);
      return null;
    } finally {
      isJoining.value = false;
    }
  }

  Future<String?> claimPrize(String contestId, {String? realAccountNumber}) async {
    errorMessage.value = '';
    try {
      return await _service.claim(
        contestId,
        realAccountNumber: realAccountNumber,
      );
    } catch (e) {
      errorMessage.value = _cleanError(e);
      return null;
    }
  }

  Future<List<DemoContestTrade>> fetchTradingHistory(String contestId) =>
      _service.fetchTradingHistory(contestId);

  Future<DemoContestRuleViolations> fetchRuleViolations(String contestId) =>
      _service.fetchRuleViolations(contestId);

  String _cleanError(Object e) =>
      e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  Future<DemoContestMyStats?> fetchMyStats(String contestId) async {
    try {
      return await _service.fetchMyStats(contestId);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadFeatured() async {
    try {
      final list = await _service.fetchFeaturedContests();
      featured.assignAll(list);
    } catch (_) {}
  }
}

/// Convert ISO-2 country code (e.g. "GB") to a flag emoji ("🇬🇧").
String countryToFlagEmoji(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6;
  final first =
      code.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0);
  final second =
      code.toUpperCase().codeUnitAt(1) - 'A'.codeUnitAt(0);
  if (first < 0 || first > 25 || second < 0 || second > 25) return '';
  return String.fromCharCode(base + first) + String.fromCharCode(base + second);
}

// ─────────────────────────── Decorators ───────────────────────────

extension LeaderboardEntryFlag on LeaderboardEntry {
  LeaderboardEntry copyWithFlag({
    String flagEmoji = '',
    bool? isCurrentUser,
    bool? isTop3,
  }) {
    return LeaderboardEntry(
      rank: rank,
      userId: userId,
      displayName: flagEmoji.isEmpty
          ? displayName
          : '$flagEmoji ${displayName.replaceAll(RegExp(r"^[^\w]+"), "")}',
      countryCode: countryCode,
      equity: equity,
      pnl: pnl,
      pnlPercent: pnlPercent,
      tradesCount: tradesCount,
      winRate: winRate,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      isTop3: isTop3 ?? this.isTop3,
    );
  }
}