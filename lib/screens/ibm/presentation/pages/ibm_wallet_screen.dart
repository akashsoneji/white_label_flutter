import 'package:crm_app/constants/color.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/presentation/pages/create_edit_plan_screen.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/assign_plan_bottom_sheet.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class IbmWalletScreen extends StatelessWidget {
  const IbmWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const IbmTopHeader(title: 'Commission', showBackButton: false),
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 1),
                ),
              ),
              child: TabBar(
                labelColor:
                    Colors.purple, // Assuming purple is the primary brand color
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: Colors.purple,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'My Commission'),
                  Tab(text: 'Commission Plans'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [MyCommissionTab(), CommissionPlansTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyCommissionTab extends StatefulWidget {
  const MyCommissionTab({super.key});

  @override
  State<MyCommissionTab> createState() => _MyCommissionTabState();
}

class _MyCommissionTabState extends State<MyCommissionTab> {
  final IbmApiProvider _apiProvider = IbmApiProvider();
  bool _isLoading = false;
  List<dynamic> _transactions = [];
  String? _error;

  String _selectedFilter = 'Everything';
  String _selectedFilterValue = '';

  final Map<String, String> _filterOptions = {
    'Everything': '',
    'Commission earned': 'commission',
    'Paid out': 'payout',
    'Payouts returned': 'payout_reversal',
    'Adjustments': 'adjustment',
    'Clawbacks': 'clawback',
  };

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiProvider.getPortalWalletTransactions(
        currency: 'USD',
        type: _selectedFilterValue.isEmpty ? null : _selectedFilterValue,
      );
      if (response.success) {
        final rawJson = response.data;
        if (rawJson != null && rawJson is Map<String, dynamic>) {
          final innerData = rawJson['data'];
          if (innerData is Map<String, dynamic>) {
            if (innerData['transactions'] is List) {
              _transactions = innerData['transactions'];
            } else if (innerData['data'] is List) {
              _transactions = innerData['data'];
            } else {
              _transactions = [];
            }
          } else if (innerData is List) {
            _transactions = innerData;
          } else {
            _transactions = [];
          }
        } else {
          _transactions = [];
        }
      } else {
        _error = response.message ?? 'Failed to load transactions';
      }
    } catch (e) {
      _error = 'An error occurred while loading transactions.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onFilterSelected(String filterLabel) {
    setState(() {
      _selectedFilter = filterLabel;
      _selectedFilterValue = _filterOptions[filterLabel] ?? '';
    });
    _fetchTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Commission',
            style: AppTextStyles.heading.copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            'What you have earned, what you have been paid, and what you are paid on',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildStatCard(
                'Available now',
                '\$0.09',
                'ready to request',
                Icons.account_balance_wallet,
                Colors.purple,
              ),
              _buildStatCard(
                'Pending payout',
                '\$0.00',
                'locked in an open request',
                Icons.hourglass_empty,
                Colors.orange,
              ),
              _buildStatCard(
                'Earned all time',
                '\$0.09',
                'your share, since day one',
                Icons.stacked_line_chart,
                Colors.purple,
              ),
              _buildStatCard(
                'Paid out',
                '\$0.00',
                'settled to you',
                Icons.check_circle,
                Colors.green,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$0.09 ready',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'The smallest payout is \$50.00.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    backgroundColor: Colors.purple.withOpacity(0.5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                  child: const Text('Request payout'),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          // Sub tabs like design
          Row(
            children: [
              Text(
                'Earnings',
                style: TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Text(
                'Payouts',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Text(
                'My Commission Plan',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Divider(color: AppColors.divider),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PopupMenuButton<String>(
                onSelected: _onFilterSelected,
                offset: const Offset(0, 30),
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                itemBuilder: (BuildContext context) {
                  return _filterOptions.keys.map((String choice) {
                    return PopupMenuItem<String>(
                      value: choice,
                      child: Row(
                        children: [
                          if (_selectedFilter == choice)
                            Icon(
                              Icons.check,
                              size: 16.w,
                              color: AppColors.textPrimary,
                            )
                          else
                            SizedBox(width: 16.w),
                          SizedBox(width: 8.w),
                          Text(
                            choice,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    _selectedFilter,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Text(
                'Every line is one movement of this wallet.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.purple, // Theme primary color
                ),
              ),
            )
          else if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red, fontSize: 14.sp),
                ),
              ),
            )
          else if (_transactions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: Text(
                  'No transactions found',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            )
          else
            ..._transactions.map((tx) {
              final trade = tx['trade'];
              final symbol = trade?['symbol'] ?? tx['symbol'] ?? 'WALLET';
              final type =
                  trade?['side']?.toString().toUpperCase() ??
                  tx['type']?.toString().toUpperCase() ??
                  'UNKNOWN';

              String details = tx['description'] ?? 'Transaction details';
              if (trade != null) {
                final account = trade['account'] ?? '';
                final lots = trade['lots']?.toString() ?? '';
                final entryPrice = trade['entry_price']?.toString() ?? '';
                final exitPrice = trade['exit_price']?.toString() ?? '';
                details =
                    'TA#$account - $lots lots - $entryPrice -> $exitPrice';
              }

              // Handle positive/negative amounts
              final direction = tx['direction'] == 'credit' ? '+' : '-';
              final amountValue = tx['amount']?.toString() ?? '0.00';
              final amountStr = '$direction \$$amountValue';

              final balanceValue = tx['balance_after']?.toString() ?? '0.00';
              final balanceStr = '\$$balanceValue';

              final date = tx['created_at'] ?? 'N/A';

              return _buildTransactionItem(
                symbol,
                type,
                details,
                amountStr,
                balanceStr,
                date,
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String amount,
    String subtitle,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      width:
          (Get.width - 40.w) /
          2, // Half width for mobile layout (16 left padding, 16 right padding, 8 spacing)
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(icon, color: Colors.white, size: 16.w),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    String symbol,
    String type,
    String details,
    String amount,
    String balance,
    String date,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  details,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  date,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  balance,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommissionPlansTab extends StatefulWidget {
  const CommissionPlansTab({super.key});

  @override
  State<CommissionPlansTab> createState() => _CommissionPlansTabState();
}

class _CommissionPlansTabState extends State<CommissionPlansTab> {
  bool _isLoading = true;
  List<dynamic> _plans = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await IbmApiProvider().getPartnerPlans();
      if (response.success) {
        final rawJson = response.data;
        if (rawJson != null && rawJson is Map<String, dynamic>) {
          final innerData = rawJson['data'];
          if (innerData is Map<String, dynamic> && innerData['plans'] is List) {
            _plans = innerData['plans'];
          } else {
            _plans = [];
          }
        } else {
          _plans = [];
        }
      } else {
        _error = response.message ?? 'Failed to load plans';
      }
    } catch (e) {
      _error = 'Error loading plans: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePlan(int planId, String planName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Plan'),
            content: Text('Are you sure you want to delete "$planName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final res = await IbmApiProvider().deletePartnerPlan(planId);
    if (res.success) {
      CustomToastService.show(message: 'Plan deleted successfully');
      _fetchPlans();
    } else {
      if (mounted) setState(() => _isLoading = false);
      CustomToastService.show(message: res.message ?? 'Failed to delete plan');
    }
  }

  void _showAssignBottomSheet(int planId, String planName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: AssignPlanBottomSheet(
              planId: planId,
              planName: planName,
              onAssigned: () => _fetchPlans(),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Commission Plans',
                style: AppTextStyles.heading.copyWith(fontSize: 18.sp),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Get.to(
                    () => const CreateEditPlanScreen(),
                  );
                  if (result == true) {
                    _fetchPlans();
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Plan'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.purple))
          else if (_error != null)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red, fontSize: 14.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_plans.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(40.w),
                child: Text(
                  'No commission plans found',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            )
          else
            ..._plans.map((plan) {
              final String name = plan['name']?.toString() ?? 'Unknown Plan';
              final String description = plan['description']?.toString() ?? '';
              final bool isActive =
                  plan['is_active'] == true || plan['is_active'] == 1;
              final int partnersUsing =
                  plan['partners_using'] is int
                      ? plan['partners_using']
                      : int.tryParse(
                            plan['partners_using']?.toString() ?? '0',
                          ) ??
                          0;

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              if (isActive)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final result = await Get.to(
                                    () => CreateEditPlanScreen(
                                      planId: plan['plan_id'],
                                    ),
                                  );
                                  if (result == true) {
                                    _fetchPlans();
                                  }
                                },
                                child: _buildActionIcon(
                                  Icons.edit,
                                  'Edit',
                                  AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              GestureDetector(
                                onTap:
                                    () => _showAssignBottomSheet(
                                      plan['plan_id'] ?? 0,
                                      name,
                                    ),
                                child: _buildActionIcon(
                                  Icons.person_add,
                                  'Assign',
                                  AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              GestureDetector(
                                onTap:
                                    () =>
                                        _deletePlan(plan['plan_id'] ?? 0, name),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 18.w,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 16.w,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            '$partnersUsing sub-IB using',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              description,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16.w, color: color),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
