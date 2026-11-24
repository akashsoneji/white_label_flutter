import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';

/// The payment-method logos the server sends (`icon` / `logo`), drawn as
/// overlapping round badges like the web portal. Shows at most [maxVisible]
/// logos plus a "+N" badge; without any usable URL it shows [fallbackIcon].
class MethodIconStack extends StatelessWidget {
  final List<String> iconUrls;
  final IconData fallbackIcon;
  final double size;
  final int maxVisible;

  const MethodIconStack({
    super.key,
    required this.iconUrls,
    required this.fallbackIcon,
    this.size = 32,
    this.maxVisible = 3,
  });

  /// Server icons come as full URLs or as paths on the API host.
  static String? resolveUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme) {
      return uri.scheme == 'https' || uri.scheme == 'http' ? value : null;
    }
    final base = Uri.tryParse(ApiConstants.baseUrl);
    return base?.resolveUri(uri).toString();
  }

  static List<String> _usableUrls(List<String> iconUrls) {
    return iconUrls
        .map(resolveUrl)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }


  @override
  Widget build(BuildContext context) {
    final urls = _usableUrls(iconUrls);
    final badge = size.w;

    if (urls.isEmpty) {
      return _Badge(
        size: badge,
        child: Icon(fallbackIcon, color: AppColors.primary, size: badge * 0.55),
      );
    }

    final visible = urls.take(maxVisible).toList(growable: false);
    final extra = urls.length - visible.length;
    final step = badge * 0.62;
    final count = visible.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      width: badge + step * (count - 1),
      height: badge,
      child: Stack(
        children: [
          for (var index = 0; index < visible.length; index++)
            PositionedDirectional(
              start: step * index,
              child: _Badge(
                size: badge,
                child: _NetworkLogo(
                  url: visible[index],
                  fallbackIcon: fallbackIcon,
                  size: badge,
                ),
              ),
            ),
          if (extra > 0)
            PositionedDirectional(
              start: step * visible.length,
              child: _Badge(
                size: badge,
                tinted: true,
                child: Text(
                  '+$extra',
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.primary,
                    fontSize: (badge * 0.34).clamp(9, 13).toDouble(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final double size;
  final Widget child;
  final bool tinted;

  const _Badge({required this.size, required this.child, this.tinted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Logos are drawn for a light plate, so they keep it in dark mode too.
        color: tinted ? AppColors.iconBgPrimary : AppColors.whiteColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cardBackground, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NetworkLogo extends StatelessWidget {
  final String url;
  final IconData fallbackIcon;
  final double size;

  const _NetworkLogo({
    required this.url,
    required this.fallbackIcon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      fallbackIcon,
      color: AppColors.primary,
      size: size * 0.5,
    );
    return Padding(
      padding: EdgeInsets.all(size * 0.14),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        memCacheWidth: (size * 3).round(),
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
