import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/ib_transfer_models.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/ib/data/repositories/ib_repository.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_transfer_create_screen.dart';
import 'package:crm_app/screens/ib/view_models/ib_transfer_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class IbTransferCommissionScreen extends StatefulWidget {
  final bool isActive;
  const IbTransferCommissionScreen({super.key, this.isActive = false});

  @override
  State<IbTransferCommissionScreen> createState() =>
      _IbTransferCommissionScreenState();
}

class _IbTransferCommissionScreenState
    extends State<IbTransferCommissionScreen> {
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

    // Explicitly fetch data when screen is opened
    // This ensures data is loaded even if the controller was already registered
    _controller.fetchInitData();
    _controller.fetchHistory(refresh: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200.h) {
        _controller.fetchHistory();
      }
    });
  }

  @override
  void didUpdateWidget(covariant IbTransferCommissionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.fetchInitData();
      _controller.fetchHistory(refresh: true);
    }
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
          padding: EdgeInsetsDirectional.only(start: 10.w),
          // child: AppBackButton(onPressed: () => Get.back()),
          child: IconButton(
            icon: SvgPicture.asset(
              "assets/svg/ib_dashboard/home.svg",
              colorFilter: ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () => Get.offAllNamed(AppPages.TRADING),
          ),
        ),
        title: Text(
          TranslationUtils.tr('ib_nav_transfer_comm'),
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
              final isInitialLoading =
                  _controller.isLoadingHistory.value &&
                  _controller.historyData.isEmpty;

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _controller.fetchInitData(),
                    _controller.fetchHistory(refresh: true),
                  ]);
                },
                color: AppColors.primary,
                backgroundColor: AppColors.whiteColor,
                child: CustomScrollView(
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
                            padding: EdgeInsets.symmetric(
                              horizontal: 40.w,
                              vertical: 40.h,
                            ),
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
                                  TranslationUtils.tr(
                                    'internal_transfer_history_screen_no_transfer_history_found',
                                  ),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 8.h,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final item = _controller.historyData[index];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: _buildHistoryCard(item),
                            );
                          }, childCount: _controller.historyData.length),
                        ),
                      ),

                      // 5. Load More Loading / No More Items Indicator at bottom
                      // SliverToBoxAdapter(
                      //   child: Padding(
                      //     padding: EdgeInsets.symmetric(vertical: 24.h),
                      //     child: Center(
                      //       child: _controller.isLoadingHistory.value
                      //           ? CircularProgressIndicator(color: AppColors.primary)
                      //           : !_controller.hasMoreHistory.value && _controller.historyData.isNotEmpty
                      //               ? Text(
                      //                   'No more history to show',
                      //                   style: TextStyle(
                      //                     color: AppColors.textSecondary,
                      //                     fontSize: 11.sp,
                      //                   ),
                      //                 )
                      //               : const SizedBox.shrink(),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ],
                ),
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
            AppColors.isDarkMode
                ? AppColors.secondary.withOpacity(0.15)
                : AppColors.primary,
            AppColors.isDarkMode
                ? AppColors.secondary.withOpacity(0.15)
                : AppColors.primary.withOpacity(0.85),
            AppColors.isDarkMode
                ? AppColors.secondary.withOpacity(0.15)
                : AppColors.secondary.withOpacity(0.9),
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppColors.isDarkMode
                    ? Colors.black.withOpacity(0.4)
                    : AppColors.primary.withOpacity(0.3),
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
            PositionedDirectional(
              end: -20.w,
              top: -20.h,
              child: CircleAvatar(
                radius: 60.r,
                backgroundColor:
                    AppColors.isDarkMode
                        ? AppColors.secondary.withOpacity(0.15)
                        : Colors.white.withOpacity(0.08),
              ),
            ),
            PositionedDirectional(
              start: -40.w,
              bottom: -40.h,
              child: CircleAvatar(
                radius: 80.r,
                backgroundColor:
                    AppColors.isDarkMode
                        ? AppColors.secondary.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
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
                        TranslationUtils.tr(
                          'ib_nav_transfer_comm',
                        ).toUpperCase(),
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
                      TranslationUtils.trArgs('ib_transfer_min_transfer', {
                        'amount': data?.minAmount?.toStringAsFixed(2) ?? "0.00",
                      }),
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

  Widget _buildHistoryCard(IbTransferHistoryItem item) {
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
        date = DateFormat(
          'dd MMM yyyy, HH:mm',
        ).format(DateTime.parse(item.requestedAt!));
      } catch (_) {}
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar or Icon based on status
              Container(
                height: 40.w,
                width: 40.w,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status == 'completed' || status == 'approved'
                      ? Icons.check_circle_outline
                      : status == 'pending'
                      ? Icons.access_time
                      : Icons.cancel_outlined,
                  color: statusColor,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              // Main details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.toClientName ??
                          (item.toClientUserId != null
                              ? TranslationUtils.trArgs(
                                'ib_transfer_client_number',
                                {'id': '${item.toClientUserId}'},
                              )
                              : TranslationUtils.tr('ib_transfer_unknown_client')),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          '#${item.id}',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 11.sp,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          width: 3.w,
                          height: 3.w,
                          decoration: BoxDecoration(
                            color: AppColors.textGrey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          date,
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Amount and Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${item.amount != null ? (double.tryParse(item.amount!)?.toStringAsFixed(2) ?? item.amount!) : "0.00"}',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (status == 'pending') ...[
                        SizedBox(width: 6.w),
                        GestureDetector(
                          onTap: () {
                            Get.dialog(
                              Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                backgroundColor: AppColors.card,
                                surfaceTintColor: Colors.transparent,
                                child: Padding(
                                  padding: EdgeInsets.all(24.w),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(12.w),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.cancel_outlined,
                                          color: Colors.red,
                                          size: 36.sp,
                                        ),
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        TranslationUtils.tr(
                                          'ib_transfer_cancel_transfer',
                                        ),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 12.h),
                                      Text(
                                        TranslationUtils.tr(
                                          'ib_transfer_cancel_confirm_message',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                      SizedBox(height: 24.h),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () => Get.back(),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 12.h,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        10.r,
                                                      ),
                                                ),
                                              ),
                                              child: Text(
                                                TranslationUtils.tr(
                                                  'ib_transfer_no_keep_it',
                                                ),
                                                style: TextStyle(
                                                  color: AppColors.textGrey,
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                Get.back();
                                                _controller.cancelTransfer(
                                                  item.id!,
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                elevation: 0,
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 12.h,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        10.r,
                                                      ),
                                                ),
                                              ),
                                              child: Text(
                                                TranslationUtils.tr(
                                                  'cregis_address_screen_yes_cancel',
                                                ),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              TranslationUtils.tr('account_management_cancel'),
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Comment Section (Compact)
          if (item.ibComment != null && item.ibComment!.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.format_quote,
                    color: AppColors.textGrey,
                    size: 12.sp,
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      item.ibComment!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.sp,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}
