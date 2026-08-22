import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class CreateEditPlanScreen extends StatefulWidget {
  final int? planId;

  const CreateEditPlanScreen({super.key, this.planId});

  @override
  State<CreateEditPlanScreen> createState() => _CreateEditPlanScreenState();
}

class _CreateEditPlanScreenState extends State<CreateEditPlanScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  bool _isActive = true;

  // Storing the API caps (available groups and max rates)
  List<dynamic> _availableCaps = [];

  // Storing the user's selected groups and rates.
  // Format: group_id -> { 'rates': {catId: rate}, 'symbol_rates': {symId: rate}, 'blocked': [symId], 'expanded': bool }
  final Map<int, Map<String, dynamic>> _selectedGroups = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.planId != null) {
        // Edit Mode
        final res = await IbmApiProvider().getPartnerPlanDetail(widget.planId!);
        if (res.success && res.data != null) {
          _parseData(res.data);
        } else {
          _error = res.message ?? 'Failed to load plan details';
        }
      } else {
        // Create Mode
        final res = await IbmApiProvider().getPartnerPlanTemplate();
        if (res.success && res.data != null) {
          _parseData(res.data);
        } else {
          _error = res.message ?? 'Failed to load plan template';
        }
      }
    } catch (e) {
      _error = 'Error loading data: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _parseData(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    final payload = data['data'] ?? data;

    if (widget.planId != null) {
      final planData = payload['plan'] ?? {};
      _nameController.text = planData['name'] ?? '';
      _descController.text = planData['description'] ?? '';
      _isActive = planData['is_active'] == true || planData['is_active'] == 1;
    }

    // Parse selected/draft groups
    final draftList = payload['draft'] ?? payload['groups'] ?? [];
    if (draftList is List) {
      for (var group in draftList) {
        int groupId = group['group_id'] ?? group['id'] ?? 0;
        if (groupId != 0) {
          _selectedGroups[groupId] = {
            'rates':
                group['rates'] is Map
                    ? Map<String, dynamic>.from(group['rates'])
                    : <String, dynamic>{},
            'symbol_rates':
                group['symbol_rates'] is Map
                    ? Map<String, dynamic>.from(group['symbol_rates'])
                    : <String, dynamic>{},
            'blocked':
                group['blocked_symbol_ids'] is List
                    ? List<dynamic>.from(group['blocked_symbol_ids'])
                    : <dynamic>[],
            'expanded': false,
          };
        }
      }
    }

    // Parse available groups and maximum rates
    if (payload['caps'] is List) {
      _availableCaps = List.from(payload['caps']);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Construct groups payload
    List<Map<String, dynamic>> groupsPayload = [];
    _selectedGroups.forEach((groupId, data) {
      groupsPayload.add({
        'group_id': groupId,
        'rates': data['rates'],
        'symbol_rates': data['symbol_rates'],
        'blocked_symbol_ids': data['blocked'],
      });
    });

    final payload = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'is_active': _isActive,
      'groups': groupsPayload,
    };

    setState(() {
      _isSubmitting = true;
    });

    try {
      final res =
          widget.planId == null
              ? await IbmApiProvider().createPartnerPlan(payload)
              : await IbmApiProvider().updatePartnerPlan(
                widget.planId!,
                payload,
              );

      if (res.success) {
        CustomToastService.show(
          message:
              widget.planId == null
                  ? 'Plan created successfully'
                  : 'Plan updated successfully',
        );
        Get.back(result: true);
      } else {
        CustomToastService.show(message: res.message ?? 'Failed to save plan');
      }
    } catch (e) {
      CustomToastService.show(message: 'Error saving plan');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        title: Text(
          widget.planId == null ? 'Create Partner Plan' : 'Edit Partner Plan',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp),
        ),
        backgroundColor: AppColors.whiteColor,
        elevation: 1,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '1 • Details'),
            Tab(text: '2 • Groups & Rates'),
          ],
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : _error != null
              ? Center(
                child: Text(_error!, style: TextStyle(color: Colors.red)),
              )
              : TabBarView(
                controller: _tabController,
                physics:
                    const NeverScrollableScrollPhysics(), // Prevent swipe to force Next button usage if wanted
                children: [_buildDetailsTab(), _buildGroupsRatesTab()],
              ),
      bottomNavigationBar:
          _isLoading || _error != null
              ? null
              : Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(minimumSize: Size.zero),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          _isSubmitting
                              ? null
                              : () {
                                if (_tabController.index == 0) {
                                  if (_formKey.currentState!.validate()) {
                                    _tabController.animateTo(1);
                                  }
                                } else {
                                  _submit();
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        minimumSize:
                            Size.zero, // Override global infinite width
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child:
                          _isSubmitting
                              ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: CircularProgressIndicator(
                                  color: AppColors.whiteColor,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                _tabController.index == 0
                                    ? 'Next: Groups & Rates'
                                    : 'Save Plan',
                                style: TextStyle(
                                  color: AppColors.whiteColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan name *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 12.h,
                ),
              ),
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            SizedBox(height: 24.h),
            Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 12.h,
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            SwitchListTile(
              title: Text(
                _isActive ? 'Active' : 'Inactive',
                style: TextStyle(fontSize: 14.sp),
              ),
              value: _isActive,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  _isActive = val;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsRatesTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          margin: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18.w,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Rates shown in Parent cap are the maximum you can give. You can only use groups your master plan includes.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _availableCaps.isEmpty
                  ? Center(
                    child: Text(
                      'No groups available',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                  : ListView.builder(
                    itemCount: _availableCaps.length,
                    itemBuilder: (context, index) {
                      final cap = _availableCaps[index];
                      final int groupId = cap['group_id'] ?? cap['id'] ?? 0;
                      final String groupName =
                          cap['group_name'] ?? cap['name'] ?? 'Group $groupId';
                      final bool isAdded = _selectedGroups.containsKey(groupId);

                      return _buildGroupRow(groupId, groupName, cap, isAdded);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildGroupRow(
    int groupId,
    String groupName,
    dynamic cap,
    bool isAdded,
  ) {
    final bool isExpanded =
        isAdded && _selectedGroups[groupId]!['expanded'] == true;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    groupName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                if (isAdded)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedGroups[groupId]!['expanded'] = !isExpanded;
                          });
                        },
                        style: TextButton.styleFrom(minimumSize: Size.zero),
                        icon: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16.w,
                          color: AppColors.textPrimary,
                        ),
                        label: Text(
                          isExpanded ? 'Close' : 'Set rates',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedGroups.remove(groupId);
                          });
                        },
                        style: TextButton.styleFrom(minimumSize: Size.zero),
                        icon: Icon(Icons.close, size: 16.w, color: Colors.red),
                        label: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedGroups[groupId] = {
                          'rates': <String, dynamic>{},
                          'symbol_rates': <String, dynamic>{},
                          'blocked': <dynamic>[],
                          'expanded': true,
                        };
                      });
                    },
                    style: TextButton.styleFrom(minimumSize: Size.zero),
                    icon: Icon(
                      Icons.add,
                      size: 16.w,
                      color: AppColors.textPrimary,
                    ),
                    label: Text(
                      'Add',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
              ],
            ),
          ),
          if (isExpanded) _buildRatesForm(groupId, cap),
        ],
      ),
    );
  }

  Widget _buildRatesForm(int groupId, dynamic cap) {
    // Attempt to extract categories / instruments
    List<dynamic> categories = cap['categories'] ?? cap['rates'] ?? [];
    List<dynamic> symbolRates = cap['symbol_rates'] ?? [];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REBATE PER INSTRUMENT TYPE',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 12.h),

          if (categories.isEmpty)
            Text(
              'No instrument categories found.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
            )
          else
            ...categories.map((cat) {
              final String catId =
                  (cat['symbol_category_id'] ??
                          cat['id'] ??
                          cat['category_id'] ??
                          '')
                      .toString();
              final String name =
                  cat['category'] ??
                  cat['name'] ??
                  cat['category_name'] ??
                  'Category $catId';
              final double parentCap =
                  double.tryParse(
                    cat['max_allowed']?.toString() ??
                        cat['max_rate']?.toString() ??
                        '0',
                  ) ??
                  0;

              // Get current set rate
              double currentRate =
                  double.tryParse(
                    _selectedGroups[groupId]!['rates'][catId]?.toString() ??
                        '0',
                  ) ??
                  0;

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(name, style: TextStyle(fontSize: 13.sp)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$$parentCap',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue:
                            currentRate > 0 ? currentRate.toString() : '',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 8.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        onChanged: (val) {
                          double newRate = double.tryParse(val) ?? 0;
                          _selectedGroups[groupId]!['rates'][catId] = newRate;
                          // Force rebuild to update 'You Keep'
                          setState(() {});
                        },
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        (parentCap - currentRate).toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

          if (symbolRates.isNotEmpty) ...[
            SizedBox(height: 24.h),
            Text(
              'REBATE PER SYMBOL (OVERRIDES INSTRUMENT TYPE)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12.h),
            ...symbolRates.map((sym) {
              final String symId =
                  (sym['symbol_id'] ?? sym['id'] ?? '').toString();
              final String name =
                  sym['name'] ?? sym['symbol_name'] ?? 'Symbol $symId';
              final double parentCap =
                  double.tryParse(
                    sym['max_allowed']?.toString() ??
                        sym['max_rate']?.toString() ??
                        '0',
                  ) ??
                  0;

              // Get current set symbol rate
              double currentRate =
                  double.tryParse(
                    _selectedGroups[groupId]!['symbol_rates'][symId]
                            ?.toString() ??
                        '0',
                  ) ??
                  0;

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(name, style: TextStyle(fontSize: 13.sp)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$$parentCap',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue:
                            currentRate > 0 ? currentRate.toString() : '',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 8.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        onChanged: (val) {
                          double newRate = double.tryParse(val) ?? 0;
                          _selectedGroups[groupId]!['symbol_rates'][symId] =
                              newRate;
                          setState(() {});
                        },
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        (parentCap - currentRate).toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],

          SizedBox(height: 24.h),
          Text(
            'BLOCK SYMBOLS (SUB-IB WON\'T EARN ON THESE)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'This feature is complex and best handled via the desktop portal at this time.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
