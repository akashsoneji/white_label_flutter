import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/utils/app_picker_theme.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Shared building blocks
/// My Team Withdrawal, IB Commission, IB Withdraw). Each report follows the
/// web portal flow: pick filters → Apply → summary cards → movements list,
/// with Export CSV using the same filters.

final DateFormat ibmReportApiDate = DateFormat('yyyy-MM-dd');
final DateFormat _fieldDate = DateFormat('dd/MM/yyyy');


/// Scaffold with the same app bar style as the other IB screens.
class IbmReportScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;
  final ScrollController? scrollController;
  final List<Widget> children;

  const IbmReportScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.children,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      appBar: AppBar(
        backgroundColor:
            AppColors.isDarkMode ? AppColors.pureBlack : AppColors.whiteColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleSpacing: 0,
        title: Text(
          title,
          style: AppTextStyles.heading.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          children: [
            Text(
              subtitle,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 12.h),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// White card used for every block on the report screens.
class IbmReportCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const IbmReportCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

/// Draft dates in the filter card. Both start empty ("dd/mm/yyyy"), like the
/// web form, and are only sent once Apply is tapped.
class IbmReportDates {
  final DateTime? from;
  final DateTime? to;

  const IbmReportDates({this.from, this.to});

  bool get isComplete => from != null && to != null;

  DateTimeRange? get range =>
      isComplete ? DateTimeRange(start: from!, end: to!) : null;

  bool sameAs(IbmReportDates other) => from == other.from && to == other.to;
}

/// Checks the draft dates before Apply / Export. Shows a toast and returns
/// null when a date is missing.
DateTimeRange? ibmValidateReportDates(IbmReportDates dates) {
  if (dates.from == null) {
    CustomToastService.showError(
      message: TranslationUtils.tr('ibm_select_from_date'),
    );
    return null;
  }
  if (dates.to == null) {
    CustomToastService.showError(
      message: TranslationUtils.tr('ibm_select_to_date'),
    );
    return null;
  }
  return dates.range;
}

/// Filter card: From date / To date, optional extra filters, then
/// Apply + Export CSV. Picking dates changes only the draft; nothing is
/// fetched until Apply is tapped — same as the web form.
class IbmReportFilterCard extends StatelessWidget {
  final IbmReportDates dates;
  final ValueChanged<IbmReportDates> onDatesChanged;
  final List<Widget> extraFilters;
  final VoidCallback? onApply;
  final VoidCallback? onExport;
  final bool isApplying;
  final bool isExporting;

  /// True when the draft filters differ from what is shown below, so the
  /// Apply button gets attention.
  final bool hasPendingChanges;

  const IbmReportFilterCard({
    super.key,
    required this.dates,
    required this.onDatesChanged,
    required this.onApply,
    required this.onExport,
    this.extraFilters = const [],
    this.isApplying = false,
    this.isExporting = false,
    this.hasPendingChanges = false,
  });

  Future<void> _pick(BuildContext context, {required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(2015);
    // From can't be after To, and To can't be before From or in the future.
    final lastAllowed = isStart ? (dates.to ?? today) : today;
    final firstAllowed = isStart ? first : (dates.from ?? first);
    var initial = (isStart ? dates.from : dates.to) ?? lastAllowed;
    if (initial.isBefore(firstAllowed)) initial = firstAllowed;
    if (initial.isAfter(lastAllowed)) initial = lastAllowed;

    final picked = await AppPickerTheme.showAppDatePicker(
      context,
      initialDate: initial,
      firstDate: firstAllowed,
      lastDate: lastAllowed,
    );
    if (picked == null) return;
    onDatesChanged(
      isStart
          ? IbmReportDates(from: picked, to: dates.to)
          : IbmReportDates(from: dates.from, to: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IbmReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: IbmReportField(
                  label: TranslationUtils.tr('ibm_from_date'),
                  value: dates.from == null ? null : _fieldDate.format(dates.from!),
                  placeholder: 'dd/mm/yyyy',
                  icon: Icons.calendar_today_outlined,
                  onTap: () => _pick(context, isStart: true),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: IbmReportField(
                  label: TranslationUtils.tr('ibm_to_date'),
                  value: dates.to == null ? null : _fieldDate.format(dates.to!),
                  placeholder: 'dd/mm/yyyy',
                  icon: Icons.calendar_today_outlined,
                  onTap: () => _pick(context, isStart: false),
                ),
              ),
            ],
          ),
          for (final filter in extraFilters) ...[
            SizedBox(height: 10.h),
            filter,
          ],
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _PrimaryButton(
                  label: TranslationUtils.tr('general_apply'),
                  icon: Icons.filter_alt_outlined,
                  isBusy: isApplying,
                  highlighted: hasPendingChanges,
                  onPressed: onApply,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _PrimaryButton(
                  label: TranslationUtils.tr('ibm_export_csv'),
                  icon: Icons.description_outlined,
                  isBusy: isExporting,
                  outlined: true,
                  onPressed: onExport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Label + tappable box, used for dates and dropdown-style filters. When
/// [value] is null the grey [placeholder] is shown instead.
class IbmReportField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;

  const IbmReportField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.placeholder = '',
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6.h),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            height: 42.h,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Icon(icon, size: 16.w, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dropdown filter (account, symbol, side, status). `null` value = "All".
class IbmReportDropdown extends StatelessWidget {
  final String label;
  final Map<String?, String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  const IbmReportDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<MapEntry<String?, String>>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(vertical: 8.h),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
                child: Text(
                  label,
                  style: AppTextStyles.heading.copyWith(fontSize: 15.sp),
                ),
              ),
              for (final entry in options.entries)
                ListTile(
                  dense: true,
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textPrimary,
                      fontWeight: entry.key == value
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: entry.key == value
                      ? Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, entry),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onChanged(selected.key);
  }

  @override
  Widget build(BuildContext context) {
    return IbmReportField(
      label: label,
      value: options[value] ?? options.values.first,
      icon: Icons.keyboard_arrow_down,
      onTap: () => _open(context),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isBusy;
  final bool outlined;
  final bool highlighted;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isBusy = false,
    this.outlined = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = outlined ? AppColors.primary : AppColors.whiteColor;
    final child = isBusy
        ? SizedBox(
            width: 16.w,
            height: 16.w,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16.w),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.r),
    );
    final padding = EdgeInsets.symmetric(vertical: 12.h);
    final onTap = isBusy ? null : onPressed;

    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary),
          padding: padding,
          shape: shape,
        ),
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.whiteColor,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
        elevation: highlighted ? 2 : 0,
        padding: padding,
        shape: shape,
      ),
      child: child,
    );
  }
}

/// One currency total, e.g. "USC · Deposits · +10,000.00". Cards sit two per
/// row on phones and wrap when there are more currencies.
class IbmCurrencySummaryCard {
  final String currency;
  final String label;
  final String value;
  final Color valueColor;

  const IbmCurrencySummaryCard({
    required this.currency,
    required this.label,
    required this.value,
    required this.valueColor,
  });
}

class IbmCurrencySummaryGrid extends StatelessWidget {
  final List<IbmCurrencySummaryCard> cards;

  const IbmCurrencySummaryGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = cards.length == 1
            ? 1
            : constraints.maxWidth > 600
                ? 3
                : 2;
        final width = (constraints.maxWidth - 10.w * (columns - 1)) / columns;
        return Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: IbmReportCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.currency,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        card.label,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          card.value,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: card.valueColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// List card: "Funding movements ... 16 records", rows, then the
/// "Showing 1–16 of 16" footer with page arrows.
class IbmReportListCard extends StatelessWidget {
  final String title;
  final int total;
  final int page;
  final int lastPage;
  final int perPage;
  final List<Widget> rows;
  final ValueChanged<int> onPage;
  final bool isLoadingPage;

  const IbmReportListCard({
    super.key,
    required this.title,
    required this.total,
    required this.page,
    required this.lastPage,
    required this.perPage,
    required this.rows,
    required this.onPage,
    this.isLoadingPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : (page - 1) * perPage + 1;
    final to = total == 0 ? 0 : from + rows.length - 1;
    return IbmReportCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  TranslationUtils.trArgs('ibm_records_count', {
                    'count': '$total',
                  }),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          if (isLoadingPage)
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    IbmReportShimmer(height: 58.h),
                    SizedBox(height: 8.h),
                  ],
                ],
              ),
            )
          else if (rows.isEmpty)
            const IbmReportEmpty()
          else
            ...rows,
          if (total > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 6.h, 6.w, 6.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      TranslationUtils.trArgs('ibm_showing_range', {
                        'from': '$from',
                        'to': '$to',
                        'total': '$total',
                      }),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (lastPage > 1) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: page > 1 && !isLoadingPage
                          ? () => onPage(page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '$page / $lastPage',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: page < lastPage && !isLoadingPage
                          ? () => onPage(page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Row inside the list card, separated by a bottom divider.
class IbmReportRow extends StatelessWidget {
  final Widget child;

  const IbmReportRow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: child,
    );
  }
}

/// Small coloured pill, e.g. "Deposit" / "Withdrawal" / "Buy".
class IbmReportPill extends StatelessWidget {
  final String text;
  final Color color;

  const IbmReportPill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Plain-text status like the web ("approved"), coloured by meaning.
class IbmReportStatusText extends StatelessWidget {
  final String status;

  const IbmReportStatusText({super.key, required this.status});

  Color get _color {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'paid':
      case 'completed':
        return Colors.green.shade700;
      case 'rejected':
      case 'failed':
        return Colors.red.shade700;
      case 'cancelled':
        return AppColors.textSecondary;
      default:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      status.isEmpty ? '-' : status,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: _color,
      ),
    );
  }
}

/// Shown before the first Apply: dates are empty, so nothing is loaded yet.
class IbmReportSelectDatesHint extends StatelessWidget {
  const IbmReportSelectDatesHint({super.key});

  @override
  Widget build(BuildContext context) {
    return IbmReportCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Column(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 36.w,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 8.h),
            Text(
              TranslationUtils.tr('ibm_select_dates_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class IbmReportEmpty extends StatelessWidget {
  const IbmReportEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 36.h),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 36.w,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 8.h),
          Text(
            TranslationUtils.tr('ibm_no_records_in_period'),
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class IbmReportError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const IbmReportError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return IbmReportCard(
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 36.w, color: Colors.red),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary),
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(TranslationUtils.tr('ibm_retry')),
          ),
        ],
      ),
    );
  }
}

class IbmReportShimmer extends StatelessWidget {
  final double height;

  const IbmReportShimmer({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }
}

/// Loading placeholder for the summary + list while the first page loads.
class IbmReportLoading extends StatelessWidget {
  const IbmReportLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: IbmReportShimmer(height: 92.h)),
            SizedBox(width: 10.w),
            Expanded(child: IbmReportShimmer(height: 92.h)),
          ],
        ),
        SizedBox(height: 12.h),
        IbmReportShimmer(height: 320.h),
      ],
    );
  }
}
