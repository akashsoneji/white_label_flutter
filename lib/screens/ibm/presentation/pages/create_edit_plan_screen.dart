import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/widgets/custom_toast.dart';

class CreateEditPlanScreen extends StatefulWidget {
  final int? planId;
  final bool readOnly;

  const CreateEditPlanScreen({
    super.key,
    this.planId,
    this.readOnly = false,
  });

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
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
          // If template returns null or error, fallback to building from groups
          _fallbackDefaultCaps();
        }
      }
    } catch (e) {
      _fallbackDefaultCaps();
    } finally {
      if (mounted) {
        if (_availableCaps.isEmpty) {
          _fallbackDefaultCaps();
        }
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _fallbackDefaultCaps() {
    if (_availableCaps.isNotEmpty) return;
    _availableCaps = [
      {
        'group_id': 1,
        'name': 'Standard',
        'categories': [
          {'category_id': 1, 'name': 'Forex / Currency', 'max_rate': 10.0, 'max_allowed': 10.0},
          {'category_id': 2, 'name': 'Metals / Commodities', 'max_rate': 10.0, 'max_allowed': 10.0},
          {'category_id': 3, 'name': 'Indices', 'max_rate': 5.0, 'max_allowed': 5.0},
          {'category_id': 4, 'name': 'Crypto', 'max_rate': 15.0, 'max_allowed': 15.0},
        ],
      },
      {
        'group_id': 2,
        'name': 'PRO',
        'categories': [
          {'category_id': 1, 'name': 'Forex / Currency', 'max_rate': 8.0, 'max_allowed': 8.0},
          {'category_id': 2, 'name': 'Metals / Commodities', 'max_rate': 8.0, 'max_allowed': 8.0},
          {'category_id': 3, 'name': 'Indices', 'max_rate': 4.0, 'max_allowed': 4.0},
          {'category_id': 4, 'name': 'Crypto', 'max_rate': 10.0, 'max_allowed': 10.0},
        ],
      },
      {
        'group_id': 3,
        'name': 'PRO 25',
        'categories': [
          {'category_id': 1, 'name': 'Forex / Currency', 'max_rate': 6.0, 'max_allowed': 6.0},
          {'category_id': 2, 'name': 'Metals / Commodities', 'max_rate': 6.0, 'max_allowed': 6.0},
        ],
      },
      {
        'group_id': 4,
        'name': 'Standard 30',
        'categories': [
          {'category_id': 1, 'name': 'Forex / Currency', 'max_rate': 10.0, 'max_allowed': 10.0},
          {'category_id': 2, 'name': 'Metals / Commodities', 'max_rate': 10.0, 'max_allowed': 10.0},
        ],
      },
    ];
  }

  final Map<String, int> _symbolNameToId = {};
  final Map<int, String> _symbolIdToName = {};

  void _parseData(dynamic rawData) {
    if (rawData == null) return;
    Map<String, dynamic> payload = {};
    if (rawData is Map) {
      payload = Map<String, dynamic>.from(rawData);
    }
    if (payload['data'] is Map) {
      payload = Map<String, dynamic>.from(payload['data']);
    }

    // Parse symbol catalogue
    if (payload['symbol_catalogue'] is Map && payload['symbol_catalogue']['names'] is Map) {
      final names = payload['symbol_catalogue']['names'] as Map;
      names.forEach((k, v) {
        final id = int.tryParse(k.toString());
        final name = v.toString().toUpperCase();
        if (id != null) {
          _symbolNameToId[name] = id;
          _symbolIdToName[id] = name;
        }
      });
    }

    if (widget.planId != null) {
      final planData = payload['plan'] is Map ? payload['plan'] as Map : payload;
      _nameController.text = planData['name']?.toString() ?? planData['plan_name']?.toString() ?? '';
      _descController.text = planData['description']?.toString() ?? '';
      _isActive = planData['is_active'] == true || planData['is_active'] == 1 || planData['is_active'] == null;
    }

    // Parse selected/draft groups
    final draftList = payload['draft'] ?? payload['groups'] ?? payload['plan_groups'] ?? [];
    if (draftList is List) {
      for (var group in draftList) {
        if (group is! Map) continue;
        int groupId = int.tryParse((group['group_id'] ?? group['id'] ?? group['plan_group_id'] ?? 0).toString()) ?? 0;
        int planGroupId = int.tryParse((group['plan_group_id'] ?? groupId).toString()) ?? groupId;
        if (groupId != 0) {
          final ratesMap = <String, dynamic>{};
          if (group['rates'] is Map) {
            (group['rates'] as Map).forEach((k, v) => ratesMap[k.toString()] = v);
          } else if (group['categories'] is List) {
            for (var c in group['categories']) {
              if (c is Map) {
                final catId = (c['symbol_category_id'] ?? c['category_id'] ?? c['id'] ?? '').toString();
                final rate = c['rate'] ?? c['given'] ?? c['amount'] ?? 0;
                ratesMap[catId] = rate;
              }
            }
          }

          final symRatesMap = <String, dynamic>{};
          if (group['symbol_rates'] is Map) {
            (group['symbol_rates'] as Map).forEach((k, v) => symRatesMap[k.toString()] = v);
          } else if (group['symbols'] is List) {
            for (var s in group['symbols']) {
              if (s is Map) {
                final symId = (s['symbol_id'] ?? s['id'] ?? '').toString();
                final rate = s['rate'] ?? s['given'] ?? s['amount'] ?? 0;
                symRatesMap[symId] = rate;
              }
            }
          }

          // Parse blocked symbols and convert to readable names or ids
          final blockedList = <dynamic>[];
          if (group['blocked_symbol_ids'] is List) {
            for (var item in group['blocked_symbol_ids']) {
              final id = int.tryParse(item.toString());
              if (id != null && _symbolIdToName.containsKey(id)) {
                blockedList.add(_symbolIdToName[id]);
              } else {
                blockedList.add(item.toString());
              }
            }
          }

          _selectedGroups[groupId] = {
            'plan_group_id': planGroupId,
            'rates': ratesMap,
            'symbol_rates': symRatesMap,
            'blocked': blockedList,
            'expanded': true, // Auto-expand pre-selected groups
          };
        }
      }
    }

    // Parse available groups and maximum rates
    if (payload['caps'] is List) {
      _availableCaps = List.from(payload['caps']);
      // Also check if any group in caps has given rates
      for (var cap in _availableCaps) {
        if (cap is! Map) continue;
        int gId = int.tryParse((cap['group_id'] ?? cap['id'] ?? 0).toString()) ?? 0;
        if (gId != 0 && !_selectedGroups.containsKey(gId)) {
          bool hasGiven = false;
          final rMap = <String, dynamic>{};
          if (cap['categories'] is List) {
            for (var c in cap['categories']) {
              if (c is Map && c['given'] != null) {
                final catId = (c['symbol_category_id'] ?? c['category_id'] ?? c['id'] ?? '').toString();
                rMap[catId] = c['given'];
                hasGiven = true;
              }
            }
          }
          if (hasGiven) {
            _selectedGroups[gId] = {
              'plan_group_id': gId,
              'rates': rMap,
              'symbol_rates': <String, dynamic>{},
              'blocked': <dynamic>[],
              'expanded': true,
            };
          }
        }
      }
    } else if (payload['template'] is Map && payload['template']['caps'] is List) {
      _availableCaps = List.from(payload['template']['caps']);
    } else if (payload['groups'] is List && _availableCaps.isEmpty) {
      _availableCaps = List.from(payload['groups']);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      CustomToastService.showError(message: 'Please enter a plan name');
      _tabController.animateTo(0);
      return;
    }

    if (_selectedGroups.isEmpty) {
      CustomToastService.showError(message: 'Please add at least one group');
      return;
    }

    // Construct groups payload
    List<Map<String, dynamic>> groupsPayload = [];
    _selectedGroups.forEach((groupId, data) {
      final Map<String, dynamic> ratesMap = {};
      final List<Map<String, dynamic>> catList = [];
      if (data['rates'] is Map) {
        (data['rates'] as Map).forEach((catId, rate) {
          final double r = double.tryParse(rate.toString()) ?? 0.0;
          ratesMap[catId.toString()] = r;
          catList.add({
            'category_id': int.tryParse(catId.toString()) ?? catId,
            'rate': r,
          });
        });
      }

      final Map<String, dynamic> symRatesMap = {};
      final List<Map<String, dynamic>> symList = [];
      if (data['symbol_rates'] is Map) {
        (data['symbol_rates'] as Map).forEach((symId, rate) {
          final double r = double.tryParse(rate.toString()) ?? 0.0;
          symRatesMap[symId.toString()] = r;
          symList.add({
            'symbol_id': int.tryParse(symId.toString()) ?? symId,
            'rate': r,
          });
        });
      }

      // Convert blocked symbol strings to IDs if possible
      final List<int> blockedSymbolIds = [];
      if (data['blocked'] is List) {
        for (var item in data['blocked']) {
          final sName = item.toString().toUpperCase();
          if (_symbolNameToId.containsKey(sName)) {
            blockedSymbolIds.add(_symbolNameToId[sName]!);
          } else {
            final id = int.tryParse(sName);
            if (id != null) {
              blockedSymbolIds.add(id);
            }
          }
        }
      }

      groupsPayload.add({
        'plan_group_id': data['plan_group_id'] ?? groupId,
        'group_id': groupId,
        'rates': ratesMap,
        'categories': catList,
        'symbols': symList,
        'symbol_rates': symRatesMap,
        'blocked_symbol_ids': blockedSymbolIds,
      });
    });

    final payload = {
      'name': name,
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
        CustomToastService.showSuccess(
          message:
              widget.planId == null
                  ? 'Plan created successfully'
                  : 'Plan updated successfully',
        );
        if (Get.isRegistered<IbmController>()) {
          Get.find<IbmController>().fetchPlans();
          Get.find<IbmController>().fetchMyPlan();
        }
        Get.back(result: true);
      } else {
        CustomToastService.showError(message: res.message ?? 'Failed to save plan');
      }
    } catch (e) {
      CustomToastService.showError(message: 'Error saving plan: $e');
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
          widget.readOnly
              ? 'View Partner Plan'
              : (widget.planId == null
                  ? 'Create Partner Plan'
                  : 'Edit Partner Plan'),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp),
        ),
        backgroundColor: AppColors.whiteColor,
        elevation: 1,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        bottom: widget.readOnly
            ? null
            : TabBar(
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
              : widget.readOnly
              ? _buildReadOnlyBody()
              : TabBarView(
                controller: _tabController,
                physics:
                    const NeverScrollableScrollPhysics(), // Prevent swipe to force Next button usage if wanted
                children: [_buildDetailsTab(), _buildGroupsRatesTab()],
              ),
      bottomNavigationBar:
          _isLoading || _error != null || widget.readOnly
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
                child: SafeArea(
                  top: false,
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
              ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: _buildDetailsFields(),
    );
  }

  Widget _buildDetailsFields() {
    return Form(
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
            readOnly: widget.readOnly,
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
                (val) => val == null || val.trim().isEmpty ? 'Required' : null,
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
            readOnly: widget.readOnly,
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
            onChanged: widget.readOnly
                ? null
                : (val) {
                    setState(() {
                      _isActive = val;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.all(12.w),
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18.w, color: AppColors.textSecondary),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Rates shown in Parent cap are the maximum you can give. You can only use groups your master plan includes.',
              style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: _buildDetailsFields(),
          ),
          _buildInfoBanner(),
          if (_availableCaps.isEmpty)
            Padding(
              padding: EdgeInsets.all(24.w),
              child: Center(
                child: Text(
                  'No groups available',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...List.generate(_availableCaps.length, (index) {
              final cap = _availableCaps[index];
              final int groupId = cap['group_id'] ?? cap['id'] ?? 0;
              final String groupName =
                  cap['group_name'] ?? cap['name'] ?? 'Group $groupId';
              final bool isAdded = _selectedGroups.containsKey(groupId);
              return _buildGroupRow(groupId, groupName, cap, isAdded);
            }),
        ],
      ),
    );
  }

  Widget _buildGroupsRatesTab() {
    return Column(
      children: [
        _buildInfoBanner(),
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
                      if (!widget.readOnly)
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
                else if (!widget.readOnly)
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

  final Map<int, TextEditingController> _blockSymbolControllers = {};

  Widget _buildRatesForm(int groupId, dynamic cap) {
    // Attempt to extract categories / instruments
    List<dynamic> categories = cap['categories'] ?? cap['rates'] ?? [];
    List<dynamic> symbolRates = cap['symbol_rates'] ?? [];
    List<dynamic> blockedSymbols = _selectedGroups[groupId]!['blocked'] ?? [];

    if (!_blockSymbolControllers.containsKey(groupId)) {
      _blockSymbolControllers[groupId] = TextEditingController();
    }
    final blockController = _blockSymbolControllers[groupId]!;

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

          // Header Row
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'INSTRUMENT',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PARENT CAP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'YOUR RATE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'YOU KEEP',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                        cat['given']?.toString() ??
                        '0',
                  ) ??
                  0;

              final youKeep = (parentCap - currentRate).clamp(0.0, 999999.0);

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${parentCap.toStringAsFixed(2)}',
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
                            currentRate > 0 ? (currentRate % 1 == 0 ? currentRate.toInt().toString() : currentRate.toString()) : '',
                        readOnly: widget.readOnly,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 8.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                        ),
                        onChanged: (val) {
                          double newRate = double.tryParse(val) ?? 0;
                          _selectedGroups[groupId]!['rates'][catId] = newRate;
                          setState(() {});
                        },
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${youKeep.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

          if (symbolRates.isNotEmpty) ...[
            SizedBox(height: 20.h),
            Text(
              'REBATE PER SYMBOL (OVERRIDES INSTRUMENT TYPE)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12.h),
            // Header Row
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'SYMBOL',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'PARENT CAP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'YOUR RATE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'YOU KEEP',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                        sym['given']?.toString() ??
                        '0',
                  ) ??
                  0;

              final youKeep = (parentCap - currentRate).clamp(0.0, 999999.0);

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${parentCap.toStringAsFixed(2)}',
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
                            currentRate > 0 ? (currentRate % 1 == 0 ? currentRate.toInt().toString() : currentRate.toString()) : '',
                        readOnly: widget.readOnly,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 8.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6.r),
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
                        '\$${youKeep.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],

          SizedBox(height: 20.h),
          Text(
            'BLOCK SYMBOLS (SUB-IB WON\'T EARN ON THESE)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          if (!widget.readOnly) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: TextField(
                      controller: blockController,
                      decoration: InputDecoration(
                        hintText: 'Symbol name e.g. BTCUSD',
                        hintStyle: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton.icon(
                  onPressed: () {
                    final sym = blockController.text.trim().toUpperCase();
                    if (sym.isNotEmpty && !blockedSymbols.contains(sym)) {
                      setState(() {
                        blockedSymbols.add(sym);
                        _selectedGroups[groupId]!['blocked'] = blockedSymbols;
                        blockController.clear();
                      });
                    }
                  },
                  icon: Icon(Icons.block, size: 14.w, color: Colors.white),
                  label: const Text('Block'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Symbols are matched by name. Leave empty if you don\'t want to add restrictions.',
              style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary),
            ),
          ],
          if (blockedSymbols.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: blockedSymbols.map((sym) {
                return Chip(
                  label: Text(sym.toString(), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                  deleteIcon:
                      widget.readOnly ? null : const Icon(Icons.close, size: 14),
                  onDeleted: widget.readOnly
                      ? null
                      : () {
                          setState(() {
                            blockedSymbols.remove(sym);
                            _selectedGroups[groupId]!['blocked'] = blockedSymbols;
                          });
                        },
                  backgroundColor: Colors.red.shade50,
                  deleteIconColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade200),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
