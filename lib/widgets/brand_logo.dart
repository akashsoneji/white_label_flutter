import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

class BrandLogo extends StatelessWidget {
  final String source;
  final double? height;
  final double? width;
  final Color? color;
  final BoxFit fit;

  const BrandLogo({
    super.key,
    required this.source,
    this.height,
    this.width,
    this.color,
    this.fit = BoxFit.contain,
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
    if (_isNetworkLogo) {
      return Image.network(
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
    }

    if (_isLocalFilePath) {
      return Image.file(
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
    }

    if (_isInlineSvg) {
      return SvgPicture.string(
        source,
        height: height,
        width: width,
        fit: fit,
        colorFilter:
            color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      );
    }

    if (source.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        source,
        height: height,
        width: width,
        colorFilter:
            color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      );
    }

    return Image.asset(source, height: height, width: width, fit: fit);
  }
}
