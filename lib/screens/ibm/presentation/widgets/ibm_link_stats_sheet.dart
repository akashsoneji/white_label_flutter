import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/services/language_service.dart';

/// Bottom sheet with visit / signup / conversion stats for one referral link.
/// Backed by `GET ibm/portal/links/{linkId}/stats?period=`.
class IbmLinkStatsSheet extends StatefulWidget {
  final int linkId;
  final String label;

  const IbmLinkStatsSheet({
    super.key,
    required this.linkId,
    required this.label,
  });

  static Future<void> show(
    BuildContext context, {
    required int linkId,
    required String label,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => IbmLinkStatsSheet(linkId: linkId, label: label),
    );
  }

  @override
  State<IbmLinkStatsSheet> createState() => _IbmLinkStatsSheetState();
}

class _IbmLinkStatsSheetState extends State<IbmLinkStatsSheet> {
  static const List<String> _periods = ['today', '7d', '30d', 'mtd', 'all'];

  String _period = '30d';
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await IbmApiProvider().getLinkStats(
      widget.linkId,
      period: _period,
    );
    if (!mounted) return;
    final body = res.data;
    final data = body is Map && body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : <String, dynamic>{};
    setState(() {
      _isLoading = false;
      if (res.success) {
        _stats = data;
      } else {
        _error = res.message ?? TranslationUtils.tr('ibm_failed_to_load_stats');
      }
    });
  }

  int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                TranslationUtils.tr('ibm_link_stats'),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
              ),
              SizedBox(height: 12.h),
              _PeriodChips(
                periods: _periods,
                selected: _period,
                onSelected: (p) {
                  if (p == _period) return;
                  _period = p;
                  _fetch();
                },
              ),
              SizedBox(height: 14.h),
              Flexible(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _StatsShimmer();
    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _fetch);
    }

    final counts = _stats['counts'] is Map ? _stats['counts'] as Map : {};
    final period = _stats['period'] is Map ? _stats['period'] as Map : {};
    final earned = _stats['earned'] is List ? _stats['earned'] as List : [];
    final daily = _stats['daily'] is List ? _stats['daily'] as List : [];

    final visits = _toInt(counts['visits']);
    final signups = _toInt(counts['signups']);
    final conversion =
        visits > 0 ? '${(signups / visits * 100).toStringAsFixed(1)}%' : '0%';

    final tiles = <MapEntry<String, String>>[
      MapEntry('ibm_visits', '$visits'),
      MapEntry('ibm_unique_visits', '${_toInt(counts['unique_visits'])}'),
      MapEntry('ibm_signups', '$signups'),
      MapEntry('ibm_accounts', '${_toInt(counts['accounts'])}'),
      MapEntry('ibm_funded', '${_toInt(counts['funded'])}'),
      MapEntry('ibm_conversion', conversion),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (period['from'] != null && period['to'] != null)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Text(
                '${period['from']} → ${period['to']}',
                style: TextStyle(fontSize: 11.sp, color: AppColors.textGrey),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 16.w) / 3;
              return Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  for (final t in tiles)
                    SizedBox(
                      width: tileWidth,
                      child: _StatTile(
                        label: TranslationUtils.tr(t.key),
                        value: t.value,
                      ),
                    ),
                ],
              );
            },
          ),
          if (earned.isNotEmpty) ...[
            SizedBox(height: 16.h),
            _SectionTitle(TranslationUtils.tr('ibm_earned')),
            for (final row in earned.whereType<Map>()) _KeyValueRow(row: row),
          ],
          SizedBox(height: 16.h),
          _SectionTitle(TranslationUtils.tr('ibm_daily_activity')),
          if (daily.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: Text(
                  TranslationUtils.tr('ibm_no_activity_in_period'),
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textGrey),
                ),
              ),
            )
          else
            for (final row in daily.whereType<Map>()) _KeyValueRow(row: row),
        ],
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  final List<String> periods;
  final String selected;
  final ValueChanged<String> onSelected;

  const _PeriodChips({
    required this.periods,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in periods)
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: ChoiceChip(
                label: Text(TranslationUtils.tr('ibm_period_$p')),
                selected: p == selected,
                onSelected: (_) => onSelected(p),
                selectedColor: AppColors.primary.withOpacity(0.15),
                labelStyle: TextStyle(
                  fontSize: 11.sp,
                  color: p == selected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.sp, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// The doc only shows empty `earned` / `daily` arrays, so rows are rendered
/// from whatever keys the server sends rather than a fixed schema.
class _KeyValueRow extends StatelessWidget {
  final Map row;

  const _KeyValueRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final entries = row.entries.toList();
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 4.h,
        children: [
          for (final e in entries)
            Text(
              '${e.key}: ${e.value}',
              style: TextStyle(fontSize: 11.sp, color: AppColors.textPrimary),
            ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: Colors.redAccent),
          ),
          SizedBox(height: 10.h),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(TranslationUtils.tr('ibm_retry')),
          ),
        ],
      ),
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: List.generate(
          6,
          (_) => Container(
            width: 100.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        ),
      ),
    );
  }
}
