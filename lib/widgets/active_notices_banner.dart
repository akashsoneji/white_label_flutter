import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/api_service.dart';

/// Broker-wide notice published from the admin panel (GET user/notices/active).
class ActiveNotice {
  final String id;
  final String title;
  final String message;
  final String type;
  final String link;

  const ActiveNotice({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.link,
  });

  /// The docs only show an empty `notices` list, so common field names are
  /// accepted for each value.
  factory ActiveNotice.fromJson(Map<String, dynamic> json) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = json[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return ActiveNotice(
      id: read(['id']),
      title: read(['title', 'heading', 'subject']),
      message: read(['message', 'content', 'description', 'body', 'text']),
      type: read(['type', 'level', 'severity']).toLowerCase(),
      link: read(['link', 'url', 'target_url', 'button_url']),
    );
  }

  bool get isEmpty => title.isEmpty && message.isEmpty;
}

/// Shows active notices at the top of the dashboard. Renders nothing when
/// there are none, and a dismissed notice stays hidden for this app session.
class ActiveNoticesBanner extends StatefulWidget {
  const ActiveNoticesBanner({super.key});

  @override
  State<ActiveNoticesBanner> createState() => _ActiveNoticesBannerState();
}

class _ActiveNoticesBannerState extends State<ActiveNoticesBanner> {
  static final Set<String> _dismissedThisSession = <String>{};

  List<ActiveNotice> _notices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiService.get(endpoint: ApiConstants.activeNotices);
      if (!response.success) return;
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      final raw = data is Map<String, dynamic> ? data['notices'] : null;
      if (raw is! List) return;
      final notices = raw
          .whereType<Map<String, dynamic>>()
          .map(ActiveNotice.fromJson)
          .where((notice) => !notice.isEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _notices = notices);
    } catch (e) {
      debugPrint('ActiveNoticesBanner: failed to load notices: $e');
    }
  }

  String _keyOf(ActiveNotice notice) =>
      notice.id.isNotEmpty ? notice.id : '${notice.title}|${notice.message}';

  void _dismiss(ActiveNotice notice) {
    setState(() => _dismissedThisSession.add(_keyOf(notice)));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _notices
        .where((notice) => !_dismissedThisSession.contains(_keyOf(notice)))
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(12.w, 8.h, 12.w, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: visible
            .map(
              (notice) => Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: _NoticeCard(
                  notice: notice,
                  onDismiss: () => _dismiss(notice),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final ActiveNotice notice;
  final VoidCallback onDismiss;

  const _NoticeCard({required this.notice, required this.onDismiss});

  Color _accent() {
    switch (notice.type) {
      case 'danger':
      case 'error':
      case 'critical':
        return AppColors.error;
      case 'warning':
      case 'maintenance':
        return AppColors.warning;
      case 'success':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _openLink() async {
    final uri = Uri.tryParse(notice.link);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    final hasLink = notice.link.isNotEmpty;

    return Material(
      color: accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: hasLink ? _openLink : null,
        child: Container(
          padding: EdgeInsetsDirectional.fromSTEB(10.w, 8.h, 4.w, 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Icon(Icons.campaign_rounded, color: accent, size: 18.sp),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notice.title.isNotEmpty)
                      Text(
                        notice.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (notice.message.isNotEmpty)
                      Text(
                        notice.message,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12.sp,
                        ),
                      ),
                  ],
                ),
              ),
              InkResponse(
                onTap: onDismiss,
                radius: 18.r,
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 16.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
