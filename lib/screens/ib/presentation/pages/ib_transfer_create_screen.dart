import 'dart:async';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/ib/view_models/ib_transfer_controller.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class IbTransferCreateScreen extends StatefulWidget {
  const IbTransferCreateScreen({super.key});

  @override
  State<IbTransferCreateScreen> createState() => _IbTransferCreateScreenState();
}

class _IbTransferCreateScreenState extends State<IbTransferCreateScreen> {
  late IbTransferController _controller;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  int? _selectedClientId;
  String? _selectedClientName;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<IbTransferController>();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submitTransfer() async {
    if (_selectedClientId == null) {
      CustomToastService.showError(
        message: 'Please select a recipient client.',
      );
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      CustomToastService.showError(message: 'Please enter a valid amount.');
      return;
    }
    final initData = _controller.initData.value;
    if (initData != null &&
        initData.minAmount != null &&
        amount < initData.minAmount!) {
      CustomToastService.showError(
        message: 'Minimum transfer amount is \$${initData.minAmount}.',
      );
      return;
    }
    if (initData != null &&
        initData.availableBalance != null &&
        amount > initData.availableBalance!) {
      CustomToastService.showError(
        message: 'Amount exceeds available balance.',
      );
      return;
    }

    final success = await _controller.submitTransfer(
      toClientId: _selectedClientId!,
      amount: amount,
      comment: _commentController.text,
    );

    if (success) {
      Get.back();
    }
  }

  void _showClientSearchSheet() {
    _controller.searchResults.clear();
    _controller.searchClients(''); // Load default list
    Timer? _debounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.tradeBackgroundCenterColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 20.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Text(
                'Select Recipient',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: TextField(
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: AppColors.textGrey),
                    hintText: 'Search by name or email...',
                    hintStyle: TextStyle(color: AppColors.textGrey),
                    filled: true,
                    fillColor: AppColors.cardBackGround,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      _controller.searchClients(value);
                    });
                  },
                ),
              ),
              SizedBox(height: 10.h),
              Expanded(
                child: Obx(() {
                  if (_controller.isSearching.value) {
                    return Center(
                      child: CommonLoadingWidget(
                        size: 30,
                        color: AppColors.primary,
                      ),
                    );
                  }
                  if (_controller.searchResults.isEmpty) {
                    return Center(
                      child: Text(
                        'No clients found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 14.sp,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    itemCount: _controller.searchResults.length,
                    separatorBuilder:
                        (_, __) => Divider(
                          color: AppColors.border.withValues(alpha: 0.3),
                        ),
                    itemBuilder: (context, index) {
                      final client = _controller.searchResults[index];
                      return ListTile(
                        title: Text(
                          client.name ?? '',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        subtitle: Text(
                          client.email ?? '',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12.sp,
                          ),
                        ),
                        trailing: Text(
                          '#${client.id}',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12.sp,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedClientId = client.id;
                            _selectedClientName = client.name;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15.sp,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        elevation: 0,
        leading: AppBackButton(onPressed: () => Get.back()),
        title: Text(
          'New Transfer',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        if (_controller.isLoadingInit.value &&
            _controller.initData.value == null) {
          return Center(
            child: CommonLoadingWidget(size: 40, color: AppColors.primary),
          );
        }

        final data = _controller.initData.value;
        final isEnabled = data?.enabled ?? false;

        if (!isEnabled && data != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, color: AppColors.error, size: 48.sp),
                SizedBox(height: 12.h),
                Text(
                  'Transfers are currently disabled.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 14.sp),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Form Fields
              _buildLabel('Recipient Client *'),
              GestureDetector(
                onTap: _showClientSearchSheet,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackGround,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedClientName ?? 'Select a client',
                        style: TextStyle(
                          color:
                              _selectedClientName == null
                                  ? AppColors.textGrey
                                  : AppColors.textPrimary,
                          fontSize: 14.sp,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textGrey,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              _buildLabel('Transfer Amount (USD) *'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.cardBackGround,
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: AppColors.textGrey,
                          size: 20.sp,
                        ),
                        hintText: '0.00',
                        hintStyle: TextStyle(color: AppColors.textGrey),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 14.h,
                          horizontal: 16.w,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: AppColors.brandPrimary),
                        ),
                      ),
                    ),
                  ),
                  // SizedBox(width: 10.w),
                  // GestureDetector(
                  //   onTap: () {
                  //     if (data?.availableBalance != null) {
                  //       _amountController.text = data!.availableBalance!.toStringAsFixed(2);
                  //     }
                  //   },
                  //   child: Container(
                  //     padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  //     decoration: BoxDecoration(
                  //       color: AppColors.primary.withValues(alpha: 0.1),
                  //       borderRadius: BorderRadius.circular(10.r),
                  //     ),
                  //     child: Text(
                  //       'MAX',
                  //       style: TextStyle(
                  //         color: AppColors.primary,
                  //         fontWeight: FontWeight.w400,
                  //         fontSize: 15.sp,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              SizedBox(height: 20.h),

              _buildLabel('Note / Comment (Optional)'),
              TextFormField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 500,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardBackGround,
                  hintText: 'Add a note for admin...',
                  hintStyle: TextStyle(color: AppColors.textGrey),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 14.h,
                    horizontal: 16.w,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppColors.brandPrimary),
                  ),
                ),
              ),
              SizedBox(height: 30.h),

              ElevatedButton(
                onPressed:
                    _controller.isSubmitting.value ? null : _submitTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child:
                    _controller.isSubmitting.value
                        ? SizedBox(
                          height: 20.h,
                          width: 20.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onColoredBackground,
                          ),
                        )
                        : Text(
                          'Submit Request',
                          style: TextStyle(
                            color: AppColors.onColoredBackground,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
