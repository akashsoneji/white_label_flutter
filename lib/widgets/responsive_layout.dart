import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 800) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, Size, bool) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final isTablet = size.width >= 800;
        return builder(context, size, isTablet);
      },
    );
  }
}

class AdaptivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? mobilePadding;
  final EdgeInsets? tabletPadding;
  final EdgeInsets? desktopPadding;

  const AdaptivePadding({
    super.key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, size, isTablet) {
        EdgeInsets padding;

        if (size.width >= 1200) {
          padding = desktopPadding ?? EdgeInsets.all(24.w);
        } else if (isTablet) {
          padding = tabletPadding ?? EdgeInsets.all(16.w);
        } else {
          padding = mobilePadding ?? EdgeInsets.all(16.w);
        }

        return Padding(padding: padding, child: child);
      },
    );
  }
}

class AdaptiveSpacing extends StatelessWidget {
  final double mobile;
  final double? tablet;
  final double? desktop;

  const AdaptiveSpacing({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, size, isTablet) {
        double spacing;

        if (size.width >= 1200) {
          spacing = desktop ?? tablet ?? mobile;
        } else if (isTablet) {
          spacing = tablet ?? mobile;
        } else {
          spacing = mobile;
        }

        return SizedBox(height: spacing);
      },
    );
  }
}

class AdaptiveFontSize {
  static double getTitle(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 800;

    if (size.width >= 1200) return 32.sp;
    if (isTablet) return 28.sp;
    return 24.sp;
  }

  static double getHeading(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 800;

    if (size.width >= 1200) return 24.sp;
    if (isTablet) return 20.sp;
    return 18.sp;
  }

  static double getBody(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 800;

    if (size.width >= 1200) return 18.sp;
    if (isTablet) return 16.sp;
    return 14.sp;
  }

  static double getCaption(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 800;

    if (size.width >= 1200) return 16.sp;
    if (isTablet) return 14.sp;
    return 12.sp;
  }
}

class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double? mobileWidth;
  final double? tabletWidth;
  final double? desktopWidth;
  final EdgeInsets? padding;
  final BoxDecoration? decoration;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.mobileWidth,
    this.tabletWidth,
    this.desktopWidth,
    this.padding,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, size, isTablet) {
        double? width;

        if (size.width >= 1200) {
          width = desktopWidth ?? tabletWidth ?? mobileWidth;
        } else if (isTablet) {
          width = tabletWidth ?? mobileWidth;
        } else {
          width = mobileWidth;
        }

        return Container(
          width: width,
          padding: padding,
          decoration: decoration,
          child: child,
        );
      },
    );
  }
}

/// A grid with a fixed `crossAxisCount` and `childAspectRatio` makes its cells
/// taller as the screen widens, so on unfolded foldables and tablets the cards
/// end up roughly twice their phone height with empty space inside.
class ResponsiveGrid {
  ResponsiveGrid._();

  static const double _maxPhoneWidth = 430;

  /// Returns [phoneRatio] on phones; on wider screens widens the ratio by the
  /// same factor the cells widen, so each cell keeps its phone height.
  static double aspectRatio(double phoneRatio) {
    final screenWidth = ScreenUtil().screenWidth;
    if (screenWidth <= _maxPhoneWidth) return phoneRatio;
    return phoneRatio * screenWidth / _maxPhoneWidth;
  }
}

class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileCrossAxisCount;
  final int? tabletCrossAxisCount;
  final int? desktopCrossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const AdaptiveGrid({
    super.key,
    required this.children,
    required this.mobileCrossAxisCount,
    this.tabletCrossAxisCount,
    this.desktopCrossAxisCount,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, size, isTablet) {
        int crossAxisCount;

        if (size.width >= 1200) {
          crossAxisCount =
              desktopCrossAxisCount ??
              tabletCrossAxisCount ??
              mobileCrossAxisCount;
        } else if (isTablet) {
          crossAxisCount = tabletCrossAxisCount ?? mobileCrossAxisCount;
        } else {
          crossAxisCount = mobileCrossAxisCount;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: _getChildAspectRatio(size.width),
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  double _getChildAspectRatio(double width) {
    if (width >= 1200) return 1.5;
    if (width >= 800) return 1.2;
    return 1.0;
  }
}
