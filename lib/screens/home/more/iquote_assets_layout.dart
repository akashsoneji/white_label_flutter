import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class IquoteAssetsLayout extends StatelessWidget {
  const IquoteAssetsLayout({super.key});

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF181E34);
    const cardBg = Color(0xFF222943);

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20.r,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white, size: 24.r),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'Sign in/Sign up',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.notifications_none, color: Colors.white70, size: 22.r),
                      SizedBox(width: 12.w),
                      Icon(Icons.wb_sunny_outlined, color: Colors.white70, size: 22.r),
                      SizedBox(width: 12.w),
                      Icon(Icons.settings_outlined, color: Colors.white70, size: 22.r),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // 2. Account Card
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sub Tabs
                    Row(
                      children: [
                        Text('Trading Account', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                        SizedBox(width: 16.w),
                        Text('Investment Account', style: TextStyle(color: Colors.white38, fontSize: 14.sp)),
                      ],
                    ),
                    SizedBox(height: 14.h),

                    // Equity Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('Equity', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                            SizedBox(width: 6.w),
                            Icon(Icons.help_outline, color: Colors.white38, size: 16.r),
                            SizedBox(width: 6.w),
                            Icon(Icons.visibility_off_outlined, color: Colors.white38, size: 16.r),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4.r)),
                          child: Text('V VIP 0', style: TextStyle(color: Colors.orange, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text('\$ **  = ₹ **', style: TextStyle(color: Colors.orange, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12.h),

                    // Available Balance / Margin
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Available Balance', style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
                            Text('\$ **', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Margin', style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
                            Text('\$ **', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Sign In / Sign Up Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white38),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text('Sign in', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Container(
                            height: 40.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9538),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text('Sign up', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),

              // 3. Profit & Bonus Ranking Banner
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC3F3A0), Color(0xFFD6F6B8)],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber, size: 28.r),
                        SizedBox(width: 8.w),
                        Text('Profit & Bonus Ranking', style: TextStyle(color: Colors.black, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14.r)),
                      child: Text('View', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),

              // 4. Cash Bonus
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monetization_on, color: Colors.amber, size: 32.r),
                        SizedBox(width: 10.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cash Bonus', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                            Text('\$ --', style: TextStyle(color: Colors.orange, fontSize: 12.sp)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(14.r)),
                      child: Text('Withdraw to Balance', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              // 5. Meta Trade5 Card
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pie_chart, color: Colors.cyan, size: 28.r),
                        SizedBox(width: 10.w),
                        Text('Meta Trade5', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.4), borderRadius: BorderRadius.circular(12.r)),
                      child: Text('Activate', style: TextStyle(color: Colors.tealAccent, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // 6. Settings List Options
              _buildOptionTile(Icons.assignment, 'Account statement', subtitle: 'Assets Report >'),
              _buildOptionTile(Icons.confirmation_number, 'Coupon'),
              _buildOptionTile(Icons.share, 'Referral Earning', isExternal: true),
              _buildOptionTile(Icons.settings, 'Settings'),
              _buildOptionTile(Icons.headset_mic, 'Customer Service'),
              SizedBox(height: 12.h),
              _buildOptionTile(Icons.credit_card, 'Negative balance protection'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, {String? subtitle, bool isExternal = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF222943),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.orange, size: 20.r),
              SizedBox(width: 12.w),
              Text(title, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
            ],
          ),
          Row(
            children: [
              if (subtitle != null) ...[
                Text(subtitle, style: TextStyle(color: Colors.orange, fontSize: 12.sp)),
                SizedBox(width: 4.w),
              ],
              Icon(
                isExternal ? Icons.open_in_new : Icons.chevron_right,
                color: Colors.white38,
                size: 18.r,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
