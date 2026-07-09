import 'package:crm_app/widgets/app_svg_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/controllers/pmam/pmam_manager_plan_detail_controller.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/dashBorder.dart';

class PmamManagerPlanDetailScreen extends StatefulWidget {
  const PmamManagerPlanDetailScreen({super.key});

  @override
  State<PmamManagerPlanDetailScreen> createState() =>
      _PmamManagerPlanDetailScreenState();
}

class _PmamManagerPlanDetailScreenState
    extends State<PmamManagerPlanDetailScreen> {
  late final PmamManagerPlanDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    final int planId = Get.arguments ?? 0;
    _ctrl = Get.put(
      PmamManagerPlanDetailController(planId),
      tag: planId.toString(),
    );
  }

  @override
  void dispose() {
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
        leading: AppSvgBackButton(
          onPressed: () => Get.back(closeOverlays: true),
          iconWidth: 30.w,
          iconHeight: 30.h,
        ),
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

            // Stats Card (collapsible)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.border.withValues(alpha: 0.04),
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
            ),

            SizedBox(height: 16.h),

            // Section header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Text(
                    'Investor Requests',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Obx(() {
                    final count = _ctrl.investorRequests.length;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.onColoredBackground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(height: 8.h),

            Expanded(child: _buildRequestsTab()),
          ],
        );
      }),
    );
  }

  // ──── REQUESTS LIST ────
  Widget _buildRequestsTab() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _ctrl.loadInvestorRequests(),
      child: Obx(() {
        if (_ctrl.investorRequests.isEmpty && _ctrl.isRequestsLoading.value) {
          return Center(
            child: CommonLoadingWidget(size: 30, color: AppColors.primary),
          );
        }
        if (_ctrl.investorRequests.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: 120.h),
              Center(
                child: Text(
                  'No pending investor requests.',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ),
            ],
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          itemCount: _ctrl.investorRequests.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (_, i) {
            final req = _ctrl.investorRequests[i];
            return _RequestCard(
              req: req,
              fmtMoney: _fmtMoney,
              processing: _ctrl.processingRequestIds,
              onApprove: (id) async {
                final ok = await _ctrl.approveInvestorRequest(id);
                Get.snackbar(
                  ok ? 'Approved' : 'Error',
                  ok
                      ? 'Investor request approved'
                      : 'Failed to approve request',
                  backgroundColor: (ok
                          ? AppColors.green
                          : AppColors.error)
                      .withValues(alpha: 0.95),
                  colorText: AppColors.onColoredBackground,
                  snackPosition: SnackPosition.BOTTOM,
                  margin: EdgeInsets.all(12.w),
                  borderRadius: 10,
                  duration: const Duration(seconds: 3),
                );
              },
              onReject: (id) async {
                final ok = await _ctrl.rejectInvestorRequest(id);
                Get.snackbar(
                  ok ? 'Rejected' : 'Error',
                  ok
                      ? 'Investor request rejected'
                      : 'Failed to reject request',
                  backgroundColor: (ok
                          ? AppColors.green
                          : AppColors.error)
                      .withValues(alpha: 0.95),
                  colorText: AppColors.onColoredBackground,
                  snackPosition: SnackPosition.BOTTOM,
                  margin: EdgeInsets.all(12.w),
                  borderRadius: 10,
                  duration: const Duration(seconds: 3),
                );
              },
            );
          },
        );
      }),
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
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final String Function(dynamic) fmtMoney;
  final RxSet<int> processing;
  final Future<void> Function(int id) onApprove;
  final Future<void> Function(int id) onReject;

  const _RequestCard({
    required this.req,
    required this.fmtMoney,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year}, '
          '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    } catch (_) {
      return iso;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return AppColors.green;
      case 'rejected':
        return AppColors.error;
      case 'pending':
      default:
        return const Color(0xFFB07A11);
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'approved':
        return AppColors.green.withValues(alpha: 0.12);
      case 'rejected':
        return AppColors.error.withValues(alpha: 0.12);
      case 'pending':
      default:
        return const Color(0xFFFFF3D6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = req['user'] as Map<String, dynamic>? ?? {};
    final acc = req['investor_account'] as Map<String, dynamic>? ?? {};

    final id = req['id'] is int
        ? req['id'] as int
        : int.tryParse('${req['id']}') ?? 0;

    final fullName = [
      user['first_name'],
      user['last_name'],
    ].where((e) => e != null && '$e'.isNotEmpty).join(' ').trim();
    final displayName = fullName.isNotEmpty
        ? fullName
        : (user['email']?.toString() ?? 'Investor #${user['id'] ?? id}');

    final email = user['email']?.toString() ?? '';
    final accNumber = acc['meta_account_number']?.toString() ?? '-';
    final amount = req['invested_amount'];
    final status = (req['status'] ?? 'pending').toString();
    final createdAt = req['created_at']?.toString();

    final isPending = status == 'pending';
    final isProcessing = processing.contains(id);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name + status pill
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        email,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 11.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 10.h),

          // Account / Amount row
          Row(
            children: [
              Expanded(
                child: _kv('Account', accNumber),
              ),
              Expanded(
                child: _kv(
                  'Amount',
                  fmtMoney(amount),
                  valueColor: AppColors.primary,
                  bold: true,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _kv('Requested at', _formatDate(createdAt)),

          if (isPending) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : () => onApprove(id),
                    icon: isProcessing
                        ? SizedBox(
                            width: 14.w,
                            height: 14.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(Icons.check, size: 16.sp),
                    label: Text(
                      'Approve',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: AppColors.onColoredBackground,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : () => onReject(id),
                    icon: Icon(Icons.close, size: 16.sp),
                    label: Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.onColoredBackground,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.textGrey,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 13.sp,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
