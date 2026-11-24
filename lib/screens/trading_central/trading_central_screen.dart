import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/common/webview_screen.dart';
import 'package:crm_app/screens/trading_central/trading_central_model.dart';
import 'package:crm_app/screens/trading_central/trading_central_service.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';

/// Lists the Trading Central pages from `GET /api/user/trading-central`.
/// Unlocked pages open in an in-app WebView; locked ones (no url) send the
/// user to Deposit, and the list reloads on return in case it unlocked.
class TradingCentralScreen extends StatefulWidget {
  const TradingCentralScreen({super.key});

  @override
  State<TradingCentralScreen> createState() => _TradingCentralScreenState();
}

class _TradingCentralScreenState extends State<TradingCentralScreen> {
  late Future<TradingCentralSettings> _future;

  @override
  void initState() {
    super.initState();
    _future = TradingCentralService.fetch();
  }

  Future<void> _reload() async {
    final future = TradingCentralService.fetch();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // The FutureBuilder shows the error with a retry button.
    }
  }

  void _openPage(TradingCentralPage page) {
    Get.to(
      () => WebViewScreen(
        url: page.url,
        title: page.label,
        // Third-party site: the CRM token must not be sent to it.
        attachAuthToken: false,
      ),
    );
  }

  Future<void> _openDeposit() async {
    await Get.toNamed(AppPages.PAYMENT_METHOD);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LanguageService>();
    final fallbackTitle = lang.trf('trading_central_title', 'Trading Central');

    return FutureBuilder<TradingCentralSettings>(
      future: _future,
      builder: (context, snapshot) {
        final settings = snapshot.data;
        final title = (settings?.menuLabel.isNotEmpty ?? false)
            ? settings!.menuLabel
            : fallbackTitle;

        final Widget body;
        if (snapshot.connectionState != ConnectionState.done) {
          body = const _LoadingList();
        } else if (snapshot.hasError || settings == null) {
          body = _ErrorView(
            message: snapshot.error
                    ?.toString()
                    .replaceFirst('Exception: ', '') ??
                '',
            onRetry: _reload,
          );
        } else if (settings.pages.isEmpty) {
          body = _MessageView(
            icon: Icons.query_stats_rounded,
            message: lang.trf(
              'trading_central_empty',
              'No Trading Central tools are available right now.',
            ),
          );
        } else {
          body = RefreshIndicator(
            onRefresh: _reload,
            child: _PageList(
              settings: settings,
              onOpen: _openPage,
              onDeposit: _openDeposit,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(),
            title: Text(title),
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: SafeArea(top: false, child: body),
        );
      },
    );
  }
}

class _PageList extends StatelessWidget {
  final TradingCentralSettings settings;
  final ValueChanged<TradingCentralPage> onOpen;
  final VoidCallback onDeposit;

  const _PageList({
    required this.settings,
    required this.onOpen,
    required this.onDeposit,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LanguageService>();
    final needsFirstDeposit =
        settings.depositRequired && !settings.hasFirstDeposit;
    final leadingCount = needsFirstDeposit ? 1 : 0;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: settings.pages.length + leadingCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index < leadingCount) {
          return _InfoBanner(
            message: lang.trf(
              'trading_central_first_deposit_required',
              'Make your first deposit to unlock Trading Central.',
            ),
            onTap: onDeposit,
          );
        }
        final page = settings.pages[index - leadingCount];
        final isOpenable = settings.canAccess && page.canOpen;
        return isOpenable
            ? _UnlockedTile(page: page, onTap: () => onOpen(page))
            : _LockedTile(
                page: page,
                depositTotal: settings.depositTotal,
                onTap: onDeposit,
              );
      },
    );
  }
}

/// Material icon for each Trading Central page key; unknown keys fall back to
/// a generic analytics icon so new pages from the backend still render.
IconData _iconForPage(String key) {
  final k = key.toLowerCase();
  if (k.contains('calendar')) return Icons.calendar_month_rounded;
  if (k.contains('education')) return Icons.school_rounded;
  if (k.contains('technical')) return Icons.candlestick_chart_rounded;
  if (k.contains('buzz')) return Icons.campaign_rounded;
  if (k.contains('news')) return Icons.newspaper_rounded;
  if (k.contains('idea')) return Icons.lightbulb_outline_rounded;
  if (k.contains('alpha') || k.contains('signal')) {
    return Icons.trending_up_rounded;
  }
  return Icons.query_stats_rounded;
}

String _formatAmount(num value) =>
    '\$${NumberFormat.decimalPattern().format(value)}';

class _TileShell extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TileShell({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class _PageIcon extends StatelessWidget {
  final IconData icon;
  final bool locked;

  const _PageIcon({required this.icon, required this.locked});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = locked ? colors.onSurfaceVariant : colors.primary;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint, size: 24),
          ),
          if (locked)
            PositionedDirectional(
              end: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 10,
                    color: colors.surface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnlockedTile extends StatelessWidget {
  final TradingCentralPage page;
  final VoidCallback onTap;

  const _UnlockedTile({required this.page, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      button: true,
      child: _TileShell(
        onTap: onTap,
        child: Row(
          children: [
            _PageIcon(icon: _iconForPage(page.key), locked: false),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                page.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedTile extends StatelessWidget {
  final TradingCentralPage page;
  final num depositTotal;
  final VoidCallback onTap;

  const _LockedTile({
    required this.page,
    required this.depositTotal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lang = Get.find<LanguageService>();
    final hasTarget = page.minDeposit > 0;
    final progress =
        hasTarget ? (depositTotal / page.minDeposit).clamp(0, 1).toDouble() : 0.0;

    final subtitle = hasTarget
        ? lang
            .trf('trading_central_deposit_to_unlock', 'Deposit :amount to unlock')
            .replaceAll(':amount', _formatAmount(page.minDeposit))
        : lang.trf('trading_central_locked', 'Locked');

    return Semantics(
      button: true,
      child: _TileShell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PageIcon(icon: _iconForPage(page.key), locked: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _DepositChip(label: lang.trf('settings_deposit', 'Deposit')),
              ],
            ),
            if (hasTarget) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: colors.primary,
                  backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatAmount(depositTotal)} / ${_formatAmount(page.minDeposit)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DepositChip extends StatelessWidget {
  final String label;

  const _DepositChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_card_rounded, size: 16, color: colors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  final VoidCallback onTap;

  const _InfoBanner({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurface),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    final placeholder =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 76,
        decoration: BoxDecoration(
          color: placeholder,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LanguageService>();
    return _MessageView(
      icon: Icons.cloud_off_rounded,
      message: message.isNotEmpty
          ? message
          : lang.trf('general_something_went_wrong', 'Something went wrong'),
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(lang.trf('general_retry', 'Retry')),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _MessageView({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
