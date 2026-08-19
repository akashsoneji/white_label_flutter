import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ibm/view_models/ibm_controller.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_manager_portal_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_clients_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_wallet_screen.dart';
import 'package:crm_app/screens/ibm/presentation/pages/ibm_links_screen.dart';
import 'package:crm_app/services/language_service.dart';

class IbmMainShell extends StatelessWidget {
  const IbmMainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final IbmController controller = Get.put(IbmController());
    final languageService = Get.find<LanguageService>();

    final List<Widget> pages = [
      const IbmManagerPortalScreen(),
      const IbmClientsScreen(),
      const IbmWalletScreen(),
      const IbmLinksScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.tradeBackgroundCenterColor,
      body: Obx(() => IndexedStack(
        index: controller.currentTabIndex.value,
        children: pages,
      )),
      bottomNavigationBar: Obx(() {
        final pendingRequests = controller.requestsData['waiting_count'] ?? 0;

        return BottomNavigationBar(
          currentIndex: controller.currentTabIndex.value,
          onTap: controller.changeTab,
          selectedItemColor: const Color(0xFF5F259E),
          unselectedItemColor: AppColors.textGrey,
          backgroundColor: AppColors.whiteColor,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard),
              label: languageService.tr('Dashboard'),
            ),
            BottomNavigationBarItem(
              icon: pendingRequests > 0
                  ? Badge(
                      label: Text('$pendingRequests'),
                      child: const Icon(Icons.people_outline),
                    )
                  : const Icon(Icons.people_outline),
              activeIcon: const Icon(Icons.people),
              label: languageService.tr('Network'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: const Icon(Icons.account_balance_wallet),
              label: languageService.tr('Commission'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.link_outlined),
              activeIcon: const Icon(Icons.link),
              label: languageService.tr('Links'),
            ),
          ],
        );
      }),
    );
  }
}
