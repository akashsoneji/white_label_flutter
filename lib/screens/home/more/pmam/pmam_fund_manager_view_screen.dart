import 'package:crm_app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../constants/color.dart';
import '../../../../services/pmam_service.dart';
import '../../../../controllers/pmam/pmam_controller.dart';
import '../../../../widgets/app_select_field.dart';
import '../../../../widgets/common_loading_widget.dart';
import '../../../../widgets/app_svg_back_button.dart';

class PmamFundManagerViewScreen extends StatefulWidget {
  const PmamFundManagerViewScreen({super.key});

  @override
  State<PmamFundManagerViewScreen> createState() =>
      _PmamFundManagerViewScreenState();
}

class _PmamFundManagerViewScreenState extends State<PmamFundManagerViewScreen> {
  String _managerCode = '';
  late PmamController _ctrl;

  bool _loadingProfile = true;
  bool _loadingTrades = false;
  bool _loadingOpen = false;

  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _selectedPlan;

  List<Map<String, dynamic>> _trades = [];
  List<Map<String, dynamic>> _openPositions = [];

  bool _showAllOpenPositions = false;
  bool _showAllTrades = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is String) {
      _managerCode = args;
    } else if (args is Map && args['manager_code'] is String) {
      _managerCode = args['manager_code'] as String;
    }
    if (Get.isRegistered<PmamController>()) {
      _ctrl = Get.find<PmamController>();
    } else {
      _ctrl = Get.put(PmamController());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    if (_managerCode.isEmpty) {
      setState(() => _loadingProfile = false);
      return;
    }
    setState(() => _loadingProfile = true);
    try {
      if (_ctrl.myInvestments.isEmpty) {
        // Load investor portal silently in background so that `myInvestments` gets populated
        _ctrl.loadInvestorPortal().then((_) {
          if (mounted) setState(() {});
        });
      }
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
    } finally {
      if (mounted) {
        setState(() {
          _loadingOpen = false;
          _loadingTrades = false;
        });
      }
    }
  }

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
    final val = v.abs();
    final prefix = v < 0 ? '-\$' : '\$';
    if (val >= 1000000) return '$prefix${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '$prefix${(val / 1000).toStringAsFixed(2)}K';
    return '$prefix${val.toStringAsFixed(2)}';
  }

  void _showInvestSheet(BuildContext btnCtx) {
    if (_selectedPlan == null) {
      Get.snackbar(
        'Not Available',
        'This manager has no active plans to invest in.',
        backgroundColor: Colors.orange,
        colorText: AppColors.onColoredBackground,
      );
      return;
    }
    Map<String, dynamic>? selectedAccount;
    Map<String, dynamic>? sheetPlan = _selectedPlan;
    bool accountsLoading = true;
    bool firstLoadTriggered = false;

    final planId = int.tryParse(sheetPlan!['id'].toString()) ?? 0;

    late StateSetter _setSheetState;

    void _loadAccounts(int pId) async {
      _setSheetState(() => accountsLoading = true);
      await _ctrl.loadEligibleAccounts(pId);
      if (_ctrl.eligibleAccounts.length == 1) {
        selectedAccount = _ctrl.eligibleAccounts.first;
      }
      _setSheetState(() => accountsLoading = false);
    }

    showModalBottomSheet(
      context: btnCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          _setSheetState = setSheetState;

          // Trigger first load only once
          if (!firstLoadTriggered && planId > 0) {
            firstLoadTriggered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadAccounts(planId);
            });
          }

          final double commission = _num(sheetPlan!['commission_percentage']);
          final double minInvest = _num(sheetPlan!['minimum_investment']);
          final String planName = (sheetPlan!['plan_name'] ?? 'Plan')
              .toString();

          final double availBalance =
              double.tryParse(
                selectedAccount?['available_balance']?.toString() ?? '0',
              ) ??
              0;
          final double accBalance =
              double.tryParse(selectedAccount?['balance']?.toString() ?? '0') ??
              0;
          final String accNo =
              selectedAccount?['meta_account_number']?.toString() ?? '';
          final bool isBalanceEnough = availBalance >= minInvest;
          final bool canInvest = isBalanceEnough && selectedAccount != null;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 12.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Invest in Plan',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close,
                            size: 22.sp,
                            color: AppColors.textGrey,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.border),

                  // ── Body ──
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Select Plan ──
                        Text(
                          'Select Plan',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        if (_plans.length > 1)
                          AppSelectField<Map<String, dynamic>>(
                            value: sheetPlan,
                            hint: 'Select a plan',
                            sheetTitle: 'Select Plan',
                            backgroundColor: AppColors.card,
                            valueEquals: (a, b) =>
                                a['id'].toString() == b['id'].toString(),
                            options: _plans.map((p) {
                              final pName = (p['plan_name'] ?? 'Plan')
                                  .toString();
                              final pComm = _num(p['commission_percentage']);
                              return AppSelectOption<Map<String, dynamic>>(
                                value: p,
                                title:
                                    '$pName - ${pComm.toStringAsFixed(2)}% Commission',
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() {
                                  sheetPlan = val;
                                  selectedAccount = null;
                                });
                                final newPlanId =
                                    int.tryParse(val['id'].toString()) ?? 0;
                                if (newPlanId > 0) {
                                  _loadAccounts(newPlanId);
                                }
                              }
                            },
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 13.h,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: AppColors.border),
                              color: AppColors.onColoredBackground,
                            ),
                            child: Text(
                              '$planName - ${commission.toStringAsFixed(2)}% Commission',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.isDarkMode
                                    ? AppColors.pureBlack
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        SizedBox(height: 6.h),
                        Text(
                          'Min. Investment: \$${minInvest.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // ── Trading Account ──
                        Text(
                          'Trading Account',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        if (accountsLoading)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.h),
                              child: CommonLoadingWidget(
                                size: 22,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        else
                          AppSelectField<Map<String, dynamic>>(
                            value: selectedAccount,
                            hint: 'Select Account',
                            sheetTitle: 'Select Trading Account',
                            backgroundColor: AppColors.card,
                            valueEquals: (a, b) => a['id'] == b['id'],
                            options: _ctrl.eligibleAccounts.map((acc) {
                              final no =
                                  acc['meta_account_number']?.toString() ?? '-';
                              final bal =
                                  double.tryParse(
                                    acc['balance']?.toString() ?? '0',
                                  ) ??
                                  0;
                              final avail =
                                  double.tryParse(
                                    acc['available_balance']?.toString() ?? '0',
                                  ) ??
                                  0;
                              return AppSelectOption<Map<String, dynamic>>(
                                value: acc,
                                title:
                                    '$no — Balance: \$${bal.toStringAsFixed(2)} (Available: \$${avail.toStringAsFixed(2)})',
                              );
                            }).toList(),
                            onChanged: (val) {
                              setSheetState(() => selectedAccount = val);
                            },
                          ),

                        // ── Validation Error ──
                        if (selectedAccount != null && !isBalanceEnough)
                          Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14.sp,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Text(
                                    'Insufficient balance for this plan.',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Full balance text ──
                        if (selectedAccount != null) ...[
                          SizedBox(height: 12.h),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textGrey,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Full balance will be invested: ',
                                ),
                                TextSpan(
                                  text: '\$${availBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 20.h),

                        // ── Summary card ──
                        if (selectedAccount != null)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _summaryRow('Plan', planName, isFirst: true),
                                _summaryDivider(),
                                _summaryRow(
                                  'Commission',
                                  '${commission.toStringAsFixed(2)}%',
                                ),
                                _summaryDivider(),
                                _summaryRow(
                                  'Min. Investment',
                                  '\$${minInvest.toStringAsFixed(2)}',
                                ),
                                _summaryDivider(),
                                _summaryRow(
                                  'Investment Amount',
                                  '\$${availBalance.toStringAsFixed(2)}',
                                  valueColor: AppColors.textPrimary,
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),
                  Divider(height: 1, color: AppColors.border),

                  // ── Bottom buttons ──
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 16.h,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 13.h),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: canInvest
                                  ? () {
                                      final curPlanId =
                                          int.tryParse(
                                            sheetPlan!['id'].toString(),
                                          ) ??
                                          0;
                                      Navigator.pop(ctx);
                                      _ctrl.joinPlan(
                                        selectedAccount!['id'],
                                        curPlanId,
                                        availBalance,
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.textPrimary,
                                disabledBackgroundColor: AppColors.textPrimary
                                    .withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 13.h),
                                elevation: 0,
                              ),
                              child: Text(
                                'Confirm Investment',
                                style: TextStyle(
                                  color: AppColors.isDarkMode
                                      ? AppColors.pureBlack
                                      : AppColors.onColoredBackground,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Divider(height: 1, color: AppColors.border);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.card,
        elevation: 0,
        centerTitle: true,
        leading: AppSvgBackButton(
          onPressed: () => Get.back(),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
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
          ? const Center(child: CircularProgressIndicator())
          : _profile.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                children: [
                  _buildTopCard(),
                  SizedBox(height: 16.h),
                  _buildPerformanceChart(),
                  SizedBox(height: 16.h),
                  _buildOpenPositionsSection(),
                  SizedBox(height: 16.h),
                  _buildTradeHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildTopCard() {
    final name = (_profile['manager_name'] ?? '—').toString();
    final since = (_profile['member_since'] ?? '').toString();
    final s = (_profile['performance_summary'] is Map)
        ? Map<String, dynamic>.from(_profile['performance_summary'] as Map)
        : <String, dynamic>{};

    final profit = _num(s['total_profit']);
    final pnl = _num(s['total_pnl_value']);
    final aum = _num(_profile['total_aum']);
    final investors = _num(_profile['total_investors']).toInt();

    double commission = 0;
    double minInv = 0;
    String risk = 'Risk 1';
    double drawdown = 0;
    String description = '';

    if (_selectedPlan != null) {
      commission = _num(_selectedPlan!['commission_percentage']);
      minInv = _num(_selectedPlan!['minimum_investment']);
      risk = (_selectedPlan!['risk_information'] ?? 'Risk 1').toString();
      description = (_selectedPlan!['strategy_description'] ?? '').toString();
      if (_selectedPlan!['performance'] is Map) {
        drawdown = _num(_selectedPlan!['performance']['max_drawdown']);
      }
    }

    final hasInvestment = _profile['is_enrolled'] == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 26.r,
                          backgroundColor: AppColors.chipSurface,
                          child: Text(
                            _initials,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.onColoredBackground,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.check_circle,
                              size: 16.sp,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.chipSurface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'FUND MANAGER',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  '• Member since $since',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield,
                            size: 12.sp,
                            color: const Color(0xFFD97706),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            risk,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!hasInvestment) {
                        _showInvestSheet(context);
                      } else {
                        Get.toNamed(
                          Routes.PMAM_MY_INVESTMENT,
                          arguments: {'managerCode': _managerCode},
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasInvestment
                          ? const Color(0xFF10B981)
                          : AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      hasInvestment ? 'My Investment' : 'INVEST NOW',
                      style: TextStyle(
                        color: AppColors.isDarkMode
                            ? AppColors.pureBlack
                            : AppColors.onColoredBackground,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Min. Investment: \$${minInv.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTopMetric(
                  'GAIN',
                  '${profit.toStringAsFixed(1)}%',
                  profit >= 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  'TOTAL P&L',
                  _money(pnl),
                  pnl >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  'TOTAL AUM',
                  _money(aum),
                  AppColors.textPrimary,
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  'INVESTORS',
                  '$investors',
                  AppColors.textPrimary,
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  'COMMISSION',
                  '${commission.toStringAsFixed(2)}%',
                  AppColors.textPrimary,
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  'FLOATING PROFIT',
                  '\$0',
                  const Color(0xFF10B981),
                ),
                _buildMetricDivider(),
                _buildTopMetric(
                  'MAX DRAWDOWN',
                  '-${drawdown.toStringAsFixed(2)}%',
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
          if (description.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DESCRIPTION',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGrey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopMetric(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(width: 1, height: 30.h, color: AppColors.border);
  }

  Widget _buildPerformanceChart() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['1W', '1M', '3M', '6M', '1Y', 'All'].map((e) {
                    final isSelected = e == '1M';
                    return Container(
                      margin: EdgeInsets.only(left: 4.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.chipSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.isDarkMode
                                    ? AppColors.pureBlack
                                    : Colors.white
                              : AppColors.textGrey,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 200.h,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 100,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: AppColors.chipSurface, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return _bottomTitle('Start');
                        if (value == 3) return _bottomTitle('2026-04-10');
                        if (value == 6) return _bottomTitle('2026-04-13');
                        if (value == 9) return _bottomTitle('2026-04-16');
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 100,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value == 0 ? '\$0' : '\$${value.toInt()}',
                          style: TextStyle(
                            color: AppColors.textGreyLight,
                            fontSize: 9.sp,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 10,
                minY: -100,
                maxY: 600,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 0),
                      FlSpot(1, 150),
                      FlSpot(2, 300),
                      FlSpot(3, 450),
                      FlSpot(4, 550),
                      FlSpot(4.5, 480),
                      FlSpot(4.8, 500),
                      FlSpot(5, 100),
                      FlSpot(5.5, 120),
                      FlSpot(6, 40),
                      FlSpot(7, 40),
                      FlSpot(7.5, 200),
                      FlSpot(8, 200),
                      FlSpot(9, 80),
                      FlSpot(10, 80),
                    ],
                    isCurved: true,
                    color: AppColors.textPrimary,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
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

  Widget _bottomTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: TextStyle(color: AppColors.textGreyLight, fontSize: 9.sp),
      ),
    );
  }

  Widget _buildOpenPositionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Open Positions',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_openPositions.length} live',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          if (_loadingOpen)
            Padding(
              padding: EdgeInsets.all(24.h),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_openPositions.isEmpty)
            Padding(
              padding: EdgeInsets.all(24.h),
              child: Center(
                child: Text(
                  'No open positions',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
                ),
              ),
            )
          else ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _colHeader('Symbol')),
                  Expanded(flex: 2, child: _colHeader('Type')),
                  Expanded(flex: 3, child: _colHeader('Lot')),
                  Expanded(flex: 4, child: _colHeader('Open Price')),
                  Expanded(flex: 4, child: _colHeader('Open Time')),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _showAllOpenPositions
                  ? _openPositions.length
                  : (_openPositions.length > 5 ? 5 : _openPositions.length),
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, index) {
                final p = _openPositions[index];
                final symbol = (p['symbol'] ?? '—').toString();
                final type = (p['type'] ?? 0).toString();
                final isBuy = type == '0' || type.toLowerCase() == 'buy';
                final lot = _num(p['lot_size']);
                final openPrice = (p['open_price'] ?? '—').toString();
                final openTime = (p['open_time'] ?? '—').toString();
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          symbol,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isBuy
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444))
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isBuy ? 'BUY' : 'SELL',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              color: isBuy
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${lot.toStringAsFixed(2)} lot',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          openPrice,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          openTime.length > 10
                              ? openTime.substring(0, 10)
                              : openTime,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_openPositions.length > 5 && !_showAllOpenPositions) ...[
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              InkWell(
                onTap: () {
                  setState(() {
                    _showAllOpenPositions = true;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  alignment: Alignment.center,
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTradeHistory() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trade History',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.chipSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_trades.length} trades',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Expanded(flex: 3, child: _colHeader('Symbol')),
                Expanded(flex: 2, child: _colHeader('Type')),
                Expanded(flex: 2, child: _colHeader('P&L')),
                Expanded(flex: 3, child: _colHeader('Close Time')),
                Expanded(flex: 2, child: _colHeader('Duration')),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          if (_loadingTrades)
            Padding(
              padding: EdgeInsets.all(24.h),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_trades.isEmpty)
            Padding(
              padding: EdgeInsets.all(24.h),
              child: const Center(child: Text('No trades available')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _showAllTrades
                  ? _trades.length
                  : (_trades.length > 5 ? 5 : _trades.length),
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, index) {
                final t = _trades[index];
                return _buildTradeRow(t);
              },
            ),
          if (_trades.length > 5 && !_showAllTrades) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            InkWell(
              onTap: () {
                setState(() {
                  _showAllTrades = true;
                });
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                alignment: Alignment.center,
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _colHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textGrey,
      ),
    );
  }

  Widget _buildTradeRow(Map<String, dynamic> t) {
    final symbol = (t['symbol'] ?? '—').toString();
    final typeStr = (t['type'] ?? '').toString();
    final profit = _num(t['profit']);
    final closeTime = (t['close_time'] ?? '').toString();

    // Attempting to calculate duration if open_time and close_time exist
    String duration = '0m';
    final openTimeStr = (t['open_time'] ?? '').toString();
    if (openTimeStr.isNotEmpty && closeTime.isNotEmpty) {
      try {
        final o = DateTime.parse(openTimeStr);
        final c = DateTime.parse(closeTime);
        final diff = c.difference(o);
        if (diff.inDays > 0) {
          duration = '${diff.inDays}d ${diff.inHours % 24}h';
        } else if (diff.inHours > 0) {
          duration = '${diff.inHours}h ${diff.inMinutes % 60}m';
        } else {
          duration = '${diff.inMinutes}m';
        }
      } catch (_) {}
    }

    final isBuy = typeStr.toLowerCase() == 'buy' || typeStr == '0';
    final isProfit = profit >= 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              symbol,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color:
                        (isBuy
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isBuy ? 'BUY' : 'SELL',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: isBuy
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isProfit
                  ? '+\$${profit.toStringAsFixed(2)}'
                  : '-\$${profit.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isProfit
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              closeTime.isNotEmpty ? closeTime : '-',
              style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              duration,
              style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
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
            Icon(
              Icons.person_off_rounded,
              size: 48.sp,
              color: AppColors.textGreyLight,
            ),
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
              style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}
