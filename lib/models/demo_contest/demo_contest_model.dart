/// Demo Contest domain models.
///
/// The `DemoContest` represents a virtual trading contest where users
/// trade on a demo MT5 account and are ranked by P&L, win rate and
/// consistency. These models are designed to be small and serialization
/// friendly so the mock service and any future real API integration can
/// share the same shapes.
library;

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
    return ContestPrize(
      label: json['label']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      extra: json['extra']?.toString(),
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
    return DemoContest(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      bannerEmoji: json['bannerEmoji']?.toString() ?? '🏆',
      startingBalance:
          (json['starting_balance'] as num?)?.toDouble() ?? 10000,
      currency: json['currency']?.toString() ?? 'USD',
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 0,
      joinedParticipants:
          (json['joined_participants'] as num?)?.toInt() ?? 0,
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? '') ??
          DateTime.now(),
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      status: ContestStatus.values.firstWhere(
        (s) => s.name == (json['status']?.toString() ?? 'upcoming'),
        orElse: () => ContestStatus.upcoming,
      ),
      entryFee: (json['entry_fee'] as num?)?.toDouble() ?? 0,
      prizes: (json['prizes'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ContestPrize.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      rules: (json['rules'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ContestRule.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      requirements: (json['requirements'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      acceptingEntries: json['accepting_entries'] as bool? ?? false,
    );
  }
}