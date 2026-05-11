import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/auth_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/utils/trl_helper.dart';

class ChangeLeverageScreen extends StatefulWidget {
  final String accountNumber;
  final int? currentLeverage; // Optional current leverage value

  const ChangeLeverageScreen({
    Key? key,
    required this.accountNumber,
    this.currentLeverage,
  }) : super(key: key);

  @override
  State<ChangeLeverageScreen> createState() => _ChangeLeverageScreenState();
}

class _ChangeLeverageScreenState extends State<ChangeLeverageScreen> {
  final AuthService _authService = Get.find<AuthService>();
  final List<int> _leverageValues = [30, 50, 100, 300, 400, 500];
  int? _selectedLeverage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set to current leverage if provided and valid, otherwise default to first value
    if (widget.currentLeverage != null &&
        _leverageValues.contains(widget.currentLeverage)) {
      _selectedLeverage = widget.currentLeverage;
    } else {
      _selectedLeverage = _leverageValues.first;
    }
  }

  String _formatLeverage(int leverage) {
    return '1:$leverage';
  }

  void _showLeveragePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final maxHeight = screenHeight * 0.7; // Use 70% of screen height max
        final itemHeight = 56.0; // Approximate height per item
        final headerHeight = 80.0; // Header + padding
        final calculatedHeight = (_leverageValues.length * itemHeight +
                headerHeight)
            .clamp(200.0, maxHeight);

        return Container(
          constraints: BoxConstraints(maxHeight: calculatedHeight),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
                    child: Row(
                      children: [
                        Text(
                          'Select Leverage',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: Colors.grey),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable list
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: ClampingScrollPhysics(),
                      itemCount: _leverageValues.length,
                      itemBuilder: (context, index) {
                        final leverage = _leverageValues[index];
                        final isSelected = _selectedLeverage == leverage;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedLeverage = leverage;
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 16.h,
                              horizontal: 24.w,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _formatLeverage(leverage),
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                  ),
                                ),
                                Spacer(),
                                if (isSelected)
                                  Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitLeverageChange() async {
    if (_selectedLeverage == null) {
      CustomToastService.showError(message: 'Please select a leverage value');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authService.changeLeverage(
        mt5Account: widget.accountNumber,
        leverage: _selectedLeverage!,
      );

      if (response.success) {
        CustomToastService.showSuccess(
          message: response.data?['message'] ?? 'Leverage changed successfully',
        );
        Get.back(closeOverlays: true);
      } else {
        CustomToastService.showError(
          message: response.message ?? 'Failed to change leverage',
        );
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Change Leverage'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Number Display
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_circle, color: AppColors.primary),
                  SizedBox(width: 12.w),
                  Text(
                    'Account: ${widget.accountNumber}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),

            // Leverage Dropdown
            Text(
              'Select Leverage',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey,
              ),
            ),
            SizedBox(height: 8.h),
            RTLHelper.rtlTextField(
              controller: TextEditingController(
                text:
                    _selectedLeverage != null
                        ? _formatLeverage(_selectedLeverage!)
                        : '',
              ),
              readOnly: true,
              onTap: _showLeveragePicker,
              suffixIcon: InkWell(
                onTap: _showLeveragePicker,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: RTLHelper.rtlIcon(
                    Icons.keyboard_arrow_down_outlined,
                    color: Colors.grey,
                  ),
                ),
              ),
              decoration: InputDecoration(
                hintText: 'Select leverage',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 16.h,
                ),
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
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            SizedBox(height: 32.h),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitLeverageChange,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.whiteColor,
                            ),
                          ),
                        )
                        : Text(
                          'Change Leverage',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.whiteColor,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
