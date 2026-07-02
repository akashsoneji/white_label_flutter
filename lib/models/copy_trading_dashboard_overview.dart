import 'package:flutter/foundation.dart';

/// A simple time-series pair (labels + values) returned by the
/// `master/dashboard-overview` endpoint. Values are numeric (may be 0 for
/// days with no activity).
@immutable
class DashboardTimeSeries {
  final List<String> labels;
  final List<num> values;

  const DashboardTimeSeries({required this.labels, required this.values});

  factory DashboardTimeSeries.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DashboardTimeSeries(labels: [], values: []);
    final rawLabels = (json['labels'] as List?) ?? const [];
    final rawValues = (json['values'] as List?) ?? const [];
    return DashboardTimeSeries(
      labels: rawLabels.map((e) => e?.toString() ?? '').toList(),
      values: rawValues
          .map((e) => e is num ? e : num.tryParse(e?.toString() ?? '') ?? 0)
          .toList(),
    );
  }

  bool get isEmpty => values.isEmpty || values.every((v) => v == 0);
  num get maxValue =>
      values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
  num get minValue =>
      values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b);
}

/// `data.range` from the dashboard-overview response.
@immutable
class DashboardRange {
  final String from;
  final String to;
  final String preset;

  const DashboardRange({
    required this.from,
    required this.to,
    required this.preset,
  });

  factory DashboardRange.fromJson(Map<String, dynamic>? json) {
    return DashboardRange(
      from: (json?['from'] ?? '').toString(),
      to: (json?['to'] ?? '').toString(),
      preset: (json?['preset'] ?? '').toString(),
    );
  }
}

/// Hero: AUM (Assets Under Management).
@immutable
class DashboardHeroAum {
  final num current;
  final num previous;
  final num deltaPct;
  final DashboardTimeSeries series;

  const DashboardHeroAum({
    required this.current,
    required this.previous,
    required this.deltaPct,
    required this.series,
  });

  factory DashboardHeroAum.fromJson(Map<String, dynamic>? json) {
    num toNum(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return DashboardHeroAum(
      current: toNum(json?['current']),
      previous: toNum(json?['previous']),
      deltaPct: toNum(json?['delta_pct']),
      series: DashboardTimeSeries.fromJson(
        (json?['series'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

/// Hero: Copiers (count + net delta in window).
@immutable
class DashboardHeroCopiers {
  final int current;
  final int delta;
  final DashboardTimeSeries series;

  const DashboardHeroCopiers({
    required this.current,
    required this.delta,
    required this.series,
  });

  factory DashboardHeroCopiers.fromJson(Map<String, dynamic>? json) {
    return DashboardHeroCopiers(
      current: (json?['current'] ?? 0) is num
          ? (json?['current'] as num).toInt()
          : int.tryParse(json?['current']?.toString() ?? '') ?? 0,
      delta: (json?['delta'] ?? 0) is num
          ? (json?['delta'] as num).toInt()
          : int.tryParse(json?['delta']?.toString() ?? '') ?? 0,
      series: DashboardTimeSeries.fromJson(
        (json?['series'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

/// Hero: Earnings (commission) + next payout hint.
@immutable
class DashboardHeroEarnings {
  final num current;
  final num previous;
  final num deltaPct;
  final num nextPayoutAmount;
  final String nextPayoutDate;
  final DashboardTimeSeries series;

  const DashboardHeroEarnings({
    required this.current,
    required this.previous,
    required this.deltaPct,
    required this.nextPayoutAmount,
    required this.nextPayoutDate,
    required this.series,
  });

  factory DashboardHeroEarnings.fromJson(Map<String, dynamic>? json) {
    num toNum(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return DashboardHeroEarnings(
      current: toNum(json?['current']),
      previous: toNum(json?['previous']),
      deltaPct: toNum(json?['delta_pct']),
      nextPayoutAmount: toNum(json?['next_payout_amount']),
      nextPayoutDate: (json?['next_payout_date'] ?? '').toString(),
      series: DashboardTimeSeries.fromJson(
        (json?['series'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

/// Hero: ROI (percentage).
@immutable
class DashboardHeroRoi {
  final num currentPct;
  final num previousPct;
  final String benchmarkPct;
  final DashboardTimeSeries series;

  const DashboardHeroRoi({
    required this.currentPct,
    required this.previousPct,
    required this.benchmarkPct,
    required this.series,
  });

  factory DashboardHeroRoi.fromJson(Map<String, dynamic>? json) {
    num toNum(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return DashboardHeroRoi(
      currentPct: toNum(json?['current_pct']),
      previousPct: toNum(json?['previous_pct']),
      benchmarkPct: (json?['benchmark_pct'] ?? '').toString(),
      series: DashboardTimeSeries.fromJson(
        (json?['series'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

/// Hero block: aum / copiers / earnings / roi.
@immutable
class DashboardHero {
  final DashboardHeroAum aum;
  final DashboardHeroCopiers copiers;
  final DashboardHeroEarnings earnings;
  final DashboardHeroRoi roi;

  const DashboardHero({
    required this.aum,
    required this.copiers,
    required this.earnings,
    required this.roi,
  });

  factory DashboardHero.fromJson(Map<String, dynamic>? json) {
    return DashboardHero(
      aum: DashboardHeroAum.fromJson(
        (json?['aum'] as Map?)?.cast<String, dynamic>(),
      ),
      copiers: DashboardHeroCopiers.fromJson(
        (json?['copiers'] as Map?)?.cast<String, dynamic>(),
      ),
      earnings: DashboardHeroEarnings.fromJson(
        (json?['earnings'] as Map?)?.cast<String, dynamic>(),
      ),
      roi: DashboardHeroRoi.fromJson(
        (json?['roi'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

/// Main performance overview chart (equity / aum / net_pnl time series).
@immutable
class DashboardMainChart {
  final List<String> labels;
  final List<num> equity;
  final List<num> aum;
  final List<num> netPnl;

  const DashboardMainChart({
    required this.labels,
    required this.equity,
    required this.aum,
    required this.netPnl,
  });

  factory DashboardMainChart.fromJson(Map<String, dynamic>? json) {
    List<num> nums(List<dynamic>? raw) {
      return (raw ?? const []).map((e) {
        if (e is num) return e;
        return num.tryParse(e?.toString() ?? '') ?? 0;
      }).toList();
    }

    List<String> labels(List<dynamic>? raw) {
      return (raw ?? const []).map((e) => e?.toString() ?? '').toList();
    }

    return DashboardMainChart(
      labels: labels(json?['labels'] as List?),
      equity: nums(json?['equity'] as List?),
      aum: nums(json?['aum'] as List?),
      netPnl: nums(json?['net_pnl'] as List?),
    );
  }

  bool get isEmpty => equity.isEmpty && aum.isEmpty && netPnl.isEmpty;

  num get maxValue {
    num m = 0;
    for (final v in equity) {
      if (v > m) m = v;
    }
    for (final v in aum) {
      if (v > m) m = v;
    }
    for (final v in netPnl) {
      if (v > m) m = v;
    }
    return m;
  }

  num get minValue {
    if (isEmpty) return 0;
    num m = equity.isNotEmpty ? equity.first : 0;
    for (final v in equity) {
      if (v < m) m = v;
    }
    for (final v in aum) {
      if (v < m) m = v;
    }
    for (final v in netPnl) {
      if (v < m) m = v;
    }
    return m < 0 ? m : 0;
  }
}

/// Copier health summary (active / paused / stopped + churn / new / retention).
@immutable
class DashboardCopierHealth {
  final int active;
  final int paused;
  final int stopped;
  final int churnedInWindow;
  final int newInWindow;
  final int avgAgeDays;
  final num retentionPct;

  const DashboardCopierHealth({
    required this.active,
    required this.paused,
    required this.stopped,
    required this.churnedInWindow,
    required this.newInWindow,
    required this.avgAgeDays,
    required this.retentionPct,
  });

  factory DashboardCopierHealth.fromJson(Map<String, dynamic>? json) {
    num toNum(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return DashboardCopierHealth(
      active: toInt(json?['active']),
      paused: toInt(json?['paused']),
      stopped: toInt(json?['stopped']),
      churnedInWindow: toInt(json?['churned_in_window']),
      newInWindow: toInt(json?['new_in_window']),
      avgAgeDays: toInt(json?['avg_age_days']),
      retentionPct: toNum(json?['retention_pct']),
    );
  }

  int get total => active + paused + stopped;
}

/// Sparkline embedded in each plan card.
@immutable
class DashboardPlanSparkline {
  final List<String> labels;
  final List<num> values;

  const DashboardPlanSparkline({required this.labels, required this.values});

  factory DashboardPlanSparkline.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DashboardPlanSparkline(labels: [], values: []);
    }
    final rawLabels = (json['labels'] as List?) ?? const [];
    final rawValues = (json['values'] as List?) ?? const [];
    return DashboardPlanSparkline(
      labels: rawLabels.map((e) => e?.toString() ?? '').toList(),
      values: rawValues
          .map((e) => e is num ? e : num.tryParse(e?.toString() ?? '') ?? 0)
          .toList(),
    );
  }

  bool get isEmpty => values.isEmpty || values.every((v) => v == 0);
  num get lastValue => values.isEmpty ? 0 : values.last;
}

/// A single plan summary row in the overview.
@immutable
class DashboardPlanRow {
  final int id;
  final String planName;
  final String tradingAccountNumber;
  final String tradingServer;
  final String lpProviderName;
  final String serverType;
  final String commissionType;
  final String commissionLabel;
  final num commissionPercentage;
  final num subscriptionFee;
  final int subscriptionPeriodDays;
  final String settlementCycle;
  final String lastSettledAt;
  final int noFeeDays;
  final String strategyDescription;
  final String riskInformation;
  final num minimumCapital;
  final num copyRatio;
  final String? maxCopiers;
  final int activeCopiersCount;
  final num totalCapital;
  final num roiPct;
  final bool isFull;
  final String status;
  final bool copyingPaused;
  final String copyingPausedAt;
  final String createdAt;
  final DashboardPlanSparkline sparkline;

  const DashboardPlanRow({
    required this.id,
    required this.planName,
    required this.tradingAccountNumber,
    required this.tradingServer,
    required this.lpProviderName,
    required this.serverType,
    required this.commissionType,
    required this.commissionLabel,
    required this.commissionPercentage,
    required this.subscriptionFee,
    required this.subscriptionPeriodDays,
    required this.settlementCycle,
    required this.lastSettledAt,
    required this.noFeeDays,
    required this.strategyDescription,
    required this.riskInformation,
    required this.minimumCapital,
    required this.copyRatio,
    required this.maxCopiers,
    required this.activeCopiersCount,
    required this.totalCapital,
    required this.roiPct,
    required this.isFull,
    required this.status,
    required this.copyingPaused,
    required this.copyingPausedAt,
    required this.createdAt,
    required this.sparkline,
  });

  factory DashboardPlanRow.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    int toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    return DashboardPlanRow(
      id: toInt(json['id']),
      planName: (json['plan_name'] ?? '').toString(),
      tradingAccountNumber: (json['trading_account_number'] ?? '').toString(),
      tradingServer: (json['trading_server'] ?? '').toString(),
      lpProviderName: (json['lp_provider_name'] ?? '').toString(),
      serverType: (json['server_type'] ?? '').toString(),
      commissionType: (json['commission_type'] ?? '').toString(),
      commissionLabel: (json['commission_label'] ?? '').toString(),
      commissionPercentage: toNum(json['commission_percentage']),
      subscriptionFee: toNum(json['subscription_fee']),
      subscriptionPeriodDays: toInt(json['subscription_period_days']),
      settlementCycle: (json['settlement_cycle'] ?? '').toString(),
      lastSettledAt: (json['last_settled_at'] ?? '').toString(),
      noFeeDays: toInt(json['no_fee_days']),
      strategyDescription: (json['strategy_description'] ?? '').toString(),
      riskInformation: (json['risk_information'] ?? '').toString(),
      minimumCapital: toNum(json['minimum_capital']),
      copyRatio: toNum(json['copy_ratio']),
      maxCopiers: json['max_copiers']?.toString(),
      activeCopiersCount: toInt(json['active_copiers_count']),
      totalCapital: toNum(json['total_capital']),
      roiPct: toNum(json['roi_pct']),
      isFull: json['is_full'] == true,
      status: (json['status'] ?? '').toString(),
      copyingPaused: json['copying_paused'] == true,
      copyingPausedAt: (json['copying_paused_at'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      sparkline: DashboardPlanSparkline.fromJson(
        (json['sparkline'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

/// Single payout row inside `payouts.recent` or `payouts.upcoming`.
@immutable
class DashboardPayoutItem {
  final num amount;
  final String date;
  final String status;

  const DashboardPayoutItem({
    required this.amount,
    required this.date,
    required this.status,
  });

  factory DashboardPayoutItem.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return DashboardPayoutItem(
      amount: toNum(json['amount']),
      date: (json['date'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

/// Payouts block (upcoming + recent + summary).
@immutable
class DashboardPayouts {
  final List<DashboardPayoutItem> upcoming;
  final List<DashboardPayoutItem> recent;
  final num earnedInWindow;
  final num pending;

  const DashboardPayouts({
    required this.upcoming,
    required this.recent,
    required this.earnedInWindow,
    required this.pending,
  });

  factory DashboardPayouts.fromJson(Map<String, dynamic>? json) {
    num toNum(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    List<DashboardPayoutItem> list(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => DashboardPayoutItem.fromJson(m.cast<String, dynamic>()))
          .toList();
    }

    return DashboardPayouts(
      upcoming: list(json?['upcoming']),
      recent: list(json?['recent']),
      earnedInWindow: toNum(json?['earned_in_window']),
      pending: toNum(json?['pending']),
    );
  }
}

/// Single trade row inside `recent_trades`.
@immutable
class DashboardRecentTrade {
  final String ts;
  final String symbol;
  final String side;
  final num lots;
  final num pnl;

  const DashboardRecentTrade({
    required this.ts,
    required this.symbol,
    required this.side,
    required this.lots,
    required this.pnl,
  });

  factory DashboardRecentTrade.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) =>
        v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return DashboardRecentTrade(
      ts: (json['ts'] ?? '').toString(),
      symbol: (json['symbol'] ?? '').toString(),
      side: (json['side'] ?? '').toString(),
      lots: toNum(json['lots']),
      pnl: toNum(json['pnl']),
    );
  }

  bool get isBuy => side.toUpperCase() == 'BUY';
  bool get isProfit => pnl > 0;
  bool get isLoss => pnl < 0;
}

/// Single alert row.
@immutable
class DashboardAlert {
  final String level;
  final String code;
  final String message;

  const DashboardAlert({
    required this.level,
    required this.code,
    required this.message,
  });

  factory DashboardAlert.fromJson(Map<String, dynamic> json) {
    return DashboardAlert(
      level: (json['level'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }
}

/// Top-level wrapper around `data` of `master/dashboard-overview`.
@immutable
class CopyTradingDashboardOverview {
  final DashboardRange range;
  final DashboardHero hero;
  final DashboardMainChart mainChart;
  final DashboardCopierHealth copierHealth;
  final List<DashboardPlanRow> plans;
  final DashboardPayouts payouts;
  final List<DashboardRecentTrade> recentTrades;
  final List<DashboardAlert> alerts;

  const CopyTradingDashboardOverview({
    required this.range,
    required this.hero,
    required this.mainChart,
    required this.copierHealth,
    required this.plans,
    required this.payouts,
    required this.recentTrades,
    required this.alerts,
  });

  factory CopyTradingDashboardOverview.fromJson(Map<String, dynamic> json) {
    List<DashboardPlanRow> plansList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => DashboardPlanRow.fromJson(m.cast<String, dynamic>()))
          .toList();
    }

    List<DashboardRecentTrade> tradesList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => DashboardRecentTrade.fromJson(m.cast<String, dynamic>()))
          .toList();
    }

    List<DashboardAlert> alertsList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => DashboardAlert.fromJson(m.cast<String, dynamic>()))
          .toList();
    }

    return CopyTradingDashboardOverview(
      range: DashboardRange.fromJson(
        (json['range'] as Map?)?.cast<String, dynamic>(),
      ),
      hero: DashboardHero.fromJson(
        (json['hero'] as Map?)?.cast<String, dynamic>(),
      ),
      mainChart: DashboardMainChart.fromJson(
        (json['main_chart'] as Map?)?.cast<String, dynamic>(),
      ),
      copierHealth: DashboardCopierHealth.fromJson(
        (json['copier_health'] as Map?)?.cast<String, dynamic>(),
      ),
      plans: plansList(json['plans']),
      payouts: DashboardPayouts.fromJson(
        (json['payouts'] as Map?)?.cast<String, dynamic>(),
      ),
      recentTrades: tradesList(json['recent_trades']),
      alerts: alertsList(json['alerts']),
    );
  }
}
