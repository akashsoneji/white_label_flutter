import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/copy_trading/copy_trading_master_plan_detail_controller.dart';
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
            'Plan Details',
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                // Header card
                _PlanHeaderCard(plan: plan, controller: controller, tokens: t),
                const SizedBox(height: 12),

                // KPI cards (2 hero + 4 pill strip)
                _KpiGrid(plan: plan, tokens: t),
                const SizedBox(height: 12),

                // Performance row (4-column compact grid)
                _SectionCard(
                  title: 'Performance',
                  tokens: t,
                  accentColor: t.success,
                  child: _PerformanceRow(perf: plan.performance, tokens: t),
                ),
                const SizedBox(height: 12),

                // Equity curve
                _SectionCard(
                  title: 'Equity curve (last 90 days)',
                  tokens: t,
                  accentColor: t.success,
                  child: _EquityCurve(equity: plan.equityCurve, tokens: t),
                ),
                const SizedBox(height: 12),

                // Commission summary
                _SectionCard(
                  title: 'Commission summary',
                  tokens: t,
                  accentColor: t.warning,
                  child: _CommissionSummary(
                    comm: plan.commissionSummary,
                    tokens: t,
                  ),
                ),
                const SizedBox(height: 12),

                // Settlement cycle
                _SectionCard(
                  title: 'Settlement cycle',
                  tokens: t,
                  accentColor: t.warning,
                  child: _SettlementCycle(settle: plan.settlement, tokens: t),
                ),
                const SizedBox(height: 12),

                // Commission & fees
                _SectionCard(
                  title: 'Commission & fees',
                  tokens: t,
                  accentColor: t.warning,
                  child: _CommissionFees(plan: plan, tokens: t),
                ),
                const SizedBox(height: 12),

                // Copier rules
                _SectionCard(
                  title: 'Copier rules',
                  tokens: t,
                  child: _CopierRules(plan: plan, tokens: t),
                ),
                const SizedBox(height: 12),

                // Strategy & risk disclosure
                _SectionCard(
                  title: 'Strategy & risk disclosure',
                  tokens: t,
                  child: _StrategyDisclosure(plan: plan, tokens: t),
                ),
                const SizedBox(height: 12),

                // Account & system
                _SectionCard(
                  title: 'Account & system',
                  tokens: t,
                  child: _AccountSystem(plan: plan, tokens: t),
                ),
                const SizedBox(height: 12),

                // Plan timeline
                _SectionCard(
                  title: 'Plan timeline',
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
          const SizedBox(height: 12),
          Text(
            'Plan not found',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => onRetry(),
            child: const Text('Retry'),
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

  Color _statusColor() {
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
    if (plan.status.isEmpty) return 'Unknown';
    return plan.status[0].toUpperCase() + plan.status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = plan.status.toLowerCase() == 'paused';
    final isInactive = plan.status.toLowerCase() == 'inactive' ||
        plan.status.toLowerCase() == 'inactivated';
    final isCopyingOn = !plan.copyingPaused;

    return Container(
      decoration: tokens.cardDecoration,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                  style: TextStyle(
                    color: tokens.card,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.planName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
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
                              : 'Commission',
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeaderAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () {},
                  color: tokens.bodyText,
                  tokens: tokens,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderAction(
                  icon: isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  label: isPaused ? 'Resume' : 'Pause',
                  onTap: isPaused
                      ? controller.resumePlan
                      : controller.pausePlan,
                  color: tokens.warning,
                  tokens: tokens,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderAction(
                  icon: Icons.block,
                  label: 'Inactivate',
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: tokens.chipDecoration,
      child: Text(
        label,
        style: TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const SizedBox(width: 5),
          Text(
            on ? 'Copying on' : 'Copying off',
            style: TextStyle(
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
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
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
                label: 'Plan AUM',
                value: '\$${plan.totalCapital.toStringAsFixed(2)}',
                accent: tokens.brandBlue,
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiHeroCard(
                icon: Icons.trending_up_rounded,
                label: 'Net P&L',
                value: '\$${plan.performance.netPnl.toStringAsFixed(2)}',
                accent: plan.performance.netPnl >= 0
                    ? tokens.success
                    : tokens.danger,
                tokens: tokens,
                trailing: Text(
                  'After fees',
                  style: TextStyle(
                    fontSize: 10,
                    color: tokens.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Compact pill strip: 4 secondary metrics, horizontal scroll
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _KpiPill(
                icon: Icons.people_alt_rounded,
                label: 'Active Copiers',
                value: '${plan.activeCopiers}',
                accent: tokens.brandBlue,
                tokens: tokens,
              ),
              const SizedBox(width: 8),
              _KpiPill(
                icon: Icons.grid_view_rounded,
                label: 'Open Positions',
                value: '${plan.openPositions}',
                accent: tokens.brandBlue,
                tokens: tokens,
              ),
              const SizedBox(width: 8),
              _KpiPill(
                icon: Icons.percent_rounded,
                label: 'Floating Comm.',
                value:
                    '\$${plan.commissionSummary.pending.toStringAsFixed(2)}',
                accent: tokens.warning,
                tokens: tokens,
              ),
              const SizedBox(width: 8),
              _KpiPill(
                icon: Icons.payments_outlined,
                label: 'Earned',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
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
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
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
            const SizedBox(height: 4),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                label: 'Closed',
                value: '${perf.closedTrades}',
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: 'Win rate',
                value: '${perf.winRate.toStringAsFixed(2)}%',
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: 'Profit factor',
                value: perf.profitFactor.toStringAsFixed(2),
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: 'Expectancy',
                value: '\$${perf.expectancy.toStringAsFixed(2)}',
                valueColor: tokens.success,
                tokens: tokens,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PerfCell(
                label: 'Avg win',
                value: '\$${perf.avgWin.toStringAsFixed(2)}',
                valueColor: tokens.success,
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: 'Avg loss',
                value: '\$${perf.avgLoss.toStringAsFixed(2)}',
                valueColor: tokens.danger,
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: 'Max DD',
                value: '\$${perf.maxDrawdown.toStringAsFixed(2)}',
                valueColor: tokens.danger,
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PerfCell(
                label: 'Net P&L',
                value: '\$${perf.netPnl.toStringAsFixed(2)}',
                valueColor:
                    perf.netPnl >= 0 ? tokens.success : tokens.danger,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: tokens.mutedText,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
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
            'No equity data yet',
            style: TextStyle(
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
            'No equity data yet',
            style: TextStyle(
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
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(d),
                      style: TextStyle(
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
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      NumberFormat.compactCurrency(symbol: '\$')
                          .format(value),
                      style: TextStyle(
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
            label: 'Lifetime',
            value: '\$${comm.lifetime.toStringAsFixed(2)}',
            tokens: tokens,
          ),
        ),
        _SummaryVSep(tokens: tokens),
        Expanded(
          child: _SummaryCell(
            label: 'This month',
            value: '\$${comm.thisMonth.toStringAsFixed(2)}',
            tokens: tokens,
          ),
        ),
        _SummaryVSep(tokens: tokens),
        Expanded(
          child: _SummaryCell(
            label: 'Pending',
            value: '\$${comm.pending.toStringAsFixed(2)}',
            valueColor: tokens.warning,
            tokens: tokens,
          ),
        ),
        _SummaryVSep(tokens: tokens),
        Expanded(
          child: _SummaryCell(
            label: 'Settled',
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
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: tokens.mutedText,
            height: 1.0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
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
          label: 'Cycle',
          description: 'How often pending commissions are flushed to your wallet.',
          value: _capitalize(settle.cycle),
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Last settled',
          description: 'When the previous cycle ran.',
          value: settle.lastSettledAt.isEmpty ? '—' : _fmtDate(settle.lastSettledAt),
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Next payout',
          description: 'Projected date of the next cycle flush.',
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Due now',
        style: TextStyle(
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
          label: 'Commission',
          description: 'What copiers pay according to this plan.',
          value: plan.commissionLabel.isNotEmpty
              ? plan.commissionLabel
              : '${plan.commissionPercentage}%',
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Commission type',
          description: 'Per profitable trade vs subscription.',
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
          label: 'Minimum capital',
          description: 'Smallest account a copier can join with.',
          value: '\$${plan.minimumCapital.toStringAsFixed(2)}',
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Active / cap',
          description: 'Current copiers vs limit.',
          value: cap,
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Plan full',
          description: 'No new copiers until someone leaves.',
          value: plan.isFull ? 'Yes' : 'No',
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
          'STRATEGY DESCRIPTION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tokens.subText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          plan.strategyDescription.isNotEmpty
              ? plan.strategyDescription
              : '— Not provided. Edit the plan to add a public description for copiers.',
          style: TextStyle(
            fontSize: 13,
            color: tokens.bodyText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'RISK INFORMATION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tokens.subText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          plan.riskInformation.isNotEmpty
              ? plan.riskInformation
              : '— Not provided. Edit the plan to disclose drawdown and risk.',
          style: TextStyle(
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
    if (plan.copyingPaused) return 'Paused';
    return 'Active';
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
          label: 'Status',
          description: 'Broker / admin approval state.',
          value: _statusLabel(),
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Copying',
          description: 'Whether new master trades are replicated to copiers.',
          value: _copyingLabel(),
          valueColor: plan.copyingPaused
              ? tokens.warning
              : tokens.success,
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Server',
          description: 'Execution routing label.',
          value: _serverLabel(),
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Trading account',
          description: 'Account number used for this plan.',
          value: plan.tradingAccountNumber.isEmpty
              ? '—'
              : plan.tradingAccountNumber,
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Initial equity snapshot',
          description: 'Captured when the plan was approved (if recorded).',
          value: _initialEquity() == null
              ? '—'
              : '\$${_initialEquity()}',
          tokens: tokens,
        ),
        _Divider(tokens: tokens),
        _KeyValueRow(
          label: 'Created',
          description: 'Plan creation timestamp.',
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
        title: 'Plan created',
        description: 'Submitted for review.',
        date: plan.createdAt,
        kind: 'created',
        tokens: tokens,
      ));
    }
    if (plan.approvedAt.isNotEmpty) {
      events.add(_TimelineRowVM(
        title: 'Plan approved',
        description: 'Live for copiers to subscribe.',
        date: plan.approvedAt,
        kind: 'approved',
        tokens: tokens,
      ));
    }
    if (plan.copyingPaused && plan.copyingPausedAt.isNotEmpty) {
      events.add(_TimelineRowVM(
        title: 'Copying paused',
        description: 'No new master trades replicated.',
        date: plan.copyingPausedAt,
        kind: 'paused',
        tokens: tokens,
      ));
    }
    if (plan.status.toLowerCase() == 'inactive' ||
        plan.status.toLowerCase() == 'inactivated') {
      events.add(_TimelineRowVM(
        title: 'Plan inactivated',
        description: 'No longer accepting copiers.',
        date: plan.updatedAt,
        kind: 'inactive',
        tokens: tokens,
      ));
    }

    if (events.isEmpty) {
      return Text(
        'No timeline events',
        style: TextStyle(color: tokens.mutedText, fontSize: 13),
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
                margin: const EdgeInsets.only(top: 4),
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
          const SizedBox(width: 12),
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _fmt(event.date),
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.mutedText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.description,
                    style: TextStyle(
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? tokens.textPrimary,
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(height: 4),
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