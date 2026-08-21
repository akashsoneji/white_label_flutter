/// Demo Contest domain models.
///
/// The `DemoContest` represents a virtual trading contest where users
/// trade on a demo MT5 account and are ranked by P&L, win rate and
/// consistency. These models are designed to be small and serialization
/// friendly so the mock service and any future real API integration can
/// share the same shapes.
library;

import 'contest_participant_model.dart';

enum ContestStatus {
  upcoming,
  active,
  ended,
}

enum ContestEntryStatus {
  notJoined,
  registered,
  running,
  finished,
  winner,
}

/// One prize bucket for a contest. A contest usually has multiple
/// tiers (1st, 2nd, 3rd, top-10, best newcomer, etc.).
class ContestPrize {
  final String label;
  final double amount;
  final String currency;
  final String? extra;

  const ContestPrize({
    required this.label,
    required this.amount,
    this.currency = 'USD',
    this.extra,
  });
  factory ContestPrize.fromJson(Map<String, dynamic> json) {
    String labelText = json['label']?.toString() ?? '';
    if (labelText.isEmpty) {
      final rMin = json['rank_min']?.toString() ?? '';
      final rMax = json['rank_max']?.toString() ?? '';
      if (rMin.isNotEmpty && rMin == rMax) {
        labelText = rMin == '1' ? '1st' : rMin == '2' ? '2nd' : rMin == '3' ? '3rd' : '${rMin}th';
      } else if (rMin.isNotEmpty) {
        labelText = '$rMin - $rMax';
      }
    }

    return ContestPrize(
      label: labelText,
      amount: (json['amount'] as num?)?.toDouble() ?? (json['prize_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      extra: json['extra']?.toString() ?? json['prize_type']?.toString(),
    );
  }
}

/// Static, mostly documentation-style rules shown in the Contest Rules
/// screen. Kept as a list so we can render bullet points.
class ContestRule {
  final String title;
  final String description;
  const ContestRule({required this.title, required this.description});

  factory ContestRule.fromJson(Map<String, dynamic> json) {
    return ContestRule(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}

/// The main contest definition.
class DemoContest {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String bannerEmoji; // glyph used in the hero card (no image asset required)

  /// Starting virtual balance for each contest MT5 account, e.g. 10000.
  final double startingBalance;
  final String currency;
  final int maxParticipants;
  final int joinedParticipants;

  final DateTime startsAt;
  final DateTime endsAt;
  final ContestStatus status;

  final double entryFee; // typically 0 for demo contests
  final List<ContestPrize> prizes;
  final List<ContestRule> rules;

  /// Free-text requirements shown on the Join screen (one per bullet).
  final List<String> requirements;

  /// Whether the user can join right now. False for ended contests.
  final bool acceptingEntries;
  final bool isEnrolled;
  final int daysLeft;
  final int myEnrollmentsCount;
  final int maxParticipations;
  final bool canParticipateAgain;
  final bool isUpcoming;
  final bool isEnded;
  final String tradingMaxLeverage;
  final String rankingBy;
  final String enrollmentType;
  final bool enrollmentStepsEnabled;
  final bool termsEnabled;
  final Map<String, dynamic>? pool;
  final ContestParticipantModel? participant;

  const DemoContest({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    this.bannerEmoji = '🏆',
    required this.startingBalance,
    this.currency = 'USD',
    required this.maxParticipants,
    required this.joinedParticipants,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.entryFee = 0,
    required this.prizes,
    required this.rules,
    required this.requirements,
    required this.acceptingEntries,
    this.isEnrolled = false,
    this.daysLeft = 0,
    this.myEnrollmentsCount = 0,
    this.maxParticipations = 0,
    this.canParticipateAgain = false,
    this.isUpcoming = false,
    this.isEnded = false,
    this.tradingMaxLeverage = '',
    this.rankingBy = '',
    this.enrollmentType = 'free',
    this.enrollmentStepsEnabled = false,
    this.termsEnabled = false,
    this.pool,
    this.participant,
  });

  Duration get remaining {
    final now = DateTime.now();
    if (now.isBefore(startsAt)) return startsAt.difference(now);
    if (now.isBefore(endsAt)) return endsAt.difference(now);
    return Duration.zero;
  }

  Duration get totalDuration => endsAt.difference(startsAt);

  double get filledPercent {
    if (maxParticipants <= 0) return 0;
    return (joinedParticipants.toDouble() / maxParticipants.toDouble())
        .clamp(0.0, 1.0);
  }

  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(startsAt) && now.isBefore(endsAt);
  }

  bool get hasStarted => DateTime.now().isAfter(startsAt);
  bool get hasEnded => DateTime.now().isAfter(endsAt);

  factory DemoContest.fromJson(Map<String, dynamic> json) {
    final contestJson = json['contest'] is Map ? json['contest'] as Map<String, dynamic> : json;

    final rawRules = (contestJson['rules'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ContestRule.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    if (rawRules.isEmpty) {
      final leverage = contestJson['trading_max_leverage']?.toString();
      final duration = contestJson['trading_min_trade_duration_seconds'];
      final maxPositions = contestJson['trading_max_open_positions'];
      final allowedInstruments = contestJson['trading_allowed_instruments']?.toString();
      final maxLots = contestJson['trading_max_lots_per_trade'];
      final tz = contestJson['timezone']?.toString();

      if (leverage != null && leverage.isNotEmpty) {
        rawRules.add(ContestRule(title: 'Max Leverage', description: leverage));
      }
      if (duration != null) {
        final durationMin = (duration is num) ? (duration / 60).round() : duration;
        rawRules.add(ContestRule(title: 'Min Trade Duration', description: '$durationMin min'));
      }
      if (maxPositions != null) {
        rawRules.add(ContestRule(title: 'Max Open Positions', description: '$maxPositions'));
      }
      if (allowedInstruments != null && allowedInstruments.isNotEmpty) {
        rawRules.add(ContestRule(
          title: 'Allowed Instruments',
          description: allowedInstruments.toLowerCase() == 'all' ? 'All Instruments' : allowedInstruments,
        ));
      }
      if (maxLots != null) {
        final lotsNum = (maxLots is num) ? maxLots : double.tryParse(maxLots.toString());
        final lotsStr = lotsNum != null ? (lotsNum == lotsNum.toInt() ? '${lotsNum.toInt()}' : '$lotsNum') : '$maxLots';
        rawRules.add(ContestRule(title: 'Max Lots Per Trade', description: lotsStr));
      }
      if (tz != null && tz.isNotEmpty) {
        rawRules.add(ContestRule(title: 'Timezone', description: tz));
      }
    }

    return DemoContest(
      id: contestJson['id']?.toString() ?? '',
      title: contestJson['name']?.toString() ?? contestJson['title']?.toString() ?? '',
      subtitle: contestJson['tagline']?.toString() ?? contestJson['subtitle']?.toString() ?? '',
      description: contestJson['terms_content']?.toString() ?? contestJson['description']?.toString() ?? '',
      bannerEmoji: contestJson['bannerEmoji']?.toString() ?? '🏆',
      startingBalance:
          (contestJson['starting_balance'] as num?)?.toDouble() ?? 10000,
      currency: contestJson['currency']?.toString() ?? 'USD',
      maxParticipants: (contestJson['max_participants'] as num?)?.toInt() ?? 0,
      joinedParticipants:
          (contestJson['joined_participants'] as num?)?.toInt() ??
          (contestJson['pool']?['total_participants'] as num?)?.toInt() ?? 0,
      startsAt: DateTime.tryParse(contestJson['start_date']?.toString() ?? contestJson['starts_at']?.toString() ?? '') ??
          DateTime.now(),
      endsAt: DateTime.tryParse(contestJson['end_date']?.toString() ?? contestJson['ends_at']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      status: ContestStatus.values.firstWhere(
        (s) => s.name == (contestJson['status']?.toString() ?? 'upcoming'),
        orElse: () => ContestStatus.upcoming,
      ),
      entryFee: (contestJson['enrollment_fee'] as num?)?.toDouble() ?? (contestJson['entry_fee'] as num?)?.toDouble() ?? 0,
      prizes: (contestJson['prizes'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ContestPrize.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      rules: rawRules,
      requirements: (contestJson['requirements'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      acceptingEntries: json['registration_open'] as bool? ?? contestJson['accepting_entries'] as bool? ?? false,
      isEnrolled: json['is_enrolled'] as bool? ?? false,
      daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
      myEnrollmentsCount: (json['my_enrollments_count'] as num?)?.toInt() ?? 0,
      maxParticipations: (json['max_participations'] as num?)?.toInt() ?? 0,
      canParticipateAgain: json['can_participate_again'] as bool? ?? false,
      isUpcoming: json['is_upcoming'] as bool? ?? false,
      isEnded: json['is_ended'] as bool? ?? false,
      tradingMaxLeverage: contestJson['trading_max_leverage']?.toString() ?? '',
      rankingBy: contestJson['ranking_by']?.toString() ?? '',
      enrollmentType: contestJson['enrollment_type']?.toString() ?? 'free',
      enrollmentStepsEnabled: contestJson['enrollment_steps_enabled'] == true,
      termsEnabled: contestJson['terms_enabled'] == true,
      pool: contestJson['pool'] as Map<String, dynamic>?,
      participant: json['participant'] != null ? ContestParticipantModel.fromJson(json['participant']) : null,
    );
  }
}