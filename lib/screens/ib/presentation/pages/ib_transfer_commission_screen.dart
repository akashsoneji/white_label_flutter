import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ib/data/repositories/ib_repository.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_transfer_create_screen.dart';
import 'package:crm_app/screens/ib/view_models/ib_transfer_controller.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class IbTransferCommissionScreen extends StatefulWidget {
  const IbTransferCommissionScreen({super.key});

  @override
  State<IbTransferCommissionScreen> createState() => _IbTransferCommissionScreenState();
}

class _IbTransferCommissionScreenState extends State<IbTransferCommissionScreen> {
  late IbTransferController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize Controller
    if (Get.isRegistered<IbTransferController>()) {
      _controller = Get.find<IbTransferController>();
    } else {
      _controller = Get.put(IbTransferController(Get.find<IbRepository>()));
    }
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200.h) {
        _controller.fetchHistory();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: AppBackButton(onPressed: () => Get.back()),
        ),
        title: Text(
          'Transfer Commission',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColors.textPrimary, size: 28.sp),
            onPressed: () => Get.to(() => const IbTransferCreateScreen()),
          ),
          SizedBox(width: 10.w),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Obx(() {
              final isInitialLoading = _controller.isLoadingHistory.value && _controller.historyData.isEmpty;

              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Balance Card
                  SliverToBoxAdapter(child: _buildPremiumBalanceCard()),

                  // 2. Initial Loading State
                  if (isInitialLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  // 3. Empty State
                  else if (_controller.historyData.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 40.h),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_toggle_off,
                                size: 48.sp,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No transfer history found',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  // 4. Transactions List
                  else ...[
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _controller.historyData[index];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: _buildHistoryCard(item),
                            );
                          },
                          childCount: _controller.historyData.length,
                        ),
                      ),
                    ),

                    // 5. Load More Loading / No More Items Indicator at bottom
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: Center(
                          child: _controller.isLoadingHistory.value
                              ? CircularProgressIndicator(color: AppColors.primary)
                              : !_controller.hasMoreHistory.value && _controller.historyData.isNotEmpty
                                  ? Text(
                                      'No more history to show',
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
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBalanceCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          colors: [
            AppColors.isDarkMode ? AppColors.secondary.withOpacity(0.15) : AppColors.primary,
            AppColors.isDarkMode ? AppColors.secondary.withOpacity(0.15) : AppColors.primary.withOpacity(0.85),
            AppColors.isDarkMode ? AppColors.secondary.withOpacity(0.15) : AppColors.secondary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDarkMode ? Colors.black.withOpacity(0.4) : AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          children: [
            // Background circles decoration
            Positioned(
              right: -20.w,
              top: -20.h,
              child: CircleAvatar(
                radius: 60.r,
                backgroundColor: AppColors.isDarkMode ? AppColors.secondary.withOpacity(0.15) : Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              left: -40.w,
              bottom: -40.h,
              child: CircleAvatar(
                radius: 80.r,
                backgroundColor: AppColors.isDarkMode ? AppColors.secondary.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TRANSFER COMMISSION',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white.withOpacity(0.8),
                        size: 24.sp,
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Obx(() {
                    final data = _controller.initData.value;
                    return Text(
                      '\$${data?.availableBalance?.toStringAsFixed(2) ?? "0.00"}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.5,
                      ),
                    );
                  }),
                  SizedBox(height: 8.h),
                  Obx(() {
                    final data = _controller.initData.value;
                    return Text(
                      'Min Transfer: \$${data?.minAmount?.toStringAsFixed(2) ?? "0.00"}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    Color statusColor;
    String status = item.status?.toLowerCase() ?? 'pending';
    switch (status) {
      case 'approved':
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'rejected':
      case 'declined':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    String date = '';
    if (item.requestedAt != null) {
      try {
        date = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(item.requestedAt!));
      } catch (_) {}
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackGround,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transfer ID: #\${item.id}',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13.sp, fontWeight: FontWeight.w400),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 12.sp, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount', style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp)),
                    SizedBox(height: 4.h),
                    Text(
                      '\$${item.amount?.toStringAsFixed(2) ?? "0.00"}',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
              Container(width: 1.w, height: 30.h, color: AppColors.border.withOpacity(0.5)),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('To Client', style: TextStyle(color: AppColors.textGrey, fontSize: 12.sp)),
                    SizedBox(height: 4.h),
                    Text(
                      item.toClientName ?? '-',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.notes, color: AppColors.textGrey, size: 14.sp),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      item.comment!,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, color: AppColors.textGrey, size: 14.sp),
                  SizedBox(width: 4.w),
                  Text(date, style: TextStyle(color: AppColors.textGrey, fontSize: 11.sp)),
                ],
              ),
              if (status == 'pending')
                GestureDetector(
                  onTap: () {
                    Get.dialog(
                      AlertDialog(
                        backgroundColor: AppColors.cardBackGround,
                        title: Text('Cancel Transfer', style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp)),
                        content: Text('Are you sure you want to cancel this transfer?', style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp)),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: Text('No', style: TextStyle(color: AppColors.textGrey)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Get.back();
                              _controller.cancelTransfer(item.id!);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                            ),
                            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 14.sp, fontWeight: FontWeight.w400)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
