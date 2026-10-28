import 'package:flutter_screenutil/flutter_screenutil.dart';

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
