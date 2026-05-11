import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/language_service.dart';

/// RTL-aware widget wrapper that automatically handles text direction
class RTLWrapper extends StatelessWidget {
  final Widget child;
  final LanguageService? languageService;

  const RTLWrapper({Key? key, required this.child, this.languageService})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = languageService ?? Get.find<LanguageService>();
    return Directionality(
      textDirection: service.getTextDirection(),
      child: child,
    );
  }
}

/// RTL-aware container with automatic padding and margin adjustments
class RTLContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;
  final LanguageService? languageService;

  const RTLContainer({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.decoration,
    this.languageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = languageService ?? Get.find<LanguageService>();
    final isRTL = service.isRTL();

    // Adjust padding for RTL
    EdgeInsetsGeometry? adjustedPadding;
    if (padding != null && isRTL) {
      if (padding is EdgeInsets) {
        final edgeInsets = padding as EdgeInsets;
        adjustedPadding = EdgeInsets.only(
          left: edgeInsets.right,
          right: edgeInsets.left,
          top: edgeInsets.top,
          bottom: edgeInsets.bottom,
        );
      }
    } else {
      adjustedPadding = padding;
    }

    // Adjust margin for RTL
    EdgeInsetsGeometry? adjustedMargin;
    if (margin != null && isRTL) {
      if (margin is EdgeInsets) {
        final edgeInsets = margin as EdgeInsets;
        adjustedMargin = EdgeInsets.only(
          left: edgeInsets.right,
          right: edgeInsets.left,
          top: edgeInsets.top,
          bottom: edgeInsets.bottom,
        );
      }
    } else {
      adjustedMargin = margin;
    }

    return Container(
      padding: adjustedPadding,
      margin: adjustedMargin,
      decoration: decoration,
      child: child,
    );
  }
}

/// RTL-aware row with automatic alignment
class RTLRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final LanguageService? languageService;

  const RTLRow({
    Key? key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.languageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = languageService ?? Get.find<LanguageService>();
    final isRTL = service.isRTL();

    // Reverse children order for RTL
    final adjustedChildren = isRTL ? children.reversed.toList() : children;

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: adjustedChildren,
    );
  }
}

/// RTL-aware column with automatic alignment
class RTLColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final LanguageService? languageService;

  const RTLColumn({
    Key? key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.languageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = languageService ?? Get.find<LanguageService>();
    final isRTL = service.isRTL();

    // Adjust crossAxisAlignment for RTL
    CrossAxisAlignment adjustedCrossAxisAlignment = crossAxisAlignment;
    if (isRTL) {
      if (crossAxisAlignment == CrossAxisAlignment.start) {
        adjustedCrossAxisAlignment = CrossAxisAlignment.end;
      } else if (crossAxisAlignment == CrossAxisAlignment.end) {
        adjustedCrossAxisAlignment = CrossAxisAlignment.start;
      }
    }

    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: adjustedCrossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }
}

/// RTL-aware text widget with automatic alignment
class RTLText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final LanguageService? languageService;

  const RTLText({
    Key? key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.languageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = languageService ?? Get.find<LanguageService>();
    final isRTL = service.isRTL();

    // Adjust text alignment for RTL
    TextAlign? adjustedTextAlign = textAlign;
    if (isRTL && textAlign != null) {
      if (textAlign == TextAlign.left) {
        adjustedTextAlign = TextAlign.right;
      } else if (textAlign == TextAlign.right) {
        adjustedTextAlign = TextAlign.left;
      }
    }

    return Text(
      text,
      style: style,
      textAlign: adjustedTextAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// RTL-aware icon widget with automatic positioning
class RTLIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final LanguageService? languageService;

  const RTLIcon({
    Key? key,
    required this.icon,
    this.size,
    this.color,
    this.languageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = languageService ?? Get.find<LanguageService>();
    final isRTL = service.isRTL();

    // Mirror certain icons for RTL
    IconData adjustedIcon = icon;
    if (isRTL) {
      switch (icon.codePoint) {
        case 0xe5c4: // Icons.arrow_back
          adjustedIcon = Icons.arrow_forward;
          break;
        case 0xe5c8: // Icons.arrow_forward
          adjustedIcon = Icons.arrow_back;
          break;
        case 0xe5de: // Icons.chevron_left
          adjustedIcon = Icons.chevron_right;
          break;
        case 0xe5df: // Icons.chevron_right
          adjustedIcon = Icons.chevron_left;
          break;
        case 0xe5e0: // Icons.chevron_left
          adjustedIcon = Icons.chevron_right;
          break;
        case 0xe5e1: // Icons.chevron_right
          adjustedIcon = Icons.chevron_left;
          break;
      }
    }

    return Icon(adjustedIcon, size: size, color: color);
  }
}

/// RTL-aware list tile with automatic alignment
class RTLListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final LanguageService? languageService;

  const RTLListTile({
    Key? key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.languageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = languageService ?? Get.find<LanguageService>();
    final isRTL = service.isRTL();

    return ListTile(
      leading: isRTL ? trailing : leading,
      title: title,
      subtitle: subtitle,
      trailing: isRTL ? leading : trailing,
      onTap: onTap,
    );
  }
}

/// Utility class for RTL-aware layouts
class RTLUtils {
  static LanguageService get languageService => Get.find<LanguageService>();

  /// Check if current language is RTL
  static bool get isRTL => languageService.isRTL();

  /// Get text direction for current language
  static TextDirection get textDirection => languageService.getTextDirection();

  /// Adjust alignment for RTL
  static AlignmentGeometry adjustAlignment(AlignmentGeometry alignment) {
    if (!isRTL) return alignment;

    if (alignment == Alignment.centerLeft) {
      return Alignment.centerRight;
    } else if (alignment == Alignment.centerRight) {
      return Alignment.centerLeft;
    } else if (alignment == Alignment.topLeft) {
      return Alignment.topRight;
    } else if (alignment == Alignment.topRight) {
      return Alignment.topLeft;
    } else if (alignment == Alignment.bottomLeft) {
      return Alignment.bottomRight;
    } else if (alignment == Alignment.bottomRight) {
      return Alignment.bottomLeft;
    }

    return alignment;
  }

  /// Adjust edge insets for RTL
  static EdgeInsets adjustEdgeInsets(EdgeInsets insets) {
    if (!isRTL) return insets;

    return EdgeInsets.only(
      left: insets.right,
      right: insets.left,
      top: insets.top,
      bottom: insets.bottom,
    );
  }

  /// Mirror icon for RTL
  static IconData mirrorIcon(IconData icon) {
    if (!isRTL) return icon;

    switch (icon.codePoint) {
      case 0xe5c4: // Icons.arrow_back
        return Icons.arrow_forward;
      case 0xe5c8: // Icons.arrow_forward
        return Icons.arrow_back;
      case 0xe5de: // Icons.chevron_left
        return Icons.chevron_right;
      case 0xe5df: // Icons.chevron_right
        return Icons.chevron_left;
      default:
        return icon;
    }
  }
}
