import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/pmam_service.dart';

/// Public "Fund Manager View" screen — opened by tapping a manager card on the
/// Explore Fund Managers screen. Hits three public endpoints:
///   GET /user/pmam/managers/{code}
///   GET /user/pmam/managers/{code}/open-positions?plan_id=...
///   GET /user/pmam/managers/{code}/trades?plan_id=...&per_page=9999
class PmamFundManagerViewScreen extends StatefulWidget {
  const PmamFundManagerViewScreen({super.key});

  @override
  State<PmamFundManagerViewScreen> createState() =>
      _PmamFundManagerViewScreenState();
}

class _PmamFundManagerViewScreenState extends State<PmamFundManagerViewScreen> {
  String _managerCode = '';

  bool _loadingProfile = true;
  bool _loadingTrades = false;
  bool _loadingOpen = false;

  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _selectedPlan;

  List<Map<String, dynamic>> _trades = [];
  List<Map<String, dynamic>> _openPositions = [];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is String) {
      _managerCode = args;
    } else if (args is Map && args['manager_code'] is String) {
      _managerCode = args['manager_code'] as String;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  // ── API ─────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    if (_managerCode.isEmpty) {
      setState(() => _loadingProfile = false);
      return;
    }
    setState(() => _loadingProfile = true);
    try {
      final resp = await PmamService.getManagerProfile(_managerCode);
      if (resp.success && resp.data is Map) {
        final root = Map<String, dynamic>.from(resp.data as Map);
        final data = (root['data'] is Map)
            ? Map<String, dynamic>.from(root['data'] as Map)
            : <String, dynamic>{};
        _profile = data;
        final plansRaw = data['plans'];
        _plans = (plansRaw is List)
            ? plansRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        _selectedPlan = _plans.isNotEmpty ? _plans.first : null;
        if (_selectedPlan != null) {
          _loadPlanData(_selectedPlan!);
        }
      }
    } catch (_) {
      // swallow — UI shows empty state
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadPlanData(Map<String, dynamic> plan) async {
    final planId = int.tryParse(plan['id'].toString()) ?? 0;
    if (planId == 0) return;
    setState(() {
      _loadingOpen = true;
      _loadingTrades = true;
      _openPositions = [];
      _trades = [];
    });
    try {
      final results = await Future.wait([
        PmamService.getManagerOpenPositions(
          managerCode: _managerCode,
          planId: planId,
        ),
        PmamService.getManagerTradesPublic(
          managerCode: _managerCode,
          planId: planId,
        ),
      ]);

      // Open positions
      final openResp = results[0];
      if (openResp.success && openResp.data is Map) {
        final root = Map<String, dynamic>.from(openResp.data as Map);
        final data = root['data'];
        if (data is List) {
          _openPositions = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      // Trades
      final tradesResp = results[1];
      if (tradesResp.success && tradesResp.data is Map) {
        final root = Map<String, dynamic>.from(tradesResp.data as Map);
        final data = root['data'];
        if (data is Map) {
          final rows = data['trades'];
          if (rows is List) {
            _trades = rows
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        } else if (data is List) {
          _trades = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (_) {
      // swallow
    } finally {
      if (mounted) {
        setState(() {
          _loadingOpen = false;
          _loadingTrades = false;
        });
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String get _initials {
    final name = (_profile['manager_name'] ?? '').toString().trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  String _money(double v) {
    if (v.abs() >= 1000000) return '\$${(v / 1000000).toStringAsFixed(2)}M';
    if (v.abs() >= 1000) return '\$${(v / 1000).toStringAsFixed(2)}K';
    return '\$${v.toStringAsFixed(2)}';
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Fund Manager',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loadingProfile
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _profile.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadProfile,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
                    children: [
                      _buildHeader(),
                      SizedBox(height: 12.h),
                      _buildSummaryStrip(),
                      SizedBox(height: 16.h),
                      _buildSectionTitle('Plans'),
                      SizedBox(height: 8.h),
                      ..._plans.map(_buildPlanCard),
                      SizedBox(height: 16.h),
                      _buildSectionTitle('Performance Summary'),
                      SizedBox(height: 8.h),
                      _buildPerformanceCard(),
                      SizedBox(height: 16.h),
                      _buildSectionTitle(
                        'Open Positions',
                        trailing: _selectedPlan == null
                            ? null
                            : Text(
                                _selectedPlan?['plan_name']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.textGrey,
                                ),
                              ),
                      ),
                      SizedBox(height: 8.h),
                      _buildOpenPositions(),
                      SizedBox(height: 16.h),
                      _buildSectionTitle('Trade History',
                          trailing: Text(
                            '${_trades.length}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )),
                      SizedBox(height: 8.h),
                      _buildTradesList(),
                    ],
                  ),
                ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    final name = (_profile['manager_name'] ?? '—').toString();
    final email = (_profile['manager_email'] ?? '').toString();
    final since = (_profile['member_since'] ?? '').toString();
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text(
              _initials,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 18.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _managerCode,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
                if (since.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11.sp, color: AppColors.textGrey),
                      SizedBox(width: 4.w),
                      Text(
                        'Since $since',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary strip ──
  Widget _buildSummaryStrip() {
    final totalPlans = _num(_profile['total_plans']).toInt();
    final aum = _num(_profile['total_aum']);
    final investors = _num(_profile['total_investors']).toInt();
    return Row(
      children: [
        Expanded(
          child: _kpiTile(
            label: 'Total Plans',
            value: '$totalPlans',
            icon: Icons.list_alt_rounded,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _kpiTile(
            label: 'Total AUM',
            value: _money(aum),
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _kpiTile(
            label: 'Investors',
            value: '$investors',
            icon: Icons.group_rounded,
          ),
        ),
      ],
    );
  }

  Widget _kpiTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.sp, color: AppColors.primary),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section title ──
  Widget _buildSectionTitle(String text, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  // ── Plan card ──
  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final id = int.tryParse(plan['id'].toString()) ?? 0;
    final selected = (_selectedPlan?['id'].toString() ?? '') == id.toString();
    final perf = (plan['performance'] is Map)
        ? Map<String, dynamic>.from(plan['performance'] as Map)
        : <String, dynamic>{};
    final profit = _num(perf['profit']);
    final winRate = _num(perf['win_rate']);
    final monthly = _num(perf['monthly_return']);
    final drawdown = _num(perf['max_drawdown']);
    final tradesCount = _num(perf['trades_count']).toInt();

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _selectedPlan = plan);
            _loadPlanData(plan);
          },
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (plan['plan_name'] ?? '—').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_num(plan['commission_percentage']).toStringAsFixed(0)}% fee',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                if ((plan['strategy_description'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  Text(
                    plan['strategy_description'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textGrey,
                      height: 1.3,
                    ),
                  ),
                SizedBox(height: 10.h),
                Divider(height: 1, color: AppColors.border),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: _miniMetric(
                        'PROFIT',
                        _money(profit),
                        profit >= 0 ? AppColors.green : AppColors.error,
                      ),
                    ),
                    Expanded(
                      child: _miniMetric(
                        'WIN RATE',
                        '${winRate.toStringAsFixed(0)}%',
                        AppColors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: _miniMetric(
                        'MONTHLY',
                        '${monthly.toStringAsFixed(1)}%',
                        monthly >= 0 ? AppColors.green : AppColors.error,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _miniMetric(
                        'MAX DD',
                        '-${drawdown.toStringAsFixed(1)}%',
                        AppColors.error,
                      ),
                    ),
                    Expanded(
                      child: _miniMetric(
                        'TRADES',
                        '$tradesCount',
                        AppColors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: _miniMetric(
                        'MIN INV',
                        '\$${_num(plan['minimum_investment']).toStringAsFixed(0)}',
                        AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Icon(Icons.group, size: 12.sp, color: AppColors.textGrey),
                    SizedBox(width: 4.w),
                    Text(
                      '${_num(plan['active_investors']).toInt()} investors',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Icon(Icons.lock_outline_rounded,
                        size: 12.sp, color: AppColors.textGrey),
                    SizedBox(width: 4.w),
                    Text(
                      _money(_num(plan['total_locked'])),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selected ? 'Selected' : 'View',
                        style: TextStyle(
                          color:
                              selected ? AppColors.whiteColor : AppColors.primary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textGrey,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Performance summary card ──
  Widget _buildPerformanceCard() {
    final s = (_profile['performance_summary'] is Map)
        ? Map<String, dynamic>.from(_profile['performance_summary'] as Map)
        : <String, dynamic>{};
    final totalProfit = _num(s['total_profit']);
    final totalPnl = _num(s['total_pnl_value']);
    final avgMonthly = _num(s['avg_monthly_return']);
    final winRate = _num(s['win_rate']);
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  'TOTAL PROFIT',
                  '${totalProfit.toStringAsFixed(2)}%',
                  totalProfit >= 0 ? AppColors.green : AppColors.error,
                ),
              ),
              Expanded(
                child: _miniMetric(
                  'TOTAL P&L',
                  _money(totalPnl),
                  totalPnl >= 0 ? AppColors.green : AppColors.error,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  'AVG MONTHLY',
                  '${avgMonthly.toStringAsFixed(2)}%',
                  avgMonthly >= 0 ? AppColors.green : AppColors.error,
                ),
              ),
              Expanded(
                child: _miniMetric(
                  'WIN RATE',
                  '${winRate.toStringAsFixed(1)}%',
                  AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Open positions ──
  Widget _buildOpenPositions() {
    if (_loadingOpen) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: SizedBox(
            width: 22.w,
            height: 22.w,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }
    if (_openPositions.isEmpty) {
      return _emptyTile('No open positions for this plan.');
    }
    return Column(
      children: _openPositions
          .map((p) => _tradeRow(p, isOpen: true))
          .toList(growable: false),
    );
  }

  // ── Trades list ──
  Widget _buildTradesList() {
    if (_loadingTrades) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: SizedBox(
            width: 22.w,
            height: 22.w,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }
    if (_trades.isEmpty) {
      return _emptyTile('No trades yet for this plan.');
    }
    return Column(
      children: _trades.map((t) => _tradeRow(t)).toList(growable: false),
    );
  }

  Widget _tradeRow(Map<String, dynamic> t, {bool isOpen = false}) {
    final symbol = (t['symbol'] ?? '—').toString();
    final type = (t['type'] ?? '').toString();
    final lot = _num(t['lot_size']);
    final profit = _num(t['profit']);
    final openTime = (t['open_time'] ?? '').toString();
    final closeTime = (t['close_time'] ?? '').toString();
    final isBuy = type.toLowerCase() == 'buy';
    final pColor = profit > 0
        ? AppColors.green
        : profit < 0
            ? AppColors.error
            : AppColors.textGrey;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: (isBuy ? AppColors.green : AppColors.error)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isBuy ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: isBuy ? AppColors.green : AppColors.error,
              size: 16.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      symbol,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 5.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: (isBuy ? AppColors.green : AppColors.error)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: isBuy ? AppColors.green : AppColors.error,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '${lot.toStringAsFixed(2)} lot',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  isOpen
                      ? 'Opened $openTime'
                      : (closeTime.isEmpty
                          ? openTime
                          : '$openTime → $closeTime'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: pColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyTile(String message) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_rounded, color: AppColors.textGrey, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded,
                size: 48.sp, color: AppColors.textGrey),
            SizedBox(height: 12.h),
            Text(
              'Manager not found',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _managerCode.isEmpty
                  ? 'No manager id was provided.'
                  : 'Unable to load profile for $_managerCode.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
