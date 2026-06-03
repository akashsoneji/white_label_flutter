import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/pmam/view_models/pmam_manager_plan_detail_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/dashBorder.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class PmamManagerPlanDetailScreen extends StatefulWidget {
  const PmamManagerPlanDetailScreen({super.key});

  @override
  State<PmamManagerPlanDetailScreen> createState() =>
      _PmamManagerPlanDetailScreenState();
}

class _PmamManagerPlanDetailScreenState
    extends State<PmamManagerPlanDetailScreen>
    with SingleTickerProviderStateMixin {
  late final PmamManagerPlanDetailController _ctrl;
  late final TabController _tabCtrl;

  final ScrollController _allocScrollCtrl = ScrollController();
  final ScrollController _invScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    final int planId = Get.arguments ?? 0;
    _ctrl = Get.put(
      PmamManagerPlanDetailController(planId),
      tag: planId.toString(),
    );

    _allocScrollCtrl.addListener(() {
      if (_allocScrollCtrl.position.pixels >=
          _allocScrollCtrl.position.maxScrollExtent - 100) {
        _ctrl.loadAllocations();
      }
    });

    _invScrollCtrl.addListener(() {
      if (_invScrollCtrl.position.pixels >=
          _invScrollCtrl.position.maxScrollExtent - 100) {
        _ctrl.loadInvestors();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _allocScrollCtrl.dispose();
    _invScrollCtrl.dispose();
    Get.delete<PmamManagerPlanDetailController>(tag: _ctrl.planId.toString());
    super.dispose();
  }

  String _fmtMoney(dynamic val) {
    if (val == null) return '\$0.00';
    final d = double.tryParse(val.toString()) ?? 0.0;
    return '\$${d.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: const AppBackButton(),
        title: Obx(() {
          final planName =
              _ctrl.planDetails['plan']?['plan_name'] ?? 'Plan Details';
          return Text('Plan: $planName', style: AppTextStyles.heading);
        }),
        centerTitle: true,
      ),
      body: Obx(() {
        if (_ctrl.isLoadingDetails.value) {
          return Center(
            child: CommonLoadingWidget(size: 40, color: AppColors.primary),
          );
        }

        final plan = _ctrl.planDetails['plan'] ?? {};
        final withdrawable = _ctrl.planDetails['withdrawable'] ?? 0.0;

        return Column(
          children: [
            // SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  plan['plan_name'] ?? '',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            // Stats Card (Expanded Style)
            Obx(() {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _ctrl.isStatsExpanded.toggle(),
                        borderRadius: BorderRadius.circular(16.r),
                        child: Padding(
                          padding: EdgeInsets.all(8.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Your Stats',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Icon(
                                _ctrl.isStatsExpanded.value
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textGrey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_ctrl.isStatsExpanded.value)
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.w),
                          child: Column(
                            children: [
                              _buildDashedStatRow(
                                'Total AUM',
                                _fmtMoney(plan['total_aum']),
                              ),
                              SizedBox(height: 12.h),
                              _buildDashedStatRow(
                                'Withdrawable',
                                _fmtMoney(withdrawable),
                              ),
                              SizedBox(height: 12.h),
                              _buildDashedStatRow(
                                'Total P&L',
                                _fmtMoney(plan['total_pnl']),
                              ),
                              SizedBox(height: 12.h),
                              _buildDashedStatRow(
                                'Total Commission',
                                _fmtMoney(plan['total_commission']),
                              ),
                              SizedBox(height: 12.h),
                              _buildDashedStatRow(
                                'Active Investors',
                                '${plan['active_investors'] ?? 0}',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            SizedBox(height: 16.h),
            Container(
              color: AppColors.whiteColor,
              child: TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textGrey,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                labelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Trades & Allocations'),
                  Tab(text: 'Investors'),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.dividerDark),

            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [_buildAllocationsTab(), _buildInvestorsTab()],
              ),
            ),
          ],
        );
      }),
    );
  }

  // ──── ALLOCATIONS TAB ────
  Widget _buildAllocationsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildFilterCol(
                      'DATE FROM',
                      'mm/dd/yyyy',
                      Icons.calendar_today_rounded,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          _ctrl.applyAllocationsFilter(
                            df: date.toIso8601String().split('T')[0],
                          );
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildFilterCol(
                      'DATE TO',
                      'mm/dd/yyyy',
                      Icons.calendar_today_rounded,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          _ctrl.applyAllocationsFilter(
                            dt: date.toIso8601String().split('T')[0],
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
                    child: _buildInvestorDropdown(
                      'FILTER BY INVESTOR',
                      _ctrl.allocFilterInvestor.value,
                      (val) {
                        if (val != null) _ctrl.applyAllocationsFilter(inv: val);
                      },
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildFilterDropdownMap(
                      'STATUS',
                      _ctrl.allocStatus.value,
                      {'all': 'All', 'open': 'Open', 'closed': 'Closed'},
                      (v) {
                        if (v != null) _ctrl.applyAllocationsFilter(status: v);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: () => _ctrl.loadAllocations(refresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 0.h),
                ),
                child: Text(
                  'Apply',
                  style: TextStyle(color: AppColors.whiteColor, fontSize: 13.sp),
                ),
              ),
            ],
          ),
        ),

        // Allocations List Area
        Expanded(
          child: Obx(() {
            if (_ctrl.allocations.isEmpty && _ctrl.isAllocationsLoading.value) {
              return Center(
                child: CommonLoadingWidget(size: 30, color: AppColors.primary),
              );
            }
            if (_ctrl.allocations.isEmpty) {
              return Center(
                child: Text(
                  'No trades/allocations found.',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              );
            }
            return ListView.separated(
              controller: _allocScrollCtrl,
              itemCount:
                  _ctrl.allocations.length + (_ctrl.hasMoreAllocations ? 1 : 0),
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              itemBuilder: (_, i) {
                if (i == _ctrl.allocations.length) {
                  return Center(
                    child: CommonLoadingWidget(
                      size: 24,
                      color: AppColors.primary,
                    ),
                  );
                }
                final alloc = _ctrl.allocations[i];
                final pnl =
                    double.tryParse(
                      alloc['net_profit_credited']?.toString() ?? '0',
                    ) ??
                    0;
                return _AllocCard(
                  alloc: alloc,
                  pnl: pnl,
                  fmtMoney: _fmtMoney,
                  buildCardRow: _buildCardRow,
                );
              },
            );
          }),
        ),
      ],
    );
  }

  // ──── INVESTORS TAB ────
  Widget _buildInvestorsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdownMap(
                      'SORT BY',
                      _ctrl.invSortBy.value,
                      {
                        'status': 'Status (Active first)',
                        'name': 'Name',
                        'invested_amount': 'Invested',
                        'active_since': 'Active since',
                      },
                      (v) {
                        if (v != null) _ctrl.applyInvestorsFilter(sort: v);
                      },
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildFilterDropdownMap(
                      'ORDER',
                      _ctrl.invOrder.value,
                      {'desc': 'Z-A / Last first', 'asc': 'A-Z / First first'},
                      (v) {
                        if (v != null) _ctrl.applyInvestorsFilter(order: v);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown(
                      'SHOW',
                      _ctrl.invPerPage.value.toString(),
                      ['10', '15', '25', '50'],
                      (v) {
                        if (v != null)
                          _ctrl.applyInvestorsFilter(
                            perPage: int.tryParse(v) ?? 10,
                          );
                      },
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildFilterInput('SEARCH', 'Name or email', (val) {
                      _ctrl.applyInvestorsFilter(search: val);
                    }),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: () => _ctrl.loadInvestors(refresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 0.h),
                ),
                child: Text(
                  'Apply',
                  style: TextStyle(color: AppColors.whiteColor, fontSize: 13.sp),
                ),
              ),
            ],
          ),
        ),

        // Investors List Area
        Expanded(
          child: Obx(() {
            if (_ctrl.investors.isEmpty && _ctrl.isInvestorsLoading.value) {
              return Center(
                child: CommonLoadingWidget(size: 30, color: AppColors.primary),
              );
            }
            if (_ctrl.investors.isEmpty) {
              return Center(
                child: Text(
                  'No investors found.',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              );
            }
            return ListView.separated(
              controller: _invScrollCtrl,
              itemCount:
                  _ctrl.investors.length + (_ctrl.hasMoreInvestors ? 1 : 0),
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              itemBuilder: (_, i) {
                if (i == _ctrl.investors.length) {
                  return Center(
                    child: CommonLoadingWidget(
                      size: 24,
                      color: AppColors.primary,
                    ),
                  );
                }
                final inv = _ctrl.investors[i];
                return _InvestorCard(
                  inv: inv,
                  fmtMoney: _fmtMoney,
                  buildCardRow: _buildCardRow,
                );
              },
            );
          }),
        ),
      ],
    );
  }

  // ──── WIDGET HELPERS ────

  Widget _buildFilterCol(
    String label,
    String hint,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              border: Border.all(color: AppColors.dividerDark),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 14.sp, color: AppColors.textGrey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          height: 36.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            border: Border.all(color: AppColors.dividerDark),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,

              icon: Icon(
                Icons.keyboard_arrow_down,
                // wn_rounded,
                size: 16.sp,
                color: AppColors.textGrey,
              ),
              items:
                  items
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: TextStyle(fontSize: 12.sp)),
                        ),
                      )
                      .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterInput(
    String label,
    String hint,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          height: 36.h,
          // padding: EdgeInsets.symmetric(horizontal: 5.w),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            border: Border.all(color: AppColors.dividerDark),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: TextField(
            style: TextStyle(fontSize: 12.sp),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(bottom: 14.h), // align vertically
            ),
            onSubmitted: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCardRow(
    String label,
    String value, {
    bool isHighlighted = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            color: color ?? AppColors.textPrimary,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDashedStatRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: DashedUnderline(
              dashWidth: 2,
              dashSpace: 2,
              color: AppColors.textGrey.withOpacity(0.2),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdownMap(
    String label,
    String value,
    Map<String, String> itemsMap,
    Function(String?) onChanged,
  ) {
    // If the selected value is not in the map keys, force it to the first key to avoid error.
    final safeValue = itemsMap.containsKey(value) ? value : itemsMap.keys.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          height: 36.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            border: Border.all(color: AppColors.dividerDark),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16.sp,
                color: AppColors.textGrey,
              ),
              menuMaxHeight: Get.height * 0.3,
              items:
                  itemsMap.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.value,
                            style: TextStyle(fontSize: 12.sp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvestorDropdown(
    String label,
    String value,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          height: 36.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            border: Border.all(color: AppColors.dividerDark),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Obx(() {
            final investors = _ctrl.allPlanInvestors;
            final itemsMap = {'': 'All investors'};
            for (var inv in investors) {
              final valId =
                  inv['user_id'] ??
                  inv['investor_user_id'] ??
                  inv['investor_id'];
              if (valId != null && inv['investor_name'] != null) {
                itemsMap[valId.toString()] = inv['investor_name'].toString();
              }
            }
            final safeValue = itemsMap.containsKey(value) ? value : '';

            return DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16.sp,
                  color: AppColors.textGrey,
                ),
                menuMaxHeight: Get.height * 0.3,
                items:
                    itemsMap.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: TextStyle(fontSize: 12.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: onChanged,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _AllocCard extends StatefulWidget {
  final Map<String, dynamic> alloc;
  final double pnl;
  final String Function(dynamic) fmtMoney;
  final Widget Function(String, String, {bool isHighlighted, Color? color})
  buildCardRow;

  const _AllocCard({
    required this.alloc,
    required this.pnl,
    required this.fmtMoney,
    required this.buildCardRow,
  });

  @override
  State<_AllocCard> createState() => _AllocCardState();
}

class _AllocCardState extends State<_AllocCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color:
                isExpanded
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.dividerDark,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: widget.buildCardRow(
                    'Investor',
                    widget.alloc['investor_name'] ?? '',
                    isHighlighted: true,
                    color: AppColors.primary,
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textGrey,
                  size: 20.sp,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            widget.buildCardRow('Symbol', widget.alloc['trade_symbol'] ?? ''),
            SizedBox(height: 8.h),
            widget.buildCardRow(
              'P&L',
              widget.fmtMoney(widget.pnl),
              color: widget.pnl >= 0 ? AppColors.green : AppColors.red,
              isHighlighted: false,
            ),
            if (isExpanded) ...[
              SizedBox(height: 8.h),
              widget.buildCardRow(
                'Type',
                widget.alloc['trade_type_label'] ?? '',
              ),
              SizedBox(height: 8.h),
              widget.buildCardRow(
                'Lot',
                '${widget.alloc['allocated_lot'] ?? 0}',
              ),
              SizedBox(height: 8.h),
              widget.buildCardRow(
                'Open',
                widget.alloc['open_time'] != null
                    ? widget.alloc['open_time'].toString().split('T')[0]
                    : '',
              ),
              SizedBox(height: 8.h),
              widget.buildCardRow(
                'Close',
                widget.alloc['close_time'] != null
                    ? widget.alloc['close_time'].toString().split('T')[0]
                    : '',
              ),
              SizedBox(height: 8.h),
              widget.buildCardRow(
                'Status',
                (widget.alloc['status'] ?? '').toString().capitalizeFirst ?? '',
                color:
                    widget.alloc['status'] == 'closed'
                        ? AppColors.red
                        : AppColors.green,
                isHighlighted: true,
              ),
              SizedBox(height: 8.h),
              widget.buildCardRow(
                'Commission',
                widget.fmtMoney(widget.alloc['commission_charged'] ?? 0),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvestorCard extends StatefulWidget {
  final Map<String, dynamic> inv;
  final String Function(dynamic) fmtMoney;
  final Widget Function(String, String, {bool isHighlighted, Color? color})
  buildCardRow;

  const _InvestorCard({
    required this.inv,
    required this.fmtMoney,
    required this.buildCardRow,
  });

  @override
  State<_InvestorCard> createState() => _InvestorCardState();
}

class _InvestorCardState extends State<_InvestorCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color:
                isExpanded
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.dividerDark,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: widget.buildCardRow(
                    'Name',
                    widget.inv['investor_name'] ?? '',
                    isHighlighted: true,
                    color: AppColors.primary,
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textGrey,
                  size: 20.sp,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            widget.buildCardRow(
              'Status',
              (widget.inv['status'] ?? '').toString().capitalizeFirst ?? '',
              isHighlighted: true,
              color:
                  widget.inv['status'] == 'active'
                      ? AppColors.green
                      : AppColors.textGrey,
            ),
            SizedBox(height: 8.h),
            widget.buildCardRow(
              'Invested',
              widget.fmtMoney(widget.inv['invested_amount']),
            ),
            if (isExpanded) ...[
              SizedBox(height: 8.h),
              widget.buildCardRow('Email', widget.inv['investor_email'] ?? ''),
              SizedBox(height: 8.h),
              widget.buildCardRow(
                'Active since',
                widget.inv['active_since'] != null &&
                        widget.inv['active_since'].toString().isNotEmpty
                    ? widget.inv['active_since'].toString().split('T')[0]
                    : '-',
              ),
              SizedBox(height: 8.h),
              widget.buildCardRow(
                'Inactive since',
                widget.inv['inactive_since'] != null &&
                        widget.inv['inactive_since'].toString().isNotEmpty
                    ? widget.inv['inactive_since'].toString().split('T')[0]
                    : '-',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
