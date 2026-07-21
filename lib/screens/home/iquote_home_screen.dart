import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crm_app/constants/color.dart';

class IquoteHomeScreen extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const IquoteHomeScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final bgDark = isDark ? const Color(0xFF181E34) : AppColors.tradeBackgroundCenterColor;
    final cardBg = isDark ? const Color(0xFF222943) : AppColors.whiteColor;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? Colors.white70 : AppColors.textGrey;
    final iconColor = isDark ? Colors.white : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 90.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Header (Avatar, iQuotes Logo, Headset)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 18.r,
                        backgroundColor: isDark ? Colors.white.withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
                        child: Icon(Icons.person, color: isDark ? Colors.white : AppColors.primary, size: 20.r),
                      ),
                      Text(
                        'iQuotes',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w600, // Regular-medium font
                          color: textPrimary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.headset_mic_outlined, color: iconColor, size: 22.r),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),

                  // 2. Banner: Profit & Bonus Ranking
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFFC3F3A0), const Color(0xFFD6F6B8)]
                            : [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      border: isDark ? null : Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profit & Bonus Ranking',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Data updated daily',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: textSecondary,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black : AppColors.primary,
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  'View',
                                  style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.emoji_events, size: 64.r, color: Colors.orange),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // 3. Marquee Announcement
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(8.r),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.campaign, color: Colors.orange, size: 18.r),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Market Closures on June 19, 2026',
                            style: TextStyle(color: textSecondary, fontSize: 12.sp),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.format_list_bulleted, color: textSecondary, size: 18.r),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // 4. 8 Shortcuts Grid
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12.h,
                    crossAxisSpacing: 8.w,
                    children: [
                      _buildShortcutItem(Icons.show_chart, 'Demo', Colors.redAccent, textPrimary),
                      _buildShortcutItem(Icons.groups, 'Team', Colors.purpleAccent, textPrimary, isHot: true),
                      _buildShortcutItem(Icons.sensors, 'Signals', Colors.pinkAccent, textPrimary, isHot: true),
                      _buildShortcutItem(Icons.confirmation_number, 'Coupon', Colors.greenAccent, textPrimary),
                      _buildShortcutItem(Icons.hardware, 'Mining', Colors.blueAccent, textPrimary),
                      _buildShortcutItem(Icons.explore, 'Discover', Colors.purple, textPrimary),
                      _buildShortcutItem(Icons.currency_bitcoin, 'MT5', Colors.blue, textPrimary),
                      _buildShortcutItem(Icons.help_outline, 'Help', Colors.lightBlue, textPrimary),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // 5. Banner: For Beginner
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2CBBE8), Color(0xFF2879D9)],
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.card_giftcard, color: Colors.amber, size: 32.r),
                            SizedBox(width: 10.w),
                            Text(
                              'For Beginner',
                              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1B38),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text('GO', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),

                  // 6. Mini Sparklines Ticker Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTickerCard('BTC/USDT', '+3.19%', '65933.6', Colors.green, cardBg, textSecondary),
                        SizedBox(width: 8.w),
                        _buildTickerCard('XAU/USD', '+1.72%', '4072.81', Colors.green, cardBg, textSecondary),
                        SizedBox(width: 8.w),
                        _buildTickerCard('ETH/USDT', '+4.69%', '1935.49', Colors.green, cardBg, textSecondary),
                        SizedBox(width: 8.w),
                        _buildTickerCard('NSDQ (x20)', '+1.11%', '28946.43', Colors.pinkAccent, cardBg, textSecondary),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // 7. Performance & Savings Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trading performance', style: TextStyle(color: textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500)),
                              SizedBox(height: 10.h),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12.r)),
                                child: Text('Check', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Savings Money', style: TextStyle(color: textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500)),
                              SizedBox(height: 2.h),
                              Text('annualized return 20%', style: TextStyle(color: Colors.orange, fontSize: 11.sp)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // 8. Signals Header Tab
                  Row(
                    children: [
                      Text('Signals', style: TextStyle(color: textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w500)),
                      SizedBox(width: 16.w),
                      Text('Calendar', style: TextStyle(color: textSecondary, fontSize: 15.sp)),
                    ],
                  ),
                  SizedBox(height: 10.h),

                  // Signal Item Card
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4.r)),
                              child: Text('UKOIL', style: TextStyle(color: Colors.green, fontSize: 11.sp, fontWeight: FontWeight.w500)),
                            ),
                            Text('12:25:00 21/07/2026', style: TextStyle(color: textSecondary, fontSize: 10.sp)),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '(U6) intraday: intraday support around 87.60.',
                          style: TextStyle(color: textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Long positions above 87.60 with targets at 90.00 & 91.20 in extension.',
                          style: TextStyle(color: textSecondary, fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 9. Floating Bottom Banner: Register & Get $199 Beginner Bonus
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 10.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7E36), Color(0xFFFFB03A)],
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Register & Get', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w500)),
                          Text('\$199 Beginner Bonus', style: TextStyle(color: Colors.yellowAccent, fontSize: 14.sp, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.lightGreenAccent,
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Text('Sign in', style: TextStyle(color: Colors.black, fontSize: 12.sp, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutItem(IconData icon, String label, Color color, Color textColor, {bool isHot = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 44.r,
              width: 44.r,
              decoration: BoxDecoration(
                color: color.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: Colors.white, size: 24.r),
            ),
            if (isHot)
              Positioned(
                top: -4.h,
                right: -4.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8.r)),
                  child: Text('Hot', style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(label, style: TextStyle(color: textColor, fontSize: 11.sp)),
      ],
    );
  }

  Widget _buildTickerCard(String symbol, String change, String price, Color color, Color cardBg, Color textSecondary) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(symbol, style: TextStyle(color: textSecondary, fontSize: 10.sp)),
              SizedBox(width: 4.w),
              Text(change, style: TextStyle(color: color, fontSize: 10.sp)),
            ],
          ),
          SizedBox(height: 2.h),
          Text(price, style: TextStyle(color: color, fontSize: 12.sp, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
