import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/screens/ibm/presentation/widgets/ibm_top_header.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class IbmWalletScreen extends StatefulWidget {
  const IbmWalletScreen({super.key});

  @override
  State<IbmWalletScreen> createState() => _IbmWalletScreenState();
}

class _IbmWalletScreenState extends State<IbmWalletScreen> with SingleTickerProviderStateMixin {
  final IbmController controller = Get.find<IbmController>();
  late TabController _sectionTabController;

  final List<String> _commissionTabs = ['Earnings', 'Payouts', 'My Commission Plan'];
  String _selectedCommissionTab = 'Earnings';

  @override
  void initState() {
    super.initState();
    _sectionTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _sectionTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(105.h),
        child: Column(
          children: [
            const IbmTopHeader(title: 'Commission & Wallet', showBackButton: false),
            Container(
              color: AppColors.whiteColor,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              child: Container(
                height: 36.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEF8),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: TabBar(
                  controller: _sectionTabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF5F259E),
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textGrey,
                  labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'My Commission'),
                    Tab(text: 'Commission Plans'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _sectionTabController,
        children: [
          _buildMyCommissionTab(),
          _buildCommissionPlansTab(),
        ],
      ),
    );
  }

  // ==========================================
  // SCREENSHOT 3: MY COMMISSION & TRANSACTIONS
  // ==========================================
  Widget _buildMyCommissionTab() {
    return Obx(() {
      if (controller.isLoading.value && controller.walletData.isEmpty) {
        return Center(child: CommonLoadingWidget(size: 50.0, color: AppColors.primary));
      }

      final wallet = controller.walletData;
      final balance = double.tryParse(wallet['balance']?.toString() ?? '0.0') ?? 0.0;
      final pendingPayout = double.tryParse(wallet['pending_payout']?.toString() ?? '0.0') ?? 0.0;
      final lifetimeEarned = double.tryParse(wallet['lifetime_earned']?.toString() ?? '$balance') ?? balance;
      final lifetimePaid = double.tryParse(wallet['lifetime_paid']?.toString() ?? '0.0') ?? 0.0;
      final minPayout = double.tryParse(wallet['minimum_payout']?.toString() ?? '50.0') ?? 50.0;

      final transactions = controller.transactionsList;

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await controller.fetchWallet();
          await controller.fetchTransactions();
        },
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          children: [
            Text('My Commission', style: AppTextStyles.heading.copyWith(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 2.h),
            Text('What you have earned, what you have been paid, and what you are paid on', style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp)),
            SizedBox(height: 14.h),

            // 4 Summary Metric Cards matching Screenshot 3
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildCommissionMetricCard(
                  title: 'Available now',
                  subtitle: 'ready to request',
                  value: '\$${balance.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF5F259E),
                ),
                _buildCommissionMetricCard(
                  title: 'Pending payout',
                  subtitle: 'locked in an open request',
                  value: '\$${pendingPayout.toStringAsFixed(2)}',
                  icon: Icons.hourglass_empty,
                  color: const Color(0xFF8C531B),
                ),
                _buildCommissionMetricCard(
                  title: 'Earned all time',
                  subtitle: 'your share, since day one',
                  value: '\$${lifetimeEarned.toStringAsFixed(2)}',
                  icon: Icons.monetization_on,
                  color: const Color(0xFF5F259E),
                ),
                _buildCommissionMetricCard(
                  title: 'Paid out',
                  subtitle: 'settled to you',
                  value: '\$${lifetimePaid.toStringAsFixed(2)}',
                  icon: Icons.check_circle,
                  color: const Color(0xFF00C48C),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Banner Card: Request payout matching Screenshot 3
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${balance.toStringAsFixed(2)} ready',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'The smallest payout is \$${minPayout.toStringAsFixed(2)}.',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: balance >= minPayout ? () => _showPayoutDialog(balance) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5F259E),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF5F259E).withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    ),
                    child: const Text('Request payout'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Commission Sub-tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _commissionTabs.map((tab) {
                  final isSelected = _selectedCommissionTab == tab;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: isSelected,
                      selectedColor: const Color(0xFF5F259E),
                      backgroundColor: AppColors.whiteColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 12.sp,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                        side: BorderSide(color: isSelected ? const Color(0xFF5F259E) : AppColors.divider),
                      ),
                      onSelected: (val) {
                        setState(() => _selectedCommissionTab = tab);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 14.h),

            // Transactions table header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Text('Everything', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4.w),
                      Icon(Icons.arrow_drop_down, size: 16.w),
                    ],
                  ),
                ),
                Text('Every line is one movement of this wallet', style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp)),
              ],
            ),
            SizedBox(height: 10.h),

            // Ledger Rows matching Screenshot 3
            if (transactions.isEmpty)
              _buildEmptyTransactionsPlaceholder()
            else
              ...transactions.map((tx) => _buildTransactionCard(tx)).toList(),
          ],
        ),
      );
    });
  }

  Widget _buildCommissionMetricCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 20.w, color: Colors.white),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 9.sp),
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

  Widget _buildTransactionCard(dynamic tx) {
    final t = tx is Map ? tx : {};
    final when = t['when'] ?? t['created_at'] ?? '14 Aug 2026 12:02';
    final symbol = t['symbol'] ?? 'XAUUSD';
    final side = t['side'] ?? 'BUY';
    final details = t['details'] ?? 'TA#2000029 · 0.01 lots';
    final amount = double.tryParse(t['amount']?.toString() ?? '0.03') ?? 0.03;
    final balanceAfter = t['balance_after'] ?? '0.09';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(symbol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: side == 'BUY' ? const Color(0xFF00C48C).withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        side,
                        style: TextStyle(
                          color: side == 'BUY' ? const Color(0xFF00C48C) : Colors.redAccent,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(details, style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp)),
                SizedBox(height: 2.h),
                Text(when, style: TextStyle(color: AppColors.textGrey, fontSize: 10.sp)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+ \$${amount.toStringAsFixed(2)}',
                style: TextStyle(color: const Color(0xFF00C48C), fontWeight: FontWeight.bold, fontSize: 13.sp),
              ),
              SizedBox(height: 2.h),
              Text(
                '\$$balanceAfter',
                style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionsPlaceholder() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 30.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40.w, color: AppColors.textGrey.withOpacity(0.5)),
          SizedBox(height: 8.h),
          Text('No movements recorded yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
          SizedBox(height: 4.h),
          Text('New trades and payouts will appear here.', style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp)),
        ],
      ),
    );
  }

  // ==========================================
  // SCREENSHOT 4 & 5: COMMISSION PLANS
  // ==========================================
  Widget _buildCommissionPlansTab() {
    return Obx(() {
      final plans = controller.plansList;

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => controller.fetchPlans(),
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Commission Plans', style: AppTextStyles.heading.copyWith(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _showCreatePlanDialog,
                  icon: Icon(Icons.add, size: 16.w),
                  label: Text('New Plan', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F259E),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            if (plans.isEmpty)
              _buildEmptyPlansPlaceholder()
            else
              ...plans.map((p) => _buildPlanCard(p as Map<String, dynamic>)).toList(),
          ],
        ),
      );
    });
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final planId = plan['plan_id'] ?? plan['id'] ?? 0;
    final name = plan['name'] ?? 'Plan $planId';
    final description = plan['description'] ?? 'Pass-down commission rate for Sub-IBs';
    final partnersUsing = plan['partners_using'] ?? plan['sub_ib_count'] ?? 1;
    final isActive = plan['is_active'] ?? true;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: AppTextStyles.heading.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF00C48C).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF00C48C) : Colors.grey,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // Action buttons matching Screenshot 4: Edit, Assign, Delete
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18.w, color: AppColors.textPrimary),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              SizedBox(width: 12.w),
              IconButton(
                icon: Icon(Icons.person_add_alt_1_outlined, size: 18.w, color: AppColors.textPrimary),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              SizedBox(width: 12.w),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18.w, color: Colors.redAccent),
                onPressed: () => _confirmDeletePlan(planId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.people_outline, size: 14.w, color: AppColors.textGrey),
              SizedBox(width: 4.w),
              Text('$partnersUsing sub-IB using', style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp, fontWeight: FontWeight.w500)),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlansPlaceholder() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 50.w, color: AppColors.textGrey.withOpacity(0.5)),
          SizedBox(height: 12.h),
          Text('No Commission Plans Yet', style: AppTextStyles.heading.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 6.h),
          Text(
            'Create templates to define pass-down commission rates for your sub-partners.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SCREENSHOT 5: CREATE PLAN MODAL
  // ==========================================
  void _showCreatePlanDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String status = 'Active';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stepper badge matching Screenshot 5
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5F259E),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text('1 · Details', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.chevron_right, size: 16.w, color: AppColors.textGrey),
                  SizedBox(width: 8.w),
                  Text('2 · Groups & Rates', style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp)),
                ],
              ),
              SizedBox(height: 16.h),

              Text('Plan name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              SizedBox(height: 6.h),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Standard Sub-IB',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
              SizedBox(height: 14.h),

              Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              SizedBox(height: 6.h),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Optional notes...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
              SizedBox(height: 14.h),

              Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: status,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                    ],
                    onChanged: (val) {},
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5F259E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        CustomToastService.showError(message: 'Please enter a plan name');
                        return;
                      }
                      Get.back();
                      await controller.createPartnerPlan({
                        'name': nameController.text.trim(),
                        'description': descController.text.trim(),
                        'groups': [],
                      });
                    },
                    child: const Text('Save Plan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletePlan(int planId) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Delete Plan'),
        content: const Text('Are you sure you want to delete this commission plan?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Get.back();
              await controller.deletePartnerPlan(planId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPayoutDialog(double availableBalance) {
    final amountController = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Request Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: \$${availableBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12.h),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter amount (USD)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5F259E), foregroundColor: Colors.white),
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amount <= 0 || amount > availableBalance) {
                CustomToastService.showError(message: 'Invalid withdrawal amount');
                return;
              }
              Get.back();
              // send request
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}
