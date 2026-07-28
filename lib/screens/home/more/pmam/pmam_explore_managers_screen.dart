import 'package:flutter/material.dart';
import '../../../../constants/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../constants/color.dart';
import '../../../../controllers/pmam/pmam_controller.dart';
import '../../../../models/pmam_model.dart';
import '../../../../routes/app_pages.dart';

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

class _PmamExploreManagersScreenState extends State<PmamExploreManagersScreen> {
  final PmamController _c = Get.find<PmamController>();
  final TextEditingController _searchCtrl = TextEditingController();

  String _sortKey = 'gain'; // gain | aum | investors | commission
  bool _sortDesc = true;
  bool _gridView = true;
  String _filter = 'all'; // all | enrolled | low_fee | featured

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadManagersDataTable();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Derived data ──────────────────────────────────────────────────────────

  List<PmamManager> get _visible {
    var list = _c.managersList.toList();

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (m) =>
                (m.managerName ?? '').toLowerCase().contains(q) ||
                m.managerCode.toLowerCase().contains(q),
          )
          .toList();
    }

    switch (_filter) {
      case 'enrolled':
        list = list.where((m) => m.isEnrolled).toList();
        break;
      case 'low_fee':
        list = list.where((m) => m.avgCommission <= 15).toList();
        break;
      case 'featured':
        list = list.where((m) => m.totalAum > 0).toList();
        break;
    }

    int cmp(PmamManager a, PmamManager b) {
      switch (_sortKey) {
        case 'aum':
          return a.totalAum.compareTo(b.totalAum);
        case 'investors':
          return a.totalInvestors.compareTo(b.totalInvestors);
        case 'commission':
          return a.avgCommission.compareTo(b.avgCommission);
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
      final loading = _c.isManagersLoading.value;
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () =>
            _c.loadManagersDataTable(search: _searchCtrl.text.trim()),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeroStrip()),
            SliverToBoxAdapter(child: _buildSearch()),
            SliverToBoxAdapter(child: _buildFilterRow()),
            SliverToBoxAdapter(child: _buildSortRow()),
            if (loading && _c.managersList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
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
          'Explore Fund Managers',
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
    final list = _c.managersList;
    final total = list.length;
    final aum = list.fold<double>(0, (s, m) => s + m.totalAum);
    final gain = list.isEmpty
        ? 0.0
        : list.fold<double>(0, (s, m) => s + m.profitPercentage) / list.length;
    final commission = list.isEmpty
        ? 0.0
        : list.fold<double>(0, (s, m) => s + m.avgCommission) / list.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _heroCard(
              label: 'Available\nManagers',
              value: '$total',
              sub: 'Browse all',
              icon: Icons.grid_view_rounded,
            ),
            SizedBox(width: 10.w),
            _heroCard(
              label: 'Community\nAUM',
              value: _fmtMoney(aum, compact: true),
              sub: 'Total locked',
              icon: Icons.account_balance_wallet_rounded,
            ),
            SizedBox(width: 10.w),
            _heroCard(
              label: 'Avg Gain',
              value: '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%',
              valueColor: gain >= 0 ? AppColors.green : AppColors.error,
              sub: 'Performance',
              icon: Icons.trending_up_rounded,
            ),
            SizedBox(width: 10.w),
            _heroCard(
              label: 'Avg\nCommission',
              value: '${commission.toStringAsFixed(2)}%',
              sub: 'Platform avg',
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
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary, fontSize: 13.sp),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search manager name or code…',
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
      ),
    );
  }

  // ── Filter chips ──────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    final filters = [
      ('all', 'All', _c.managersList.length),
      (
        'enrolled',
        'Enrolled',
        _c.managersList.where((m) => m.isEnrolled).length,
      ),
      (
        'low_fee',
        'Low Fee',
        _c.managersList.where((m) => m.avgCommission <= 15).length,
      ),
      (
        'featured',
        'Active',
        _c.managersList.where((m) => m.totalAum > 0).length,
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
          return 'AUM';
        case 'investors':
          return 'Investors';
        case 'commission':
          return 'Commission';
        case 'gain':
        default:
          return 'Gain %';
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
                    'Sort: ${sortLabel()}',
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
      ('gain', 'Gain %', Icons.trending_up_rounded),
      ('aum', 'AUM', Icons.account_balance_wallet_rounded),
      ('investors', 'Investors', Icons.group_rounded),
      ('commission', 'Commission', Icons.percent_rounded),
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
                    'Sort by',
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
                    label: Text(_sortDesc ? 'Highest first' : 'Lowest first'),
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

  // ── Manager cards ─────────────────────────────────────────────────────────

  Widget _buildGrid() {
    final managers = _visible;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 10.h,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _ManagerCard(manager: managers[i], compact: true),
          childCount: managers.length,
        ),
      ),
    );
  }

  Widget _buildList() {
    final managers = _visible;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
      sliver: SliverList.separated(
        itemCount: managers.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (_, i) =>
            _ManagerCard(manager: managers[i], compact: false),
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
            'No managers found',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Try adjusting your filters or search.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(fontSize: 13.sp, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

// ── Manager card widget ────────────────────────────────────────────────────

class _ManagerCard extends StatelessWidget {
  const _ManagerCard({required this.manager, required this.compact});

  final PmamManager manager;
  final bool compact;

  String get _initials {
    final name = (manager.managerName ?? '').trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  ({String label, Color bg, Color fg}) get _risk {
    // Heuristic: commission % as a risk proxy until backend ships risk band.
    final c = manager.avgCommission;
    if (c >= 35) {
      return (
        label: 'RISK 4',
        bg: const Color(0xFFFFEDD5),
        fg: const Color(0xFFC2410C),
      );
    }
    if (c >= 20) {
      return (
        label: 'RISK 3',
        bg: const Color(0xFFFEF9C3),
        fg: const Color(0xFFA16207),
      );
    }
    if (c >= 10) {
      return (
        label: 'RISK 2',
        bg: const Color(0xFFDBEAFE),
        fg: const Color(0xFF1D4ED8),
      );
    }
    return (
      label: 'RISK 1',
      bg: const Color(0xFFDCFCE7),
      fg: const Color(0xFF15803D),
    );
  }

  String _activeFor() {
    final raw = manager.memberSince;
    if (raw == null || raw.isEmpty) return 'Active';
    try {
      final d = DateTime.parse(raw);
      final days = DateTime.now().difference(d).inDays;
      if (days <= 0) return 'New';
      if (days < 30) return 'Active ${days}D';
      if (days < 365) return 'Active ${(days / 30).floor()}M';
      return 'Active ${(days / 365).floor()}Y';
    } catch (_) {
      return 'Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final gain = manager.profitPercentage;
    final gainColor = gain > 0
        ? AppColors.green
        : gain < 0
        ? AppColors.error
        : AppColors.textPrimary;

    final hasInvestment = manager.isEnrolled;
    final risk = _risk;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          Get.toNamed(
            AppPages.PMAM_FUND_MANAGER_VIEW,
            arguments: manager.managerCode,
          );
        },
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
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: Text(
                      _initials,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),

                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          manager.managerName ?? '—',
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
                          _activeFor(),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
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

              // Metrics 2×2
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      'TOTAL GAIN',
                      '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(0)}%',
                      gainColor,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      'MAX DRAWDOWN',
                      '-${manager.maxDrawdown.toStringAsFixed(0)}%',
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
                      'TOTAL P&L',
                      '+\$${manager.totalAum.toStringAsFixed(2)}',
                      AppColors.green,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      'MIN INVESTMENT',
                      _minInvestment(),
                      AppColors.textPrimary,
                      bold: true,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8.h),
              // Footer row: fee + investors
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Fee: ',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          color: AppColors.textGrey,
                        ),
                      ),
                      Text(
                        '${manager.avgCommission.toStringAsFixed(0)}%',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.group, size: 12.sp, color: AppColors.textGrey),
                      SizedBox(width: 4.w),
                      Text(
                        '${manager.totalInvestors}',
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
              InkWell(
                onTap: () {
                  if (hasInvestment) {
                    Get.toNamed(
                      Routes.PMAM_MY_INVESTMENT,
                      arguments: {'managerCode': manager.managerCode},
                    );
                  } else {
                    Get.toNamed(
                      AppPages.PMAM_FUND_MANAGER_VIEW,
                      arguments: manager.managerCode,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: hasInvestment
                        ? const Color(0xFF10B981)
                        : 
                        // AppColors.isDarkMode
                        // ? AppColors.primary.withValues(alpha: 0.2)
                        // : AppColors.brandPrimary,
                        AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasInvestment) ...[
                        Icon(
                          Icons.pie_chart_rounded,
                          size: 14.sp,
                          color: AppColors.onColoredBackground,
                        ),
                        SizedBox(width: 6.w),
                      ],
                      Text(
                        hasInvestment ? 'My Investment' : 'View Details',
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.onColoredBackground,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _minInvestment() {
    if (manager.plans.isEmpty) return '\$—';
    final min = manager.plans
        .map((p) => p.minimumInvestment)
        .reduce((a, b) => a < b ? a : b);
    if (min >= 1000) return '\$${(min / 1000).toStringAsFixed(0)}K';
    return '\$${min.toStringAsFixed(0)}';
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
