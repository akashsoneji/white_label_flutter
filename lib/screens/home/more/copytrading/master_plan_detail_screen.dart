import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_plan_detail_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/services/theme_service.dart';
import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class MasterPlanDetailScreen extends StatelessWidget {
  final int planId;
  const MasterPlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      CopyTradingMasterPlanDetailController(planId: planId),
      permanent: false,
    );

    // Re-build the screen when the theme flips, so hard-coded tints
    // controlled via [PlanTokens] pick up dark-mode values.
    return Obx(() {
      final theme = Get.find<ThemeService>();
      final isDark = theme.isDarkModeObs.value;
      final t = PlanTokens(isDark: isDark);

      return Scaffold(
        backgroundColor: t.background,
        appBar: AppBar(
          backgroundColor: t.appBar,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: t.appBar,
          leading: AppSvgBackButton(onPressed: () => Get.back()),
          title: Text(
            TranslationUtils.tr('master_plan_detail_screen_plan_details'),
            style: AppTextStyles.heading.copyWith(color: t.textPrimary),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value &&
              controller.detail.value == null) {
            return Center(
              child: CircularProgressIndicator(color: t.brandBlue),
            );
          }

          final plan = controller.detail.value;
          if (plan == null) {
            return _EmptyState(
              onRetry: controller.loadPlanDetail,
              tokens: t,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadPlanDetail,
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                // Header card
                _PlanHeaderCard(plan: plan, controller: controller, tokens: t),
                SizedBox(height: 12),

                // KPI cards (2 hero + 4 pill strip)
                _KpiGrid(plan: plan, tokens: t),
                SizedBox(height: 12),

                // Performance row (4-column compact grid)
                _SectionCard(
                  title: TranslationUtils.tr('portfolio_performance'),
                  tokens: t,
                  accentColor: t.success,
                  child: _PerformanceRow(perf: plan.performance, tokens: t),
                ),
                SizedBox(height: 12),

                // Equity curve
                _SectionCard(
                  title: TranslationUtils.tr('master_plan_detail_screen_equity_curve_last_90_days'),
                  tokens: t,
                  accentColor: t.success,
                  child: _EquityCurve(equity: plan.equityCurve, tokens: t),
                ),
                SizedBox(height: 12),

                _CollapsibleSection(
                  title: TranslationUtils.tr('master_plan_detail_screen_copiers'),
                  count: plan.copiersTotal > 0 ? plan.copiersTotal : plan.copiers.length,
                  tokens: t,
                  child: _PlanItemList(
                    itemCount: plan.copiers.length,
                    emptyText: TranslationUtils.tr('master_plan_detail_screen_no_copiers'),
                    tokens: t,
                    itemBuilder: (_, i) => _PlanCopierRow(copier: plan.copiers[i], tokens: t),
                  ),
                ),
                SizedBox(height: 12),

                _CollapsibleSection(
                  title: TranslationUtils.tr('dashboard_open_positions'),
                  count: plan.openPositionsDetail.length,
                  tokens: t,
                  child: _PlanItemList(
                    itemCount: plan.openPositionsDetail.length,
                    emptyText: TranslationUtils.tr('master_plan_detail_screen_no_open_positions'),
                    tokens: t,
                    itemBuilder: (_, i) =>
                        _OpenPositionRow(position: plan.openPositionsDetail[i], tokens: t),
                  ),
                ),
                SizedBox(height: 12),

                _CollapsibleSection(
                  title: TranslationUtils.tr('master_plan_detail_screen_trade_history'),
                  count: plan.tradeHistory.length,
                  tokens: t,
                  accentColor: t.success,
                  child: _PlanItemList(
                    itemCount: plan.tradeHistory.length,
                    emptyText: TranslationUtils.tr('master_plan_detail_screen_no_trades'),
                    tokens: t,
                    itemBuilder: (_, i) => _TradeHistoryRow(trade: plan.tradeHistory[i], tokens: t),
                  ),
                ),
                SizedBox(height: 12),

                // Commission summary
                _SectionCard(
                  title: TranslationUtils.tr('master_plan_detail_screen_commission_summary'),
                  tokens: t,
                  accentColor: t.warning,
                  child: _CommissionSummary(
                    comm: plan.commissionSummary,
                    tokens: t,
                  ),
                ),
                SizedBox(height: 12),

                _CollapsibleSection(
                  title: TranslationUtils.tr('master_plan_detail_screen_commission_history'),
                  count: plan.commissionHistory.length,
                  tokens: t,
                  accentColor: t.warning,
                  child: _PlanItemList(
                    itemCount: plan.commissionHistory.length,
                    emptyText: TranslationUtils.tr('master_plan_detail_screen_no_commission_history'),
                    tokens: t,
                    itemBuilder: (_, i) =>
                        _CommissionHistoryRow(entry: plan.commissionHistory[i], tokens: t),
                  ),
                ),
                SizedBox(height: 12),

                // Settlement cycle
                _SectionCard(
                  title: TranslationUtils.tr('master_plan_detail_screen_settlement_cycle'),
                  tokens: t,
                  accentColor: t.warning,
                  child: _SettlementCycle(settle: plan.settlement, tokens: t),
                ),
                SizedBox(height: 12),

                // Commission & fees
                _SectionCard(
                  title: TranslationUtils.tr('master_plan_detail_screen_commission_fees'),
                  tokens: t,
                  accentColor: t.warning,
                  child: _CommissionFees(plan: plan, tokens: t),
                ),
                SizedBox(height: 12),

                // Copier rules
                _SectionCard(
                  title: TranslationUtils.tr('master_plan_detail_screen_copier_rules'),
                  tokens: t,
                  child: _CopierRules(plan: plan, tokens: t),
                ),
                SizedBox(height: 12),

                // Strategy & risk disclosure
                _SectionCard(
                  title: TranslationUtils.tr('master_details_screen_strategy_risk_disclosure'),
                  tokens: t,
                  child: _StrategyDisclosure(plan: plan, tokens: t),
                ),
                SizedBox(height: 12),

                // Account & system
                _SectionCard(
                  title: TranslationUtils.tr('master_plan_detail_screen_account_system'),
                  tokens: t,
                  child: _AccountSystem(plan: plan, tokens: t),
                ),
                SizedBox(height: 12),

                _CollapsibleSection(
                  title: TranslationUtils.tr('master_plan_detail_screen_activity'),
                  count: plan.activityFeed.length,
                  tokens: t,
                  accentColor: t.brandBlue,
                  child: _PlanItemList(
                    itemCount: plan.activityFeed.length,
                    emptyText: TranslationUtils.tr('master_plan_detail_screen_no_activity'),
                    tokens: t,
                    itemBuilder: (_, i) => _ActivityRow(item: plan.activityFeed[i], tokens: t),
                  ),
                ),
                SizedBox(height: 12),

                // Plan timeline
                _SectionCard(
                  title: TranslationUtils.tr('master_plan_detail_screen_plan_timeline'),
                  tokens: t,
                  accentColor: t.brandBlue,
                  child: _PlanTimeline(plan: plan, tokens: t),
                ),
              ],
            ),
          );
        }),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme tokens
// ─────────────────────────────────────────────────────────────────────────────

class PlanTokens {
  final bool isDark;
  PlanTokens({required this.isDark});

  // Brand accents stay the same across themes (matches web).
  static const Color _brandBlue = Color(0xFF2C5FFB);
  static const Color _success = Color(0xFF12B76A);
  static const Color _successText = Color(0xFF027A48);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _dangerText = Color(0xFFB42318);
  static const Color _warning = Color(0xFFF79009);
  static const Color _warningSoft = Color(0xFFFFFAEB);
  static const Color _warningText = Color(0xFFB54708);

  // Neutrals - light
  static const Color _bgLight = Color(0xFFF7F8FA);
  static const Color _cardLight = Colors.white;
  static const Color _borderLight = Color(0xFFE4E7EC);
  static const Color _dividerLineLight = Color(0xFFEAECF0);
  static const Color _dividerLight = Color(0xFFF2F4F7);
  static const Color _mutedLight = Color(0xFFF2F4F7);
  static const Color _mutedTextLight = Color(0xFF98A2B3);
  static const Color _subTextLight = Color(0xFF667085);
  static const Color _subTextAltLight = Color(0xFF6B7280);
  static const Color _descTextLight = Color(0xFF475467);
  static const Color _bodyTextLight = Color(0xFF344054);
  static const Color _headingTextLight = Color(0xFF101828);

  // Neutrals - dark
  static const Color _bgDark = Color(0xFF0E1217);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _borderDark = Color(0xFF2A3038);
  static const Color _dividerDark = Color(0xFF1F242C);
  static const Color _mutedDark = Color(0xFF1F242C);
  static const Color _mutedTextDark = Color(0xFF6B7280);
  static const Color _subTextDark = Color(0xFF8B95A4);
  static const Color _descTextDark = Color(0xFFB6BFCD);
  static const Color _bodyTextDark = Color(0xFFD4DAE4);
  static const Color _headingTextDark = Color(0xFFF5F7FA);

  Color get background => isDark ? _bgDark : _bgLight;
  Color get appBar => isDark ? _cardDark : _cardLight;
  Color get card => isDark ? _cardDark : _cardLight;
  Color get border => isDark ? _borderDark : _borderLight;
  Color get divider => isDark ? _dividerDark : _dividerLight;
  Color get dividerLine => isDark ? _dividerDark : _dividerLineLight;
  Color get muted => isDark ? _mutedDark : _mutedLight;
  Color get mutedText => isDark ? _mutedTextDark : _mutedTextLight;
  Color get subText => isDark ? _subTextDark : _subTextLight;
  Color get subTextAlt => isDark ? _subTextDark : _subTextAltLight;
  Color get descText => isDark ? _descTextDark : _descTextLight;
  Color get bodyText => isDark ? _bodyTextDark : _bodyTextLight;
  Color get textPrimary => isDark ? _headingTextDark : _headingTextLight;
  Color get textSecondary => isDark ? _bodyTextDark : _bodyTextLight;

  // Brand
  Color get brandBlue => _brandBlue;
  Color get success => _success;
  Color get successText => _successText;
  Color get danger => _danger;
  Color get dangerText => _dangerText;
  Color get warning => _warning;
  Color get warningSoft => _warningSoft;
  Color get warningText => _warningText;

  BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      );

  BoxDecoration get chipDecoration => BoxDecoration(
        color: muted,
        borderRadius: BorderRadius.circular(10),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / loading state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRetry;
  final PlanTokens tokens;
  const _EmptyState({required this.onRetry, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: tokens.mutedText),
          SizedBox(height: 12),
          Text(
            TranslationUtils.tr('master_plan_detail_screen_plan_not_found'),
            style: AppTextStyles.bodyText.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: tokens.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => onRetry(),
            child: Text(TranslationUtils.tr('common_retry')),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan header


class _PlanHeaderCard extends StatelessWidget {
  final CopyTradingMasterPlanDetail plan;
  final CopyTradingMasterPlanDetailController controller;
  final PlanTokens tokens;

  const _PlanHeaderCard({
    required this.plan,
    required this.controller,
    required this.tokens,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  /// Pausing only flips `copying_paused`; `status` stays "approved", so the
  /// header must read the flag to show the plan as paused.
  bool get _isPausedApproved {
    final status = plan.status.toLowerCase();
    return plan.copyingPaused && (status == 'approved' || status == 'active');
  }

  Color _statusColor() {
    if (_isPausedApproved) return tokens.warning;
    switch (plan.status.toLowerCase()) {
      case 'approved':
      case 'active':
        return tokens.success;
      case 'paused':
        return tokens.warning;
      case 'inactive':
      case 'inactivated':
        return tokens.mutedText;
      default:
        return tokens.brandBlue;
    }
  }

  String _statusLabel() {
    if (plan.status.isEmpty) return TranslationUtils.tr('ib_status_unknown');
    if (_isPausedApproved) return TranslationUtils.tr('copy_trading_paused');
    switch (plan.status.toLowerCase()) {
      case 'approved':
      case 'active':
        return TranslationUtils.tr('kyc_verification_approved');
      case 'pending_admin':
      case 'pending_review':
        return TranslationUtils.tr('copy_trading_hub_screen_pending_review');
      case 'rejected':
        return TranslationUtils.tr('kyc_verification_rejected');
      default:
        final readable = plan.status.replaceAll('_', ' ');
        return readable[0].toUpperCase() + readable.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pause/resume sets `copying_paused`; `status` stays "approved".
    final isPaused =
        plan.copyingPaused || plan.status.toLowerCase() == 'paused';
    final isInactive = plan.status.toLowerCase() == 'inactive' ||
        plan.status.toLowerCase() == 'inactivated';
    final isCopyingOn = !plan.copyingPaused;

    return Container(
      decoration: tokens.cardDecoration,
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: tokens.brandBlue,
                child: Text(
                  _initials(plan.planName),
                  style: AppTextStyles.bodyText.copyWith(
                    color: tokens.card,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.planName,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusPill(
                          label: _statusLabel(),
                          color: _statusColor(),
                          tokens: tokens,
                        ),
                        _GrayPill(
                          label: plan.commissionLabel.isNotEmpty
                              ? plan.commissionLabel
                              : TranslationUtils.tr('general_commission'),
                          tokens: tokens,
                        ),
                        // Compact "copying" indicator merged with a tiny dot
                        _CopyingDotPill(
                          on: isCopyingOn,
                          tokens: tokens,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeaderAction(
                  icon: Icons.edit_outlined,
                  label: TranslationUtils.tr('general_edit'),
                  onTap: () {},
                  color: tokens.bodyText,
                  tokens: tokens,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HeaderAction(
                  icon: isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  label: isPaused
                      ? TranslationUtils.tr('my_plans_tab_resume')
                      : TranslationUtils.tr('my_plans_tab_pause'),
                  onTap: isPaused
                      ? controller.resumePlan
                      : controller.pausePlan,
                  color: tokens.warning,
                  tokens: tokens,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HeaderAction(
                  icon: Icons.block,
                  label: TranslationUtils.tr('copy_trading_inactivate'),
                  onTap: controller.inactivatePlan,
                  color: tokens.dangerText,
                  borderColor: tokens.danger.withValues(alpha: 0.4),
                  disabled: isInactive,
                  tokens: tokens,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final PlanTokens tokens;
  const _StatusPill({
    required this.label,
    required this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GrayPill extends StatelessWidget {
  final String label;
  final PlanTokens tokens;
  const _GrayPill({required this.label, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: tokens.chipDecoration,
      child: Text(
        label,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 11,
          color: tokens.bodyText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Tiny pill that shows a colored dot + "Copying on/off" text in one compact chip
class _CopyingDotPill extends StatelessWidget {
  final bool on;
  final PlanTokens tokens;
  const _CopyingDotPill({required this.on, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final color = on ? tokens.success : tokens.mutedText;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 5),
          Text(
            on
                ? TranslationUtils.tr('copy_trading_copying_on')
                : TranslationUtils.tr('copy_trading_copying_off'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? borderColor;
  final bool disabled;
  final PlanTokens tokens;

  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tokens,
    this.color,
    this.borderColor,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? tokens.bodyText;
    final b = borderColor ?? tokens.border;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: tokens.card,
          border: Border.all(color: b),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14, color: disabled ? tokens.mutedText : c),
            SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: disabled ? tokens.mutedText : c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI block (redesigned): 2 hero cards + horizontal scrolling pill row
// ─────────────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final CopyTradingMasterPlanDetail plan;
  final PlanTokens tokens;
  const _KpiGrid({required this.plan, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero band: 2 standout numbers (AUM + Net P&L)
        Row(
          children: [
            Expanded(
              child: _KpiHeroCard(
                icon: Icons.account_balance_wallet_outlined,
                label: TranslationUtils.tr('copy_trading_plan_aum'),
                value: '\$${plan.totalCapital.toStringAsFixed(2)}',
                accent: tokens.brandBlue,
                tokens: tokens,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _KpiHeroCard(
                icon: Icons.trending_up_rounded,
                label: TranslationUtils.tr('pmam_net_pnl'),
                value: '\$${plan.performance.netPnl.toStringAsFixed(2)}',
                accent: plan.performance.netPnl >= 0
                    ? tokens.success
                    : tokens.danger,
                tokens: tokens,
                trailing: Text(
                  TranslationUtils.tr('master_plan_detail_screen_after_fees'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10,
                    color: tokens.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),

        // ── Compact pill strip: 4 secondary metrics, horizontal scroll
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _KpiPill(
                icon: Icons.people_alt_rounded,
                label: TranslationUtils.tr('copy_trading_active_copiers'),
                value: '${plan.activeCopiers}',
                accent: tokens.brandBlue,
                tokens: tokens,
              ),
              SizedBox(width: 8),
              _KpiPill(
                icon: Icons.grid_view_rounded,
                label: TranslationUtils.tr('dashboard_open_positions'),
                value: '${plan.openPositions}',
                accent: tokens.brandBlue,
                tokens: tokens,
              ),
              SizedBox(width: 8),
              _KpiPill(
                icon: Icons.percent_rounded,
                label: TranslationUtils.tr('copy_trading_floating_comm'),
                value:
                    '\$${plan.commissionSummary.pending.toStringAsFixed(2)}',
                accent: tokens.warning,
                tokens: tokens,
              ),
              SizedBox(width: 8),
              _KpiPill(
                icon: Icons.payments_outlined,
                label: TranslationUtils.tr('ibm_earned'),
                value:
                    '\$${plan.totalCommissionEarned.toStringAsFixed(2)}',
                accent: tokens.success,
                tokens: tokens,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact metric pill: icon + value + label, single dense row
class _KpiPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final PlanTokens tokens;

  const _KpiPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3),
                Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: tokens.mutedText,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standout "hero" metric card (used only for the 2 most important numbers)
class _KpiHeroCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final PlanTokens tokens;
  final Widget? trailing;

  const _KpiHeroCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.tokens,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            accent.withValues(alpha: tokens.isDark ? 0.18 : 0.10),
            accent.withValues(alpha: tokens.isDark ? 0.08 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: tokens.isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: AppColors.onColoredBackground, size: 15),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.descText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                height: 1.05,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
            ),
          ),
          if (trailing != null) ...[
            SizedBox(height: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final PlanTokens tokens;
  final Color? accentColor;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.tokens,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? tokens.brandBlue;
    return Container(
      width: double.infinity,
      decoration: tokens.cardDecoration,
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with thin colored accent stripe on the left
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Performance row (8 mini-stats)
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceRow extends StatelessWidget {
  final CopyTradingPlanPerformance perf;
  final PlanTokens tokens;
  const _PerformanceRow({required this.perf, required this.tokens});

  @override
  Widget build(BuildContext context) {
    // 4 columns × 2 rows — fits on a single screen, no horizontal scroll.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('ticket_status_closed'),
                value: '${perf.closedTrades}',
                tokens: tokens,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('dashboard_win_rate'),
                value: '${perf.winRate.toStringAsFixed(2)}%',
                tokens: tokens,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('copy_trading_profit_factor'),
                value: perf.profitFactor.toStringAsFixed(2),
                tokens: tokens,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('copy_trading_expectancy'),
                value: '\$${perf.expectancy.toStringAsFixed(2)}',
                valueColor: tokens.success,
                tokens: tokens,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('copy_trading_avg_win'),
                value: '\$${perf.avgWin.toStringAsFixed(2)}',
                valueColor: tokens.success,
                tokens: tokens,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('copy_trading_avg_loss'),
                value: '\$${perf.avgLoss.toStringAsFixed(2)}',
                valueColor: tokens.danger,
                tokens: tokens,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('copy_trading_max_dd'),
                value: '\$${perf.maxDrawdown.toStringAsFixed(2)}',
                valueColor: tokens.danger,
                tokens: tokens,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('pmam_net_pnl'),
                value: '\$${perf.netPnl.toStringAsFixed(2)}',
                valueColor:
                    perf.netPnl >= 0 ? tokens.success : tokens.danger,
                tokens: tokens,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('master_plan_detail_screen_wins'),
                value: '${perf.wins}',
                valueColor: tokens.success,
                tokens: tokens,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('master_plan_detail_screen_losses'),
                value: '${perf.losses}',
                valueColor: tokens.danger,
                tokens: tokens,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('master_plan_detail_screen_breakeven'),
                value: '${perf.breakeven}',
                tokens: tokens,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('master_plan_detail_screen_gross_profit'),
                value: _planMoney(perf.grossProfit),
                valueColor: tokens.success,
                tokens: tokens,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: TranslationUtils.tr('master_plan_detail_screen_gross_loss'),
                value: _planMoney(perf.grossLoss),
                valueColor: tokens.danger,
                tokens: tokens,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Compact performance cell — small label + bold value, no scroll needed
class _PerfCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final PlanTokens tokens;

  const _PerfCell({
    required this.label,
    required this.value,
    required this.tokens,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: tokens.mutedText,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? tokens.textPrimary,
                height: 1.0,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Equity curve
// ─────────────────────────────────────────────────────────────────────────────

class _EquityCurve extends StatelessWidget {
  final List<CopyTradingPlanEquityCurvePoint> equity;
  final PlanTokens tokens;
  const _EquityCurve({required this.equity, required this.tokens});

  @override
  Widget build(BuildContext context) {
    if (equity.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            TranslationUtils.tr('master_plan_detail_screen_no_equity_data_yet'),
            style: AppTextStyles.bodyText.copyWith(
              color: tokens.mutedText,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    // Build list of parsed (DateTime, double) pairs, ignore unparseable rows.
    final pts = <_EquityPt>[];
    for (final p in equity) {
      if (p.date.isEmpty) continue;
      try {
        final d = DateTime.parse(p.date);
        pts.add(_EquityPt(d, p.equity.toDouble()));
      } catch (_) {
        // ignore
      }
    }

    if (pts.length < 2) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            TranslationUtils.tr('master_plan_detail_screen_no_equity_data_yet'),
            style: AppTextStyles.bodyText.copyWith(
              color: tokens.mutedText,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final spots = <FlSpot>[
      for (int i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].value),
    ];

    final minY =
        pts.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final maxY =
        pts.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    final padY = range * 0.15 + 1;
    final chartMin = minY - padY;
    final chartMax = maxY + padY;
    final yInterval = ((chartMax - chartMin) / 5).abs();
    final xInterval = (pts.length / 6).clamp(1, pts.length).toDouble();

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: chartMin,
          maxY: chartMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: tokens.dividerLine,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: xInterval,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= pts.length) {
                    return const SizedBox.shrink();
                  }
                  final d = pts[idx].date;
                  return Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(d),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 9,
                        color: tokens.mutedText,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text(
                      NumberFormat.compactCurrency(symbol: '\$')
                          .format(value),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 9,
                        color: tokens.mutedText,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: tokens.success,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: tokens.success.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquityPt {
  final DateTime date;
  final double value;
  _EquityPt(this.date, this.value);
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsible list sections (copiers, positions, trades, commission, activity)
// ─────────────────────────────────────────────────────────────────────────────

String _planMoney(num value) => value < 0
    ? '-\$${value.abs().toStringAsFixed(2)}'
    : '\$${value.toStringAsFixed(2)}';

String _planDateTime(String iso) {
  if (iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  return DateFormat('d MMM yyyy, HH:mm').format(parsed.toLocal());
}

Color _pnlColor(num value, PlanTokens tokens) {
  if (value > 0) return tokens.success;
  if (value < 0) return tokens.danger;
  return tokens.textPrimary;
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final int count;
  final PlanTokens tokens;
  final Color? accentColor;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.tokens,
    required this.child,
    this.accentColor,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final accent = widget.accentColor ?? tokens.brandBlue;
    return Container(
      width: double.infinity,
      decoration: tokens.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: tokens.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class _PlanItemList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyText;
  final PlanTokens tokens;

  const _PlanItemList({
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyText,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            emptyText,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12,
              color: tokens.mutedText,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < itemCount; i++) ...[
          if (i > 0) _Divider(tokens: tokens),
          itemBuilder(context, i),
        ],
      ],
    );
  }
}

/// Bold title, optional pills, optional trailing widget — shared by every row.
class _ItemHeader extends StatelessWidget {
  final String title;
  final List<Widget> pills;
  final Widget? trailing;
  final PlanTokens tokens;

  const _ItemHeader({
    required this.title,
    required this.tokens,
    this.pills = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final pill in pills) ...[SizedBox(width: 6), pill],
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ItemSubtitle extends StatelessWidget {
  final String text;
  final PlanTokens tokens;
  const _ItemSubtitle({required this.text, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 3),
      child: Text(
        text,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 11,
          color: tokens.mutedText,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Row of summary cells separated by thin vertical lines.
class _ItemStats extends StatelessWidget {
  final List<_SummaryCell> cells;
  final PlanTokens tokens;
  const _ItemStats({required this.cells, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cells.length; i++) ...[
            if (i > 0) _SummaryVSep(tokens: tokens),
            Expanded(child: cells[i]),
          ],
        ],
      ),
    );
  }
}

class _DirectionPill extends StatelessWidget {
  final String direction;
  final PlanTokens tokens;
  const _DirectionPill({required this.direction, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final isBuy = direction.toLowerCase() == 'buy';
    return _StatusPill(
      label: direction.toUpperCase(),
      color: isBuy ? tokens.success : tokens.danger,
      tokens: tokens,
    );
  }
}

class _PlanCopierRow extends StatelessWidget {
  final PlanCopierItem copier;
  final PlanTokens tokens;
  const _PlanCopierRow({required this.copier, required this.tokens});

  Color _statusColor() {
    switch (copier.status.toLowerCase()) {
      case 'active':
        return tokens.success;
      case 'paused':
      case 'pending':
        return tokens.warning;
      case 'stopped':
      case 'cancelled':
        return tokens.mutedText;
      default:
        return tokens.brandBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [copier.accountNumber, copier.userEmail]
        .where((part) => part.isNotEmpty)
        .join(' · ');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemHeader(
            title: copier.userName.isNotEmpty ? copier.userName : '—',
            tokens: tokens,
            trailing: _StatusPill(
              label: _capitalize(copier.status),
              color: _statusColor(),
              tokens: tokens,
            ),
          ),
          if (subtitle.isNotEmpty) _ItemSubtitle(text: subtitle, tokens: tokens),
          _ItemStats(
            tokens: tokens,
            cells: [
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_capital'),
                value: _planMoney(copier.capitalAmount),
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_pnl'),
                value: _planMoney(copier.totalPnl),
                valueColor: _pnlColor(copier.totalPnl, tokens),
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_commission_paid'),
                value: _planMoney(copier.totalCommissionPaid),
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_pending_commission'),
                value: _planMoney(copier.pendingCommission),
                valueColor: tokens.warning,
                tokens: tokens,
              ),
            ],
          ),
          _ItemSubtitle(
            text: '${TranslationUtils.tr('master_plan_detail_screen_joined')}: '
                '${_planDateTime(copier.joinedAt)} · '
                '${TranslationUtils.tr('master_plan_detail_screen_open_trades')}: '
                '${copier.openTradesCount}',
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

class _OpenPositionRow extends StatelessWidget {
  final PlanOpenPositionItem position;
  final PlanTokens tokens;
  const _OpenPositionRow({required this.position, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      position.copierName,
      position.copierAccount,
      _planDateTime(position.openTime),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemHeader(
            title: position.symbol,
            tokens: tokens,
            pills: [
              if (position.direction.isNotEmpty)
                _DirectionPill(direction: position.direction, tokens: tokens),
            ],
            trailing: Text(
              _planMoney(position.profit),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _pnlColor(position.profit, tokens),
              ),
            ),
          ),
          _ItemSubtitle(text: subtitle, tokens: tokens),
          _ItemStats(
            tokens: tokens,
            cells: [
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_master_volume'),
                value: '${position.masterVolume}',
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_copier_volume'),
                value: '${position.copierVolume}',
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_open_price'),
                value: '${position.openPrice}',
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_current_price'),
                value: '${position.currentPrice}',
                tokens: tokens,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TradeHistoryRow extends StatelessWidget {
  final CopyTradingMasterTradeHistoryItem trade;
  final PlanTokens tokens;
  const _TradeHistoryRow({required this.trade, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      trade.copierName,
      trade.copierAccount,
      _planDateTime(trade.closeTime),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemHeader(
            title: trade.symbol,
            tokens: tokens,
            pills: [
              if (trade.direction.isNotEmpty)
                _DirectionPill(direction: trade.direction, tokens: tokens),
            ],
            trailing: trade.distributionStatus.isEmpty
                ? null
                : _GrayPill(
                    label: _capitalize(trade.distributionStatus),
                    tokens: tokens,
                  ),
          ),
          _ItemSubtitle(text: subtitle, tokens: tokens),
          _ItemStats(
            tokens: tokens,
            cells: [
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_master_volume'),
                value: '${trade.masterVolume}',
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_copier_volume'),
                value: '${trade.copierVolume}',
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_price'),
                value: '${trade.openPrice} → ${trade.closePrice}',
                tokens: tokens,
              ),
            ],
          ),
          _ItemStats(
            tokens: tokens,
            cells: [
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_master_pnl'),
                value: _planMoney(trade.masterProfit),
                valueColor: _pnlColor(trade.masterProfit, tokens),
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_copier_pnl'),
                value: _planMoney(trade.copierProfit),
                valueColor: _pnlColor(trade.copierProfit, tokens),
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_commission_accrued'),
                value: _planMoney(trade.commissionAccruedDisplay),
                valueColor: tokens.warning,
                tokens: tokens,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommissionHistoryRow extends StatelessWidget {
  final CopyTradingMasterCommissionHistoryItem entry;
  final PlanTokens tokens;
  const _CommissionHistoryRow({required this.entry, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      entry.copierName,
      entry.copierAccount,
      _planDateTime(entry.settledAt),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemHeader(
            title: entry.symbol.isNotEmpty ? entry.symbol : '—',
            tokens: tokens,
            pills: [
              if (entry.direction.isNotEmpty)
                _DirectionPill(direction: entry.direction, tokens: tokens),
              if (entry.inGracePeriod)
                _StatusPill(
                  label: TranslationUtils.tr('master_plan_detail_screen_grace_period'),
                  color: tokens.warning,
                  tokens: tokens,
                ),
            ],
            trailing: entry.status.isEmpty
                ? null
                : _GrayPill(label: _capitalize(entry.status), tokens: tokens),
          ),
          _ItemSubtitle(text: subtitle, tokens: tokens),
          _ItemStats(
            tokens: tokens,
            cells: [
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_gross_share'),
                value: _planMoney(entry.grossProfitShare),
                valueColor: _pnlColor(entry.grossProfitShare, tokens),
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_commission_accrued'),
                value: _planMoney(entry.commissionAccruedDisplay),
                valueColor: tokens.warning,
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_commission_preview'),
                value: _planMoney(entry.commissionPreview),
                tokens: tokens,
              ),
              _SummaryCell(
                label: TranslationUtils.tr('master_plan_detail_screen_commission_credited'),
                value: _planMoney(entry.masterCommissionCredited),
                tokens: tokens,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final CopyTradingPlanActivityFeedItem item;
  final PlanTokens tokens;
  const _ActivityRow({required this.item, required this.tokens});

  IconData _icon() {
    final type = item.type.toLowerCase();
    if (type.contains('trade')) return Icons.swap_vert_rounded;
    if (type.contains('join') || type.contains('copier')) {
      return Icons.person_add_alt_1_rounded;
    }
    return Icons.notifications_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tokens.brandBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon(), size: 15, color: tokens.brandBlue),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.subtitle.isNotEmpty)
                  _ItemSubtitle(text: item.subtitle, tokens: tokens),
                _ItemSubtitle(text: _planDateTime(item.at), tokens: tokens),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Commission summary
// ─────────────────────────────────────────────────────────────────────────────

class _CommissionSummary extends StatelessWidget {
  final CopyTradingPlanCommissionSummary comm;
  final PlanTokens tokens;
  const _CommissionSummary({required this.comm, required this.tokens});

  @override
  Widget build(BuildContext context) {
    // Single dense row: 4 metrics side-by-side with a thin divider
    // between them. Fits in one screen-height — no nested grid.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SummaryCell(
            label: TranslationUtils.tr('copy_trading_lifetime'),
            value: '\$${comm.lifetime.toStringAsFixed(2)}',
            tokens: tokens,
          ),
        ),
        _SummaryVSep(tokens: tokens),
        Expanded(
          child: _SummaryCell(
            label: TranslationUtils.tr('time_this_month'),
            value: '\$${comm.thisMonth.toStringAsFixed(2)}',
            tokens: tokens,
          ),
        ),
        _SummaryVSep(tokens: tokens),
        Expanded(
          child: _SummaryCell(
            label: TranslationUtils.tr('transaction_history_pending'),
            value: '\$${comm.pending.toStringAsFixed(2)}',
            valueColor: tokens.warning,
            tokens: tokens,
          ),
        ),
        _SummaryVSep(tokens: tokens),
        Expanded(
          child: _SummaryCell(
            label: TranslationUtils.tr('copy_trading_settled'),
            value: '\$${comm.settled.toStringAsFixed(2)}',
            tokens: tokens,
          ),
        ),
      ],
    );
  }
}

/// Compact inline metric cell — small label above bold value
class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final PlanTokens tokens;

  const _SummaryCell({
    required this.label,
    required this.value,
    required this.tokens,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: tokens.mutedText,
            height: 1.0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? tokens.textPrimary,
              height: 1.0,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// Thin vertical separator between summary cells
class _SummaryVSep extends StatelessWidget {
  final PlanTokens tokens;
  const _SummaryVSep({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: EdgeInsets.symmetric(horizontal: 8),
      color: tokens.divider,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settlement cycle
// ─────────────────────────────────────────────────────────────────────────────

class _SettlementCycle extends StatelessWidget {
  final CopyTradingPlanSettlement settle;
  final PlanTokens tokens;
  const _SettlementCycle({required this.settle, required this.tokens});

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('d MMM yyyy, HH:mm').format(d);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_cycle'),
          description: TranslationUtils.tr('copy_trading_cycle_description'),
          value: _capitalize(settle.cycle),
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_last_settled'),
          description: TranslationUtils.tr('copy_trading_last_settled_description'),
          value: settle.lastSettledAt.isEmpty ? '—' : _fmtDate(settle.lastSettledAt),
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_next_payout'),
          description: TranslationUtils.tr('copy_trading_next_payout_description'),
          value: settle.nextPayoutAt.isEmpty ? '—' : _fmtDate(settle.nextPayoutAt),
          trailingWidget: settle.isDue ? _DueBadge(tokens: tokens) : null,
          tokens: tokens,
        ),
      ],
    );
  }
}

String _capitalize(String s) {
  if (s.isEmpty) return '—';
  return s[0].toUpperCase() + s.substring(1);
}

class _DueBadge extends StatelessWidget {
  final PlanTokens tokens;
  const _DueBadge({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        TranslationUtils.tr('master_plan_detail_screen_due_now'),
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 10,
          color: tokens.warningText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Commission & fees
// ─────────────────────────────────────────────────────────────────────────────

class _CommissionFees extends StatelessWidget {
  final CopyTradingMasterPlanDetail plan;
  final PlanTokens tokens;
  const _CommissionFees({required this.plan, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _KeyValueRow(
          label: TranslationUtils.tr('general_commission'),
          description: TranslationUtils.tr('copy_trading_commission_description'),
          value: plan.commissionLabel.isNotEmpty
              ? plan.commissionLabel
              : '${plan.commissionPercentage}%',
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_commission_type_label'),
          description: TranslationUtils.tr('copy_trading_commission_type_description'),
          value: _capitalize(plan.commissionType.isEmpty
              ? 'per_trade'
              : plan.commissionType),
          tokens: tokens,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Copier rules
// ─────────────────────────────────────────────────────────────────────────────

class _CopierRules extends StatelessWidget {
  final CopyTradingMasterPlanDetail plan;
  final PlanTokens tokens;
  const _CopierRules({required this.plan, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final cap = plan.maxCopiers == 0
        ? '∞'
        : '${plan.activeCopiers} / ${plan.maxCopiers}';
    return Column(
      children: [
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_minimum_capital'),
          description: TranslationUtils.tr('copy_trading_minimum_capital_description'),
          value: '\$${plan.minimumCapital.toStringAsFixed(2)}',
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_active_cap'),
          description: TranslationUtils.tr('copy_trading_active_cap_description'),
          value: cap,
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_plan_full'),
          description: TranslationUtils.tr('copy_trading_plan_full_description'),
          value: plan.isFull
              ? TranslationUtils.tr('general_yes')
              : TranslationUtils.tr('general_no'),
          valueColor:
              plan.isFull ? tokens.danger : tokens.textPrimary,
          tokens: tokens,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Strategy & risk disclosure
// ─────────────────────────────────────────────────────────────────────────────

class _StrategyDisclosure extends StatelessWidget {
  final CopyTradingMasterPlanDetail plan;
  final PlanTokens tokens;
  const _StrategyDisclosure({required this.plan, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TranslationUtils.tr('master_plan_detail_screen_strategy_description'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tokens.subText,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          plan.strategyDescription.isNotEmpty
              ? plan.strategyDescription
              : TranslationUtils.tr('copy_trading_not_provided_add_description'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13,
            color: tokens.bodyText,
            height: 1.4,
          ),
        ),
        SizedBox(height: 16),
        Text(
          TranslationUtils.tr('master_plan_detail_screen_risk_information'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tokens.subText,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          plan.riskInformation.isNotEmpty
              ? plan.riskInformation
              : TranslationUtils.tr('copy_trading_not_provided_disclose_risk'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13,
            color: tokens.bodyText,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account & system
// ─────────────────────────────────────────────────────────────────────────────

class _AccountSystem extends StatelessWidget {
  final CopyTradingMasterPlanDetail plan;
  final PlanTokens tokens;
  const _AccountSystem({required this.plan, required this.tokens});

  String _statusLabel() {
    if (plan.status.isEmpty) return '—';
    return _capitalize(plan.status);
  }

  String _copyingLabel() {
    if (plan.copyingPaused) return TranslationUtils.tr('copy_trading_paused');
    return TranslationUtils.tr('wallet_active');
  }

  String _serverLabel() {
    if (plan.tradingServer.isNotEmpty) return plan.tradingServer;
    if (plan.lpProviderName.isNotEmpty) return plan.lpProviderName;
    return '—';
  }

  String _createdAtLabel() {
    if (plan.createdAt.isEmpty) return '—';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(plan.createdAt));
    } catch (_) {
      return plan.createdAt;
    }
  }

  String? _initialEquity() {
    if (plan.initialEquitySnapshot.isEmpty) return null;
    final n = num.tryParse(plan.initialEquitySnapshot);
    if (n == null) return plan.initialEquitySnapshot;
    return n.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _KeyValueRow(
          label: TranslationUtils.tr('common_status'),
          description: TranslationUtils.tr('copy_trading_status_description'),
          value: _statusLabel(),
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_copying'),
          description: TranslationUtils.tr('copy_trading_copying_description'),
          value: _copyingLabel(),
          valueColor: plan.copyingPaused
              ? tokens.warning
              : tokens.success,
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_server'),
          description: TranslationUtils.tr('copy_trading_server_description'),
          value: _serverLabel(),
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_edit_plan_trading_account'),
          description: TranslationUtils.tr('copy_trading_trading_account_description'),
          value: plan.tradingAccountNumber.isEmpty
              ? '—'
              : plan.tradingAccountNumber,
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('copy_trading_initial_equity_snapshot'),
          description: TranslationUtils.tr('copy_trading_initial_equity_snapshot_description'),
          value: _initialEquity() == null
              ? '—'
              : '\$${_initialEquity()}',
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: TranslationUtils.tr('ticket_created'),
          description: TranslationUtils.tr('copy_trading_created_description'),
          value: _createdAtLabel(),
          tokens: tokens,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan timeline
// ─────────────────────────────────────────────────────────────────────────────

class _PlanTimeline extends StatelessWidget {
  final CopyTradingMasterPlanDetail plan;
  final PlanTokens tokens;
  const _PlanTimeline({required this.plan, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final events = <_TimelineRowVM>[];

    if (plan.createdAt.isNotEmpty) {
      events.add(_TimelineRowVM(
        title: TranslationUtils.tr('master_plan_detail_screen_plan_created'),
        description: TranslationUtils.tr('copy_trading_submitted_for_review'),
        date: plan.createdAt,
        kind: 'created',
        tokens: tokens,
      ));
    }
    if (plan.approvedAt.isNotEmpty) {
      events.add(_TimelineRowVM(
        title: TranslationUtils.tr('master_plan_detail_screen_plan_approved'),
        description: TranslationUtils.tr('copy_trading_live_for_copiers_to_subscribe'),
        date: plan.approvedAt,
        kind: 'approved',
        tokens: tokens,
      ));
    }
    if (plan.copyingPaused && plan.copyingPausedAt.isNotEmpty) {
      events.add(_TimelineRowVM(
        title: TranslationUtils.tr('master_plan_detail_screen_copying_paused'),
        description: TranslationUtils.tr('copy_trading_no_new_master_trades_replicated'),
        date: plan.copyingPausedAt,
        kind: 'paused',
        tokens: tokens,
      ));
    }
    if (plan.status.toLowerCase() == 'inactive' ||
        plan.status.toLowerCase() == 'inactivated') {
      events.add(_TimelineRowVM(
        title: TranslationUtils.tr('master_plan_detail_screen_plan_inactivated'),
        description: TranslationUtils.tr('copy_trading_no_longer_accepting_copiers'),
        date: plan.updatedAt,
        kind: 'inactive',
        tokens: tokens,
      ));
    }

    if (events.isEmpty) {
      return Text(
        TranslationUtils.tr('master_plan_detail_screen_no_timeline_events'),
        style: AppTextStyles.bodyText.copyWith(color: tokens.mutedText, fontSize: 13),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < events.length; i++) ...[
          _TimelineRowWidget(
            event: events[i],
            isLast: i == events.length - 1,
            tokens: tokens,
          ),
        ],
      ],
    );
  }
}

class _TimelineRowVM {
  final String title;
  final String description;
  final String date;
  final String kind;
  final PlanTokens tokens;
  _TimelineRowVM({
    required this.title,
    required this.description,
    required this.date,
    required this.kind,
    required this.tokens,
  });
}

class _TimelineRowWidget extends StatelessWidget {
  final _TimelineRowVM event;
  final bool isLast;
  final PlanTokens tokens;
  const _TimelineRowWidget({
    required this.event,
    required this.isLast,
    required this.tokens,
  });

  Color _dotColor() {
    switch (event.kind.toLowerCase()) {
      case 'approved':
        return tokens.success;
      case 'created':
        return tokens.brandBlue;
      case 'paused':
        return tokens.warning;
      case 'inactive':
      case 'inactivated':
        return tokens.mutedText;
      default:
        return tokens.subText;
    }
  }

  String _fmt(String iso) {
    try {
      return DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: _dotColor(),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: tokens.border,
                  ),
                ),
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _fmt(event.date),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11,
                          color: tokens.mutedText,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    event.description,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 11,
                      color: tokens.subText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String description;
  final String value;
  final Color? valueColor;
  final Widget? trailingWidget;
  final PlanTokens tokens;

  const _KeyValueRow({
    required this.label,
    required this.description,
    required this.value,
    required this.tokens,
    this.valueColor,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11,
                    color: tokens.mutedText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? tokens.textPrimary,
                ),
              ),
              if (trailingWidget != null) ...[
                SizedBox(height: 4),
                trailingWidget!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final PlanTokens tokens;
  const _Divider({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: tokens.divider);
  }
}