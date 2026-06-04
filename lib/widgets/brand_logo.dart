import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

class BrandLogo extends StatelessWidget {
  final String source;
  final double? height;
  final double? width;
  final Color? color;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool isCircle;

  const BrandLogo({
    super.key,
    required this.source,
    this.height,
    this.width,
    this.color,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.isCircle = false,
  });

  bool get _isNetworkLogo {
    final value = source.toLowerCase();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  bool get _isLocalFilePath {
    return source.startsWith('/');
  }

  bool get _isInlineSvg {
    final trimmed = source.trimLeft();
    return trimmed.startsWith('<svg') || trimmed.startsWith('<?xml');
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isNetworkLogo) {
      child = Image.network(
        source,
        height: height,
        width: width,
        fit: fit,
        errorBuilder:
            (context, error, stackTrace) => Icon(
              Icons.image_not_supported_outlined,
              size: height ?? width ?? 24,
              color: Colors.grey,
            ),
      );
    } else if (_isLocalFilePath) {
      child = Image.file(
        File(source),
        height: height,
        width: width,
        fit: fit,
        errorBuilder:
            (context, error, stackTrace) => Icon(
              Icons.image_not_supported_outlined,
              size: height ?? width ?? 24,
              color: Colors.grey,
            ),
      );
    } else if (_isInlineSvg) {
      child = SvgPicture.string(
        source,
        height: height,
        width: width,
        fit: fit,
        colorFilter:
            color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      );
    } else if (source.toLowerCase().endsWith('.svg')) {
      child = SvgPicture.asset(
        source,
        height: height,
        width: width,
        colorFilter:
            color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      );
    } else {
      child = Image.asset(source, height: height, width: width, fit: fit);
    }

    if (isCircle) {
      return ClipOval(child: child);
    }
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }
}
