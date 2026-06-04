import 'package:crm_app/widgets/common_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/models/ib_models.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class CommissionGroupFormScreen extends StatefulWidget {
  final CommissionGroup? group;

  const CommissionGroupFormScreen({super.key, this.group});

  @override
  State<CommissionGroupFormScreen> createState() =>
      _CommissionGroupFormScreenState();
}

class _CommissionGroupFormScreenState extends State<CommissionGroupFormScreen> {
  late IBController ibController;
  final TextEditingController _groupNameController = TextEditingController();
  final Map<String, TextEditingController> _commissionControllers = {};
  final Map<int, bool> _expandedGroups =
      {}; // Track expanded state for each group
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Get or create IBController
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }
    _loadStructureDataAndInitialize();
  }

  Future<void> _loadStructureDataAndInitialize() async {
    // Always load structure data to ensure we have latest data
    await ibController.getIBStructure(showLoading: true);
    if (mounted) {
      setState(() {
        // Force rebuild after data loads
      });
      _initializeForm();
    }
  }

  void _initializeForm() {
    if (widget.group != null) {
      _groupNameController.text = widget.group!.groupName ?? '';
      _loadExistingCommissionData();
    } else {
      _initializeEmptyForm();
    }
  }

  void _initializeEmptyForm() {
    final structureData = ibController.ibStructureData.value;
    if (structureData?.masterGroups != null &&
        structureData?.symbolCategories != null) {
      for (var masterGroup in structureData!.masterGroups!) {
        for (var category in structureData.symbolCategories!) {
          final key = '${masterGroup.id}_${category.id}';
          _commissionControllers[key] = TextEditingController(text: '0');
        }
      }
    }
  }

  void _loadExistingCommissionData() {
    if (widget.group?.parsedCommissionData != null) {
      final data = widget.group!.parsedCommissionData!;
      for (var masterId in data.keys) {
        final masterData = data[masterId];
        if (masterData is Map && masterData['commission'] != null) {
          final commissions = masterData['commission'] as Map;
          for (var categoryId in commissions.keys) {
            final key = '${masterId}_$categoryId';
            final value = commissions[categoryId];
            _commissionControllers[key] = TextEditingController(
              text: value?.toString() ?? '0',
            );
          }
        }
      }
    } else {
      _initializeEmptyForm();
    }
  }

  double? _getMaxValue(int masterId, int categoryId) {
    final structureData = ibController.ibStructureData.value;
    if (structureData?.masterGroups != null) {
      final masterGroup = structureData!.masterGroups!.firstWhere(
        (g) => g.id == masterId,
        orElse: () => MasterGroup(),
      );
      if (masterGroup.commissions != null) {
        final category = structureData.symbolCategories?.firstWhere(
          (c) => c.id == categoryId,
          orElse: () => SymbolCategory(),
        );
        if (category?.categoryName != null) {
          final commissionStr =
              masterGroup.commissions![category!.categoryName!];
          if (commissionStr != null && commissionStr.isNotEmpty) {
            final value = double.tryParse(commissionStr);
            if (value != null) {
              return value;
            }
          }
        }
      }
    }
    return null;
  }

  Future<void> _saveGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Please enter a group name',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final structureData = ibController.ibStructureData.value;
      if (structureData?.masterGroups == null) {
        throw Exception('Structure data not loaded');
      }

      final masterIds = structureData!.masterGroups!.map((g) => g.id!).toList();
      final commissionRates = <String, dynamic>{};

      // Ensure all commission rates are included (even if 0)
      for (var masterGroup in structureData.masterGroups!) {
        for (var category in structureData.symbolCategories!) {
          final key = '${masterGroup.id}_${category.id}';
          final controller = _commissionControllers[key];
          if (controller != null) {
            final value = controller.text.trim();
            final numValue = double.tryParse(value) ?? 0;
            commissionRates['${masterGroup.id}_${category.id}'] =
                numValue.toInt();
          } else {
            commissionRates['${masterGroup.id}_${category.id}'] = 0;
          }
        }
      }

      final success = await ibController.manageCommissionGroup(
        groupName: _groupNameController.text.trim(),
        masterIds: masterIds,
        structureType: 'standard',
        commissionRates: commissionRates,
        groupId: widget.group?.id,
      );

      if (success) {
        Get.back();
      }
    } catch (e) {
      CustomToastService.showError(
        title: 'Error',
        message: 'Failed to save group: $e',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    for (var controller in _commissionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          widget.group != null ? 'Edit Standard Group' : 'Add Standard Group',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: GetBuilder<IBController>(
        id: 'ib_structure',
        builder: (controller) {
          return Obx(() {
            final isLoading = controller.isLoading.value;
            final structureData = controller.ibStructureData.value;

            if (isLoading) {
              return Center(
                child: CommonLoadingWidget(
                  message: 'Loading structure data...',
                  size: 50.0,
                  color: AppColors.primary,
                ),
              );
            }

            if (structureData == null ||
                structureData.masterGroups == null ||
                structureData.masterGroups!.isEmpty ||
                structureData.symbolCategories == null ||
                structureData.symbolCategories!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48.sp,
                      color: AppColors.textGrey,
                    ),
                    SizedBox(height: 16.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.w),
                      child: Text(
                        controller.errorMessage.value.isNotEmpty
                            ? controller.errorMessage.value
                            : 'Failed to load structure data',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () {
                        _loadStructureDataAndInitialize();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    width: double.infinity,
                    color: AppColors.whiteColor,
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Standard Group Structure',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Standard Group Structure: Create commission groups for Sub-IBs. Commission rates cannot exceed your own rates.',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Group Name Section
                  Container(
                    width: double.infinity,
                    color: AppColors.whiteColor,
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Group Name',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: _groupNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter group name',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14.sp,
                            ),
                            filled: true,
                            fillColor: AppColors.whiteColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 6.h,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // SizedBox(height: 12.h),

                  // Commission Rates Section
                  Container(
                    width: double.infinity,
                    color: AppColors.whiteColor,
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Commission Rates (Category-wise)',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        _buildCommissionList(
                          structureData.masterGroups!,
                          structureData.symbolCategories!,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 80.h), // Space for bottom buttons
                ],
              ),
            );
          });
        },
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isLoading
                          ? SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.whiteColor,
                              ),
                            ),
                          )
                          : Text(
                            'Save Standard Group',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.whiteColor,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommissionList(
    List<MasterGroup> masterGroups,
    List<SymbolCategory> categories,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: masterGroups.length,
      itemBuilder: (context, index) {
        final group = masterGroups[index];
        final isExpanded = _expandedGroups[index] ?? false;
        return _buildExpandableGroupCard(group, index, isExpanded, categories);
      },
    );
  }

  Widget _buildExpandableGroupCard(
    MasterGroup masterGroup,
    int index,
    bool isExpanded,
    List<SymbolCategory> symbolCategories,
  ) {
    final groupName = masterGroup.planTitle ?? 'N/A';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isExpanded ? AppColors.primary : Colors.grey[300]!,
          width: isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header - Always visible (collapsed/expanded toggle)
          InkWell(
            onTap: () {
              setState(() {
                _expandedGroups[index] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12.r),
              topRight: Radius.circular(12.r),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: !isExpanded ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.all(Radius.circular(12.r)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    groupName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color:
                          isExpanded ? AppColors.primary : AppColors.whiteColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Animated triangle icon (caret)
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color:
                          isExpanded ? AppColors.primary : AppColors.whiteColor,
                      size: 24.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded Content
          if (isExpanded)
            Container(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 16.h,
                bottom: 20.h,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child:
                  symbolCategories.isEmpty
                      ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Center(
                          child: Text(
                            'No categories available',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            symbolCategories.asMap().entries.map((entry) {
                              final category = entry.value;
                              final isLast =
                                  entry.key == symbolCategories.length - 1;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: isLast ? 0 : 16.h,
                                ),
                                child: _buildCategoryInput(
                                  masterGroup,
                                  category,
                                ),
                              );
                            }).toList(),
                      ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryInput(MasterGroup masterGroup, SymbolCategory category) {
    final key = '${masterGroup.id}_${category.id}';
    final controller =
        _commissionControllers[key] ??= TextEditingController(text: '0');
    final maxValue = _getMaxValue(masterGroup.id!, category.id!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                category.categoryName ?? 'N/A',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            SizedBox(
              width: 110.w,
              child: TextField(
                controller: controller,
                readOnly: maxValue != null && maxValue == 0,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  _MaxValueInputFormatter(maxValue),
                ],
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color:
                      (maxValue != null && maxValue == 0)
                          ? Colors.grey[600]
                          : AppColors.primary,
                ),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(
                    color:
                        (maxValue != null && maxValue == 0)
                            ? Colors.grey[600]
                            : AppColors.primary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  filled: true,
                  fillColor:
                      (maxValue != null && maxValue == 0)
                          ? Colors.grey.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color:
                          (maxValue != null && maxValue == 0)
                              ? Colors.grey.withOpacity(0.3)
                              : AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            maxValue != null
                ? 'Max: \$${maxValue.toStringAsFixed(2)}'
                : 'Max: \$0.00',
            style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }
}

/// Custom formatter that limits input to values <= [maxValue].
/// If [maxValue] is null, no upper bound is applied.
/// Supports decimal values (e.g. 13.99, 6.50).
class _MaxValueInputFormatter extends TextInputFormatter {
  final double? maxValue;

  _MaxValueInputFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    if (text.isEmpty) return newValue;

    // Handle replacing initial "0" when typing a new digit
    if (oldValue.text == '0' && text.length == 2 && text != '0.') {
      if (text.startsWith('0')) {
        text = text.substring(1);
        newValue = newValue.copyWith(
          text: text,
          selection: const TextSelection.collapsed(offset: 1),
        );
      } else if (text.endsWith('0')) {
        text = text.substring(0, 1);
        newValue = newValue.copyWith(
          text: text,
          selection: const TextSelection.collapsed(offset: 1),
        );
      }
    }

    // Prevent leading zeros like "00", "000", "0000"
    // Allow "0" alone or "0.xx" (decimal starting with zero)
    if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
      return oldValue;
    }

    // Allow a trailing dot while the user is still typing (e.g. "13.")
    // We only validate once they type a digit after the dot.
    if (text.endsWith('.')) {
      final base = double.tryParse(text.substring(0, text.length - 1));
      if (base == null) return oldValue;
      if (maxValue != null && base > maxValue!) return oldValue;
      return newValue;
    }

    final parsed = double.tryParse(text);
    if (parsed == null) return oldValue;

    // If no max, allow any non-negative number
    if (maxValue == null) {
      return parsed >= 0 ? newValue : oldValue;
    }

    // Reject if exceeds max
    return parsed <= maxValue! ? newValue : oldValue;
  }
}
