import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/models/ib_models.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/common_loading_widget.dart';

/// "My Network": the IB downline from `GET ib/tree-structure`, searchable by
/// name/email. Tapping a node opens `GET ib/get-ib-details/{userSlug}`.
class IbNetworkTreeScreen extends StatefulWidget {
  const IbNetworkTreeScreen({super.key});

  @override
  State<IbNetworkTreeScreen> createState() => _IbNetworkTreeScreenState();
}

class _IbNetworkTreeScreenState extends State<IbNetworkTreeScreen> {
  final IBController _c = Get.isRegistered<IBController>()
      ? Get.find<IBController>()
      : Get.put(IBController());
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.loadNetworkTree());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          TranslationUtils.tr('ib_network_title'),
          style: AppTextStyles.screenTitle,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.sp,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: TranslationUtils.tr('ib_network_search_hint'),
                  prefixIcon: Icon(Icons.search, size: 18.sp),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                final tree = _c.networkTree.toList();
                if (_c.isNetworkTreeLoading.value && tree.isEmpty) {
                  return const Center(
                    child: CommonLoadingWidget(isFullScreen: false),
                  );
                }
                if (_c.networkTreeError.value.isNotEmpty && tree.isEmpty) {
                  return _CenteredMessage(
                    icon: Icons.error_outline_rounded,
                    message: _c.networkTreeError.value,
                    onRetry: _c.loadNetworkTree,
                  );
                }
                final query = _searchCtrl.text.trim();
                final visible = tree.where((n) => n.matches(query)).toList();
                if (visible.isEmpty) {
                  return _CenteredMessage(
                    icon: Icons.account_tree_outlined,
                    message: TranslationUtils.tr('ib_network_empty'),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _c.loadNetworkTree,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                    children: [
                      for (final node in visible)
                        _TreeNodeTile(
                          node: node,
                          depth: 0,
                          query: query,
                          onTap: _openDetails,
                        ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(IbTreeNode node) {
    if (node.userSlug.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => _IbDetailsSheet(node: node, controller: _c),
    );
  }
}

class _TreeNodeTile extends StatefulWidget {
  final IbTreeNode node;
  final int depth;
  final String query;
  final ValueChanged<IbTreeNode> onTap;

  const _TreeNodeTile({
    required this.node,
    required this.depth,
    required this.query,
    required this.onTap,
  });

  @override
  State<_TreeNodeTile> createState() => _TreeNodeTileState();
}

class _TreeNodeTileState extends State<_TreeNodeTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final children =
        node.children.where((c) => c.matches(widget.query)).toList();
    // While searching, open the branches that lead to a match.
    final expanded = _expanded || (widget.query.isNotEmpty && children.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: (widget.depth * 14).w,
            bottom: 6.h,
          ),
          child: Material(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: () => widget.onTap(node),
              child: Container(
                padding: EdgeInsetsDirectional.fromSTEB(4.w, 8.h, 12.w, 8.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32.w,
                      child: node.children.isEmpty
                          ? Icon(
                              Icons.person_outline,
                              size: 18.sp,
                              color: AppColors.textSecondary,
                            )
                          : IconButton(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _expanded = !expanded),
                              icon: Icon(
                                expanded
                                    ? Icons.expand_more_rounded
                                    : Icons.chevron_right_rounded,
                                size: 20.sp,
                                color: AppColors.textPrimary,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.fullname.isEmpty ? node.email : node.fullname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            node.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (node.role.isNotEmpty)
                          Text(
                            node.role,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        if (node.totalDescendants > 0)
                          Text(
                            TranslationUtils.trArgs('ib_network_downline', {
                              'count': '${node.totalDescendants}',
                            }),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 10.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          for (final child in children)
            _TreeNodeTile(
              node: child,
              depth: widget.depth + 1,
              query: widget.query,
              onTap: widget.onTap,
            ),
      ],
    );
  }
}

class _IbDetailsSheet extends StatefulWidget {
  final IbTreeNode node;
  final IBController controller;

  const _IbDetailsSheet({required this.node, required this.controller});

  @override
  State<_IbDetailsSheet> createState() => _IbDetailsSheetState();
}

class _IbDetailsSheetState extends State<_IbDetailsSheet> {
  late final Future<Map<String, dynamic>?> _details =
      widget.controller.loadIbDetails(widget.node.userSlug);

  static String _fmt(dynamic value) {
    final number = value is num ? value : num.tryParse('$value');
    if (number == null) return '$value';
    return number % 1 == 0 ? '${number.toInt()}' : number.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.w,
        16.h,
        16.w,
        MediaQuery.paddingOf(context).bottom + 12.h,
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              height: 160.h,
              child: const Center(
                child: CommonLoadingWidget(isFullScreen: false),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return SizedBox(
              height: 120.h,
              child: Center(
                child: Text(
                  TranslationUtils.tr('ib_network_details_failed'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }
          final stats = data['statistics'] is Map
              ? (data['statistics'] as Map).cast<String, dynamic>()
              : const <String, dynamic>{};
          final structure = data['ib_structure'] is Map
              ? (data['ib_structure'] as Map).cast<String, dynamic>()
              : const <String, dynamic>{};
          final statRows = <(String, String)>[
            ('ib_network_total_clients', 'total_clients'),
            ('ib_network_sub_ibs', 'sub_ib_count'),
            ('ib_network_total_deposited', 'total_deposited'),
            ('ib_network_total_withdrawal', 'total_withdrawal'),
            ('ib_network_total_equity', 'total_equity'),
            ('ib_network_total_lots', 'total_lots'),
            ('ib_network_total_rebate', 'total_rebate'),
            ('ib_network_available_rebate', 'available_rebate'),
          ];
          final groupName = '${structure['group_name'] ?? ''}';
          final ibType = '${structure['ib_type'] ?? ''}';

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.node.fullname,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  [
                    widget.node.email,
                    if (groupName.isNotEmpty) groupName,
                    if (ibType.isNotEmpty) ibType,
                  ].join(' · '),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 12.h),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8.h,
                  crossAxisSpacing: 8.w,
                  childAspectRatio: 2.6,
                  children: [
                    for (final (labelKey, field) in statRows)
                      if (stats.containsKey(field))
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                TranslationUtils.tr(labelKey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 10.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                _fmt(stats[field]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 40.sp),
            SizedBox(height: 10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 12.h),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(TranslationUtils.tr('common_retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
