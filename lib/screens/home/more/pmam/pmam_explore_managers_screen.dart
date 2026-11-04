import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/widgets/responsive_layout.dart';
import 'package:get/get.dart';

import '../../../../constants/color.dart';
import '../../../../controllers/pmam/pmam_controller.dart';
import '../../../../models/pmam_model.dart';
import '../../../../routes/app_pages.dart';
import 'package:crm_app/services/language_service.dart';

/// Mobile-first "Explore Fund Managers" screen.
///
/// Hero KPI strip (Available Managers, Community AUM, Avg Gain, Avg
/// Commission) + filter chips + sort/view-mode controls + a list of manager
/// cards. Supports grid + list view, dark mode, pull-to-refresh.
class PmamExploreManagersScreen extends StatefulWidget {
  const PmamExploreManagersScreen({super.key, this.embedded = false});

  /// When true, the screen renders without its own Scaffold/AppBar so it can
  /// be embedded inside the PMAM main IndexedStack.
  final bool embedded;

  @override
  State<PmamExploreManagersScreen> createState() =>
      _PmamExploreManagersScreenState();
}

class _SearchOptionTile extends StatelessWidget {
  final PmamSearchOption option;
  final VoidCallback onTap;

  const _SearchOptionTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        child: Row(
          children: [
            Icon(
              option.isPlan ? Icons.layers_outlined : Icons.person_outline,
              size: 16.sp,
              color: AppColors.textGrey,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                option.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (option.subtitle.isNotEmpty) ...[
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  option.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PmamExploreManagersScreenState extends State<PmamExploreManagersScreen> {
  final PmamController _c = Get.find<PmamController>();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String _sortKey = 'gain'; // gain | aum | investors | commission
  bool _sortDesc = true;
  bool _gridView = true;
  String _filter = 'all'; // all | enrolled | low_fee | featured

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadExplorePlans();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _c.clearSearchOptions();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _c.searchExploreOptions(value),
    );
  }

  /// Guide step 1: a picked manager / plan filters the plan table.
  void _pickOption(PmamSearchOption option) {
    FocusScope.of(context).unfocus();
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {});
    _c.applyExploreFilter(option);
  }

  // ── Derived data ──────────────────────────────────────────────────────────

  List<PmamExplorePlan> get _visible {
    var list = _c.explorePlans.toList();

    switch (_filter) {
      case 'enrolled':
        list = list.where((p) => p.isEnrolled).toList();
        break;
      case 'low_fee':
        list = list.where((p) => p.commissionPercentage <= 15).toList();
        break;
      case 'featured':
        list = list.where((p) => p.totalAum > 0).toList();
        break;
    }

    int cmp(PmamExplorePlan a, PmamExplorePlan b) {
      switch (_sortKey) {
        case 'aum':
          return a.totalAum.compareTo(b.totalAum);
        case 'investors':
          return a.activeInvestors.compareTo(b.activeInvestors);
        case 'commission':
          return a.commissionPercentage.compareTo(b.commissionPercentage);
        case 'gain':
        default:
          return a.profitPercentage.compareTo(b.profitPercentage);
      }
    }

    list.sort((a, b) => _sortDesc ? cmp(b, a) : cmp(a, b));
    return list;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      final loading = _c.isExploreLoading.value;
      final error = _c.exploreError.value;
      // Read the filters so Obx rebuilds when they change.
      _c.exploreManagerFilter.value;
      _c.explorePlanFilter.value;
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _c.loadExplorePlans,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeroStrip()),
            SliverToBoxAdapter(child: _buildSearch()),
            SliverToBoxAdapter(child: _buildFilterRow()),
            SliverToBoxAdapter(child: _buildSortRow()),
            if (loading && _c.explorePlans.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (error.isNotEmpty && _c.explorePlans.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildError(error),
              )
            else if (_visible.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _buildEmpty())
            else
              _gridView ? _buildGrid() : _buildList(),
            SliverToBoxAdapter(child: SizedBox(height: 24.h)),
          ],
        ),
      );
    });

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: Text(
          TranslationUtils.tr(
              'pmam_explore_managers_screen_explore_fund_managers'),
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: body,
    );
  }

  // ── Hero KPI strip ────────────────────────────────────────────────────────

  Widget _buildHeroStrip() {
    final list = _c.explorePlans;
    final total = list.length;
    final aum = list.fold<double>(0, (s, p) => s + p.totalAum);
    final gain = list.isEmpty
        ? 0.0
        : list.fold<double>(0, (s, p) => s + p.profitPercentage) / list.length;
    final commission = list.isEmpty
        ? 0.0
        : list.fold<double>(0, (s, p) => s + p.commissionPercentage) /
            list.length;

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(12.w, 12.h, 12.w, 4.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _heroCard(
              label: TranslationUtils.tr('pmam_available_plans'),
              value: '$total',
              sub: TranslationUtils.tr('pmam_browse_all'),
              icon: Icons.grid_view_rounded,
            ),
            SizedBox(width: 10.w),
            _heroCard(
              label: TranslationUtils.tr('pmam_community_aum'),
              value: _fmtMoney(aum, compact: true),
              sub: TranslationUtils.tr('pmam_total_locked'),
              icon: Icons.account_balance_wallet_rounded,
            ),
            SizedBox(width: 10.w),
            _heroCard(
              label: TranslationUtils.tr('pmam_avg_gain'),
              value: '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%',
              valueColor: gain >= 0 ? AppColors.green : AppColors.error,
              sub: TranslationUtils.tr('portfolio_performance'),
              icon: Icons.trending_up_rounded,
            ),
            SizedBox(width: 10.w),
            _heroCard(
              label: TranslationUtils.tr('pmam_avg_commission'),
              value: '${commission.toStringAsFixed(2)}%',
              sub: TranslationUtils.tr('pmam_platform_avg'),
              icon: Icons.percent_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    Color? valueColor,
  }) {
    return Container(
      width: 170.w,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: AppColors.isDarkMode
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.onColoredBackground,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sub,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 9.sp,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Widget _buildSearch() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 6.h),
      child: Column(
        children: [
          _buildSearchField(),
          _buildActiveFilters(),
          Obx(() {
            final options = _c.searchOptions.toList();
            if (options.isEmpty || _searchCtrl.text.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              margin: EdgeInsets.only(top: 6.h),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final option in options)
                    _SearchOptionTile(
                      option: option,
                      onTap: () => _pickOption(option),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary, fontSize: 13.sp),
        decoration: InputDecoration(
          isDense: true,
          hintText: TranslationUtils.tr(
              'pmam_explore_managers_screen_search_manager_name_or_code'),
          hintStyle: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey, fontSize: 13.sp),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.textGrey,
            size: 18.sp,
          ),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
    );
  }

  /// Chips for the manager / plan filter currently applied to the table.
  Widget _buildActiveFilters() {
    return Obx(() {
      final manager = _c.exploreManagerFilter.value;
      final plan = _c.explorePlanFilter.value;
      if (manager == null && plan == null) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          children: [
            if (manager != null)
              _filterChip(
                Icons.person_outline,
                manager.title,
                () => _c.clearExploreFilter(plan: false),
              ),
            if (plan != null)
              _filterChip(
                Icons.layers_outlined,
                plan.title,
                () => _c.clearExploreFilter(plan: true),
              ),
          ],
        ),
      );
    });
  }

  Widget _filterChip(IconData icon, String label, VoidCallback onClear) {
    return InputChip(
      avatar: Icon(icon, size: 14.sp, color: AppColors.primary),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyText.copyWith(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      backgroundColor: AppColors.card,
      side: BorderSide(color: AppColors.primary),
      deleteIconColor: AppColors.textGrey,
      onDeleted: onClear,
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Filter chips ──────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    final filters = [
      ('all', TranslationUtils.tr('common_all'), _c.explorePlans.length),
      (
        'enrolled',
        TranslationUtils.tr('dc_enrolled'),
        _c.explorePlans.where((p) => p.isEnrolled).length,
      ),
      (
        'low_fee',
        TranslationUtils.tr('pmam_low_fee'),
        _c.explorePlans.where((p) => p.commissionPercentage <= 15).length,
      ),
      (
        'featured',
        TranslationUtils.tr('chart_active'),
        _c.explorePlans.where((p) => p.totalAum > 0).length,
      ),
    ];
    return SizedBox(
      height: 38.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, i) {
          final (k, label, count) = filters[i];
          final selected = _filter == k;
          return GestureDetector(
            onTap: () => setState(() => _filter = k),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.isDarkMode
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.primary
                    : AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.isDarkMode?AppColors.primary:AppColors.whiteColor
                          : AppColors.textGreyLight,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.onColoredBackground
                            : AppColors.textGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Sort + view-mode ──────────────────────────────────────────────────────

  Widget _buildSortRow() {
    String sortLabel() {
      switch (_sortKey) {
        case 'aum':
          return TranslationUtils.tr('pmam_aum');
        case 'investors':
          return TranslationUtils.tr('pmam_nav_investors');
        case 'commission':
          return TranslationUtils.tr('general_commission');
        case 'gain':
        default:
          return TranslationUtils.tr('pmam_gain_percent');
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _showSortSheet,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, size: 14.sp, color: AppColors.textGrey),
                  SizedBox(width: 6.w),
                  Text(
                    '${TranslationUtils.tr('pmam_sort')}: ${sortLabel()}',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    _sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 12.sp,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _viewModeBtn(true, Icons.grid_view_rounded),
          SizedBox(width: 6.w),
          _viewModeBtn(false, Icons.view_agenda_rounded),
        ],
      ),
    );
  }

  Widget _viewModeBtn(bool grid, IconData icon) {
    final active = _gridView == grid;
    return GestureDetector(
      onTap: () => setState(() => _gridView = grid),
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.1) : AppColors.card,
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16.sp,
          color: active ? AppColors.primary : AppColors.textGrey,
        ),
      ),
    );
  }

  void _showSortSheet() {
    final options = [
      (
        'gain',
        TranslationUtils.tr('pmam_gain_percent'),
        Icons.trending_up_rounded
      ),
      (
        'aum',
        TranslationUtils.tr('pmam_aum'),
        Icons.account_balance_wallet_rounded
      ),
      (
        'investors',
        TranslationUtils.tr('pmam_nav_investors'),
        Icons.group_rounded
      ),
      (
        'commission',
        TranslationUtils.tr('general_commission'),
        Icons.percent_rounded
      ),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Text(
                    TranslationUtils.tr('instruments_screen_sort_by'),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _sortDesc = !_sortDesc);
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      _sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 14.sp,
                    ),
                    label: Text(_sortDesc
                        ? TranslationUtils.tr('pmam_highest_first')
                        : TranslationUtils.tr('pmam_lowest_first')),
                  ),
                ],
              ),
            ),
            ...options.map((o) {
              final (k, label, icon) = o;
              final selected = _sortKey == k;
              return ListTile(
                leading: Icon(
                  icon,
                  color: selected ? AppColors.primary : AppColors.textGrey,
                ),
                title: Text(
                  label,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortKey = k);
                  Navigator.pop(context);
                },
              );
            }),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  // ── Plan cards ────────────────────────────────────────────────────────────

  Widget _buildGrid() {
    final plans = _visible;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 10.h,
          childAspectRatio: ResponsiveGrid.aspectRatio(0.58),
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _PlanCard(plan: plans[i], compact: true),
          childCount: plans.length,
        ),
      ),
    );
  }

  Widget _buildList() {
    final plans = _visible;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
      sliver: SliverList.separated(
        itemCount: plans.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (_, i) => _PlanCard(plan: plans[i], compact: false),
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40.sp, color: AppColors.error),
          SizedBox(height: 12.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: _c.loadExplorePlans,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(TranslationUtils.tr('common_retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.travel_explore_rounded,
              size: 40.sp,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            TranslationUtils.tr('pmam_explore_managers_screen_no_managers_found'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            TranslationUtils.tr(
                'pmam_explore_managers_screen_try_adjusting_your_filters_or_search'),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

// ── Plan card widget (one row of plans/datatable) ──────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.compact});

  final PmamExplorePlan plan;
  final bool compact;

  String get _initials {
    final name = plan.managerName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// `risk_score` from the API (1 when the manager did not set one).
  ({String label, Color bg, Color fg}) get _risk {
    final score = plan.riskScore.clamp(1, 4);
    final fg = switch (score) {
      4 => AppColors.error,
      3 => AppColors.warning,
      2 => AppColors.primary,
      _ => AppColors.green,
    };
    return (
      label: TranslationUtils.tr('pmam_risk_$score'),
      bg: fg.withValues(alpha: 0.12),
      fg: fg,
    );
  }

  String _activeFor() {
    final raw = plan.memberSince;
    if (raw == null || raw.isEmpty) return TranslationUtils.tr('chart_active');
    final d = DateTime.tryParse(raw);
    if (d == null) return TranslationUtils.tr('chart_active');
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return TranslationUtils.tr('ibm_new');
    if (days < 30) {
      return TranslationUtils.trArgs('pmam_active_days', {'days': '$days'});
    }
    if (days < 365) {
      return TranslationUtils.trArgs(
          'pmam_active_months', {'months': '${(days / 30).floor()}'});
    }
    return TranslationUtils.trArgs(
        'pmam_active_years', {'years': '${(days / 365).floor()}'});
  }

  void _openProfile() {
    Get.toNamed(
      AppPages.PMAM_FUND_MANAGER_VIEW,
      arguments: {'manager_code': plan.managerCode, 'plan_id': plan.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final gain = plan.profitPercentage;
    final gainColor = gain > 0
        ? AppColors.green
        : gain < 0
        ? AppColors.error
        : AppColors.textPrimary;
    final risk = _risk;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _openProfile,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      _initials,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.planName.isEmpty ? '—' : plan.planName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          plan.managerName.isEmpty
                              ? plan.managerCode
                              : plan.managerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: AppColors.textGreyLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _activeFor(),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact || !plan.isEnrolled)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: risk.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        risk.label,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: risk.fg,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 10.h),
              Divider(height: 1, color: AppColors.border),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      TranslationUtils.tr('copy_trading_total_gain'),
                      '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%',
                      gainColor,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      TranslationUtils.tr('pmam_max_drawdown_caps'),
                      '-${plan.maxDrawdown.abs().toStringAsFixed(2)}%',
                      AppColors.error,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      TranslationUtils.tr('pmam_aum'),
                      _fmtMoney(plan.totalAum, compact: true),
                      AppColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      TranslationUtils.tr('pmam_min_investment_caps'),
                      _fmtMoney(plan.minimumInvestment, compact: true),
                      AppColors.textPrimary,
                      bold: true,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${TranslationUtils.tr('pmam_explore_managers_screen_fee')} ',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                      Text(
                        '${plan.commissionPercentage.toStringAsFixed(0)}%',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (!plan.hideInvestors)
                    Row(
                      children: [
                        Icon(Icons.group, size: 12.sp, color: AppColors.textGrey),
                        SizedBox(width: 4.w),
                        Text(
                          '${plan.activeInvestors}',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 11.sp,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              SizedBox(height: 8.h),
              _actionButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// `is_enrolled` → "Invested" (opens My Investments) instead of Invest.
  Widget _actionButton() {
    final invested = plan.isEnrolled;
    return InkWell(
      onTap: invested
          ? () => Get.toNamed(
                Routes.PMAM_MY_INVESTMENT,
                arguments: {'managerCode': plan.managerCode},
              )
          : _openProfile,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: invested ? AppColors.green : AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              invested ? Icons.check_circle_rounded : Icons.trending_up_rounded,
              size: 14.sp,
              color: AppColors.onColoredBackground,
            ),
            SizedBox(width: 6.w),
            Text(
              invested
                  ? TranslationUtils.tr('pmam_invested')
                  : TranslationUtils.tr('pmam_invest'),
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.onColoredBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    String value,
    Color valueColor, {
    bool bold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textGrey,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.sp,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

String _fmtMoney(double v, {bool compact = false}) {
  if (compact) {
    if (v.abs() >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
  }
  return '\$${v.toStringAsFixed(2)}';
}
