import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_const.dart';
import '../models/demo_contest/contest_winner_model.dart';
import '../models/demo_contest/demo_contest_model.dart';
import '../models/demo_contest/leaderboard_entry_model.dart';
import '../models/demo_contest/my_contest_entry_model.dart';
import '../models/demo_contest/demo_contest_my_stats_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../flavor_config.dart';

/// Real HTTP-backed service for the Demo Contest module.
///
/// Each method calls the backend via [ApiService.get] and maps the JSON
/// response into the shared Dart model classes. The public API surface
/// mirrors the old mock service so the controller needs no changes.
class DemoContestService {
  DemoContestService._internal();
  static final DemoContestService instance = DemoContestService._internal();

  /// All published contests (open, live, upcoming, ended).
  Future<List<DemoContest>> fetchContests() async {
    final response = await ApiService.get(
      endpoint: ApiConstants.demoContestContests,
    );

    if (!response.success || response.data == null) {
      throw Exception(response.message ?? 'Failed to load contests');
    }

    final rawList = response.data is List
        ? response.data as List
        : (response.data['data'] as List? ?? <dynamic>[]);

    return rawList
        .map((e) => DemoContest.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Contests the user has joined (accepted or active entries).
  Future<List<DemoContest>> fetchFeaturedContests() async {
    final all = await fetchContests();
    return all
        .where((c) => c.acceptingEntries || c.isLive)
        .toList(growable: false);
  }

  /// Single contest by id — fetched from the same list endpoint and
  /// filtered locally since the backend returns a flat array.
  Future<DemoContest?> fetchContestById(String id) async {
    final all = await fetchContests();
    return all.firstWhereOrNull((c) => c.id == id);
  }

  /// Top-N leaderboard for a contest.
  Future<List<LeaderboardEntry>> fetchLeaderboard(
    String contestId, {
    int limit = 100,
  }) async {
    final response = await ApiService.get(
      endpoint: ApiConstants.demoContestContests,
      queryParameters: {'contest_id': contestId, 'leaderboard': '1'},
    );

    if (!response.success || response.data == null) {
      throw Exception(response.message ?? 'Failed to load leaderboard');
    }

    final rawList = response.data is List
        ? response.data as List
        : (response.data['data'] as List? ?? <dynamic>[]);

    return rawList
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .take(limit)
        .toList(growable: false);
  }

  /// Top-10 subset of the leaderboard.
  Future<List<LeaderboardEntry>> fetchTopLeaderboard(
    String contestId, {
    int limit = 10,
  }) async {
    return fetchLeaderboard(contestId, limit: limit);
  }

  /// The authenticated user's contest entries, sorted newest first.
  Future<List<MyContestEntry>> fetchMyEntries() async {
    final response = await ApiService.get(
      endpoint: ApiConstants.demoContestContests,
      queryParameters: {'my_entries': '1'},
    );

    if (!response.success || response.data == null) {
      throw Exception(response.message ?? 'Failed to load your entries');
    }

    final rawList = response.data is List
        ? response.data as List
        : (response.data['data'] as List? ?? <dynamic>[]);

    final entries = rawList
        .map((e) => MyContestEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    entries.sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    return entries;
  }

  /// Entry for a specific contest, or null if the user hasn't joined.
  Future<MyContestEntry?> fetchMyEntryForContest(String contestId) async {
    final all = await fetchMyEntries();
    return all.firstWhereOrNull((e) => e.contestId == contestId);
  }

  /// User's own stats for a given contest.
  Future<DemoContestMyStats?> fetchMyStats(String contestId) async {
    final response = await ApiService.get(
      endpoint: ApiConstants.demoContestMyStats,
      queryParameters: {'contest_id': contestId},
    );

    if (!response.success || response.data == null) {
      return null;
    }

    return DemoContestMyStats.fromJson(
      response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'status': false},
    );
  }

  /// Join a contest (register / create entry).
  Future<MyContestEntry> joinContest(String contestId) async {
    final token = await SecureStorageService.getAuthToken();
    final base = FlavorConfig.instance.apiBaseUrl.endsWith('/')
        ? FlavorConfig.instance.apiBaseUrl
        : '${FlavorConfig.instance.apiBaseUrl}/';
    final url = Uri.parse('${base}${ApiConstants.ajax}demo-contest/join');

    final response = await http.post(
      url,
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'contest_id': contestId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to join contest (HTTP ${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != true || body['data'] == null) {
      throw Exception(body['message'] ?? 'Failed to join contest');
    }

    return MyContestEntry.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Past winners (global leaderboard summary).
  Future<List<ContestWinner>> fetchWinners({int limit = 25}) async {
    final response = await ApiService.get(
      endpoint: ApiConstants.demoContestContests,
      queryParameters: {'winners': '1', 'limit': '$limit'},
    );

    if (!response.success || response.data == null) {
      return <ContestWinner>[];
    }

    final rawList = response.data is List
        ? response.data as List
        : (response.data['data'] as List? ?? <dynamic>[]);

    return rawList
        .map((e) => ContestWinner.fromJson(e as Map<String, dynamic>))
        .take(limit)
        .toList(growable: false);
  }
}

// ───────────────────────────── Compatibility ─────────────────────────────

extension _IterableFirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
