import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:crm_app/constants/color.dart';

class IbmClientsShimmerLoading extends StatelessWidget {
  const IbmClientsShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final baseColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E8);
    final highlightColor =
        isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Header title placeholder
          Container(
            width: 140.w,
            height: 20.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(height: 6.h),
          Container(
            width: 220.w,
            height: 12.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(height: 14.h),

          // Date Filter Pills bar placeholder
          Container(
            height: 36.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          SizedBox(height: 16.h),

          // Sub-tabs placeholder
          Row(
            children: [
              Container(
                width: 120.w,
                height: 36.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 100.w,
                height: 36.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // 4 Metric cards grid
          Row(
            children: [
              Expanded(child: _buildMetricCardSkeleton()),
              SizedBox(width: 12.w),
              Expanded(child: _buildMetricCardSkeleton()),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(child: _buildMetricCardSkeleton()),
              SizedBox(width: 12.w),
              Expanded(child: _buildMetricCardSkeleton()),
            ],
          ),
          SizedBox(height: 16.h),

          // Search bar placeholder
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 75.w,
                height: 42.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                width: 65.w,
                height: 42.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Tree Node Skeletons
          _buildTreeNodeSkeleton(),
          SizedBox(height: 10.h),
          _buildTreeNodeSkeleton(),
          SizedBox(height: 10.h),
          _buildTreeNodeSkeleton(),
        ],
      ),
    );
  }

  Widget _buildMetricCardSkeleton() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 60.w,
                height: 10.h,
                color: Colors.white,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            width: 50.w,
            height: 18.h,
            color: Colors.white,
          ),
          SizedBox(height: 4.h),
          Container(
            width: 80.w,
            height: 8.h,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildTreeNodeSkeleton() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100.w, height: 12.h, color: Colors.white),
                      SizedBox(height: 4.h),
                      Container(width: 150.w, height: 8.h, color: Colors.white),
                    ],
                  ),
                ],
              ),
              Container(width: 40.w, height: 14.h, color: Colors.white),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            height: 38.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ],
      ),
    );
  }
}
