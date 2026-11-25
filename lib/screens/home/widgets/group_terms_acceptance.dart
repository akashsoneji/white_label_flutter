import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// "I agree to these Terms and Conditions" checkbox for a trading group with
/// terms enabled. Tapping "Terms and Conditions" shows the group's plain-text
/// terms, cut at [previewLength] characters with Show more / Show less (same
/// cut as the web portal).
class GroupTermsAcceptance extends StatefulWidget {
  static const int previewLength = 280;

  final String? termsText;
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const GroupTermsAcceptance({
    super.key,
    required this.termsText,
    required this.accepted,
    required this.onChanged,
  });

  @override
  State<GroupTermsAcceptance> createState() => _GroupTermsAcceptanceState();
}

class _GroupTermsAcceptanceState extends State<GroupTermsAcceptance> {
  late final TapGestureRecognizer _linkRecognizer;
  bool _showTerms = false;
  bool _expanded = false;

  String get _terms =>
      (widget.termsText ?? '').replaceAll('\r\n', '\n').trim();

  @override
  void initState() {
    super.initState();
    _linkRecognizer = TapGestureRecognizer()..onTap = _toggleTerms;
  }

  @override
  void dispose() {
    _linkRecognizer.dispose();
    super.dispose();
  }

  void _toggleTerms() {
    if (_terms.isEmpty) return;
    setState(() => _showTerms = !_showTerms);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyles.bodyText.copyWith(
      fontSize: 13.sp,
      color: AppColors.textPrimary,
    );
    final template = TranslationUtils.tr('create_account_terms_agree');
    final link = TranslationUtils.tr('create_account_terms_link');
    final linkAt = template.indexOf('{terms}');
    final prefix = linkAt < 0 ? '$template ' : template.substring(0, linkAt);
    final suffix = linkAt < 0 ? '' : template.substring(linkAt + 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24.r,
              height: 24.r,
              child: Checkbox(
                key: const Key('group_terms_checkbox'),
                value: widget.accepted,
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => widget.onChanged(v ?? false),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onChanged(!widget.accepted),
                child: Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Text.rich(
                    TextSpan(
                      style: textStyle,
                      children: [
                        TextSpan(text: prefix),
                        TextSpan(
                          text: link,
                          recognizer: _linkRecognizer,
                          style: textStyle.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                        TextSpan(text: suffix),
                      ],
                    ),
                    key: const Key('group_terms_link'),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showTerms && _terms.isNotEmpty) ...[
          SizedBox(height: 8.h),
          _TermsTextBox(
            terms: _terms,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ],
    );
  }
}

class _TermsTextBox extends StatelessWidget {
  final String terms;
  final bool expanded;
  final VoidCallback onToggle;

  const _TermsTextBox({
    required this.terms,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Count characters, not UTF-16 units, so emoji and Arabic marks are not
    // split at the cut.
    final chars = terms.characters;
    final isLong = chars.length > GroupTermsAcceptance.previewLength;
    final shown = isLong && !expanded
        ? '${chars.take(GroupTermsAcceptance.previewLength).toString().trimRight()}…'
        : terms;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shown,
            key: const Key('group_terms_text'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.sp,
              height: 1.45,
              color: AppColors.textGrey,
            ),
          ),
          if (isLong)
            GestureDetector(
              key: const Key('group_terms_toggle'),
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: EdgeInsets.only(top: 6.h),
                child: Text(
                  TranslationUtils.tr(
                    expanded
                        ? 'create_account_terms_show_less'
                        : 'create_account_terms_show_more',
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
