import 'dart:math';

import '../models/demo_contest/contest_winner_model.dart';
import '../models/demo_contest/demo_contest_model.dart';
import '../models/demo_contest/leaderboard_entry_model.dart';
import '../models/demo_contest/my_contest_entry_model.dart';

/// Mock data service for the Demo Contest module.
///
/// This service intentionally mirrors the shape of a real REST API so the
/// controller code can stay backend-agnostic. Each method simulates a
/// network round-trip with a small artificial delay so the UI exercises
/// the real loading states (spinner, skeleton, refresh behaviour).
///
/// Once the backend endpoints exist, only this class needs to be replaced
/// with real HTTP calls — every consumer takes plain Dart models.
class DemoContestService {
  DemoContestService._internal();
  static final DemoContestService instance = DemoContestService._internal();

  /// Demo contests shipped out-of-the-box. Realistic enough to drive the
  /// entire UI flow (Join, Live, Ended, Upcoming).
  final List<DemoContest> _contests = _seedContests();

  /// Per-contest leaderboard state, keyed by contest id.
  final Map<String, List<LeaderboardEntry>> _leaderboards =
      _seedLeaderboards();

  /// The user's currently active / past entries, one per contest.
  final Map<String, MyContestEntry> _myEntries = _seedMyEntries();

  /// Past winners showcases.
  final List<ContestWinner> _winners = _seedWinners();

  // ────────────────────────── Public API ──────────────────────────

  Future<List<DemoContest>> fetchContests() async {
    await _simulateLatency();
    return List.unmodifiable(_contests);
  }

  Future<List<DemoContest>> fetchFeaturedContests() async {
    await _simulateLatency(minMs: 200, maxMs: 500);
    return _contests
        .where((c) => c.acceptingEntries || c.isLive)
        .toList(growable: false);
  }

  Future<DemoContest?> fetchContestById(String id) async {
    await _simulateLatency();
    return _contests.firstWhereOrNull((c) => c.id == id);
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard(
    String contestId, {
    int limit = 100,
  }) async {
    await _simulateLatency(minMs: 400, maxMs: 900);
    final list = _leaderboards[contestId] ?? const <LeaderboardEntry>[];
    return list.take(limit).toList(growable: false);
  }

  Future<List<LeaderboardEntry>> fetchTopLeaderboard(
    String contestId, {
    int limit = 10,
  }) async {
    await _simulateLatency();
    final list = _leaderboards[contestId] ?? const <LeaderboardEntry>[];
    return list.take(limit).toList(growable: false);
  }

  Future<List<MyContestEntry>> fetchMyEntries() async {
    await _simulateLatency();
    final list = _myEntries.values.toList()
      ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    return List.unmodifiable(list);
  }

  Future<MyContestEntry?> fetchMyEntryForContest(String contestId) async {
    await _simulateLatency();
    return _myEntries[contestId];
  }

  Future<MyContestEntry> joinContest(String contestId) async {
    await _simulateLatency(minMs: 400, maxMs: 900);
    final contest = _contests.firstWhere(
      (c) => c.id == contestId,
      orElse: () => throw StateError('Contest $contestId not found'),
    );

    if (!contest.acceptingEntries) {
      throw StateError('Contest is not accepting entries');
    }

    if (_myEntries.containsKey(contestId)) {
      return _myEntries[contestId]!;
    }

    final entry = MyContestEntry(
      contestId: contest.id,
      contestTitle: contest.title,
      contestSubtitle: contest.subtitle,
      status: ContestEntryStatus.registered,
      joinedAt: DateTime.now(),
      endsAt: contest.endsAt,
      startingBalance: contest.startingBalance,
      equity: contest.startingBalance,
      pnl: 0,
      pnlPercent: 0,
      rank: contest.joinedParticipants + 1,
      totalParticipants: contest.maxParticipants,
      tradesCount: 0,
      winRate: 0,
      currency: contest.currency,
      hasWithdrawableReward: false,
    );
    _myEntries[contest.id] = entry;
    return entry;
  }

  Future<List<ContestWinner>> fetchWinners({
    int limit = 25,
  }) async {
    await _simulateLatency();
    return _winners.take(limit).toList(growable: false);
  }

  // ─────────────────────────── helpers ───────────────────────────

  Future<void> _simulateLatency({
    int minMs = 300,
    int maxMs = 700,
  }) async {
    final ms = minMs + Random().nextInt(max(1, maxMs - minMs));
    await Future.delayed(Duration(milliseconds: ms));
  }
}

// ───────────────────────────── Internals ─────────────────────────────

extension _IterableFirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

List<DemoContest> _seedContests() {
  final now = DateTime.now();

  return <DemoContest>[
    // 1. Active / live contest the user is currently in.
    DemoContest(
      id: 'wkly-feb-2026',
      title: 'Weekly Trading Showdown',
      subtitle: 'Feb 2026 · Weekly Round',
      description:
          'Trade the most volatile pairs this week for a chance to share in \$20,000 prize pool. '
              'Lowest drawdown wins — consistency is rewarded.',
      bannerEmoji: '🏆',
      startingBalance: 10000,
      currency: 'USD',
      maxParticipants: 2500,
      joinedParticipants: 1872,
      startsAt: now.subtract(const Duration(days: 3)),
      endsAt: now.add(const Duration(days: 4, hours: 7)),
      status: ContestStatus.active,
      entryFee: 0,
      prizes: const [
        ContestPrize(
          label: '1st Place',
          amount: 6000,
          extra: 'Cash + Pro account upgrade',
        ),
        ContestPrize(label: '2nd Place', amount: 4000),
        ContestPrize(label: '3rd Place', amount: 2000),
        ContestPrize(label: 'Top 10', amount: 500),
        ContestPrize(label: 'Top 50', amount: 100),
      ],
      rules: const [
        ContestRule(
          title: 'Demo Account Required',
          description:
              'A demo MT5 account will be opened for you with \$10,000 virtual balance.',
        ),
        ContestRule(
          title: 'Trading Instruments',
          description:
              'Forex majors, minors and top 10 metals/indices are eligible. Crypto not included.',
        ),
        ContestRule(
          title: 'Leverage Cap',
          description:
              'Maximum effective leverage is 1:100. Higher leverage will disqualify the entry.',
        ),
        ContestRule(
          title: 'Minimum Trades',
          description:
              'At least 5 closed trades during the contest window are required to qualify for prizes.',
        ),
        ContestRule(
          title: 'Ranking Metric',
          description:
              'Ranked by % profit with daily drawdown as tiebreaker.',
        ),
        ContestRule(
          title: 'One Entry Per User',
          description: 'Multiple aliases or linked accounts will be removed.',
        ),
      ],
      requirements: const [
        'Verified email & phone',
        'Active demo MT5 account',
        'Accept contest terms',
      ],
      acceptingEntries: true,
    ),

    // 2. Upcoming contest starting in a few days.
    DemoContest(
      id: 'monthly-mar-2026',
      title: 'Monthly Championship',
      subtitle: 'Mar 2026 · Monthly Round',
      description:
          'Compete against thousands of traders for the biggest prize pool of the month — '
              '\$50,000 split among the top 100.',
      bannerEmoji: '🥇',
      startingBalance: 25000,
      currency: 'USD',
      maxParticipants: 5000,
      joinedParticipants: 932,
      startsAt: now.add(const Duration(days: 6, hours: 12)),
      endsAt: now.add(const Duration(days: 34)),
      status: ContestStatus.upcoming,
      entryFee: 0,
      prizes: const [
        ContestPrize(
          label: '1st Place',
          amount: 15000,
          extra: 'Cash + featured master status',
        ),
        ContestPrize(label: '2nd Place', amount: 10000),
        ContestPrize(label: '3rd Place', amount: 6000),
        ContestPrize(label: 'Top 10', amount: 1500),
        ContestPrize(label: 'Top 100', amount: 200),
      ],
      rules: const [
        ContestRule(
          title: 'Higher Starting Balance',
          description: 'Each participant receives \$25,000 demo balance.',
        ),
        ContestRule(
          title: 'All Instruments',
          description: 'Forex, metals, indices and energies are eligible.',
        ),
        ContestRule(
          title: 'Max Effective Leverage',
          description: 'Capped at 1:200.',
        ),
        ContestRule(
          title: 'Minimum Trades',
          description: 'At least 25 closed trades required.',
        ),
      ],
      requirements: const [
        'Verified email & phone',
        'KYC verified or skip KYC demo participation',
        'Accept contest terms',
      ],
      acceptingEntries: true,
    ),

    // 3. Ended contest that the user participated in (in history).
    DemoContest(
      id: 'weekend-jan-2026',
      title: 'Weekend Sprint',
      subtitle: 'Jan 2026 · Weekend Round',
      description:
          '48-hour sprint for the most aggressive day traders. Prize pool \$5,000.',
      bannerEmoji: '⚡',
      startingBalance: 5000,
      currency: 'USD',
      maxParticipants: 1000,
      joinedParticipants: 1000,
      startsAt: now.subtract(const Duration(days: 28)),
      endsAt: now.subtract(const Duration(days: 26)),
      status: ContestStatus.ended,
      entryFee: 0,
      prizes: const [
        ContestPrize(label: '1st Place', amount: 1500),
        ContestPrize(label: '2nd Place', amount: 1000),
        ContestPrize(label: '3rd Place', amount: 500),
        ContestPrize(label: 'Top 20', amount: 100),
      ],
      rules: const [
        ContestRule(
          title: 'Short Duration',
          description: '48 hours. Trade fast.',
        ),
        ContestRule(
          title: 'Starting Balance',
          description: '\$5,000 demo balance per participant.',
        ),
      ],
      requirements: const [
        'Verified email',
        'Accept contest terms',
      ],
      acceptingEntries: false,
    ),
  ];
}

Map<String, List<LeaderboardEntry>> _seedLeaderboards() {
  // Pseudo-random but stable seed so the user always sees the same data
  // between restarts during demos.
  final rand = Random(42);

  List<LeaderboardEntry> build(int count, {required bool currentUserInside}) {
    final entries = <LeaderboardEntry>[];
    double previousPercent = 95; // top winner
    for (var i = 0; i < count; i++) {
      final rank = i + 1;
      final countryIndex = rand.nextInt(countries.length);
      final tradeCount = 25 + rand.nextInt(120);
      final winRate = 0.45 + rand.nextDouble() * 0.4;
      final pnlPercent =
          (previousPercent * (0.85 + rand.nextDouble() * 0.12)).clamp(2.0, 200.0);
      final pnl = 10000 * pnlPercent / 100;
      final equity = 10000 + pnl;
      entries.add(
        LeaderboardEntry(
          rank: rank,
          userId: 'u_${rank}_${rand.nextInt(99999)}',
          displayName:
              '${sampleNames[rank % sampleNames.length]} ${(100 + rank).toString()}',
          countryCode: countries[countryIndex],
          equity: equity,
          pnl: pnl,
          pnlPercent: pnlPercent,
          tradesCount: tradeCount,
          winRate: winRate,
          isCurrentUser:
              currentUserInside && rank == currentUserRank,
          isTop3: rank <= 3,
        ),
      );
      previousPercent = pnlPercent;
    }
    return entries;
  }

  return {
    'wkly-feb-2026': build(120, currentUserInside: true),
    'monthly-mar-2026': build(0, currentUserInside: false),
    'weekend-jan-2026': build(120, currentUserInside: false),
  };
}

const currentUserRank = 47;

const countries = <String>[
  'GB', 'DE', 'FR', 'ES', 'IT', 'IN', 'PK', 'AE', 'SA', 'EG',
  'BR', 'AR', 'US', 'CA', 'MX', 'NG', 'KE', 'ZA', 'AU', 'NZ',
  'SG', 'MY', 'TH', 'VN', 'PH', 'ID', 'JP', 'KR', 'CN', 'HK',
  'TR', 'RU', 'UA', 'PL', 'NL', 'SE', 'NO', 'FI', 'CH', 'AT',
];

const sampleNames = <String>[
  'Trader', 'Pro', 'Master', 'Alpha', 'Bull', 'Wolf', 'Eagle', 'Shark',
  'Tiger', 'Phoenix', 'Falcon', 'Knight', 'Quant', 'Edge', 'Vortex',
  'Apex', 'Nova', 'Astro', 'Zen', 'Storm',
];

Map<String, MyContestEntry> _seedMyEntries() {
  final now = DateTime.now();
  return {
    'wkly-feb-2026': MyContestEntry(
      contestId: 'wkly-feb-2026',
      contestTitle: 'Weekly Trading Showdown',
      contestSubtitle: 'Feb 2026 · Weekly Round',
      status: ContestEntryStatus.running,
      joinedAt: now.subtract(const Duration(days: 3)),
      endsAt: now.add(const Duration(days: 4, hours: 7)),
      startingBalance: 10000,
      equity: 10984.32,
      pnl: 984.32,
      pnlPercent: 9.84,
      rank: 47,
      totalParticipants: 1872,
      tradesCount: 18,
      winRate: 0.61,
      currency: 'USD',
      hasWithdrawableReward: false,
    ),
    'weekend-jan-2026': MyContestEntry(
      contestId: 'weekend-jan-2026',
      contestTitle: 'Weekend Sprint',
      contestSubtitle: 'Jan 2026 · Weekend Round',
      status: ContestEntryStatus.finished,
      joinedAt: now.subtract(const Duration(days: 28)),
      endsAt: now.subtract(const Duration(days: 26)),
      startingBalance: 5000,
      equity: 5320.50,
      pnl: 320.50,
      pnlPercent: 6.41,
      rank: 31,
      totalParticipants: 1000,
      tradesCount: 12,
      winRate: 0.67,
      prizeAmount: null,
      currency: 'USD',
      hasWithdrawableReward: false,
    ),
  };
}

List<ContestWinner> _seedWinners() {
  final rand = Random(11);
  final now = DateTime.now();

  String flag(String code) {
    if (code.length != 2) return '🏳️';
    const base = 0x1F1E6;
    final first =
        code.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0);
    final second =
        code.toUpperCase().codeUnitAt(1) - 'A'.codeUnitAt(0);
    if (first < 0 || first > 25 || second < 0 || second > 25) return '🏳️';
    return String.fromCharCode(base + first) +
        String.fromCharCode(base + second);
  }

  String mask(String name) {
    if (name.length <= 2) return name;
    final first = name.substring(0, 1);
    final last = name.substring(name.length - 1);
    return '$first***$last';
  }

  final showcases = <ContestWinner>[];
  for (var c = 0; c < 3; c++) {
    final contestId = 'past-contest-$c';
    final contestTitle = c == 0
        ? 'Championship Cup 2025'
        : c == 1
            ? 'Q4 Masters League'
            : 'November Sprint';
    final endedAt = now.subtract(Duration(days: 30 + c * 30));
    for (var r = 1; r <= 10; r++) {
      final cn = countries[rand.nextInt(countries.length)];
      final name =
          mask('${sampleNames[(r + c) % sampleNames.length]} ${100 + r}');
      showcases.add(
        ContestWinner(
          contestId: contestId,
          contestTitle: contestTitle,
          rank: r,
          displayName: '$flag ${name.substring(3)}',
          countryCode: cn,
          pnlPercent: (95 - (r - 1) * 6.5 + rand.nextDouble() * 4)
              .clamp(8.0, 99.0),
          prizeAmount: (1500 / r).roundToDouble(),
          currency: 'USD',
          endedAt: endedAt,
        ),
      );
    }
  }
  return showcases;
}