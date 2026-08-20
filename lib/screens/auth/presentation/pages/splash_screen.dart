import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/routes/app_pages.dart';
import 'package:crm_app/flavor_config.dart';
import 'dart:async';
import 'package:crm_app/screens/auth/view_models/auth_view_model.dart';
import 'package:crm_app/services/chart_webview_prewarmer.dart';

import 'package:crm_app/services/symbol_selection_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    // Pre-warm the chart WebView engine and cache the HTML in parallel with the auth check.
    if (!FlavorConfig.instance.useNewChart) {
      final symService =
          Get.isRegistered<SymbolSelectionService>()
              ? Get.find<SymbolSelectionService>()
              : Get.put(SymbolSelectionService());

      symService.ensureDefault().then((_) {
        final sym =
            symService.currentSymbol.isNotEmpty
                ? symService.currentSymbol
                : 'XAUUSD';
        ChartWebViewPrewarmer.instance.prewarm(symbol: sym);
      });
    }
    // No branded Flutter splash UI. Let native splash show background,
    // then immediately route based on persisted session.
    scheduleMicrotask(_checkAuthAndNavigate);
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final isLoggedIn = await SecureStorageService.isUserLoggedIn();

      if (isLoggedIn) {
        await authController.checkAuthStatus().timeout(
          const Duration(seconds: 8),
        );
        await Future.delayed(const Duration(milliseconds: 100));

        if (authController.isAuthenticated) {
          Get.offAllNamed(AppPages.TRADING);
        } else {
          await SecureStorageService.clearAuthData();
          Get.offAllNamed(AppPages.GET_STARTED);
        }
      } else {
        Get.offAllNamed(AppPages.GET_STARTED);
      }
    } catch (e) {
      // Don't clear persisted sessions on transient startup failures (timeout, flaky network, etc.).
      // If a real 401 happens, the normal API layer will eventually surface it and logout safely.
      try {
        final stillLoggedIn = await SecureStorageService.isUserLoggedIn();
        if (stillLoggedIn) {
          Get.offAllNamed(AppPages.TRADING);
          return;
        }
      } catch (_) {}
      Get.offAllNamed(AppPages.GET_STARTED);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlavorConfig.instance.primaryColor,
      body: const SizedBox.shrink(),
    );
  }
}
