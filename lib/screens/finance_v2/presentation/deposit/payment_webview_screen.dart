import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:crm_app/widgets/custom_toast.dart';

/// Where the gateway sends the client back once the payment page is done:
/// the portal's `/#/dashboard` route.
const String _returnFragment = '/dashboard';

const Set<String> _webSchemes = <String>{'http', 'https'};

/// Schemes that are neither a web page nor another app.
const Set<String> _blockedSchemes = <String>{
  'javascript',
  'data',
  'file',
  'blob',
  'content',
  'view-source',
};

final RegExp _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*$');
final RegExp _intentSchemePattern = RegExp(r'(?:^|;)scheme=([^;]+)');

/// What the payment page may do with a URL it wants to open.
enum PaymentNavigation {
  /// A web page: stays in the webview.
  allow,

  /// The portal dashboard: the payment page is done.
  close,

  /// Another app (UPI, a bank app, the dialler): opened outside the webview.
  external,

  /// Neither a page nor an app: dropped.
  block,
}

/// True when [url] is the portal page a gateway returns to after payment.
///
/// Only the fragment counts, so a URL that merely carries the dashboard
/// address in a query parameter does not close the page.
bool isPaymentReturnUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !_webSchemes.contains(uri.scheme.toLowerCase())) {
    return false;
  }
  return uri.fragment.startsWith(_returnFragment);
}

PaymentNavigation classifyPaymentNavigation(String url) {
  if (isPaymentReturnUrl(url)) return PaymentNavigation.close;

  final scheme = Uri.tryParse(url)?.scheme.toLowerCase() ?? '';
  // `about:blank` is what an empty frame loads.
  if (_webSchemes.contains(scheme) || scheme == 'about') {
    return PaymentNavigation.allow;
  }
  if (scheme.isEmpty || _blockedSchemes.contains(scheme)) {
    return PaymentNavigation.block;
  }
  return PaymentNavigation.external;
}

/// The address to hand to the system for a non-web [url].
///
/// An Android `intent://…#Intent;scheme=upi;…;end` URL is turned into the
/// plain `upi://…` address it stands for. Null when there is nothing safe to
/// open.
Uri? externalPaymentUri(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.scheme.toLowerCase() != 'intent') return uri;

  final target = _intentSchemePattern.firstMatch(uri.fragment)?.group(1) ?? '';
  if (!_schemePattern.hasMatch(target) ||
      _blockedSchemes.contains(target.toLowerCase())) {
    return null;
  }
  return uri.replace(scheme: target).removeFragment();
}

/// The gateway's payment page inside the app.
///
/// Pops by itself when the page navigates to the portal dashboard. The API
/// token is never sent: the page belongs to a third party.
class PaymentWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PaymentWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    final initialUri = Uri.tryParse(widget.url.trim());
    // A payment page is only ever opened over https.
    if (initialUri == null || initialUri.scheme.toLowerCase() != 'https') {
      _isLoading = false;
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          // Hash-only changes do not raise a navigation request.
          onUrlChange: (change) {
            if (isPaymentReturnUrl(change.url ?? '')) _close();
          },
          onPageStarted: (_) => _setLoading(true),
          onPageFinished: (_) => _setLoading(false),
          onWebResourceError: (_) => _setLoading(false),
        ),
      )
      ..loadRequest(initialUri);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    switch (classifyPaymentNavigation(request.url)) {
      case PaymentNavigation.allow:
        return NavigationDecision.navigate;
      case PaymentNavigation.close:
        _close();
        return NavigationDecision.prevent;
      case PaymentNavigation.external:
        _openExternally(request.url);
        return NavigationDecision.prevent;
      case PaymentNavigation.block:
        // Inline frames of a payment page (3-D Secure) use data and blob
        // documents; only the page itself may not go there.
        return request.isMainFrame
            ? NavigationDecision.prevent
            : NavigationDecision.navigate;
    }
  }

  Future<void> _openExternally(String url) async {
    final uri = externalPaymentUri(url);
    var isOpened = false;
    if (uri != null) {
      try {
        isOpened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // No app on the device handles this address.
        isOpened = false;
      }
    }
    if (isOpened) return;
    CustomToastService.showError(
      message: TranslationUtils.tr('platforms_open_failed'),
    );
  }

  void _setLoading(bool value) {
    if (mounted && _isLoading != value) setState(() => _isLoading = value);
  }

  void _close() {
    if (_isClosed || !mounted) return;
    _isClosed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.tradeBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.tradeBackground,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: controller == null
            ? const _LinkNotOpened()
            : Stack(
                children: [
                  WebViewWidget(controller: controller),
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Shown instead of the page when the payment link is not an https address.
class _LinkNotOpened extends StatelessWidget {
  const _LinkNotOpened();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Text(
          TranslationUtils.tr('platforms_open_failed'),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}
