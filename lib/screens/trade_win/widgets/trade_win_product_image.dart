import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/trade_win_image_url.dart';

class TradeWinProductImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const TradeWinProductImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = TradeWinImageUrl.resolve(imagePath);
    final radius = borderRadius ?? BorderRadius.circular(12.r);

    if (url.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.icongrey.withValues(alpha: 0.2),
          borderRadius: radius,
        ),
        child: Icon(Icons.image_outlined, color: AppColors.textGrey),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: FutureBuilder<Map<String, String>>(
        future: TradeWinImageUrl.authHeaders(),
        builder: (context, snapshot) {
          return Image.network(
            url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            headers: snapshot.data ?? const {},
            errorBuilder: (_, __, ___) => Container(
              width: width,
              height: height,
              color: AppColors.icongrey.withValues(alpha: 0.2),
              child: Icon(Icons.broken_image_outlined, color: AppColors.textGrey),
            ),
          );
        },
      ),
    );
  }
}
