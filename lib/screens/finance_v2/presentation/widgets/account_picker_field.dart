import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance_v2/presentation/widgets/finance_account_option.dart';
import 'package:crm_app/services/language_service.dart';

/// The search box appears only for lists longer than this many rows.
const int _searchThreshold = 8;

/// Read-only field showing the chosen wallet / trading account; tapping it
/// should open [showAccountPickerSheet].
class AccountPickerField extends StatelessWidget {
  final String label;
  final FinanceAccountOption? selected;
  final VoidCallback onTap;
  final bool isLoading;

  const AccountPickerField({
    super.key,
    required this.label,
    this.selected,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    final balanceText = selected?.balanceText;
    final radius = BorderRadius.circular(12.r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Material(
          color: AppColors.textFieldBg,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: isLoading ? null : onTap,
            child: SizedBox(
              height: 48.h,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: 12.w),
                child: Row(
                  children: [
                    Expanded(
                      child: selected == null
                          ? Text(
                              TranslationUtils.tr('fv2_select_account'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.hint,
                                fontSize: 14.sp,
                              ),
                            )
                          : Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                selected.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                    if (balanceText != null && balanceText.isNotEmpty) ...[
                      SizedBox(width: 8.w),
                      Text(
                        balanceText,
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                    SizedBox(width: 8.w),
                    if (isLoading)
                      SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textGrey,
                        size: 20.sp,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the account list as a bottom sheet and completes with the tapped
/// account, or null when the sheet is dismissed.
///
/// The sheet never grows past 70% of the screen height and shows a search
/// box once [accounts] has more than eight rows.
Future<FinanceAccountOption?> showAccountPickerSheet(
  BuildContext context, {
  required List<FinanceAccountOption> accounts,
  String? selectedId,
}) {
  return showModalBottomSheet<FinanceAccountOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBackground,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.7,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (_) =>
        _AccountPickerSheet(accounts: accounts, selectedId: selectedId),
  );
}

class _AccountPickerSheet extends StatefulWidget {
  final List<FinanceAccountOption> accounts;
  final String? selectedId;

  const _AccountPickerSheet({required this.accounts, this.selectedId});

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  String _query = '';

  List<FinanceAccountOption> get _visibleAccounts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.accounts;
    return widget.accounts.where((account) {
      final subtitle = account.subtitle ?? '';
      return account.title.toLowerCase().contains(query) ||
          subtitle.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleAccounts = _visibleAccounts;
    final showSearch = widget.accounts.length > _searchThreshold;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16.w, 16.h, 16.w, 8.h),
              child: Text(
                TranslationUtils.tr('fv2_select_account'),
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (showSearch)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.w, 0, 16.w, 8.h),
                child: _SearchBox(
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            if (visibleAccounts.isEmpty)
              Padding(
                padding: EdgeInsets.all(24.w),
                child: Text(
                  TranslationUtils.tr('common_no_accounts'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textGrey,
                    fontSize: 13.sp,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.only(bottom: 8.h),
                  itemCount: visibleAccounts.length,
                  itemBuilder: (context, index) {
                    final account = visibleAccounts[index];
                    return _AccountRow(
                      account: account,
                      isSelected: account.id == widget.selectedId,
                      onTap: () => Navigator.of(context).pop(account),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: AppColors.border),
    );

    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.bodyText.copyWith(
        color: AppColors.textPrimary,
        fontSize: 13.sp,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.textFieldBg,
        hintText: TranslationUtils.tr('common_search'),
        hintStyle: AppTextStyles.bodyText.copyWith(
          color: AppColors.hint,
          fontSize: 13.sp,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.textGrey,
          size: 18.sp,
        ),
        contentPadding: EdgeInsetsDirectional.symmetric(
          horizontal: 12.w,
          vertical: 10.h,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final FinanceAccountOption account;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountRow({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = account.subtitle;
    final balanceText = account.balanceText;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 52.h),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Icon(
                account.isWallet
                    ? Icons.account_balance_wallet_outlined
                    : Icons.candlestick_chart_outlined,
                color: AppColors.primary,
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textGrey,
                          fontSize: 11.sp,
                        ),
                      ),
                  ],
                ),
              ),
              if (balanceText != null && balanceText.isNotEmpty) ...[
                SizedBox(width: 8.w),
                Text(
                  balanceText,
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
              SizedBox(width: 8.w),
              SizedBox(
                width: 20.w,
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: AppColors.primary,
                        size: 18.sp,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
