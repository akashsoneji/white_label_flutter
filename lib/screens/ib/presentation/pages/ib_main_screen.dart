import 'package:flutter/material.dart';

// import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/screens/ib/view_models/ib_controller.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_dashboard_new_screen.dart';
import 'package:crm_app/screens/ib/presentation/pages/my_structure_screen.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_structure_screen.dart';
import 'package:crm_app/screens/ib/presentation/pages/ib_requests_screen.dart';
// import 'package:crm_app/screens/ib/presentation/pages/ib_more_screen.dart';
import 'package:crm_app/screens/ib/presentation/pages/my_clients_screen.dart';
import 'package:crm_app/widgets/ib_bottom_navigation.dart';

class IbMainScreen extends StatefulWidget {
  const IbMainScreen({super.key});

  @override
  State<IbMainScreen> createState() => _IbMainScreenState();
}

class _IbMainScreenState extends State<IbMainScreen> {
  int _currentIndex = 0;
  late IBController ibController;
  int _screenKey = 0; // Key to force rebuild screens
  bool _hasInitialized = false;
  DateTime? _lastResetTime;
  late final PageController _pageController;


  @override
  void initState() {
    super.initState();
    // Initialize IBController if not registered
    if (Get.isRegistered<IBController>()) {
      ibController = Get.find<IBController>();
    } else {
      ibController = Get.put(IBController());
    }

    // Reset state when navigating to IB dashboard
    _resetIBState();
    _hasInitialized = true;
    _lastResetTime = DateTime.now();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset state when screen becomes visible again after navigation
    // Only reset if it's been more than 500ms since last reset to avoid excessive calls
    if (_hasInitialized &&
        (_lastResetTime == null ||
            DateTime.now().difference(_lastResetTime!).inMilliseconds > 500)) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _resetIBState();
        }
      });
    }
  }

  void _resetIBState() {
    // Reset selected sub-IB and clear hierarchy
    ibController.selectedSubIBId = null;
    // Reset to Dashboard tab only if not already on it
    if (_currentIndex != 0) {
      _currentIndex = 0;
    }
    // Increment key to force rebuild all screens when navigating back
    _screenKey++;
    _lastResetTime = DateTime.now();
    // Force update to clear any stale UI state
    ibController.update(['ib_clients', 'ib_structure']);
  }

  List<Widget> _getScreens(bool isTraditional) {
    // Use key to force rebuild when navigating back
    return [
      KeepAliveWrapper(
        key: ValueKey('dashboard_$_screenKey'),
        child: IbDashboardNewScreen(
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (_pageController.hasClients) {
              _pageController.jumpToPage(index);
            }
          },
        ),
      ),
      KeepAliveWrapper(
        key: ValueKey('my_structure_$_screenKey'),
        child: const MyStructureScreen(),
      ),
      if (!isTraditional) ...[
        KeepAliveWrapper(
          key: ValueKey('structure_$_screenKey'),
          child: const IBStructureScreen(),
        ),
        KeepAliveWrapper(
          key: ValueKey('clients_$_screenKey'),
          child: const MyClientsScreen(),
        ),
        KeepAliveWrapper(
          key: ValueKey('requests_$_screenKey'),
          child: const IBRequestsScreen(),
        ),
      ] else ...[
        KeepAliveWrapper(
          key: ValueKey('clients_$_screenKey'),
          child: const MyClientsScreen(),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ibType = ibController.ibStatusResponse.value?.data?.ibType ?? 'dynamic';
      final isTraditional = ibType == 'traditional';

      return Scaffold(
        backgroundColor: AppColors.tradeBackgroundCenterColor,
        extendBody: true,
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (_currentIndex == index) return;
              setState(() {
                if (index == 0 && _currentIndex != 0) {
                  _resetIBState();
                }
                _currentIndex = index;
              });
            },
            physics: const NeverScrollableScrollPhysics(),
            children: _getScreens(isTraditional),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
        floatingActionButton: IbBottomNavigation(
          currentIndex: _currentIndex,
          isTraditional: isTraditional,
          onTap: (index) {
            if (_currentIndex == index) return;
            if (_pageController.hasClients) {
              _pageController.jumpToPage(index);
            }
            setState(() {
              // If switching to Dashboard, reset state
              if (index == 0 && _currentIndex != 0) {
                _resetIBState();
              }
              _currentIndex = index;
            });
          },
        ),
      );
    });
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

