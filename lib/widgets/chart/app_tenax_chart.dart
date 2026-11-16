import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tenax_chart/tenax_chart.dart';

import 'package:crm_app/screens/trading/view_models/account_controller.dart';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/services/chart/app_tenax_chart_data_source.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// The Tenax chart wired to this app: the stream-socket data source, the
/// brand's theme and a per-flavor storage key. Use this instead of
/// [TenaxChartView] directly anywhere in the app.
class AppTenaxChart extends StatefulWidget {
  const AppTenaxChart({
    super.key,
    required this.symbol,
    this.interval = '15m',
    this.allowOrderActions = true,
    this.controller,
  });

  final String symbol;
  final String interval;

  /// False draws orders read-only (no drag, no close) — used for the small
  /// inline chart on the edit and close screens.
  final bool allowOrderActions;
  final TenaxChartController? controller;

  /// On only for brands with `features.useNewChart` (tenax, proactive).
  static bool get isSupported => FlavorConfig.instance.useNewChart;

  @override
  State<AppTenaxChart> createState() => _AppTenaxChartState();
}

class _AppTenaxChartState extends State<AppTenaxChart> {
  final AppTenaxChartDataSource _dataSource = AppTenaxChartDataSource();

  // The trader's in-chart timeframe pick; kept here so the account-switch
  // remount below reopens on that timeframe instead of the default.
  late String _interval = widget.interval;

  @override
  void didUpdateWidget(AppTenaxChart old) {
    super.didUpdateWidget(old);
    if (old.interval != widget.interval) _interval = widget.interval;
  }

  void _onChartEvent(TenaxChartEvent event) {
    if (event is! TenaxSymbolChangeEvent) return;
    final interval = event.interval;
    if (interval == null || interval == _interval || !mounted) return;
    setState(() => _interval = interval);
  }

  void _showActionError(Object error) {
    if (!mounted) return;
    final text = error.toString().replaceFirst(RegExp(r'^\w*(Exception|Error): '), '');
    CustomToastService.show(
      message: text.isEmpty ? 'Chart action failed' : text,
      type: ToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = TenaxChartConfig(
      symbol: widget.symbol,
      interval: _interval,
      themeMode: isDark ? 'dark' : 'light',
      orders: TenaxOrdersOptions(
        allowDrag: widget.allowOrderActions,
        allowClose: widget.allowOrderActions,
      ),
      persistenceKey: 'tenax.chart.${FlavorConfig.instance.flavor.name}',
    );
    final accountController = Get.find<AccountController>();
    // A new key per account remounts the view: history is re-read with the
    // new account and the page re-mounts with that server's clock offset,
    // which the page cannot change after mount.
    return Obx(() {
      final accountNumber =
          accountController.activeMT5AccountRx.value?.metaAccountNumber ?? '';
      return TenaxChartView(
        key: ValueKey<String>('tenax-chart-$accountNumber'),
        config: config,
        dataSource: _dataSource,
        controller: widget.controller,
        onEvent: _onChartEvent,
        onActionError: _showActionError,
        placeholder: const Center(child: CircularProgressIndicator()),
      );
    });
  }
}
