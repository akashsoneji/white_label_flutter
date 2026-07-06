import 'dart:async';

import 'package:crm_app/constants/color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Tick-based countdown timer.
///
/// Drops the cost of `Timer.periodic` once per render by exposing
/// `stream`-friendly updates. Use this for contdown displays in the
/// contest detail / join screens.
class ContestCountdownTimer extends StatefulWidget {
  final DateTime endsAt;
  final TextStyle? textStyle;
  final Color? accentColor;
  final bool compact;

  const ContestCountdownTimer({
    super.key,
    required this.endsAt,
    this.textStyle,
    this.accentColor,
    this.compact = false,
  });

  @override
  State<ContestCountdownTimer> createState() => _ContestCountdownTimerState();
}

class _ContestCountdownTimerState extends State<ContestCountdownTimer> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.endsAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.endsAt.difference(DateTime.now());
      });
    });
  }

  @override
  void didUpdateWidget(covariant ContestCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _remaining = widget.endsAt.difference(DateTime.now());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.primary;
    final positive = _remaining.inSeconds > 0;
    final parts = _formatDuration(_remaining);

    final textStyle = widget.textStyle ??
        TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: positive ? AppColors.textPrimary : AppColors.error,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < parts.length; i++)
          Padding(
            padding: EdgeInsets.only(right: i == parts.length - 1 ? 0 : 6.w),
            child: _CountdownCell(
              label: parts[i].label,
              value: parts[i].value,
              accent: accent,
              textStyle: textStyle,
              compact: widget.compact,
            ),
          ),
      ],
    );
  }

  List<_CountdownPart> _formatDuration(Duration d) {
    final total = d.inSeconds;
    if (total <= 0) {
      return const [
        _CountdownPart(label: '00', value: '00'),
        _CountdownPart(label: '00', value: '00'),
        _CountdownPart(label: '00', value: '00'),
      ];
    }
    final days = total ~/ 86400;
    final hours = (total % 86400) ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;

    if (days > 0) {
      return [
        _CountdownPart(label: _maybeLabel('D'), value: _two(days)),
        _CountdownPart(label: _maybeLabel('H'), value: _two(hours)),
        _CountdownPart(label: _maybeLabel('M'), value: _two(minutes)),
      ];
    }
    return [
      _CountdownPart(label: _maybeLabel('H'), value: _two(hours)),
      _CountdownPart(label: _maybeLabel('M'), value: _two(minutes)),
      _CountdownPart(label: _maybeLabel('S'), value: _two(seconds)),
    ];
  }

  String _two(int v) => v.toString().padLeft(2, '0');
  String _maybeLabel(String s) => widget.compact ? '' : s;
}

class _CountdownCell extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final TextStyle textStyle;
  final bool compact;

  const _CountdownCell({
    required this.label,
    required this.value,
    required this.accent,
    required this.textStyle,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.w : 10.w,
        vertical: compact ? 4.h : 6.h,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: textStyle.copyWith(fontWeight: FontWeight.w700),
          ),
          if (!compact && label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                fontSize: 9.sp,
                color: accent,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
        ],
      ),
    );
  }
}

class _CountdownPart {
  final String label;
  final String value;
  const _CountdownPart({required this.label, required this.value});
}
