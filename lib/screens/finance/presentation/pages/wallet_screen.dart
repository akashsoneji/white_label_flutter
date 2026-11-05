import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';


import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance/presentation/pages/internal_transfer_screen.dart';
import 'package:crm_app/screens/finance/presentation/pages/payment_methods_screen.dart';
import 'package:crm_app/screens/wallet/view_models/wallet_controller.dart';
import 'package:crm_app/utils/navigation_helper.dart';
import '../../../../services/language_service.dart';
import '../../../../widgets/common_loading_widget.dart';
import '../../../../widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletController controller = Get.put(WalletController());
  final LanguageService languageService = Get.find<LanguageService>();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200.h) {
        controller.loadMoreTransactions();
      }
    });
    // Trigger fresh load on enter
    controller.fetchWalletData();
    controller.fetchWalletHistory(page: 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  final NumberFormat _amountFormat = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: EdgeInsetsDirectional.only(start: 10.w),
          child: AppBackButton(
            onPressed: () => NavigationHelper.safeBack(context: context),
          ),
        ),
        title: Text(
          languageService.tr('wallet_title'),
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Obx(() {
              final transactions = controller.visibleHistoryTransactions;
              // A tab can be empty while later pages (which may hold its
              // rows) are still being fetched — show a loader, not "empty".
              final isInitialLoading =
                  transactions.isEmpty &&
                  (controller.isHistoryLoading.value ||
                      controller.isLoadingMore.value);

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  await Future.wait([
                    controller.fetchWalletData(),
                    controller.fetchWalletHistory(page: 1),
                  ]);
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildWalletHeader()),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PinnedControlsDelegate(
                        // Taller when the active date-range chip is visible.
                        extent:
                            (controller.filterDateFrom.value.isNotEmpty ||
                                    controller.filterDateTo.value.isNotEmpty)
                                ? 54.h + 38.h
                                : 54.h,
                        child: _buildHistoryControls(),
                      ),
                    ),

                    if (isInitialLoading)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (transactions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 40.w,
                              vertical: 40.h,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48.sp,
                                  color: AppColors.textSecondary.withOpacity(
                                    0.5,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  languageService.tr(
                                    'transaction_history_no_transactions',
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Builder(
                        builder: (context) {
                          final groups = _groupByDay(transactions);
                          return SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 4.h,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _buildTransactionGroup(groups[index]),
                                childCount: groups.length,
                              ),
                            ),
                          );
                        },
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.h),
                          child: Center(
                            child:
                                controller.isLoadingMore.value
                                    ? CircularProgressIndicator(
                                      color: AppColors.primary,
                                    )
                                    : !controller.hasMore.value
                                    ? Text(
                                      languageService.tr(
                                        'wallet_screen_no_more_transactions_to_show',
                                      ),
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.sp,
                                      ),
                                    )
                                    : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),

          // Processing overlay (used for deposit, transfers)
          Obx(
            () =>
                controller.isLoading.value
                    ? CommonLoadingWidget(
                      message: languageService.tr('wallet_processing'),
                      size: 60.0,
                      color: AppColors.primary,
                      isFullScreen: true,
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Compact header that replaces the old hero card, two action buttons and
  /// three summary tiles: balance + wallet ID on the left, icon actions on
  /// the right, and an in/out flow bar summarising the selected period.
  Widget _buildWalletHeader() {
    return Obx(() {
      final walletId = controller.wallet.value?.walletId ?? '';

      return Container(
        margin: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageService.tr('wallet_history_current_balance'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          '\$${controller.balance.value}',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (walletId.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: walletId));
                            CustomToastService.showSuccess(
                              message: TranslationUtils.tr(
                                'wallet_screen_wallet_id_copied',
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${languageService.tr('wallet_wallet_id')} $walletId',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.copy_rounded,
                                size: 12.sp,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _buildHeaderAction(
                  icon: Icons.add_rounded,
                  label: languageService.tr('wallet_deposit_wallet'),
                  isPrimary: true,
                  // Passing the wallet id makes the Deposit screen preselect
                  // the wallet in "Deposit to" instead of the first MT5 account.
                  onTap:
                      () => Get.to(
                        () => PaymentMethodsScreen(accountNumber: walletId),
                      ),
                ),
                SizedBox(width: 10.w),
                _buildHeaderAction(
                  icon: Icons.swap_horiz_rounded,
                  label: languageService.tr('internal_transfer'),
                  isPrimary: false,
                  onTap:
                      () => Get.to(
                        () => const InternalTransferScreen(
                          preselectWallet: true,
                        ),
                      ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final foreground = isPrimary ? AppColors.onPrimary : AppColors.primary;
    return SizedBox(
      width: 58.w,
      child: Column(
        children: [
          Material(
            color:
                isPrimary
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.08),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 42.w,
                height: 42.w,
                child: Icon(icon, size: 20.sp, color: foreground),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5.sp,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Single strip: segmented status tabs + filter icon. The active date
  /// range (if any) shows as a removable chip underneath.
  Widget _buildHistoryControls() {
    return Obx(() {
      final selected = controller.selectedHistoryTab.value;
      final hasDateFilter =
          controller.filterDateFrom.value.isNotEmpty ||
          controller.filterDateTo.value.isNotEmpty;
      final from =
          controller.filterDateFrom.value.isNotEmpty
              ? controller.filterDateFrom.value
              : languageService.tr('wallet_screen_any');
      final to =
          controller.filterDateTo.value.isNotEmpty
              ? controller.filterDateTo.value
              : languageService.tr('wallet_screen_any');
      final tabs = [
        (
          tab: WalletHistoryTab.completed,
          label: languageService.tr('transaction_history_completed'),
          count: controller.completedTransactions.length,
        ),
        (
          tab: WalletHistoryTab.pending,
          label: languageService.tr('transaction_history_pending'),
          count: controller.pendingTransactions.length,
        ),
        (
          tab: WalletHistoryTab.rejected,
          label: languageService.tr('kyc_verification_rejected'),
          count: controller.rejectedTransactions.length,
        ),
      ];

      return Container(
        color: AppColors.background,
        padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatusSegmentedControl(tabs, selected),
                ),
                SizedBox(width: 8.w),
                Builder(
                  builder:
                      (buttonContext) => _buildSquareIconButton(
                        icon: Icons.tune_rounded,
                        tooltip: languageService.tr('wallet_screen_filters'),
                        onTap: () => _showFilterPopup(buttonContext),
                        highlighted: hasDateFilter,
                      ),
                ),
              ],
            ),
            if (hasDateFilter) ...[
              SizedBox(height: 8.h),
              _buildFilterChip(
                label:
                    '$from ${languageService.tr('pmam_trade_history_to')} $to',
                onDeleted: controller.clearFilters,
              ),
            ],
          ],
        ),
      );
    });
  }

  ({IconData icon, Color color}) _tabVisual(WalletHistoryTab tab) {
    switch (tab) {
      case WalletHistoryTab.completed:
        return (icon: Icons.check_circle_rounded, color: AppColors.success);
      case WalletHistoryTab.pending:
        return (icon: Icons.schedule_rounded, color: AppColors.warning);
      case WalletHistoryTab.rejected:
        return (icon: Icons.cancel_rounded, color: AppColors.error);
    }
  }

  /// Segmented control with a thumb that slides to the selected tab. Each
  /// tab carries its status colour (green / amber / red) on the icon, the
  /// thumb outline and the count pill.
  Widget _buildStatusSegmentedControl(
    List<({WalletHistoryTab tab, String label, int count})> tabs,
    WalletHistoryTab selected,
  ) {
    final selectedIndex = tabs.indexWhere((t) => t.tab == selected);
    final selectedColor = _tabVisual(selected).color;
    // -1, 0, 1 for three tabs; directional so RTL mirrors with the Row.
    final thumbX =
        tabs.length > 1 ? -1 + 2 * selectedIndex / (tabs.length - 1) : 0.0;

    return Container(
      height: 40.h,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.textFieldBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withOpacity(0.15)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional(thumbX, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / tabs.length,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(9.r),
                  border: Border.all(color: selectedColor.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: selectedColor.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children:
                tabs.map((t) {
                  final isSelected = t.tab == selected;
                  final visual = _tabVisual(t.tab);
                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (isSelected) return;
                          HapticFeedback.selectionClick();
                          controller.selectHistoryTab(t.tab);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(
                                      milliseconds: 200,
                                    ),
                                    transitionBuilder:
                                        (child, animation) => ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                    child:
                                        isSelected
                                            ? Padding(
                                              key: const ValueKey('icon'),
                                              padding:
                                                  EdgeInsetsDirectional.only(
                                                    end: 4.w,
                                                  ),
                                              child: Icon(
                                                visual.icon,
                                                size: 14.sp,
                                                color: visual.color,
                                              ),
                                            )
                                            : const SizedBox.shrink(
                                              key: ValueKey('none'),
                                            ),
                                  ),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(
                                      milliseconds: 200,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                      color:
                                          isSelected
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                    ),
                                    child: Text(t.label, maxLines: 1),
                                  ),
                                  SizedBox(width: 5.w),
                                  AnimatedContainer(
                                    duration: const Duration(
                                      milliseconds: 200,
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 18.w,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 5.w,
                                      vertical: 1.5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? visual.color
                                              : visual.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(
                                        10.r,
                                      ),
                                    ),
                                    child: Text(
                                      '${t.count}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : visual.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color:
            highlighted
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.r),
          child: SizedBox(
            width: 40.h,
            height: 40.h,
            child: Icon(
              icon,
              size: 18.sp,
              color: highlighted ? AppColors.onPrimary : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.textFieldBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: onDeleted,
            child: Icon(
              Icons.close,
              size: 12.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Dropdown panel anchored under the filter button instead of a bottom
  /// sheet, so the history stays visible behind it. Quick ranges apply on
  /// tap; a custom range needs Apply.
  void _showFilterPopup(BuildContext anchorContext) {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final screen = MediaQuery.sizeOf(context);
    final maxPanelWidth = screen.width - 32.w;
    final panelWidth = maxPanelWidth < 300.w ? maxPanelWidth : 300.w;
    // Open towards the side with room: a button on the right half aligns the
    // panel's right edge to it (works for both LTR and RTL layouts).
    final alignToRight = anchor.center.dx > screen.width / 2;
    final rawLeft = alignToRight ? anchor.right - panelWidth : anchor.left;
    final left =
        rawLeft.clamp(16.w, screen.width - panelWidth - 16.w).toDouble();
    final top = anchor.bottom + 6.h;

    final today = DateTime.now();
    String fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    final presets = [
      (label: languageService.tr('ibm_range_all_time'), from: '', to: ''),
      (
        label: languageService.tr('time_today'),
        from: fmt(today),
        to: fmt(today),
      ),
      (
        label: languageService.tr('ibm_last_7_days'),
        from: fmt(today.subtract(const Duration(days: 6))),
        to: fmt(today),
      ),
      (
        label: languageService.tr('ibm_last_30_days'),
        from: fmt(today.subtract(const Duration(days: 29))),
        to: fmt(today),
      ),
      (
        label: languageService.tr('time_this_month'),
        from: fmt(DateTime(today.year, today.month)),
        to: fmt(today),
      ),
    ];

    var customFrom = controller.filterDateFrom.value;
    var customTo = controller.filterDateTo.value;

    void apply(BuildContext dialogContext, String from, String to) {
      // yyyy-MM-dd compares correctly as a string; swap a reversed range.
      final isReversed =
          from.isNotEmpty && to.isNotEmpty && from.compareTo(to) > 0;
      controller.filterDateFrom.value = isReversed ? to : from;
      controller.filterDateTo.value = isReversed ? from : to;
      controller.applyFilters();
      Navigator.pop(dialogContext);
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.08),
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (_, __, ___, child) => child,
      pageBuilder: (dialogContext, animation, _) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: panelWidth,
              child: FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
                  alignment:
                      alignToRight ? Alignment.topRight : Alignment.topLeft,
                  child: Material(
                    color: AppColors.cardBackground,
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(14.r),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: screen.height - top - 16.h,
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(14.w),
                        child: StatefulBuilder(
                          builder: (panelContext, setPanelState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  languageService.tr('wallet_screen_date_range'),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Wrap(
                                  spacing: 6.w,
                                  runSpacing: 6.h,
                                  children:
                                      presets.map((preset) {
                                        final isActive =
                                            controller.filterDateFrom.value ==
                                                preset.from &&
                                            controller.filterDateTo.value ==
                                                preset.to;
                                        return InkWell(
                                          onTap:
                                              () => apply(
                                                dialogContext,
                                                preset.from,
                                                preset.to,
                                              ),
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10.w,
                                              vertical: 6.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isActive
                                                      ? AppColors.primary
                                                      : AppColors.textFieldBg,
                                              borderRadius:
                                                  BorderRadius.circular(16.r),
                                            ),
                                            child: Text(
                                              preset.label,
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isActive
                                                        ? AppColors.onPrimary
                                                        : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                                SizedBox(height: 12.h),
                                Divider(height: 1, color: AppColors.divider),
                                SizedBox(height: 12.h),
                                Text(
                                  languageService.tr('ibm_custom_range'),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDateField(
                                        label: languageService.tr(
                                          'internal_transfer_history_screen_from_date',
                                        ),
                                        value: customFrom,
                                        onTap: () async {
                                          final picked = await _pickDate(
                                            dialogContext,
                                          );
                                          if (picked != null) {
                                            setPanelState(
                                              () => customFrom = picked,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _buildDateField(
                                        label: languageService.tr(
                                          'internal_transfer_history_screen_to_date',
                                        ),
                                        value: customTo,
                                        onTap: () async {
                                          final picked = await _pickDate(
                                            dialogContext,
                                          );
                                          if (picked != null) {
                                            setPanelState(
                                              () => customTo = picked,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed:
                                            () => apply(dialogContext, '', ''),
                                        child: Text(
                                          languageService.tr('common_clear'),
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            () => apply(
                                              dialogContext,
                                              customFrom,
                                              customTo,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10.r),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10.h,
                                          ),
                                        ),
                                        child: Text(
                                          languageService.tr('common_apply'),
                                          style: TextStyle(
                                            color: AppColors.onPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _pickDate(BuildContext context) async {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark || AppColors.isDarkMode;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                isDark
                    ? ColorScheme.dark(
                      primary: AppColors.primary,
                      onPrimary: Colors.black,
                      surface: AppColors.cardBackground,
                      onSurface: AppColors.textPrimary,
                    )
                    : ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: AppColors.cardBackground,
                      onSurface: AppColors.textPrimary,
                    ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      return DateFormat('yyyy-MM-dd').format(picked);
    }
    return null;
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.textFieldBg,
          border: Border.all(color: AppColors.border.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? label : value,
                style: TextStyle(
                  fontSize: 12.sp,
                  color:
                      value.isEmpty
                          ? AppColors.textGrey
                          : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.calendar_today, size: 14.sp, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  String _formatSignedAmount(double amount) {
    final formatted = _amountFormat.format(amount.abs());
    return amount < 0 ? '-\$$formatted' : '+\$$formatted';
  }

  String _formatDate(DateTime? date, String pattern) {
    if (date == null) return '';
    return DateFormat(pattern).format(date.toLocal());
  }

  ({Color foreground, Color background}) _statusColors(String status) {
    final Color base;
    switch (status.toLowerCase()) {
      case 'completed':
      case 'approved':
      case 'success':
        base = AppColors.success;
        break;
      case 'processing':
        base = AppColors.primary;
        break;
      case 'rejected':
      case 'failed':
      case 'cancelled':
        base = AppColors.error;
        break;
      default:
        base = AppColors.warning;
    }
    return (foreground: base, background: base.withOpacity(0.12));
  }

  ({IconData icon, Color color}) _typeVisual(WalletHistoryEntry tx) {
    final type = tx.type.toLowerCase();
    if (type.contains('transfer')) {
      return (icon: Icons.swap_horiz, color: AppColors.primary);
    }
    if (type.contains('deposit') || (!type.contains('withdraw') && tx.isCredit)) {
      return (icon: Icons.arrow_downward, color: AppColors.success);
    }
    return (icon: Icons.arrow_upward, color: AppColors.error);
  }

  Widget _buildStatusBadge(String status, {double fontSize = 9}) {
    final colors = _statusColors(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        (status.isEmpty ? 'Pending' : status).toUpperCase(),
        style: TextStyle(
          fontSize: fontSize.sp,
          fontWeight: FontWeight.bold,
          color: colors.foreground,
        ),
      ),
    );
  }

  /// Groups consecutive entries that share a calendar day, preserving the
  /// API's ordering. Entries without a date fall into a header-less group.
  List<({String header, List<WalletHistoryEntry> items})> _groupByDay(
    List<WalletHistoryEntry> entries,
  ) {
    final groups = <({String header, List<WalletHistoryEntry> items})>[];
    for (final tx in entries) {
      final header = _formatDate(tx.date, 'dd MMM yyyy');
      if (groups.isNotEmpty && groups.last.header == header) {
        groups.last.items.add(tx);
      } else {
        groups.add((header: header, items: [tx]));
      }
    }
    return groups;
  }

  Widget _buildTransactionGroup(
    ({String header, List<WalletHistoryEntry> items}) group,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.header.isNotEmpty)
            Padding(
              padding: EdgeInsetsDirectional.only(start: 4.w, bottom: 6.h),
              child: Text(
                group.header.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Material(
            color: AppColors.cardBackground,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
              side: BorderSide(color: AppColors.border.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < group.items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 58.w,
                      color: AppColors.divider.withOpacity(0.5),
                    ),
                  _buildTransactionTile(group.items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(WalletHistoryEntry tx) {
    final visual = _typeVisual(tx);
    final amountColor = tx.isCredit ? AppColors.success : AppColors.error;
    final statusColor = _statusColors(tx.status).foreground;
    final statusText = tx.status.isEmpty ? 'Pending' : tx.status;
    final route = [tx.from, tx.to].where((s) => s.isNotEmpty).join('  →  ');
    final subtitle = [
      tx.reference,
      _formatDate(tx.date, 'hh:mm a'),
    ].where((s) => s.isNotEmpty).join(' · ');

    return InkWell(
      onTap: () => _showTransactionDetails(tx),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: visual.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(visual.icon, size: 17.sp, color: visual.color),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.type.isNotEmpty
                        ? tx.type
                        : languageService.tr('wallet_screen_transaction'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (route.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      route,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatSignedAmount(tx.amount),
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
                SizedBox(height: 3.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(WalletHistoryEntry tx) {
    final amountColor = tx.isCredit ? AppColors.success : AppColors.error;
    final dateText = _formatDate(tx.date, 'MMMM dd, yyyy hh:mm a');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsetsDirectional.fromSTEB(
            24.w,
            24.h,
            24.w,
            MediaQuery.of(context).padding.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    languageService.tr('ibm_transaction_details'),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Divider(color: AppColors.divider),
              SizedBox(height: 16.h),
              Center(
                child: Column(
                  children: [
                    Text(
                      _formatSignedAmount(tx.amount),
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _buildStatusBadge(tx.status, fontSize: 12),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              _buildDetailRow(
                languageService.tr('tw_reference_number'),
                tx.reference.isNotEmpty ? tx.reference : 'N/A',
              ),
              _buildDetailRow(
                languageService.tr('transaction_history_transaction_type'),
                tx.type.isNotEmpty ? tx.type : 'N/A',
              ),
              _buildDetailRow(
                languageService.tr('internal_transfer_history_from'),
                tx.from.isNotEmpty ? tx.from : 'N/A',
              ),
              _buildDetailRow(
                languageService.tr('pmam_trade_history_to'),
                tx.to.isNotEmpty ? tx.to : 'N/A',
              ),
              if (dateText.isNotEmpty)
                _buildDetailRow(
                  languageService.tr('wallet_screen_date_and_time'),
                  dateText,
                ),
              if (tx.reason.isNotEmpty)
                _buildDetailRow(
                  languageService.tr('order_history_screen_reason'),
                  tx.reason,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedControlsDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  _PinnedControlsDelegate({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedControlsDelegate oldDelegate) => true;
}

class ExampleNavigationScreen extends StatelessWidget {
  const ExampleNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Get.find<LanguageService>();
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Get.to(() => WalletScreen()),
          child: Text(languageService.tr('wallet_open_wallet')),
        ),
      ),
    );
  }
}
