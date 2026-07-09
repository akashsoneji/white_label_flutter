import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'pmam_investor_portal_screen.dart';

class PmamMyInvestmentScreen extends StatelessWidget {
  const PmamMyInvestmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map?;
    final managerCode = args?['managerCode'] as String?;

    return PmamInvestorPortalScreen(
      managerCode: managerCode,
    );
  }
}
