import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:crm_app/screens/finance/view_models/payment_method_controller.dart';
import 'package:crm_app/screens/finance/presentation/pages/deposit_real_screen.dart';
import 'package:crm_app/widgets/custom_toast.dart';

import '../../../../constants/color.dart';
import '../../../../constants/text_styles.dart';
import '../../../../services/language_service.dart';
import '../../../../utils/navigation_helper.dart';
import '../../../../widgets/common_loading_widget.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final String accountNumber;

  const PaymentMethodsScreen({super.key, required this.accountNumber});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final PaymentMethodController controller = Get.put(PaymentMethodController());

  late final LanguageService languageService;

  @override
  void initState() {
    super.initState();
    languageService = Get.find<LanguageService>();
    print(
      'PaymentMethodsScreen: initState called with accountNumber: "${widget.accountNumber}"',
    );
    print(
      'PaymentMethodsScreen: accountNumber isEmpty: ${widget.accountNumber.isEmpty}',
    );
    print(
      'PaymentMethodsScreen: accountNumber length: ${widget.accountNumber.length}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: IconButton(
            icon: SvgPicture.asset("assets/svg/trade/arro_back.svg",color: AppColors.textPrimary),
            onPressed: () => NavigationHelper.safeBack(context: context),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              languageService.tr('payment_methods_title'),
              style: AppTextStyles.screenTitle,
            ),
            SizedBox(height: 2.h),
            // Text(
            //   'MT5 ${widget.accountNumber}',
            //   style: TextStyle(
            //     fontSize: 12.sp,
            //     color: Colors.grey[600],
            //     fontWeight: FontWeight.normal,
            //   ),
            // ),
          ],
        ),
        shape: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading) {
          return Center(child: CommonLoadingWidget(isFullScreen: true));
        } else if (controller.kycDeposits.isEmpty) {
          return Center(child: Text(languageService.tr('common_no_data')));
        } else {
          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: controller.kycDeposits.length,
            itemBuilder: (context, index) {
              final method = controller.kycDeposits[index];
              final name = method['display_name'] ?? '';
              final iconBytes = method['iconBytes'];

              return InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                onTap: () {
                  if (method['status'] == 'active') {
                    controller.setSelectedKYCDeposit(
                      method,
                      accountNumber: widget.accountNumber,
                    );
                    // Navigate to your next screen
                    // CRITICAL: Capture account number in a final variable to ensure it's preserved
                    final accountNumberToPass = widget.accountNumber;
                    final paymentMethod = method;

                    print('========================================');
                    print(
                      'PaymentMethodsScreen: NAVIGATING TO DepositRealScreen',
                    );
                    print(
                      'PaymentMethodsScreen: widget.accountNumber: "${widget.accountNumber}"',
                    );
                    print(
                      'PaymentMethodsScreen: accountNumberToPass: "$accountNumberToPass"',
                    );
                    print(
                      'PaymentMethodsScreen: accountNumberToPass type: ${accountNumberToPass.runtimeType}',
                    );
                    print(
                      'PaymentMethodsScreen: accountNumberToPass length: ${accountNumberToPass.length}',
                    );
                    print(
                      'PaymentMethodsScreen: About to create DepositRealScreen with preselectedAccountNumber: "$accountNumberToPass"',
                    );
                    print('========================================');

                    // Use GetX arguments to pass account number (GetX preserves arguments)
                    print(
                      'PaymentMethodsScreen: Preparing navigation with arguments...',
                    );
                    print(
                      'PaymentMethodsScreen: accountNumberToPass: "$accountNumberToPass"',
                    );

                    // Store account number in GetX arguments to ensure it's preserved
                    // CRITICAL: Set arguments BEFORE calling Get.to
                    final navigationArguments = {
                      'accountNumber': accountNumberToPass,
                      'paymentMethod': paymentMethod,
                    };
                    print(
                      'PaymentMethodsScreen: Setting arguments: $navigationArguments',
                    );

                    Get.to(() {
                      print('PaymentMethodsScreen: Inside Get.to callback');
                      print(
                        'PaymentMethodsScreen: Get.arguments in callback: ${Get.arguments}',
                      );
                      return DepositRealScreen(
                        object: paymentMethod,
                        preselectedAccountNumber: accountNumberToPass,
                      );
                    }, arguments: navigationArguments);
                  } else {
                    CustomToastService.showError(
                      message: languageService.tr(
                        'payment_methods_kyc_required',
                      ),
                    );
                  }
                },
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child:
                        (iconBytes != null)
                            ? Image.memory(
                              iconBytes,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return CircleAvatar(
                                  child: Text(name.isNotEmpty ? name[0] : "?"),
                                );
                              },
                            )
                            : CircleAvatar(
                              child: Text(name.isNotEmpty ? name[0] : "?"),
                            ),
                  ),
                  title: Text(name),
                  // subtitle: Text("Instant up to 1 hour"),
                  trailing: Icon(Icons.arrow_forward_ios_rounded),
                ),
              );
            },
          );
        }
      }),
    );
  }
}
