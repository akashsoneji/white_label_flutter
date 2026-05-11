import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../app_lock_service.dart';

class AppLockLifecycle extends StatefulWidget {
  final Widget child;

  const AppLockLifecycle({super.key, required this.child});

  @override
  State<AppLockLifecycle> createState() => _AppLockLifecycleState();
}

class _AppLockLifecycleState extends State<AppLockLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (!Get.isRegistered<AppLockService>()) return;
      final lock = Get.find<AppLockService>();
      lock.lockIfNeeded(reason: 'Unlock to continue');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

