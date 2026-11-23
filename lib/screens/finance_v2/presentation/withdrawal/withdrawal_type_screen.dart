import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/screens/finance_v2/data/models/payment_type_option.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_empty_state.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_error_retry.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_scaffold.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_v2_shimmer.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/payment_type_tile.dart';
import 'package:crm_app/services/language_service.dart';

import 'withdrawal_amount_screen.dart';
import 'withdrawal_type_controller.dart';

/// First screen of the quote-driven withdrawal flow (TSK-0119): the client
/// picks how the money should be paid out.
class WithdrawalTypeScreen extends StatefulWidget {
  /// Account to preselect on the amount screen.
  final String? accountNumber;

  const WithdrawalTypeScreen({super.key, this.accountNumber});

  @override
  State<WithdrawalTypeScreen> createState() => _WithdrawalTypeScreenState();
}

class _WithdrawalTypeScreenState extends State<WithdrawalTypeScreen> {
  late final String _tag = 'withdrawal_type_${identityHashCode(this)}';
  late final WithdrawalTypeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(WithdrawalTypeController(), tag: _tag);
  }

  @override
  void dispose() {
    Get.delete<WithdrawalTypeController>(tag: _tag);
    super.dispose();
  }

  void _openKyc() {
    Get.toNamed(AppPages.KYC_INTRO);
  }

  void _openAmount(PaymentTypeGroup group) {
    Get.to<void>(
      () => WithdrawalAmountScreen(
        group: group,
        typeInfo: _controller.typeInfoOf(group),
        accountNumber: widget.accountNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FinanceV2Scaffold(
      title: TranslationUtils.tr('withdrawal'),
      body: Obx(() {
        final message = _controller.message.value;
        switch (_controller.state.value) {
          case WithdrawalTypeState.loading:
            return const SingleChildScrollView(
              physics: NeverScrollableScrollPhysics(),
              child: FinanceV2Shimmer.tiles(count: 5),
            );
          case WithdrawalTypeState.empty:
            return Center(
              child: FinanceV2EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: TranslationUtils.tr('fv2_no_withdrawal_methods'),
              ),
            );
          case WithdrawalTypeState.disabled:
            return Center(
              child: FinanceV2EmptyState(
                icon: Icons.info_outline_rounded,
                title: _messageOrDefault(message),
              ),
            );
          case WithdrawalTypeState.error:
            if (_controller.needsKyc.value) {
              return Center(
                child: FinanceV2EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: _messageOrDefault(message),
                  actionLabel: TranslationUtils.tr(
                    'withdrawal_screen_complete_verification',
                  ),
                  onAction: _openKyc,
                ),
              );
            }
            return Center(
              child: FinanceV2ErrorRetry(
                message: _messageOrDefault(message),
                onRetry: _controller.load,
              ),
            );
          case WithdrawalTypeState.data:
            return _TypeList(
              groups: _controller.groups.toList(growable: false),
              onGroupTap: _openAmount,
              onLockedTap: _openKyc,
            );
        }
      }),
    );
  }

  String _messageOrDefault(String message) {
    return message.isEmpty
        ? TranslationUtils.tr('fv2_no_withdrawal_methods')
        : message;
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
    final lockReason = TranslationUtils.tr(
      'withdrawal_screen_complete_verification',
    );
    final captionStyle = AppTextStyles.bodyText.copyWith(
      color: AppColors.textSecondary,
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
    );

    final children = <Widget>[
      Text(
        TranslationUtils.tr('fv2_choose_how_to_receive'),
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.textPrimary,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
    for (final group in groups) {
      if (!group.locked) {
        children.add(
          PaymentTypeTile(
            icon: _iconOf(group.type),
            iconUrls: group.rows.map((row) => row.icon).toList(growable: false),
            title: _titleOf(group),
            subtitle: _subtitleOf(group),
            onTap: () => onGroupTap(group),
          ),
        );
        continue;
      }
      children.add(
        Padding(
          padding: EdgeInsetsDirectional.only(top: 8.h),
          child: Text(
            TranslationUtils.tr('fv2_verification_required'),
            style: captionStyle,
          ),
        ),
      );
      for (final row in group.rows) {
        children.add(
          PaymentTypeTile(
            icon: Icons.account_balance_wallet_outlined,
            iconUrls: <String>[row.icon],
            title: row.displayName.isEmpty ? row.methodName : row.displayName,
            isLocked: true,
            lockReason: lockReason,
            onTap: onLockedTap,
          ),
        );
      }
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      itemCount: children.length,
      separatorBuilder: (_, _) => SizedBox(height: 8.h),
      itemBuilder: (_, index) => children[index],
    );
  }

  /// The server label of the type; without one the raw type code is shown,
  /// capitalised.
  static String _titleOf(PaymentTypeGroup group) {
    if (group.label.isNotEmpty) return group.label;
    return switch (group.type) {
      'crypto' => TranslationUtils.tr('instruments_crypto'),
      'bank' => TranslationUtils.tr('withdrawal_bank'),
      'upi' => group.type.toUpperCase(),
      _ => group.type.capitalizeFirst ?? group.type,
    };
  }

  /// The method names behind a tile, as the server named them.
  static String? _subtitleOf(PaymentTypeGroup group) {
    final names = group.rows
        .map((row) => row.displayName.isEmpty ? row.methodName : row.displayName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .join(', ');
    return names.isEmpty ? null : names;
  }

  static IconData _iconOf(String type) {
    return switch (type) {
      'crypto' => Icons.currency_bitcoin_rounded,
      'bank' => Icons.account_balance_outlined,
      'upi' => Icons.qr_code_2_rounded,
      'card' => Icons.credit_card_rounded,
      _ => Icons.storefront_outlined,
    };
  }
}
