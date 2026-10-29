import 'package:flutter/material.dart';
import '../../constants/text_styles.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../constants/color.dart';
import '../../services/secure_storage_service.dart';
import '../../widgets/app_back_button.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  /// Sends the user's API token as a Bearer header. Turn off for third-party
  /// pages (e.g. the live chat provider) so the token never leaves our backend.
  final bool attachAuthToken;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.attachAuthToken = true,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final token = widget.attachAuthToken
        ? await SecureStorageService.getAuthToken()
        : null;

    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                  });
                }
              },
              onPageFinished: (String url) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              onWebResourceError: (WebResourceError error) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
            ),
          );

    // Load with headers
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    controller.loadRequest(Uri.parse(widget.url), headers: headers);

    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.title, style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary)),
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      // Keep page content (e.g. the chat provider's bottom bar) above the
      // system navigation bar on edge-to-edge devices.
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (_isLoading || _controller == null)
              Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
