import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../widgets/rtl_components.dart';
import '../constants/color.dart';
import '../constants/text_styles.dart';
import 'package:crm_app/screens/common/view_models/app_notification_controller.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:flutter/material.dart';

/// Example screen showing how to use RTL Components
class ExampleRTLComponentsScreen extends StatelessWidget {
  const ExampleRTLComponentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('RTL Components Demo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.whiteColor,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Buttons
            _buildSectionTitle('1. Buttons'),
            SizedBox(height: 16.h),

            // Elevated Button
            RTLComponents.elevatedButton(
              text: 'Elevated Button',
              onPressed: () => _showSnackBar('Elevated Button Pressed'),
            ),
            SizedBox(height: 12.h),

            // Elevated Button with Icon
            RTLComponents.elevatedButton(
              text: 'Button with Icon',
              onPressed: () => _showSnackBar('Icon Button Pressed'),
              icon: Icon(Icons.star, color: AppColors.whiteColor, size: 20.sp),
            ),
            SizedBox(height: 12.h),

            // Elevated Button with Custom Size
            RTLComponents.elevatedButton(
              text: 'Custom Height (60)',
              onPressed: () => _showSnackBar('Custom Height Button'),
              height: 60,
              width: 200.w,
            ),
            SizedBox(height: 12.h),

            // Elevated Button with Loading
            RTLComponents.elevatedButton(
              text: 'Loading Button',
              onPressed: () => _showSnackBar('Loading Button'),
              isLoading: true,
            ),
            SizedBox(height: 24.h),

            // Outlined Button
            RTLComponents.outlinedButton(
              text: 'Outlined Button',
              onPressed: () => _showSnackBar('Outlined Button Pressed'),
            ),
            SizedBox(height: 12.h),

            // Outlined Button with Custom Colors
            RTLComponents.outlinedButton(
              text: 'Custom Colors',
              onPressed: () => _showSnackBar('Custom Colors Button'),
              borderColor: AppColors.success,
              textColor: AppColors.success,
            ),
            SizedBox(height: 24.h),

            // Text Button
            RTLComponents.textButton(
              text: 'Text Button',
              onPressed: () => _showSnackBar('Text Button Pressed'),
            ),
            SizedBox(height: 24.h),

            // Section 2: Text Fields
            _buildSectionTitle('2. Text Fields'),
            SizedBox(height: 16.h),

            // Basic Text Field
            RTLComponents.textField(
              controller: _emailController,
              labelText: 'Email',
              hintText: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(Icons.email, color: AppColors.primary),
            ),
            SizedBox(height: 16.h),

            // Password Text Field
            RTLComponents.textField(
              controller: _passwordController,
              labelText: 'Password',
              hintText: 'Enter your password',
              obscureText: true,
              prefixIcon: Icon(Icons.lock, color: AppColors.primary),
              suffixIcon: Icon(Icons.visibility, color: AppColors.primary),
            ),
            SizedBox(height: 16.h),

            // Custom Height Text Field
            RTLComponents.textField(
              controller: _emailController,
              labelText: 'Custom Height (60)',
              hintText: 'Taller text field',
              height: 60,
              borderColor: AppColors.success,
              focusedBorderColor: AppColors.success,
            ),
            SizedBox(height: 24.h),

            // Section 3: Cards and Containers
            _buildSectionTitle('3. Cards & Containers'),
            SizedBox(height: 16.h),

            // Basic Card
            RTLComponents.card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Card Title', style: AppTextStyles.heading),
                  SizedBox(height: 8.h),
                  Text(
                    'This is a card with default styling and RTL support.',
                    style: AppTextStyles.subheading,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Custom Card
            RTLComponents.card(
              child: Text('Custom Card'),
              color: AppColors.cardBackGround,
              elevation: 4,
              borderRadius: BorderRadius.circular(20.r),
            ),
            SizedBox(height: 16.h),

            // Container
            RTLComponents.container(
              child: Text('Container with default styling'),
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(8.r),
            ),
            SizedBox(height: 24.h),

            // Section 4: Layout Components
            _buildSectionTitle('4. Layout Components'),
            SizedBox(height: 16.h),

            // Row with spacing
            RTLComponents.row(
              children: [
                RTLComponents.iconButton(
                  icon: Icons.favorite,
                  onPressed: () => _showSnackBar('Like'),
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.whiteColor,
                ),
                RTLComponents.iconButton(
                  icon: Icons.share,
                  onPressed: () => _showSnackBar('Share'),
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.whiteColor,
                ),
                RTLComponents.iconButton(
                  icon: Icons.bookmark,
                  onPressed: () => _showSnackBar('Bookmark'),
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.whiteColor,
                ),
              ],
              spacing: 12,
            ),
            SizedBox(height: 16.h),

            // Column with spacing
            RTLComponents.column(
              children: [
                RTLComponents.elevatedButton(
                  text: 'Button 1',
                  onPressed: () => _showSnackBar('Button 1'),
                  width: double.infinity,
                ),
                RTLComponents.outlinedButton(
                  text: 'Button 2',
                  onPressed: () => _showSnackBar('Button 2'),
                  width: double.infinity,
                ),
                RTLComponents.textButton(
                  text: 'Button 3',
                  onPressed: () => _showSnackBar('Button 3'),
                  width: double.infinity,
                ),
              ],
              spacing: 12,
            ),
            SizedBox(height: 24.h),

            // Section 5: List Tiles
            _buildSectionTitle('5. List Tiles'),
            SizedBox(height: 16.h),

            RTLComponents.listTile(
              title: 'Profile Settings',
              subtitle: 'Manage your account settings',
              leading: Icon(Icons.person, color: AppColors.primary),
              trailing: Icon(Icons.arrow_forward_ios, color: AppColors.primary),
              onTap: () => _showSnackBar('Profile Settings tapped'),
            ),

            RTLComponents.listTile(
              title: 'Notifications',
              subtitle: 'Configure notification preferences',
              leading: Icon(Icons.notifications, color: AppColors.primary),
              trailing: Icon(Icons.arrow_forward_ios, color: AppColors.primary),
              onTap: () => _showSnackBar('Notifications tapped'),
            ),

            RTLComponents.listTile(
              title: 'Privacy',
              subtitle: 'Manage your privacy settings',
              leading: Icon(Icons.security, color: AppColors.primary),
              trailing: Icon(Icons.arrow_forward_ios, color: AppColors.primary),
              onTap: () => _showSnackBar('Privacy tapped'),
            ),

            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 18.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  void _showSnackBar(String message) {
    if (Get.isRegistered<AppNotificationController>()) {
      Get.find<AppNotificationController>().showInfo(
        message: message,
        title: 'Action',
      );
    }
  }
}
