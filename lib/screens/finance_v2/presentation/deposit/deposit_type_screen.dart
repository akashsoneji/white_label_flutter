import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';

import '../../data/finance_v2_repository.dart';
import '../../data/models/payment_type_option.dart';
import '../widgets/finance_v2_empty_state.dart';
import '../widgets/finance_v2_error_retry.dart';
import '../widgets/finance_v2_scaffold.dart';
import '../widgets/finance_v2_shimmer.dart';
import '../widgets/payment_type_tile.dart';
import 'deposit_amount_screen.dart';
import 'deposit_navigation.dart';
import 'deposit_type_controller.dart';

/// First screen of the quote-driven deposit flow: how the client wants to
/// pay.
///
/// [accountNumber] is the account the caller had selected, if any; it is
/// preselected on the amount screen.
class DepositTypeScreen extends StatefulWidget {
  const DepositTypeScreen({super.key, this.accountNumber = ''});

  final String accountNumber;

  @override
  State<DepositTypeScreen> createState() => _DepositTypeScreenState();
}

class _DepositTypeScreenState extends State<DepositTypeScreen> {
  late final String _tag = 'deposit_type_${identityHashCode(this)}';
  late final DepositTypeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      DepositTypeController(repository: Get.find<FinanceV2Repository>()),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<DepositTypeController>(tag: _tag);
    super.dispose();
  }

  void _openGroup(PaymentTypeGroup group) {
    Get.to<void>(
      () => DepositAmountScreen(
        group: group,
        accountNumber: widget.accountNumber,
      ),
    );
  }

  Future<void> _openKyc() async {
    await openDepositKyc();
    if (mounted) _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return FinanceV2Scaffold(
      title: TranslationUtils.tr('deposit'),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: const FinanceV2Shimmer.tiles(count: 5),
          );
        }

        final error = _controller.errorMessage.value;
        if (error != null) {
          if (_controller.isFinanceDisabled.value) {
            return _MessageOnly(message: error);
          }
          if (_controller.needsKyc.value) {
            return FinanceV2EmptyState(
              icon: Icons.verified_user_outlined,
              title: TranslationUtils.tr('fv2_verification_required'),
              message: error,
              actionLabel: TranslationUtils.tr(
                'withdrawal_screen_complete_verification',
              ),
              onAction: _openKyc,
            );
          }
          return Center(
            child: FinanceV2ErrorRetry(
              message: error,
              onRetry: _controller.load,
            ),
          );
        }

        final groups = _controller.groups;
        if (groups.isEmpty) {
          return FinanceV2EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: TranslationUtils.tr('fv2_no_deposit_methods'),
          );
        }

        return _TypeList(
          groups: groups.toList(growable: false),
          onGroupTap: _openGroup,
          onLockedTap: _openKyc,
        );
      }),
    );
  }
}

class _TypeList extends StatelessWidget {
  final List<PaymentTypeGroup> groups;
  final ValueChanged<PaymentTypeGroup> onGroupTap;
  final VoidCallback onLockedTap;

  const _TypeList({
    required this.groups,
    required this.onGroupTap,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final openGroups =
        groups.where((group) => !group.locked).toList(growable: false);
    final lockedRows = groups
        .where((group) => group.locked)
        .expand((group) => group.rows)
        .toList(growable: false);
    // Each locked card says so itself and carries its own way out: some
    // methods can need verification while others are open.
    final lockReason = TranslationUtils.tr('fv2_verification_required');
    final lockTagLabel = TranslationUtils.tr('kyc_intro_screen_locked');
    final lockActionLabel = TranslationUtils.tr(
      'withdrawal_screen_complete_verification',
    );
    final availableLabel = TranslationUtils.tr('ibm_available');

    final children = <Widget>[
      for (final group in openGroups)
        PaymentTypeTile(
          icon: _typeIcon(group.type),
          iconUrls: group.rows.map((row) => row.icon).toList(growable: false),
          title: _groupTitle(group),
          subtitle: _groupSubtitle(group),
          availableLabel: availableLabel,
          onTap: () => onGroupTap(group),
        ),
      for (final row in lockedRows)
        PaymentTypeTile(
          icon: _typeIcon(row.paymentType.trim().toLowerCase()),
          iconUrls: <String>[row.icon],
          title: _rowTitle(row),
          isLocked: true,
          lockReason: lockReason,
          lockTagLabel: lockTagLabel,
          lockActionLabel: lockActionLabel,
          onTap: onLockedTap,
        ),
    ];

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      itemCount: children.length,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (_, index) => children[index],
    );
  }

  String _groupTitle(PaymentTypeGroup group) {
    return group.label.isNotEmpty ? group.label : _capitalised(group.type);
  }

  /// The channel names behind a tile, as the server named them.
  String? _groupSubtitle(PaymentTypeGroup group) {
    final names = group.rows
        .map(_rowTitle)
        .where((name) => name.isNotEmpty)
        .toSet()
        .join(', ');
    return names.isEmpty ? null : names;
  }

  String _rowTitle(PaymentTypeOption row) {
    for (final name in <String>[row.displayName, row.label, row.methodName]) {
      if (name.isNotEmpty) return name;
    }
    return _capitalised(row.paymentType);
  }

  String _capitalised(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      'crypto' => Icons.currency_bitcoin_rounded,
      'bank' => Icons.account_balance_outlined,
      'upi' => Icons.qr_code_2_rounded,
      'card' => Icons.credit_card_rounded,
      _ => Icons.storefront_outlined,
    };
  }
}

class _MessageOnly extends StatelessWidget {
  final String message;

  const _MessageOnly({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }
}
