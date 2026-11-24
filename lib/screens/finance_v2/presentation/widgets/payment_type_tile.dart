import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

import 'method_icon_stack.dart';

/// One payment type (crypto, bank, card…) on the deposit / withdrawal type
/// screens: the server logos of its methods on a tinted plate, the type name,
/// the method names and a status line.
///
/// An open tile shows [availableLabel] and a chevron. A locked tile is the
/// same card with muted content, plus [lockTagLabel] as a tab on its top edge,
/// [lockReason] as its status, a pulsing lock and [lockActionLabel] as a
/// button inside the card, all in a washed-out accent with grey text.
/// The whole tile calls [onTap], so the screen can send the user to
/// verification. Locked and open tiles can sit in the same list.
class PaymentTypeTile extends StatelessWidget {
  final IconData icon;
  final List<String> iconUrls;
  final String title;
  final String? subtitle;
  final bool isLocked;
  final String? lockReason;
  final String? lockTagLabel;
  final String? lockActionLabel;

  /// Status of an open tile ("Available"), shown where a locked tile shows
  /// its reason.
  final String? availableLabel;
  final VoidCallback onTap;

  const PaymentTypeTile({
    super.key,
    required this.icon,
    this.iconUrls = const <String>[],
    required this.title,
    this.subtitle,
    this.isLocked = false,
    this.lockReason,
    this.lockTagLabel,
    this.lockActionLabel,
    this.availableLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final lockReason = this.lockReason;
    final lockTagLabel = this.lockTagLabel;
    final lockActionLabel = this.lockActionLabel;
    final availableLabel = this.availableLabel;
    final hasAvailableLabel =
        !isLocked && availableLabel != null && availableLabel.isNotEmpty;
    final hasLockReason =
        isLocked && lockReason != null && lockReason.isNotEmpty;
    final hasLockTag =
        isLocked && lockTagLabel != null && lockTagLabel.isNotEmpty;
    final hasLockAction =
        isLocked && lockActionLabel != null && lockActionLabel.isNotEmpty;
    final corner = Radius.circular(20.r);
    // The tab grows out of the top-start corner, so that corner is square.
    final radius = BorderRadiusDirectional.only(
      topStart: hasLockTag ? Radius.zero : corner,
      topEnd: corner,
      bottomStart: corner,
      bottomEnd: corner,
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppColors.cardBackground,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Opacity(
                      opacity: isLocked ? 0.5 : 1,
                      child: _LogoPlate(iconUrls: iconUrls, fallbackIcon: icon),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyText.copyWith(
                              color: isLocked
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                                height: 1.3,
                              ),
                            ),
                          ],
                          if (hasLockReason) ...[
                            SizedBox(height: 5.h),
                            _StatusLine(
                              label: lockReason,
                              color: AppColors.warning,
                            ),
                          ],
                          if (hasAvailableLabel) ...[
                            SizedBox(height: 5.h),
                            _StatusLine(
                              label: availableLabel,
                              color: AppColors.success,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    if (isLocked)
                      const _PulsingLockBadge()
                    else
                      const _ChevronBadge(),
                  ],
                ),
                if (hasLockAction) ...[
                  SizedBox(height: 12.h),
                  _LockActionButton(label: lockActionLabel),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!hasLockTag) return card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // One pixel into the card, so no hairline shows between the two.
        Transform.translate(
          offset: const Offset(0, 1),
          child: _LockTab(label: lockTagLabel),
        ),
        card,
      ],
    );
  }
}

/// Accent of a locked tile: the brand colour washed out, so the tile reads
/// as disabled. Text on it is grey.
Color _lockedAccent() {
  return Color.alphaBlend(
    AppColors.primary.withValues(alpha: 0.25),
    AppColors.cardBackground,
  );
}

/// Tinted rounded plate behind the method logos.
class _LogoPlate extends StatelessWidget {
  final List<String> iconUrls;
  final IconData fallbackIcon;

  const _LogoPlate({required this.iconUrls, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 52.w, minHeight: 52.w),
      padding: EdgeInsets.all(9.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.iconBgPrimary,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: MethodIconStack(iconUrls: iconUrls, fallbackIcon: fallbackIcon),
    );
  }
}

/// Tab on the top edge of a locked tile. Its far side sweeps down into the
/// card's border.
class _LockTab extends StatelessWidget {
  final String label;

  const _LockTab({required this.label});

  @override
  Widget build(BuildContext context) {
    final labelColor = AppColors.textSecondary;
    final sweep = 22.w;

    return CustomPaint(
      painter: _LockTabPainter(
        color: _lockedAccent(),
        cornerRadius: 12.r,
        sweep: sweep,
        isRtl: Directionality.of(context) == TextDirection.rtl,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(12.w, 5.h, sweep + 2.w, 4.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, color: labelColor, size: 12.sp),
            SizedBox(width: 5.w),
            Text(
              label,
              maxLines: 1,
              style: AppTextStyles.bodyText.copyWith(
                color: labelColor,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockTabPainter extends CustomPainter {
  final Color color;
  final double cornerRadius;

  /// Width of the S-curve that takes the tab's top edge down to its base.
  final double sweep;
  final bool isRtl;

  const _LockTabPainter({
    required this.color,
    required this.cornerRadius,
    required this.sweep,
    required this.isRtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final path = Path()
      ..moveTo(0, height)
      ..lineTo(0, cornerRadius)
      ..quadraticBezierTo(0, 0, cornerRadius, 0)
      ..lineTo(width - sweep, 0)
      ..cubicTo(
        width - sweep / 2,
        0,
        width - sweep / 2,
        height,
        width,
        height,
      )
      ..close();

    if (isRtl) {
      canvas
        ..translate(width, 0)
        ..scale(-1, 1);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LockTabPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.sweep != sweep ||
        oldDelegate.isRtl != isRtl;
  }
}

/// Button inside a locked tile: says what a tap does. The tile itself takes
/// the tap.
class _LockActionButton extends StatelessWidget {
  final String label;

  const _LockActionButton({required this.label});

  @override
  Widget build(BuildContext context) {
    final labelColor = AppColors.textSecondary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: _lockedAccent(),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        children: [
          // Same width as the arrow, so the label stays centred.
          SizedBox(width: 18.sp),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: labelColor,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyText.copyWith(
                      color: labelColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            color: labelColor,
            size: 18.sp,
            textDirection: Directionality.of(context),
          ),
        ],
      ),
    );
  }
}

/// Status line of a tile: a dot and a short label, in [color]. It has no
/// background so the dot starts on the same edge as the method name above it.
class _StatusLine extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusLine({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6.w,
          height: 6.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Filled lock badge of a locked tile with a ring that breathes out of it.
class _PulsingLockBadge extends StatelessWidget {
  const _PulsingLockBadge();

  @override
  Widget build(BuildContext context) {
    final badgeColor = _lockedAccent();
    final size = 32.w;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _Pulse(
            builder: (context, value) => Transform.scale(
              scale: 1 + 0.4 * value,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: 0.2 * (1 - value),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChevronBadge extends StatelessWidget {
  const _ChevronBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32.w,
      height: 32.w,
      decoration: BoxDecoration(
        color: AppColors.iconBgPrimary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.primary,
        size: 22.sp,
        textDirection: Directionality.of(context),
      ),
    );
  }
}

/// Rebuilds [builder] with a value that eases between 0 and 1 and back, for
/// ever. It stays at 0 when the device asks for reduced motion.
class _Pulse extends StatefulWidget {
  final Widget Function(BuildContext context, double value) builder;

  const _Pulse({required this.builder});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
      return;
    }
    if (!_controller.isAnimating) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(
        context,
        Curves.easeInOut.transform(_controller.value),
      ),
    );
  }
}
